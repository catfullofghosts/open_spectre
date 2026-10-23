#include "PluginProcessor.h"
#include "PluginEditor.h"

#include <cstring>

namespace
{
bool bitIsOn(const uint8_t* data, int sizeBytes, int index)
{
    if (index < 0 || (index >> 3) >= sizeBytes)
        return false;

    return (data[index >> 3] & (uint8_t) (1u << (index & 7))) != 0;
}

void writeBit(uint8_t* data, int sizeBytes, int index, bool on)
{
    if (index < 0 || (index >> 3) >= sizeBytes)
        return;

    const auto mask = (uint8_t) (1u << (index & 7));
    if (on)
        data[index >> 3] = (uint8_t) (data[index >> 3] | mask);
    else
        data[index >> 3] = (uint8_t) (data[index >> 3] & (uint8_t) ~mask);
}
}

OpenSpectreAudioProcessor::OpenSpectreAudioProcessor()
#ifndef JucePlugin_PreferredChannelConfigurations
    : AudioProcessor(BusesProperties()
        #if ! JucePlugin_IsMidiEffect
         #if ! JucePlugin_IsSynth
          .withInput("Input", juce::AudioChannelSet::stereo(), true)
         #endif
          .withOutput("Output", juce::AudioChannelSet::stereo(), true)
        #endif
      )
#endif
{
}

OpenSpectreAudioProcessor::~OpenSpectreAudioProcessor()
{
    const juce::ScopedLock lock(midiLock);
    midiOutput.clear();
}

const juce::String OpenSpectreAudioProcessor::getName() const
{
    return JucePlugin_Name;
}

bool OpenSpectreAudioProcessor::acceptsMidi() const
{
   #if JucePlugin_WantsMidiInput
    return true;
   #else
    return false;
   #endif
}

bool OpenSpectreAudioProcessor::producesMidi() const
{
   #if JucePlugin_ProducesMidiOutput
    return true;
   #else
    return false;
   #endif
}

bool OpenSpectreAudioProcessor::isMidiEffect() const
{
   #if JucePlugin_IsMidiEffect
    return true;
   #else
    return false;
   #endif
}

double OpenSpectreAudioProcessor::getTailLengthSeconds() const
{
    return 0.0;
}

int OpenSpectreAudioProcessor::getNumPrograms()
{
    return 1;
}

int OpenSpectreAudioProcessor::getCurrentProgram()
{
    return 0;
}

void OpenSpectreAudioProcessor::setCurrentProgram(int index)
{
    juce::ignoreUnused(index);
}

const juce::String OpenSpectreAudioProcessor::getProgramName(int index)
{
    juce::ignoreUnused(index);
    return {};
}

void OpenSpectreAudioProcessor::changeProgramName(int index, const juce::String& newName)
{
    juce::ignoreUnused(index, newName);
}

void OpenSpectreAudioProcessor::prepareToPlay(double sampleRate, int samplesPerBlock)
{
    juce::ignoreUnused(sampleRate, samplesPerBlock);
}

void OpenSpectreAudioProcessor::releaseResources()
{
}

#ifndef JucePlugin_PreferredChannelConfigurations
bool OpenSpectreAudioProcessor::isBusesLayoutSupported(const BusesLayout& layouts) const
{
   #if JucePlugin_IsMidiEffect
    juce::ignoreUnused(layouts);
    return true;
   #else
    if (layouts.getMainOutputChannelSet() != juce::AudioChannelSet::mono()
        && layouts.getMainOutputChannelSet() != juce::AudioChannelSet::stereo())
        return false;

    #if ! JucePlugin_IsSynth
    if (layouts.getMainOutputChannelSet() != layouts.getMainInputChannelSet())
        return false;
    #endif

    return true;
   #endif
}
#endif

void OpenSpectreAudioProcessor::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages)
{
    juce::ScopedNoDenormals noDenormals;

    const int numSamples = buffer.getNumSamples();

    // Host MIDI passes through. UI SysEx is merged in, same pattern as the Vidirol plugins.
    juce::MidiBuffer combined;

    for (const auto metadata : midiMessages)
        combined.addEvent(metadata.data, metadata.numBytes, metadata.samplePosition);

    {
        const juce::ScopedLock lock(midiLock);

        for (const auto metadata : midiOutput)
        {
            int position = metadata.samplePosition;
            if (numSamples > 0)
                position = juce::jlimit(0, numSamples - 1, position);

            combined.addEvent(metadata.data, metadata.numBytes, position);
        }

        midiOutput.clear();
    }

    midiMessages.swapWith(combined);

    for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
        buffer.clear(channel, 0, numSamples);
}

bool OpenSpectreAudioProcessor::hasEditor() const
{
    return true;
}

juce::AudioProcessorEditor* OpenSpectreAudioProcessor::createEditor()
{
    return new OpenSpectreAudioProcessorEditor(*this);
}

void OpenSpectreAudioProcessor::getStateInformation(juce::MemoryBlock& destData)
{
    juce::MemoryBlock digitalBlock;
    juce::MemoryBlock analogBlock;
    Page savedPage = Page::classic;

    {
        const juce::ScopedLock lock(matrixLock);
        savedPage = page;
        digitalBlock.append(digitalBits.data(), digitalBits.size());
        analogBlock.append(analogBits.data(), analogBits.size());
    }

    juce::XmlElement xml("OpenSpectre");
    xml.setAttribute("page", getPageName(savedPage));
    xml.setAttribute("digital", digitalBlock.toBase64Encoding());
    xml.setAttribute("analog", analogBlock.toBase64Encoding());
    copyXmlToBinary(xml, destData);
}

void OpenSpectreAudioProcessor::setStateInformation(const void* data, int sizeInBytes)
{
    std::unique_ptr<juce::XmlElement> xml(getXmlFromBinary(data, sizeInBytes));

    if (xml == nullptr || ! xml->hasTagName("OpenSpectre"))
        return;

    const Page loadedPage = pageFromName(xml->getStringAttribute("page"));
    const bool hasPage = xml->hasAttribute("page");

    bool digitalChanged = false;
    bool analogChanged = false;

    {
        const juce::ScopedLock lock(matrixLock);

        if (hasPage)
            page = loadedPage;

        juce::MemoryBlock block;

        if (block.fromBase64Encoding(xml->getStringAttribute("digital"))
            && block.getSize() == digitalBits.size())
        {
            std::array<uint8_t, kDigitalBytes> next {};
            std::memcpy(next.data(), block.getData(), next.size());
            digitalChanged = next != digitalBits;
            digitalBits = next;
        }

        block.reset();

        if (block.fromBase64Encoding(xml->getStringAttribute("analog"))
            && block.getSize() == analogBits.size())
        {
            std::array<uint8_t, kAnalogBytes> next {};
            std::memcpy(next.data(), block.getData(), next.size());
            analogChanged = next != analogBits;
            analogBits = next;
        }
    }

    if (digitalChanged)
        publishMatrix(kMatrixDigital);

    if (analogChanged)
        publishMatrix(kMatrixAnalog);

    sendChangeMessage();
}

const char* OpenSpectreAudioProcessor::getPageName(Page pageToName)
{
    switch (pageToName)
    {
        case Page::classic:  return "classic";
        case Page::modern:   return "modern";
        case Page::express:  return "express";
        case Page::fx:       return "fx";
        case Page::ext:      return "ext";
        case Page::settings: return "settings";
    }

    return "classic";
}

OpenSpectreAudioProcessor::Page OpenSpectreAudioProcessor::pageFromName(const juce::String& name)
{
    if (name == "modern")   return Page::modern;
    if (name == "express")  return Page::express;
    if (name == "fx")       return Page::fx;
    if (name == "ext")      return Page::ext;
    if (name == "settings") return Page::settings;
    return Page::classic;
}

OpenSpectreAudioProcessor::Page OpenSpectreAudioProcessor::getPage() const
{
    const juce::ScopedLock lock(matrixLock);
    return page;
}

void OpenSpectreAudioProcessor::setPage(Page nextPage)
{
    {
        const juce::ScopedLock lock(matrixLock);
        if (page == nextPage)
            return;

        page = nextPage;
    }

    sendChangeMessage();
}

void OpenSpectreAudioProcessor::setCrosspoint(int matrixId, int outputIndex, int inputIndex, bool on)
{
    const bool digital = matrixId == kMatrixDigital;
    const int rows = digital ? kDigitalInputs : kAnalogInputs;
    const int columns = digital ? kDigitalOutputs : kAnalogOutputs;

    if (inputIndex < 0 || outputIndex < 0 || inputIndex >= rows || outputIndex >= columns)
        return;

    {
        const juce::ScopedLock lock(matrixLock);
        const int index = inputIndex * columns + outputIndex;

        if (digital)
            writeBit(digitalBits.data(), (int) digitalBits.size(), index, on);
        else
            writeBit(analogBits.data(), (int) analogBits.size(), index, on);
    }

    sendMatrixCell(matrixId, outputIndex, inputIndex, on);
}

std::array<uint8_t, OpenSpectreAudioProcessor::kDigitalBytes> OpenSpectreAudioProcessor::copyDigitalBits() const
{
    const juce::ScopedLock lock(matrixLock);
    return digitalBits;
}

std::array<uint8_t, OpenSpectreAudioProcessor::kAnalogBytes> OpenSpectreAudioProcessor::copyAnalogBits() const
{
    const juce::ScopedLock lock(matrixLock);
    return analogBits;
}

void OpenSpectreAudioProcessor::enqueueSysEx(const juce::uint8* data, int size)
{
    auto message = juce::MidiMessage::createSysExMessage(data, size);
    const juce::ScopedLock lock(midiLock);
    midiOutput.addEvent(message, 0);
}

void OpenSpectreAudioProcessor::sendMatrixCell(int matrixId, int outputIndex, int inputIndex, bool on)
{
    const juce::uint8 data[] = {
        0x7D, 0x53, 0x50, 0x20,
        (juce::uint8) matrixId,
        (juce::uint8) outputIndex,
        (juce::uint8) inputIndex,
        (juce::uint8) (on ? 1 : 0)
    };

    enqueueSysEx(data, (int) sizeof(data));
}

void OpenSpectreAudioProcessor::sendMatrixReset(int matrixId)
{
    const juce::uint8 data[] = {
        0x7D, 0x53, 0x50, 0x21,
        (juce::uint8) matrixId,
        127
    };

    enqueueSysEx(data, (int) sizeof(data));
}

void OpenSpectreAudioProcessor::publishMatrix(int matrixId)
{
    const bool digital = matrixId == kMatrixDigital;
    const int rows = digital ? kDigitalInputs : kAnalogInputs;
    const int columns = digital ? kDigitalOutputs : kAnalogOutputs;

    std::array<uint8_t, kDigitalBytes> digitalCopy {};
    std::array<uint8_t, kAnalogBytes> analogCopy {};

    {
        const juce::ScopedLock lock(matrixLock);
        digitalCopy = digitalBits;
        analogCopy = analogBits;
    }

    const uint8_t* bits = digital ? digitalCopy.data() : analogCopy.data();
    const int sizeBytes = digital ? (int) digitalCopy.size() : (int) analogCopy.size();

    sendMatrixReset(matrixId);

    for (int row = 0; row < rows; ++row)
    {
        for (int column = 0; column < columns; ++column)
        {
            if (bitIsOn(bits, sizeBytes, row * columns + column))
                sendMatrixCell(matrixId, column, row, true);
        }
    }
}

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new OpenSpectreAudioProcessor();
}
