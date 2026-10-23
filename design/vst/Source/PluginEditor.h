#pragma once

#include <juce_audio_processors/juce_audio_processors.h>
#include "PluginProcessor.h"
#include "MatrixGrid.h"

#include <functional>
#include <vector>

class PageTabs : public juce::Component
{
public:
    std::function<void (int)> onSelect;

    void setTabs(const juce::StringArray& names);
    void setActiveIndex(int index);
    void setRoundOuterBottomCorners(bool shouldRound);
    int contentWidth() const;

    void paint(juce::Graphics& g) override;
    void mouseDown(const juce::MouseEvent& event) override;

private:
    struct Tab
    {
        juce::String name;
        juce::Rectangle<int> bounds;
    };

    std::vector<Tab> layoutTabs() const;

    juce::StringArray names;
    int activeIndex = 0;
    bool roundOuterBottomCorners = false;
};

class OpenSpectreAudioProcessorEditor : public juce::AudioProcessorEditor,
                                        private juce::ChangeListener
{
public:
    explicit OpenSpectreAudioProcessorEditor(OpenSpectreAudioProcessor&);
    ~OpenSpectreAudioProcessorEditor() override;

    void paint(juce::Graphics&) override;
    void resized() override;

    static constexpr int kWindowWidth = 900;
    static constexpr int kWindowHeight = 760;

private:
    void changeListenerCallback(juce::ChangeBroadcaster* source) override;
    void selectPage(OpenSpectreAudioProcessor::Page page);
    void updatePageVisibility();

    OpenSpectreAudioProcessor& audioProcessor;
    OpenSpectreAudioProcessor::Page currentPage = OpenSpectreAudioProcessor::Page::classic;

    juce::Image background;
    juce::Image matrixBackground;

    PageTabs pageTabs;
    PageTabs modernTabs;
    MatrixGrid digitalGrid;
    MatrixGrid analogGrid;
    juce::TooltipWindow tooltipWindow;
    int modernSection = 0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(OpenSpectreAudioProcessorEditor)
};
