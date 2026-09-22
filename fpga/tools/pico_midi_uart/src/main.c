#include "pico/stdlib.h"
#include "hardware/gpio.h"
#include "hardware/uart.h"
#include "tusb.h"

#if __has_include("bsp/board_api.h")
#include "bsp/board_api.h"
#else
#include "bsp/board.h"
#endif

/*
 * USB-MIDI gadget on the Pico USB port, raw MIDI bytes on UART0 @ 31250.
 *
 * The Pico does not map CCs. Channel-1 CC 1–35 → AXI lives on the Zynq
 * (fpga/z7_build/sw/midi_uart). TinyUSB stream_read/write is used so UART
 * sees DIN-style bytes, not USB-MIDI 4-byte CIN packets.
 *
 * Wiring (3.3 V TTL — not a DIN current-loop):
 *   Pico GP0 / UART0 TX  ->  Arty JA1_P Y18  UART1_RX
 *   Pico GP1 / UART0 RX  <-  Arty JA1_N Y19  UART1_TX
 *   Pico GND             --  Arty GND
 */

#ifndef MIDI_UART_BAUD
#define MIDI_UART_BAUD      31250
#endif

#define MIDI_UART           uart0
#define MIDI_UART_TX_PIN    0
#define MIDI_UART_RX_PIN    1

static void midi_uart_init(void)
{
    uart_init(MIDI_UART, MIDI_UART_BAUD);
    gpio_set_function(MIDI_UART_TX_PIN, GPIO_FUNC_UART);
    gpio_set_function(MIDI_UART_RX_PIN, GPIO_FUNC_UART);
    uart_set_hw_flow(MIDI_UART, false, false);
    uart_set_format(MIDI_UART, 8, 1, UART_PARITY_NONE);
    uart_set_fifo_enabled(MIDI_UART, true);
}

/* Host DAW → Pico USB-MIDI → raw bytes on UART TX. */
static void usb_to_uart(void)
{
    uint8_t buf[64];

    while (tud_midi_available()) {
        uint32_t n = tud_midi_stream_read(buf, sizeof(buf));
        for (uint32_t i = 0; i < n; i++) {
            while (!uart_is_writable(MIDI_UART)) {
                tud_task();
            }
            uart_putc_raw(MIDI_UART, buf[i]);
        }
    }
}

/* UART RX → USB-MIDI (future SysEx / echo from the Zynq). */
static void uart_to_usb(void)
{
    uint8_t buf[32];
    uint32_t n = 0;

    while (uart_is_readable(MIDI_UART) && n < sizeof(buf)) {
        buf[n++] = (uint8_t)uart_getc(MIDI_UART);
    }
    if (n && tud_midi_mounted()) {
        tud_midi_stream_write(0, buf, n);
    }
}

int main(void)
{
    board_init();

    tusb_rhport_init_t dev_init = {
        .role  = TUSB_ROLE_DEVICE,
        .speed = TUSB_SPEED_AUTO
    };
    tusb_init(BOARD_TUD_RHPORT, &dev_init);
    if (board_init_after_tusb) {
        board_init_after_tusb();
    }

    midi_uart_init();

#ifdef PICO_DEFAULT_LED_PIN
    gpio_init(PICO_DEFAULT_LED_PIN);
    gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);
#endif

    while (true) {
        tud_task();
        usb_to_uart();
        uart_to_usb();
#ifdef PICO_DEFAULT_LED_PIN
        gpio_put(PICO_DEFAULT_LED_PIN, tud_mounted());
#endif
    }
}
