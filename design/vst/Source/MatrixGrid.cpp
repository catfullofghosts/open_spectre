#include "MatrixGrid.h"
#include "MatrixNames.h"

namespace
{
juce::Colour rgb(int hex)
{
    return juce::Colour(0xff000000 | (juce::uint32) hex);
}

juce::Colour subtle(juce::Colour colour)
{
    return colour.interpolatedWith(rgb(0xE6E6E6), 0.42f);
}

int digitalRowBlock(int row)
{
    if (0 <= row && row <= 17)  return 0;
    if (18 <= row && row <= 23) return 1;
    if (24 <= row && row <= 27) return 2;
    if (28 <= row && row <= 31) return 3;
    if (32 <= row && row <= 35) return 4;
    if (36 <= row && row <= 38) return 5;
    if (39 <= row && row <= 40) return 6;
    if (41 <= row && row <= 42) return 7;
    if (43 <= row && row <= 49) return 8;
    if (row == 50)              return 9;
    if (51 <= row && row <= 52) return 10;
    if (53 <= row && row <= 54) return 11;
    if (55 <= row && row <= 56) return 12;
    if (row == 57)              return 13;
    return 0;
}

int digitalColumnBlock(int column)
{
    if (0 <= column && column <= 17)  return 0;
    if (18 <= column && column <= 25) return 1;
    if (26 <= column && column <= 29) return 2;
    if (30 <= column && column <= 33) return 3;
    if (34 <= column && column <= 35) return 4;
    if (36 <= column && column <= 39) return 5;
    if (40 <= column && column <= 45) return 6;
    if (46 <= column && column <= 49) return 7;
    if (50 <= column && column <= 55) return 8;
    if (column == 56)                 return 9;
    return 0;
}

juce::Colour digitalRestingColour(int row, int column)
{
    const bool oddRow = (digitalRowBlock(row) % 2) == 1;
    const bool lightBlock = ((digitalRowBlock(row) + digitalColumnBlock(column)) % 2) == 0;

    if ((36 <= column && column <= 39) || (46 <= column && column <= 49))
        return subtle(oddRow ? rgb(0x6BA8B6) : rgb(0x8DC8D6));

    if ((40 <= column && column <= 45) || (50 <= column && column <= 55))
    {
        const int pairOrigin = column >= 50 ? 50 : 40;
        const bool evenInPair = ((column - pairOrigin) % 2) == 0;

        if (evenInPair)
            return subtle(oddRow ? rgb(0xC08691) : rgb(0xE0A6B1));

        return subtle(oddRow ? rgb(0x60BE70) : rgb(0x80DE80));
    }

    return lightBlock ? rgb(0xA6A6A6) : rgb(0x8E8E8E);
}

juce::Colour cellColour(int matrixId, int row, int column, bool on, bool hover)
{
    if (on)
        return hover ? rgb(0x45A049) : rgb(0x4CAF50);

    juce::Colour colour = rgb(0xA6A6A6);

    if (matrixId == OpenSpectreAudioProcessor::kMatrixDigital)
        colour = digitalRestingColour(row, column);
    else if (column >= OpenSpectreAudioProcessor::kAnalogOutputs - 4
             && column < OpenSpectreAudioProcessor::kAnalogOutputs - 1)
        colour = rgb(0x8E8E8E);

    return hover ? colour.darker(0.08f) : colour;
}

bool bitOn(const uint8_t* data, int sizeBytes, int index)
{
    if (index < 0 || (index >> 3) >= sizeBytes)
        return false;

    return (data[index >> 3] & (uint8_t) (1u << (index & 7))) != 0;
}
}

MatrixGrid::MatrixGrid(OpenSpectreAudioProcessor& processorIn, int matrixIdIn)
    : processor(processorIn), matrixId(matrixIdIn)
{
    setOpaque(false);
    setMouseCursor(juce::MouseCursor::PointingHandCursor);
}

void MatrixGrid::setTipHandler(std::function<void (juce::Point<int> screenPosition, const juce::String& text)> handler)
{
    tipHandler = std::move(handler);
}

int MatrixGrid::rowCount() const
{
    return matrixId == OpenSpectreAudioProcessor::kMatrixDigital
        ? OpenSpectreAudioProcessor::kDigitalGridRows
        : OpenSpectreAudioProcessor::kAnalogInputs;
}

int MatrixGrid::columnCount() const
{
    return matrixId == OpenSpectreAudioProcessor::kMatrixDigital
        ? OpenSpectreAudioProcessor::kDigitalOutputs
        : OpenSpectreAudioProcessor::kAnalogOutputs;
}

int MatrixGrid::columnAt(int x) const
{
    const int columns = columnCount();
    const int width = juce::jmax(1, getWidth());
    int column = juce::jlimit(0, columns - 1, x * columns / width);

    while (column < columns - 1 && (column + 1) * width / columns <= x)
        ++column;

    while (column > 0 && column * width / columns > x)
        --column;

    return column;
}

int MatrixGrid::rowAt(int y) const
{
    const int rows = rowCount();
    const int height = juce::jmax(1, getHeight());
    int row = juce::jlimit(0, rows - 1, y * rows / height);

    while (row < rows - 1 && (row + 1) * height / rows <= y)
        ++row;

    while (row > 0 && row * height / rows > y)
        --row;

    return row;
}

bool MatrixGrid::cellAt(juce::Point<int> position, int& row, int& column) const
{
    if (! getLocalBounds().contains(position))
        return false;

    column = columnAt(position.x);
    row = rowAt(position.y);
    return true;
}

juce::Rectangle<int> MatrixGrid::cellBounds(int row, int column) const
{
    const int rows = rowCount();
    const int columns = columnCount();
    const int width = juce::jmax(1, getWidth());
    const int height = juce::jmax(1, getHeight());
    const int x0 = column * width / columns;
    const int x1 = (column + 1) * width / columns;
    const int y0 = row * height / rows;
    const int y1 = (row + 1) * height / rows;
    return { x0, y0, juce::jmax(1, x1 - x0), juce::jmax(1, y1 - y0) };
}

void MatrixGrid::updateHover(int row, int column, juce::Point<int> screenPosition)
{
    if (row == hoverRow && column == hoverColumn)
        return;

    const int previousRow = hoverRow;
    const int previousColumn = hoverColumn;
    hoverRow = row;
    hoverColumn = column;

    if (previousRow >= 0 && previousColumn >= 0)
        repaint(cellBounds(previousRow, previousColumn).expanded(1));

    if (row >= 0 && column >= 0)
        repaint(cellBounds(row, column).expanded(1));

    if (tipHandler == nullptr)
        return;

    if (row < 0 || column < 0)
        tipHandler({}, {});
    else
        tipHandler(screenPosition, matrixCellLabel(matrixId, row, column));
}

void MatrixGrid::paint(juce::Graphics& g)
{
    const int rows = rowCount();
    const int columns = columnCount();
    const int width = getWidth();
    const int height = getHeight();

    const auto clip = g.getClipBounds();
    const bool digital = matrixId == OpenSpectreAudioProcessor::kMatrixDigital;
    const auto digitalBits = digital ? processor.copyDigitalBits() : std::array<uint8_t, OpenSpectreAudioProcessor::kDigitalBytes> {};
    const auto analogBits = digital ? std::array<uint8_t, OpenSpectreAudioProcessor::kAnalogBytes> {} : processor.copyAnalogBits();
    const uint8_t* bits = digital ? digitalBits.data() : analogBits.data();
    const int sizeBytes = digital ? (int) digitalBits.size() : (int) analogBits.size();

    for (int row = 0; row < rows; ++row)
    {
        const int y0 = row * height / rows;
        const int y1 = (row + 1) * height / rows;

        if (y1 < clip.getY() || y0 > clip.getBottom())
            continue;

        for (int column = 0; column < columns; ++column)
        {
            const int x0 = column * width / columns;
            const int x1 = (column + 1) * width / columns;

            if (x1 < clip.getX() || x0 > clip.getRight())
                continue;
            const bool on = bitOn(bits, sizeBytes, row * columns + column);
            const bool hover = row == hoverRow && column == hoverColumn;
            const float cellW = (float) juce::jmax(1, x1 - x0);
            const float cellH = (float) juce::jmax(1, y1 - y0);
            float diameter = juce::jmin(cellW, cellH);

            if (matrixId == OpenSpectreAudioProcessor::kMatrixAnalog)
                diameter = juce::jmax(1.0f, diameter - 1.0f);

            auto button = juce::Rectangle<float>((float) x0 + (cellW - diameter) * 0.5f,
                                                 (float) y0 + (cellH - diameter) * 0.5f,
                                                 diameter,
                                                 diameter);

            g.setColour(cellColour(matrixId, row, column, on, hover));
            g.fillEllipse(button);
        }
    }
}

void MatrixGrid::mouseMove(const juce::MouseEvent& event)
{
    int row = -1;
    int column = -1;

    if (! cellAt(event.getPosition(), row, column))
    {
        updateHover(-1, -1, event.getScreenPosition());
        return;
    }

    updateHover(row, column, event.getScreenPosition());
}

void MatrixGrid::mouseDown(const juce::MouseEvent& event)
{
    if (! event.mods.isLeftButtonDown())
        return;

    int row = -1;
    int column = -1;

    if (! cellAt(event.getPosition(), row, column))
        return;

    const int columns = columnCount();
    const auto digitalBits = processor.copyDigitalBits();
    const auto analogBits = processor.copyAnalogBits();
    const uint8_t* bits = matrixId == OpenSpectreAudioProcessor::kMatrixDigital
        ? digitalBits.data()
        : analogBits.data();
    const int sizeBytes = matrixId == OpenSpectreAudioProcessor::kMatrixDigital
        ? (int) digitalBits.size()
        : (int) analogBits.size();

    const bool next = ! bitOn(bits, sizeBytes, row * columns + column);
    processor.setCrosspoint(matrixId, column, row, next);
    repaint(cellBounds(row, column).expanded(1));
}

void MatrixGrid::mouseExit(const juce::MouseEvent& event)
{
    updateHover(-1, -1, event.getScreenPosition());
}
