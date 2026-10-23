#pragma once

#include "OutputFx.h"

// Mix/wipe controls from fpga/tools/ems_tester/gui/midi_gui_app.py _wipe_panel.
// Direction and blinds band share CC 101, matching _wipe_send_origin.

enum class MixEncode
{
    scale,
    bits,
    gate,
    pair,
    direction,
    band
};

struct MixWipeControl
{
    const char* id;
    const char* group;
    const char* label;
    bool toggle;
    int cc;
    int minimum;
    int maximum;
    int defaultValue;
    MixEncode encode;
    int encodeParam;
    const char* const* names;
};

inline constexpr const char* kMixModeNames[] = {
    "Mix", "Horizontal", "Vertical", "Square", "Diagonal",
    "Diamond", "Cross", "Barn doors", "Venetian", "V blinds"
};

inline constexpr const char* kMixDirectionNames[] = {
    "0 centre", "1 north", "2 east", "3 south",
    "4 west", "5 NE", "6 SE", "7 SW", "8 NW"
};

inline constexpr const char* kMixBandNames[] = { "64 px", "128 px", "256 px", "512 px" };

inline constexpr const char* kMixBorderNames[] = {
    "Black", "Grey", "White", "Red", "Green", "Blue",
    "Yellow", "Cyan", "Magenta", "Orange", "Rose",
    "Purple", "Lime", "Teal", "Brown", "Dark grey"
};

inline constexpr MixWipeControl kMixWipe[] = {
    { "mode", "Mix", "Mode", false, 99, 0, 9, 0, MixEncode::bits, 4, kMixModeNames },
    { "position", "Mix", "Position", false, 103, 0, 4095, 0, MixEncode::pair, 0, nullptr },
    { "soft", "Mix", "Soft edge", false, 102, 0, 255, 0, MixEncode::scale, 255, nullptr },
    { "invert", "Mix", "Invert", true, 100, 0, 1, 0, MixEncode::gate, 0, nullptr },

    { "direction", "Wipe", "Direction", false, 101, 0, 8, 0, MixEncode::direction, 4, kMixDirectionNames },
    { "band", "Wipe", "Band", false, 101, 0, 3, 0, MixEncode::band, 4, kMixBandNames },

    { "border", "Border", "Colour", false, 105, 0, 15, 0, MixEncode::bits, 4, kMixBorderNames },
    { "width", "Border", "Width", false, 106, 0, 127, 0, MixEncode::scale, 127, nullptr },
};

inline constexpr int kMixWipeCount = (int) (sizeof (kMixWipe) / sizeof (kMixWipe[0]));

inline int mixWipeOriginCode (int direction, int band)
{
    direction = fxClamp (direction, 0, 8);
    band = fxClamp (band, 0, 3);

    if (direction <= 3)
        return (band << 2) | direction;

    return direction;
}

template <typename Send>
void dispatchMixWipe (const MixWipeControl& control, int value, Send&& send)
{
    value = fxClamp (value, control.minimum, control.maximum);

    switch (control.encode)
    {
        case MixEncode::scale:
            send (control.cc, fxScaleToCc (value, control.encodeParam));
            break;
        case MixEncode::bits:
            send (control.cc, fxEnumToCc (value, control.encodeParam));
            break;
        case MixEncode::gate:
            send (control.cc, value != 0 ? 127 : 0);
            break;
        case MixEncode::pair:
        {
            int msb = 0;
            int lsb = 0;
            fxEncodeU14 (value, msb, lsb);
            send (control.cc, msb);
            send (control.cc + 1, lsb);
            break;
        }
        case MixEncode::direction:
        case MixEncode::band:
            break;
    }
}
