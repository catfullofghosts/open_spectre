#pragma once

#include <juce_gui_basics/juce_gui_basics.h>
#include "PluginProcessor.h"

#include <functional>

// Clickable crosspoint grid. One cell per input (row) and output (column).
class MatrixGrid : public juce::Component
{
public:
    MatrixGrid(OpenSpectreAudioProcessor& processor, int matrixId);

    void setTipHandler(std::function<void (juce::Point<int> screenPosition, const juce::String& text)> handler);

    void paint(juce::Graphics& g) override;
    void mouseMove(const juce::MouseEvent& event) override;
    void mouseDown(const juce::MouseEvent& event) override;
    void mouseExit(const juce::MouseEvent& event) override;

private:
    int rowCount() const;
    int columnCount() const;
    int columnAt(int x) const;
    int rowAt(int y) const;
    bool cellAt(juce::Point<int> position, int& row, int& column) const;
    juce::Rectangle<int> cellBounds(int row, int column) const;
    void updateHover(int row, int column, juce::Point<int> screenPosition);

    OpenSpectreAudioProcessor& processor;
    int matrixId = 0;
    int hoverRow = -1;
    int hoverColumn = -1;
    std::function<void (juce::Point<int>, const juce::String&)> tipHandler;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MatrixGrid)
};
