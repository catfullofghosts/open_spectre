#pragma once

// Output video FX, matching fpga/tools/ems_tester/gui/midi_gui_app.py Video FX.
// Values are the same units as that panel. Encoding matches its CC helpers.

enum class FxEncode
{
    raw,
    scale,
    bits,
    gate,
    rotate,
    pair
};

struct OutputFxControl
{
    const char* id;
    const char* group;
    const char* label;
    bool toggle;
    int cc;
    int minimum;
    int maximum;
    int defaultValue;
    FxEncode encode;
    int encodeParam;
    const char* const* names;
};

inline constexpr const char* kSwapNames[] = { "RGB", "BGR", "GRB", "RBG" };
inline constexpr const char* kLineNames[] = { "1", "2", "4", "8", "16" };
inline constexpr const char* kPrevNames[] = { "Off", "OR", "AND", "XOR" };
inline constexpr const char* kDepthNames[] = { "6-bit", "5-bit", "4-bit", "3-bit" };
inline constexpr const char* kPosterNames[] = { "Off", "7-bit", "6-bit", "5-bit", "4-bit", "3-bit", "2-bit", "1-bit" };
inline constexpr const char* kColourNames[] = {
    "Black", "Grey", "White", "Red", "Green", "Blue",
    "Yellow", "Cyan", "Mag", "Orange", "Rose",
    "Purple", "Lime", "Teal", "Brown", "Dk grey"
};

inline constexpr OutputFxControl kOutputFx[] = {
    { "rRot", "Bit rotate", "R rot", false, 92, -7, 7, 0, FxEncode::rotate, 4, nullptr },
    { "gRot", "Bit rotate", "G rot", false, 93, -7, 7, 0, FxEncode::rotate, 4, nullptr },
    { "bRot", "Bit rotate", "B rot", false, 94, -7, 7, 0, FxEncode::rotate, 4, nullptr },

    { "invR", "Color", "Inv R", true, 59, 0, 1, 0, FxEncode::gate, 0, nullptr },
    { "invG", "Color", "Inv G", true, 60, 0, 1, 0, FxEncode::gate, 0, nullptr },
    { "invB", "Color", "Inv B", true, 61, 0, 1, 0, FxEncode::gate, 0, nullptr },
    { "swap", "Color", "Swap", false, 62, 0, 3, 0, FxEncode::bits, 2, kSwapNames },
    { "revR", "Color", "Rev R", true, 63, 0, 1, 0, FxEncode::gate, 0, nullptr },
    { "revG", "Color", "Rev G", true, 64, 0, 1, 0, FxEncode::gate, 0, nullptr },
    { "revB", "Color", "Rev B", true, 65, 0, 1, 0, FxEncode::gate, 0, nullptr },

    { "scan", "Scan", "Scan", true, 66, 0, 1, 0, FxEncode::gate, 0, nullptr },
    { "scanDelay", "Scan", "Delay", false, 67, 0, 16, 0, FxEncode::bits, 5, nullptr },
    { "scanLines", "Scan", "Lines", false, 90, 0, 4, 0, FxEncode::bits, 3, kLineNames },
    { "crt", "Scan", "CRT", true, 91, 0, 1, 0, FxEncode::gate, 0, nullptr },
    { "prev", "Scan", "Prev", false, 68, 0, 3, 0, FxEncode::bits, 2, kPrevNames },

    { "smear", "Smear", "Repeat", false, 95, 0, 64, 0, FxEncode::raw, 0, nullptr },
    { "thrR", "Smear", "R thr", false, 96, 0, 255, 128, FxEncode::scale, 255, nullptr },
    { "thrG", "Smear", "G thr", false, 97, 0, 255, 128, FxEncode::scale, 255, nullptr },
    { "thrB", "Smear", "B thr", false, 98, 0, 255, 128, FxEncode::scale, 255, nullptr },

    { "fullR", "Bit plane", "R full", true, 69, 0, 1, 1, FxEncode::gate, 0, nullptr },
    { "bitR", "Bit plane", "R bit", false, 70, 0, 7, 0, FxEncode::bits, 3, nullptr },
    { "fullG", "Bit plane", "G full", true, 71, 0, 1, 1, FxEncode::gate, 0, nullptr },
    { "bitG", "Bit plane", "G bit", false, 72, 0, 7, 0, FxEncode::bits, 3, nullptr },
    { "fullB", "Bit plane", "B full", true, 73, 0, 1, 1, FxEncode::gate, 0, nullptr },
    { "bitB", "Bit plane", "B bit", false, 74, 0, 7, 0, FxEncode::bits, 3, nullptr },

    { "dither", "Dither", "Dither", true, 75, 0, 1, 0, FxEncode::gate, 0, nullptr },
    { "depth", "Dither", "Depth", false, 76, 0, 3, 0, FxEncode::bits, 2, kDepthNames },
    { "poster", "Dither", "Poster", false, 89, 0, 7, 0, FxEncode::bits, 3, kPosterNames },

    { "mirror", "Mirror", "Mirror", true, 77, 0, 1, 0, FxEncode::gate, 0, nullptr },
    { "width", "Mirror", "Width", false, 78, 0, 960, 360, FxEncode::pair, 0, nullptr },

    { "chroma", "Chroma", "Chroma", true, 80, 0, 1, 0, FxEncode::gate, 0, nullptr },
    { "delayG", "Chroma", "G delay", false, 81, 0, 32, 0, FxEncode::bits, 6, nullptr },
    { "delayB", "Chroma", "B delay", false, 82, 0, 32, 0, FxEncode::bits, 6, nullptr },

    { "emboss", "Emboss", "Emboss", true, 83, 0, 1, 0, FxEncode::gate, 0, nullptr },
    { "shadow", "Emboss", "Shadow", true, 84, 0, 1, 0, FxEncode::gate, 0, nullptr },
    { "embThresh", "Emboss", "Thresh", false, 85, 1, 255, 1, FxEncode::scale, 255, nullptr },
    { "embStrength", "Emboss", "Strength", false, 86, 1, 255, 1, FxEncode::scale, 255, nullptr },
    { "fringe", "Emboss", "Fringe", true, 87, 0, 1, 0, FxEncode::gate, 0, nullptr },
    { "fringeColour", "Emboss", "Colour", false, 88, 0, 15, 0, FxEncode::bits, 4, kColourNames },
};

inline constexpr int kOutputFxCount = (int) (sizeof (kOutputFx) / sizeof (kOutputFx[0]));

inline int fxClamp (int value, int minimum, int maximum)
{
    if (value < minimum)
        return minimum;
    if (value > maximum)
        return maximum;
    return value;
}

inline int fxScaleToCc (int value, int maximum)
{
    if (maximum <= 0)
        return 0;

    const int scaled = (int) ((value * 127.0 / maximum) + (value >= 0 ? 0.5 : -0.5));
    return fxClamp (scaled, 0, 127);
}

inline int fxEnumToCc (int index, int bits)
{
    const int shift = 7 - bits;
    return fxClamp (index << shift, 0, 127);
}

inline int fxRotToCc (int steps)
{
    int code = 0;

    if (steps > 0)
        code = steps > 7 ? 7 : steps;
    else if (steps < 0)
        code = (7 - steps) > 14 ? 14 : (7 - steps);

    return fxEnumToCc (code, 4);
}

inline void fxEncodeU14 (int value, int& msb, int& lsb)
{
    value = fxClamp (value, 0, 16383);
    msb = (value >> 7) & 0x7f;
    lsb = value & 0x7f;
}

template <typename Send>
void dispatchOutputFx (const OutputFxControl& control, int value, Send&& send)
{
    value = fxClamp (value, control.minimum, control.maximum);

    switch (control.encode)
    {
        case FxEncode::raw:
            send (control.cc, fxClamp (value, 0, 127));
            break;
        case FxEncode::scale:
            send (control.cc, fxScaleToCc (value, control.encodeParam));
            break;
        case FxEncode::bits:
            send (control.cc, fxEnumToCc (value, control.encodeParam));
            break;
        case FxEncode::gate:
            send (control.cc, value != 0 ? 127 : 0);
            break;
        case FxEncode::rotate:
            send (control.cc, fxRotToCc (value));
            break;
        case FxEncode::pair:
        {
            int msb = 0;
            int lsb = 0;
            fxEncodeU14 (value, msb, lsb);
            send (control.cc, msb);
            send (control.cc + 1, lsb);
            break;
        }
    }
}
