cmake_minimum_required(VERSION 3.13)

include(${CMAKE_CURRENT_LIST_DIR}/pico_env.cmake)
include(pico_sdk_import.cmake)

project(pico_midi_uart C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# Import the host picotool before the SDK looks for it, so it does not
# try to compile picotool from source (needs a Windows host compiler).
if (PICO_PICOTOOL_EXE AND NOT TARGET picotool)
    add_executable(picotool IMPORTED GLOBAL)
    set_property(TARGET picotool PROPERTY IMPORTED_LOCATION "${PICO_PICOTOOL_EXE}")
endif()

pico_sdk_init()

add_executable(pico_midi_uart
    src/main.c
    src/usb_descriptors.c
)

target_include_directories(pico_midi_uart PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}/src
)

# Must match MIDI_UART_BAUD on the Zynq (midi_uart.h). 31250 is DIN MIDI.
target_compile_definitions(pico_midi_uart PRIVATE
    MIDI_UART_BAUD=31250
)

target_link_libraries(pico_midi_uart
    pico_stdlib
    pico_unique_id
    hardware_uart
    tinyusb_device
    tinyusb_board
)

# USB is MIDI only — do not steal the port for stdio.
pico_enable_stdio_usb(pico_midi_uart 0)
pico_enable_stdio_uart(pico_midi_uart 0)

pico_add_extra_outputs(pico_midi_uart)
