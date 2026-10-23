#include "PluginEditor.h"
#include "BinaryData.h"

constexpr int kSafeRight = 870;
constexpr int kTabTop = 0;
constexpr int kTabHeight = 22;
constexpr int kTabGap = 0;
constexpr int kTabPad = 16;
constexpr int kTabMinWidth = 36;

juce::Rectangle<int> inclusiveRect(int x, int y, int right, int bottom)
{
    return { x, y, right - x + 1, bottom - y + 1 };
}

juce::Font tabFont()
{
    return juce::Font(juce::FontOptions(12.0f));
}

int tabWidth(const juce::Font& font, const juce::String& label)
{
    return juce::jmax(kTabMinWidth, juce::GlyphArrangement::getStringWidthInt(font, label) + kTabPad);
}

constexpr int kTabCorner = 8;

const juce::Colour kWoodLight (0xffB89A7E);
const juce::Colour kWoodDark (0xff4A3829);
const juce::Colour kWoodInk (0xff2A2018);
const juce::Colour kWoodHighlight (0xffF4E8D8);

void PageTabs::setTabs(const juce::StringArray& tabs)
{
    names = tabs;
    activeIndex = juce::jlimit(0, juce::jmax(0, names.size() - 1), activeIndex);
    repaint();
}

void PageTabs::setActiveIndex(int index)
{
    if (names.isEmpty())
        return;

    index = juce::jlimit(0, names.size() - 1, index);

    if (activeIndex == index)
        return;

    activeIndex = index;
    repaint();
}

void PageTabs::setRoundOuterBottomCorners(bool shouldRound)
{
    roundOuterBottomCorners = shouldRound;
    repaint();
}

std::vector<PageTabs::Tab> PageTabs::layoutTabs() const
{
    const auto font = tabFont();
    int x = 0;
    std::vector<Tab> tabs;

    for (const auto& name : names)
    {
        const int width = tabWidth(font, name);
        tabs.push_back({ name, { x, 0, width, getHeight() } });
        x += width + kTabGap;
    }

    return tabs;
}

int PageTabs::contentWidth() const
{
    const auto font = tabFont();
    int width = 0;

    for (const auto& name : names)
        width += tabWidth(font, name);

    if (names.size() > 1)
        width += kTabGap * (names.size() - 1);

    return width;
}

void PageTabs::paint(juce::Graphics& g)
{
    const auto font = tabFont();
    g.setFont(font);

    const auto tabs = layoutTabs();
    const int last = (int) tabs.size() - 1;

    for (int i = 0; i <= last; ++i)
    {
        const auto& tab = tabs[(size_t) i];
        const bool active = i == activeIndex;
        const bool roundLeft = roundOuterBottomCorners && i == 0;
        const bool roundRight = roundOuterBottomCorners && i == last;
        const auto area = tab.bounds.toFloat();

        juce::Path shape;
        shape.addRoundedRectangle(area.getX(), area.getY(), area.getWidth(), area.getHeight(),
                                  (float) kTabCorner, (float) kTabCorner,
                                  false, false, roundLeft, roundRight);

        g.setColour(active ? kWoodLight : kWoodDark);
        g.fillPath(shape);
        g.setColour(active ? kWoodInk : kWoodHighlight);
        g.drawText(tab.name, tab.bounds, juce::Justification::centred, false);
    }

    g.setColour(kWoodInk);

    for (int i = 0; i < last; ++i)
        g.fillRect(tabs[(size_t) i].bounds.getRight(), 0, 1, getHeight());

    juce::Path outline;
    const auto bounds = getLocalBounds().toFloat().reduced(0.5f);
    outline.addRoundedRectangle(bounds.getX(), bounds.getY(), bounds.getWidth(), bounds.getHeight(),
                                (float) kTabCorner, (float) kTabCorner,
                                false, false, roundOuterBottomCorners, roundOuterBottomCorners);
    g.strokePath(outline, juce::PathStrokeType(1.0f));
}

void PageTabs::mouseDown(const juce::MouseEvent& event)
{
    const auto tabs = layoutTabs();

    for (int i = 0; i < (int) tabs.size(); ++i)
    {
        if (tabs[(size_t) i].bounds.contains(event.getPosition()) && onSelect != nullptr)
        {
            onSelect(i);
            return;
        }
    }
}

OpenSpectreAudioProcessorEditor::OpenSpectreAudioProcessorEditor(OpenSpectreAudioProcessor& processor)
    : AudioProcessorEditor(&processor),
      audioProcessor(processor),
      currentPage(processor.getPage()),
      digitalGrid(processor, OpenSpectreAudioProcessor::kMatrixDigital),
      analogGrid(processor, OpenSpectreAudioProcessor::kMatrixAnalog),
      tooltipWindow(this, 0)
{
    background = juce::ImageFileFormat::loadFrom(BinaryData::blank_VST_BG_png,
                                                 BinaryData::blank_VST_BG_pngSize);
    matrixBackground = juce::ImageFileFormat::loadFrom(BinaryData::blank_VST_matrix_png,
                                                       BinaryData::blank_VST_matrix_pngSize);

    pageTabs.setTabs({ "classic", "modern", "express", "fx", "ext", "settings" });
    pageTabs.setRoundOuterBottomCorners(true);
    pageTabs.setActiveIndex((int) currentPage);
    pageTabs.onSelect = [this](int index) { selectPage((OpenSpectreAudioProcessor::Page) index); };

    modernTabs.setTabs({ "digital", "analog" });
    modernTabs.setActiveIndex(modernSection);
    modernTabs.onSelect = [this](int index)
    {
        modernSection = index;
        modernTabs.setActiveIndex(index);
    };

    const auto showTip = [this](juce::Point<int> screenPosition, const juce::String& text)
    {
        if (text.isEmpty())
            tooltipWindow.hideTip();
        else
            tooltipWindow.displayTip(screenPosition, text);
    };

    digitalGrid.setTipHandler(showTip);
    analogGrid.setTipHandler(showTip);
    tooltipWindow.setInterceptsMouseClicks(false, false);

    addAndMakeVisible(pageTabs);
    addAndMakeVisible(modernTabs);
    addAndMakeVisible(digitalGrid);
    addAndMakeVisible(analogGrid);

    audioProcessor.addChangeListener(this);

    setOpaque(true);
    setResizeLimits(kWindowWidth, kWindowHeight, kWindowWidth, kWindowHeight);
    setResizable(false, false);
    setSize(kWindowWidth, kWindowHeight);
}

OpenSpectreAudioProcessorEditor::~OpenSpectreAudioProcessorEditor()
{
    audioProcessor.removeChangeListener(this);
}

void OpenSpectreAudioProcessorEditor::paint(juce::Graphics& g)
{
    const auto& image = currentPage == OpenSpectreAudioProcessor::Page::classic
        ? matrixBackground
        : background;

    if (image.isValid())
        g.drawImageAt(image, 0, 0);
    else
        g.fillAll(juce::Colours::white);
}

void OpenSpectreAudioProcessorEditor::resized()
{
    const int tabWidthPx = pageTabs.contentWidth();
    pageTabs.setBounds(kSafeRight - tabWidthPx, kTabTop, tabWidthPx, kTabHeight);

    const int modernWidth = modernTabs.contentWidth();
    modernTabs.setBounds(kSafeRight - modernWidth, 48, modernWidth, kTabHeight);

    digitalGrid.setBounds(inclusiveRect(64, 89, 524, 480));
    analogGrid.setBounds(inclusiveRect(567, 89, 857, 297));
    updatePageVisibility();
}

void OpenSpectreAudioProcessorEditor::changeListenerCallback(juce::ChangeBroadcaster* source)
{
    juce::ignoreUnused(source);
    currentPage = audioProcessor.getPage();
    pageTabs.setActiveIndex((int) currentPage);
    updatePageVisibility();
    repaint();
}

void OpenSpectreAudioProcessorEditor::selectPage(OpenSpectreAudioProcessor::Page page)
{
    currentPage = page;
    pageTabs.setActiveIndex((int) page);
    audioProcessor.setPage(page);
    updatePageVisibility();
    repaint();
}

void OpenSpectreAudioProcessorEditor::updatePageVisibility()
{
    const bool classic = currentPage == OpenSpectreAudioProcessor::Page::classic;
    const bool modern = currentPage == OpenSpectreAudioProcessor::Page::modern;
    digitalGrid.setVisible(classic);
    analogGrid.setVisible(classic);
    modernTabs.setVisible(modern);

    if (! classic)
        tooltipWindow.hideTip();
}
