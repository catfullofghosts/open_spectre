#pragma once

#include <juce_audio_processors/juce_audio_processors.h>
#include "OutputFx.h"
#include "MixWipe.h"

#include <array>
#include <cstdint>

class OpenSpectreAudioProcessor : public juce::AudioProcessor,
                                  public juce::ChangeBroadcaster
{
public:
    enum class Page
    {
        classic = 0,
        modern,
        express,
        fx,
        ext,
        settings
    };

    static constexpr int kDigitalInputs = 64;
    static constexpr int kDigitalOutputs = 57;
    // Grid shows inputs through ca_out (row 57). Rows after that stay off the panel.
    static constexpr int kDigitalGridRows = 58;
    static constexpr int kAnalogInputs = 11;
    static constexpr int kAnalogOutputs = 20;
    static constexpr int kMatrixDigital = 0;
    static constexpr int kMatrixAnalog = 1;

    static constexpr int kDigitalBytes = (kDigitalInputs * kDigitalOutputs + 7) / 8;
    static constexpr int kAnalogBytes = (kAnalogInputs * kAnalogOutputs + 7) / 8;

    OpenSpectreAudioProcessor();
    ~OpenSpectreAudioProcessor() override;

    void prepareToPlay(double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;

#ifndef JucePlugin_PreferredChannelConfigurations
    bool isBusesLayoutSupported(const BusesLayout& layouts) const override;
#endif

    void processBlock(juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override;

    const juce::String getName() const override;

    bool acceptsMidi() const override;
    bool producesMidi() const override;
    bool isMidiEffect() const override;
    double getTailLengthSeconds() const override;

    int getNumPrograms() override;
    int getCurrentProgram() override;
    void setCurrentProgram(int index) override;
    const juce::String getProgramName(int index) override;
    void changeProgramName(int index, const juce::String& newName) override;

    void getStateInformation(juce::MemoryBlock& destData) override;
    void setStateInformation(const void* data, int sizeInBytes) override;

    static const char* getPageName(Page page);
    static Page pageFromName(const juce::String& name);

    Page getPage() const;
    void setPage(Page page);

    // outputIndex is the column, inputIndex is the row. Matches the tester SysEx.
    void setCrosspoint(int matrixId, int outputIndex, int inputIndex, bool on);
    std::array<uint8_t, kDigitalBytes> copyDigitalBits() const;
    std::array<uint8_t, kAnalogBytes> copyAnalogBits() const;

    int getOutputFx (int index) const;
    void setOutputFx (int index, int value);

    int getMixWipe (int index) const;
    void setMixWipe (int index, int value);

private:
    void enqueueSysEx(const juce::uint8* data, int size);
    void sendCC(int controller, int value);
    void sendOutputFxIndex(int index, int value);
    void publishOutputFx();
    void sendMixWipeIndex (int index, int value);
    void publishMixWipe();
    void sendMatrixCell(int matrixId, int outputIndex, int inputIndex, bool on);
    void sendMatrixReset(int matrixId);
    void publishMatrix(int matrixId);

    mutable juce::CriticalSection matrixLock;
    juce::CriticalSection midiLock;
    juce::MidiBuffer midiOutput;

    Page page = Page::classic;
    std::array<uint8_t, kDigitalBytes> digitalBits {};
    std::array<uint8_t, kAnalogBytes> analogBits {};
    std::array<int, kOutputFxCount> outputFxValues {};
    std::array<int, kMixWipeCount> mixWipeValues {};

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(OpenSpectreAudioProcessor)
};
