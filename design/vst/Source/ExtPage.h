#pragma once

#include <juce_gui_basics/juce_gui_basics.h>
#include "PluginProcessor.h"

#include <memory>
#include <vector>

class ExtPage : public juce::Component
{
public:
    explicit ExtPage (OpenSpectreAudioProcessor& processor);
    ~ExtPage() override;

    void paint (juce::Graphics& g) override;
    void resized() override;
    void syncFromProcessor();

private:
    class LookAndFeel;

    struct Slot
    {
        int index = 0;
        int height = 0;
        bool toggle = false;
        juce::Component* component = nullptr;
        juce::Label* caption = nullptr;
    };

    struct Group
    {
        juce::String title;
        std::unique_ptr<juce::Label> titleLabel;
        std::vector<Slot> slots;
    };

    OpenSpectreAudioProcessor& processor;
    std::unique_ptr<LookAndFeel> lookAndFeel;
    std::vector<std::unique_ptr<juce::Component>> owned;
    std::vector<Group> groups;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (ExtPage)
};
