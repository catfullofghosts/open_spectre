#ifndef LIVE_VIDEO_FX_H_
#define LIVE_VIDEO_FX_H_

#include "xil_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Parameterized live video effects. Menu keys stay in video_demo.c and
 * call these with the matching mode / size argument.
 */

/* Mirror: 0=off, 1=H, 2=V, 3=both, 4=center X, 5=center Y, 6=center XY */
#define LIVE_FX_MIRROR_OFF       0
#define LIVE_FX_MIRROR_H         1
#define LIVE_FX_MIRROR_V         2
#define LIVE_FX_MIRROR_BOTH      3
#define LIVE_FX_MIRROR_CENTER_X  4
#define LIVE_FX_MIRROR_CENTER_Y  5
#define LIVE_FX_MIRROR_CENTER_XY 6

/* Tile: 0=off, 1=2x2, 2=4x4, 3=3x3, 4=8x8, 5=16x16 */
#define LIVE_FX_TILE_OFF    0
#define LIVE_FX_TILE_2X2    1
#define LIVE_FX_TILE_4X4    2
#define LIVE_FX_TILE_3X3    3
#define LIVE_FX_TILE_8X8    4
#define LIVE_FX_TILE_16X16  5

/* Zoom: 0=off, 1=2x in, 2=0.5x out */
#define LIVE_FX_ZOOM_OFF  0
#define LIVE_FX_ZOOM_IN   1
#define LIVE_FX_ZOOM_OUT  2

/* Mosaic: 0=off, 1=8px, 2=16px, 3=32px */
#define LIVE_FX_MOSAIC_OFF  0
#define LIVE_FX_MOSAIC_8    1
#define LIVE_FX_MOSAIC_16   2
#define LIVE_FX_MOSAIC_32   3

/* 3D presets: 0=off, 1..6 match menu F..K */
#define LIVE_FX_PLANE3D_OFF     0
#define LIVE_FX_PLANE3D_Z45     1
#define LIVE_FX_PLANE3D_Z90     2
#define LIVE_FX_PLANE3D_X       3
#define LIVE_FX_PLANE3D_Y       4
#define LIVE_FX_PLANE3D_XYZ     5
#define LIVE_FX_PLANE3D_SCALE   6

/* Slit: 0=off, 1=columns, 2=rows, 3=center band tiled vertically */
#define LIVE_FX_SLIT_OFF     0
#define LIVE_FX_SLIT_COLUMNS 1
#define LIVE_FX_SLIT_ROWS    2
#define LIVE_FX_SLIT_CENTER  3

/* Difference: 0=abs/freeze, 1=xor/freeze, 2=abs/prev, 3=xor/prev */
#define LIVE_FX_DIFF_ABS_FREEZE 0
#define LIVE_FX_DIFF_XOR_FREEZE 1
#define LIVE_FX_DIFF_ABS_PREV   2
#define LIVE_FX_DIFF_XOR_PREV   3

void LiveFxReset(void);

void LiveFxCopy(const u8 *src, u8 *dst, u32 width, u32 height, u32 srcStride, u32 dstStride);
void LiveFxMirror(u8 *src, u8 *dst, u32 width, u32 height, u32 stride, int mode);
void LiveFxTile(u8 *src, u8 *dst, u32 width, u32 height, u32 stride, int mode);
void LiveFxZoom(u8 *src, u8 *dst, u32 width, u32 height, u32 stride, int mode);
void LiveFxMosaic(u8 *src, u8 *dst, u32 width, u32 height, u32 stride, int mode);
void LiveFxPlane3D(u8 *src, u8 *dst, u32 width, u32 height, u32 stride, int mode);
void LiveFxPlane3DRaw(u8 *src, u8 *dst, u32 width, u32 height, u32 stride,
	float rotX, float rotY, float rotZ, float scale, float offsetX, float offsetY);
void LiveFxShrinkRandom(u8 *src, u8 *dst, u32 width, u32 height, u32 stride, int enable);

/* Time / DDR effects. srcHalf is packed RGB (stride = halfW*3). dest uses destStride.
 * Strobe / shuffle return 1 when dest was written this frame. */
int LiveFxStrobe(const u8 *srcHalf, u8 *dest, u32 destStride,
	u32 halfW, u32 halfH, u32 interval);
void LiveFxFeedback(const u8 *srcHalf, u8 *dest, u32 destStride,
	u32 halfW, u32 halfH, u32 mix256);
void LiveFxFilmStrip(const u8 *src, u8 *dest, u32 width, u32 height, u32 stride,
	u32 tiles);
int LiveFxShuffle(const u8 *srcHalf, u8 *dest, u32 destStride,
	u32 halfW, u32 halfH, u32 hold);
void LiveFxDifference(const u8 *srcHalf, u8 *dest, u32 destStride,
	u32 halfW, u32 halfH, int mode);
void LiveFxTunnel(const u8 *srcHalf, u8 *dest, u32 destStride,
	u32 halfW, u32 halfH, u32 zoomQ8, u32 mix256);
void LiveFxSlitScan(const u8 *src, u8 *dest, u32 width, u32 height, u32 stride,
	int mode, u32 chunk);
void LiveFxSpeckle(const u8 *src, u8 *dest, u32 width, u32 height, u32 stride,
	u32 percent);
void LiveFxRandomTiles(const u8 *src, u8 *dest, u32 width, u32 height, u32 stride,
	u32 tileSize);

void LiveFxPixelDoubleInPlace(u8 *frame, u32 halfW, u32 halfH, u32 stride);

#ifdef __cplusplus
}
#endif

#endif /* LIVE_VIDEO_FX_H_ */
