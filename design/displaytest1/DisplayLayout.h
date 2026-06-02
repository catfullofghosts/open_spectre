#ifndef DisplayLayout_h
#define DisplayLayout_h

#include "ER_TFTM070_7.h"
#include "Arduino.h"

// Grid configuration
#define GRID_BORDER 2
#define GRID_X_DIV 15
#define GRID_Y_DIV 8

// Calculate grid dimensions
#define GRID_START_X GRID_BORDER
#define GRID_START_Y GRID_BORDER
#define GRID_END_X ((LCD_XSIZE_TFT) - (GRID_BORDER) - 1)
#define GRID_END_Y ((LCD_YSIZE_TFT) - (GRID_BORDER) - 1)
#define GRID_WIDTH ((GRID_END_X) - (GRID_START_X) + 1)
#define GRID_HEIGHT ((GRID_END_Y) - (GRID_START_Y) + 1)
#define GRID_X_STEP ((GRID_WIDTH) / (GRID_X_DIV))
#define GRID_Y_STEP ((GRID_HEIGHT) / (GRID_Y_DIV))

// Section heights (in grid rows)
#define TOP_SECTION_ROWS 2
#define BOTTOM_SECTION_ROWS 1
#define MIDDLE_SECTION_ROWS (GRID_Y_DIV - TOP_SECTION_ROWS - BOTTOM_SECTION_ROWS)

// Section Y positions
#define TOP_SECTION_Y (GRID_START_Y)
#define TOP_SECTION_HEIGHT ((TOP_SECTION_ROWS) * (GRID_Y_STEP))
#define MIDDLE_SECTION_Y ((TOP_SECTION_Y) + (TOP_SECTION_HEIGHT))
#define MIDDLE_SECTION_HEIGHT ((MIDDLE_SECTION_ROWS) * (GRID_Y_STEP))
#define BOTTOM_SECTION_Y ((MIDDLE_SECTION_Y) + (MIDDLE_SECTION_HEIGHT))
#define BOTTOM_SECTION_HEIGHT ((BOTTOM_SECTION_ROWS) * (GRID_Y_STEP))

// Top section divided into 3 parts in Y direction
#define TOP_SECTION_PART_HEIGHT ((TOP_SECTION_HEIGHT) / 3)

// Button grid configuration (left element in top section)
#define BUTTON_GRID_WIDTH 4
#define BUTTON_GRID_HEIGHT 2
// Buttons centered between left edge and tabs (tabs start at LCD_XSIZE_TFT / 2)
#define BUTTON_AREA_START_X 0  // Left edge of screen
#define BUTTON_AREA_END_X (LCD_XSIZE_TFT / 2)  // Tabs start here
#define BUTTON_AREA_WIDTH ((BUTTON_AREA_END_X) - (BUTTON_AREA_START_X))  // Space for buttons
#define BUTTON_VERTICAL_SPACING 0  // Vertical spacing between buttons and edges (very tightly packed)
#define BUTTON_HORIZONTAL_SPACING 0  // Horizontal spacing between buttons (very tightly packed)
#define BUTTON_TOP_PADDING 6  // push the 8 buttons down so they don't touch top of screen
#define BUTTON_BOX_HEIGHT ((BUTTON_CORNER_RADIUS * 2) + 1)  // Height matches pill shape (circle diameter + 1)
#define BUTTON_GRID_START_Y (TOP_SECTION_Y + BUTTON_TOP_PADDING + BUTTON_VERTICAL_SPACING)  // Start with padding from top
#define BUTTON_BOX_WIDTH (((BUTTON_AREA_WIDTH - (BUTTON_HORIZONTAL_SPACING * ((BUTTON_GRID_WIDTH) + 1))) / (BUTTON_GRID_WIDTH)) + 5 + 4 + 10 - 10)  // Width reduced by 10px (split difference) to make buttons shorter in x direction
#define BUTTON_GRID_START_X (BUTTON_AREA_START_X + BUTTON_HORIZONTAL_SPACING)  // Start with spacing from left edge
#define BUTTON_CORNER_RADIUS 18  // Radius for rounded corners (increased a little more)
#define BUTTON_BACKGROUND_RECT_HEIGHT 20  // Height of rounded rectangle under all buttons
#define BUTTON_BACKGROUND_RECT_Y (TOP_SECTION_Y + TOP_SECTION_HEIGHT - BUTTON_BACKGROUND_RECT_HEIGHT - BUTTON_VERTICAL_SPACING)  // Position at bottom of top section

// Circle configuration (right element in top section)
#define CIRCLE_COUNT 4
#define CIRCLE_ROW_Y ((TOP_SECTION_Y + TOP_SECTION_PART_HEIGHT) - 10)  // Second row down, moved up 10 pixels
#define CIRCLE_AREA_START_X (LCD_XSIZE_TFT / 2)  // Start from middle of screen (right half)
#define CIRCLE_AREA_WIDTH (LCD_XSIZE_TFT / 2)  // Right half of screen for circles
#define CIRCLE_SPACING ((CIRCLE_AREA_WIDTH / (CIRCLE_COUNT + 1)) + 5)  // Space between circles (5 pixels more)
#define CIRCLE_RADIUS ((GRID_X_STEP * 3) / 4)  // Circle radius (split difference: was GRID_X_STEP/2, now 3/4)
#define CIRCLE_TAB_WIDTH (((CIRCLE_RADIUS) * 2) + 1)  // Width of the tab rectangle (1 pixel wider than circle diameter)

// Page system
enum PageType {
  PAGE_GLOBAL = 0,
  PAGE_EXT,
  PAGE_MIDI,
  PAGE_SETTINGS,
  PAGE_DIGITAL,
  PAGE_ANALOG,
  PAGE_SHAPES,
  PAGE_OSCILLATOR,  // Oscillator page with 3 columns
  PAGE_CENTRAL,  // Central page with buttons for all pages
  PAGE_COUNT
};

// Button state for each page
struct ButtonConfig {
  const char* text;
  uint16_t color;
  bool visible;
  bool enabled;  // If false, button is greyed out
};

class DisplayLayout {
public:
  DisplayLayout();
  
  // Initialize the display layout
  void init();
  
  // Draw the layout structure (sections, borders, etc.)
  void drawLayout();
  
  // Draw button grid (4x2 grid of boxes with text)
  void drawButtonGrid(const char* buttonTexts[BUTTON_GRID_HEIGHT][BUTTON_GRID_WIDTH]);
  
  // Draw button grid with custom colors
  void drawButtonGridWithColors(const char* buttonTexts[BUTTON_GRID_HEIGHT][BUTTON_GRID_WIDTH], 
                                 uint16_t colors[BUTTON_GRID_HEIGHT][BUTTON_GRID_WIDTH]);
  
  // Draw a single button in the grid
  void drawButton(uint8_t row, uint8_t col, const char* text, uint16_t bgColor, uint16_t textColor);
  
  // Draw rounded rectangle background under all buttons
  void drawButtonBackground(uint16_t color);
  
  // Button activation (touched buttons can be active/inactive)
  void setButtonActive(uint8_t row, uint8_t col, bool active);
  bool isButtonActive(uint8_t row, uint8_t col);
  
  // Check if touch point is on a button and return button coordinates (row, col), returns true if found
  bool getTouchedButton(uint16_t x, uint16_t y, uint8_t* outRow, uint8_t* outCol);
  
  // Draw rounded rectangle (helper function)
  void drawRoundedRect(uint16_t x, uint16_t y, uint16_t width, uint16_t height, uint16_t radius, uint16_t color);
  
  // Draw circles on the second row (4 circles horizontally)
  void drawCircles(uint16_t colors[CIRCLE_COUNT]);
  
  // Draw a single circle
  void drawCircle(uint8_t index, uint16_t color);
  
  // Draw center dot (smaller black circle in center)
  void drawCircleCenter(uint8_t index);

  // Tab label/value drawing
  void setTabLabel(uint8_t index, const char* label);
  void setTabValue(uint8_t index, int value);
  void drawTabLabel(uint8_t index);
  void drawTabValue(uint8_t index);
  
  // Draw tab (rectangle from top to circle center)
  void drawCircleTab(uint8_t index, uint16_t color);
  
  // Draw top bar spanning all tabs
  void drawTopBar(uint16_t color);
  
  // Tab activation (only one can be active at a time)
  void setActiveTab(uint8_t index);  // Set active tab (0-3), 255 to deactivate
  uint8_t getActiveTab() { return activeTabIndex; }
  
  // Check if touch point is on a tab and return tab index (0-3), 255 if none
  uint8_t getTouchedTab(uint16_t x, uint16_t y);
  
  // Clear a section
  void clearTopSection();
  void clearMiddleSection();
  void clearBottomSection();
  
  // Clear only the tab area (for redrawing tabs without affecting buttons)
  void clearTabArea();
  
  // Clear a single button area
  void clearButtonArea(uint8_t row, uint8_t col);
  
  // Clear a single tab area (tab rectangle and circle)
  void clearSingleTabArea(uint8_t index);

  // Bottom section UI
  void drawBottomSectionUI();
  
  // Draw the page box in the middle section
  void drawPage();
  
  // Draw test page grid
  void drawTestPage();
  
  // Orange button extended state
  void setOrangeButtonExtended(bool extended);
  bool isOrangeButtonExtended() { return orangeButtonExtended; }
  bool isTouchedOrangeButton(uint16_t x, uint16_t y);  // Check if touch is on orange button
  int8_t getTouchedExtendedCircle(uint16_t x, uint16_t y);  // Returns 0-2 for ext/mid/set, -1 if none
  bool isTouchedPgeButton(uint16_t x, uint16_t y);  // Check if touch is on "pge" button in extended orange button
  int8_t getTouchedCentralPageButton(uint16_t x, uint16_t y);  // Returns page index (0-6) if touched, -1 if none
  uint16_t getExtendedButtonWidth();  // Get the width of the button when extended
  uint16_t getNormalButtonWidth();  // Get the width of the button when not extended
  
  // Page management
  void setCurrentPage(PageType page);
  PageType getCurrentPage() { return currentPage; }
  const char* getCurrentPageName();  // Get current page name for display
  void drawPageContent();  // Draw the middle section content for current page
  
  // Draw a page block with consistent borders
  void drawPageBlock(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1, const char* label, uint16_t bgColor);
  
  // Get section dimensions
  uint16_t getTopSectionHeight() { return TOP_SECTION_HEIGHT; }
  uint16_t getMiddleSectionHeight() { return MIDDLE_SECTION_HEIGHT; }
  uint16_t getBottomSectionHeight() { return BOTTOM_SECTION_HEIGHT; }
  
  uint16_t getTopSectionY() { return TOP_SECTION_Y; }
  uint16_t getMiddleSectionY() { return MIDDLE_SECTION_Y; }
  uint16_t getBottomSectionY() { return BOTTOM_SECTION_Y; }

private:
  uint8_t activeTabIndex;  // Currently active tab (0-3), 255 if none active
  bool buttonActiveState[BUTTON_GRID_HEIGHT][BUTTON_GRID_WIDTH];  // Active state for each button
  bool orangeButtonExtended;  // Whether the orange button is extended
  bool previousOrangeButtonExtended;  // Previous extended state to track changes
  const char* tabLabels[CIRCLE_COUNT];
  int tabValues[CIRCLE_COUNT];
  PageType currentPage;  // Current page being displayed
  
  // Helper functions
  void setupTextMode(uint16_t fgColor, uint16_t bgColor);
  void setupGraphicMode();
  uint16_t calculateButtonX(uint8_t col);
  uint16_t calculateButtonY(uint8_t row);
  uint16_t calculateCircleX(uint8_t index);
};

#endif

