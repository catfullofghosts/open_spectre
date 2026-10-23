cmake_minimum_required(VERSION 3.22)

# Open Spectre MIDI-out plugin (VST3, VST2 when the SDK is present, and Standalone).
#
#   cmake -S design/vst -B design/vst/build -G "Visual Studio 17 2022" -A x64
#   cmake --build design/vst/build --config Release
#
# JUCE is not vendored. Point JUCE_DIR at a JUCE 9 tree if the default is missing.

project(OpenSpectreVST VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(JUCE_DIR "C:/Users/robertjo/Downloads/vidirol_unifie/JUCE" CACHE PATH "Path to the JUCE source tree")

if(NOT EXISTS "${JUCE_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "JUCE not found at ${JUCE_DIR}. Reconfigure with -DJUCE_DIR=/path/to/JUCE")
endif()

add_subdirectory(${JUCE_DIR} JUCE)

set(VST2_SDK_PATH "C:/Users/robertjo/Downloads/vidirol_unifie/VST_SDK/VST2_SDK" CACHE PATH "VST2 SDK root (optional)")
set(OPEN_SPECTRE_FORMATS VST3 Standalone)

if(EXISTS "${VST2_SDK_PATH}/pluginterfaces/vst2.x/aeffect.h")
    juce_set_vst2_sdk_path("${VST2_SDK_PATH}")
    list(APPEND OPEN_SPECTRE_FORMATS VST)
    message(STATUS "VST2 SDK: ${VST2_SDK_PATH}")
else()
    message(STATUS "VST2 SDK not found; building VST3 and Standalone only")
endif()

juce_add_binary_data(OpenSpectreAssets
    SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/../VST_interface_GUI/blank_VST_BG.png
        ${CMAKE_CURRENT_SOURCE_DIR}/../VST_interface_GUI/blank_VST_matrix.png
)

juce_add_plugin(OpenSpectre
    COMPANY_NAME "Open Spectre"
    BUNDLE_ID "com.openspectre.controller"
    IS_SYNTH FALSE
    NEEDS_MIDI_INPUT TRUE
    NEEDS_MIDI_OUTPUT TRUE
    IS_MIDI_EFFECT FALSE
    EDITOR_WANTS_KEYBOARD_FOCUS FALSE
    COPY_PLUGIN_AFTER_BUILD FALSE
    PLUGIN_MANUFACTURER_CODE OpSp
    PLUGIN_CODE OSp1
    FORMATS ${OPEN_SPECTRE_FORMATS}
    PRODUCT_NAME "Open Spectre"
    VST3_CATEGORY Fx
)

target_sources(OpenSpectre
    PRIVATE
        Source/PluginProcessor.cpp
        Source/PluginProcessor.h
        Source/PluginEditor.cpp
        Source/PluginEditor.h
        Source/MatrixGrid.cpp
        Source/MatrixGrid.h
        Source/MatrixNames.h
)

target_link_libraries(OpenSpectre
    PRIVATE
        OpenSpectreAssets
        juce::juce_audio_utils
        juce::juce_audio_devices
        juce::juce_audio_processors
        juce::juce_core
        juce::juce_data_structures
        juce::juce_events
        juce::juce_graphics
        juce::juce_gui_basics
    PUBLIC
        juce::juce_recommended_config_flags
        juce::juce_recommended_lto_flags
        juce::juce_recommended_warning_flags
)

target_compile_definitions(OpenSpectre
    PUBLIC
        JUCE_WEB_BROWSER=0
        JUCE_USE_CURL=0
        JUCE_VST3_CAN_REPLACE_VST2=0
)
