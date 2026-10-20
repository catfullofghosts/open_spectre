#include "live_video_fx.h"

#include <string.h>
#include "xil_cache.h"

#define LIVE_FX_MAX_FRAME   (1920U * 1080U * 3U)
#define LIVE_FX_HALF_FRAME  (LIVE_FX_MAX_FRAME / 2U)
#define LIVE_FX_STRIP_SLOTS 8U
#define LIVE_FX_SHUFFLE_SLOTS 8U
#define LIVE_FX_FILM_GRID_MAX 4U
#define LIVE_FX_PI          3.14159265359f

#define SIN_LUT_BITS 10U
#define SIN_LUT_SIZE (1U << SIN_LUT_BITS)
#define SIN_LUT_MASK (SIN_LUT_SIZE - 1U)
#define SIN_LUT_FRAC_BITS (32U - SIN_LUT_BITS)
#define SIN_LUT_FRAC_MASK ((1U << SIN_LUT_FRAC_BITS) - 1U)
#define PHASE_PI_2 0x40000000U
#define PHASE_PER_RAD 683565280.0f

static float g_sinLut[SIN_LUT_SIZE + 1U];
static int g_sinLutInit = 0;

static u8 g_delayPlane[LIVE_FX_HALF_FRAME] __attribute__((aligned(0x20)));
static u8 g_stripRing[LIVE_FX_STRIP_SLOTS][LIVE_FX_HALF_FRAME] __attribute__((aligned(0x20)));
static u32 g_frameCount = 0U;
static u32 g_stripWrite = 0U;
static int g_inited = 0;
static u32 g_slitIndex = 0U;
static u32 g_lastSlitChunk = 0U;
static u32 g_lastFilmTiles = 0U;
static u32 g_speckleRng = 1U;
static u32 g_fxRng = 1U;
static u32 g_shrinkSeed = 12345U;

static float fx_sin_poly(float x)
{
	const float TWO_PI = 6.28318530718f;
	float x2;
	float x3;
	float x5;
	float x7;

	while (x < 0.0f)
	{
		x += TWO_PI;
	}
	while (x >= TWO_PI)
	{
		x -= TWO_PI;
	}
	x2 = x * x;
	x3 = x2 * x;
	x5 = x3 * x2;
	x7 = x5 * x2;
	return x - (x3 / 6.0f) + (x5 / 120.0f) - (x7 / 5040.0f);
}

static void fx_init_sin(void)
{
	u32 i;
	const float twoPiOverN = 6.28318530718f / (float)SIN_LUT_SIZE;

	if (g_sinLutInit != 0)
	{
		return;
	}
	for (i = 0U; i < SIN_LUT_SIZE; i++)
	{
		g_sinLut[i] = fx_sin_poly(twoPiOverN * (float)i);
	}
	g_sinLut[SIN_LUT_SIZE] = g_sinLut[0];
	g_sinLutInit = 1;
}

static float fx_sin_phase(u32 phase)
{
	u32 idx;
	u32 fracRaw;
	float frac;
	float a;
	float b;

	if (g_sinLutInit == 0)
	{
		fx_init_sin();
	}
	idx = phase >> SIN_LUT_FRAC_BITS;
	fracRaw = phase & SIN_LUT_FRAC_MASK;
	frac = (float)fracRaw * (1.0f / (float)(1U << SIN_LUT_FRAC_BITS));
	a = g_sinLut[idx & SIN_LUT_MASK];
	b = g_sinLut[(idx + 1U) & SIN_LUT_MASK];
	return a + ((b - a) * frac);
}

static float fx_sin(float x)
{
	return fx_sin_phase((u32)(x * PHASE_PER_RAD));
}

static float fx_cos(float x)
{
	return fx_sin_phase((u32)(x * PHASE_PER_RAD) + PHASE_PI_2);
}

static u32 fx_packed(u32 width)
{
	return width * 3U;
}

static void fx_copy_plane(u8 *dst, u32 dstStride, const u8 *src, u32 srcStride, u32 width, u32 height)
{
	u32 y;
	u32 rowBytes = width * 3U;

	if ((dstStride == srcStride) && (srcStride == rowBytes))
	{
		memcpy(dst, src, rowBytes * height);
		return;
	}
	for (y = 0U; y < height; y++)
	{
		memcpy(dst + (y * dstStride), src + (y * srcStride), rowBytes);
	}
}

static void fx_flush(u8 *frame, u32 height, u32 stride)
{
	Xil_DCacheFlushRange((unsigned int)frame, height * stride);
}

static void fx_reverse_row(u8 *dst, const u8 *src, u32 width)
{
	const u8 *s = src + ((width - 1U) * 3U);
	u32 x;

	for (x = 0U; x < width; x++)
	{
		dst[0] = s[0];
		dst[1] = s[1];
		dst[2] = s[2];
		dst += 3;
		s -= 3;
	}
}

void LiveFxReset(void)
{
	g_frameCount = 0U;
	g_stripWrite = 0U;
	g_inited = 0;
	g_slitIndex = 0U;
	g_lastSlitChunk = 0U;
	g_lastFilmTiles = 0U;
	g_speckleRng = 1U;
	g_fxRng = 1U;
	memset(g_delayPlane, 0, sizeof(g_delayPlane));
}

void LiveFxCopy(const u8 *src, u8 *dst, u32 width, u32 height, u32 srcStride, u32 dstStride)
{
	fx_copy_plane(dst, dstStride, src, srcStride, width, height);
	fx_flush(dst, height, dstStride);
}

void LiveFxMirror(u8 *src, u8 *dst, u32 width, u32 height, u32 stride, int mode)
{
	u32 y;
	u32 centerX = width / 2U;
	u32 centerY = height / 2U;
	u32 rowBytes = width * 3U;
	u32 leftBytes = centerX * 3U;
	u32 rightWidth = width - centerX;

	if (mode == LIVE_FX_MIRROR_OFF)
	{
		LiveFxCopy(src, dst, width, height, stride, stride);
		return;
	}

	for (y = 0U; y < height; y++)
	{
		u8 *dstRow = dst + (y * stride);
		const u8 *srcRow;
		u32 srcY;

		switch (mode)
		{
		case LIVE_FX_MIRROR_V:
			srcY = height - 1U - y;
			memcpy(dstRow, src + (srcY * stride), rowBytes);
			break;
		case LIVE_FX_MIRROR_H:
			fx_reverse_row(dstRow, src + (y * stride), width);
			break;
		case LIVE_FX_MIRROR_BOTH:
			srcY = height - 1U - y;
			fx_reverse_row(dstRow, src + (srcY * stride), width);
			break;
		case LIVE_FX_MIRROR_CENTER_X:
			srcRow = src + (y * stride);
			memcpy(dstRow, srcRow, leftBytes);
			fx_reverse_row(dstRow + leftBytes, srcRow, rightWidth);
			break;
		case LIVE_FX_MIRROR_CENTER_Y:
			srcY = (y < centerY) ? y : (height - 1U - y);
			memcpy(dstRow, src + (srcY * stride), rowBytes);
			break;
		case LIVE_FX_MIRROR_CENTER_XY:
			srcY = (y < centerY) ? y : (height - 1U - y);
			srcRow = src + (srcY * stride);
			memcpy(dstRow, srcRow, leftBytes);
			fx_reverse_row(dstRow + leftBytes, srcRow, rightWidth);
			break;
		default:
			memcpy(dstRow, src + (y * stride), rowBytes);
			break;
		}
	}
	fx_flush(dst, height, stride);
}

void LiveFxTile(u8 *src, u8 *dst, u32 width, u32 height, u32 stride, int mode)
{
	u32 tiles;
	u32 xcoi;
	u32 ycoi;
	u32 destAddr;
	u32 srcX;
	u32 srcY;
	u32 srcAddr;
	u32 tileWidth;
	u32 tileHeight;
	u32 srcYScale;
	u32 srcXScale;

	switch (mode)
	{
	case LIVE_FX_TILE_2X2:
		tiles = 2U;
		break;
	case LIVE_FX_TILE_4X4:
		tiles = 4U;
		break;
	case LIVE_FX_TILE_3X3:
		tiles = 3U;
		break;
	case LIVE_FX_TILE_8X8:
		tiles = 8U;
		break;
	case LIVE_FX_TILE_16X16:
		tiles = 16U;
		break;
	default:
		LiveFxCopy(src, dst, width, height, stride, stride);
		return;
	}

	tileWidth = width / tiles;
	tileHeight = height / tiles;
	if ((tileWidth == 0U) || (tileHeight == 0U))
	{
		LiveFxCopy(src, dst, width, height, stride, stride);
		return;
	}

	srcYScale = (height << 16) / tileHeight;
	srcXScale = (width << 16) / tileWidth;

	for (ycoi = 0U; ycoi < height; ycoi++)
	{
		u32 tileRow = ycoi / tileHeight;
		u32 yInTile = ycoi % tileHeight;

		if (tileRow >= tiles)
		{
			tileRow = tiles - 1U;
		}
		srcY = (yInTile * srcYScale) >> 16;
		if (srcY >= height)
		{
			srcY = height - 1U;
		}
		destAddr = ycoi * stride;
		for (xcoi = 0U; xcoi < width; xcoi++)
		{
			u32 tileCol = xcoi / tileWidth;
			u32 xInTile = xcoi % tileWidth;

			if (tileCol >= tiles)
			{
				tileCol = tiles - 1U;
			}
			srcX = (xInTile * srcXScale) >> 16;
			if (srcX >= width)
			{
				srcX = width - 1U;
			}
			srcAddr = (srcY * stride) + (srcX * 3U);
			dst[destAddr] = src[srcAddr];
			dst[destAddr + 1U] = src[srcAddr + 1U];
			dst[destAddr + 2U] = src[srcAddr + 2U];
			destAddr += 3U;
		}
	}
	fx_flush(dst, height, stride);
}

static void fx_zoom(u8 *src, u8 *dst, u32 width, u32 height, u32 stride, float zoom)
{
	u32 xcoi;
	u32 ycoi;
	u32 destAddr;
	float invZoom = 1.0f / zoom;
	float centerXPix = 0.5f * (float)width;
	float centerYPix = 0.5f * (float)height;
	float offsetX = centerXPix * (1.0f - invZoom);
	float offsetY = centerYPix * (1.0f - invZoom);
	float maxX = (float)(width - 1U);
	float maxY = (float)(height - 1U);

	for (ycoi = 0U; ycoi < height; ycoi++)
	{
		float yZoomed = ((float)ycoi * invZoom) + offsetY;
		destAddr = ycoi * stride;
		for (xcoi = 0U; xcoi < width; xcoi++)
		{
			float srcX = ((float)xcoi * invZoom) + offsetX;
			float srcY = yZoomed;
			u32 srcXInt;
			u32 srcYInt;
			u32 srcAddr;

			if (srcX < 0.0f)
			{
				srcX = 0.0f;
			}
			if (srcX > maxX)
			{
				srcX = maxX;
			}
			if (srcY < 0.0f)
			{
				srcY = 0.0f;
			}
			if (srcY > maxY)
			{
				srcY = maxY;
			}
			srcXInt = (u32)srcX;
			srcYInt = (u32)srcY;
			srcAddr = (srcYInt * stride) + (srcXInt * 3U);
			dst[destAddr] = src[srcAddr];
			dst[destAddr + 1U] = src[srcAddr + 1U];
			dst[destAddr + 2U] = src[srcAddr + 2U];
			destAddr += 3U;
		}
	}
	fx_flush(dst, height, stride);
}

void LiveFxZoom(u8 *src, u8 *dst, u32 width, u32 height, u32 stride, int mode)
{
	if (mode == LIVE_FX_ZOOM_IN)
	{
		fx_zoom(src, dst, width, height, stride, 2.0f);
	}
	else if (mode == LIVE_FX_ZOOM_OUT)
	{
		fx_zoom(src, dst, width, height, stride, 0.5f);
	}
	else
	{
		LiveFxCopy(src, dst, width, height, stride, stride);
	}
}

void LiveFxMosaic(u8 *src, u8 *dst, u32 width, u32 height, u32 stride, int mode)
{
	u32 blockSize;
	u32 blockX;
	u32 blockY;

	if (mode == LIVE_FX_MOSAIC_8)
	{
		blockSize = 8U;
	}
	else if (mode == LIVE_FX_MOSAIC_16)
	{
		blockSize = 16U;
	}
	else if (mode == LIVE_FX_MOSAIC_32)
	{
		blockSize = 32U;
	}
	else
	{
		LiveFxCopy(src, dst, width, height, stride, stride);
		return;
	}

	for (blockY = 0U; blockY < height; blockY += blockSize)
	{
		for (blockX = 0U; blockX < width; blockX += blockSize)
		{
			u32 blockEndX = blockX + blockSize;
			u32 blockEndY = blockY + blockSize;
			u32 rSum = 0U;
			u32 gSum = 0U;
			u32 bSum = 0U;
			u32 pixelCount = 0U;
			u32 srcY;
			u32 srcX;
			u32 destAddr;
			u32 xcoi;
			u32 ycoi;
			u8 rAvg;
			u8 gAvg;
			u8 bAvg;
			u32 rowSlice;
			u8 *firstRow;

			if (blockEndX > width)
			{
				blockEndX = width;
			}
			if (blockEndY > height)
			{
				blockEndY = height;
			}
			for (srcY = blockY; srcY < blockEndY; srcY++)
			{
				u32 srcAddr = (srcY * stride) + (blockX * 3U);
				for (srcX = blockX; srcX < blockEndX; srcX++)
				{
					rSum += src[srcAddr];
					gSum += src[srcAddr + 1U];
					bSum += src[srcAddr + 2U];
					srcAddr += 3U;
					pixelCount++;
				}
			}
			rAvg = (u8)(rSum / pixelCount);
			gAvg = (u8)(gSum / pixelCount);
			bAvg = (u8)(bSum / pixelCount);
			destAddr = (blockY * stride) + (blockX * 3U);
			for (xcoi = blockX; xcoi < blockEndX; xcoi++)
			{
				dst[destAddr] = rAvg;
				dst[destAddr + 1U] = gAvg;
				dst[destAddr + 2U] = bAvg;
				destAddr += 3U;
			}
			rowSlice = (blockEndX - blockX) * 3U;
			firstRow = dst + (blockY * stride) + (blockX * 3U);
			for (ycoi = blockY + 1U; ycoi < blockEndY; ycoi++)
			{
				memcpy(dst + (ycoi * stride) + (blockX * 3U), firstRow, rowSlice);
			}
		}
	}
	fx_flush(dst, height, stride);
}

void LiveFxPlane3DRaw(u8 *src, u8 *dst, u32 width, u32 height, u32 stride,
	float rotX, float rotY, float rotZ, float scale, float offsetX, float offsetY)
{
	u32 xcoi;
	u32 ycoi;
	u32 destAddr;
	float cosX = fx_cos(rotX);
	float sinX = fx_sin(rotX);
	float cosY = fx_cos(rotY);
	float sinY = fx_sin(rotY);
	float cosZ = fx_cos(rotZ);
	float sinZ = fx_sin(rotZ);
	float centerX = (float)width * 0.5f;
	float centerY = (float)height * 0.5f;
	float invCenterX = 1.0f / centerX;
	float invCenterY = 1.0f / centerY;
	float maxX = (float)(width - 1U);
	float maxY = (float)(height - 1U);
	float perspectiveDist = 2.5f;

	if (scale == 0.0f)
	{
		scale = 1.0f;
	}

	for (ycoi = 0U; ycoi < height; ycoi++)
	{
		float screenY = ((float)ycoi - centerY) * invCenterY;
		float screenX = (-centerX) * invCenterX;
		destAddr = ycoi * stride;
		for (xcoi = 0U; xcoi < width; xcoi++)
		{
			float scaledX = screenX / scale;
			float scaledY = screenY / scale;
			float srcNX = scaledX;
			float srcNY = scaledY;
			int iter;
			float srcXf;
			float srcYf;
			u32 srcXInt;
			u32 srcYInt;

			for (iter = 0; iter < 3; iter++)
			{
				float px = srcNX;
				float py = srcNY * cosX;
				float pz = srcNY * sinX;
				float px2 = (px * cosY) - (pz * sinY);
				float pz2 = (px * sinY) + (pz * cosY);
				float px3;
				float py3;
				float perspFactor;
				float projX;
				float projY;

				px = px2;
				pz = pz2;
				px3 = (px * cosZ) - (py * sinZ);
				py3 = (px * sinZ) + (py * cosZ);
				px = px3;
				py = py3;
				perspFactor = 1.0f / (1.0f + (pz / perspectiveDist));
				projX = px * perspFactor;
				projY = py * perspFactor;
				srcNX += (scaledX - projX) * 0.8f;
				srcNY += (scaledY - projY) * 0.8f;
			}

			srcXf = (srcNX * centerX) + centerX + offsetX;
			srcYf = (srcNY * centerY) + centerY + offsetY;
			if (srcXf < 0.0f)
			{
				srcXf = 0.0f;
			}
			else if (srcXf > maxX)
			{
				srcXf = maxX;
			}
			if (srcYf < 0.0f)
			{
				srcYf = 0.0f;
			}
			else if (srcYf > maxY)
			{
				srcYf = maxY;
			}
			srcXInt = (u32)srcXf;
			srcYInt = (u32)srcYf;
			if ((srcXInt < width) && (srcYInt < height))
			{
				u32 srcAddr = (srcYInt * stride) + (srcXInt * 3U);
				dst[destAddr] = src[srcAddr];
				dst[destAddr + 1U] = src[srcAddr + 1U];
				dst[destAddr + 2U] = src[srcAddr + 2U];
			}
			destAddr += 3U;
			screenX += invCenterX;
		}
	}
	fx_flush(dst, height, stride);
}

void LiveFxPlane3D(u8 *src, u8 *dst, u32 width, u32 height, u32 stride, int mode)
{
	switch (mode)
	{
	case LIVE_FX_PLANE3D_Z45:
		LiveFxPlane3DRaw(src, dst, width, height, stride, 0.0f, 0.0f, LIVE_FX_PI / 4.0f, 1.0f, 0.0f, 0.0f);
		break;
	case LIVE_FX_PLANE3D_Z90:
		LiveFxPlane3DRaw(src, dst, width, height, stride, 0.0f, 0.0f, LIVE_FX_PI / 2.0f, 1.0f, 0.0f, 0.0f);
		break;
	case LIVE_FX_PLANE3D_X:
		LiveFxPlane3DRaw(src, dst, width, height, stride, LIVE_FX_PI / 3.0f, 0.0f, 0.0f, 0.7f, 0.0f, 0.0f);
		break;
	case LIVE_FX_PLANE3D_Y:
		LiveFxPlane3DRaw(src, dst, width, height, stride, 0.0f, LIVE_FX_PI / 3.0f, 0.0f, 0.7f, 0.0f, 0.0f);
		break;
	case LIVE_FX_PLANE3D_XYZ:
		LiveFxPlane3DRaw(src, dst, width, height, stride, LIVE_FX_PI / 4.0f, LIVE_FX_PI / 4.0f, LIVE_FX_PI / 4.0f, 0.7f, 0.0f, 0.0f);
		break;
	case LIVE_FX_PLANE3D_SCALE:
		LiveFxPlane3DRaw(src, dst, width, height, stride, 0.0f, 0.0f, LIVE_FX_PI / 6.0f, 1.5f, 0.0f, 0.0f);
		break;
	default:
		LiveFxCopy(src, dst, width, height, stride, stride);
		break;
	}
}

void LiveFxShrinkRandom(u8 *src, u8 *dst, u32 width, u32 height, u32 stride, int enable)
{
	u32 xcoi;
	u32 ycoi;
	u32 destAddr;
	u32 srcX;
	u32 srcY;
	u32 srcAddr;
	u32 shrunkWidth;
	u32 shrunkHeight;
	u32 maxX;
	u32 maxY;
	u32 posX;
	u32 posY;
	u32 randX;
	u32 randY;
	u32 y;

	if (enable == 0)
	{
		LiveFxCopy(src, dst, width, height, stride, stride);
		return;
	}

	shrunkWidth = (u32)((float)width * 0.75f);
	shrunkHeight = (u32)((float)height * 0.75f);
	g_shrinkSeed = (g_shrinkSeed * 1103515245U) + 12345U;
	randX = g_shrinkSeed;
	g_shrinkSeed = (g_shrinkSeed * 1103515245U) + 12345U;
	randY = g_shrinkSeed;
	maxX = (width > shrunkWidth) ? (width - shrunkWidth) : 0U;
	maxY = (height > shrunkHeight) ? (height - shrunkHeight) : 0U;
	posX = (maxX > 0U) ? (randX % maxX) : 0U;
	posY = (maxY > 0U) ? (randY % maxY) : 0U;

	for (y = 0U; y < height; y++)
	{
		memset(dst + (y * stride), 0, width * 3U);
	}

	for (ycoi = 0U; (ycoi < shrunkHeight) && ((posY + ycoi) < height); ycoi++)
	{
		destAddr = ((posY + ycoi) * stride) + (posX * 3U);
		srcY = (ycoi * height) / shrunkHeight;
		if (srcY >= height)
		{
			srcY = height - 1U;
		}
		for (xcoi = 0U; (xcoi < shrunkWidth) && ((posX + xcoi) < width); xcoi++)
		{
			srcX = (xcoi * width) / shrunkWidth;
			if (srcX >= width)
			{
				srcX = width - 1U;
			}
			srcAddr = (srcY * stride) + (srcX * 3U);
			dst[destAddr] = src[srcAddr];
			dst[destAddr + 1U] = src[srcAddr + 1U];
			dst[destAddr + 2U] = src[srcAddr + 2U];
			destAddr += 3U;
		}
	}
	fx_flush(dst, height, stride);
}

static void fx_blend_half(u8 *dst, u32 dstStride, const u8 *live, const u8 *prev,
	u32 packedStride, u32 halfW, u32 halfH, u32 feedback)
{
	u32 liveAmt = 256U - feedback;
	u32 y;
	u32 n;
	u32 count = halfW * 3U;

	for (y = 0U; y < halfH; y++)
	{
		const u8 *l = live + (y * packedStride);
		const u8 *p = prev + (y * packedStride);
		u8 *d = dst + (y * dstStride);

		for (n = 0U; n < count; n++)
		{
			d[n] = (u8)((((u32)l[n] * liveAmt) + ((u32)p[n] * feedback)) >> 8);
		}
	}
}

int LiveFxStrobe(const u8 *srcHalf, u8 *dest, u32 destStride,
	u32 halfW, u32 halfH, u32 interval)
{
	u32 packed = fx_packed(halfW);

	if (interval == 0U)
	{
		interval = 1U;
	}
	g_frameCount++;
	if ((g_inited == 0) || (g_frameCount >= interval))
	{
		fx_copy_plane(g_delayPlane, packed, srcHalf, packed, halfW, halfH);
		fx_copy_plane(dest, destStride, g_delayPlane, packed, halfW, halfH);
		g_frameCount = 0U;
		g_inited = 1;
		return 1;
	}
	return 0;
}

void LiveFxFeedback(const u8 *srcHalf, u8 *dest, u32 destStride,
	u32 halfW, u32 halfH, u32 mix256)
{
	u32 packed = fx_packed(halfW);

	if (mix256 > 256U)
	{
		mix256 = 256U;
	}
	if (g_inited == 0)
	{
		fx_copy_plane(g_delayPlane, packed, srcHalf, packed, halfW, halfH);
		g_inited = 1;
	}
	fx_blend_half(dest, destStride, srcHalf, g_delayPlane, packed, halfW, halfH, mix256);
	fx_copy_plane(g_delayPlane, packed, dest, destStride, halfW, halfH);
}

void LiveFxFilmStrip(const u8 *src, u8 *dest, u32 width, u32 height, u32 stride,
	u32 tiles)
{
	u32 grid;
	u32 slotCount;
	u32 slot;
	u32 tx;
	u32 ty;
	u32 tileW;
	u32 tileH;
	u32 x0;
	u32 y0;
	u32 x;
	u32 y;
	u32 srcXScale;
	u32 srcYScale;

	if (tiles <= 4U)
	{
		grid = 2U;
	}
	else if (tiles <= 9U)
	{
		grid = 3U;
	}
	else
	{
		grid = LIVE_FX_FILM_GRID_MAX;
	}

	slotCount = grid * grid;
	if ((g_lastFilmTiles != tiles) || (g_inited == 0))
	{
		g_stripWrite = 0U;
		g_lastFilmTiles = tiles;
		g_inited = 1;
	}

	slot = g_stripWrite % slotCount;
	tx = slot % grid;
	ty = slot / grid;
	tileW = width / grid;
	tileH = height / grid;
	if (tx == (grid - 1U))
	{
		tileW = width - (tx * tileW);
	}
	if (ty == (grid - 1U))
	{
		tileH = height - (ty * tileH);
	}
	if ((tileW == 0U) || (tileH == 0U))
	{
		return;
	}

	x0 = tx * (width / grid);
	y0 = ty * (height / grid);
	srcXScale = (width << 16) / tileW;
	srcYScale = (height << 16) / tileH;

	for (y = 0U; y < tileH; y++)
	{
		u32 srcY = (y * srcYScale) >> 16;
		u8 *d = dest + ((y0 + y) * stride) + (x0 * 3U);
		const u8 *srow;

		if (srcY >= height)
		{
			srcY = height - 1U;
		}
		srow = src + (srcY * stride);
		for (x = 0U; x < tileW; x++)
		{
			u32 srcX = (x * srcXScale) >> 16;
			const u8 *s;

			if (srcX >= width)
			{
				srcX = width - 1U;
			}
			s = srow + (srcX * 3U);
			d[0] = s[0];
			d[1] = s[1];
			d[2] = s[2];
			d += 3;
		}
	}

	g_stripWrite = (g_stripWrite + 1U) % slotCount;
	fx_flush(dest, height, stride);
}

int LiveFxShuffle(const u8 *srcHalf, u8 *dest, u32 destStride,
	u32 halfW, u32 halfH, u32 hold)
{
	u32 i;
	u32 packed = fx_packed(halfW);

	if (hold == 0U)
	{
		hold = 1U;
	}
	if (g_inited == 0)
	{
		for (i = 0U; i < LIVE_FX_SHUFFLE_SLOTS; i++)
		{
			fx_copy_plane(g_stripRing[i], packed, srcHalf, packed, halfW, halfH);
		}
		g_stripWrite = 0U;
		g_frameCount = 0U;
		g_inited = 1;
		fx_copy_plane(dest, destStride, g_stripRing[0], packed, halfW, halfH);
		return 1;
	}

	fx_copy_plane(g_stripRing[g_stripWrite], packed, srcHalf, packed, halfW, halfH);
	g_stripWrite = (g_stripWrite + 1U) % LIVE_FX_SHUFFLE_SLOTS;
	g_frameCount++;
	if (g_frameCount >= hold)
	{
		g_fxRng = (g_fxRng * 1664525U) + 1013904223U;
		i = g_fxRng % LIVE_FX_SHUFFLE_SLOTS;
		fx_copy_plane(dest, destStride, g_stripRing[i], packed, halfW, halfH);
		g_frameCount = 0U;
		return 1;
	}
	return 0;
}

void LiveFxDifference(const u8 *srcHalf, u8 *dest, u32 destStride,
	u32 halfW, u32 halfH, int mode)
{
	u32 y;
	u32 n;
	u32 packed = fx_packed(halfW);
	u32 count = halfW * 3U;
	int useXor = ((mode & 1) != 0);
	int vsPrev = (mode >= LIVE_FX_DIFF_ABS_PREV);

	if (g_inited == 0)
	{
		fx_copy_plane(g_delayPlane, packed, srcHalf, packed, halfW, halfH);
		g_inited = 1;
	}
	for (y = 0U; y < halfH; y++)
	{
		const u8 *l = srcHalf + (y * packed);
		const u8 *p = g_delayPlane + (y * packed);
		u8 *d = dest + (y * destStride);

		for (n = 0U; n < count; n++)
		{
			if (useXor != 0)
			{
				d[n] = (u8)(l[n] ^ p[n]);
			}
			else
			{
				int v = (int)l[n] - (int)p[n];
				d[n] = (u8)((v < 0) ? -v : v);
			}
		}
	}
	if (vsPrev != 0)
	{
		fx_copy_plane(g_delayPlane, packed, srcHalf, packed, halfW, halfH);
	}
}

void LiveFxTunnel(const u8 *srcHalf, u8 *dest, u32 destStride,
	u32 halfW, u32 halfH, u32 zoomQ8, u32 mix256)
{
	u32 y;
	u32 x;
	int cx = (int)(halfW / 2U);
	int cy = (int)(halfH / 2U);
	u32 packed = fx_packed(halfW);
	u32 liveAmt;
	u32 fbAmt = mix256;

	if (zoomQ8 == 0U)
	{
		zoomQ8 = 256U;
	}
	if (fbAmt > 256U)
	{
		fbAmt = 256U;
	}
	liveAmt = 256U - fbAmt;
	if (g_inited == 0)
	{
		fx_copy_plane(g_delayPlane, packed, srcHalf, packed, halfW, halfH);
		g_inited = 1;
	}
	for (y = 0U; y < halfH; y++)
	{
		u8 *d = dest + (y * destStride);
		const u8 *l = srcHalf + (y * packed);

		for (x = 0U; x < halfW; x++)
		{
			int sx = (((((int)x - cx) * (int)zoomQ8) >> 8) + cx);
			int sy = (((((int)y - cy) * (int)zoomQ8) >> 8) + cy);
			u8 fb0 = 0U;
			u8 fb1 = 0U;
			u8 fb2 = 0U;

			if ((sx >= 0) && (sy >= 0) && ((u32)sx < halfW) && ((u32)sy < halfH))
			{
				const u8 *fb = g_delayPlane + ((u32)sy * packed) + ((u32)sx * 3U);
				fb0 = fb[0];
				fb1 = fb[1];
				fb2 = fb[2];
			}
			d[0] = (u8)((((u32)l[0] * liveAmt) + ((u32)fb0 * fbAmt)) >> 8);
			d[1] = (u8)((((u32)l[1] * liveAmt) + ((u32)fb1 * fbAmt)) >> 8);
			d[2] = (u8)((((u32)l[2] * liveAmt) + ((u32)fb2 * fbAmt)) >> 8);
			d += 3;
			l += 3;
		}
	}
	fx_copy_plane(g_delayPlane, packed, dest, destStride, halfW, halfH);
}

void LiveFxSlitScan(const u8 *src, u8 *dest, u32 width, u32 height, u32 stride,
	int mode, u32 chunk)
{
	u32 maxSlots;
	u32 slot;
	u32 copyW;
	u32 copyH;
	u32 y;
	u32 row;
	u32 srcY0;

	if ((chunk == 0U) || (mode == LIVE_FX_SLIT_OFF))
	{
		return;
	}
	if (g_lastSlitChunk != chunk)
	{
		g_slitIndex = 0U;
		g_lastSlitChunk = chunk;
	}

	if (mode == LIVE_FX_SLIT_COLUMNS)
	{
		maxSlots = (width + chunk - 1U) / chunk;
		if (g_slitIndex >= maxSlots)
		{
			g_slitIndex = 0U;
		}
		slot = g_slitIndex * chunk;
		copyW = chunk;
		if ((slot + copyW) > width)
		{
			copyW = width - slot;
		}
		for (y = 0U; y < height; y++)
		{
			memcpy(dest + (y * stride) + (slot * 3U),
				src + (y * stride) + (slot * 3U),
				copyW * 3U);
		}
		g_slitIndex++;
	}
	else if (mode == LIVE_FX_SLIT_ROWS)
	{
		maxSlots = (height + chunk - 1U) / chunk;
		if (g_slitIndex >= maxSlots)
		{
			g_slitIndex = 0U;
		}
		slot = g_slitIndex * chunk;
		copyH = chunk;
		if ((slot + copyH) > height)
		{
			copyH = height - slot;
		}
		for (y = 0U; y < copyH; y++)
		{
			memcpy(dest + ((slot + y) * stride),
				src + ((slot + y) * stride),
				width * 3U);
		}
		g_slitIndex++;
	}
	else if (mode == LIVE_FX_SLIT_CENTER)
	{
		srcY0 = (height > chunk) ? ((height - chunk) / 2U) : 0U;
		for (slot = 0U; slot < height; slot += chunk)
		{
			copyH = chunk;
			if ((slot + copyH) > height)
			{
				copyH = height - slot;
			}
			for (row = 0U; row < copyH; row++)
			{
				memcpy(dest + ((slot + row) * stride),
					src + ((srcY0 + row) * stride),
					width * 3U);
			}
		}
	}
	fx_flush(dest, height, stride);
}

void LiveFxSpeckle(const u8 *src, u8 *dest, u32 width, u32 height, u32 stride,
	u32 percent)
{
	u32 thresh;
	u32 y;
	u32 x;
	u32 rng = g_speckleRng;

	if (percent > 100U)
	{
		percent = 100U;
	}
	thresh = (percent * 256U) / 100U;
	if (thresh > 256U)
	{
		thresh = 256U;
	}
	for (y = 0U; y < height; y++)
	{
		const u8 *s = src + (y * stride);
		u8 *d = dest + (y * stride);

		for (x = 0U; x < width; x++)
		{
			rng = (rng * 1664525U) + 1013904223U;
			if ((rng >> 24) < thresh)
			{
				d[0] = s[0];
				d[1] = s[1];
				d[2] = s[2];
			}
			s += 3;
			d += 3;
		}
	}
	g_speckleRng = rng;
	fx_flush(dest, height, stride);
}

void LiveFxRandomTiles(const u8 *src, u8 *dest, u32 width, u32 height, u32 stride,
	u32 tileSize)
{
	u32 tile = tileSize;
	u32 thresh = (30U * 256U) / 100U;
	u32 tx;
	u32 ty;
	u32 y;
	u32 rng = g_fxRng;

	if (tile == 0U)
	{
		return;
	}
	for (ty = 0U; ty < height; ty += tile)
	{
		u32 copyH = tile;
		if ((ty + copyH) > height)
		{
			copyH = height - ty;
		}
		for (tx = 0U; tx < width; tx += tile)
		{
			u32 copyW;

			rng = (rng * 1664525U) + 1013904223U;
			if ((rng >> 24) >= thresh)
			{
				continue;
			}
			copyW = tile;
			if ((tx + copyW) > width)
			{
				copyW = width - tx;
			}
			for (y = 0U; y < copyH; y++)
			{
				memcpy(dest + ((ty + y) * stride) + (tx * 3U),
					src + ((ty + y) * stride) + (tx * 3U),
					copyW * 3U);
			}
		}
	}
	g_fxRng = rng;
	fx_flush(dest, height, stride);
}

void LiveFxPixelDoubleInPlace(u8 *frame, u32 halfW, u32 halfH, u32 stride)
{
	int y;
	int x;

	for (y = (int)halfH - 1; y >= 0; y--)
	{
		u8 *srcRow = frame + ((u32)y * stride);
		u8 *dstRow = frame + ((u32)y * 2U * stride);

		for (x = (int)halfW - 1; x >= 0; x--)
		{
			u8 *s = srcRow + ((u32)x * 3U);
			u8 *d = dstRow + ((u32)x * 6U);

			d[0] = s[0];
			d[1] = s[1];
			d[2] = s[2];
			d[3] = s[0];
			d[4] = s[1];
			d[5] = s[2];
		}
		memcpy(dstRow + stride, dstRow, halfW * 6U);
	}
}
