#include "PluginProcessor.h"
#include "PluginEditor.h"
#include "OutputFx.h"

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
    for (int index = 0; index < kOutputFxCount; ++index)
        outputFxValues[(size_t) index] = kOutputFx[index].defaultValue;

    for (int index = 0; index < kMixWipeCount; ++index)
        mixWipeValues[(size_t) index] = kMixWipe[index].defaultValue;
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

    juce::String fxValues;
    juce::String mixValues;

    {
        const juce::ScopedLock lock(matrixLock);
        savedPage = page;
        digitalBlock.append(digitalBits.data(), digitalBits.size());
        analogBlock.append(analogBits.data(), analogBits.size());

        for (int index = 0; index < kOutputFxCount; ++index)
        {
            if (index > 0)
                fxValues << ",";
            fxValues << outputFxValues[(size_t) index];
        }

        for (int index = 0; index < kMixWipeCount; ++index)
        {
            if (index > 0)
                mixValues << ",";
            mixValues << mixWipeValues[(size_t) index];
        }
    }

    juce::XmlElement xml("OpenSpectre");
    xml.setAttribute("page", getPageName(savedPage));
    xml.setAttribute("digital", digitalBlock.toBase64Encoding());
    xml.setAttribute("analog", analogBlock.toBase64Encoding());
    xml.setAttribute("outputFx", fxValues);
    xml.setAttribute("mixWipe", mixValues);
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
    bool outputFxChanged = false;
    bool mixWipeChanged = false;

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

        const auto fxParts = juce::StringArray::fromTokens(xml->getStringAttribute("outputFx"), ",", "");

        if (fxParts.size() == kOutputFxCount)
        {
            for (int index = 0; index < kOutputFxCount; ++index)
            {
                const int loaded = fxClamp(fxParts[index].getIntValue(),
                                           kOutputFx[index].minimum,
                                           kOutputFx[index].maximum);

                if (outputFxValues[(size_t) index] != loaded)
                {
                    outputFxValues[(size_t) index] = loaded;
                    outputFxChanged = true;
                }
            }
        }

        const auto mixParts = juce::StringArray::fromTokens(xml->getStringAttribute("mixWipe"), ",", "");

        if (mixParts.size() == kMixWipeCount)
        {
            for (int index = 0; index < kMixWipeCount; ++index)
            {
                const int loaded = fxClamp(mixParts[index].getIntValue(),
                                           kMixWipe[index].minimum,
                                           kMixWipe[index].maximum);

                if (mixWipeValues[(size_t) index] != loaded)
                {
                    mixWipeValues[(size_t) index] = loaded;
                    mixWipeChanged = true;
                }
            }
        }
    }

    if (digitalChanged)
        publishMatrix(kMatrixDigital);

    if (analogChanged)
        publishMatrix(kMatrixAnalog);

    if (outputFxChanged)
        publishOutputFx();

    if (mixWipeChanged)
        publishMixWipe();

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

void OpenSpectreAudioProcessor::sendCC(int controller, int value)
{
    const auto message = juce::MidiMessage::controllerEvent(1, controller, fxClamp(value, 0, 127));
    const juce::ScopedLock lock(midiLock);
    midiOutput.addEvent(message, 0);
}

void OpenSpectreAudioProcessor::sendOutputFxIndex(int index, int value)
{
    if (index < 0 || index >= kOutputFxCount)
        return;

    dispatchOutputFx(kOutputFx[index], value, [this](int controller, int controllerValue)
    {
        sendCC(controller, controllerValue);
    });
}

void OpenSpectreAudioProcessor::publishOutputFx()
{
    std::array<int, kOutputFxCount> values {};

    {
        const juce::ScopedLock lock(matrixLock);
        values = outputFxValues;
    }

    for (int index = 0; index < kOutputFxCount; ++index)
        sendOutputFxIndex(index, values[(size_t) index]);
}

int OpenSpectreAudioProcessor::getOutputFx(int index) const
{
    if (index < 0 || index >= kOutputFxCount)
        return 0;

    const juce::ScopedLock lock(matrixLock);
    return outputFxValues[(size_t) index];
}

void OpenSpectreAudioProcessor::setOutputFx(int index, int value)
{
    if (index < 0 || index >= kOutputFxCount)
        return;

    value = fxClamp(value, kOutputFx[index].minimum, kOutputFx[index].maximum);

    {
        const juce::ScopedLock lock(matrixLock);

        if (outputFxValues[(size_t) index] == value)
            return;

        outputFxValues[(size_t) index] = value;
    }

    sendOutputFxIndex(index, value);
}

void OpenSpectreAudioProcessor::sendMixWipeIndex(int index, int value)
{
    if (index < 0 || index >= kMixWipeCount)
        return;

    const auto& spec = kMixWipe[index];

    if (spec.encode == MixEncode::direction || spec.encode == MixEncode::band)
    {
        int direction = 0;
        int band = 0;

        {
            const juce::ScopedLock lock(matrixLock);

            for (int control = 0; control < kMixWipeCount; ++control)
            {
                if (kMixWipe[control].encode == MixEncode::direction)
                    direction = mixWipeValues[(size_t) control];
                else if (kMixWipe[control].encode == MixEncode::band)
                    band = mixWipeValues[(size_t) control];
            }
        }

        sendCC(spec.cc, fxEnumToCc(mixWipeOriginCode(direction, band), spec.encodeParam));
        return;
    }

    dispatchMixWipe(spec, value, [this](int controller, int controllerValue)
    {
        sendCC(controller, controllerValue);
    });
}

void OpenSpectreAudioProcessor::publishMixWipe()
{
    std::array<int, kMixWipeCount> values {};
    bool sentOrigin = false;

    {
        const juce::ScopedLock lock(matrixLock);
        values = mixWipeValues;
    }

    for (int index = 0; index < kMixWipeCount; ++index)
    {
        const auto encode = kMixWipe[index].encode;

        if (encode == MixEncode::direction || encode == MixEncode::band)
        {
            if (! sentOrigin)
            {
                sendMixWipeIndex(index, values[(size_t) index]);
                sentOrigin = true;
            }

            continue;
        }

        sendMixWipeIndex(index, values[(size_t) index]);
    }
}

int OpenSpectreAudioProcessor::getMixWipe(int index) const
{
    if (index < 0 || index >= kMixWipeCount)
        return 0;

    const juce::ScopedLock lock(matrixLock);
    return mixWipeValues[(size_t) index];
}

void OpenSpectreAudioProcessor::setMixWipe(int index, int value)
{
    if (index < 0 || index >= kMixWipeCount)
        return;

    value = fxClamp(value, kMixWipe[index].minimum, kMixWipe[index].maximum);

    {
        const juce::ScopedLock lock(matrixLock);

        if (mixWipeValues[(size_t) index] == value)
            return;

        mixWipeValues[(size_t) index] = value;
    }

    sendMixWipeIndex(index, value);
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
