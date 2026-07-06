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
#include "xil_types.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "timer_ps/timer_ps.h"
#include "xparameters.h"

/* ------------------------------------------------------------ */
/*				Math Function Approximations					*/
/* ------------------------------------------------------------ */
/*
 * Simple math function implementations for embedded systems
 * These avoid linking the math library
 */

/* Fast sine approximation using lookup table */
static float fast_sin(float x)
{
	// Normalize to [0, 2*PI]
	const float PI = 3.14159265359f;
	const float TWO_PI = 6.28318530718f;
	
	// Wrap to [0, 2*PI]
	while (x < 0.0f) x += TWO_PI;
	while (x >= TWO_PI) x -= TWO_PI;
	
	// Taylor series approximation: sin(x) ≈ x - x³/6 + x⁵/120 - x⁷/5040
	float x2 = x * x;
	float x3 = x2 * x;
	float x5 = x3 * x2;
	float x7 = x5 * x2;
	
	return x - (x3 / 6.0f) + (x5 / 120.0f) - (x7 / 5040.0f);
}

/* Fast cosine using sin(x + PI/2) */
static float fast_cos(float x)
{
	const float PI = 3.14159265359f;
	return fast_sin(x + PI / 2.0f);
}

/* Fast square root using Newton's method */
static float fast_sqrt(float x)
{
	if (x < 0.0f) return 0.0f;
	if (x == 0.0f) return 0.0f;
	
	// Initial guess
	float result = x;
	float prev = 0.0f;
	
	// Newton's method: x_{n+1} = (x_n + x/x_n) / 2
	int iterations = 0;
	while (result != prev && iterations < 10)
	{
		prev = result;
		result = (result + x / result) * 0.5f;
		iterations++;
	}
	
	return result;
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
#define VID_VTC_IRPT_ID XPAR_FABRIC_V_TC_0_INTR
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
static void DemoSpriteRandomTest(u32 displayWidth, u32 displayHeight);

/*
 * Framebuffers for video data
 */
u8 frameBuf[DISPLAY_NUM_FRAMES][DEMO_MAX_FRAME] __attribute__((aligned(0x20)));
u8 *pFrames[DISPLAY_NUM_FRAMES]; //array of pointers to the frame buffers

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
	Status = DisplayStart(&dispCtrl);
	if (Status != XST_SUCCESS)
	{
		xil_printf("Couldn't start display during demo initialization%d\r\n", Status);
		return;
	}

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

	DemoPrintTest(dispCtrl.framePtr[dispCtrl.curFrame], dispCtrl.vMode.width, dispCtrl.vMode.height, dispCtrl.stride, DEMO_PATTERN_1);

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
		{}

		/* Store the first character in the UART receive FIFO and echo it */
		if (XUartPs_IsReceiveData(UART_BASEADDR))
		{
			userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			xil_printf("%c", userInput);
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
			if (videoCapt.state == VIDEO_STREAMING)
				VideoStop(&videoCapt);
			else
				VideoStart(&videoCapt);
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
			DemoRunAnimatedPattern(pFrames[dispCtrl.curFrame], dispCtrl.vMode.width, dispCtrl.vMode.height, DEMO_STRIDE, DEMO_PATTERN_PLASMA, 5000);
			break;
		case 'a':
		case 'A':
			DemoRunAnimatedPattern(pFrames[dispCtrl.curFrame], dispCtrl.vMode.width, dispCtrl.vMode.height, DEMO_STRIDE, DEMO_PATTERN_SPIRAL, 5000);
			break;
		case 'b':
		case 'B':
			DemoRunAnimatedPattern(pFrames[dispCtrl.curFrame], dispCtrl.vMode.width, dispCtrl.vMode.height, DEMO_STRIDE, DEMO_PATTERN_RIPPLE, 5000);
			break;
		case 'c':
		case 'C':
			DemoRunAnimatedPattern(pFrames[dispCtrl.curFrame], dispCtrl.vMode.width, dispCtrl.vMode.height, DEMO_STRIDE, DEMO_PATTERN_WAVES, 5000);
			break;
		case 'd':
		case 'D':
			DemoRunAnimatedPattern(pFrames[dispCtrl.curFrame], dispCtrl.vMode.width, dispCtrl.vMode.height, DEMO_STRIDE, DEMO_PATTERN_GRADIENT, 5000);
			break;
		case 'e':
		case 'E':
			DemoRunAnimatedPattern(pFrames[dispCtrl.curFrame], dispCtrl.vMode.width, dispCtrl.vMode.height, DEMO_STRIDE, DEMO_PATTERN_MOIRE, 5000);
			break;
		case 'f':
		case 'F':
			DemoRunAnimatedPattern(pFrames[dispCtrl.curFrame], dispCtrl.vMode.width, dispCtrl.vMode.height, DEMO_STRIDE, DEMO_PATTERN_STANDING_WAVE, 5000);
			break;
		case 'g':
		case 'G':
			DemoRunAnimatedPattern(pFrames[dispCtrl.curFrame], dispCtrl.vMode.width, dispCtrl.vMode.height, DEMO_STRIDE, DEMO_PATTERN_LISSAJOUS, 5000);
			break;
		case 'h':
		case 'H':
			DemoRunAnimatedPattern(pFrames[dispCtrl.curFrame], dispCtrl.vMode.width, dispCtrl.vMode.height, DEMO_STRIDE, DEMO_PATTERN_FLOW_FIELD, 5000);
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
			DemoSpriteRandomTest(dispCtrl.vMode.width, dispCtrl.vMode.height);
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
	xil_printf("2 - Change Display Framebuffer Index\n\r");
	xil_printf("3 - Print Blended Test Pattern to Display Framebuffer\n\r");
	xil_printf("4 - Print Color Bar Test Pattern to Display Framebuffer\n\r");
	xil_printf("0 - Print Grid Test Pattern (for 3D testing)\n\r");
	xil_printf("5 - Start/Stop Video stream into Video Framebuffer\n\r");
	xil_printf("6 - Change Video Framebuffer Index\n\r");
	xil_printf("7 - Grab Video Frame and invert colors\n\r");
	xil_printf("8 - Grab Video Frame and scale to Display resolution\n\r");
	xil_printf("9 - Plasma Pattern (animated)\n\r");
	xil_printf("A - Spiral Pattern (animated)\n\r");
	xil_printf("B - Mandelbrot Fractal (animated)\n\r");
	xil_printf("C - Wave Interference Pattern (animated)\n\r");
	xil_printf("D - Julia Fractal (animated)\n\r");
	xil_printf("E - Moiré Pattern (animated)\n\r");
	xil_printf("F - Standing Wave Pattern (animated)\n\r");
	xil_printf("G - Lissajous Pattern (animated)\n\r");
	xil_printf("H - Flow Field Pattern (animated)\n\r");
	xil_printf("I - Apply Video Effects Menu\n\r");
	xil_printf("J - Overlay VRAM Pattern Test (with transparency)\n\r");
	xil_printf("K - Sprite VRAM Test (random position)\n\r");
	xil_printf("q - Quit\n\r");
	xil_printf("\n\r");
	xil_printf("\n\r");
	xil_printf("Enter a selection:");
}

void DemoChangeRes()
{
	int fResSet = 0;
	int status;
	char userInput = 0;

	/* Flush UART FIFO */
	while (XUartPs_IsReceiveData(UART_BASEADDR))
	{
		XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
	}

	while (!fResSet)
	{
		DemoCRMenu();

		/* Wait for data on UART */
		while (!XUartPs_IsReceiveData(UART_BASEADDR))
		{}

		/* Store the first character in the UART recieve FIFO and echo it */
		userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
		xil_printf("%c", userInput);
		status = XST_SUCCESS;
		switch (userInput)
		{
		case '1':
			status = DisplayStop(&dispCtrl);
			DisplaySetMode(&dispCtrl, &VMODE_640x480);
			DisplayStart(&dispCtrl);
			fResSet = 1;
			break;
		case '2':
			status = DisplayStop(&dispCtrl);
			DisplaySetMode(&dispCtrl, &VMODE_800x600);
			DisplayStart(&dispCtrl);
			fResSet = 1;
			break;
		case '3':
			status = DisplayStop(&dispCtrl);
			DisplaySetMode(&dispCtrl, &VMODE_1280x720);
			DisplayStart(&dispCtrl);
			fResSet = 1;
			break;
		case '4':
			status = DisplayStop(&dispCtrl);
			DisplaySetMode(&dispCtrl, &VMODE_1280x1024);
			DisplayStart(&dispCtrl);
			fResSet = 1;
			break;
		case '5':
			status = DisplayStop(&dispCtrl);
			DisplaySetMode(&dispCtrl, &VMODE_1920x1080);
			DisplayStart(&dispCtrl);
			fResSet = 1;
			break;
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

void DemoEffectMenu()
{
	int fEffectSet = 0;
	char userInput = 0;
	int nextFrame;
	u32 width, height;
	u8 *srcFrame;
	u8 *originalSrcFrame; // Store original source frame
	u32 originalWidth, originalHeight; // Store original dimensions
	int clearFrame = 1; // Default to clearing frame before effects (important for zoom/rotate)
	int originalFrameStored = 0; // Track if we've stored the original frame

	/* Flush UART FIFO */
	while (XUartPs_IsReceiveData(UART_BASEADDR))
	{
		XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
	}

	while (!fEffectSet)
	{
		xil_printf("\x1B[H"); //Set cursor to top left of terminal
		xil_printf("\x1B[2J"); //Clear terminal
		xil_printf("**************************************************\n\r");
		xil_printf("*            Video Effects Menu                   *\n\r");
		xil_printf("**************************************************\n\r");
		xil_printf("\n\r");
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
		xil_printf("M - Animated 3D Rotate X\n\r");
		xil_printf("N - Animated 3D Rotate Y\n\r");
		xil_printf("O - Animated 3D Rotate Z\n\r");
		xil_printf("P - Animated 3D Rotate XYZ\n\r");
		xil_printf("T - Toggle Frame Clear (Current: %s)\n\r", clearFrame ? "ON" : "OFF");
		xil_printf("q - Quit (back to main menu)\n\r");
			xil_printf("\n\r");
		xil_printf("Select an effect:");

		/* Wait for data on UART */
		while (!XUartPs_IsReceiveData(UART_BASEADDR))
		{}

		/* Store the first character in the UART receive FIFO and echo it */
		userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
		xil_printf("%c", userInput);
		
		// Check for quit first
		if (userInput == 'q' || userInput == 'Q')
		{
			fEffectSet = 1;
			break;
		}
		
		// Store original source frame on first effect (always use original, never chain)
		if (!originalFrameStored)
		{
			// Determine original source frame
			if (videoCapt.state == VIDEO_STREAMING)
			{
				// Use video frame as original
				originalSrcFrame = pFrames[videoCapt.curFrame];
				originalWidth = videoCapt.timing.HActiveVideo;
				originalHeight = videoCapt.timing.VActiveVideo;
				xil_printf("\n\rOriginal source: video frame (%dx%d)\n\r", originalWidth, originalHeight);
			}
			else
			{
				// Use display frame as original
				originalSrcFrame = pFrames[dispCtrl.curFrame];
				originalWidth = dispCtrl.vMode.width;
				originalHeight = dispCtrl.vMode.height;
				xil_printf("\n\rOriginal source: display frame (%dx%d)\n\r", originalWidth, originalHeight);
			}
			originalFrameStored = 1;
		}
		
		// Always use the original source frame for effects
		srcFrame = originalSrcFrame;
		width = originalWidth;
		height = originalHeight;
		
		// Get next frame for output
		nextFrame = dispCtrl.curFrame + 1;
		if (nextFrame >= DISPLAY_NUM_FRAMES)
		{
			nextFrame = 0;
		}
		// Make sure we don't overwrite the original source frame
		if (nextFrame == videoCapt.curFrame && videoCapt.state == VIDEO_STREAMING)
		{
			nextFrame = (nextFrame + 1) % DISPLAY_NUM_FRAMES;
		}
		// Also avoid overwriting if nextFrame is the same as original source
		if (pFrames[nextFrame] == originalSrcFrame)
		{
			nextFrame = (nextFrame + 1) % DISPLAY_NUM_FRAMES;
			if (pFrames[nextFrame] == originalSrcFrame)
			{
				nextFrame = (nextFrame + 1) % DISPLAY_NUM_FRAMES;
			}
		}
		
		// Clear frame if requested (important for zoom/rotate to avoid artifacts)
		if (clearFrame)
		{
			DemoClearFrame(pFrames[nextFrame], dispCtrl.vMode.width, dispCtrl.vMode.height, DEMO_STRIDE);
		}
		
		switch (userInput)
		{
		case '1':
			DemoMirrorEffect(srcFrame, pFrames[nextFrame], width, height, DEMO_STRIDE, DEMO_MIRROR_HORIZONTAL);
			DisplayChangeFrame(&dispCtrl, nextFrame);
			xil_printf("\n\rApplied: Mirror Horizontal\n\r");
			xil_printf("Press any key to continue, 'q' to quit...\n\r");
			// Flush UART and wait for any key
			while (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			}
			// Wait for keypress
			while (!XUartPs_IsReceiveData(UART_BASEADDR))
			{}
			// Check if 'q' was pressed to quit
			userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			if (userInput == 'q' || userInput == 'Q')
			{
				fEffectSet = 1;
				break;
			}
			break;
		case '2':
			DemoMirrorEffect(srcFrame, pFrames[nextFrame], width, height, DEMO_STRIDE, DEMO_MIRROR_VERTICAL);
			DisplayChangeFrame(&dispCtrl, nextFrame);
			xil_printf("\n\rApplied: Mirror Vertical\n\r");
			xil_printf("Press any key to continue, 'q' to quit...\n\r");
			while (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			}
			while (!XUartPs_IsReceiveData(UART_BASEADDR))
			{}
			userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			if (userInput == 'q' || userInput == 'Q')
			{
				fEffectSet = 1;
				break;
			}
			break;
		case '3':
			DemoMirrorEffect(srcFrame, pFrames[nextFrame], width, height, DEMO_STRIDE, DEMO_MIRROR_BOTH);
			DisplayChangeFrame(&dispCtrl, nextFrame);
			xil_printf("\n\rApplied: Mirror Both\n\r");
			xil_printf("Press any key to continue, 'q' to quit...\n\r");
			while (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			}
			while (!XUartPs_IsReceiveData(UART_BASEADDR))
			{}
			userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			if (userInput == 'q' || userInput == 'Q')
			{
				fEffectSet = 1;
				break;
			}
			break;
		case '4':
			DemoMirrorEffect(srcFrame, pFrames[nextFrame], width, height, DEMO_STRIDE, DEMO_MIRROR_CENTER_X);
			DisplayChangeFrame(&dispCtrl, nextFrame);
			xil_printf("\n\rApplied: Center Mirror X\n\r");
			xil_printf("Press any key to continue, 'q' to quit...\n\r");
			while (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			}
			while (!XUartPs_IsReceiveData(UART_BASEADDR))
			{}
			userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			if (userInput == 'q' || userInput == 'Q')
			{
				fEffectSet = 1;
				break;
			}
			break;
		case '5':
			DemoMirrorEffect(srcFrame, pFrames[nextFrame], width, height, DEMO_STRIDE, DEMO_MIRROR_CENTER_Y);
			DisplayChangeFrame(&dispCtrl, nextFrame);
			xil_printf("\n\rApplied: Center Mirror Y\n\r");
			xil_printf("Press any key to continue, 'q' to quit...\n\r");
			while (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			}
			while (!XUartPs_IsReceiveData(UART_BASEADDR))
			{}
			userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			if (userInput == 'q' || userInput == 'Q')
			{
				fEffectSet = 1;
				break;
			}
			break;
		case '6':
			DemoMirrorEffect(srcFrame, pFrames[nextFrame], width, height, DEMO_STRIDE, DEMO_MIRROR_CENTER_XY);
			DisplayChangeFrame(&dispCtrl, nextFrame);
			xil_printf("\n\rApplied: Center Mirror XY\n\r");
			xil_printf("Press any key to continue, 'q' to quit...\n\r");
			while (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			}
			while (!XUartPs_IsReceiveData(UART_BASEADDR))
			{}
			userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			if (userInput == 'q' || userInput == 'Q')
			{
				fEffectSet = 1;
				break;
			}
			break;
		case '7':
			DemoTileEffect(srcFrame, pFrames[nextFrame], width, height, dispCtrl.vMode.width, dispCtrl.vMode.height, DEMO_STRIDE, 2, 2);
			DisplayChangeFrame(&dispCtrl, nextFrame);
			xil_printf("\n\rApplied: Tile 2x2\n\r");
			xil_printf("Press any key to continue, 'q' to quit...\n\r");
			while (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			}
			while (!XUartPs_IsReceiveData(UART_BASEADDR))
			{}
			userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			if (userInput == 'q' || userInput == 'Q')
			{
				fEffectSet = 1;
				break;
			}
			break;
		case '8':
			DemoTileEffect(srcFrame, pFrames[nextFrame], width, height, dispCtrl.vMode.width, dispCtrl.vMode.height, DEMO_STRIDE, 3, 3);
			DisplayChangeFrame(&dispCtrl, nextFrame);
			xil_printf("\n\rApplied: Tile 3x3\n\r");
			xil_printf("Press any key to continue, 'q' to quit...\n\r");
			while (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			}
			while (!XUartPs_IsReceiveData(UART_BASEADDR))
			{}
			userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			if (userInput == 'q' || userInput == 'Q')
			{
				fEffectSet = 1;
				break;
			}
			break;
		case '9':
			DemoTileEffect(srcFrame, pFrames[nextFrame], width, height, dispCtrl.vMode.width, dispCtrl.vMode.height, DEMO_STRIDE, 4, 4);
			DisplayChangeFrame(&dispCtrl, nextFrame);
			xil_printf("\n\rApplied: Tile 4x4\n\r");
			xil_printf("Press any key to continue, 'q' to quit...\n\r");
			while (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			}
			while (!XUartPs_IsReceiveData(UART_BASEADDR))
			{}
			userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			if (userInput == 'q' || userInput == 'Q')
			{
				fEffectSet = 1;
				break;
			}
			break;
		case 'a':
		case 'A':
			DemoZoomEffect(srcFrame, pFrames[nextFrame], width, height, DEMO_STRIDE, 2.0f, 0.5f, 0.5f);
			DisplayChangeFrame(&dispCtrl, nextFrame);
			xil_printf("\n\rApplied: Zoom In 2x\n\r");
			xil_printf("Press any key to continue, 'q' to quit...\n\r");
			while (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			}
			while (!XUartPs_IsReceiveData(UART_BASEADDR))
			{}
			userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			if (userInput == 'q' || userInput == 'Q')
			{
				fEffectSet = 1;
				break;
			}
			break;
		case 'b':
		case 'B':
			DemoZoomEffect(srcFrame, pFrames[nextFrame], width, height, DEMO_STRIDE, 0.5f, 0.5f, 0.5f);
			DisplayChangeFrame(&dispCtrl, nextFrame);
			xil_printf("\n\rApplied: Zoom Out 0.5x\n\r");
			xil_printf("Press any key to continue, 'q' to quit...\n\r");
			while (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			}
			while (!XUartPs_IsReceiveData(UART_BASEADDR))
			{}
			userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			if (userInput == 'q' || userInput == 'Q')
			{
				fEffectSet = 1;
				break;
			}
			break;
		case 'c':
		case 'C':
			DemoMosaicEffect(srcFrame, pFrames[nextFrame], width, height, DEMO_STRIDE, 8);
			DisplayChangeFrame(&dispCtrl, nextFrame);
			xil_printf("\n\rApplied: Mosaic 8x8\n\r");
			xil_printf("Press any key to continue, 'q' to quit...\n\r");
			while (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			}
			while (!XUartPs_IsReceiveData(UART_BASEADDR))
			{}
			userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			if (userInput == 'q' || userInput == 'Q')
			{
				fEffectSet = 1;
				break;
			}
			break;
		case 'd':
		case 'D':
			DemoMosaicEffect(srcFrame, pFrames[nextFrame], width, height, DEMO_STRIDE, 16);
			DisplayChangeFrame(&dispCtrl, nextFrame);
			xil_printf("\n\rApplied: Mosaic 16x16\n\r");
			xil_printf("Press any key to continue, 'q' to quit...\n\r");
			while (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			}
			while (!XUartPs_IsReceiveData(UART_BASEADDR))
			{}
			userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			if (userInput == 'q' || userInput == 'Q')
			{
				fEffectSet = 1;
				break;
			}
			break;
		case 'e':
		case 'E':
			DemoMosaicEffect(srcFrame, pFrames[nextFrame], width, height, DEMO_STRIDE, 32);
			DisplayChangeFrame(&dispCtrl, nextFrame);
			xil_printf("\n\rApplied: Mosaic 32x32\n\r");
			xil_printf("Press any key to continue, 'q' to quit...\n\r");
			while (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			}
			while (!XUartPs_IsReceiveData(UART_BASEADDR))
			{}
			userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			if (userInput == 'q' || userInput == 'Q')
			{
				fEffectSet = 1;
				break;
			}
			break;
		case 'f':
		case 'F':
			{
				const float PI = 3.14159265359f;
				Demo3DPlaneEffect(srcFrame, pFrames[nextFrame], width, height, DEMO_STRIDE, 0.0f, 0.0f, PI/4.0f, 1.0f, 0.0f, 0.0f);
				DisplayChangeFrame(&dispCtrl, nextFrame);
				xil_printf("\n\rApplied: 3D Rotate Z (45 degrees)\n\r");
				xil_printf("Press any key to continue, 'q' to quit...\n\r");
				while (XUartPs_IsReceiveData(UART_BASEADDR))
				{
					XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				}
				while (!XUartPs_IsReceiveData(UART_BASEADDR))
				{}
				userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				if (userInput == 'q' || userInput == 'Q')
				{
					fEffectSet = 1;
					break;
				}
			}
			break;
		case 'g':
		case 'G':
			{
				const float PI = 3.14159265359f;
				Demo3DPlaneEffect(srcFrame, pFrames[nextFrame], width, height, DEMO_STRIDE, 0.0f, 0.0f, PI/2.0f, 1.0f, 0.0f, 0.0f);
				DisplayChangeFrame(&dispCtrl, nextFrame);
				xil_printf("\n\rApplied: 3D Rotate Z (90 degrees)\n\r");
				xil_printf("Press any key to continue, 'q' to quit...\n\r");
				while (XUartPs_IsReceiveData(UART_BASEADDR))
				{
					XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				}
				while (!XUartPs_IsReceiveData(UART_BASEADDR))
				{}
				userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				if (userInput == 'q' || userInput == 'Q')
				{
					fEffectSet = 1;
					break;
				}
			}
			break;
		case 'h':
		case 'H':
			{
				const float PI = 3.14159265359f;
				// Scale down to 70% and rotate X axis 60 degrees
				Demo3DPlaneEffect(srcFrame, pFrames[nextFrame], width, height, DEMO_STRIDE, PI/3.0f, 0.0f, 0.0f, 0.7f, 0.0f, 0.0f);
				DisplayChangeFrame(&dispCtrl, nextFrame);
				xil_printf("\n\rApplied: 3D Rotate X (60 deg, scaled 70%%)\n\r");
				xil_printf("Press any key to continue, 'q' to quit...\n\r");
				while (XUartPs_IsReceiveData(UART_BASEADDR))
				{
					XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				}
				while (!XUartPs_IsReceiveData(UART_BASEADDR))
				{}
				userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				if (userInput == 'q' || userInput == 'Q')
				{
					fEffectSet = 1;
					break;
				}
			}
			break;
		case 'i':
		case 'I':
			{
				const float PI = 3.14159265359f;
				// Scale down to 70% and rotate Y axis 60 degrees
				Demo3DPlaneEffect(srcFrame, pFrames[nextFrame], width, height, DEMO_STRIDE, 0.0f, PI/3.0f, 0.0f, 0.7f, 0.0f, 0.0f);
				DisplayChangeFrame(&dispCtrl, nextFrame);
				xil_printf("\n\rApplied: 3D Rotate Y (60 deg, scaled 70%%)\n\r");
				xil_printf("Press any key to continue, 'q' to quit...\n\r");
				while (XUartPs_IsReceiveData(UART_BASEADDR))
				{
					XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				}
				while (!XUartPs_IsReceiveData(UART_BASEADDR))
				{}
				userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				if (userInput == 'q' || userInput == 'Q')
				{
					fEffectSet = 1;
					break;
				}
			}
			break;
		case 'j':
		case 'J':
			{
				const float PI = 3.14159265359f;
				// Scale down to 70% and rotate on all axes
				Demo3DPlaneEffect(srcFrame, pFrames[nextFrame], width, height, DEMO_STRIDE, PI/4.0f, PI/4.0f, PI/4.0f, 0.7f, 0.0f, 0.0f);
				DisplayChangeFrame(&dispCtrl, nextFrame);
				xil_printf("\n\rApplied: 3D Rotate XYZ (45 deg each, scaled 70%%)\n\r");
				xil_printf("Press any key to continue, 'q' to quit...\n\r");
				while (XUartPs_IsReceiveData(UART_BASEADDR))
				{
					XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				}
				while (!XUartPs_IsReceiveData(UART_BASEADDR))
				{}
				userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				if (userInput == 'q' || userInput == 'Q')
				{
					fEffectSet = 1;
					break;
				}
			}
			break;
		case 'k':
		case 'K':
			{
				const float PI = 3.14159265359f;
				Demo3DPlaneEffect(srcFrame, pFrames[nextFrame], width, height, DEMO_STRIDE, 0.0f, 0.0f, PI/6.0f, 1.5f, 0.0f, 0.0f);
				DisplayChangeFrame(&dispCtrl, nextFrame);
				xil_printf("\n\rApplied: 3D Scale + Rotate\n\r");
				xil_printf("Press any key to continue, 'q' to quit...\n\r");
				while (XUartPs_IsReceiveData(UART_BASEADDR))
				{
					XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				}
				while (!XUartPs_IsReceiveData(UART_BASEADDR))
				{}
				userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				if (userInput == 'q' || userInput == 'Q')
				{
					fEffectSet = 1;
					break;
				}
			}
			break;
		case 'l':
		case 'L':
			DemoShrinkRandomEffect(srcFrame, pFrames[nextFrame], width, height, dispCtrl.vMode.width, dispCtrl.vMode.height, DEMO_STRIDE);
			DisplayChangeFrame(&dispCtrl, nextFrame);
			xil_printf("\n\rApplied: Shrink 25%% and Random Position\n\r");
			xil_printf("Press any key to continue, 'q' to quit...\n\r");
			while (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			}
			while (!XUartPs_IsReceiveData(UART_BASEADDR))
			{}
			userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			if (userInput == 'q' || userInput == 'Q')
			{
				fEffectSet = 1;
				break;
			}
			break;
		case 'm':
		case 'M':
			{
				// Animated 3D Rotate X
				// Find which frame index contains the source frame
				u32 srcFrameIdx = 0;
				for (u32 i = 0; i < DISPLAY_NUM_FRAMES; i++)
				{
					if (pFrames[i] == srcFrame)
					{
						srcFrameIdx = i;
						break;
					}
				}
				xil_printf("\n\rStarting animated 3D Rotate X... Press any key to stop\n\r");
				DemoRunAnimated3DEffect(srcFrame, pFrames, srcFrameIdx, width, height, DEMO_STRIDE, dispCtrl.vMode.width, dispCtrl.vMode.height, 
				                        'X', 0.7f, &dispCtrl, &videoCapt);
				xil_printf("Press any key to continue, 'q' to quit...\n\r");
				while (XUartPs_IsReceiveData(UART_BASEADDR))
				{
					XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				}
				while (!XUartPs_IsReceiveData(UART_BASEADDR))
				{}
				userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				if (userInput == 'q' || userInput == 'Q')
				{
					fEffectSet = 1;
					break;
				}
			}
			break;
		case 'n':
		case 'N':
			{
				// Animated 3D Rotate Y
				// Find which frame index contains the source frame
				u32 srcFrameIdx = 0;
				for (u32 i = 0; i < DISPLAY_NUM_FRAMES; i++)
				{
					if (pFrames[i] == srcFrame)
					{
						srcFrameIdx = i;
						break;
					}
				}
				xil_printf("\n\rStarting animated 3D Rotate Y... Press any key to stop\n\r");
				DemoRunAnimated3DEffect(srcFrame, pFrames, srcFrameIdx, width, height, DEMO_STRIDE, dispCtrl.vMode.width, dispCtrl.vMode.height, 
				                        'Y', 0.7f, &dispCtrl, &videoCapt);
				xil_printf("Press any key to continue, 'q' to quit...\n\r");
				while (XUartPs_IsReceiveData(UART_BASEADDR))
				{
					XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				}
				while (!XUartPs_IsReceiveData(UART_BASEADDR))
				{}
				userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				if (userInput == 'q' || userInput == 'Q')
				{
					fEffectSet = 1;
					break;
				}
			}
			break;
		case 'o':
		case 'O':
			{
				// Animated 3D Rotate Z
				// Find which frame index contains the source frame
				u32 srcFrameIdx = 0;
				for (u32 i = 0; i < DISPLAY_NUM_FRAMES; i++)
				{
					if (pFrames[i] == srcFrame)
					{
						srcFrameIdx = i;
						break;
					}
				}
				xil_printf("\n\rStarting animated 3D Rotate Z... Press any key to stop\n\r");
				DemoRunAnimated3DEffect(srcFrame, pFrames, srcFrameIdx, width, height, DEMO_STRIDE, dispCtrl.vMode.width, dispCtrl.vMode.height, 
				                        'Z', 0.7f, &dispCtrl, &videoCapt);
				xil_printf("Press any key to continue, 'q' to quit...\n\r");
				while (XUartPs_IsReceiveData(UART_BASEADDR))
				{
					XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				}
				while (!XUartPs_IsReceiveData(UART_BASEADDR))
				{}
				userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				if (userInput == 'q' || userInput == 'Q')
				{
					fEffectSet = 1;
					break;
				}
			}
			break;
		case 'p':
		case 'P':
			{
				// Animated 3D Rotate XYZ
				// Find which frame index contains the source frame
				u32 srcFrameIdx = 0;
				for (u32 i = 0; i < DISPLAY_NUM_FRAMES; i++)
				{
					if (pFrames[i] == srcFrame)
					{
						srcFrameIdx = i;
						break;
					}
				}
				xil_printf("\n\rStarting animated 3D Rotate XYZ... Press any key to stop\n\r");
				DemoRunAnimated3DEffect(srcFrame, pFrames, srcFrameIdx, width, height, DEMO_STRIDE, dispCtrl.vMode.width, dispCtrl.vMode.height, 
				                        'A', 0.7f, &dispCtrl, &videoCapt);
				xil_printf("Press any key to continue, 'q' to quit...\n\r");
				while (XUartPs_IsReceiveData(UART_BASEADDR))
				{
					XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				}
				while (!XUartPs_IsReceiveData(UART_BASEADDR))
				{}
				userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
				if (userInput == 'q' || userInput == 'Q')
				{
					fEffectSet = 1;
					break;
				}
			}
			break;
		case 't':
		case 'T':
			clearFrame = !clearFrame;
			xil_printf("\n\rFrame Clear: %s\n\r", clearFrame ? "ON" : "OFF");
			xil_printf("Press any key to continue...\n\r");
			while (XUartPs_IsReceiveData(UART_BASEADDR))
			{
				XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			}
			while (!XUartPs_IsReceiveData(UART_BASEADDR))
			{}
			XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
			break;
		default:
			xil_printf("\n\rInvalid Selection");
			TimerDelay(500000);
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
	DemoOverlaySetSprite(0U, 1U, 64U, 64U, patternWidth, patternHeight, 0U);
	DemoOverlayWriteReg(OVERLAY_REG_GLOBAL_ENABLE, 1U);

	xil_printf("\n\rOverlay test loaded: sprite0=%dx%d @ (64,64), BRAM words=%d\n\r",
	           (int)patternWidth, (int)patternHeight, (int)patternWords);
	xil_printf("Overlay global enable=%d, readback errors=%d\n\r",
	           (int)(DemoOverlayReadReg(OVERLAY_REG_GLOBAL_ENABLE) & 0x1U),
	           (int)readBackErrors);
}

static void DemoSpriteRandomTest(u32 displayWidth, u32 displayHeight)
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
	posX = (maxX > 0U) ? (randX % (maxX + 1U)) : 0U;
	posY = (maxY > 0U) ? (randY % (maxY + 1U)) : 0U;

	/* Keep overlay enabled and move/update sprite slot every run. */
	DemoOverlayWriteReg(OVERLAY_REG_GLOBAL_ENABLE, 1U);
	DemoOverlaySetSprite(spriteIdx, 1U, posX, posY, spriteWidth, spriteHeight, spriteBaseWord);

	xil_printf("\n\rSprite test loaded: sprite%d=%dx%d @ (%d,%d), baseWord=%d\n\r",
	           (int)spriteIdx, (int)spriteWidth, (int)spriteHeight, (int)posX, (int)posY, (int)spriteBaseWord);
}


/*
 * Plasma Pattern - Monochrome wave pattern that evolves over time
 * Creates smooth, organic-looking transitions
 */
void DemoPlasmaPattern(u8 *frame, u32 width, u32 height, u32 stride, float time)
{
	u32 xcoi, ycoi;
	u32 iPixelAddr;
	u8 monochrome;
	double x, y;
	double value;
	double centerX = width / 2.0;
	double centerY = height / 2.0;
	
	for(ycoi = 0; ycoi < height; ycoi++)
	{
		y = (double)ycoi;
		iPixelAddr = ycoi * stride;
		
		for(xcoi = 0; xcoi < width; xcoi++)
		{
			x = (double)xcoi;
			
			// Create multiple sine waves with different frequencies and phases
			value = fast_sin((x + time * 20.0f) / 16.0f) +
					fast_sin((y + time * 15.0f) / 12.0f) +
					fast_sin((x + y + time * 10.0f) / 14.0f) +
					fast_sin(fast_sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY)) / 8.0f + time * 25.0f);
			
			// Normalize to 0-1 range
			value = (value + 4.0) / 8.0;
			
			// Clamp and convert to monochrome (0-255)
			if (value < 0.0) value = 0.0;
			if (value > 1.0) value = 1.0;
			monochrome = (u8)(value * 255.0);
			
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
	double cx, cy;  // Complex plane coordinates
	double zx, zy;  // Iteration variables
	double zx2, zy2; // Squared values for optimization
	u32 iterations;
	u32 maxIterations = 50;
	double value;
	
	// Pre-calculate inverses to avoid divisions in loops
	double invWidth = 1.0 / (double)width;
	double invHeight = 1.0 / (double)height;
	double invMaxIter = 1.0 / (double)maxIterations;
	
	// Evolve view: zoom in/out and pan around
	double zoom = 0.5 + 0.3 * fast_sin(time * 0.05f);  // Zoom oscillates
	double centerX = -0.5 + 0.3 * fast_sin(time * 0.03f);  // Pan X
	double centerY = 0.0 + 0.2 * fast_cos(time * 0.04f);   // Pan Y
	
	// Calculate scale based on zoom
	double scale = 2.5 / zoom;
	double offsetX = centerX;
	double offsetY = centerY;
	
	// Pre-calculate Y scaling factor
	double yScale = scale * invHeight;
	double yOffset = (offsetY - 0.5 * scale);
	
	for(ycoi = 0; ycoi < height; ycoi++)
	{
		iPixelAddr = ycoi * stride;
		
		// Map pixel Y to complex plane (pre-calculated)
		cy = (double)ycoi * yScale + yOffset;
		
		// Pre-calculate X scaling factor for this row
		double xScale = scale * invWidth;
		double xOffset = (offsetX - 0.5 * scale);
		
		for(xcoi = 0; xcoi < width; xcoi++)
		{
			// Map pixel X to complex plane (optimized)
			cx = (double)xcoi * xScale + xOffset;
			
			// Mandelbrot iteration: z = z^2 + c
			zx = 0.0;
			zy = 0.0;
			iterations = 0;
			
			// Iterate until escape or max iterations
			while (iterations < maxIterations)
			{
				zx2 = zx * zx;
				zy2 = zy * zy;
				
				// Check if escaped (|z| > 2)
				if (zx2 + zy2 > 4.0)
					break;
				
				// z = z^2 + c
				zy = 2.0 * zx * zy + cy;
				zx = zx2 - zy2 + cx;
				
				iterations++;
			}
			
			// Smooth coloring based on iterations
			if (iterations >= maxIterations)
			{
				// Inside set - black
				value = 0.0;
			}
			else
				{
					// Smooth escape time coloring using distance estimate
					double dist = zx * zx + zy * zy;
					if (dist > 4.0 && dist < 100.0)
					{
						// Use log-based smoothing for better gradients
						double smoothIter = (double)iterations + 1.0 - fast_log2(fast_log2(dist));
						if (smoothIter < 0.0) smoothIter = 0.0;
						value = smoothIter * invMaxIter;
					}
					else
					{
						// Fallback to simple iteration count (optimized)
						value = (double)iterations * invMaxIter;
					}
					if (value > 1.0) value = 1.0;
				}
			
			// Convert to monochrome (0-255)
			monochrome = (u8)(value * 255.0);
			
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
 * Wave Interference Pattern - Animated sine wave interference
 */
void DemoWavePattern(u8 *frame, u32 width, u32 height, u32 stride, float time)
{
	u32 xcoi, ycoi;
	u32 iPixelAddr;
	u8 monochrome;
	double x, y;
	double wave1, wave2, wave3;
	double combined;
	
	for(ycoi = 0; ycoi < height; ycoi++)
	{
		y = (double)ycoi;
		iPixelAddr = ycoi * stride;
		
		for(xcoi = 0; xcoi < width; xcoi++)
		{
			x = (double)xcoi;
			
			// Create multiple waves with different directions and frequencies
			wave1 = fast_sin((x * 0.1f) + (time * 20.0f));
			wave2 = fast_sin((y * 0.1f) + (time * 15.0f));
			wave3 = fast_sin(((x + y) * 0.07f) + (time * 25.0f));
			
			// Combine waves to create interference pattern
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
 * Julia Fractal - Evolving Julia set with changing constant
 */
void DemoGradientPattern(u8 *frame, u32 width, u32 height, u32 stride, float time)
{
	u32 xcoi, ycoi;
	u32 iPixelAddr;
	u8 monochrome;
	double zx, zy;  // Iteration variables
	double zx2, zy2; // Squared values for optimization
	u32 iterations;
	u32 maxIterations = 50;
	double value;
	
	// Pre-calculate inverses to avoid divisions in loops
	double invWidth = 1.0 / (double)width;
	double invHeight = 1.0 / (double)height;
	double invMaxIter = 1.0 / (double)maxIterations;
	
	// Evolve Julia constant c over time (creates morphing patterns)
	double cReal = 0.7885 * fast_cos(time * 0.1f);  // Real part oscillates
	double cImag = 0.7885 * fast_sin(time * 0.1f);  // Imaginary part oscillates
	
	// Fixed view window for Julia set
	double scale = 3.0;
	double offsetX = 0.0;
	double offsetY = 0.0;
	
	// Pre-calculate Y scaling factors
	double yScale = scale * invHeight;
	double yOffset = (offsetY - 0.5 * scale);
	
	// Pre-calculate X scaling factors
	double xScale = scale * invWidth;
	double xOffset = (offsetX - 0.5 * scale);
	
	for(ycoi = 0; ycoi < height; ycoi++)
	{
		iPixelAddr = ycoi * stride;
		
		// Map pixel Y to complex plane (optimized)
		zy = (double)ycoi * yScale + yOffset;
		
		for(xcoi = 0; xcoi < width; xcoi++)
		{
			// Map pixel X to complex plane (optimized)
			zx = (double)xcoi * xScale + xOffset;
			
			// Julia iteration: z = z^2 + c (c is constant, z starts at pixel)
			iterations = 0;
			
			// Iterate until escape or max iterations
			while (iterations < maxIterations)
			{
				zx2 = zx * zx;
				zy2 = zy * zy;
				
				// Check if escaped (|z| > 2)
				if (zx2 + zy2 > 4.0)
					break;
				
				// z = z^2 + c
				double temp = zx2 - zy2 + cReal;
				zy = 2.0 * zx * zy + cImag;
				zx = temp;
				
				iterations++;
			}
			
			// Smooth coloring based on iterations
			if (iterations >= maxIterations)
			{
				// Inside set - black
				value = 0.0;
			}
			else
				{
					// Smooth escape time coloring using distance estimate
					double dist = zx * zx + zy * zy;
					if (dist > 4.0 && dist < 100.0)
					{
						// Use log-based smoothing for better gradients
						double smoothIter = (double)iterations + 1.0 - fast_log2(fast_log2(dist));
						if (smoothIter < 0.0) smoothIter = 0.0;
						value = smoothIter * invMaxIter;
					}
					else
					{
						// Fallback to simple iteration count (optimized)
						value = (double)iterations * invMaxIter;
					}
					if (value > 1.0) value = 1.0;
				}
			
			// Convert to monochrome (0-255)
			monochrome = (u8)(value * 255.0);
			
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
 * Moiré Pattern - Overlapping grids creating interference patterns
 * Slow-evolving pattern similar to wave interference
 */
void DemoMoirePattern(u8 *frame, u32 width, u32 height, u32 stride, float time)
{
	u32 xcoi, ycoi;
	u32 iPixelAddr;
	u8 monochrome;
	double x, y;
	double grid1, grid2, grid3;
	double combined;
	double centerX = width / 2.0;
	double centerY = height / 2.0;
	double dx, dy;
	
	for(ycoi = 0; ycoi < height; ycoi++)
	{
		y = (double)ycoi;
		iPixelAddr = ycoi * stride;
		
		for(xcoi = 0; xcoi < width; xcoi++)
		{
			x = (double)xcoi;
			dx = x - centerX;
			dy = y - centerY;
			
			// Create overlapping grids with different orientations and frequencies
			// Grid 1: Horizontal lines with slow rotation
			grid1 = fast_sin((y * 0.08f) + (time * 12.0f));
			
			// Grid 2: Vertical lines with slow rotation
			grid2 = fast_sin((x * 0.08f) + (time * 10.0f));
			
			// Grid 3: Diagonal grid with rotation
			double angle = time * 0.05f;
			double rotX = dx * fast_cos(angle) - dy * fast_sin(angle);
			double rotY = dx * fast_sin(angle) + dy * fast_cos(angle);
			grid3 = fast_sin((rotX + rotY) * 0.06f + time * 8.0f);
			
			// Combine grids to create moiré interference
			combined = (grid1 + grid2 + grid3) / 3.0;
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
	
	// Calculate scaling factors (fixed-point for speed)
	xScale = (lowWidth << 16) / highWidth;  // Fixed point 16.16
	yScale = (lowHeight << 16) / highHeight;
	
	for(ycoi = 0; ycoi < highHeight; ycoi++)
	{
		// Calculate source Y coordinate
		srcY = (ycoi * yScale) >> 16;
		if(srcY >= lowHeight) srcY = lowHeight - 1;
		
		destAddr = ycoi * highStride;
		srcAddr = srcY * lowStride;
		
		for(xcoi = 0; xcoi < highWidth; xcoi++)
		{
			// Calculate source X coordinate
			srcX = (xcoi * xScale) >> 16;
			if(srcX >= lowWidth) srcX = lowWidth - 1;
			
			// Copy pixel (RGB)
			highResFrame[destAddr] = lowResFrame[srcAddr + srcX * 3];
			highResFrame[destAddr + 1] = lowResFrame[srcAddr + srcX * 3 + 1];
			highResFrame[destAddr + 2] = lowResFrame[srcAddr + srcX * 3 + 2];
			
			destAddr += 3;
		}
	}
	
	Xil_DCacheFlushRange((unsigned int) highResFrame, highHeight * highStride);
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
	u32 maxFrames = 200; // Maximum number of frames to draw
	
	// Calculate lower resolution for faster rendering
	// Use 1/2 resolution for good speed/quality balance
	// For very large displays, could use 1/4 resolution
	u32 scaleFactor = 4; // Render at 1/8 resolution
	u32 lowWidth = (width + scaleFactor - 1) / scaleFactor;  // Round up
	u32 lowHeight = (height + scaleFactor - 1) / scaleFactor;
	u32 lowStride = lowWidth * 3;
	
	// Allocate temporary low-resolution buffer (on stack, but limited size)
	// For safety, limit to reasonable size
	if(lowWidth > 960 || lowHeight > 540)
	{
		// Fall back to 1/4 scale if too large
		scaleFactor = 4;
		lowWidth = (width + scaleFactor - 1) / scaleFactor;
		lowHeight = (height + scaleFactor - 1) / scaleFactor;
		lowStride = lowWidth * 3;
	}
	
	// Use a static buffer for low-res rendering (max 960x540 = ~1.5MB)
	// This is safe since it's much smaller than DEMO_MAX_FRAME
	static u8 lowResBuffer[960 * 540 * 3] __attribute__((aligned(0x20)));
	
	xil_printf("\n\rRunning animated pattern at %dx%d (scaled from %dx%d)... Press any key to stop\n\r", 
	           width, height, lowWidth, lowHeight);
	
	// Flush UART FIFO
	while (XUartPs_IsReceiveData(UART_BASEADDR))
	{
		XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
	}
	
	g_shouldExitPattern = 0;
	
	// Main animation loop
	while(frameCount < maxFrames && !shouldExit)
	{
		// Check for exit before starting
		if (CheckForExit())
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
		
		// Increment time for next frame - larger increment for visible changes
		time += 5.0f; // Increase time significantly for visible animation
		if(time > 1000.0f) time = 0.0f; // Wrap time to prevent overflow
		
		// Very short delay - just enough to let frame be visible
		// Check for exit very frequently
		u32 i;
		for (i = 0; i < 20; i++)
		{
			// TimerDelay(2500); // 2.5ms chunks = 50ms total delay per frame
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

/*
 * Mirror Effect - Flip image horizontally, vertically, or both
 * Works on RGB frames (both animations and video)
 */
void DemoMirrorEffect(u8 *srcFrame, u8 *destFrame, u32 width, u32 height, u32 stride, int mirrorType)
{
	u32 xcoi, ycoi;
	u32 srcAddr, destAddr;
	u32 srcX, srcY;
	u32 centerX = width / 2;
	u32 centerY = height / 2;
	
	for(ycoi = 0; ycoi < height; ycoi++)
	{
		destAddr = ycoi * stride;
		
		for(xcoi = 0; xcoi < width; xcoi++)
		{
			// Handle different mirror types
			if (mirrorType == DEMO_MIRROR_HORIZONTAL)
			{
				// Flip entire image horizontally
				srcX = width - 1 - xcoi;
				srcY = ycoi;
			}
			else if (mirrorType == DEMO_MIRROR_VERTICAL)
			{
				// Flip entire image vertically
				srcX = xcoi;
				srcY = height - 1 - ycoi;
			}
			else if (mirrorType == DEMO_MIRROR_BOTH)
			{
				// Flip both axes
				srcX = width - 1 - xcoi;
				srcY = height - 1 - ycoi;
			}
			else if (mirrorType == DEMO_MIRROR_CENTER_X)
			{
				// Center X-axis mirror: left side original, right side mirrors left
				if (xcoi < centerX)
				{
					// Left side: use original
					srcX = xcoi;
				}
				else
				{
					// Right side: mirror from left side
					srcX = width - 1 - xcoi;
				}
				srcY = ycoi;
			}
			else if (mirrorType == DEMO_MIRROR_CENTER_Y)
			{
				// Center Y-axis mirror: top original, bottom mirrors top
				srcX = xcoi;
				if (ycoi < centerY)
				{
					// Top half: use original
					srcY = ycoi;
				}
				else
				{
					// Bottom half: mirror from top
					srcY = height - 1 - ycoi;
				}
			}
			else if (mirrorType == DEMO_MIRROR_CENTER_XY)
			{
				// Center XY mirror: top-left quadrant original, others mirror it
				if (xcoi < centerX && ycoi < centerY)
				{
					// Top-left quadrant: original
					srcX = xcoi;
					srcY = ycoi;
				}
				else if (xcoi >= centerX && ycoi < centerY)
				{
					// Top-right quadrant: mirror X from top-left
					srcX = width - 1 - xcoi;
					srcY = ycoi;
				}
				else if (xcoi < centerX && ycoi >= centerY)
				{
					// Bottom-left quadrant: mirror Y from top-left
					srcX = xcoi;
					srcY = height - 1 - ycoi;
				}
				else
				{
					// Bottom-right quadrant: mirror both from top-left
					srcX = width - 1 - xcoi;
					srcY = height - 1 - ycoi;
				}
			}
			else
			{
				// No mirror (DEMO_MIRROR_NONE)
				srcX = xcoi;
				srcY = ycoi;
			}
			
			srcAddr = srcY * stride + srcX * 3;
			
			// Copy RGB pixel
			destFrame[destAddr] = srcFrame[srcAddr];
			destFrame[destAddr + 1] = srcFrame[srcAddr + 1];
			destFrame[destAddr + 2] = srcFrame[srcAddr + 2];
			
			destAddr += 3;
		}
	}
	
	Xil_DCacheFlushRange((unsigned int) destFrame, height * stride);
}

/*
 * Tile Effect - Repeat source image multiple times across destination
 * Works on RGB frames (both animations and video)
 */
void DemoTileEffect(u8 *srcFrame, u8 *destFrame, u32 srcWidth, u32 srcHeight, u32 destWidth, u32 destHeight, u32 stride, u32 tilesX, u32 tilesY)
{
	u32 xcoi, ycoi;
	u32 destAddr;
	u32 srcX, srcY;
	u32 srcAddr;
	
	// Ensure at least 1 tile
	if (tilesX == 0) tilesX = 1;
	if (tilesY == 0) tilesY = 1;
	
	// Calculate tile dimensions (how big each tile should be)
	u32 tileWidth = destWidth / tilesX;
	u32 tileHeight = destHeight / tilesY;
	
	// Pre-calculate scaling factors to avoid divisions in inner loop
	u32 srcYScale = (srcHeight << 16) / tileHeight;  // Fixed-point scaling
	u32 srcXScale = (srcWidth << 16) / tileWidth;
	
	for(ycoi = 0; ycoi < destHeight; ycoi++)
	{
		destAddr = ycoi * stride;
		
		// Determine which tile row we're in
		u32 tileRow = ycoi / tileHeight;
		if (tileRow >= tilesY) tileRow = tilesY - 1;
		
		// Get Y position within the current tile
		u32 yInTile = ycoi % tileHeight;
		
		// Map tile Y to source Y (scale source to fit tile size) - optimized
		srcY = (yInTile * srcYScale) >> 16;
		if (srcY >= srcHeight) srcY = srcHeight - 1;
		
		for(xcoi = 0; xcoi < destWidth; xcoi++)
		{
			// Determine which tile column we're in
			u32 tileCol = xcoi / tileWidth;
			if (tileCol >= tilesX) tileCol = tilesX - 1;
			
			// Get X position within the current tile
			u32 xInTile = xcoi % tileWidth;
			
			// Map tile X to source X (scale source to fit tile size) - optimized
			srcX = (xInTile * srcXScale) >> 16;
			if (srcX >= srcWidth) srcX = srcWidth - 1;
			
			srcAddr = srcY * stride + srcX * 3;
			
			// Copy RGB pixel
			destFrame[destAddr] = srcFrame[srcAddr];
			destFrame[destAddr + 1] = srcFrame[srcAddr + 1];
			destFrame[destAddr + 2] = srcFrame[srcAddr + 2];
			
			destAddr += 3;
		}
	}
	
	Xil_DCacheFlushRange((unsigned int) destFrame, destHeight * stride);
}

/*
 * Zoom Effect - Zoom in/out with optional center point
 * Works on RGB frames (both animations and video)
 * zoom > 1.0 = zoom in, zoom < 1.0 = zoom out
 * centerX, centerY are normalized (0.0-1.0) for center point
 */
void DemoZoomEffect(u8 *srcFrame, u8 *destFrame, u32 width, u32 height, u32 stride, float zoom, float centerX, float centerY)
{
	u32 xcoi, ycoi;
	u32 destAddr;
	float srcX, srcY;
	u32 srcXInt, srcYInt;
	u32 srcAddr;
	
	// Clamp center to valid range
	if (centerX < 0.0f) centerX = 0.0f;
	if (centerX > 1.0f) centerX = 1.0f;
	if (centerY < 0.0f) centerY = 0.0f;
	if (centerY > 1.0f) centerY = 1.0f;
	
	// Pre-calculate inverse zoom to avoid division in loop
	float invZoom = 1.0f / zoom;
	
	// Calculate center point in pixel coordinates
	float centerXPix = centerX * (float)width;
	float centerYPix = centerY * (float)height;
	
	// Calculate offset to center the zoom (optimized)
	float offsetX = centerXPix * (1.0f - invZoom);
	float offsetY = centerYPix * (1.0f - invZoom);
	
	// Pre-calculate bounds for clamping
	float maxX = (float)(width - 1);
	float maxY = (float)(height - 1);
	
	for(ycoi = 0; ycoi < height; ycoi++)
	{
		destAddr = ycoi * stride;
		
		// Pre-calculate Y component
		float yZoomed = (float)ycoi * invZoom + offsetY;
		
		for(xcoi = 0; xcoi < width; xcoi++)
		{
			// Calculate source coordinates with zoom (optimized)
			srcX = (float)xcoi * invZoom + offsetX;
			srcY = yZoomed;
			
			// Clamp to source bounds
			if (srcX < 0.0f) srcX = 0.0f;
			if (srcX >= (float)width) srcX = (float)(width - 1);
			if (srcY < 0.0f) srcY = 0.0f;
			if (srcY >= (float)height) srcY = (float)(height - 1);
			
			// Nearest neighbor sampling
			srcXInt = (u32)srcX;
			srcYInt = (u32)srcY;
			
			srcAddr = srcYInt * stride + srcXInt * 3;
			
			// Copy RGB pixel
			destFrame[destAddr] = srcFrame[srcAddr];
			destFrame[destAddr + 1] = srcFrame[srcAddr + 1];
			destFrame[destAddr + 2] = srcFrame[srcAddr + 2];
			
			destAddr += 3;
		}
	}
	
	Xil_DCacheFlushRange((unsigned int) destFrame, height * stride);
}

/*
 * Mosaic/Pixelate Effect - Group pixels into blocks
 * Works on RGB frames (both animations and video)
 * blockSize = size of each mosaic block (e.g., 8 = 8x8 blocks)
 */
void DemoMosaicEffect(u8 *srcFrame, u8 *destFrame, u32 width, u32 height, u32 stride, u32 blockSize)
{
	u32 xcoi, ycoi;
	u32 destAddr;
	u32 blockX, blockY;
	u32 blockStartX, blockStartY;
	u32 srcX, srcY;
	u32 srcAddr;
	u32 rSum, gSum, bSum;
	u32 pixelCount;
	u8 rAvg, gAvg, bAvg;
	
	// Ensure block size is at least 1
	if (blockSize == 0) blockSize = 1;
	
	// Process in blocks
	for(blockY = 0; blockY < height; blockY += blockSize)
	{
		for(blockX = 0; blockX < width; blockX += blockSize)
		{
			// Calculate block bounds
			u32 blockEndX = blockX + blockSize;
			u32 blockEndY = blockY + blockSize;
			if (blockEndX > width) blockEndX = width;
			if (blockEndY > height) blockEndY = height;
			
			// Calculate average color of this block
			rSum = gSum = bSum = 0;
			pixelCount = 0;
			
			for(srcY = blockY; srcY < blockEndY; srcY++)
			{
				srcAddr = srcY * stride + blockX * 3;
				for(srcX = blockX; srcX < blockEndX; srcX++)
				{
					rSum += srcFrame[srcAddr];
					gSum += srcFrame[srcAddr + 1];
					bSum += srcFrame[srcAddr + 2];
					srcAddr += 3;
					pixelCount++;
				}
			}
			
			// Calculate average
			rAvg = (u8)(rSum / pixelCount);
			gAvg = (u8)(gSum / pixelCount);
			bAvg = (u8)(bSum / pixelCount);
			
			// Fill block with average color
			for(ycoi = blockY; ycoi < blockEndY; ycoi++)
			{
				destAddr = ycoi * stride + blockX * 3;
				for(xcoi = blockX; xcoi < blockEndX; xcoi++)
				{
					destFrame[destAddr] = rAvg;
					destFrame[destAddr + 1] = gAvg;
					destFrame[destAddr + 2] = bAvg;
					destAddr += 3;
				}
			}
		}
	}
	
	Xil_DCacheFlushRange((unsigned int) destFrame, height * stride);
}

/*
 * 3D Plane Effect - Transform image as if it's a flat plane in 3D space
 * Works on RGB frames (both animations and video)
 * rotX, rotY, rotZ = rotation angles in radians
 * scale = scale factor (1.0 = no scaling)
 * offsetX, offsetY = translation offset in pixels
 */
void Demo3DPlaneEffect(u8 *srcFrame, u8 *destFrame, u32 width, u32 height, u32 stride, float rotX, float rotY, float rotZ, float scale, float offsetX, float offsetY)
{
	u32 xcoi, ycoi;
	u32 destAddr;
	float srcX, srcY;
	u32 srcXInt, srcYInt;
	u32 srcAddr;
	
	// Pre-calculate rotation matrices
	float cosX = fast_cos(rotX);
	float sinX = fast_sin(rotX);
	float cosY = fast_cos(rotY);
	float sinY = fast_sin(rotY);
	float cosZ = fast_cos(rotZ);
	float sinZ = fast_sin(rotZ);
	
	// Center point
	float centerX = (float)width * 0.5f;
	float centerY = (float)height * 0.5f;
	
	// Perspective distance (viewer distance from plane)
	// Controls how much perspective effect - smaller = more dramatic
	float perspectiveDist = 2.5f;
	
	// For inverse mapping: for each destination pixel, find which source pixel maps to it
	for(ycoi = 0; ycoi < height; ycoi++)
	{
		destAddr = ycoi * stride;
		
		for(xcoi = 0; xcoi < width; xcoi++)
		{
			// Destination pixel in normalized coordinates (-1 to 1)
			float screenX = ((float)xcoi - centerX) / centerX;
			float screenY = ((float)ycoi - centerY) / centerY;
			
			// Apply inverse scaling
			screenX /= scale;
			screenY /= scale;
			
			// For a plane rotating in 3D space:
			// The source image is a plane at Z=0
			// After rotation, each point (x,y,0) becomes a 3D point
			// That 3D point projects to screen coordinates with perspective
			// We need the inverse: given screen coords, find original (x,y,0)
			
			// Use iterative method to solve for source coordinates
			// Start with screen coordinates as initial guess
			float srcNX = screenX;
			float srcNY = screenY;
			
			// Iterate to find the correct source coordinates
			// Usually converges in 2-3 iterations, reduced to 3 for performance
			for(int iter = 0; iter < 3; iter++)
			{
				// Forward: rotate source point (srcNX, srcNY, 0) in 3D
				// Rotate around X axis
				float px = srcNX;
				float py = srcNY * cosX;
				float pz = srcNY * sinX;
				
				// Rotate around Y axis
				float px2 = px * cosY - pz * sinY;
				float pz2 = px * sinY + pz * cosY;
				px = px2;
				pz = pz2;
				
				// Rotate around Z axis
				float px3 = px * cosZ - py * sinZ;
				float py3 = px * sinZ + py * cosZ;
				px = px3;
				py = py3;
				
				// Apply perspective projection
				// Perspective: screen = 3D / (1 + Z/distance)
				float perspFactor = 1.0f / (1.0f + pz / perspectiveDist);
				float projX = px * perspFactor;
				float projY = py * perspFactor;
				
				// Calculate error
				float errX = screenX - projX;
				float errY = screenY - projY;
				
				// Adjust source coordinates based on error
				// Approximate inverse by scaling error by inverse of derivative
				srcNX += errX * 0.8f;
				srcNY += errY * 0.8f;
			}
			
			// Convert back to pixel coordinates
			srcX = srcNX * centerX + centerX + offsetX;
			srcY = srcNY * centerY + centerY + offsetY;
			
			// Clamp to source bounds (optimized)
			float maxX = (float)(width - 1);
			float maxY = (float)(height - 1);
			if (srcX < 0.0f) srcX = 0.0f;
			else if (srcX > maxX) srcX = maxX;
			if (srcY < 0.0f) srcY = 0.0f;
			else if (srcY > maxY) srcY = maxY;
			
			// Nearest neighbor sampling
			srcXInt = (u32)srcX;
			srcYInt = (u32)srcY;
			
			if (srcXInt < width && srcYInt < height)
			{
				srcAddr = srcYInt * stride + srcXInt * 3;
				
				// Copy RGB pixel
				destFrame[destAddr] = srcFrame[srcAddr];
				destFrame[destAddr + 1] = srcFrame[srcAddr + 1];
				destFrame[destAddr + 2] = srcFrame[srcAddr + 2];
			}
			// If out of bounds, pixel remains cleared (black)
			
			destAddr += 3;
		}
	}
	
	Xil_DCacheFlushRange((unsigned int) destFrame, height * stride);
}

/*
 * Clear Frame - Fill frame with black (RGB = 0,0,0)
 * Useful before applying effects like zoom/rotate to avoid artifacts
 */
void DemoClearFrame(u8 *frame, u32 width, u32 height, u32 stride)
{
	u32 ycoi;
	u32 totalBytes = height * stride;
	
	// Optimized: clear entire frame buffer in one pass
	// Use word-aligned clearing for better performance
	u32 *frame32 = (u32 *)frame;
	u32 wordsToClear = totalBytes / 4;
	
	// Clear in 32-bit words (much faster)
	for (u32 i = 0; i < wordsToClear; i++)
	{
		frame32[i] = 0;
	}
	
	// Clear remaining bytes (if not word-aligned)
	u32 remainingBytes = totalBytes % 4;
	if (remainingBytes > 0)
	{
		u8 *remainingPtr = (u8 *)&frame32[wordsToClear];
		for (u32 i = 0; i < remainingBytes; i++)
		{
			remainingPtr[i] = 0;
		}
	}
	
	// Flush cache to ensure clearing is visible
	Xil_DCacheFlushRange((unsigned int) frame, totalBytes);
}

/*
 * Shrink and Random Position Effect - Shrinks image to 75% and places it at random position
 * Works on RGB frames (both animations and video)
 */
void DemoShrinkRandomEffect(u8 *srcFrame, u8 *destFrame, u32 srcWidth, u32 srcHeight, u32 destWidth, u32 destHeight, u32 stride)
{
	u32 xcoi, ycoi;
	u32 destAddr;
	u32 srcX, srcY;
	u32 srcAddr;
	
	// Shrink to 75% (scale factor 0.75)
	float scale = 0.75f;
	u32 shrunkWidth = (u32)(srcWidth * scale);
	u32 shrunkHeight = (u32)(srcHeight * scale);
	
	// Generate random position (using a simple pseudo-random based on time/state)
	// Use a simple LCG (Linear Congruential Generator) for pseudo-random
	static u32 randomSeed = 12345;
	randomSeed = randomSeed * 1103515245 + 12345;
	u32 randX = randomSeed;
	randomSeed = randomSeed * 1103515245 + 12345;
	u32 randY = randomSeed;
	
	// Calculate random position ensuring shrunk image fits
	u32 maxX = (destWidth > shrunkWidth) ? (destWidth - shrunkWidth) : 0;
	u32 maxY = (destHeight > shrunkHeight) ? (destHeight - shrunkHeight) : 0;
	
	u32 posX = (maxX > 0) ? (randX % maxX) : 0;
	u32 posY = (maxY > 0) ? (randY % maxY) : 0;
	
	// Clear destination (frame should already be cleared, but ensure it)
	DemoClearFrame(destFrame, destWidth, destHeight, stride);
	
	// Copy and scale source to destination at random position
	for(ycoi = 0; ycoi < shrunkHeight && (posY + ycoi) < destHeight; ycoi++)
	{
		destAddr = (posY + ycoi) * stride + posX * 3;
		
		// Calculate source Y (scale up)
		srcY = (ycoi * srcHeight) / shrunkHeight;
		if (srcY >= srcHeight) srcY = srcHeight - 1;
		
		for(xcoi = 0; xcoi < shrunkWidth && (posX + xcoi) < destWidth; xcoi++)
		{
			// Calculate source X (scale up)
			srcX = (xcoi * srcWidth) / shrunkWidth;
			if (srcX >= srcWidth) srcX = srcWidth - 1;
			
			srcAddr = srcY * stride + srcX * 3;
			
			// Copy RGB pixel
			destFrame[destAddr] = srcFrame[srcAddr];
			destFrame[destAddr + 1] = srcFrame[srcAddr + 1];
			destFrame[destAddr + 2] = srcFrame[srcAddr + 2];
			
			destAddr += 3;
		}
	}
	
	Xil_DCacheFlushRange((unsigned int) destFrame, destHeight * stride);
}

/*
 * Run Animated 3D Effect - Continuously rotates image in 3D space
 * axis: 'X', 'Y', 'Z', or 'A' (all axes)
 * scale: scale factor for the image (0.7 = 70% size)
 */
void DemoRunAnimated3DEffect(u8 *srcFrame, u8 **pFrames, u32 srcFrameIdx, u32 srcWidth, u32 srcHeight, u32 srcStride, u32 destWidth, u32 destHeight, char axis, float scale, DisplayCtrl *dispCtrl, VideoCapture *videoCapt)
{
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


