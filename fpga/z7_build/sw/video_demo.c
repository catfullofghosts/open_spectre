/************************************************************************/
/*																		*/
/*	video_demo.c	--	ZYBO Video demonstration 						*/
/*																		*/
/************************************************************************/
/*	Author: Sam Bobrowicz												*/
/*	Copyright 2015, Digilent Inc.										*/
/************************************************************************/
/*  Module Description: 												*/
/*																		*/
/*		This file contains code for running a demonstration of the		*/
/*		Video input and output capabilities on the ZYBO. It is a good	*/
/*		example of how to properly use the display_ctrl and				*/
/*		video_capture drivers.											*/
/*																		*/
/*																		*/
/************************************************************************/
/*  Revision History:													*/
/* 																		*/
/*		11/25/2015(SamB): Created										*/
/*																		*/
/************************************************************************/

/* ------------------------------------------------------------ */
/*				Include File Definitions						*/
/* ------------------------------------------------------------ */

#include "video_demo.h"
#include "video_capture/video_capture.h"
#include "display_ctrl/display_ctrl.h"
#include "intc/intc.h"
#include <stdio.h>
#include "xuartps.h"
#include "math.h"
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include "xil_types.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "timer_ps/timer_ps.h"
#include "xparameters.h"
#include "midi_uart/midi_uart.h"
#include "splash.h"
#include "live_video_fx.h"

/* ------------------------------------------------------------ */
/*				Math Function Approximations					*/
/* ------------------------------------------------------------ */
/*
 * Simple math function implementations for embedded systems
 * These avoid linking the math library
 */

/*
 * Trig LUT and fixed-point helpers.
 * Phase format: 32-bit unsigned where 2^32 == 2*PI radians.
 */
#define SIN_LUT_BITS 10U
#define SIN_LUT_SIZE (1U << SIN_LUT_BITS)
#define SIN_LUT_MASK (SIN_LUT_SIZE - 1U)
#define SIN_LUT_FRAC_BITS (32U - SIN_LUT_BITS)
#define SIN_LUT_FRAC_MASK ((1U << SIN_LUT_FRAC_BITS) - 1U)
#define PHASE_PI_2 0x40000000U
#define PHASE_PER_RAD 683565280.0f

static float g_sinLut[SIN_LUT_SIZE + 1U];
static int g_sinLutInit = 0;

/* Polynomial sine approximation used only during LUT generation. */
static float fast_sin_poly(float x)
{
	const float PI = 3.14159265359f;
	const float TWO_PI = 6.28318530718f;
	float x2, x3, x5, x7;

	while (x < 0.0f) x += TWO_PI;
	while (x >= TWO_PI) x -= TWO_PI;

	x2 = x * x;
	x3 = x2 * x;
	x5 = x3 * x2;
	x7 = x5 * x2;

	return x - (x3 / 6.0f) + (x5 / 120.0f) - (x7 / 5040.0f);
}

static void InitSinLut(void)
{
	u32 i;
	const float twoPiOverN = 6.28318530718f / (float)SIN_LUT_SIZE;
	if (g_sinLutInit)
	{
		return;
	}
	for (i = 0U; i < SIN_LUT_SIZE; i++)
	{
		g_sinLut[i] = fast_sin_poly(twoPiOverN * (float)i);
	}
	g_sinLut[SIN_LUT_SIZE] = g_sinLut[0];
	g_sinLutInit = 1;
}

static u32 rad_to_phase(float radians)
{
	return (u32)(radians * PHASE_PER_RAD);
}

static float fast_sin_phase(u32 phase)
{
	u32 idx;
	u32 fracRaw;
	float frac;
	float a;
	float b;

	if (!g_sinLutInit)
	{
		InitSinLut();
	}

	idx = phase >> SIN_LUT_FRAC_BITS;
	fracRaw = phase & SIN_LUT_FRAC_MASK;
	frac = (float)fracRaw * (1.0f / (float)(1U << SIN_LUT_FRAC_BITS));
	a = g_sinLut[idx & SIN_LUT_MASK];
	b = g_sinLut[(idx + 1U) & SIN_LUT_MASK];
	return a + (b - a) * frac;
}

/* Fast sine via LUT + linear interpolation. */
static float fast_sin(float x)
{
	return fast_sin_phase(rad_to_phase(x));
}

/* Fast cosine via quarter-phase offset. */
static float fast_cos(float x)
{
	return fast_sin_phase(rad_to_phase(x) + PHASE_PI_2);
}

/*
 * Fast square root approximation.
 * Uses inverse-sqrt bit hack + one Newton refinement:
 *   sqrt(x) ~= x * inv_sqrt(x)
 * This is significantly cheaper than iterative divide-based Newton sqrt
 * and is good enough for visual pattern generation.
 */
static float fast_sqrt(float x)
{
	union
	{
		float f;
		u32 i;
	} conv;
	float xHalf;
	float invSqrt;

	if (x <= 0.0f)
	{
		return 0.0f;
	}

	xHalf = 0.5f * x;
	conv.f = x;
	conv.i = 0x5f3759dfU - (conv.i >> 1); /* Initial invsqrt approximation */
	invSqrt = conv.f;

	/* One Newton-Raphson step for inverse sqrt. */
	invSqrt = invSqrt * (1.5f - xHalf * invSqrt * invSqrt);

	return x * invSqrt;
}

/* Fast atan2 approximation */
static float fast_atan2(float y, float x)
{
	const float PI = 3.14159265359f;
	
	if (x == 0.0f)
	{
		if (y > 0.0f) return PI / 2.0f;
		if (y < 0.0f) return -PI / 2.0f;
		return 0.0f;
	}
	
	float atan = y / x;
	
	// First order approximation: atan(x) ≈ x for small x, use polynomial for larger
	if (atan < -1.0f || atan > 1.0f)
	{
		// Use identity: atan(x) = PI/2 - atan(1/x) for |x| > 1
		float inv = 1.0f / atan;
		atan = (PI / 2.0f) - (inv - (inv * inv * inv) / 3.0f);
	}
	else
	{
		// Taylor series: atan(x) ≈ x - x³/3 + x⁵/5
		float x2 = atan * atan;
		float x3 = x2 * atan;
		float x5 = x3 * x2;
		atan = atan - (x3 / 3.0f) + (x5 / 5.0f);
	}
	
	// Adjust for quadrant
	if (x < 0.0f)
	{
		if (y >= 0.0f) atan += PI;
		else atan -= PI;
	}
	
	return atan;
}

/* Fast floor - simple truncation for positive numbers */
static float fast_floor(float x)
{
	if (x >= 0.0f)
	{
		return (float)((int)x);
	}
	else
	{
		// For negative numbers, truncate towards negative infinity
		float truncated = (float)((int)x);
		if (truncated != x) truncated -= 1.0f;
		return truncated;
	}
}

/* Fast log2 approximation using bit manipulation and polynomial */
static float fast_log2(float x)
{
	if (x <= 0.0f) return 0.0f;
	if (x == 1.0f) return 0.0f;
	
	// For values > 1, use integer part + fractional approximation
	// For values < 1, handle separately
	if (x < 1.0f)
	{
		// For small values, use polynomial approximation
		float y = x - 1.0f;
		return y * (1.442695f - y * (0.721347f - y * 0.480898f));
	}
	
	// Extract integer part using bit manipulation (rough approximation)
	// For embedded, use a simpler polynomial approximation
	// log2(x) ≈ (x-1) - (x-1)²/2 + (x-1)³/3 for x near 1
	// For larger x, normalize to [1,2] range
	float normalized = x;
	int shift = 0;
	
	// Normalize to [1, 2) range
	while (normalized >= 2.0f)
	{
		normalized *= 0.5f;
		shift++;
	}
	while (normalized < 1.0f)
	{
		normalized *= 2.0f;
		shift--;
	}
	
	// Polynomial approximation for log2 in [1, 2)
	float y = normalized - 1.0f;
	float log2_approx = y * (1.442695f - y * (0.721347f - y * 0.480898f));
	
	return (float)shift + log2_approx;
}

/*
 * XPAR redefines
 */
#define DYNCLK_BASEADDR XPAR_AXI_DYNCLK_0_BASEADDR
#define VGA_VDMA_ID XPAR_AXI_VDMA_0_BASEADDR
#define DISP_VTC_ID XPAR_XVTC_0_BASEADDR
#define VID_VTC_ID XPAR_XVTC_1_BASEADDR
#define VID_GPIO_ID XPAR_AXI_GPIO_VIDEO_BASEADDR
#if defined(XPAR_FABRIC_V_TC_1_INTR)
#define VID_VTC_IRPT_ID XPAR_FABRIC_V_TC_1_INTR
#elif defined(XPAR_FABRIC_XVTC_1_INTR)
#define VID_VTC_IRPT_ID XPAR_FABRIC_XVTC_1_INTR
#else
#define VID_VTC_IRPT_ID XPAR_FABRIC_V_TC_0_INTR
#endif
#define VID_GPIO_IRPT_ID XPAR_FABRIC_AXI_GPIO_VIDEO_INTR
#define SCU_TIMER_ID XPAR_SCUTIMER_BASEADDR
#define UART_BASEADDR XPAR_XUARTPS_0_BASEADDR

#if defined(XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR)
#define REGS_BRAM_BASEADDR XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR
#elif defined(XPAR_AXI_BRAM_CTRL_0_BASEADDR)
#define REGS_BRAM_BASEADDR XPAR_AXI_BRAM_CTRL_0_BASEADDR
#else
#error "Overlay test requires AXI BRAM controller base address macro"
#endif

#define OVERLAY_BRAM_BYTE_BASE        0x00000400U
#define OVERLAY_BRAM_WORDS            2048U
#define OVERLAY_REG_GLOBAL_ENABLE     0x000000FCU
#define OVERLAY_REG_SPRITE_BASE       0x00000100U
#define OVERLAY_REG_SPRITE_STRIDE     0x00000010U
#define VIDEO_CTRL_REG_OFFSET         0x00000078U
#define VIDEO_CTRL_SYNC_INV_BIT       6U
#define VIDEO_CTRL_EXT_MUX_BIT        3U
#define FRAME_STATS_LUMA_OFFSET       0x00000180U
#define FRAME_STATS_R_OFFSET          0x00000184U
#define FRAME_STATS_G_OFFSET          0x00000188U
#define FRAME_STATS_B_OFFSET          0x0000018CU
#define FRAME_STATS_HASH_OFFSET       0x00000190U
#define FRAME_STATS_PIX_OFFSET        0x00000194U

/* ------------------------------------------------------------ */
/*				Global Variables								*/
/* ------------------------------------------------------------ */

/*
 * Display and Video Driver structs
 */
DisplayCtrl dispCtrl;
XAxiVdma vdma;
VideoCapture videoCapt;
INTC intc;
char fRefresh; //flag used to trigger a refresh of the Menu on video detect

static u32 g_overlayRandState = 0xC0DEC0DEU;

static u32 DemoNextRandom(void);
static void DemoOverlayWriteReg(u32 regOffset, u32 value);
static u32 DemoOverlayReadReg(u32 regOffset);
static void DemoOverlayWriteWord(u32 wordAddr, u32 value);
static u32 DemoOverlayReadWord(u32 wordAddr);
static void DemoOverlaySetSprite(u32 spriteIdx, u32 enable, u32 x, u32 y, u32 width, u32 height, u32 baseWord);
static void DemoOverlayDisableAllSprites(void);
static void DemoOverlayPatternTest(void);
static void DemoSpriteRandomTest(u32 displayWidth, u32 displayHeight, u32 activeStartX, u32 activeStartY);
static void DemoSetSyncPolarityInvert(u32 enableInvert);
static char g_liveEffectCmd = 0;
static int g_liveEffectClear = 1;
static int g_liveEffectNeedClear = 0;
static void DemoInvalidateVideoSrc(u8 *frame, u32 height);
static int DemoApplySelectedEffect(char cmd, u8 *src, u8 *dst, u32 width, u32 height, int clearFrame);
static int DemoApplyLiveEffectFrame(void);
static int DemoApplyDdrEffect(u8 *dest, int destIdx, u32 halfW, u32 halfH, u32 fullHeight);
static int DemoApplySlitEffect(const u8 *src, u32 width, u32 height);
static int DemoApplySpeckleEffect(const u8 *src, u32 width, u32 height);
static int DemoApplyRandomTileEffect(const u8 *src, u32 width, u32 height);
static int DemoApplyFilmStripEffect(const u8 *src, u32 width, u32 height);

/*
 * Framebuffers for video data
 */
u8 frameBuf[DISPLAY_NUM_FRAMES][DEMO_MAX_FRAME] __attribute__((aligned(0x20)));
u8 *pFrames[DISPLAY_NUM_FRAMES]; //array of pointers to the frame buffers
static u8 g_halfSrc[DEMO_MAX_FRAME / 2U] __attribute__((aligned(0x20)));
static u8 g_delayPlane[DEMO_MAX_FRAME / 2U] __attribute__((aligned(0x20)));
static u32 g_strobeInterval = 4U;
static u32 g_feedbackAmt = 160U;
static u32 g_filmTiles = 4U;
static int g_ddrInited = 0;
static u32 g_slitChunk = 20U;
static int g_slitDestIdx = 0;
static u32 g_specklePct = 30U;
static u32 g_tileSize = 16U;
static u32 g_shuffleHold = 1U;
static u32 g_diffMode = 0U;
static u32 g_tunnelZoomQ8 = 269U;
static u32 g_tunnelMix = 200U;

/*
 * Interrupt vector table
 */
const ivt_t ivt[] = {
	videoGpioIvt(VID_GPIO_IRPT_ID, &videoCapt),
	videoVtcIvt(VID_VTC_IRPT_ID, &(videoCapt.vtc))
};


/* ------------------------------------------------------------ */
/*				Procedure Definitions							*/
/* ------------------------------------------------------------ */

int main(void)
{
	DemoInitialize();

	DemoRun();

	return 0;
}


void DemoInitialize()
{
	int Status;
	XAxiVdma_Config *vdmaConfig;
	int i;

	/*
	 * Initialize an array of pointers to the 3 frame buffers
	 */
	for (i = 0; i < DISPLAY_NUM_FRAMES; i++)
	{
		pFrames[i] = frameBuf[i];
	}

	/*
	 * Initialize a timer used for a simple delay
	 */
	TimerInitialize(SCU_TIMER_ID);

	/*
	 * Initialize VDMA driver
	 */
	vdmaConfig = XAxiVdma_LookupConfig(VGA_VDMA_ID);
	if (!vdmaConfig)
	{
		xil_printf("No video DMA found for ID %d\r\n", VGA_VDMA_ID);
		return;
	}
	Status = XAxiVdma_CfgInitialize(&vdma, vdmaConfig, vdmaConfig->BaseAddress);
	if (Status != XST_SUCCESS)
	{
		xil_printf("VDMA Configuration Initialization failed %d\r\n", Status);
		return;
	}

	/*
	 * Initialize the Display controller and start it
	 */
	Status = DisplayInitialize(&dispCtrl, &vdma, DISP_VTC_ID, DYNCLK_BASEADDR, pFrames, DEMO_STRIDE);
	if (Status != XST_SUCCESS)
	{
		xil_printf("Display Ctrl initialization failed during demo initialization%d\r\n", Status);
		return;
	}
	for (i = 0; i < DISPLAY_NUM_FRAMES; i++)
	{
		DemoBlitSplash(pFrames[i], dispCtrl.vMode.width, dispCtrl.vMode.height, dispCtrl.stride);
	}
	xil_printf("Startup splash %ux%u 1-bit, centred\r\n",
		(unsigned)SPLASH_WIDTH, (unsigned)SPLASH_HEIGHT);
	Status = DisplayStart(&dispCtrl);
	if (Status != XST_SUCCESS)
	{
		xil_printf("Couldn't start display during demo initialization%d\r\n", Status);
		return;
	}
	/* 720p is positive sync. invert=0 keeps idle-low so digital X/Y counters run. */
	DemoSetSyncPolarityInvert(0U);

	/*
	 * Initialize the Interrupt controller and start it.
	 */
	Status = fnInitInterruptController(&intc);
	if(Status != XST_SUCCESS) {
		xil_printf("Error initializing interrupts");
		return;
	}
	fnEnableInterrupts(&intc, &ivt[0], sizeof(ivt)/sizeof(ivt[0]));

	/*
	 * Initialize the Video Capture device
	 */
	Status = VideoInitialize(&videoCapt, &intc, &vdma, VID_GPIO_ID, VID_VTC_ID, VID_VTC_IRPT_ID, pFrames, DEMO_STRIDE, DEMO_START_ON_DET);
	if (Status != XST_SUCCESS)
	{
		xil_printf("Video Ctrl initialization failed during demo initialization%d\r\n", Status);
		return;
	}

	/*
	 * Set the Video Detect callback to trigger the menu to reset, displaying the new detected resolution
	 */
	VideoSetCallback(&videoCapt, DemoISR, &fRefresh);

	Status = MidiUartInit();
	if (Status != XST_SUCCESS)
	{
		xil_printf("MIDI UART1 init failed %d (Pico PMOD link)\r\n", Status);
	}
	else
	{
		xil_printf("MIDI UART1 ready @ %u baud\r\n", (unsigned)MIDI_UART_BAUD);
	}

	return;
}

void DemoRun()
{
	int nextFrame = 0;
	char userInput = 0;

	/* Flush UART FIFO */
	while (XUartPs_IsReceiveData(UART_BASEADDR))
	{
		XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
	}

	while (userInput != 'q')
	{
		fRefresh = 0;
		DemoPrintMenu();

		/* Wait for data on UART */
		while (!XUartPs_IsReceiveData(UART_BASEADDR) && !fRefresh)
		{
			MidiUartPoll();
			(void)DemoApplyLiveEffectFrame();
			/* Recover after unplug/replug without entering V. Do not
			 * touch VTC while pLocked is low (AXI hang). */
			if ((XGpio_DiscreteRead(&videoCapt.gpio, LOCKED_CHANNEL) & LOCKED_MASK) != 0U)
			{
				if ((videoCapt.state == VIDEO_DISCONNECTED) || (videoCapt.detStarted == 0U))
				{
					if (VideoDetectLocked(&videoCapt) == XST_SUCCESS)
					{
						if ((videoCapt.state == VIDEO_STREAMING) && (g_liveEffectCmd == 0))
						{
							DisplayChangeFrame(&dispCtrl, videoCapt.curFrame);
						}
						fRefresh = 1;
					}
				}
			}
		}

		/* Store the first character in the UART receive FIFO and echo it */
		if (XUartPs_IsReceiveData(UART_BASEADDR))
		{
			char rxChar;
			userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);

			/* Ignore trailing CR/LF characters that some terminals append. */
			while (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				rxChar = (char)XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				if (rxChar != '\r' && rxChar != '\n')
				{
					userInput = rxChar;
				}
			}

			if (userInput != '\r' && userInput != '\n')
			{
				xil_printf("%c", userInput);
			}
			else
			{
				/* Treat naked CR/LF as "refresh menu", not an invalid command. */
				userInput = 'r';
			}
		}
		else  //Refresh triggered by video detect interrupt
		{
			userInput = 'r';
		}

		switch (userInput)
		{
		case '1':
			DemoChangeRes();
			break;
		case '2':
			nextFrame = dispCtrl.curFrame + 1;
			if (nextFrame >= DISPLAY_NUM_FRAMES)
			{
				nextFrame = 0;
			}
			DisplayChangeFrame(&dispCtrl, nextFrame);
			if ((videoCapt.state == VIDEO_STREAMING) && (dispCtrl.curFrame == videoCapt.curFrame))
			{
				xil_printf("\n\rDisplay frame %d (live HDMI-in)\n\r", dispCtrl.curFrame);
			}
			else
			{
				xil_printf("\n\rDisplay frame %d (static buffer, not live HDMI-in)\n\r", dispCtrl.curFrame);
			}
			break;
		case '3':
			DemoPrintTest(pFrames[dispCtrl.curFrame], dispCtrl.vMode.width, dispCtrl.vMode.height, DEMO_STRIDE, DEMO_PATTERN_0);
			break;
		case '4':
			DemoPrintTest(pFrames[dispCtrl.curFrame], dispCtrl.vMode.width, dispCtrl.vMode.height, DEMO_STRIDE, DEMO_PATTERN_1);
			break;
		case '0':
			DemoPrintTest(pFrames[dispCtrl.curFrame], dispCtrl.vMode.width, dispCtrl.vMode.height, DEMO_STRIDE, DEMO_PATTERN_GRID);
			break;
		case '5':
			if (videoCapt.state != VIDEO_STREAMING)
			{
				if ((XGpio_DiscreteRead(&videoCapt.gpio, LOCKED_CHANNEL) & LOCKED_MASK) != 0U)
				{
					(void)VideoDetectLocked(&videoCapt);
				}
				if (VideoStart(&videoCapt) != XST_SUCCESS)
				{
					xil_printf("\n\rHDMI-in start failed (need lock+timing, use V)\n\r");
					break;
				}
			}
			if (DemoApplyLiveEffectFrame() == 0)
			{
				DisplayChangeFrame(&dispCtrl, videoCapt.curFrame);
			}
			xil_printf("\n\rHDMI-in streaming on display frame %u\n\r",
				(unsigned)dispCtrl.curFrame);
			break;
		case '6':
			nextFrame = videoCapt.curFrame + 1;
			if (nextFrame >= DISPLAY_NUM_FRAMES)
			{
				nextFrame = 0;
			}
			VideoChangeFrame(&videoCapt, nextFrame);
			break;
		case '7':
			nextFrame = videoCapt.curFrame + 1;
			if (nextFrame >= DISPLAY_NUM_FRAMES)
			{
				nextFrame = 0;
			}
			VideoStop(&videoCapt);
			DemoInvertFrame(pFrames[videoCapt.curFrame], pFrames[nextFrame], videoCapt.timing.HActiveVideo, videoCapt.timing.VActiveVideo, DEMO_STRIDE);
			VideoStart(&videoCapt);
			DisplayChangeFrame(&dispCtrl, nextFrame);
			break;
		case '8':
			nextFrame = videoCapt.curFrame + 1;
			if (nextFrame >= DISPLAY_NUM_FRAMES)
			{
				nextFrame = 0;
			}
			VideoStop(&videoCapt);
			DemoScaleFrame(pFrames[videoCapt.curFrame], pFrames[nextFrame], videoCapt.timing.HActiveVideo, videoCapt.timing.VActiveVideo, dispCtrl.vMode.width, dispCtrl.vMode.height, DEMO_STRIDE);
			VideoStart(&videoCapt);
			DisplayChangeFrame(&dispCtrl, nextFrame);
			break;
		case '9':
			DemoPatternMenu();
			break;
		case 'i':
		case 'I':
			DemoEffectMenu();
			break;
		case 'j':
		case 'J':
			DemoOverlayPatternTest();
			break;
		case 'k':
		case 'K':
			DemoSpriteRandomTest(
				dispCtrl.vMode.width,
				dispCtrl.vMode.height,
				dispCtrl.vMode.hmax - dispCtrl.vMode.hpe,
				dispCtrl.vMode.vmax - dispCtrl.vMode.vpe
			);
			break;
		case 'm':
		case 'M':
			DemoMidiUartMonitor();
			break;
		case 'v':
		case 'V':
			DemoVideoInMonitor();
			break;
		case 'q':
			break;
		case 'r':
			break;
		default :
			xil_printf("\n\rInvalid Selection");
			TimerDelay(500000);
		}
	}

	return;
}

void DemoPrintMenu()
{
	xil_printf("\x1B[H"); //Set cursor to top left of terminal
	xil_printf("\x1B[2J"); //Clear terminal
	xil_printf("**************************************************\n\r");
	xil_printf("*                Arty Z7 HDMI In Demo            *\n\r");
	xil_printf("**************************************************\n\r");
	xil_printf("*Display Resolution: %28s*\n\r", dispCtrl.vMode.label);
	xil_printf("*Display Pixel Clock Freq. (MHz): %11d.%03d*\n\r", (int)dispCtrl.pxlFreq, (((int)dispCtrl.pxlFreq*1000)%1000));
	xil_printf("*Display Frame Index: %27d*\n\r", dispCtrl.curFrame);
	if (videoCapt.state == VIDEO_DISCONNECTED) xil_printf("*Video Capture Resolution: %22s*\n\r", "!HDMI UNPLUGGED!");
	else xil_printf("*Video Capture Resolution: %17dx%-4d*\n\r", videoCapt.timing.HActiveVideo, videoCapt.timing.VActiveVideo);
	xil_printf("*Video Frame Index: %29d*\n\r", videoCapt.curFrame);
	xil_printf("**************************************************\n\r");
	xil_printf("\n\r");
	xil_printf("1 - Change Display Resolution\n\r");
	xil_printf("2 - Change Display Framebuffer Index (static unless it is the live capture frame)\n\r");
	xil_printf("3 - Print Blended Test Pattern to Display Framebuffer\n\r");
	xil_printf("4 - Print Color Bar Test Pattern to Display Framebuffer\n\r");
	xil_printf("0 - Print Grid Test Pattern (for 3D testing)\n\r");
	xil_printf("5 - Start HDMI-in and show it on the HDMI-out monitor\n\r");
	xil_printf("6 - Change Video Framebuffer Index\n\r");
	xil_printf("7 - Grab Video Frame and invert colors\n\r");
	xil_printf("8 - Grab Video Frame and scale to Display resolution\n\r");
	xil_printf("9 - Animated patterns menu\n\r");
	xil_printf("I - Apply Video Effects Menu\n\r");
	xil_printf("J - Overlay VRAM Pattern Test (with transparency)\n\r");
	xil_printf("K - Sprite VRAM Test (random position)\n\r");
	xil_printf("M - MIDI UART1 raw dump (any byte, q exits)\n\r");
	xil_printf("V - Video in debug (HDMI lock, timing, pixels)\n\r");
	xil_printf("q - Quit\n\r");
	xil_printf("\n\r");
	xil_printf("\n\r");
	xil_printf("Enter a selection:");
}

void DemoMidiUartMonitor()
{
	u8 byte;
	u32 col;
	char userInput;

	while (XUartPs_IsReceiveData(UART_BASEADDR))
	{
		(void)XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
	}

	xil_printf("\x1B[2J\x1B[H");
	xil_printf("MIDI UART1 raw dump @ %u baud (Pico / JB)\r\n", (unsigned)MIDI_UART_BAUD);
	xil_printf("Prints every RX byte. Press q to return.\r\n\r\n");

	col = 0U;
	while (1)
	{
		if (XUartPs_IsReceiveData(UART_BASEADDR))
		{
			userInput = (char)XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			if ((userInput == 'q') || (userInput == 'Q'))
			{
				xil_printf("\r\n");
				return;
			}
		}

		if (MidiUartTryRead(&byte) != 0)
		{
			xil_printf("%02X ", (unsigned)byte);
			col++;
			if (col >= 16U)
			{
				xil_printf("\r\n");
				col = 0U;
			}
		}
	}
}

static void DemoVideoInSampleRgb(u8 *frame, u32 stride, u32 x, u32 y, u8 *r, u8 *b, u8 *g)
{
	u32 off;

	off = (y * stride) + (x * 3U);
	*r = frame[off];
	*b = frame[off + 1U];
	*g = frame[off + 2U];
}

static void DemoVideoInInvPix(u8 *frame, u32 stride, u32 x, u32 y)
{
	Xil_DCacheInvalidateRange((unsigned int)(frame + (y * stride) + (x * 3U)), 32U);
}

void DemoVideoInMonitor()
{
	char userInput;
	const char *stateName;
	u32 locked;
	u32 width;
	u32 height;
	u32 cx;
	u32 cy;
	u8 r;
	u8 g;
	u8 b;
	u8 lastCenterLuma;
	u32 changeCount;
	u32 spin;
	u32 savedStart;
	int detRc;
	int streamRc;
	int leaveMenu;
	int printNow;

	lastCenterLuma = 0U;
	changeCount = 0U;
	leaveMenu = 0;
	printNow = 1;

	while (XUartPs_IsReceiveData(UART_BASEADDR))
	{
		(void)XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
	}

	xil_printf("\r\nVIDEO IN  q=back  s=stream  (plain text, 1 Hz)\r\n");

	/* Do not auto-start VDMA from this page. Incomplete 1280x0 timing
	 * plus startOnDetect can hang the UART loop. */
	savedStart = videoCapt.startOnDetect;
	videoCapt.startOnDetect = 0U;

	while (leaveMenu == 0)
	{
		if (printNow != 0)
		{
			printNow = 0;
			detRc = XST_NO_DATA;
			if ((XGpio_DiscreteRead(&videoCapt.gpio, LOCKED_CHANNEL) & LOCKED_MASK) != 0U)
			{
				detRc = VideoDetectLocked(&videoCapt);
			}

			locked = XGpio_DiscreteRead(&videoCapt.gpio, LOCKED_CHANNEL) & LOCKED_MASK;
			if (videoCapt.state == VIDEO_DISCONNECTED)
			{
				stateName = "UNPLUGGED";
			}
			else if (videoCapt.state == VIDEO_STREAMING)
			{
				stateName = "STREAMING";
			}
			else
			{
				stateName = "PAUSED";
			}

			width = videoCapt.timing.HActiveVideo;
			height = videoCapt.timing.VActiveVideo;
			xil_printf("HDMI=%s %s %ux%u rc=%d size=0x%08X",
				locked ? "YES" : "NO",
				stateName,
				(unsigned)width,
				(unsigned)height,
				detRc,
				locked ? (unsigned)Xil_In32(XPAR_XVTC_1_BASEADDR + 0x20U) : 0U);

			if ((videoCapt.state != VIDEO_DISCONNECTED) && (width > 2U) && (height > 2U))
			{
				cx = width / 2U;
				cy = height / 2U;
				DemoVideoInInvPix(pFrames[videoCapt.curFrame], DEMO_STRIDE, cx, cy);
				DemoVideoInSampleRgb(pFrames[videoCapt.curFrame], DEMO_STRIDE, cx, cy, &r, &b, &g);
				if (((u8)(((u32)r + g + b) / 3U)) != lastCenterLuma)
				{
					changeCount++;
					lastCenterLuma = (u8)(((u32)r + g + b) / 3U);
				}
				xil_printf("  C=%02X%02X%02X chg=%u\r\n", r, b, g, (unsigned)changeCount);
			}
			else
			{
				xil_printf("  (waiting for timing)\r\n");
			}
		}

		for (spin = 0U; spin < 200U; spin++)
		{
			MidiUartPoll();
			if (!XUartPs_IsReceiveData(UART_BASEADDR))
			{
				TimerDelay(5000);
				continue;
			}

			userInput = (char)XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			if ((userInput == '\r') || (userInput == '\n'))
			{
				continue;
			}
			if ((userInput == 'q') || (userInput == 'Q'))
			{
				xil_printf("leaving video in\r\n");
				leaveMenu = 1;
				break;
			}
			if ((userInput == 's') || (userInput == 'S'))
			{
				if (videoCapt.state == VIDEO_STREAMING)
				{
					streamRc = VideoStop(&videoCapt);
					xil_printf("stream stop rc=%d\r\n", streamRc);
				}
				else
				{
					streamRc = VideoStart(&videoCapt);
					if (streamRc == XST_SUCCESS)
					{
						DisplayChangeFrame(&dispCtrl, videoCapt.curFrame);
					}
					xil_printf("stream start rc=%d %ux%u\r\n",
						streamRc,
						(unsigned)videoCapt.timing.HActiveVideo,
						(unsigned)videoCapt.timing.VActiveVideo);
				}
				printNow = 1;
				break;
			}
		}

		if (leaveMenu == 0)
		{
			printNow = 1;
		}
	}

	videoCapt.startOnDetect = savedStart;
}

void DemoChangeRes()
{
	int fResSet = 0;
	int status;
	char userInput = 0;
	u32 waitCount;
	int wasStreaming;
	char rxChar;

	/* Flush UART FIFO */
	while (XUartPs_IsReceiveData(UART_BASEADDR))
	{
		XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
	}

	while (!fResSet)
	{
		DemoCRMenu();

		/*
		 * Wait for data on UART, but never block forever.
		 * If no input arrives for a while, return to main menu.
		 */
		waitCount = 0U;
		while (!XUartPs_IsReceiveData(UART_BASEADDR))
		{
			MidiUartPoll();
			waitCount++;
			if (waitCount > 80000000U)
			{
				xil_printf("\n\rResolution menu timeout, returning to main menu.\n\r");
				return;
			}
		}

		/* Read command and ignore terminal CR/LF noise. */
		userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
		while (XUartPs_IsReceiveData(UART_BASEADDR))
		{
			rxChar = (char)XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			if (rxChar != '\r' && rxChar != '\n')
			{
				userInput = rxChar;
			}
		}
		if (userInput == '\r' || userInput == '\n')
		{
			continue;
		}
		xil_printf("%c", userInput);

		status = XST_SUCCESS;
		wasStreaming = (videoCapt.state == VIDEO_STREAMING);
		switch (userInput)
		{
		case '1':
			if (wasStreaming) VideoStop(&videoCapt);
			status = DisplayStop(&dispCtrl);
			if (status == XST_SUCCESS) status = DisplaySetMode(&dispCtrl, &VMODE_640x480);
			if (status == XST_SUCCESS) status = DisplayStart(&dispCtrl);
			if (status == XST_SUCCESS)
			{
				DemoSetSyncPolarityInvert(1U);
				fResSet = 1;
			}
			if (wasStreaming) VideoStart(&videoCapt);
			break;
		case '2':
			if (wasStreaming) VideoStop(&videoCapt);
			status = DisplayStop(&dispCtrl);
			if (status == XST_SUCCESS) status = DisplaySetMode(&dispCtrl, &VMODE_800x600);
			if (status == XST_SUCCESS) status = DisplayStart(&dispCtrl);
			if (status == XST_SUCCESS)
			{
				DemoSetSyncPolarityInvert(0U);
				fResSet = 1;
			}
			if (wasStreaming) VideoStart(&videoCapt);
			break;
		case '3':
			if (wasStreaming) VideoStop(&videoCapt);
			status = DisplayStop(&dispCtrl);
			if (status == XST_SUCCESS) status = DisplaySetMode(&dispCtrl, &VMODE_1280x720);
			if (status == XST_SUCCESS) status = DisplayStart(&dispCtrl);
			if (status == XST_SUCCESS)
			{
				DemoSetSyncPolarityInvert(0U);
				fResSet = 1;
			}
			if (wasStreaming) VideoStart(&videoCapt);
			break;
		case '4':
			if (wasStreaming) VideoStop(&videoCapt);
			status = DisplayStop(&dispCtrl);
			if (status == XST_SUCCESS) status = DisplaySetMode(&dispCtrl, &VMODE_1280x1024);
			if (status == XST_SUCCESS) status = DisplayStart(&dispCtrl);
			if (status == XST_SUCCESS)
			{
				DemoSetSyncPolarityInvert(0U);
				fResSet = 1;
			}
			if (wasStreaming) VideoStart(&videoCapt);
			break;
		case '5':
			if (wasStreaming) VideoStop(&videoCapt);
			status = DisplayStop(&dispCtrl);
			if (status == XST_SUCCESS) status = DisplaySetMode(&dispCtrl, &VMODE_1920x1080);
			if (status == XST_SUCCESS) status = DisplayStart(&dispCtrl);
			if (status == XST_SUCCESS)
			{
				DemoSetSyncPolarityInvert(0U);
				fResSet = 1;
			}
			if (wasStreaming) VideoStart(&videoCapt);
			break;
		case 'Q':
		case 'q':
			fResSet = 1;
			break;
		default :
			xil_printf("\n\rInvalid Selection");
			TimerDelay(500000);
		}
		if (status == XST_DMA_ERROR)
		{
			xil_printf("\n\rWARNING: AXI VDMA Error detected and cleared\n\r");
		}
		else if (status != XST_SUCCESS)
		{
			xil_printf("\n\rResolution change failed, status=%d\n\r", status);
			TimerDelay(500000);
		}
	}
}

void DemoCRMenu()
{
	xil_printf("\x1B[H"); //Set cursor to top left of terminal
	xil_printf("\x1B[2J"); //Clear terminal
	xil_printf("**************************************************\n\r");
	xil_printf("*                Arty Z7 HDMI In Demo            *\n\r");
	xil_printf("**************************************************\n\r");
	xil_printf("*Current Resolution: %28s*\n\r", dispCtrl.vMode.label);
	xil_printf("*Display Pixel Clock Freq. (MHz): %11d.%03d*\n\r", (int)dispCtrl.pxlFreq, (((int)dispCtrl.pxlFreq*1000)%1000));
	xil_printf("**************************************************\n\r");
	xil_printf("\n\r");
	xil_printf("1 - %s\n\r", VMODE_640x480.label);
	xil_printf("2 - %s\n\r", VMODE_800x600.label);
	xil_printf("3 - %s\n\r", VMODE_1280x720.label);
	xil_printf("4 - %s\n\r", VMODE_1280x1024.label);
	xil_printf("5 - %s\n\r", VMODE_1920x1080.label);
	xil_printf("q - Quit (don't change resolution)\n\r");
	xil_printf("\n\r");
	xil_printf("Select a new resolution:");
}

#define DEMO_IN_DECIM 2U

static void DemoPixelDoubleInPlace(u8 *frame, u32 halfW, u32 halfH, u32 stride);

static int DemoEffectDestFrame(void)
{
	int i;

	/* Write the half-res + 2x result into a buffer the HDMI-out VDMA is
	 * not scanning, then flip. Otherwise the monitor sees 640x360 then 1280x720. */
	for (i = 0; i < DISPLAY_NUM_FRAMES; i++)
	{
		if ((i != (int)videoCapt.curFrame) && (i != (int)dispCtrl.curFrame))
		{
			return i;
		}
	}
	return ((int)videoCapt.curFrame + 1) % DISPLAY_NUM_FRAMES;
}

static u32 DemoPackedStride(u32 width)
{
	return width * 3U;
}

static void DemoDecimateSkip2(const u8 *src, u8 *dst, u32 width, u32 height, u32 srcStride)
{
	u32 x;
	u32 y;
	u32 dw = width / DEMO_IN_DECIM;
	u32 dh = height / DEMO_IN_DECIM;
	u32 dstStride = DemoPackedStride(dw);

	for (y = 0U; y < dh; y++)
	{
		const u8 *s = src + ((y * DEMO_IN_DECIM) * srcStride);
		u8 *d = dst + (y * dstStride);

		for (x = 0U; x < dw; x++)
		{
			d[0] = s[0];
			d[1] = s[1];
			d[2] = s[2];
			d += 3;
			s += (3U * DEMO_IN_DECIM);
		}
	}
}

static int DemoIsDdrEffect(char cmd)
{
	return ((cmd == 'r') || (cmd == 'R') ||
		(cmd == 's') || (cmd == 'S') ||
		(cmd == 'u') || (cmd == 'U') ||
		(cmd == 'w') || (cmd == 'W') ||
		(cmd == 'x') || (cmd == 'X') ||
		(cmd == 'y') || (cmd == 'Y') ||
		(cmd == 'z') || (cmd == 'Z') ||
		(cmd == 'v') || (cmd == 'V') ||
		(cmd == ',') ||
		(cmd == '-') ||
		(cmd == '/'));
}

static int DemoIsSlitEffect(char cmd)
{
	return ((cmd == 'w') || (cmd == 'W') ||
		(cmd == 'x') || (cmd == 'X') ||
		(cmd == 'y') || (cmd == 'Y'));
}

static int DemoIsParkedDdrEffect(char cmd)
{
	return (DemoIsSlitEffect(cmd) ||
		(cmd == 'z') || (cmd == 'Z') ||
		(cmd == 'v') || (cmd == 'V') ||
		(cmd == 'u') || (cmd == 'U'));
}

static void DemoResetDdrEffectState(void)
{
	g_ddrInited = 0;
	g_slitDestIdx = 0;
	memset(g_delayPlane, 0, sizeof(g_delayPlane));
	LiveFxReset();
}

static void DemoCopyPlane(u8 *dst, u32 dstStride, const u8 *src, u32 srcStride, u32 width, u32 height)
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

static void DemoCycleDdrEffectParam(char cmd)
{
	if ((cmd == 'r') || (cmd == 'R'))
	{
		if (g_strobeInterval <= 2U)
		{
			g_strobeInterval = 4U;
		}
		else if (g_strobeInterval <= 4U)
		{
			g_strobeInterval = 8U;
		}
		else if (g_strobeInterval <= 8U)
		{
			g_strobeInterval = 16U;
		}
		else
		{
			g_strobeInterval = 2U;
		}
		xil_printf("\n\rStrobe interval = %u frames\r\n", (unsigned)g_strobeInterval);
	}
	else if ((cmd == 's') || (cmd == 'S'))
	{
		if (g_feedbackAmt <= 64U)
		{
			g_feedbackAmt = 128U;
		}
		else if (g_feedbackAmt <= 128U)
		{
			g_feedbackAmt = 160U;
		}
		else if (g_feedbackAmt <= 160U)
		{
			g_feedbackAmt = 208U;
		}
		else
		{
			g_feedbackAmt = 64U;
		}
		xil_printf("\n\rFeedback mix = %u/256\r\n", (unsigned)g_feedbackAmt);
	}
	else if ((cmd == 'u') || (cmd == 'U'))
	{
		if (g_filmTiles <= 4U)
		{
			g_filmTiles = 9U;
		}
		else if (g_filmTiles <= 9U)
		{
			g_filmTiles = 16U;
		}
		else
		{
			g_filmTiles = 4U;
		}
		g_ddrInited = 0;
		xil_printf("\n\rFilm-strip tiles = %u\r\n", (unsigned)g_filmTiles);
	}
	else if (DemoIsSlitEffect(cmd))
	{
		if (g_slitChunk <= 10U)
		{
			g_slitChunk = 20U;
		}
		else if (g_slitChunk <= 20U)
		{
			g_slitChunk = 40U;
		}
		else
		{
			g_slitChunk = 10U;
		}
		xil_printf("\n\rSlit chunk = %u pixels\r\n", (unsigned)g_slitChunk);
	}
	else if ((cmd == 'z') || (cmd == 'Z'))
	{
		if (g_specklePct <= 15U)
		{
			g_specklePct = 30U;
		}
		else if (g_specklePct <= 30U)
		{
			g_specklePct = 50U;
		}
		else if (g_specklePct <= 50U)
		{
			g_specklePct = 80U;
		}
		else
		{
			g_specklePct = 15U;
		}
		xil_printf("\n\rSpeckle update = %u%%\r\n", (unsigned)g_specklePct);
	}
	else if ((cmd == 'v') || (cmd == 'V'))
	{
		if (g_tileSize <= 8U)
		{
			g_tileSize = 16U;
		}
		else if (g_tileSize <= 16U)
		{
			g_tileSize = 32U;
		}
		else if (g_tileSize <= 32U)
		{
			g_tileSize = 64U;
		}
		else
		{
			g_tileSize = 8U;
		}
		xil_printf("\n\rRandom tile size = %u px\r\n", (unsigned)g_tileSize);
	}
	else if (cmd == ',')
	{
		if (g_shuffleHold <= 1U)
		{
			g_shuffleHold = 3U;
		}
		else if (g_shuffleHold <= 3U)
		{
			g_shuffleHold = 8U;
		}
		else if (g_shuffleHold <= 8U)
		{
			g_shuffleHold = 16U;
		}
		else
		{
			g_shuffleHold = 1U;
		}
		xil_printf("\n\rShuffle hold = %u frames\r\n", (unsigned)g_shuffleHold);
	}
	else if (cmd == '-')
	{
		g_diffMode = (g_diffMode + 1U) & 3U;
		g_ddrInited = 0;
		if (g_diffMode == 0U)
		{
			xil_printf("\n\rDifference = abs vs freeze\r\n");
		}
		else if (g_diffMode == 1U)
		{
			xil_printf("\n\rDifference = XOR vs freeze\r\n");
		}
		else if (g_diffMode == 2U)
		{
			xil_printf("\n\rDifference = abs vs previous\r\n");
		}
		else
		{
			xil_printf("\n\rDifference = XOR vs previous\r\n");
		}
	}
	else if (cmd == '/')
	{
		if (g_tunnelZoomQ8 <= 243U)
		{
			g_tunnelZoomQ8 = 269U;
		}
		else if (g_tunnelZoomQ8 <= 269U)
		{
			g_tunnelZoomQ8 = 284U;
		}
		else if (g_tunnelZoomQ8 <= 284U)
		{
			g_tunnelZoomQ8 = 320U;
		}
		else
		{
			g_tunnelZoomQ8 = 243U;
		}
		xil_printf("\n\rTunnel zoom = %u%%\r\n",
			(unsigned)((256U * 100U) / g_tunnelZoomQ8));
	}
}

static int DemoApplyDdrEffect(u8 *dest, int destIdx, u32 halfW, u32 halfH, u32 fullHeight)
{
	char cmd = g_liveEffectCmd;
	int wrote = 1;

	if ((cmd == 'r') || (cmd == 'R'))
	{
		wrote = LiveFxStrobe(g_halfSrc, dest, DEMO_STRIDE, halfW, halfH, g_strobeInterval);
	}
	else if ((cmd == 's') || (cmd == 'S'))
	{
		LiveFxFeedback(g_halfSrc, dest, DEMO_STRIDE, halfW, halfH, g_feedbackAmt);
	}
	else if (cmd == ',')
	{
		wrote = LiveFxShuffle(g_halfSrc, dest, DEMO_STRIDE, halfW, halfH, g_shuffleHold);
	}
	else if (cmd == '-')
	{
		LiveFxDifference(g_halfSrc, dest, DEMO_STRIDE, halfW, halfH, (int)g_diffMode);
	}
	else if (cmd == '/')
	{
		LiveFxTunnel(g_halfSrc, dest, DEMO_STRIDE, halfW, halfH, g_tunnelZoomQ8, g_tunnelMix);
	}
	else
	{
		return 0;
	}

	if (wrote != 0)
	{
		LiveFxPixelDoubleInPlace(dest, halfW, halfH, DEMO_STRIDE);
		Xil_DCacheFlushRange((unsigned int)dest, fullHeight * DEMO_STRIDE);
		DisplayChangeFrame(&dispCtrl, destIdx);
	}
	return 1;
}

static int DemoApplySlitEffect(const u8 *src, u32 width, u32 height)
{
	u8 *dest;
	u32 chunk;
	char cmd = g_liveEffectCmd;
	int mode;

	chunk = g_slitChunk;
	if (chunk == 0U)
	{
		chunk = 20U;
	}

	if ((g_ddrInited == 0) || (g_slitDestIdx == (int)videoCapt.curFrame))
	{
		g_slitDestIdx = DemoEffectDestFrame();
		memset(pFrames[g_slitDestIdx], 0, height * DEMO_STRIDE);
		Xil_DCacheFlushRange((unsigned int)pFrames[g_slitDestIdx], height * DEMO_STRIDE);
		DisplayChangeFrame(&dispCtrl, g_slitDestIdx);
		g_ddrInited = 1;
	}

	dest = pFrames[g_slitDestIdx];
	if ((cmd == 'w') || (cmd == 'W'))
	{
		mode = LIVE_FX_SLIT_COLUMNS;
	}
	else if ((cmd == 'x') || (cmd == 'X'))
	{
		mode = LIVE_FX_SLIT_ROWS;
	}
	else if ((cmd == 'y') || (cmd == 'Y'))
	{
		mode = LIVE_FX_SLIT_CENTER;
	}
	else
	{
		return 0;
	}
	LiveFxSlitScan(src, dest, width, height, DEMO_STRIDE, mode, chunk);
	return 1;
}

static int DemoParkDdrDest(const u8 *src, u32 width, u32 height, int copySrc)
{
	u32 y;

	if ((g_ddrInited != 0) && (g_slitDestIdx != (int)videoCapt.curFrame))
	{
		return g_slitDestIdx;
	}

	g_slitDestIdx = DemoEffectDestFrame();
	if (copySrc != 0)
	{
		for (y = 0U; y < height; y++)
		{
			memcpy(pFrames[g_slitDestIdx] + (y * DEMO_STRIDE),
				src + (y * DEMO_STRIDE),
				width * 3U);
		}
	}
	else
	{
		memset(pFrames[g_slitDestIdx], 0, height * DEMO_STRIDE);
	}
	Xil_DCacheFlushRange((unsigned int)pFrames[g_slitDestIdx], height * DEMO_STRIDE);
	DisplayChangeFrame(&dispCtrl, g_slitDestIdx);
	g_ddrInited = 1;
	return g_slitDestIdx;
}

static int DemoApplySpeckleEffect(const u8 *src, u32 width, u32 height)
{
	if (DemoParkDdrDest(src, width, height, 1) < 0)
	{
		return 0;
	}
	LiveFxSpeckle(src, pFrames[g_slitDestIdx], width, height, DEMO_STRIDE, g_specklePct);
	return 1;
}

static int DemoApplyRandomTileEffect(const u8 *src, u32 width, u32 height)
{
	u32 tile = g_tileSize;

	if (DemoParkDdrDest(src, width, height, 1) < 0)
	{
		return 0;
	}
	if (tile == 0U)
	{
		tile = 16U;
	}
	LiveFxRandomTiles(src, pFrames[g_slitDestIdx], width, height, DEMO_STRIDE, tile);
	return 1;
}

static int DemoApplyFilmStripEffect(const u8 *src, u32 width, u32 height)
{
	u32 tiles = g_filmTiles;

	if (DemoParkDdrDest(src, width, height, 0) < 0)
	{
		return 0;
	}
	if (tiles < 4U)
	{
		tiles = 4U;
	}
	LiveFxFilmStrip(src, pFrames[g_slitDestIdx], width, height, DEMO_STRIDE, tiles);
	return 1;
}

static void DemoPixelDoubleInPlace(u8 *frame, u32 halfW, u32 halfH, u32 stride)
{
	LiveFxPixelDoubleInPlace(frame, halfW, halfH, stride);
}

static int DemoApplyLiveEffectFrame(void)
{
	int dest;
	u8 *src;
	u32 width;
	u32 height;
	u32 halfW;
	u32 halfH;
	int clearNow;

	if ((g_liveEffectCmd == 0) || (videoCapt.state != VIDEO_STREAMING))
	{
		return 0;
	}

	src = pFrames[videoCapt.curFrame];
	width = videoCapt.timing.HActiveVideo;
	height = videoCapt.timing.VActiveVideo;
	if ((width < 16U) || (height < 16U))
	{
		return 0;
	}

	if (DemoIsParkedDdrEffect(g_liveEffectCmd))
	{
		DemoInvalidateVideoSrc(src, height);
		if ((g_liveEffectCmd == 'z') || (g_liveEffectCmd == 'Z'))
		{
			return DemoApplySpeckleEffect(src, width, height);
		}
		if ((g_liveEffectCmd == 'v') || (g_liveEffectCmd == 'V'))
		{
			return DemoApplyRandomTileEffect(src, width, height);
		}
		if ((g_liveEffectCmd == 'u') || (g_liveEffectCmd == 'U'))
		{
			return DemoApplyFilmStripEffect(src, width, height);
		}
		return DemoApplySlitEffect(src, width, height);
	}

	if ((width < (16U * DEMO_IN_DECIM)) || (height < (16U * DEMO_IN_DECIM)))
	{
		return 0;
	}

	halfW = width / DEMO_IN_DECIM;
	halfH = height / DEMO_IN_DECIM;
	if ((halfH * DemoPackedStride(halfW)) > sizeof(g_halfSrc))
	{
		return 0;
	}

	dest = DemoEffectDestFrame();
	DemoInvalidateVideoSrc(src, height);
	DemoDecimateSkip2(src, g_halfSrc, width, height, DEMO_STRIDE);
	if (DemoIsDdrEffect(g_liveEffectCmd))
	{
		return DemoApplyDdrEffect(pFrames[dest], dest, halfW, halfH, height);
	}
	DemoCopyPlane(g_delayPlane, DEMO_STRIDE, g_halfSrc, DemoPackedStride(halfW), halfW, halfH);
	clearNow = g_liveEffectNeedClear;
	g_liveEffectNeedClear = 0;
	if (DemoApplySelectedEffect(g_liveEffectCmd, g_delayPlane, pFrames[dest], halfW, halfH, clearNow) != 0)
	{
		return 0;
	}
	DemoPixelDoubleInPlace(pFrames[dest], halfW, halfH, DEMO_STRIDE);
	Xil_DCacheFlushRange((unsigned int)pFrames[dest], height * DEMO_STRIDE);
	DisplayChangeFrame(&dispCtrl, dest);
	return 1;
}

static void DemoInvalidateVideoSrc(u8 *frame, u32 height)
{
	if ((frame != NULL) && (height > 0U))
	{
		Xil_DCacheInvalidateRange((unsigned int)frame, height * DEMO_STRIDE);
	}
}

static int DemoApplySelectedEffect(char cmd, u8 *src, u8 *dst, u32 width, u32 height, int clearFrame)
{
	if (clearFrame)
	{
		DemoClearFrame(dst, width, height, DEMO_STRIDE);
	}

	switch (cmd)
	{
	case '1':
		LiveFxMirror(src, dst, width, height, DEMO_STRIDE, LIVE_FX_MIRROR_H);
		return 0;
	case '2':
		LiveFxMirror(src, dst, width, height, DEMO_STRIDE, LIVE_FX_MIRROR_V);
		return 0;
	case '3':
		LiveFxMirror(src, dst, width, height, DEMO_STRIDE, LIVE_FX_MIRROR_BOTH);
		return 0;
	case '4':
		LiveFxMirror(src, dst, width, height, DEMO_STRIDE, LIVE_FX_MIRROR_CENTER_X);
		return 0;
	case '5':
		LiveFxMirror(src, dst, width, height, DEMO_STRIDE, LIVE_FX_MIRROR_CENTER_Y);
		return 0;
	case '6':
		LiveFxMirror(src, dst, width, height, DEMO_STRIDE, LIVE_FX_MIRROR_CENTER_XY);
		return 0;
	case '7':
		LiveFxTile(src, dst, width, height, DEMO_STRIDE, LIVE_FX_TILE_2X2);
		return 0;
	case '8':
		LiveFxTile(src, dst, width, height, DEMO_STRIDE, LIVE_FX_TILE_3X3);
		return 0;
	case '9':
		LiveFxTile(src, dst, width, height, DEMO_STRIDE, LIVE_FX_TILE_4X4);
		return 0;
	case 'a':
	case 'A':
		LiveFxZoom(src, dst, width, height, DEMO_STRIDE, LIVE_FX_ZOOM_IN);
		return 0;
	case 'b':
	case 'B':
		LiveFxZoom(src, dst, width, height, DEMO_STRIDE, LIVE_FX_ZOOM_OUT);
		return 0;
	case 'c':
	case 'C':
		LiveFxMosaic(src, dst, width, height, DEMO_STRIDE, LIVE_FX_MOSAIC_8);
		return 0;
	case 'd':
	case 'D':
		LiveFxMosaic(src, dst, width, height, DEMO_STRIDE, LIVE_FX_MOSAIC_16);
		return 0;
	case 'e':
	case 'E':
		LiveFxMosaic(src, dst, width, height, DEMO_STRIDE, LIVE_FX_MOSAIC_32);
		return 0;
	case 'f':
	case 'F':
		LiveFxPlane3D(src, dst, width, height, DEMO_STRIDE, LIVE_FX_PLANE3D_Z45);
		return 0;
	case 'g':
	case 'G':
		LiveFxPlane3D(src, dst, width, height, DEMO_STRIDE, LIVE_FX_PLANE3D_Z90);
		return 0;
	case 'h':
	case 'H':
		LiveFxPlane3D(src, dst, width, height, DEMO_STRIDE, LIVE_FX_PLANE3D_X);
		return 0;
	case 'i':
	case 'I':
		LiveFxPlane3D(src, dst, width, height, DEMO_STRIDE, LIVE_FX_PLANE3D_Y);
		return 0;
	case 'j':
	case 'J':
		LiveFxPlane3D(src, dst, width, height, DEMO_STRIDE, LIVE_FX_PLANE3D_XYZ);
		return 0;
	case 'k':
	case 'K':
		LiveFxPlane3D(src, dst, width, height, DEMO_STRIDE, LIVE_FX_PLANE3D_SCALE);
		return 0;
	case 'l':
	case 'L':
		LiveFxShrinkRandom(src, dst, width, height, DEMO_STRIDE, 1);
		return 0;
	default:
		return -1;
	}
}

static char DemoReadMenuKey(void)
{
	char userInput;
	char rxChar;

	userInput = (char)XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
	while (XUartPs_IsReceiveData(UART_BASEADDR))
	{
		rxChar = (char)XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
		if ((rxChar != '\r') && (rxChar != '\n'))
		{
			userInput = rxChar;
		}
	}
	return userInput;
}

static int DemoRunEffectUntilKey(char cmd, int clearFrame, u8 *staticSrc, u32 staticWidth, u32 staticHeight)
{
	int dest;
	char key;

	if (videoCapt.state == VIDEO_PAUSED)
	{
		(void)VideoStart(&videoCapt);
	}

	if (videoCapt.state == VIDEO_STREAMING)
	{
		if (DemoIsDdrEffect(cmd) && (g_liveEffectCmd == cmd))
		{
			DemoCycleDdrEffectParam(cmd);
		}
		else
		{
			if (DemoIsDdrEffect(cmd) || DemoIsDdrEffect(g_liveEffectCmd))
			{
				DemoResetDdrEffectState();
			}
			g_liveEffectCmd = cmd;
			g_liveEffectClear = clearFrame;
			g_liveEffectNeedClear = clearFrame;
		}
		if (DemoApplyLiveEffectFrame() == 0)
		{
			g_liveEffectCmd = 0;
			return -1;
		}
		xil_printf("\n\rHDMI-out now shows effected video-in on frame %d.\r\n",
			dispCtrl.curFrame);
		return 0;
	}

	dest = DemoEffectDestFrame();
	if (DemoApplySelectedEffect(cmd, staticSrc, pFrames[dest], staticWidth, staticHeight, clearFrame) != 0)
	{
		return -1;
	}
	/* DemoClearFrame already flushed the blank frame. The effect itself is still
	 * in the CPU cache, so without this the VDMA keeps scanning the old splash. */
	Xil_DCacheFlushRange((unsigned int)pFrames[dest], staticHeight * DEMO_STRIDE);
	DisplayChangeFrame(&dispCtrl, dest);
	xil_printf("\n\rPress any key to continue, q to quit...\r\n");
	while (XUartPs_IsReceiveData(UART_BASEADDR))
	{
		(void)XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
	}
	while (!XUartPs_IsReceiveData(UART_BASEADDR))
	{
		MidiUartPoll();
	}
	key = DemoReadMenuKey();
	if ((key == 'q') || (key == 'Q'))
	{
		return 1;
	}
	return 0;
}

void DemoPatternMenu(void)
{
	char userInput = 0;
	int pattern = -1;

	while (XUartPs_IsReceiveData(UART_BASEADDR))
	{
		(void)XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
	}

	while (1)
	{
		xil_printf("\x1B[H");
		xil_printf("\x1B[2J");
		xil_printf("**************************************************\n\r");
		xil_printf("*            Animated Patterns                    *\n\r");
		xil_printf("**************************************************\n\r");
		xil_printf("Any key stops a running pattern.\n\r\n\r");
		xil_printf("Existing\n\r");
		xil_printf("1 - Plasma\n\r");
		xil_printf("2 - Spiral\n\r");
		xil_printf("3 - Ripple\n\r");
		xil_printf("4 - Waves\n\r");
		xil_printf("5 - Gradient\n\r");
		xil_printf("6 - Moire\n\r");
		xil_printf("7 - Standing wave\n\r");
		xil_printf("8 - Lissajous\n\r");
		xil_printf("9 - Flow field\n\r");
		xil_printf("\n\rFast / cheap\n\r");
		xil_printf("A - Color blocks (large tiles, slow change)\n\r");
		xil_printf("B - White noise\n\r");
		xil_printf("C - Random boxes (accumulate)\n\r");
		xil_printf("D - Random lines (accumulate)\n\r");
		xil_printf("E - Color wash (full-screen hue crawl)\n\r");
		xil_printf("F - Sliding color bars\n\r");
		xil_printf("G - Snow (dots accumulate)\n\r");
		xil_printf("q - Back to main menu\n\r");
		xil_printf("\n\rSelect a pattern:");

		do
		{
			while (!XUartPs_IsReceiveData(UART_BASEADDR))
			{
				MidiUartPoll();
				(void)DemoApplyLiveEffectFrame();
			}
			userInput = DemoReadMenuKey();
		} while ((userInput == '\r') || (userInput == '\n'));

		xil_printf("%c", userInput);

		if ((userInput == 'q') || (userInput == 'Q'))
		{
			return;
		}

		pattern = -1;
		if (userInput == '1')
		{
			pattern = DEMO_PATTERN_PLASMA;
		}
		else if (userInput == '2')
		{
			pattern = DEMO_PATTERN_SPIRAL;
		}
		else if (userInput == '3')
		{
			pattern = DEMO_PATTERN_RIPPLE;
		}
		else if (userInput == '4')
		{
			pattern = DEMO_PATTERN_WAVES;
		}
		else if (userInput == '5')
		{
			pattern = DEMO_PATTERN_GRADIENT;
		}
		else if (userInput == '6')
		{
			pattern = DEMO_PATTERN_MOIRE;
		}
		else if (userInput == '7')
		{
			pattern = DEMO_PATTERN_STANDING_WAVE;
		}
		else if (userInput == '8')
		{
			pattern = DEMO_PATTERN_LISSAJOUS;
		}
		else if (userInput == '9')
		{
			pattern = DEMO_PATTERN_FLOW_FIELD;
		}
		else if ((userInput == 'a') || (userInput == 'A'))
		{
			pattern = DEMO_PATTERN_COLOR_BLOCKS;
		}
		else if ((userInput == 'b') || (userInput == 'B'))
		{
			pattern = DEMO_PATTERN_WHITE_NOISE;
		}
		else if ((userInput == 'c') || (userInput == 'C'))
		{
			pattern = DEMO_PATTERN_RANDOM_BOXES;
		}
		else if ((userInput == 'd') || (userInput == 'D'))
		{
			pattern = DEMO_PATTERN_RANDOM_LINES;
		}
		else if ((userInput == 'e') || (userInput == 'E'))
		{
			pattern = DEMO_PATTERN_COLOR_WASH;
		}
		else if ((userInput == 'f') || (userInput == 'F'))
		{
			pattern = DEMO_PATTERN_SLIDING_BARS;
		}
		else if ((userInput == 'g') || (userInput == 'G'))
		{
			pattern = DEMO_PATTERN_SNOW;
		}

		if (pattern < 0)
		{
			xil_printf("\n\rInvalid Selection");
			TimerDelay(400000);
			continue;
		}

		DemoRunAnimatedPattern(pFrames[dispCtrl.curFrame], dispCtrl.vMode.width,
			dispCtrl.vMode.height, DEMO_STRIDE, pattern, 0);
	}
}

void DemoEffectMenu()
{
	int fEffectSet = 0;
	char userInput = 0;
	u8 *originalSrcFrame;
	u32 originalWidth;
	u32 originalHeight;
	int clearFrame = 1;
	int originalFrameStored = 0;
	u32 srcFrameIdx;
	u32 i;

	while (XUartPs_IsReceiveData(UART_BASEADDR))
	{
		(void)XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
	}

	originalSrcFrame = pFrames[dispCtrl.curFrame];
	originalWidth = dispCtrl.vMode.width;
	originalHeight = dispCtrl.vMode.height;

	while (!fEffectSet)
	{
		xil_printf("\x1B[H");
		xil_printf("\x1B[2J");
		xil_printf("**************************************************\n\r");
		xil_printf("*            Video Effects Menu                   *\n\r");
		xil_printf("**************************************************\n\r");
		xil_printf("HDMI-in: %s\n\r",
			(videoCapt.state == VIDEO_STREAMING) ? "LIVE (effects keep updating)" : "static frame");
		if (g_liveEffectCmd != 0)
		{
			xil_printf("Active effect: %c  display frame %d\n\r",
				g_liveEffectCmd, dispCtrl.curFrame);
			if ((g_liveEffectCmd == 'r') || (g_liveEffectCmd == 'R'))
			{
				xil_printf("  strobe every %u frames (press R again to change)\n\r",
					(unsigned)g_strobeInterval);
			}
			else if ((g_liveEffectCmd == 's') || (g_liveEffectCmd == 'S'))
			{
				xil_printf("  feedback %u/256 (press S again to change)\n\r",
					(unsigned)g_feedbackAmt);
			}
			else if ((g_liveEffectCmd == 'u') || (g_liveEffectCmd == 'U'))
			{
				xil_printf("  film strip %u tiles (press U again to change)\n\r",
					(unsigned)g_filmTiles);
			}
			else if (DemoIsSlitEffect(g_liveEffectCmd))
			{
				xil_printf("  slit chunk %u px (press the key again to change)\n\r",
					(unsigned)g_slitChunk);
			}
			else if ((g_liveEffectCmd == 'z') || (g_liveEffectCmd == 'Z'))
			{
				xil_printf("  speckle %u%% of pixels (press Z again to change)\n\r",
					(unsigned)g_specklePct);
			}
			else if ((g_liveEffectCmd == 'v') || (g_liveEffectCmd == 'V'))
			{
				xil_printf("  random tiles %ux%u (press V again to change)\n\r",
					(unsigned)g_tileSize, (unsigned)g_tileSize);
			}
			else if (g_liveEffectCmd == ',')
			{
				xil_printf("  frame shuffle hold %u (press , again to change)\n\r",
					(unsigned)g_shuffleHold);
			}
			else if (g_liveEffectCmd == '-')
			{
				xil_printf("  difference %s (press - again to change)\n\r",
					(g_diffMode == 0U) ? "abs vs freeze" :
					(g_diffMode == 1U) ? "XOR vs freeze" :
					(g_diffMode == 2U) ? "abs vs previous" : "XOR vs previous");
			}
			else if (g_liveEffectCmd == '/')
			{
				xil_printf("  tunnel zoom %u%% (press / again to change)\n\r",
					(unsigned)((256U * 100U) / g_tunnelZoomQ8));
			}
		}
		xil_printf("\n\r");
		xil_printf("0 - Clear live effect (show raw HDMI-in)\n\r");
		xil_printf("1 - Mirror Horizontal (flip)\n\r");
		xil_printf("2 - Mirror Vertical (flip)\n\r");
		xil_printf("3 - Mirror Both (flip)\n\r");
		xil_printf("4 - Center Mirror X (left mirrors right)\n\r");
		xil_printf("5 - Center Mirror Y (top mirrors bottom)\n\r");
		xil_printf("6 - Center Mirror XY (quadrant mirror)\n\r");
		xil_printf("7 - Tile Effect (2x2)\n\r");
		xil_printf("8 - Tile Effect (3x3)\n\r");
		xil_printf("9 - Tile Effect (4x4)\n\r");
		xil_printf("A - Zoom In (2x)\n\r");
		xil_printf("B - Zoom Out (0.5x)\n\r");
		xil_printf("C - Mosaic Effect (8x8 blocks)\n\r");
		xil_printf("D - Mosaic Effect (16x16 blocks)\n\r");
		xil_printf("E - Mosaic Effect (32x32 blocks)\n\r");
		xil_printf("F - 3D Rotate Z (45 degrees)\n\r");
		xil_printf("G - 3D Rotate Z (90 degrees)\n\r");
		xil_printf("H - 3D Rotate X (perspective)\n\r");
		xil_printf("I - 3D Rotate Y (perspective)\n\r");
		xil_printf("J - 3D Rotate XYZ (combined)\n\r");
		xil_printf("K - 3D Scale + Rotate\n\r");
		xil_printf("L - Shrink 25%% and Random Position\n\r");
		xil_printf("R - Strobe / freeze (DDR, repeat to change interval)\n\r");
		xil_printf("S - Feedback (DDR, repeat to change mix)\n\r");
		xil_printf("U - Film strip (DDR, repeat to change tile count)\n\r");
		xil_printf("W - Slit scan columns (20px, new frame at next X)\n\r");
		xil_printf("X - Slit scan rows (20px, new frame at next Y)\n\r");
		xil_printf("Y - Center band tiled vertically (same slice fills the screen)\n\r");
		xil_printf("Z - Speckle (random 30%% of pixels from new frame)\n\r");
		xil_printf("V - Random tiles (30%% of 16px blocks from new frame)\n\r");
		xil_printf(", - Frame shuffle (8 stills, random slot)\n\r");
		xil_printf("- - Difference (live minus frozen still)\n\r");
		xil_printf("/ - Video feedback tunnel (zoom mix into history)\n\r");
		xil_printf("M - Animated 3D Rotate X\n\r");
		xil_printf("N - Animated 3D Rotate Y\n\r");
		xil_printf("O - Animated 3D Rotate Z\n\r");
		xil_printf("P - Animated 3D Rotate XYZ\n\r");
		xil_printf("T - Toggle Frame Clear (Current: %s)\n\r", clearFrame ? "ON" : "OFF");
		xil_printf("q - Quit (back to main menu)\n\r");
		xil_printf("\n\r");
		xil_printf("Select an effect:");

		do
		{
			while (!XUartPs_IsReceiveData(UART_BASEADDR))
			{
				MidiUartPoll();
				(void)DemoApplyLiveEffectFrame();
			}
			userInput = DemoReadMenuKey();
		} while ((userInput == '\r') || (userInput == '\n'));

		xil_printf("%c", userInput);

		if ((userInput == 'q') || (userInput == 'Q'))
		{
			fEffectSet = 1;
			break;
		}

		if (userInput == '0')
		{
			g_liveEffectCmd = 0;
			DemoResetDdrEffectState();
			if (videoCapt.state == VIDEO_STREAMING)
			{
				DisplayChangeFrame(&dispCtrl, videoCapt.curFrame);
			}
			xil_printf("\n\rLive effect cleared, showing raw HDMI-in\n\r");
			continue;
		}

		if ((userInput == 't') || (userInput == 'T'))
		{
			clearFrame = !clearFrame;
			xil_printf("\n\rFrame Clear: %s\n\r", clearFrame ? "ON" : "OFF");
			continue;
		}

		if (videoCapt.state == VIDEO_STREAMING)
		{
			originalSrcFrame = pFrames[videoCapt.curFrame];
			originalWidth = videoCapt.timing.HActiveVideo;
			originalHeight = videoCapt.timing.VActiveVideo;
			originalFrameStored = 1;
		}
		else if (!originalFrameStored)
		{
			originalSrcFrame = pFrames[dispCtrl.curFrame];
			originalWidth = dispCtrl.vMode.width;
			originalHeight = dispCtrl.vMode.height;
			originalFrameStored = 1;
		}

		if ((userInput == 'm') || (userInput == 'M') ||
			(userInput == 'n') || (userInput == 'N') ||
			(userInput == 'o') || (userInput == 'O') ||
			(userInput == 'p') || (userInput == 'P'))
		{
			srcFrameIdx = 0U;
			for (i = 0U; i < DISPLAY_NUM_FRAMES; i++)
			{
				if (pFrames[i] == originalSrcFrame)
				{
					srcFrameIdx = i;
					break;
				}
			}
			xil_printf("\n\rAnimated 3D effect. Any key stops.\r\n");
			DemoRunAnimated3DEffect(originalSrcFrame, pFrames, srcFrameIdx,
				originalWidth, originalHeight, DEMO_STRIDE,
				dispCtrl.vMode.width, dispCtrl.vMode.height,
				(char)((userInput == 'p' || userInput == 'P') ? 'A' :
					(userInput == 'n' || userInput == 'N') ? 'Y' :
					(userInput == 'o' || userInput == 'O') ? 'Z' : 'X'),
				0.7f, &dispCtrl, &videoCapt);
			continue;
		}

		{
			int effectRc;

			effectRc = DemoRunEffectUntilKey(userInput, clearFrame, originalSrcFrame, originalWidth, originalHeight);
			if (effectRc > 0)
			{
				fEffectSet = 1;
			}
			else if (effectRc < 0)
			{
				xil_printf("\n\rInvalid Selection");
				TimerDelay(500000);
			}
		}
	}

}


int DemoGetInactiveFrame(DisplayCtrl *DispCtrlPtr, VideoCapture *VideoCaptPtr)
{
	int i;
	for (i=1; i<DISPLAY_NUM_FRAMES; i++)
	{
		if (DispCtrlPtr->curFrame == i && DispCtrlPtr->state == DISPLAY_RUNNING)
		{
			continue;
		}
		else if (VideoCaptPtr->curFrame == i && VideoCaptPtr->state == VIDEO_STREAMING)
		{
			continue;
		}
		else
		{
			return i;
		}
	}
	xil_printf("Unreachable error state reached. All buffers are in use.\r\n");
	return 0;
}

void DemoInvertFrame(u8 *srcFrame, u8 *destFrame, u32 width, u32 height, u32 stride)
{
	u32 xcoi, ycoi;
	u32 lineStart = 0;
	for(ycoi = 0; ycoi < height; ycoi++)
	{
		for(xcoi = 0; xcoi < (width * 3); xcoi+=3)
		{
			destFrame[xcoi + lineStart] = ~srcFrame[xcoi + lineStart];         //Red
			destFrame[xcoi + lineStart + 1] = ~srcFrame[xcoi + lineStart + 1]; //Blue
			destFrame[xcoi + lineStart + 2] = ~srcFrame[xcoi + lineStart + 2]; //Green
		}
		lineStart += stride;
	}
	/*
	 * Flush the framebuffer memory range to ensure changes are written to the
	 * actual memory, and therefore accessible by the VDMA.
	 */
	Xil_DCacheFlushRange((unsigned int) destFrame, height * stride);
}


/*
 * Bilinear interpolation algorithm. Assumes both frames have the same stride.
 */
void DemoScaleFrame(u8 *srcFrame, u8 *destFrame, u32 srcWidth, u32 srcHeight, u32 destWidth, u32 destHeight, u32 stride)
{
	float xInc, yInc; // Width/height of a destination frame pixel in the source frame coordinate system
	float xcoSrc, ycoSrc; // Location of the destination pixel being operated on in the source frame coordinate system
	float x1y1, x2y1, x1y2, x2y2; //Used to store the color data of the four nearest source pixels to the destination pixel
	int ix1y1, ix2y1, ix1y2, ix2y2; //indexes into the source frame for the four nearest source pixels to the destination pixel
	float xDist, yDist; //distances between destination pixel and x1y1 source pixels in source frame coordinate system

	int xcoDest, ycoDest; // Location of the destination pixel being operated on in the destination coordinate system
	int iy1; //Used to store the index of the first source pixel in the line with y1
	int iDest; //index of the pixel data in the destination frame being operated on

	int i;

	xInc = ((float) srcWidth - 1.0) / ((float) destWidth);
	yInc = ((float) srcHeight - 1.0) / ((float) destHeight);

	ycoSrc = 0.0;
	for (ycoDest = 0; ycoDest < destHeight; ycoDest++)
	{
		iy1 = ((int) ycoSrc) * stride;
		yDist = ycoSrc - ((float) ((int) ycoSrc));

		/*
		 * Save some cycles in the loop below by presetting the destination
		 * index to the first pixel in the current line
		 */
		iDest = ycoDest * stride;

		xcoSrc = 0.0;
		for (xcoDest = 0; xcoDest < destWidth; xcoDest++)
		{
			ix1y1 = iy1 + ((int) xcoSrc) * 3;
			ix2y1 = ix1y1 + 3;
			ix1y2 = ix1y1 + stride;
			ix2y2 = ix1y1 + stride + 3;

			xDist = xcoSrc - ((float) ((int) xcoSrc));

			/*
			 * For loop handles all three colors
			 */
			for (i = 0; i < 3; i++)
			{
				x1y1 = (float) srcFrame[ix1y1 + i];
				x2y1 = (float) srcFrame[ix2y1 + i];
				x1y2 = (float) srcFrame[ix1y2 + i];
				x2y2 = (float) srcFrame[ix2y2 + i];

				/*
				 * Bilinear interpolation function
				 */
				destFrame[iDest] = (u8) ((1.0-yDist)*((1.0-xDist)*x1y1+xDist*x2y1) + yDist*((1.0-xDist)*x1y2+xDist*x2y2));
				iDest++;
			}
			xcoSrc += xInc;
		}
		ycoSrc += yInc;
	}

	/*
	 * Flush the framebuffer memory range to ensure changes are written to the
	 * actual memory, and therefore accessible by the VDMA.
	 */
	Xil_DCacheFlushRange((unsigned int) destFrame, destHeight * stride);

	return;
}

void DemoClearFrame(u8 *frame, u32 width, u32 height, u32 stride)
{
	u32 y;
	u32 rowBytes;

	if ((frame == NULL) || (height == 0U) || (stride == 0U))
	{
		return;
	}

	rowBytes = width * 3U;
	if ((rowBytes == 0U) || (rowBytes > stride))
	{
		rowBytes = stride;
	}
	for (y = 0U; y < height; y++)
	{
		memset(frame + (y * stride), 0, rowBytes);
	}
	Xil_DCacheFlushRange((unsigned int)frame, height * stride);
}

void DemoBlitSplash(u8 *frame, u32 width, u32 height, u32 stride)
{
	u32 splashW;
	u32 splashH;
	u32 x0;
	u32 y0;
	u32 sx;
	u32 sy;

	DemoClearFrame(frame, width, height, stride);
	if ((frame == NULL) || (width == 0U) || (height == 0U) || (stride < 3U))
	{
		return;
	}

	splashW = SPLASH_WIDTH;
	splashH = SPLASH_HEIGHT;
	if (splashW > width)
	{
		splashW = width;
	}
	if (splashH > height)
	{
		splashH = height;
	}
	x0 = (width - splashW) / 2U;
	y0 = (height - splashH) / 2U;

	for (sy = 0U; sy < splashH; sy++)
	{
		const u8 *row = splash_bits + (sy * SPLASH_ROW_BYTES);
		u8 *dst = frame + ((y0 + sy) * stride) + (x0 * 3U);

		for (sx = 0U; sx < splashW; sx++)
		{
			if ((row[sx >> 3] & (u8)(0x80U >> (sx & 7U))) != 0U)
			{
				dst[sx * 3U] = 0xFFU;
				dst[(sx * 3U) + 1U] = 0xFFU;
				dst[(sx * 3U) + 2U] = 0xFFU;
			}
		}
	}
	Xil_DCacheFlushRange((unsigned int)frame, height * stride);
}

void DemoPrintTest(u8 *frame, u32 width, u32 height, u32 stride, int pattern)
{
	u32 xcoi, ycoi;
	u32 iPixelAddr;
	u8 wRed, wBlue, wGreen;
	u32 wCurrentInt;
	double fRed, fBlue, fGreen, fColor;
	u32 xLeft, xMid, xRight, xInt;
	u32 yMid, yInt;
	double xInc, yInc;


	switch (pattern)
	{
	case DEMO_PATTERN_0:

		xInt = width / 4; //Four intervals, each with width/4 pixels
		xLeft = xInt * 3;
		xMid = xInt * 2 * 3;
		xRight = xInt * 3 * 3;
		xInc = 256.0 / ((double) xInt); //256 color intensities are cycled through per interval (overflow must be caught when color=256.0)

		yInt = height / 2; //Two intervals, each with width/2 lines
		yMid = yInt;
		yInc = 256.0 / ((double) yInt); //256 color intensities are cycled through per interval (overflow must be caught when color=256.0)

		fBlue = 0.0;
		fRed = 256.0;
		for(xcoi = 0; xcoi < (width*3); xcoi+=3)
		{
			/*
			 * Convert color intensities to integers < 256, and trim values >=256
			 */
			wRed = (fRed >= 256.0) ? 255 : ((u8) fRed);
			wBlue = (fBlue >= 256.0) ? 255 : ((u8) fBlue);
			iPixelAddr = xcoi;
			fGreen = 0.0;
			for(ycoi = 0; ycoi < height; ycoi++)
			{

				wGreen = (fGreen >= 256.0) ? 255 : ((u8) fGreen);
				frame[iPixelAddr] = wRed;
				frame[iPixelAddr + 1] = wBlue;
				frame[iPixelAddr + 2] = wGreen;
				if (ycoi < yMid)
				{
					fGreen += yInc;
				}
				else
				{
					fGreen -= yInc;
				}

				/*
				 * This pattern is printed one vertical line at a time, so the address must be incremented
				 * by the stride instead of just 1.
				 */
				iPixelAddr += stride;
			}

			if (xcoi < xLeft)
			{
				fBlue = 0.0;
				fRed -= xInc;
			}
			else if (xcoi < xMid)
			{
				fBlue += xInc;
				fRed += xInc;
			}
			else if (xcoi < xRight)
			{
				fBlue -= xInc;
				fRed -= xInc;
			}
			else
			{
				fBlue += xInc;
				fRed = 0;
			}
		}
		/*
		 * Flush the framebuffer memory range to ensure changes are written to the
		 * actual memory, and therefore accessible by the VDMA.
		 */
		Xil_DCacheFlushRange((unsigned int) frame, height * stride);
		break;
	case DEMO_PATTERN_1:

		xInt = width / 7; //Seven intervals, each with width/7 pixels
		xInc = 256.0 / ((double) xInt); //256 color intensities per interval. Notice that overflow is handled for this pattern.

		fColor = 0.0;
		wCurrentInt = 1;
		for(xcoi = 0; xcoi < (width*3); xcoi+=3)
		{

			/*
			 * Just draw white in the last partial interval (when width is not divisible by 7)
			 */
			if (wCurrentInt > 7)
			{
				wRed = 255;
				wBlue = 255;
				wGreen = 255;
			}
			else
			{
				if (wCurrentInt & 0b001)
					wRed = (u8) fColor;
				else
					wRed = 0;

				if (wCurrentInt & 0b010)
					wBlue = (u8) fColor;
				else
					wBlue = 0;

				if (wCurrentInt & 0b100)
					wGreen = (u8) fColor;
				else
					wGreen = 0;
			}

			iPixelAddr = xcoi;

			for(ycoi = 0; ycoi < height; ycoi++)
			{
				frame[iPixelAddr] = wRed;
				frame[iPixelAddr + 1] = wBlue;
				frame[iPixelAddr + 2] = wGreen;
				/*
				 * This pattern is printed one vertical line at a time, so the address must be incremented
				 * by the stride instead of just 1.
				 */
				iPixelAddr += stride;
			}

			fColor += xInc;
			if (fColor >= 256.0)
			{
				fColor = 0.0;
				wCurrentInt++;
			}
		}
		/*
		 * Flush the framebuffer memory range to ensure changes are written to the
		 * actual memory, and therefore accessible by the VDMA.
		 */
		Xil_DCacheFlushRange((unsigned int) frame, height * stride);
		break;
	case DEMO_PATTERN_GRID:
		{
			u32 gridSize = 50; // Grid cell size in pixels
			u32 borderWidth = 2; // Border/outline width
			u8 gridColor = 255; // White for grid lines
			u8 bgColor = 0; // Black background
			
			for(ycoi = 0; ycoi < height; ycoi++)
			{
				iPixelAddr = ycoi * stride;
				
				for(xcoi = 0; xcoi < width; xcoi++)
				{
					// Check if we're on a grid line (horizontal or vertical)
					u32 gridX = xcoi % gridSize;
					u32 gridY = ycoi % gridSize;
					
					// Draw grid lines
					if (gridX < borderWidth || gridX >= (gridSize - borderWidth) ||
						gridY < borderWidth || gridY >= (gridSize - borderWidth))
					{
						wRed = gridColor;
						wBlue = gridColor;
						wGreen = gridColor;
					}
					else
					{
						wRed = bgColor;
						wBlue = bgColor;
						wGreen = bgColor;
					}
					
					// Draw border outline
					if (xcoi < borderWidth || xcoi >= (width - borderWidth) ||
						ycoi < borderWidth || ycoi >= (height - borderWidth))
					{
						wRed = gridColor;
						wBlue = gridColor;
						wGreen = gridColor;
					}
					
					frame[iPixelAddr] = wRed;
					frame[iPixelAddr + 1] = wBlue;
					frame[iPixelAddr + 2] = wGreen;
					
					iPixelAddr += 3;
				}
			}
		}
		Xil_DCacheFlushRange((unsigned int) frame, height * stride);
		break;
	default :
		xil_printf("Error: invalid pattern passed to DemoPrintTest");
	}
}

void DemoISR(void *callBackRef, void *pVideo)
{
	char *data = (char *) callBackRef;
	*data = 1; //set fRefresh to 1
}

static u32 DemoNextRandom(void)
{
	g_overlayRandState = g_overlayRandState * 1664525U + 1013904223U;
	return g_overlayRandState;
}

static void DemoOverlayWriteReg(u32 regOffset, u32 value)
{
	Xil_Out32(REGS_BRAM_BASEADDR + regOffset, value);
}

static u32 DemoOverlayReadReg(u32 regOffset)
{
	return Xil_In32(REGS_BRAM_BASEADDR + regOffset);
}

/* 0x78 bit 6: 1 = invert 640x480 negative sync, 0 = pass 720p positive sync.
 * Digital X is held in reset while H is high, so this must yield idle-low pulses.
 */
static void DemoSetSyncPolarityInvert(u32 enableInvert)
{
	u32 regVal;
	u32 bitMask;

	bitMask = (1U << VIDEO_CTRL_SYNC_INV_BIT);
	regVal = DemoOverlayReadReg(VIDEO_CTRL_REG_OFFSET);

	if (enableInvert != 0U)
	{
		regVal |= bitMask;
	}
	else
	{
		regVal &= ~bitMask;
	}

	DemoOverlayWriteReg(VIDEO_CTRL_REG_OFFSET, regVal);
}

static void DemoOverlayWriteWord(u32 wordAddr, u32 value)
{
	Xil_Out32(REGS_BRAM_BASEADDR + OVERLAY_BRAM_BYTE_BASE + (wordAddr << 2), value);
}

static u32 DemoOverlayReadWord(u32 wordAddr)
{
	return Xil_In32(REGS_BRAM_BASEADDR + OVERLAY_BRAM_BYTE_BASE + (wordAddr << 2));
}

static void DemoOverlaySetSprite(u32 spriteIdx, u32 enable, u32 x, u32 y, u32 width, u32 height, u32 baseWord)
{
	u32 spriteBase;
	u32 ctrlWord;
	u32 sizeWord;
	u32 baseAddrWord;

	if (spriteIdx >= 8U)
	{
		return;
	}

	spriteBase = OVERLAY_REG_SPRITE_BASE + spriteIdx * OVERLAY_REG_SPRITE_STRIDE;
	ctrlWord = ((y & 0x7FFU) << 12) | ((x & 0x7FFU) << 1) | (enable & 0x1U);
	sizeWord = ((height & 0x7FFU) << 11) | (width & 0x7FFU);
	baseAddrWord = (baseWord & 0x7FFU);

	DemoOverlayWriteReg(spriteBase + 0x0U, ctrlWord);
	DemoOverlayWriteReg(spriteBase + 0x4U, sizeWord);
	DemoOverlayWriteReg(spriteBase + 0x8U, baseAddrWord);
}

static void DemoOverlayDisableAllSprites(void)
{
	u32 i;
	for (i = 0; i < 8U; i++)
	{
		DemoOverlaySetSprite(i, 0U, 0U, 0U, 0U, 0U, 0U);
	}
}

static void DemoOverlayPatternTest(void)
{
	u32 i;
	u32 x;
	u32 y;
	u32 rgbaWord;
	u32 readBackErrors = 0U;
	u32 activeStartX;
	u32 activeStartY;
	u32 spriteX;
	u32 spriteY;
	const u32 patternWidth = 64U;
	const u32 patternHeight = 16U;
	const u32 patternWords = patternWidth * patternHeight; /* 1024 words */

	if (patternWords > OVERLAY_BRAM_WORDS)
	{
		xil_printf("\n\rOverlay test pattern does not fit BRAM.\n\r");
		return;
	}

	for (i = 0U; i < patternWords; i++)
	{
		x = i % patternWidth;
		y = i / patternWidth;
		/* Visible checker + transparent holes to test overlay keying path. */
		if (((x + y) & 0x3U) == 0U)
		{
			rgbaWord = 0x00000000U; /* transparent */
		}
		else
		{
			u32 red = (x * 9U) & 0xFFU;
			u32 green = (y * 15U + x * 3U) & 0xFFU;
			u32 blue = ((x ^ y) * 19U) & 0xFFU;
			rgbaWord = 0x80000000U | (blue << 16) | (green << 8) | red;
		}
		DemoOverlayWriteWord(i, rgbaWord);
	}

	/* Read a sparse subset back to validate CPU mux + BRAM write path. */
	for (i = 0U; i < patternWords; i += 17U)
	{
		x = i % patternWidth;
		y = i / patternWidth;
		if (((x + y) & 0x3U) == 0U)
		{
			rgbaWord = 0x00000000U;
		}
		else
		{
			u32 red = (x * 9U) & 0xFFU;
			u32 green = (y * 15U + x * 3U) & 0xFFU;
			u32 blue = ((x ^ y) * 19U) & 0xFFU;
			rgbaWord = 0x80000000U | (blue << 16) | (green << 8) | red;
		}

		if (DemoOverlayReadWord(i) != rgbaWord)
		{
			readBackErrors++;
		}
	}

	DemoOverlayDisableAllSprites();
	activeStartX = dispCtrl.vMode.hmax - dispCtrl.vMode.hpe;
	activeStartY = dispCtrl.vMode.vmax - dispCtrl.vMode.vpe;
	spriteX = activeStartX + 32U;
	spriteY = activeStartY + 32U;
	DemoOverlaySetSprite(0U, 1U, spriteX, spriteY, patternWidth, patternHeight, 0U);
	DemoOverlayWriteReg(OVERLAY_REG_GLOBAL_ENABLE, 1U);

	xil_printf("\n\rOverlay test loaded: sprite0=%dx%d @ (%d,%d), BRAM words=%d\n\r",
	           (int)patternWidth, (int)patternHeight, (int)spriteX, (int)spriteY, (int)patternWords);
	xil_printf("Overlay global enable=%d, readback errors=%d\n\r",
	           (int)(DemoOverlayReadReg(OVERLAY_REG_GLOBAL_ENABLE) & 0x1U),
	           (int)readBackErrors);
}

static void DemoSpriteRandomTest(u32 displayWidth, u32 displayHeight, u32 activeStartX, u32 activeStartY)
{
	u32 i;
	u32 x;
	u32 y;
	u32 pixelWord;
	u32 randX;
	u32 randY;
	const u32 spriteIdx = 1U;
	const u32 spriteWidth = 32U;
	const u32 spriteHeight = 16U;
	const u32 spriteWords = spriteWidth * spriteHeight; /* 512 words */
	const u32 spriteBaseWord = 1024U;                   /* after overlay test block */
	u32 maxX;
	u32 maxY;
	u32 posX;
	u32 posY;

	if ((spriteBaseWord + spriteWords) > OVERLAY_BRAM_WORDS)
	{
		xil_printf("\n\rSprite test data does not fit overlay BRAM.\n\r");
		return;
	}

	for (i = 0U; i < spriteWords; i++)
	{
		x = i % spriteWidth;
		y = i / spriteWidth;

		/* "Information" style sprite: border + row/column encoded intensity bars. */
		if (x == 0U || y == 0U || x == (spriteWidth - 1U) || y == (spriteHeight - 1U))
		{
			pixelWord = 0x80FFFFFFU;
		}
		else if ((y & 0x3U) == 0U || (x & 0x7U) == 0U)
		{
			u32 red = (x * 6U) & 0xFFU;
			u32 green = (y * 14U) & 0xFFU;
			u32 blue = ((x + y) * 10U) & 0xFFU;
			pixelWord = 0x80000000U | (blue << 16) | (green << 8) | red;
		}
		else
		{
			pixelWord = 0x00000000U; /* transparent interior gaps */
		}

		DemoOverlayWriteWord(spriteBaseWord + i, pixelWord);
	}

	randX = DemoNextRandom();
	randY = DemoNextRandom();
	maxX = (displayWidth > spriteWidth) ? (displayWidth - spriteWidth) : 0U;
	maxY = (displayHeight > spriteHeight) ? (displayHeight - spriteHeight) : 0U;
	posX = activeStartX + ((maxX > 0U) ? (randX % (maxX + 1U)) : 0U);
	posY = activeStartY + ((maxY > 0U) ? (randY % (maxY + 1U)) : 0U);

	/* Keep overlay enabled and move/update sprite slot every run. */
	DemoOverlayWriteReg(OVERLAY_REG_GLOBAL_ENABLE, 1U);
	DemoOverlaySetSprite(spriteIdx, 1U, posX, posY, spriteWidth, spriteHeight, spriteBaseWord);

	xil_printf("\n\rSprite test loaded: sprite%d=%dx%d @ (%d,%d), baseWord=%d\n\r",
	           (int)spriteIdx, (int)spriteWidth, (int)spriteHeight, (int)posX, (int)posY, (int)spriteBaseWord);
	xil_printf("Active window starts near (%d,%d)\n\r", (int)activeStartX, (int)activeStartY);
}


/*
 * Plasma Pattern - Monochrome wave pattern that evolves over time
 * Creates smooth, organic-looking transitions
 */
void DemoPlasmaPattern(u8 *frame, u32 width, u32 height, u32 stride, float time)
{
	u32 xcoi, ycoi;
	u32 iPixelAddr;
	float centerX = (float)width * 0.5f;
	float centerY = (float)height * 0.5f;
	const u32 phaseStepX16 = rad_to_phase(1.0f / 16.0f);
	const u32 phaseStepY12 = rad_to_phase(1.0f / 12.0f);
	const u32 phaseStepXY14 = rad_to_phase(1.0f / 14.0f);
	const u32 phaseTime1 = rad_to_phase(time * 20.0f / 16.0f);
	const u32 phaseTime2 = rad_to_phase(time * 15.0f / 12.0f);
	const u32 phaseTime3 = rad_to_phase(time * 10.0f / 14.0f);
	const u32 phaseTime4 = rad_to_phase(time * 25.0f);
	
	for(ycoi = 0; ycoi < height; ycoi++)
	{
		u32 phaseX1 = phaseTime1;
		u32 phaseY2 = phaseTime2 + ycoi * phaseStepY12;
		u32 phaseXY = phaseTime3 + ycoi * phaseStepXY14;
		float waveY = fast_sin_phase(phaseY2);
		float dy = (float)ycoi - centerY;
		iPixelAddr = ycoi * stride;
		
		for(xcoi = 0; xcoi < width; xcoi++)
		{
			float dx = (float)xcoi - centerX;
			float radialPhase = fast_sqrt(dx * dx + dy * dy) * 0.125f; /* /8 */
			float waveR = fast_sin_phase(phaseTime4 + rad_to_phase(radialPhase));
			float value = fast_sin_phase(phaseX1) + waveY + fast_sin_phase(phaseXY) + waveR;
			int mono = (int)((value + 4.0f) * (255.0f / 8.0f));
			u8 monochrome;

			mono = (mono < 0) ? 0 : mono;
			mono = (mono > 255) ? 255 : mono;
			monochrome = (u8)mono;

			frame[iPixelAddr] = monochrome;
			frame[iPixelAddr + 1] = monochrome;
			frame[iPixelAddr + 2] = monochrome;
			
			iPixelAddr += 3;
			phaseX1 += phaseStepX16;
			phaseXY += phaseStepXY14;
		}
	}
	
	Xil_DCacheFlushRange((unsigned int) frame, height * stride);
}

/*
 * Rotating Spiral Pattern - Animated spiral that rotates and expands
 */
void DemoSpiralPattern(u8 *frame, u32 width, u32 height, u32 stride, float time)
{
	u32 xcoi, ycoi;
	u32 iPixelAddr;
	u8 monochrome;
	double x, y;
	double centerX = width / 2.0;
	double centerY = height / 2.0;
	double dx, dy;
	double angle, radius;
	double spiralValue;
	
	for(ycoi = 0; ycoi < height; ycoi++)
	{
		y = (double)ycoi;
		iPixelAddr = ycoi * stride;
		
		for(xcoi = 0; xcoi < width; xcoi++)
		{
			x = (double)xcoi;
			dx = x - centerX;
			dy = y - centerY;
			
			// Calculate angle and radius from center
			angle = fast_atan2(dy, dx);
			radius = fast_sqrt(dx * dx + dy * dy);
			
			// Create spiral pattern (angle + radius creates spiral)
			spiralValue = (angle + time * 0.5f) / (2.0f * 3.14159f) + radius / 50.0f + time * 0.1f;
			spiralValue = spiralValue - fast_floor(spiralValue); // Wrap to 0-1
			
			// Clamp and convert to monochrome (0-255)
			if (spiralValue < 0.0) spiralValue = 0.0;
			if (spiralValue > 1.0) spiralValue = 1.0;
			monochrome = (u8)(spiralValue * 255.0);
			
			// Write monochrome value to all RGB channels
			frame[iPixelAddr] = monochrome;
			frame[iPixelAddr + 1] = monochrome;
			frame[iPixelAddr + 2] = monochrome;
			
			iPixelAddr += 3;
		}
	}
	
	Xil_DCacheFlushRange((unsigned int) frame, height * stride);
}

/*
 * Mandelbrot Fractal - Evolving Mandelbrot set with zoom and pan
 */
void DemoRipplePattern(u8 *frame, u32 width, u32 height, u32 stride, float time)
{
	u32 xcoi, ycoi;
	u32 iPixelAddr;
	u8 monochrome;
	float cx, cy;   /* Complex plane coordinates */
	float zx, zy;   /* Iteration variables */
	float zx2, zy2; /* Squared values for optimization */
	u32 iterations;
	u32 maxIterations = 50;
	float value;
	
	/* Pre-calculate inverses to avoid divisions in loops */
	float invWidth = 1.0f / (float)width;
	float invHeight = 1.0f / (float)height;
	float invMaxIter = 1.0f / (float)maxIterations;
	
	/* Evolve view: zoom in/out and pan around */
	float zoom = 0.5f + 0.3f * fast_sin(time * 0.05f);
	float centerX = -0.5f + 0.3f * fast_sin(time * 0.03f);
	float centerY = 0.0f + 0.2f * fast_cos(time * 0.04f);
	
	float scale = 2.5f / zoom;
	float offsetX = centerX;
	float offsetY = centerY;
	
	float yScale = scale * invHeight;
	float yOffset = (offsetY - 0.5f * scale);
	float xScale = scale * invWidth;
	float xOffset = (offsetX - 0.5f * scale);
	
	for(ycoi = 0; ycoi < height; ycoi++)
	{
		iPixelAddr = ycoi * stride;
		cy = (float)ycoi * yScale + yOffset;
		cx = xOffset;
		
		for(xcoi = 0; xcoi < width; xcoi++)
		{
			zx = 0.0f;
			zy = 0.0f;
			iterations = 0;
			
			while (iterations < maxIterations)
			{
				zx2 = zx * zx;
				zy2 = zy * zy;
				if (zx2 + zy2 > 4.0f)
					break;
				zy = 2.0f * zx * zy + cy;
				zx = zx2 - zy2 + cx;
				iterations++;
			}
			
			if (iterations >= maxIterations)
			{
				value = 0.0f;
			}
			else
			{
				float dist = zx * zx + zy * zy;
				if (dist > 4.0f && dist < 100.0f)
				{
					float smoothIter = (float)iterations + 1.0f - fast_log2(fast_log2(dist));
					smoothIter = (smoothIter < 0.0f) ? 0.0f : smoothIter;
					value = smoothIter * invMaxIter;
				}
				else
				{
					value = (float)iterations * invMaxIter;
				}
				value = (value > 1.0f) ? 1.0f : value;
			}

			monochrome = (u8)(value * 255.0);
			frame[iPixelAddr] = monochrome;
			frame[iPixelAddr + 1] = monochrome;
			frame[iPixelAddr + 2] = monochrome;
			iPixelAddr += 3;
			cx += xScale;
		}
	}
	
	Xil_DCacheFlushRange((unsigned int) frame, height * stride);
}

/*
 * Wave Interference Pattern - Animated sine wave interference
 */
void DemoWavePattern(u8 *frame, u32 width, u32 height, u32 stride, float time)
{
	u32 xcoi, ycoi;
	u32 iPixelAddr;
	u32 phaseX1, phaseY2, phaseXY;
	const u32 phaseStepX1 = rad_to_phase(0.1f);
	const u32 phaseStepY2 = rad_to_phase(0.1f);
	const u32 phaseStepXY = rad_to_phase(0.07f);
	const u32 phaseTime1 = rad_to_phase(time * 20.0f);
	const u32 phaseTime2 = rad_to_phase(time * 15.0f);
	const u32 phaseTime3 = rad_to_phase(time * 25.0f);

	for(ycoi = 0; ycoi < height; ycoi++)
	{
		float wave2;
		iPixelAddr = ycoi * stride;
		phaseX1 = phaseTime1;
		phaseY2 = phaseTime2 + (u32)ycoi * phaseStepY2;
		phaseXY = phaseTime3 + (u32)ycoi * phaseStepXY;
		wave2 = fast_sin_phase(phaseY2);

		for(xcoi = 0; xcoi < width; xcoi++)
		{
			float wave1 = fast_sin_phase(phaseX1);
			float wave3 = fast_sin_phase(phaseXY);
			int mono = (int)((wave1 + wave2 + wave3 + 3.0f) * (255.0f / 6.0f));
			u8 monochrome;

			mono = (mono < 0) ? 0 : mono;
			mono = (mono > 255) ? 255 : mono;
			monochrome = (u8)mono;

			frame[iPixelAddr] = monochrome;
			frame[iPixelAddr + 1] = monochrome;
			frame[iPixelAddr + 2] = monochrome;

			iPixelAddr += 3;
			phaseX1 += phaseStepX1;
			phaseXY += phaseStepXY;
		}
	}
	
	Xil_DCacheFlushRange((unsigned int) frame, height * stride);
}

/*
 * Julia Fractal - Evolving Julia set with changing constant
 */
void DemoGradientPattern(u8 *frame, u32 width, u32 height, u32 stride, float time)
{
	u32 xcoi, ycoi;
	u32 iPixelAddr;
	u8 monochrome;
	float zx, zy;   /* Iteration variables */
	float zx2, zy2; /* Squared values for optimization */
	u32 iterations;
	u32 maxIterations = 50;
	float value;
	
	float invWidth = 1.0f / (float)width;
	float invHeight = 1.0f / (float)height;
	float invMaxIter = 1.0f / (float)maxIterations;
	
	float cReal = 0.7885f * fast_cos(time * 0.1f);
	float cImag = 0.7885f * fast_sin(time * 0.1f);
	
	float scale = 3.0f;
	float offsetX = 0.0f;
	float offsetY = 0.0f;
	
	float yScale = scale * invHeight;
	float yOffset = (offsetY - 0.5f * scale);
	
	float xScale = scale * invWidth;
	float xOffset = (offsetX - 0.5f * scale);
	
	for(ycoi = 0; ycoi < height; ycoi++)
	{
		float zxStart = xOffset;
		float zyStart = (float)ycoi * yScale + yOffset;
		iPixelAddr = ycoi * stride;
		
		for(xcoi = 0; xcoi < width; xcoi++)
		{
			zx = zxStart;
			zy = zyStart;
			iterations = 0;
			
			while (iterations < maxIterations)
			{
				zx2 = zx * zx;
				zy2 = zy * zy;
				if (zx2 + zy2 > 4.0f)
					break;
				{
					float temp = zx2 - zy2 + cReal;
					zy = 2.0f * zx * zy + cImag;
					zx = temp;
				}
				iterations++;
			}
			
			if (iterations >= maxIterations)
			{
				value = 0.0f;
			}
			else
			{
				float dist = zx * zx + zy * zy;
				if (dist > 4.0f && dist < 100.0f)
				{
					float smoothIter = (float)iterations + 1.0f - fast_log2(fast_log2(dist));
					smoothIter = (smoothIter < 0.0f) ? 0.0f : smoothIter;
					value = smoothIter * invMaxIter;
				}
				else
				{
					value = (float)iterations * invMaxIter;
				}
				value = (value > 1.0f) ? 1.0f : value;
			}

			monochrome = (u8)(value * 255.0);
			frame[iPixelAddr] = monochrome;
			frame[iPixelAddr + 1] = monochrome;
			frame[iPixelAddr + 2] = monochrome;
			iPixelAddr += 3;
			zxStart += xScale;
		}
	}
	
	Xil_DCacheFlushRange((unsigned int) frame, height * stride);
}

/*
 * Moiré Pattern - Overlapping grids creating interference patterns
 * Slow-evolving pattern similar to wave interference
 */
void DemoMoirePattern(u8 *frame, u32 width, u32 height, u32 stride, float time)
{
	u32 xcoi, ycoi;
	u32 iPixelAddr;
	float centerX = (float)width * 0.5f;
	float centerY = (float)height * 0.5f;
	const float angle = time * 0.05f;
	const float cosA = fast_cos(angle);
	const float sinA = fast_sin(angle);
	const u32 phaseStepX = rad_to_phase(0.08f);
	const u32 phaseStepY = rad_to_phase(0.08f);
	const u32 phaseTime1 = rad_to_phase(time * 12.0f);
	const u32 phaseTime2 = rad_to_phase(time * 10.0f);
	const u32 phaseTime3 = rad_to_phase(time * 8.0f);
	
	for(ycoi = 0; ycoi < height; ycoi++)
	{
		float dy = (float)ycoi - centerY;
		float rotX = (-centerX) * cosA - dy * sinA;
		float rotY = (-centerX) * sinA + dy * cosA;
		u32 phaseX = phaseTime2;
		u32 phaseY = phaseTime1 + ycoi * phaseStepY;
		float grid1 = fast_sin_phase(phaseY);
		iPixelAddr = ycoi * stride;
		
		for(xcoi = 0; xcoi < width; xcoi++)
		{
			float grid2 = fast_sin_phase(phaseX);
			float grid3 = fast_sin_phase(rad_to_phase((rotX + rotY) * 0.06f) + phaseTime3);
			int mono = (int)((grid1 + grid2 + grid3 + 3.0f) * (255.0f / 6.0f));
			u8 monochrome;

			mono = (mono < 0) ? 0 : mono;
			mono = (mono > 255) ? 255 : mono;
			monochrome = (u8)mono;
			
			// Write monochrome value to all RGB channels
			frame[iPixelAddr] = monochrome;
			frame[iPixelAddr + 1] = monochrome;
			frame[iPixelAddr + 2] = monochrome;
			
			iPixelAddr += 3;
			phaseX += phaseStepX;
			rotX += cosA;
			rotY += sinA;
		}
	}
	
	Xil_DCacheFlushRange((unsigned int) frame, height * stride);
}

/*
 * Standing Wave Pattern - Waves that appear stationary but evolve
 * Similar to interference pattern but with standing wave characteristics
 */
void DemoStandingWavePattern(u8 *frame, u32 width, u32 height, u32 stride, float time)
{
	u32 xcoi, ycoi;
	u32 iPixelAddr;
	u8 monochrome;
	double x, y;
	double wave1, wave2, wave3;
	double combined;
	double centerX = width / 2.0;
	double centerY = height / 2.0;
	
	for(ycoi = 0; ycoi < height; ycoi++)
	{
		y = (double)ycoi;
		iPixelAddr = ycoi * stride;
		
		for(xcoi = 0; xcoi < width; xcoi++)
		{
			x = (double)xcoi;
			
			// Create standing waves - waves that don't move but amplitude changes
			// Wave 1: Horizontal standing wave
			wave1 = fast_sin(x * 0.12f) * fast_sin(time * 8.0f);
			
			// Wave 2: Vertical standing wave
			wave2 = fast_sin(y * 0.12f) * fast_sin(time * 10.0f);
			
			// Wave 3: Radial standing wave from center
			double dx = x - centerX;
			double dy = y - centerY;
			double dist = fast_sqrt(dx * dx + dy * dy);
			wave3 = fast_sin(dist * 0.1f) * fast_sin(time * 6.0f);
			
			// Combine waves to create interference
			combined = (wave1 + wave2 + wave3) / 3.0;
			combined = (combined + 1.0) / 2.0; // Normalize to 0-1
			
			// Clamp and convert to monochrome (0-255)
			if (combined < 0.0) combined = 0.0;
			if (combined > 1.0) combined = 1.0;
			monochrome = (u8)(combined * 255.0);
			
			// Write monochrome value to all RGB channels
			frame[iPixelAddr] = monochrome;
			frame[iPixelAddr + 1] = monochrome;
			frame[iPixelAddr + 2] = monochrome;
			
			iPixelAddr += 3;
		}
	}
	
	Xil_DCacheFlushRange((unsigned int) frame, height * stride);
}

/*
 * Lissajous Pattern - Parametric curves creating evolving patterns
 * Slow-evolving interference-like pattern
 */
void DemoLissajousPattern(u8 *frame, u32 width, u32 height, u32 stride, float time)
{
	u32 xcoi, ycoi;
	u32 iPixelAddr;
	u8 monochrome;
	double x, y;
	double centerX = width / 2.0;
	double centerY = height / 2.0;
	double dx, dy;
	double lissajous1, lissajous2, lissajous3;
	double combined;
	
	for(ycoi = 0; ycoi < height; ycoi++)
	{
		y = (double)ycoi;
		iPixelAddr = ycoi * stride;
		
		for(xcoi = 0; xcoi < width; xcoi++)
		{
			x = (double)xcoi;
			dx = (x - centerX) / (width * 0.5);
			dy = (y - centerY) / (height * 0.5);
			
			// Create Lissajous curves with different frequency ratios
			// Lissajous 1: 3:2 ratio
			lissajous1 = fast_sin(3.0f * dx + time * 5.0f) * fast_sin(2.0f * dy + time * 5.0f);
			
			// Lissajous 2: 5:3 ratio
			lissajous2 = fast_sin(5.0f * dx + time * 4.0f) * fast_sin(3.0f * dy + time * 4.0f);
			
			// Lissajous 3: 4:1 ratio
			lissajous3 = fast_sin(4.0f * dx + time * 6.0f) * fast_sin(1.0f * dy + time * 6.0f);
			
			// Combine to create interference pattern
			combined = (lissajous1 + lissajous2 + lissajous3) / 3.0;
			combined = (combined + 1.0) / 2.0; // Normalize to 0-1
			
			// Clamp and convert to monochrome (0-255)
			if (combined < 0.0) combined = 0.0;
			if (combined > 1.0) combined = 1.0;
			monochrome = (u8)(combined * 255.0);
			
			// Write monochrome value to all RGB channels
			frame[iPixelAddr] = monochrome;
			frame[iPixelAddr + 1] = monochrome;
			frame[iPixelAddr + 2] = monochrome;
			
			iPixelAddr += 3;
		}
	}
	
	Xil_DCacheFlushRange((unsigned int) frame, height * stride);
}

/*
 * Flow Field Pattern - Vector field visualization with slow evolution
 * Creates organic, flowing interference-like patterns
 */
void DemoFlowFieldPattern(u8 *frame, u32 width, u32 height, u32 stride, float time)
{
	u32 xcoi, ycoi;
	u32 iPixelAddr;
	u8 monochrome;
	double x, y;
	double flow1, flow2, flow3;
	double combined;
	double centerX = width / 2.0;
	double centerY = height / 2.0;
	double dx, dy;
	double angle, radius;
	
	for(ycoi = 0; ycoi < height; ycoi++)
	{
		y = (double)ycoi;
		iPixelAddr = ycoi * stride;
		
		for(xcoi = 0; xcoi < width; xcoi++)
		{
			x = (double)xcoi;
			dx = x - centerX;
			dy = y - centerY;
			angle = fast_atan2(dy, dx);
			radius = fast_sqrt(dx * dx + dy * dy);
			
			// Create flow field with multiple components
			// Flow 1: Radial flow with slow rotation
			flow1 = fast_sin(radius * 0.08f + angle * 2.0f + time * 3.0f);
			
			// Flow 2: Perlin-like noise using sine waves
			flow2 = fast_sin(x * 0.05f + time * 2.0f) * fast_sin(y * 0.05f + time * 2.0f);
			flow2 += fast_sin(x * 0.1f + time * 3.0f) * 0.5;
			flow2 += fast_sin(y * 0.1f + time * 3.0f) * 0.5;
			flow2 = flow2 / 2.0;
			
			// Flow 3: Spiral flow field
			flow3 = fast_sin(angle * 3.0f + radius * 0.06f + time * 4.0f);
			
			// Combine flows to create interference pattern
			combined = (flow1 + flow2 + flow3) / 3.0;
			combined = (combined + 1.0) / 2.0; // Normalize to 0-1
			
			// Clamp and convert to monochrome (0-255)
			if (combined < 0.0) combined = 0.0;
			if (combined > 1.0) combined = 1.0;
			monochrome = (u8)(combined * 255.0);
			
			// Write monochrome value to all RGB channels
			frame[iPixelAddr] = monochrome;
			frame[iPixelAddr + 1] = monochrome;
			frame[iPixelAddr + 2] = monochrome;
			
			iPixelAddr += 3;
		}
	}
	
	Xil_DCacheFlushRange((unsigned int) frame, height * stride);
}

/*
 * Global flag to signal exit from pattern drawing
 * Set by CheckForExit() which should be called periodically
 */
static volatile char g_shouldExitPattern = 0;

// /*
//  * Global flag to signal exit from pattern drawing
//  */
// static volatile char g_shouldExitPattern = 0;

/*
 * Helper function to check if user wants to exit (non-blocking)
 * Returns 1 if exit requested, 0 otherwise
 */
static char CheckForExit(void)
{
	if (XUartPs_IsReceiveData(UART_BASEADDR))
	{
		g_shouldExitPattern = 1;
		return 1;
	}
	return 0;
}

/*
 * The pattern menu reads the selection key, then this runner prints a banner.
 * Terminals send CR/LF a few milliseconds after that key. The old main-menu
 * path printed first and flushed after, so the newline never counted as stop.
 * Eat only CR/LF for a short window. Any other byte still stops the pattern.
 */
static void DemoDrainPatternEnter(void)
{
	u32 slice;

	for (slice = 0U; slice < 40U; slice++)
	{
		TimerDelay(1000);
		MidiUartPoll();
		while (XUartPs_IsReceiveData(UART_BASEADDR) != 0)
		{
			char rx = (char)XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);

			if ((rx != '\r') && (rx != '\n'))
			{
				g_shouldExitPattern = 1;
			}
		}
		if (g_shouldExitPattern != 0)
		{
			return;
		}
	}
}

#define DEMO_BLOCK_COLS 5
#define DEMO_BLOCK_ROWS 3

static u32 g_patRng = 0xA5A5A5A5U;
static u8 g_blockRgb[DEMO_BLOCK_ROWS][DEMO_BLOCK_COLS][3];
static int g_blockInited = 0;

static u32 DemoPatRandom(void)
{
	g_patRng = (g_patRng * 1664525U) + 1013904223U;
	return g_patRng;
}

static void DemoHueRgb(u32 t, u8 *r, u8 *g, u8 *b)
{
	u32 h = t % 1536U;
	u32 seg = h / 256U;
	u8 x = (u8)(h & 255U);

	switch (seg)
	{
	case 0:
		*r = 255U;
		*g = x;
		*b = 0U;
		break;
	case 1:
		*r = (u8)(255U - x);
		*g = 255U;
		*b = 0U;
		break;
	case 2:
		*r = 0U;
		*g = 255U;
		*b = x;
		break;
	case 3:
		*r = 0U;
		*g = (u8)(255U - x);
		*b = 255U;
		break;
	case 4:
		*r = x;
		*g = 0U;
		*b = 255U;
		break;
	default:
		*r = 255U;
		*g = 0U;
		*b = (u8)(255U - x);
		break;
	}
}

static void DemoFillRgbRect(u8 *frame, u32 width, u32 height, u32 stride,
	u32 x0, u32 y0, u32 rw, u32 rh, u8 r, u8 g, u8 b)
{
	u32 y;
	u32 x;

	if ((x0 >= width) || (y0 >= height))
	{
		return;
	}
	if ((x0 + rw) > width)
	{
		rw = width - x0;
	}
	if ((y0 + rh) > height)
	{
		rh = height - y0;
	}
	{
		u8 *first = frame + (y0 * stride) + (x0 * 3U);
		u8 *p = first;

		for (x = 0U; x < rw; x++)
		{
			p[0] = r;
			p[1] = g;
			p[2] = b;
			p += 3;
		}
		for (y = 1U; y < rh; y++)
		{
			memcpy(frame + ((y0 + y) * stride) + (x0 * 3U), first, rw * 3U);
		}
	}
}

static void DemoDrawRgbLine(u8 *frame, u32 width, u32 height, u32 stride,
	int x0, int y0, int x1, int y1, u8 r, u8 g, u8 b)
{
	int dx = (x1 > x0) ? (x1 - x0) : (x0 - x1);
	int sx = (x0 < x1) ? 1 : -1;
	int dy = (y1 > y0) ? (y0 - y1) : (y1 - y0);
	int sy = (y0 < y1) ? 1 : -1;
	int err = dx + dy;

	for (;;)
	{
		if ((x0 >= 0) && (y0 >= 0) && ((u32)x0 < width) && ((u32)y0 < height))
		{
			u8 *p = frame + ((u32)y0 * stride) + ((u32)x0 * 3U);
			p[0] = r;
			p[1] = g;
			p[2] = b;
		}
		if ((x0 == x1) && (y0 == y1))
		{
			break;
		}
		{
			int e2 = err * 2;
			if (e2 >= dy)
			{
				err += dy;
				x0 += sx;
			}
			if (e2 <= dx)
			{
				err += dx;
				y0 += sy;
			}
		}
	}
}

void DemoColorBlockPattern(u8 *frame, u32 width, u32 height, u32 stride, float time)
{
	u32 tx;
	u32 ty;
	u32 tw;
	u32 th;
	u32 n;
	(void)time;

	if ((width < 2U) || (height < 2U))
	{
		return;
	}
	tw = width / DEMO_BLOCK_COLS;
	th = height / DEMO_BLOCK_ROWS;
	if (tw == 0U)
	{
		tw = 1U;
	}
	if (th == 0U)
	{
		th = 1U;
	}

	if (g_blockInited == 0)
	{
		for (ty = 0U; ty < DEMO_BLOCK_ROWS; ty++)
		{
			for (tx = 0U; tx < DEMO_BLOCK_COLS; tx++)
			{
				u32 rng = DemoPatRandom();
				g_blockRgb[ty][tx][0] = (u8)(rng >> 24);
				g_blockRgb[ty][tx][1] = (u8)(rng >> 16);
				g_blockRgb[ty][tx][2] = (u8)(rng >> 8);
			}
		}
		g_blockInited = 1;
	}

	for (n = 0U; n < 2U; n++)
	{
		u32 rng = DemoPatRandom();
		int ch;
		int next;

		ty = (rng >> 8) % DEMO_BLOCK_ROWS;
		tx = (rng >> 16) % DEMO_BLOCK_COLS;
		ch = (int)((rng >> 24) % 3U);
		next = (int)g_blockRgb[ty][tx][ch] + (int)(((rng >> 3) & 31U) - 16);
		if (next < 0)
		{
			next = 0;
		}
		if (next > 255)
		{
			next = 255;
		}
		g_blockRgb[ty][tx][ch] = (u8)next;
	}

	for (ty = 0U; ty < DEMO_BLOCK_ROWS; ty++)
	{
		for (tx = 0U; tx < DEMO_BLOCK_COLS; tx++)
		{
			DemoFillRgbRect(frame, width, height, stride,
				tx * tw, ty * th,
				(tx == (DEMO_BLOCK_COLS - 1U)) ? (width - tx * tw) : tw,
				(ty == (DEMO_BLOCK_ROWS - 1U)) ? (height - ty * th) : th,
				g_blockRgb[ty][tx][0],
				g_blockRgb[ty][tx][1],
				g_blockRgb[ty][tx][2]);
		}
	}
	Xil_DCacheFlushRange((unsigned int)frame, height * stride);
}

void DemoWhiteNoisePattern(u8 *frame, u32 width, u32 height, u32 stride, float time)
{
	u32 y;
	u32 x;
	u32 rng = g_patRng;
	(void)time;

	for (y = 0U; y < height; y++)
	{
		u8 *p = frame + (y * stride);
		for (x = 0U; x < width; x++)
		{
			rng = (rng * 1664525U) + 1013904223U;
			p[0] = (u8)(rng >> 24);
			p[1] = p[0];
			p[2] = p[0];
			p += 3;
		}
	}
	g_patRng = rng;
	Xil_DCacheFlushRange((unsigned int)frame, height * stride);
}

void DemoRandomBoxPattern(u8 *frame, u32 width, u32 height, u32 stride, u32 count)
{
	u32 i;

	if ((width < 8U) || (height < 8U) || (count == 0U))
	{
		return;
	}
	for (i = 0U; i < count; i++)
	{
		u32 rng = DemoPatRandom();
		u32 rw = 16U + (rng % (width / 2U));
		u32 rh = 16U + ((rng >> 8) % (height / 2U));
		u32 x0 = (rng >> 16) % width;
		u32 y0 = (DemoPatRandom() >> 16) % height;
		u8 r = (u8)(rng >> 24);
		u8 g = (u8)(rng >> 8);
		u8 b = (u8)rng;

		DemoFillRgbRect(frame, width, height, stride, x0, y0, rw, rh, r, g, b);
	}
	Xil_DCacheFlushRange((unsigned int)frame, height * stride);
}

void DemoRandomLinePattern(u8 *frame, u32 width, u32 height, u32 stride, u32 count)
{
	u32 i;

	if ((width < 2U) || (height < 2U) || (count == 0U))
	{
		return;
	}
	for (i = 0U; i < count; i++)
	{
		u32 rng = DemoPatRandom();
		int x0 = (int)(rng % width);
		int y0 = (int)((rng >> 10) % height);
		int x1 = (int)((rng >> 16) % width);
		int y1 = (int)(DemoPatRandom() % height);
		u8 r = (u8)(rng >> 24);
		u8 g = (u8)(rng >> 8);
		u8 b = (u8)rng;

		DemoDrawRgbLine(frame, width, height, stride, x0, y0, x1, y1, r, g, b);
		if ((y0 + 1) < (int)height)
		{
			DemoDrawRgbLine(frame, width, height, stride, x0, y0 + 1, x1, y1 + 1, r, g, b);
		}
	}
	Xil_DCacheFlushRange((unsigned int)frame, height * stride);
}

void DemoColorWashPattern(u8 *frame, u32 width, u32 height, u32 stride, float time)
{
	u8 r;
	u8 g;
	u8 b;
	u32 y;
	u32 x;

	DemoHueRgb((u32)(time * 8.0f), &r, &g, &b);
	{
		u8 *first = frame;
		u8 *p = first;

		for (x = 0U; x < width; x++)
		{
			p[0] = r;
			p[1] = g;
			p[2] = b;
			p += 3;
		}
		for (y = 1U; y < height; y++)
		{
			memcpy(frame + (y * stride), first, width * 3U);
		}
	}
	Xil_DCacheFlushRange((unsigned int)frame, height * stride);
}

void DemoSlidingBarPattern(u8 *frame, u32 width, u32 height, u32 stride, float time)
{
	u32 y;
	u32 x;
	u32 bandH;
	u32 shift;

	bandH = height / 8U;
	if (bandH < 4U)
	{
		bandH = 4U;
	}
	shift = ((u32)time * 3U);

	{
		u8 prevR = 1U;
		u8 prevG = 0U;
		u8 prevB = 0U;
		u8 *prevRow = NULL;

		for (y = 0U; y < height; y++)
		{
			u8 r;
			u8 g;
			u8 b;
			u8 *p = frame + (y * stride);

			DemoHueRgb(((y + shift) / bandH) * 180U, &r, &g, &b);
			if ((prevRow != NULL) && (r == prevR) && (g == prevG) && (b == prevB))
			{
				memcpy(p, prevRow, width * 3U);
			}
			else
			{
				u8 *q = p;
				for (x = 0U; x < width; x++)
				{
					q[0] = r;
					q[1] = g;
					q[2] = b;
					q += 3;
				}
			}
			prevRow = p;
			prevR = r;
			prevG = g;
			prevB = b;
		}
	}
	Xil_DCacheFlushRange((unsigned int)frame, height * stride);
}

void DemoSnowPattern(u8 *frame, u32 width, u32 height, u32 stride, u32 count)
{
	u32 i;

	if ((width == 0U) || (height == 0U))
	{
		return;
	}
	for (i = 0U; i < count; i++)
	{
		u32 rng = DemoPatRandom();
		u32 x = rng % width;
		u32 y = (rng >> 16) % height;
		u8 *p = frame + (y * stride) + (x * 3U);
		p[0] = 255U;
		p[1] = 255U;
		p[2] = 255U;
	}
	Xil_DCacheFlushRange((unsigned int)frame, height * stride);
}

static int DemoIsPersistPattern(int pattern)
{
	return ((pattern == DEMO_PATTERN_RANDOM_BOXES) ||
		(pattern == DEMO_PATTERN_RANDOM_LINES) ||
		(pattern == DEMO_PATTERN_SNOW));
}

/*
 * Fast nearest-neighbor upscaling from low-res to high-res
 * Much faster than bilinear interpolation
 */
void DemoFastScalePattern(u8 *lowResFrame, u32 lowWidth, u32 lowHeight, u32 lowStride,
                          u8 *highResFrame, u32 highWidth, u32 highHeight, u32 highStride)
{
	u32 xcoi, ycoi;
	u32 srcX, srcY;
	u32 srcAddr, destAddr;
	u32 xScale, yScale;

	if ((lowWidth > 0U) && (lowHeight > 0U) &&
		((highWidth % lowWidth) == 0U) && ((highHeight % lowHeight) == 0U))
	{
		u32 sx = highWidth / lowWidth;
		u32 sy = highHeight / lowHeight;
		u32 rowBytes = highWidth * 3U;

		for (srcY = 0U; srcY < lowHeight; srcY++)
		{
			const u8 *s = lowResFrame + (srcY * lowStride);
			u8 *dstRow = highResFrame + ((srcY * sy) * highStride);
			u8 *d = dstRow;
			u32 k;

			for (srcX = 0U; srcX < lowWidth; srcX++)
			{
				u8 r = s[0];
				u8 g = s[1];
				u8 b = s[2];

				s += 3;
				for (k = 0U; k < sx; k++)
				{
					d[0] = r;
					d[1] = g;
					d[2] = b;
					d += 3;
				}
			}
			for (k = 1U; k < sy; k++)
			{
				memcpy(dstRow + (k * highStride), dstRow, rowBytes);
			}
		}
		Xil_DCacheFlushRange((unsigned int)highResFrame, highHeight * highStride);
		return;
	}

	xScale = (lowWidth << 16) / highWidth;
	yScale = (lowHeight << 16) / highHeight;

	for (ycoi = 0; ycoi < highHeight; ycoi++)
	{
		srcY = (ycoi * yScale) >> 16;
		if (srcY >= lowHeight)
		{
			srcY = lowHeight - 1;
		}

		destAddr = ycoi * highStride;
		srcAddr = srcY * lowStride;

		for (xcoi = 0; xcoi < highWidth; xcoi++)
		{
			srcX = (xcoi * xScale) >> 16;
			if (srcX >= lowWidth)
			{
				srcX = lowWidth - 1;
			}

			highResFrame[destAddr] = lowResFrame[srcAddr + srcX * 3];
			highResFrame[destAddr + 1] = lowResFrame[srcAddr + srcX * 3 + 1];
			highResFrame[destAddr + 2] = lowResFrame[srcAddr + srcX * 3 + 2];
			destAddr += 3;
		}
	}

	Xil_DCacheFlushRange((unsigned int)highResFrame, highHeight * highStride);
}

/*
 * Helper function to run an animated pattern
 * Uses lower resolution rendering + upscaling for speed
 */
void DemoRunAnimatedPattern(u8 *frame, u32 width, u32 height, u32 stride, int pattern, u32 durationMs)
{
	float time = 0.0f;
	u32 frameCount = 0;
	u32 currentFrameIdx = dispCtrl.curFrame;
	u32 nextFrameIdx;
	char shouldExit = 0;
	u32 scaleFactor = 4;
	u32 lowWidth;
	u32 lowHeight;
	u32 lowStride;
	static u8 lowResBuffer[960 * 540 * 3] __attribute__((aligned(0x20)));
	(void)frame;
	(void)durationMs;

	while (XUartPs_IsReceiveData(UART_BASEADDR))
	{
		XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
	}
	g_shouldExitPattern = 0;

	if (DemoIsPersistPattern(pattern))
	{
		int destIdx = DemoEffectDestFrame();
		u8 *dest = pFrames[destIdx];

		memset(dest, 0, height * stride);
		Xil_DCacheFlushRange((unsigned int)dest, height * stride);
		DisplayChangeFrame(&dispCtrl, destIdx);
		xil_printf("\n\rRunning accumulating pattern. Press any key to stop\n\r");
		DemoDrainPatternEnter();

		while (!shouldExit)
		{
			MidiUartPoll();
			if (CheckForExit() || g_shouldExitPattern)
			{
				shouldExit = 1;
				break;
			}
			if (pattern == DEMO_PATTERN_RANDOM_BOXES)
			{
				DemoRandomBoxPattern(dest, width, height, stride, 2U);
			}
			else if (pattern == DEMO_PATTERN_RANDOM_LINES)
			{
				DemoRandomLinePattern(dest, width, height, stride, 3U);
			}
			else
			{
				DemoSnowPattern(dest, width, height, stride, 180U);
			}
			if (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				shouldExit = 1;
				g_shouldExitPattern = 1;
			}
		}
		g_shouldExitPattern = 0;
		while (XUartPs_IsReceiveData(UART_BASEADDR))
		{
			XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
		}
		xil_printf("\n\rAnimation stopped by user\n\r");
		return;
	}

	if (pattern == DEMO_PATTERN_COLOR_BLOCKS)
	{
		scaleFactor = 16;
	}
	else if (pattern == DEMO_PATTERN_WHITE_NOISE)
	{
		scaleFactor = 2;
	}

	lowWidth = (width + scaleFactor - 1) / scaleFactor;
	lowHeight = (height + scaleFactor - 1) / scaleFactor;
	lowStride = lowWidth * 3;
	if ((lowWidth > 960U) || (lowHeight > 540U))
	{
		scaleFactor = 4;
		lowWidth = (width + scaleFactor - 1) / scaleFactor;
		lowHeight = (height + scaleFactor - 1) / scaleFactor;
		lowStride = lowWidth * 3;
	}

	xil_printf("\n\rRunning animated pattern at %dx%d (scaled from %dx%d)... Press any key to stop\n\r",
		width, height, lowWidth, lowHeight);
	DemoDrainPatternEnter();

	while (!shouldExit)
	{
		// Check for exit before starting
		if (CheckForExit() || g_shouldExitPattern)
		{
			shouldExit = 1;
			break;
		}
		
		// Get next available frame buffer for triple buffering
		nextFrameIdx = (currentFrameIdx + 1) % DISPLAY_NUM_FRAMES;
		if (nextFrameIdx == videoCapt.curFrame && videoCapt.state == VIDEO_STREAMING)
		{
			nextFrameIdx = (nextFrameIdx + 1) % DISPLAY_NUM_FRAMES;
		}
		
		// Render pattern at LOW resolution first (much faster!)
		switch(pattern)
		{
		case DEMO_PATTERN_PLASMA:
			DemoPlasmaPattern(lowResBuffer, lowWidth, lowHeight, lowStride, time);
			break;
		case DEMO_PATTERN_SPIRAL:
			DemoSpiralPattern(lowResBuffer, lowWidth, lowHeight, lowStride, time);
			break;
		case DEMO_PATTERN_RIPPLE:
			DemoRipplePattern(lowResBuffer, lowWidth, lowHeight, lowStride, time);
			break;
		case DEMO_PATTERN_WAVES:
			DemoWavePattern(lowResBuffer, lowWidth, lowHeight, lowStride, time);
			break;
		case DEMO_PATTERN_GRADIENT:
			DemoGradientPattern(lowResBuffer, lowWidth, lowHeight, lowStride, time);
			break;
		case DEMO_PATTERN_MOIRE:
			DemoMoirePattern(lowResBuffer, lowWidth, lowHeight, lowStride, time);
			break;
		case DEMO_PATTERN_STANDING_WAVE:
			DemoStandingWavePattern(lowResBuffer, lowWidth, lowHeight, lowStride, time);
			break;
		case DEMO_PATTERN_LISSAJOUS:
			DemoLissajousPattern(lowResBuffer, lowWidth, lowHeight, lowStride, time);
			break;
		case DEMO_PATTERN_FLOW_FIELD:
			DemoFlowFieldPattern(lowResBuffer, lowWidth, lowHeight, lowStride, time);
			break;
		case DEMO_PATTERN_COLOR_BLOCKS:
			DemoColorBlockPattern(lowResBuffer, lowWidth, lowHeight, lowStride, time);
			break;
		case DEMO_PATTERN_WHITE_NOISE:
			DemoWhiteNoisePattern(lowResBuffer, lowWidth, lowHeight, lowStride, time);
			break;
		case DEMO_PATTERN_COLOR_WASH:
			DemoColorWashPattern(lowResBuffer, lowWidth, lowHeight, lowStride, time);
			break;
		case DEMO_PATTERN_SLIDING_BARS:
			DemoSlidingBarPattern(lowResBuffer, lowWidth, lowHeight, lowStride, time);
			break;
		default:
			xil_printf("\n\rInvalid pattern type\n\r");
			return;
		}
		
		// Check for exit after low-res rendering
		if (CheckForExit() || g_shouldExitPattern)
		{
			shouldExit = 1;
			break;
		}
		
		// Upscale from low-res to full resolution (fast nearest-neighbor)
		DemoFastScalePattern(lowResBuffer, lowWidth, lowHeight, lowStride,
		                     pFrames[nextFrameIdx], width, height, stride);
		
		// Check for exit after upscaling
		if (CheckForExit() || g_shouldExitPattern)
		{
			shouldExit = 1;
			break;
		}
		
		// Switch display to show the new frame
		DisplayChangeFrame(&dispCtrl, nextFrameIdx);
		currentFrameIdx = nextFrameIdx;
		frameCount++;
		MidiUartPoll();

		if ((pattern == DEMO_PATTERN_COLOR_BLOCKS) ||
			(pattern == DEMO_PATTERN_COLOR_WASH) ||
			(pattern == DEMO_PATTERN_SLIDING_BARS))
		{
			time += 1.0f;
		}
		else
		{
			time += 5.0f;
		}
		if (time > 10000.0f)
		{
			time = 0.0f;
		}

		{
			u32 i;
			u32 wait = ((pattern == DEMO_PATTERN_COLOR_BLOCKS) ||
				(pattern == DEMO_PATTERN_COLOR_WASH)) ? 80U : 20U;

			for (i = 0U; i < wait; i++)
			{
				if (XUartPs_IsReceiveData(UART_BASEADDR))
				{
					shouldExit = 1;
					g_shouldExitPattern = 1;
					break;
				}
			}
		}
	}
	
	// Clear exit flag
	g_shouldExitPattern = 0;
	
	if(shouldExit || CheckForExit())
	{
		// Clear the input
		while (XUartPs_IsReceiveData(UART_BASEADDR))
		{
			XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
		}
		xil_printf("\n\rAnimation stopped by user\n\r");
	}
	else
	{
		xil_printf("\n\rAnimation completed (%d frames)\n\r", frameCount);
	}
	
	return;
}

/* ------------------------------------------------------------ */
/*				Video Effect Functions							*/
/* ------------------------------------------------------------ */

void DemoMirrorEffect(u8 *srcFrame, u8 *destFrame, u32 width, u32 height, u32 stride, int mirrorType)
{
	LiveFxMirror(srcFrame, destFrame, width, height, stride, mirrorType);
}

void DemoTileEffect(u8 *srcFrame, u8 *destFrame, u32 srcWidth, u32 srcHeight, u32 destWidth, u32 destHeight, u32 stride, u32 tilesX, u32 tilesY)
{
	int mode = LIVE_FX_TILE_OFF;

	(void)srcWidth;
	(void)srcHeight;
	(void)destWidth;
	(void)destHeight;
	if ((tilesX == 2U) && (tilesY == 2U))
	{
		mode = LIVE_FX_TILE_2X2;
	}
	else if ((tilesX == 3U) && (tilesY == 3U))
	{
		mode = LIVE_FX_TILE_3X3;
	}
	else if ((tilesX == 4U) && (tilesY == 4U))
	{
		mode = LIVE_FX_TILE_4X4;
	}
	else if ((tilesX == 8U) && (tilesY == 8U))
	{
		mode = LIVE_FX_TILE_8X8;
	}
	else if ((tilesX == 16U) && (tilesY == 16U))
	{
		mode = LIVE_FX_TILE_16X16;
	}
	LiveFxTile(srcFrame, destFrame, destWidth, destHeight, stride, mode);
}

void DemoZoomEffect(u8 *srcFrame, u8 *destFrame, u32 width, u32 height, u32 stride, float zoom, float centerX, float centerY)
{
	int mode = LIVE_FX_ZOOM_OFF;

	(void)centerX;
	(void)centerY;
	if (zoom > 1.0f)
	{
		mode = LIVE_FX_ZOOM_IN;
	}
	else if (zoom < 1.0f)
	{
		mode = LIVE_FX_ZOOM_OUT;
	}
	LiveFxZoom(srcFrame, destFrame, width, height, stride, mode);
}

void DemoMosaicEffect(u8 *srcFrame, u8 *destFrame, u32 width, u32 height, u32 stride, u32 blockSize)
{
	int mode = LIVE_FX_MOSAIC_OFF;

	if (blockSize <= 8U)
	{
		mode = LIVE_FX_MOSAIC_8;
	}
	else if (blockSize <= 16U)
	{
		mode = LIVE_FX_MOSAIC_16;
	}
	else
	{
		mode = LIVE_FX_MOSAIC_32;
	}
	LiveFxMosaic(srcFrame, destFrame, width, height, stride, mode);
}

void Demo3DPlaneEffect(u8 *srcFrame, u8 *destFrame, u32 width, u32 height, u32 stride, float rotX, float rotY, float rotZ, float scale, float offsetX, float offsetY)
{
	LiveFxPlane3DRaw(srcFrame, destFrame, width, height, stride, rotX, rotY, rotZ, scale, offsetX, offsetY);
}

void DemoShrinkRandomEffect(u8 *srcFrame, u8 *destFrame, u32 srcWidth, u32 srcHeight, u32 destWidth, u32 destHeight, u32 stride)
{
	(void)srcWidth;
	(void)srcHeight;
	(void)destWidth;
	(void)destHeight;
	LiveFxShrinkRandom(srcFrame, destFrame, destWidth, destHeight, stride, 1);
}

/*
 * Run Animated 3D Effect - Continuously rotates image in 3D space
 * axis: 'X', 'Y', 'Z', or 'A' (all axes)
 * scale: scale factor for the image (0.7 = 70% size)
 */
void DemoRunAnimated3DEffect(u8 *srcFrame, u8 **pFrames, u32 srcFrameIdx, u32 srcWidth, u32 srcHeight, u32 srcStride, u32 destWidth, u32 destHeight, char axis, float scale, DisplayCtrl *dispCtrl, VideoCapture *videoCapt)
{
	(void)srcStride;
	float time = 0.0f;
	u32 frameCount = 0;
	u32 currentFrameIdx = dispCtrl->curFrame;
	u32 nextFrameIdx;
	char shouldExit = 0;
	const float PI = 3.14159265359f;
	
	// Flush UART FIFO
	while (XUartPs_IsReceiveData(UART_BASEADDR))
	{
		XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
	}
	
	g_shouldExitPattern = 0;
	
	// Main animation loop
	while(!shouldExit)
	{
		// Check for exit before starting
		if (CheckForExit() || g_shouldExitPattern)
		{
			shouldExit = 1;
			break;
		}

		if (videoCapt->state == VIDEO_STREAMING)
		{
			srcFrame = pFrames[videoCapt->curFrame];
			srcFrameIdx = videoCapt->curFrame;
			srcWidth = videoCapt->timing.HActiveVideo;
			srcHeight = videoCapt->timing.VActiveVideo;
			Xil_DCacheInvalidateRange((unsigned int)srcFrame, srcHeight * DEMO_STRIDE);
		}
		
		// Get next available frame buffer for triple buffering
		// Make sure we never overwrite the source frame
		nextFrameIdx = (currentFrameIdx + 1) % DISPLAY_NUM_FRAMES;
		
		// Skip if it's the video capture frame (if streaming)
		if (nextFrameIdx == videoCapt->curFrame && videoCapt->state == VIDEO_STREAMING)
		{
			nextFrameIdx = (nextFrameIdx + 1) % DISPLAY_NUM_FRAMES;
		}
		
		// CRITICAL: Never overwrite the source frame!
		if (nextFrameIdx == srcFrameIdx)
		{
			nextFrameIdx = (nextFrameIdx + 1) % DISPLAY_NUM_FRAMES;
			// If we wrapped around and hit video frame, skip it again
			if (nextFrameIdx == videoCapt->curFrame && videoCapt->state == VIDEO_STREAMING)
			{
				nextFrameIdx = (nextFrameIdx + 1) % DISPLAY_NUM_FRAMES;
			}
			// If we still hit source, skip one more
			if (nextFrameIdx == srcFrameIdx)
			{
				nextFrameIdx = (nextFrameIdx + 1) % DISPLAY_NUM_FRAMES;
			}
		}
		
		// Clear frame before applying effect
		DemoClearFrame(pFrames[nextFrameIdx], destWidth, destHeight, DEMO_STRIDE);
		
		// Calculate rotation angles based on time
		float rotX = 0.0f;
		float rotY = 0.0f;
		float rotZ = 0.0f;
		
		// Rotate through full 360 degrees (2*PI radians) over time
		// Use different speeds for different axes for variety
		float angle = (time * 0.1f); // Slow rotation
		if (angle > 2.0f * PI) angle -= 2.0f * PI;
		
		switch(axis)
		{
		case 'X':
		case 'x':
			// Rotate X axis: 0 to 60 degrees (PI/3)
			rotX = (fast_sin(angle) + 1.0f) * 0.5f * (PI / 3.0f); // Oscillate between 0 and 60 degrees
			break;
		case 'Y':
		case 'y':
			// Rotate Y axis: 0 to 60 degrees (PI/3)
			rotY = (fast_sin(angle) + 1.0f) * 0.5f * (PI / 3.0f); // Oscillate between 0 and 60 degrees
			break;
		case 'Z':
		case 'z':
			// Rotate Z axis: full 360 degree rotation
			rotZ = angle;
			break;
		case 'A':
		case 'a':
			// Rotate all axes with different speeds
			rotX = (fast_sin(angle) + 1.0f) * 0.5f * (PI / 3.0f);
			rotY = (fast_sin(angle * 1.3f) + 1.0f) * 0.5f * (PI / 3.0f);
			rotZ = angle * 0.5f;
			break;
		default:
			rotZ = angle;
			break;
		}
		
		// Apply 3D effect
		Demo3DPlaneEffect(srcFrame, pFrames[nextFrameIdx], srcWidth, srcHeight, DEMO_STRIDE, 
		                  rotX, rotY, rotZ, scale, 0.0f, 0.0f);
		
		// Check for exit after rendering
		if (CheckForExit() || g_shouldExitPattern)
		{
			shouldExit = 1;
			break;
		}
		
		// Switch display to show the new frame
		DisplayChangeFrame(dispCtrl, nextFrameIdx);
		currentFrameIdx = nextFrameIdx;
		frameCount++;
		
		// Increment time for next frame
		time += 1.0f;
		if(time > 1000.0f) time = 0.0f; // Wrap time to prevent overflow
		
		// Delay to allow frame to be displayed and control animation speed
		// Use a longer delay to ensure frames are visible
		u32 i;
		for (i = 0; i < 200; i++)  // Increased delay for better visibility
		{
			// Check for exit very frequently during delay
			if (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				shouldExit = 1;
				g_shouldExitPattern = 1;
				break;
			}
		}
	}
	
	// Clear exit flag
	g_shouldExitPattern = 0;
	
	// Clear the input
	while (XUartPs_IsReceiveData(UART_BASEADDR))
	{
		XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
	}
	
	xil_printf("\n\rAnimation stopped (%d frames)\n\r", frameCount);
}


