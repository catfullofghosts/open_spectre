#include "FxPage.h"
#include "OutputFx.h"

#include <cmath>

namespace
{
const juce::Colour kBrown (0xff6B5340);
const juce::Colour kInk (0xff4A3829);
const juce::Colour kWoodLight (0xffB89A7E);
const juce::Colour kWoodDark (0xff4A3829);
const juce::Colour kDivider (0xffCDBBA6);

constexpr int kKnobHeight = 72;
constexpr int kCaptionHeight = 12;
constexpr int kTextBoxHeight = 12;
constexpr int kToggleHeight = 18;
constexpr int kTitleHeight = 13;
constexpr int kGap = 0;
constexpr int kColumnInset = 8;
}

class FxPage::LookAndFeel : public juce::LookAndFeel_V4
{
public:
    juce::Font getLabelFont (juce::Label&) override
    {
        return juce::Font (juce::FontOptions (11.0f));
    }

    juce::Font getTextButtonFont (juce::TextButton&, int) override
    {
        return juce::Font (juce::FontOptions (11.0f));
    }

    juce::Label* createSliderTextBox (juce::Slider& slider) override
    {
        auto* label = juce::LookAndFeel_V4::createSliderTextBox (slider);
        label->setFont (juce::Font (juce::FontOptions (11.0f)));
        return label;
    }

    void drawRotarySlider (juce::Graphics& g, int x, int y, int width, int height,
                           float sliderPos, float rotaryStartAngle, float rotaryEndAngle,
                           juce::Slider& slider) override
    {
        auto bounds = juce::Rectangle<int> (x, y, width, height).toFloat().reduced (2.0f);
        auto radius = juce::jmin (bounds.getWidth(), bounds.getHeight()) * 0.5f;
        auto toAngle = rotaryStartAngle + sliderPos * (rotaryEndAngle - rotaryStartAngle);
        auto lineW = juce::jmin (5.0f, radius * 0.28f);
        auto arcRadius = radius - lineW * 0.5f;
        auto centre = bounds.getCentre();

        juce::Path backgroundArc;
        backgroundArc.addCentredArc (centre.x, centre.y, arcRadius, arcRadius, 0.0f,
                                     rotaryStartAngle, rotaryEndAngle, true);
        g.setColour (slider.findColour (juce::Slider::rotarySliderOutlineColourId));
        g.strokePath (backgroundArc, juce::PathStrokeType (lineW, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));

        if (slider.isEnabled())
        {
            juce::Path valueArc;
            valueArc.addCentredArc (centre.x, centre.y, arcRadius, arcRadius, 0.0f,
                                    rotaryStartAngle, toAngle, true);
            g.setColour (slider.findColour (juce::Slider::rotarySliderFillColourId));
            g.strokePath (valueArc, juce::PathStrokeType (lineW, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));
        }

        auto thumbWidth = lineW * 1.6f;
        juce::Point<float> thumbPoint (centre.x + arcRadius * std::cos (toAngle - juce::MathConstants<float>::halfPi),
                                       centre.y + arcRadius * std::sin (toAngle - juce::MathConstants<float>::halfPi));
        g.setColour (slider.findColour (juce::Slider::thumbColourId));
        g.fillEllipse (juce::Rectangle<float> (thumbWidth, thumbWidth).withCentre (thumbPoint));
    }
};

FxPage::FxPage (OpenSpectreAudioProcessor& processorIn)
    : processor (processorIn)
{
    setOpaque (false);
    lookAndFeel = std::make_unique<LookAndFeel>();
    setLookAndFeel (lookAndFeel.get());

    for (int index = 0; index < kOutputFxCount; ++index)
    {
        const auto& spec = kOutputFx[index];
        const juce::String groupName (spec.group);

        if (groups.empty() || groups.back().title != groupName)
        {
            Group group;
            group.title = groupName;
            group.titleLabel = std::make_unique<juce::Label>();
            group.titleLabel->setText (groupName, juce::dontSendNotification);
            group.titleLabel->setJustificationType (juce::Justification::centredLeft);
            group.titleLabel->setFont (juce::Font (juce::FontOptions (12.0f)));
            group.titleLabel->setColour (juce::Label::textColourId, kInk);
            group.titleLabel->setInterceptsMouseClicks (false, false);
            addAndMakeVisible (*group.titleLabel);
            groups.push_back (std::move (group));
        }

        Slot slot;
        slot.index = index;
        slot.toggle = spec.toggle;

        if (spec.toggle)
        {
            auto button = std::make_unique<juce::TextButton> (spec.label);
            button->setClickingTogglesState (true);
            button->setColour (juce::TextButton::buttonColourId, juce::Colours::white);
            button->setColour (juce::TextButton::buttonOnColourId, kWoodDark);
            button->setColour (juce::TextButton::textColourOffId, kInk);
            button->setColour (juce::TextButton::textColourOnId, juce::Colour (0xffF4E8D8));
            button->onClick = [this, index, raw = button.get()]
            {
                processor.setOutputFx (index, raw->getToggleState() ? 1 : 0);
            };
            slot.height = kToggleHeight;
            slot.component = button.get();
            addAndMakeVisible (*button);
            owned.push_back (std::move (button));
        }
        else
        {
            auto caption = std::make_unique<juce::Label>();
            caption->setText (spec.label, juce::dontSendNotification);
            caption->setJustificationType (juce::Justification::centred);
            caption->setFont (juce::Font (juce::FontOptions (11.0f)));
            caption->setColour (juce::Label::textColourId, kInk);
            caption->setInterceptsMouseClicks (false, false);

            auto slider = std::make_unique<juce::Slider>();
            slider->setSliderStyle (juce::Slider::RotaryHorizontalVerticalDrag);
            slider->setTextBoxStyle (juce::Slider::TextBoxBelow, false, 80, kTextBoxHeight);
            slider->setRange (spec.minimum, spec.maximum, 1.0);
            slider->setDoubleClickReturnValue (true, spec.defaultValue);
            slider->setMouseDragSensitivity (110);
            slider->setPopupDisplayEnabled (false, false, nullptr);
            slider->setColour (juce::Slider::rotarySliderFillColourId, kWoodLight);
            slider->setColour (juce::Slider::rotarySliderOutlineColourId, kBrown);
            slider->setColour (juce::Slider::thumbColourId, juce::Colour (0xff2A2018));
            slider->setColour (juce::Slider::textBoxTextColourId, kInk);
            slider->setColour (juce::Slider::textBoxBackgroundColourId, juce::Colours::transparentBlack);
            slider->setColour (juce::Slider::textBoxOutlineColourId, juce::Colours::transparentBlack);

            if (spec.names != nullptr)
            {
                const int nameCount = spec.maximum - spec.minimum + 1;
                const int minimum = spec.minimum;
                const char* const* names = spec.names;
                slider->textFromValueFunction = [names, nameCount, minimum] (double value)
                {
                    const int nameIndex = (int) value - minimum;
                    if (nameIndex >= 0 && nameIndex < nameCount && names[nameIndex] != nullptr)
                        return juce::String (names[nameIndex]);
                    return juce::String ((int) value);
                };
                slider->valueFromTextFunction = [names, nameCount, minimum] (const juce::String& text)
                {
                    for (int nameIndex = 0; nameIndex < nameCount; ++nameIndex)
                        if (text == names[nameIndex])
                            return (double) (minimum + nameIndex);
                    return text.getDoubleValue();
                };
            }

            auto* sliderPtr = slider.get();
            slider->onValueChange = [this, index, sliderPtr]
            {
                processor.setOutputFx (index, (int) std::round (sliderPtr->getValue()));
            };

            slot.height = kKnobHeight;
            slot.component = sliderPtr;
            slot.caption = caption.get();
            addAndMakeVisible (*caption);
            addAndMakeVisible (*slider);
            owned.push_back (std::move (caption));
            owned.push_back (std::move (slider));
        }

        groups.back().slots.push_back (slot);
    }

    syncFromProcessor();
}

FxPage::~FxPage()
{
    setLookAndFeel (nullptr);
}

void FxPage::paint (juce::Graphics& g)
{
    const int mid = getHeight() / 2;
    g.setColour (kBrown);
    g.drawRect (getLocalBounds(), 1);
    g.drawHorizontalLine (mid, 0.0f, (float) getWidth());

    const int columnCount = (int) groups.size();

    if (columnCount > 1)
    {
        const int left = 8;
        const int width = juce::jmax (1, getWidth() - 16);
        const int columnWidth = width / columnCount;
        const float lineTop = (float) mid + 22.0f;
        const float lineBottom = (float) getHeight() - 8.0f;

        g.setColour (kDivider);

        for (int columnIndex = 1; columnIndex < columnCount; ++columnIndex)
            g.drawVerticalLine (left + columnIndex * columnWidth, lineTop, lineBottom);
    }

    g.setColour (kBrown);
    g.setFont (juce::Font (juce::FontOptions (13.0f)));
    g.drawText ("input fx", 8, 4, 140, 16, juce::Justification::centredLeft);
    g.drawText ("output fx", 8, mid + 4, 140, 16, juce::Justification::centredLeft);
}

void FxPage::resized()
{
    const int mid = getHeight() / 2;
    const int left = 8;
    const int top = mid + 22;
    const int width = juce::jmax (1, getWidth() - 16);
    const int columnCount = juce::jmax (1, (int) groups.size());
    const int columnWidth = width / columnCount;

    for (int columnIndex = 0; columnIndex < columnCount; ++columnIndex)
    {
        auto& group = groups[(size_t) columnIndex];
        const int x = left + columnIndex * columnWidth + kColumnInset;
        const int controlWidth = juce::jmax (1, columnWidth - kColumnInset * 2);
        int y = top;

        if (group.titleLabel != nullptr)
        {
            group.titleLabel->setBounds (x, y, controlWidth, kTitleHeight);
            y += kTitleHeight + kGap;
        }

        for (const auto& slot : group.slots)
        {
            if (slot.component == nullptr)
                continue;

            if (slot.caption != nullptr)
                slot.caption->setBounds (x, y, controlWidth, kCaptionHeight);

            const int controlY = y + (slot.caption != nullptr ? kCaptionHeight : 0);
            const int controlHeight = slot.caption != nullptr ? slot.height - kCaptionHeight : slot.height;
            slot.component->setBounds (x, controlY, controlWidth, controlHeight);
            y += slot.height + kGap;
        }
    }
}

void FxPage::syncFromProcessor()
{
    for (const auto& group : groups)
    {
        for (const auto& slot : group.slots)
        {
            const int value = processor.getOutputFx (slot.index);

            if (slot.toggle)
            {
                if (auto* button = dynamic_cast<juce::TextButton*> (slot.component))
                    button->setToggleState (value != 0, juce::dontSendNotification);
            }
            else if (auto* slider = dynamic_cast<juce::Slider*> (slot.component))
            {
                slider->setValue (value, juce::dontSendNotification);
            }
        }
    }
}
