#ifndef MIDI_UART_H_
#define MIDI_UART_H_

#include "xil_types.h"
#include "xstatus.h"

/*
 * UART1 (EMIO, PMOD) is the Pico USB-MIDI link.
 * UART0 stays the FTDI console.
 *
 * Pico must use the same baud. 31250 is DIN MIDI; 115200 is easier to debug.
 */
#ifndef MIDI_UART_BAUD
#define MIDI_UART_BAUD 31250U
#endif

/*
 * Channel 1 CC map — contiguous, MSB/LSB pairs adjacent.
 *
 * Osc 1
 *   1  freq MSB     2  freq LSB     (14-bit)
 *   3  derivative   4  PWM duty     (0-127 → 0-360°)
 *   5  wave 0-3     6  sync 0-3
 *   7  speed        8  alpha        (12-bit)
 *
 * Osc 2 (same layout)
 *   9  freq MSB    10  freq LSB
 *  11  derivative  12  PWM duty
 *  13  wave        14  sync
 *  15  speed       16  alpha
 *
 * Noise
 *  17  freq MSB    18  freq LSB
 *  19  slew        20  slowdown
 *  21  recycle ≥64 22  alpha
 *
 * Audio
 *  23  crossover   24  T thresh     25  B thresh
 *
 * YUV (12-bit from adjacent 7+7)
 *  26  Y MSB       27  Y LSB
 *  28  Cr MSB      29  Cr LSB
 *  30  Cb MSB      31  Cb LSB
 *
 * Digital
 *  32  edge width  33  slow-cnt frame
 *  34  slow-cnt /4 35  CA rule      (0-127)
 *
 * Classic / noise extra
 *  36  classic all  (DAC + X delay + 4:3 + luma lift)
 *  37  noise reset
 *
 * Shape gen 1 (0-127 → 0-1000, selects 0-15)
 *  38  pos H       39  pos V       40  zoom H      41  zoom V
 *  42  circle      43  gear        44  lantern     45  fizz
 *  46  shape A     47  shape B
 *
 * Shape gen 2 (same layout)
 *  48  pos H       49  pos V       50  zoom H      51  zoom V
 *  52  circle      53  gear        54  lantern     55  fizz
 *  56  shape A     57  shape B
 *
 * Video
 *  58  vid span     (0-127 → 0-255)
 *
 * Matrix SysEx (educational 0x7D, "SP"):
 *   F0 7D 53 50 20 <mat> <out> <in> <on> F7
 *     mat 0=digital 1=analog, on 0/1
 *     digital out 0-56 in 0-63; analog out 0-19 in 0-15
 *   F0 7D 53 50 21 <mat> <out> F7
 *     clear one output; out=127 clears all
 *
 * Text plane SysEx. Cells are 80 x 45. A cell value is character in
 * [7:0] and ink colour in [11:8]. Colour 0 is transparent.
 *   F0 7D 53 50 33 <index lo> <index hi> <count> <char lo> <attr> ... F7
 *     index is 14-bit, cell = row*80+column
 *     char bit 7 is attr bit 0, colour is attr [4:1]
 *   F0 7D 53 50 34 <row> F7
 *     row 0-44 clears that row; row 127 clears the plane
 */

int MidiUartInit(void);
void MidiUartPoll(void);
int MidiUartTryRead(u8 *byte);

u32 MidiUartByteCount(void);
u32 MidiUartMsgCount(void);
u8 MidiUartLastStatus(void);
u8 MidiUartLastData1(void);
u8 MidiUartLastData2(void);

#endif
