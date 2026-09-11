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
 */

int MidiUartInit(void);
void MidiUartPoll(void);

u32 MidiUartMsgCount(void);
u8 MidiUartLastStatus(void);
u8 MidiUartLastData1(void);
u8 MidiUartLastData2(void);

#endif
