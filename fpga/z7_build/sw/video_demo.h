/************************************************************************/
/*																		*/
/*	video_demo.h	--	ZYBO Video demonstration 						*/
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

#ifndef VIDEO_DEMO_H_
#define VIDEO_DEMO_H_

/* ------------------------------------------------------------ */
/*				Include File Definitions						*/
/* ------------------------------------------------------------ */

#include "xil_types.h"
#include "display_ctrl/display_ctrl.h"
#include "video_capture/video_capture.h"

/* ------------------------------------------------------------ */
/*					Miscellaneous Declarations					*/
/* ------------------------------------------------------------ */

#define DEMO_PATTERN_0 0
#define DEMO_PATTERN_1 1
#define DEMO_PATTERN_PLASMA 2
#define DEMO_PATTERN_SPIRAL 3
#define DEMO_PATTERN_RIPPLE 4
#define DEMO_PATTERN_WAVES 5
#define DEMO_PATTERN_GRADIENT 6
#define DEMO_PATTERN_MOIRE 7
#define DEMO_PATTERN_STANDING_WAVE 8
#define DEMO_PATTERN_LISSAJOUS 9
#define DEMO_PATTERN_FLOW_FIELD 10
#define DEMO_PATTERN_GRID 11


#define DEMO_MAX_FRAME (1920*1080*3)
#define DEMO_STRIDE (1920 * 3)

/*
 * Configure the Video capture driver to start streaming on signal
 * detection
 */
#define DEMO_START_ON_DET 1

/* ------------------------------------------------------------ */
/*					Procedure Declarations						*/
/* ------------------------------------------------------------ */

void DemoInitialize();
void DemoRun();
void DemoPrintMenu();
void DemoChangeRes();
void DemoCRMenu();
void DemoEffectMenu();
void DemoInvertFrame(u8 *srcFrame, u8 *destFrame, u32 width, u32 height, u32 stride);
void DemoPrintTest(u8 *frame, u32 width, u32 height, u32 stride, int pattern);
void DemoScaleFrame(u8 *srcFrame, u8 *destFrame, u32 srcWidth, u32 srcHeight, u32 destWidth, u32 destHeight, u32 stride);
void DemoISR(void *callBackRef, void *pVideo);

/* Evolving pattern functions - take time parameter for animation */
void DemoPlasmaPattern(u8 *frame, u32 width, u32 height, u32 stride, float time);
void DemoSpiralPattern(u8 *frame, u32 width, u32 height, u32 stride, float time);
void DemoRipplePattern(u8 *frame, u32 width, u32 height, u32 stride, float time);
void DemoWavePattern(u8 *frame, u32 width, u32 height, u32 stride, float time);
void DemoGradientPattern(u8 *frame, u32 width, u32 height, u32 stride, float time);
void DemoMoirePattern(u8 *frame, u32 width, u32 height, u32 stride, float time);
void DemoStandingWavePattern(u8 *frame, u32 width, u32 height, u32 stride, float time);
void DemoLissajousPattern(u8 *frame, u32 width, u32 height, u32 stride, float time);
void DemoFlowFieldPattern(u8 *frame, u32 width, u32 height, u32 stride, float time);

/* Helper function to run an animated pattern for a duration */
void DemoRunAnimatedPattern(u8 *frame, u32 width, u32 height, u32 stride, int pattern, u32 durationMs);

/* Fast scaling function - nearest neighbor upscale from low-res to full-res */
void DemoFastScalePattern(u8 *lowResFrame, u32 lowWidth, u32 lowHeight, u32 lowStride,
                          u8 *highResFrame, u32 highWidth, u32 highHeight, u32 highStride);

/* Video effect functions - work on RGB frames (animations or video) */
void DemoMirrorEffect(u8 *srcFrame, u8 *destFrame, u32 width, u32 height, u32 stride, int mirrorType);
void DemoTileEffect(u8 *srcFrame, u8 *destFrame, u32 srcWidth, u32 srcHeight, u32 destWidth, u32 destHeight, u32 stride, u32 tilesX, u32 tilesY);
void DemoZoomEffect(u8 *srcFrame, u8 *destFrame, u32 width, u32 height, u32 stride, float zoom, float centerX, float centerY);
void DemoMosaicEffect(u8 *srcFrame, u8 *destFrame, u32 width, u32 height, u32 stride, u32 blockSize);
void Demo3DPlaneEffect(u8 *srcFrame, u8 *destFrame, u32 width, u32 height, u32 stride, float rotX, float rotY, float rotZ, float scale, float offsetX, float offsetY);
void DemoClearFrame(u8 *frame, u32 width, u32 height, u32 stride);
void DemoShrinkRandomEffect(u8 *srcFrame, u8 *destFrame, u32 srcWidth, u32 srcHeight, u32 destWidth, u32 destHeight, u32 stride);
void DemoRunAnimated3DEffect(u8 *srcFrame, u8 **pFrames, u32 srcFrameIdx, u32 srcWidth, u32 srcHeight, u32 srcStride, u32 destWidth, u32 destHeight, char axis, float scale, DisplayCtrl *dispCtrl, VideoCapture *videoCapt);

/* Effect type definitions */
#define DEMO_MIRROR_NONE 0
#define DEMO_MIRROR_HORIZONTAL 1
#define DEMO_MIRROR_VERTICAL 2
#define DEMO_MIRROR_BOTH 3
#define DEMO_MIRROR_CENTER_X 4
#define DEMO_MIRROR_CENTER_Y 5
#define DEMO_MIRROR_CENTER_XY 6

/* ------------------------------------------------------------ */

/************************************************************************/

#endif /* VIDEO_DEMO_H_ */
