#pragma once

#include <juce_core/juce_core.h>
#include <array>

// Pin names match fpga/tools/ems_tester/gui/midi_matrix_grid.py.
// Row is a matrix input, column is a matrix output.

inline std::array<juce::String, 64> makeDigitalInputNames()
{
    std::array<juce::String, 64> names;

    for (int i = 0; i < 64; ++i)
        names[(size_t) i] = "in_" + juce::String(i);

    for (int i = 0; i < 18; ++i)
        names[(size_t) i] = "xy_inv_out_" + juce::String(i);

    names[18] = "slow_cnt_6";
    names[19] = "slow_cnt_3";
    names[20] = "slow_cnt_1_5";
    names[21] = "slow_cnt_0_6";
    names[22] = "slow_cnt_0_4";
    names[23] = "slow_cnt_0_2";

    for (int i = 0; i < 4; ++i)
    {
        names[(size_t) (24 + i)] = "overlay_gate_out_" + juce::String(i);
        names[(size_t) (28 + i)] = "inv_out_" + juce::String(i);
        names[(size_t) (32 + i)] = "edge_detector_out_" + juce::String(i);
    }

    names[36] = "delay_out";
    names[37] = "ff_out_a";
    names[38] = "ff_out_b";
    names[39] = "shape1_a";
    names[40] = "shape1_b";
    names[41] = "shape2_a";
    names[42] = "shape2_b";

    for (int i = 0; i < 7; ++i)
        names[(size_t) (43 + i)] = "comp_output_" + juce::String(i);

    names[50] = "gnd";
    names[51] = "osc1_sqr";
    names[52] = "osc2_sqr";
    names[53] = "random1";
    names[54] = "random2";
    names[55] = "audio_T";
    names[56] = "audio_B";
    names[57] = "ca_out";
    names[63] = "vcc";

    return names;
}

inline std::array<juce::String, 57> makeDigitalOutputNames()
{
    std::array<juce::String, 57> names;

    for (int i = 0; i < 57; ++i)
        names[(size_t) i] = "out_" + juce::String(i);

    for (int i = 0; i < 18; ++i)
        names[(size_t) i] = "xy_inv_in_" + juce::String(i);

    names[18] = "overlay_gate1_0";
    names[19] = "overlay_gate2_0";
    names[20] = "overlay_gate1_1";
    names[21] = "overlay_gate2_1";
    names[22] = "overlay_gate1_2";
    names[23] = "overlay_gate2_2";
    names[24] = "overlay_gate1_3";
    names[25] = "overlay_gate2_3";

    for (int i = 0; i < 4; ++i)
        names[(size_t) (26 + i)] = "inv_in_" + juce::String(i);

    names[30] = "edge_detector_in";
    names[31] = "delay_in";
    names[32] = "ff_in_a";
    names[33] = "ff_in_b";
    names[34] = "acm_out1";
    names[35] = "acm_out2";

    for (int i = 0; i < 4; ++i)
        names[(size_t) (39 - i)] = "luma_in1_" + juce::String(i);

    for (int i = 0; i < 3; ++i)
    {
        names[(size_t) (42 - i)] = "chroma_mux_in1_" + juce::String(i);
        names[(size_t) (45 - i)] = "chroma_mux_in1_" + juce::String(i + 3);
    }

    for (int i = 0; i < 4; ++i)
        names[(size_t) (49 - i)] = "luma_in2_" + juce::String(i);

    for (int i = 0; i < 3; ++i)
    {
        names[(size_t) (52 - i)] = "chroma_mux_in2_" + juce::String(i);
        names[(size_t) (55 - i)] = "chroma_mux_in2_" + juce::String(i + 3);
    }

    names[56] = "chrom_swap";
    return names;
}

inline const std::array<juce::String, 64>& digitalInputNames()
{
    static const std::array<juce::String, 64> names = makeDigitalInputNames();
    return names;
}

inline const std::array<juce::String, 57>& digitalOutputNames()
{
    static const std::array<juce::String, 57> names = makeDigitalOutputNames();
    return names;
}

inline juce::String analogInputName(int row)
{
    static const char* names[] = {
        "osc1_sq", "osc1_sin", "osc2_sq", "osc2_sin",
        "noise_1", "noise_2", "audio_in_t", "audio_in_b",
        "audio_in_sig", "dsm_hi", "dsm_lo"
    };

    if (row >= 0 && row < 11)
        return names[row];

    return "analog_in_" + juce::String(row);
}

inline juce::String analogOutputName(int col)
{
    static const char* names[] = {
        "pos_h_1", "pos_v_1", "zoom_h_1", "zoom_v_1", "circle_1", "gear_1",
        "lantern_1", "fizz_1", "pos_h_2", "pos_v_2", "zoom_h_2", "zoom_v_2",
        "circle_2", "gear_2", "lantern_2", "fizz_2", "y_anna", "u_anna",
        "v_anna", "vid_span"
    };

    if (col >= 0 && col < 20)
        return names[col];

    return "analog_out_" + juce::String(col);
}

inline juce::String matrixCellLabel(int matrixId, int row, int col)
{
    if (matrixId == 0)
    {
        const auto& inputs = digitalInputNames();
        const auto& outputs = digitalOutputNames();
        const juce::String input = (row >= 0 && row < (int) inputs.size()) ? inputs[(size_t) row]
                                                                            : "in_" + juce::String(row);
        const juce::String output = (col >= 0 && col < (int) outputs.size()) ? outputs[(size_t) col]
                                                                              : "out_" + juce::String(col);
        return input + " -> " + output;
    }

    return analogInputName(row) + " -> " + analogOutputName(col);
}
