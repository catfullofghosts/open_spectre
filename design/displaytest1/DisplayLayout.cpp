#include "DisplayLayout.h"

DisplayLayout::DisplayLayout() {
  // Constructor - initialize active tab to none
  activeTabIndex = 255;  // 255 means no tab is active
  
  // Initialize all buttons to inactive
  for (uint8_t row = 0; row < BUTTON_GRID_HEIGHT; row++) {
    for (uint8_t col = 0; col < BUTTON_GRID_WIDTH; col++) {
      buttonActiveState[row][col] = false;
    }
  }
  
  // Initialize orange button to not extended
  orangeButtonExtended = false;
  previousOrangeButtonExtended = false;

  // Initialize to global page
  currentPage = PAGE_GLOBAL;

  // Default tab labels/values
  tabLabels[0] = "TAB1";
  tabLabels[1] = "TAB2";
  tabLabels[2] = "TAB3";
  tabLabels[3] = "TAB4";
  tabValues[0] = 1;
  tabValues[1] = 2;
  tabValues[2] = 3;
  tabValues[3] = 4;
}

void DisplayLayout::setOrangeButtonExtended(bool extended) {
  previousOrangeButtonExtended = orangeButtonExtended;
  orangeButtonExtended = extended;
}

uint16_t DisplayLayout::getNormalButtonWidth() {
  const uint16_t orangeBtnX0 = calculateButtonX(0) + 5;
  uint16_t orangeBtnX1 = (LCD_XSIZE_TFT / 3) - 1;
  orangeBtnX1 = (orangeBtnX1 + 20 > LCD_XSIZE_TFT - 1) ? (LCD_XSIZE_TFT - 1) : (orangeBtnX1 + 20);
  return orangeBtnX1;
}

uint16_t DisplayLayout::getExtendedButtonWidth() {
  const uint16_t screenMidX = LCD_XSIZE_TFT / 2;
  const uint16_t circleR = 15;
  const uint16_t circleSpacing = 50;  // Fixed spacing (must match drawBottomSectionUI)
  const uint16_t firstCircleX = screenMidX + 20;
  const uint16_t lastCircleX = firstCircleX + (2 * circleSpacing);  // Third circle (index 2)
  const uint16_t lastCircleRight = lastCircleX + circleR;
  const uint16_t buttonPadding = 10;
  // Extended button width to contain all circles with padding
  uint16_t extendedX1 = (lastCircleRight + buttonPadding > LCD_XSIZE_TFT - 1) ? (LCD_XSIZE_TFT - 1) : (lastCircleRight + buttonPadding);
  return extendedX1;
}

bool DisplayLayout::isTouchedOrangeButton(uint16_t x, uint16_t y) {
  // Calculate orange button position - ALWAYS use contracted size for clickable area
  // The button visual expands, but the clickable area stays the same
  const uint16_t sectionY0 = BOTTOM_SECTION_Y;
  const uint16_t sectionH = BOTTOM_SECTION_HEIGHT;
  const uint16_t orangeBtnX0 = calculateButtonX(0) + 5;
  uint16_t orangeBtnX1 = (LCD_XSIZE_TFT / 3) - 1;
  orangeBtnX1 = (orangeBtnX1 + 20 > LCD_XSIZE_TFT - 1) ? (LCD_XSIZE_TFT - 1) : (orangeBtnX1 + 20);
  // Always use contracted size, even when extended
  // This ensures the clickable area doesn't change when button expands
  
  const uint16_t orangeBtnH = (sectionH > 10) ? (sectionH - 10) : sectionH;
  const uint16_t orangeBtnY0 = sectionY0 + ((sectionH - orangeBtnH) / 2);
  const uint16_t orangeBtnY1 = orangeBtnY0 + orangeBtnH - 1;
  
  // Check if touch is within button bounds (pill shape) - only contracted area
  if (x >= orangeBtnX0 && x <= orangeBtnX1 && y >= orangeBtnY0 && y <= orangeBtnY1) {
    return true;
  }
  
  return false;
}

int8_t DisplayLayout::getTouchedExtendedCircle(uint16_t x, uint16_t y) {
  if (!orangeButtonExtended) {
    return -1;
  }
  
  // Calculate positions of the 4 circles (pge, ext, mid, set) - must match drawBottomSectionUI
  const uint16_t sectionY0 = BOTTOM_SECTION_Y;
  const uint16_t sectionH = BOTTOM_SECTION_HEIGHT;
  const uint16_t centerY = sectionY0 + (sectionH / 2);
  const uint16_t circleR = 15;  // Radius of the circles
  const uint16_t screenMidX = LCD_XSIZE_TFT / 2;
  const uint16_t circleSpacing = 50;  // Fixed spacing between circle centers (must match drawBottomSectionUI)
  const uint16_t firstCircleX = screenMidX + 20;  // Start past middle (this is "ext")
  const uint16_t pgeCircleX = firstCircleX - circleSpacing;  // "pge" circle just before "ext"
  const uint16_t circleY = centerY;
  
  // Check "pge" circle first
  {
    int16_t dx = x - pgeCircleX;
    int16_t dy = y - circleY;
    uint16_t distSq = (dx * dx) + (dy * dy);
    if (distSq <= (circleR * circleR)) {
      return -2;  // Special value for "pge" button
    }
  }
  
  // Check each circle (ext, mid, set)
  for (uint8_t i = 0; i < 3; i++) {
    uint16_t circleX = firstCircleX + (i * circleSpacing);
    int16_t dx = x - circleX;
    int16_t dy = y - circleY;
    uint16_t distSq = (dx * dx) + (dy * dy);
    if (distSq <= (circleR * circleR)) {
      return i;  // 0=ext, 1=mid, 2=set
    }
  }
  
  return -1;
}

bool DisplayLayout::isTouchedPgeButton(uint16_t x, uint16_t y) {
  if (!orangeButtonExtended) {
    return false;
  }
  
  // Calculate "pge" circle position - must match drawBottomSectionUI
  const uint16_t sectionY0 = BOTTOM_SECTION_Y;
  const uint16_t sectionH = BOTTOM_SECTION_HEIGHT;
  const uint16_t centerY = sectionY0 + (sectionH / 2);
  const uint16_t circleR = 15;  // Radius of the circles
  const uint16_t screenMidX = LCD_XSIZE_TFT / 2;
  const uint16_t circleSpacing = 50;  // Fixed spacing between circle centers
  const uint16_t firstCircleX = screenMidX + 20;  // Start past middle (this is "ext")
  const uint16_t pgeCircleX = firstCircleX - circleSpacing;  // "pge" circle just before "ext"
  
  // Check if touch is within circle bounds
  int16_t dx = x - pgeCircleX;
  int16_t dy = y - centerY;
  uint16_t distSq = (dx * dx) + (dy * dy);
  if (distSq <= (circleR * circleR)) {
    return true;
  }
  
  return false;
}

int8_t DisplayLayout::getTouchedCentralPageButton(uint16_t x, uint16_t y) {
  if (currentPage != PAGE_CENTRAL) {
    return -1;
  }
  
  // Get page dimensions
  const uint16_t pageGapHorizontal = 5;
  const uint16_t pageGapBottom = 50;
  const uint16_t pageX0 = pageGapHorizontal;
  const uint16_t pageX1 = LCD_XSIZE_TFT - 1 - pageGapHorizontal;
  const uint16_t pageY0 = MIDDLE_SECTION_Y;
  const uint16_t pageY1 = BOTTOM_SECTION_Y - 1 - pageGapBottom;
  
  // Check if touch is within page area
  if (x < pageX0 || x > pageX1 || y < pageY0 || y > pageY1) {
    return -1;
  }
  
  // Calculate button grid (3 columns, 3 rows for 7 pages + 1 back button = 8 buttons)
  // We'll arrange them as 3x3 grid (9 slots, but only use 8)
  const uint8_t gridCols = 3;
  const uint8_t gridRows = 3;
  const uint16_t pageWidth = pageX1 - pageX0 + 1;
  const uint16_t pageHeight = pageY1 - pageY0 + 1;
  const uint16_t buttonWidth = (pageWidth - 20) / gridCols;  // 20px total spacing
  const uint16_t buttonHeight = (pageHeight - 20) / gridRows;  // 20px total spacing
  const uint16_t buttonSpacingX = 10;
  const uint16_t buttonSpacingY = 10;
  
  // Calculate which button was touched
  uint16_t relX = x - pageX0 - 5;  // Account for 5px margin
  uint16_t relY = y - pageY0 - 5;  // Account for 5px margin
  
  uint8_t col = relX / (buttonWidth + buttonSpacingX);
  uint8_t row = relY / (buttonHeight + buttonSpacingY);
  
  if (col >= gridCols || row >= gridRows) {
    return -1;
  }
  
  // Map grid position to page index
  // Pages: global(0), ext(1), midi(2), settings(3), digital(4), analog(5), shapes(6)
  // Last button (row 2, col 2) is "back" which returns -2
  uint8_t buttonIndex = row * gridCols + col;
  
  if (buttonIndex >= PAGE_COUNT - 1) {  // -1 because PAGE_CENTRAL is not included
    return -2;  // Back button
  }
  
  return buttonIndex;
}

void DisplayLayout::init() {
  // Initialize display if needed
  setupGraphicMode();
}

void DisplayLayout::drawLayout() {
  setupGraphicMode();
  
  // No horizontal lines drawn - layout structure only (sections exist but no visual lines)
}

void DisplayLayout::drawButtonGrid(const char* buttonTexts[BUTTON_GRID_HEIGHT][BUTTON_GRID_WIDTH]) {
  // Draw all buttons in the grid
  for (uint8_t row = 0; row < BUTTON_GRID_HEIGHT; row++) {
    for (uint8_t col = 0; col < BUTTON_GRID_WIDTH; col++) {
      if (buttonTexts[row][col] != nullptr) {
        // Default colors - can be customized
        drawButton(row, col, buttonTexts[row][col], 0x8410, 0xFFFF);  // Grey background, white text
      }
    }
  }
}

void DisplayLayout::drawButtonGridWithColors(const char* buttonTexts[BUTTON_GRID_HEIGHT][BUTTON_GRID_WIDTH], 
                                              uint16_t colors[BUTTON_GRID_HEIGHT][BUTTON_GRID_WIDTH]) {
  // Draw all buttons in the grid with active/inactive colors (no background boxes)
  for (uint8_t row = 0; row < BUTTON_GRID_HEIGHT; row++) {
    for (uint8_t col = 0; col < BUTTON_GRID_WIDTH; col++) {
      if (buttonTexts[row][col] != nullptr) {
        // Determine colors based on active state
        uint16_t bgColor, textColor;
        if (buttonActiveState[row][col]) {
          bgColor = Orange_Coral;  // Active: orange background
          textColor = White;  // Active: white text
        } else {
          bgColor = colors[row][col];  // Inactive: use color from array (darker colors)
          textColor = White;  // Inactive: white text for dark backgrounds
        }
        drawButton(row, col, buttonTexts[row][col], bgColor, textColor);
      }
    }
  }
}

void DisplayLayout::drawRoundedRect(uint16_t x, uint16_t y, uint16_t width, uint16_t height, uint16_t radius, uint16_t color) {
  uint16_t rightX = x + width - 1;
  uint16_t bottomY = y + height - 1;
  uint16_t circleRadius = radius - 1;  // Make circles 1 pixel smaller so they don't stick out
  
  setupGraphicMode();
  ER5517.Foreground_color_65k(color);
  
  // Draw the main rectangle body first (full rectangle)
  ER5517.Line_Start_XY(x, y);
  ER5517.Line_End_XY(rightX, bottomY);
  ER5517.Start_Square_Fill();
  
  // Draw corner cutouts in light grey (0xC618) to create rounded corners, then redraw corners in color
  ER5517.Foreground_color_65k(0xC618);  // Light grey for cutouts
  ER5517.DrawCircle_Fill(x, y, radius, 0xC618);  // Top-left corner cutout
  ER5517.DrawCircle_Fill(rightX, y, radius, 0xC618);  // Top-right corner cutout
  ER5517.DrawCircle_Fill(x, bottomY, radius, 0xC618);  // Bottom-left corner cutout
  ER5517.DrawCircle_Fill(rightX, bottomY, radius, 0xC618);  // Bottom-right corner cutout
  
  // Redraw the rounded corners in the correct color
  ER5517.Foreground_color_65k(color);
  ER5517.DrawCircle_Fill(x + radius, y + radius, circleRadius, color);  // Top-left
  ER5517.DrawCircle_Fill(rightX - radius, y + radius, circleRadius, color);  // Top-right
  ER5517.DrawCircle_Fill(x + radius, bottomY - radius, circleRadius, color);  // Bottom-left
  ER5517.DrawCircle_Fill(rightX - radius, bottomY - radius, circleRadius, color);  // Bottom-right
}

void DisplayLayout::drawButton(uint8_t row, uint8_t col, const char* text, uint16_t bgColor, uint16_t textColor) {
  if (row >= BUTTON_GRID_HEIGHT || col >= BUTTON_GRID_WIDTH) return;
  
  uint16_t x = calculateButtonX(col);
  uint16_t y = calculateButtonY(row);
  
  setupGraphicMode();
  
  // Draw pill shape: 2 circles connected by a rectangle
  uint16_t radius = BUTTON_CORNER_RADIUS;
  uint16_t centerY = y + (BUTTON_BOX_HEIGHT / 2);
  // Move circles closer together by adding offset from edges
  uint16_t circleOffset = radius + 5;  // Offset from button edges, bringing circles closer
  uint16_t leftCircleX = x + circleOffset;
  uint16_t rightCircleX = x + BUTTON_BOX_WIDTH - circleOffset - 1;
  
  // Draw connecting rectangle from center of left circle to center of right circle
  uint16_t rectX = leftCircleX;  // Start at left circle center
  uint16_t rectY = centerY - radius;
  uint16_t rectWidth = rightCircleX - leftCircleX;  // End at right circle center
  uint16_t rectHeight = (radius * 2) + 1;  // Add 1 pixel to match circle diameter exactly
  
  ER5517.Foreground_color_65k(bgColor);
  if (rectWidth > 0) {
    ER5517.Line_Start_XY(rectX, rectY);
    ER5517.Line_End_XY(rectX + rectWidth - 1, rectY + rectHeight - 1);
    ER5517.Start_Square_Fill();
  }
  
  // Draw left circle
  ER5517.DrawCircle_Fill(leftCircleX, centerY, radius, bgColor);
  
  // Draw right circle
  ER5517.DrawCircle_Fill(rightCircleX, centerY, radius, bgColor);
  
  // Draw button text (centered)
  if (text != nullptr && strlen(text) > 0) {
    setupTextMode(textColor, bgColor);
    // Center text in button (back to X1 font)
    uint16_t textX = x + (BUTTON_BOX_WIDTH / 2) - (strlen(text) * 4);  // X1 font is 4 pixels per char
    uint16_t textY = y + (BUTTON_BOX_HEIGHT / 2) - 8;  // X1 font is 8 pixels tall
    if (textX < x) textX = x + 2;  // Ensure text doesn't go outside button
    
    ER5517.Goto_Text_XY(textX, textY);
    ER5517.LCD_CmdWrite(0x04);
    const char *str = text;
    while(*str != '\0') {
      ER5517.LCD_DataWrite(*str);
      ER5517.Check_Mem_WR_FIFO_not_Full();
      ++str;
    }
    ER5517.Check_2D_Busy();
  }
  
  setupGraphicMode();
}

void DisplayLayout::drawCircles(uint16_t colors[CIRCLE_COUNT]) {
  // Draw top bar first (spans all tabs) - drawn first so tabs draw over it
  drawTopBar(Green_Olive_Dark);
  
  // Draw all tabs with color based on active state (drawn over top bar)
  for (uint8_t i = 0; i < CIRCLE_COUNT; i++) {
    uint16_t tabColor = (activeTabIndex == i) ? Pink_Pastel : Green_Olive_Dark;
    drawCircleTab(i, tabColor);
  }
  
  // Draw all circles with color based on active state
  for (uint8_t i = 0; i < CIRCLE_COUNT; i++) {
    uint16_t circleColor = (activeTabIndex == i) ? Pink_Pastel : Green_Olive_Dark;
    drawCircle(i, circleColor);
  }
  
  // Draw black center dots last (on top, so tabs cut them off at the top)
  for (uint8_t i = 0; i < CIRCLE_COUNT; i++) {
    drawCircleCenter(i);
  }

  // Draw moving labels above each circle + value inside each black center circle
  for (uint8_t i = 0; i < CIRCLE_COUNT; i++) {
    drawTabLabel(i);
    drawTabValue(i);
  }
}

void DisplayLayout::drawCircle(uint8_t index, uint16_t color) {
  if (index >= CIRCLE_COUNT) return;
  
  uint16_t x = calculateCircleX(index);
  uint16_t baseY = CIRCLE_ROW_Y + (TOP_SECTION_PART_HEIGHT / 2);  // Base center position
  uint16_t y = baseY;
  
  // If this tab is active, drop the circle by 20 pixels
  if (activeTabIndex == index) {
    y = baseY + 20;
  }
  
  setupGraphicMode();
  ER5517.DrawCircle_Fill(x, y, CIRCLE_RADIUS, color);
}

void DisplayLayout::drawCircleCenter(uint8_t index) {
  if (index >= CIRCLE_COUNT) return;
  
  uint16_t x = calculateCircleX(index);
  uint16_t baseY = CIRCLE_ROW_Y + (TOP_SECTION_PART_HEIGHT / 2);  // Base center position
  uint16_t y = baseY;
  
  // If this tab is active, drop the center dot by 20 pixels (same as circle)
  if (activeTabIndex == index) {
    y = baseY + 20;
  }
  
  uint16_t centerRadius = CIRCLE_RADIUS / 2;  // Bigger circle, 1/2 the size of the main circle
  
  setupGraphicMode();
  ER5517.DrawCircle_Fill(x, y, centerRadius, Black);
}

void DisplayLayout::setTabLabel(uint8_t index, const char* label) {
  if (index >= CIRCLE_COUNT) return;
  tabLabels[index] = label;
}

void DisplayLayout::setTabValue(uint8_t index, int value) {
  if (index >= CIRCLE_COUNT) return;
  tabValues[index] = value;
}

void DisplayLayout::drawTabLabel(uint8_t index) {
  if (index >= CIRCLE_COUNT) return;
  const char* label = tabLabels[index];
  // Always show a label (fallback)
  if (!label) label = "TAB";

  uint16_t x = calculateCircleX(index);
  uint16_t baseY = CIRCLE_ROW_Y + (TOP_SECTION_PART_HEIGHT / 2);
  uint16_t y = (activeTabIndex == index) ? (baseY + 20) : baseY;

  // Place label just above the circle (8x16 font)
  int16_t labelY = (int16_t)y - (int16_t)CIRCLE_RADIUS - 18;
  if (labelY < 0) labelY = 0;

  // Move unselected tab labels down a bit so they don't touch the top edge
  const bool isActive = (activeTabIndex == index);
  if (!isActive) labelY += 6;

  // Avoid "black box" behind text by matching background to the tab color.
  // Only change text color when active (pink tab).
  const uint16_t bg = isActive ? Pink_Pastel : Green_Olive_Dark;
  const uint16_t fg = isActive ? 0xC618 : Orange_Coral; // active -> light grey text, inactive -> orange text
  setupTextMode(fg, bg);
  uint16_t labelX = (x > (strlen(label) * 4)) ? (x - (strlen(label) * 4)) : 0;
  ER5517.Goto_Text_XY(labelX, (uint16_t)labelY);
  ER5517.Show_String((char*)label);
  setupGraphicMode();
}

void DisplayLayout::drawTabValue(uint8_t index) {
  if (index >= CIRCLE_COUNT) return;
  int value = tabValues[index];

  uint16_t x = calculateCircleX(index);
  uint16_t baseY = CIRCLE_ROW_Y + (TOP_SECTION_PART_HEIGHT / 2);
  uint16_t y = (activeTabIndex == index) ? (baseY + 20) : baseY;

  char buf[8];
  snprintf(buf, sizeof(buf), "%d", value);

  // Center within the black dot (8x16 font)
  setupTextMode(0xC618, Black); // light grey text on black
  uint16_t textX = (x > (strlen(buf) * 4)) ? (x - (strlen(buf) * 4)) : 0;
  uint16_t textY = (y > 8) ? (y - 8) : 0;
  ER5517.Goto_Text_XY(textX, textY);
  ER5517.Show_String(buf);
  setupGraphicMode();
}

void DisplayLayout::drawCircleTab(uint8_t index, uint16_t color) {
  if (index >= CIRCLE_COUNT) return;
  
  uint16_t circleX = calculateCircleX(index);
  uint16_t baseCircleY = CIRCLE_ROW_Y + (TOP_SECTION_PART_HEIGHT / 2);  // Base center of circle
  uint16_t circleY = baseCircleY;
  
  // If this tab is active, drop the circle position by 20 pixels
  if (activeTabIndex == index) {
    circleY = baseCircleY + 20;
  }
  
  uint16_t tabX = circleX - (CIRCLE_TAB_WIDTH / 2);  // Center tab on circle
  uint16_t tabTopY = 0;  // Start from top of screen (draws over top bar)
  uint16_t tabBottomY = circleY;  // End at circle center (adjusted if active)
  
  setupGraphicMode();
  ER5517.Foreground_color_65k(color);
  ER5517.Line_Start_XY(tabX, tabTopY);
  ER5517.Line_End_XY(tabX + CIRCLE_TAB_WIDTH - 1, tabBottomY);
  ER5517.Start_Square_Fill();
}

void DisplayLayout::drawTopBar(uint16_t color) {
  // Calculate first tab left edge
  uint16_t firstCircleX = calculateCircleX(0);
  uint16_t firstTabX = firstCircleX - (CIRCLE_TAB_WIDTH / 2);
  
  // Draw bar from first tab left edge all the way to right edge of screen
  setupGraphicMode();
  ER5517.Foreground_color_65k(color);
  ER5517.Line_Start_XY(firstTabX, 0);
  ER5517.Line_End_XY(LCD_XSIZE_TFT - 1, 16);  // 0 to 16 = 17 pixels tall, extends to right edge
  ER5517.Start_Square_Fill();
}

void DisplayLayout::clearTopSection() {
  setupGraphicMode();
  ER5517.Foreground_color_65k(0x0000);  // Black
  ER5517.Line_Start_XY(GRID_START_X, TOP_SECTION_Y);
  ER5517.Line_End_XY(GRID_END_X, TOP_SECTION_Y + TOP_SECTION_HEIGHT - 1);
  ER5517.Start_Square_Fill();
}

void DisplayLayout::clearTabArea() {
  // Clear only the tab area (right half of top section, from top bar down)
  setupGraphicMode();
  ER5517.Foreground_color_65k(0x0000);  // Black
  
  // Calculate tab area bounds
  uint16_t firstCircleX = calculateCircleX(0);
  uint16_t firstTabX = firstCircleX - (CIRCLE_TAB_WIDTH / 2);
  uint16_t lastCircleX = calculateCircleX(CIRCLE_COUNT - 1);
  uint16_t lastTabX = lastCircleX - (CIRCLE_TAB_WIDTH / 2);
  uint16_t lastTabRightX = lastTabX + CIRCLE_TAB_WIDTH - 1;
  uint16_t tabAreaTopY = 17;  // Below top bar
  uint16_t tabAreaBottomY = CIRCLE_ROW_Y + (TOP_SECTION_PART_HEIGHT / 2) + 20 + CIRCLE_RADIUS;  // Bottom of circle + drop
  
  ER5517.Line_Start_XY(firstTabX, tabAreaTopY);
  ER5517.Line_End_XY(lastTabRightX, tabAreaBottomY);
  ER5517.Start_Square_Fill();
}

void DisplayLayout::clearButtonArea(uint8_t row, uint8_t col) {
  if (row >= BUTTON_GRID_HEIGHT || col >= BUTTON_GRID_WIDTH) return;
  
  uint16_t x = calculateButtonX(col);
  uint16_t y = calculateButtonY(row);
  uint16_t rightX = x + BUTTON_BOX_WIDTH - 1;
  uint16_t bottomY = y + BUTTON_BOX_HEIGHT - 1;
  
  setupGraphicMode();
  ER5517.Foreground_color_65k(0x0000);  // Black
  ER5517.Line_Start_XY(x, y);
  ER5517.Line_End_XY(rightX, bottomY);
  ER5517.Start_Square_Fill();
}

void DisplayLayout::clearSingleTabArea(uint8_t index) {
  if (index >= CIRCLE_COUNT) return;
  
  uint16_t circleX = calculateCircleX(index);
  uint16_t baseCircleY = CIRCLE_ROW_Y + (TOP_SECTION_PART_HEIGHT / 2);
  uint16_t maxCircleY = baseCircleY + 20 + CIRCLE_RADIUS;  // Maximum Y including drop
  uint16_t tabX = circleX - (CIRCLE_TAB_WIDTH / 2);
  uint16_t tabRightX = tabX + CIRCLE_TAB_WIDTH - 1;
  
  setupGraphicMode();
  ER5517.Foreground_color_65k(0x0000);  // Black
  // Clear from top of screen (tabs start at y=0) to bottom of circle
  ER5517.Line_Start_XY(tabX, 0);
  ER5517.Line_End_XY(tabRightX, maxCircleY);
  ER5517.Start_Square_Fill();
  
  // Redraw only the portion of the top bar that was cleared (not the entire bar)
  // Top bar is 17 pixels tall (0 to 16)
  const uint16_t TOP_BAR_HEIGHT = 17;
  ER5517.Foreground_color_65k(Green_Olive_Dark);
  ER5517.Line_Start_XY(tabX, 0);
  ER5517.Line_End_XY(tabRightX, TOP_BAR_HEIGHT - 1);
  ER5517.Start_Square_Fill();
}

void DisplayLayout::clearMiddleSection() {
  setupGraphicMode();
  ER5517.Foreground_color_65k(0x0000);  // Black
  
  // Calculate purple circle position to avoid clearing it
  const uint16_t sectionH = BOTTOM_SECTION_HEIGHT;
  const uint16_t centerY = BOTTOM_SECTION_Y + (sectionH / 2);
  const uint16_t bigR = ((sectionH >= 50) ? 20 : (sectionH >= 40 ? 16 : 14)) + 16;
  const uint16_t bigCenterY = centerY - 1;
  const uint16_t purpleCircleTop = bigCenterY - bigR;  // Top edge of purple circle
  
  // Calculate purple circle X position
  const uint16_t bigAreaX0 = (LCD_XSIZE_TFT * 2 / 3);
  const uint16_t bigAreaX1 = LCD_XSIZE_TFT - 1;
  const uint16_t bigCenterX = (bigAreaX1 > (bigR + 5)) ? (bigAreaX1 - bigR - 5) : (bigAreaX0 + ((bigAreaX1 - bigAreaX0) / 2));
  const uint16_t boxWidth = (bigR * 2) + 1;
  const uint16_t purpleCircleLeft = bigCenterX - (boxWidth / 2);  // Left edge of purple circle box
  const uint16_t purpleCircleRight = purpleCircleLeft + boxWidth - 1;  // Right edge of purple circle box
  
  // Clear middle section, but avoid purple circle area if it extends into middle section
  if (purpleCircleTop < BOTTOM_SECTION_Y && purpleCircleTop >= MIDDLE_SECTION_Y) {
    // Purple circle extends into middle section - clear around it
    // Clear area to the left of purple circle
    if (purpleCircleLeft > GRID_START_X) {
      ER5517.Line_Start_XY(GRID_START_X, MIDDLE_SECTION_Y);
      ER5517.Line_End_XY(purpleCircleLeft - 1, MIDDLE_SECTION_Y + MIDDLE_SECTION_HEIGHT - 1);
      ER5517.Start_Square_Fill();
    }
    // Clear area above purple circle (entire width)
    ER5517.Line_Start_XY(GRID_START_X, MIDDLE_SECTION_Y);
    ER5517.Line_End_XY(GRID_END_X, purpleCircleTop - 1);
    ER5517.Start_Square_Fill();
    // Clear area to the right of purple circle (only the part above purple circle)
    if (purpleCircleRight < GRID_END_X) {
      ER5517.Line_Start_XY(purpleCircleRight + 1, MIDDLE_SECTION_Y);
      ER5517.Line_End_XY(GRID_END_X, purpleCircleTop - 1);
      ER5517.Start_Square_Fill();
    }
  } else {
    // Purple circle doesn't extend into middle section - clear normally
    ER5517.Line_Start_XY(GRID_START_X, MIDDLE_SECTION_Y);
    ER5517.Line_End_XY(GRID_END_X, MIDDLE_SECTION_Y + MIDDLE_SECTION_HEIGHT - 1);
    ER5517.Start_Square_Fill();
  }
}

void DisplayLayout::clearBottomSection() {
  setupGraphicMode();
  ER5517.Foreground_color_65k(0x0000);  // Black
  ER5517.Line_Start_XY(GRID_START_X, BOTTOM_SECTION_Y);
  ER5517.Line_End_XY(GRID_END_X, BOTTOM_SECTION_Y + BOTTOM_SECTION_HEIGHT - 1);
  ER5517.Start_Square_Fill();
}

void DisplayLayout::drawBottomSectionUI() {
  // Bottom section: 1) orange button (left 1/3) with page number circle at the end,
  // 2) three small grey circles w/ labels (ext/midi/audio),
  // 3) large green circle w/ 4 small circles inside (cross pattern).
  setupGraphicMode();

  const uint16_t sectionX0 = 0;
  const uint16_t sectionX1 = LCD_XSIZE_TFT - 1;
  const uint16_t sectionY0 = BOTTOM_SECTION_Y;
  const uint16_t sectionY1 = BOTTOM_SECTION_Y + BOTTOM_SECTION_HEIGHT - 1;
  const uint16_t sectionH = BOTTOM_SECTION_HEIGHT;
  const uint16_t centerY = sectionY0 + (sectionH / 2);

  // Calculate orange button position first to determine what needs clearing
  const uint16_t orangeBtnX0 = calculateButtonX(0) + 5;
  uint16_t orangeBtnX1 = (LCD_XSIZE_TFT / 3) - 1;
  orangeBtnX1 = (orangeBtnX1 + 20 > sectionX1) ? sectionX1 : (orangeBtnX1 + 20);
  
  // Store the original (non-extended) button width
  const uint16_t originalBtnX1 = orangeBtnX1;
  
  // Calculate button dimensions
  const uint16_t orangeBtnH = (sectionH > 10) ? (sectionH - 10) : sectionH;
  const uint16_t orangeBtnY0 = sectionY0 + ((sectionH - orangeBtnH) / 2);
  const uint16_t orangeBtnY1 = orangeBtnY0 + orangeBtnH - 1;
  const uint16_t orangeBtnR = (orangeBtnH / 2);

  // Calculate extended button position if needed
  if (orangeButtonExtended) {
    // When extended, calculate circle positions first (using fixed spacing)
    // Then extend button to contain all circles (pge, ext, mid, set)
    const uint16_t screenMidX = LCD_XSIZE_TFT / 2;
    const uint16_t circleR = 15;
    const uint16_t circleSpacing = 50;  // Fixed spacing between circle centers
    const uint16_t firstCircleX = screenMidX + 20;  // Start past middle (this is "ext")
    const uint16_t pgeCircleX = firstCircleX - circleSpacing;  // "pge" circle just before "ext"
    const uint16_t lastCircleX = firstCircleX + (2 * circleSpacing);  // Third circle (index 2, "set")
    const uint16_t lastCircleRight = lastCircleX + circleR;  // Right edge of last circle
    const uint16_t buttonPadding = 10;  // Padding from button right edge
    // Extend button to contain all circles with padding
    orangeBtnX1 = (lastCircleRight + buttonPadding > sectionX1) ? sectionX1 : (lastCircleRight + buttonPadding);
  } else {
    // When not extended, ensure button width is set to original (contracted) width
    orangeBtnX1 = originalBtnX1;
  }
  
  // Only clear the minimum area needed - only where screen data is actually changing
  if (orangeButtonExtended && !previousOrangeButtonExtended) {
    // Button is expanding: only clear the expansion area (from normal button end to extended button end)
    if (orangeBtnX1 > originalBtnX1) {
      ER5517.Foreground_color_65k(Black);
      ER5517.Line_Start_XY(originalBtnX1 + 1, orangeBtnY0);
      ER5517.Line_End_XY(orangeBtnX1, orangeBtnY1);
      ER5517.Start_Square_Fill();
    }
  } else if (!orangeButtonExtended && previousOrangeButtonExtended) {
    // Button is contracting: need to clear the extended button area and redraw contracted button
    // First, calculate what the extended button width was
    const uint16_t screenMidX = LCD_XSIZE_TFT / 2;
    const uint16_t circleR = 15;
    const uint16_t circleSpacing = 50;
    const uint16_t firstCircleX = screenMidX + 20;  // "ext" circle
    const uint16_t lastCircleX = firstCircleX + (2 * circleSpacing);  // "set" circle
    const uint16_t lastCircleRight = lastCircleX + circleR;
    const uint16_t buttonPadding = 10;
    const uint16_t extendedBtnX1 = (lastCircleRight + buttonPadding > sectionX1) ? sectionX1 : (lastCircleRight + buttonPadding);
    
    // Clear the extended button area (from contracted end to extended end) - this is where the button was extended
    // Also clear the button area itself to ensure it's fully redrawn with the correct contracted width
    if (extendedBtnX1 > originalBtnX1) {
      // Clear the extended area
      ER5517.Foreground_color_65k(Black);
      ER5517.Line_Start_XY(originalBtnX1 + 1, orangeBtnY0);
      ER5517.Line_End_XY(extendedBtnX1, orangeBtnY1);
      ER5517.Start_Square_Fill();
    }
    // Also clear the button area itself to ensure clean redraw (especially the right edge/circle)
    ER5517.Foreground_color_65k(Black);
    ER5517.Line_Start_XY(orangeBtnX0, orangeBtnY0);
    ER5517.Line_End_XY(originalBtnX1, orangeBtnY1);
    ER5517.Start_Square_Fill();
    
    // Calculate where the 3 circles start (same calculation as drawing code below)
    const uint16_t smallR = (sectionH >= 40) ? 10 : (sectionH >= 28 ? 8 : 6);
    const uint16_t bigAreaX0 = (LCD_XSIZE_TFT * 2 / 3);
    const uint16_t bigAreaX1 = LCD_XSIZE_TFT - 1;
    const uint16_t bigR = ((sectionH >= 50) ? 20 : (sectionH >= 40) ? 16 : 14) + 16;
    const uint16_t bigCenterX = (bigAreaX1 > (bigR + 5)) ? (bigAreaX1 - bigR - 5) : (bigAreaX0 + ((bigAreaX1 - bigAreaX0) / 2));
    const uint16_t bigLeftEdgeX = (bigCenterX > bigR) ? (bigCenterX - bigR) : bigAreaX0;
    const uint16_t groupCenterX = screenMidX + ((bigLeftEdgeX - screenMidX) * 2) / 3;
    const uint16_t smallStep = (smallR * 3) + 22;
    const uint16_t c1x = (groupCenterX > smallStep) ? (groupCenterX - smallStep) : groupCenterX;
    const uint16_t firstCircleStartX = c1x - smallR;  // Left edge of first circle (ext)
    
    // Clear from end of extended button area to start of first circle (button height only)
    if (firstCircleStartX > extendedBtnX1) {
      ER5517.Foreground_color_65k(Black);
      ER5517.Line_Start_XY(extendedBtnX1 + 1, orangeBtnY0);
      ER5517.Line_End_XY(firstCircleStartX - 1, orangeBtnY1);
      ER5517.Start_Square_Fill();
    }
    // Also clear the area for other UI elements that need to be redrawn (grey circles and purple circle)
    // Calculate the actual Y bounds where these elements are drawn
    const uint16_t labelGap = 8;
    const uint16_t labelY = (centerY + smallR + labelGap);
    const uint16_t bigCenterY = centerY - 1;
    const uint16_t elementsTopY = centerY - smallR;  // Top of circles
    const uint16_t elementsBottomY = labelY + 16;  // Bottom of labels (8x16 font height)
    const uint16_t purpleBoxTopY = bigCenterY;  // Purple circle box starts here
    const uint16_t purpleBoxBottomY = LCD_YSIZE_TFT - 1;  // Purple circle box extends to bottom
    
    // Clear area for the 3 grey circles and their labels
    if (firstCircleStartX < sectionX1) {
      // Clear from first circle to end, but only the height where circles and labels are
      ER5517.Foreground_color_65k(Black);
      ER5517.Line_Start_XY(firstCircleStartX, elementsTopY);
      ER5517.Line_End_XY(sectionX1, elementsBottomY);
      ER5517.Start_Square_Fill();
    }
    
    // Clear area for purple circle (if it's in the cleared X range)
    // Calculate purple circle position (using already declared variables)
    const uint16_t boxWidth = (bigR * 2) + 1;
    const uint16_t boxX0 = bigCenterX - (boxWidth / 2);
    const uint16_t boxX1 = boxX0 + boxWidth - 1;
    
    // Only clear purple circle area if it overlaps with the area that was covered by extended button
    // Only clear if it's in the range from extended button end to where circles start
    if (boxX0 < sectionX1 && boxX1 >= extendedBtnX1 && boxX0 <= firstCircleStartX) {
      uint16_t clearX0 = (boxX0 > extendedBtnX1) ? boxX0 : extendedBtnX1;
      uint16_t clearX1 = (boxX1 < firstCircleStartX) ? boxX1 : (firstCircleStartX - 1);
      // Only clear the height where the purple circle actually is (circle + box)
      // The box extends from bigCenterY to bottom, but only clear what was covered by extended button
      const uint16_t purpleCircleTopY = bigCenterY - bigR;  // Top of purple circle
      const uint16_t purpleCircleBottomY = bigCenterY + bigR;  // Bottom of purple circle
      ER5517.Foreground_color_65k(Black);
      // Clear the circle area
      ER5517.Line_Start_XY(clearX0, purpleCircleTopY);
      ER5517.Line_End_XY(clearX1, purpleCircleBottomY);
      ER5517.Start_Square_Fill();
      // Clear the box area below the circle (only if it was covered by extended button)
      // Only clear down to section bottom, not entire screen
      if (purpleBoxBottomY > purpleCircleBottomY && purpleBoxBottomY <= sectionY1) {
        ER5517.Line_Start_XY(clearX0, purpleCircleBottomY + 1);
        ER5517.Line_End_XY(clearX1, sectionY1);
        ER5517.Start_Square_Fill();
      }
    }
  } else if (!orangeButtonExtended && !previousOrangeButtonExtended) {
    // Button state unchanged (not extended): clear button area and other UI elements (initial draw or full redraw)
    ER5517.Foreground_color_65k(Black);
    ER5517.Line_Start_XY(orangeBtnX0, orangeBtnY0);
    ER5517.Line_End_XY(orangeBtnX1, orangeBtnY1);
    ER5517.Start_Square_Fill();
    
    // Clear the rest of the bottom section for other elements (grey circles and purple circle)
    if (orangeBtnX1 < sectionX1) {
      ER5517.Line_Start_XY(orangeBtnX1 + 1, sectionY0);
      ER5517.Line_End_XY(sectionX1, sectionY1);
      ER5517.Start_Square_Fill();
    }
  }
  // If button is extended and was already extended, don't clear anything (no change)

  // 1) Long orange button, left 1/3 width (aligned with top button block)
  // Top pill buttons have a built-in 5px inset (from the circleOffset logic),
  // so match the *visual* left edge by adding the same inset here.
  // Note: orangeBtnX0 and orangeBtnX1 are already calculated above (may have been extended for circles)

  // pill button
  ER5517.Foreground_color_65k(Orange_Coral);
  // middle rect
  if (orangeBtnX1 > orangeBtnX0 + (orangeBtnR * 2)) {
    ER5517.Line_Start_XY(orangeBtnX0 + orangeBtnR, orangeBtnY0);
    ER5517.Line_End_XY(orangeBtnX1 - orangeBtnR, orangeBtnY1);
    ER5517.Start_Square_Fill();
  }
  // end circles
  ER5517.DrawCircle_Fill(orangeBtnX0 + orangeBtnR, orangeBtnY0 + orangeBtnR, orangeBtnR, Orange_Coral);
  ER5517.DrawCircle_Fill(orangeBtnX1 - orangeBtnR, orangeBtnY0 + orangeBtnR, orangeBtnR, Orange_Coral);

  // Centered text inside orange button: show current page name
  setupTextMode(0xC618, Orange_Coral); // light grey text on orange background
  {
    const char* label = getCurrentPageName();
    uint16_t textX = orangeBtnX0 + ((orangeBtnX1 - orangeBtnX0 + 1) / 2) - (strlen(label) * 4);
    uint16_t textY = orangeBtnY0 + ((orangeBtnY1 - orangeBtnY0 + 1) / 2) - 8;
    ER5517.Goto_Text_XY(textX, textY);
    ER5517.Show_String((char*)label);
  }
  setupGraphicMode();

  // Orange page number circle at the end of the orange button (smaller than button height)
  // Only draw when not extended
  if (!orangeButtonExtended) {
    // Position the circle so it sits at the right edge of the button
    const uint16_t pageCircleR = (orangeBtnR * 3) / 4;  // Make it 3/4 the size of button radius (smaller)
    const uint16_t pageCircleCenterY = orangeBtnY0 + orangeBtnR;
    // Position circle center at the right edge of the button (so circle sits at the end)
    const uint16_t pageCircleCenterX = orangeBtnX1 - orangeBtnR;
    if (pageCircleCenterX + pageCircleR < LCD_XSIZE_TFT) {
      // Make this circle magenta
      ER5517.Foreground_color_65k(Pink_Magenta);
      ER5517.DrawCircle_Fill(pageCircleCenterX, pageCircleCenterY, pageCircleR, Pink_Magenta);

      // Page number text inside circle (white)
      setupTextMode(White, Pink_Magenta);
      {
        const char* pageNum = "1";
        uint16_t pTextX = pageCircleCenterX - 4; // ~1 char centered for 8x16 font
        uint16_t pTextY = pageCircleCenterY - 8;
        ER5517.Goto_Text_XY(pTextX, pTextY);
        ER5517.Show_String((char*)pageNum);
      }
      setupGraphicMode();
    }
  }

  // Draw 4 circles (pge, ext, mid, set) when orange button is extended
  if (orangeButtonExtended) {
    const uint16_t screenMidX = LCD_XSIZE_TFT / 2;
    const uint16_t circleR = 15;  // Radius of the circles
    const uint16_t circleSpacing = 50;  // Fixed spacing between circle centers (must match clearing logic)
    const uint16_t firstCircleX = screenMidX + 20;  // Start past middle (this is "ext")
    const uint16_t pgeCircleX = firstCircleX - circleSpacing;  // "pge" circle just before "ext"
    const uint16_t circleY = centerY;
    
    // Draw "pge" circle first (just before "ext")
    ER5517.Foreground_color_65k(Pink_Pastel);  // Use Pink_Pastel to match other button colors
    ER5517.DrawCircle_Fill(pgeCircleX, circleY, circleR, Pink_Pastel);
    
    // Draw "pge" text inside circle
    setupTextMode(White, Pink_Pastel);
    {
      const char* pgeText = "pge";
      uint16_t textX = pgeCircleX - (strlen(pgeText) * 4) / 2;
      uint16_t textY = circleY - 8;
      ER5517.Goto_Text_XY(textX, textY);
      ER5517.Show_String((char*)pgeText);
    }
    setupGraphicMode();
    
    // Colors for each circle (ext, mid, set)
    uint16_t circleColors[3] = {Green_Olive_Dark, Purple_Dark, Magenta_Dark};
    const char* circleTexts[3] = {"ext", "mid", "set"};
    
    for (uint8_t i = 0; i < 3; i++) {
      uint16_t circleX = firstCircleX + (i * circleSpacing);
      
      // Draw circle
      ER5517.Foreground_color_65k(circleColors[i]);
      ER5517.DrawCircle_Fill(circleX, circleY, circleR, circleColors[i]);
      
      // Draw text inside circle
      setupTextMode(White, circleColors[i]);
      uint16_t textX = circleX - (strlen(circleTexts[i]) * 4) / 2;
      uint16_t textY = circleY - 8;
      ER5517.Goto_Text_XY(textX, textY);
      ER5517.Show_String((char*)circleTexts[i]);
    }
    setupGraphicMode();
  }

  // 2) Three small grey circles with labels ext/midi/audio (only when not extended)
  // 3) Large purple circle on the right with 4 smaller circles inside (only when not extended)
  if (!orangeButtonExtended) {
    const uint16_t smallR = (sectionH >= 40) ? 10 : (sectionH >= 28 ? 8 : 6);
    const uint16_t labelGap = 8;
    const uint16_t labelY = (centerY + smallR + labelGap);

    // 3) Large purple circle on the right with 4 smaller circles inside (cross pattern)
    const uint16_t bigAreaX0 = (LCD_XSIZE_TFT * 2 / 3);
    const uint16_t bigAreaX1 = LCD_XSIZE_TFT - 1;
    const uint16_t bigR = ((sectionH >= 50) ? 20 : (sectionH >= 40 ? 16 : 14)) + 16; // slightly smaller
    // Move to far right with a small margin
    const uint16_t bigCenterX = (bigAreaX1 > (bigR + 5)) ? (bigAreaX1 - bigR - 5) : (bigAreaX0 + ((bigAreaX1 - bigAreaX0) / 2));
    const uint16_t innerR = (bigR >= 30) ? 10 : ((bigR >= 22) ? 9 : 8); // bigger inner circles
    const uint16_t d = (bigR * 2) / 3;  // cross spacing from center (spaced further apart)
    const uint16_t bigCenterY = centerY - 1;  // Move circle down by 4 pixels from previous position

    // Draw box behind the circle (like inverted tab) - draw before circle so it's behind
    const uint16_t boxWidth = (bigR * 2) + 1;  // Same width as circle diameter + 1 (like tabs)
    const uint16_t boxX0 = bigCenterX - (boxWidth / 2);
    const uint16_t boxX1 = boxX0 + boxWidth - 1;
    const uint16_t boxY0 = bigCenterY;  // Start from middle of circle
    const uint16_t boxY1 = LCD_YSIZE_TFT - 1;  // Extend to bottom of screen
    ER5517.Foreground_color_65k(Purple_Dark);
    ER5517.Line_Start_XY(boxX0, boxY0);
    ER5517.Line_End_XY(boxX1, boxY1);
    ER5517.Start_Square_Fill();

    // Use Purple_Dark for the large circle
    ER5517.Foreground_color_65k(Purple_Dark);
    ER5517.DrawCircle_Fill(bigCenterX, bigCenterY, bigR, Purple_Dark);

    ER5517.Foreground_color_65k(Green_Olive_Dark);
    // Cross (+) inner circles: left, right, up, down
    ER5517.DrawCircle_Fill(bigCenterX - d, bigCenterY, innerR, Green_Olive_Dark);
    ER5517.DrawCircle_Fill(bigCenterX + d, bigCenterY, innerR, Green_Olive_Dark);
    ER5517.DrawCircle_Fill(bigCenterX, bigCenterY - d, innerR, Green_Olive_Dark);
    ER5517.DrawCircle_Fill(bigCenterX, bigCenterY + d, innerR, Green_Olive_Dark);

    // Add text to each inner circle: L, R, +, -
    setupTextMode(White, Green_Olive_Dark);
    // Left circle: "L"
    ER5517.Goto_Text_XY(bigCenterX - d - 4, bigCenterY - 8);
    ER5517.Show_String((char*)"L");
    // Right circle: "R"
    ER5517.Goto_Text_XY(bigCenterX + d - 4, bigCenterY - 8);
    ER5517.Show_String((char*)"R");
    // Top circle: "+"
    ER5517.Goto_Text_XY(bigCenterX - 4, bigCenterY - d - 8);
    ER5517.Show_String((char*)"+");
    // Bottom circle: "-"
    ER5517.Goto_Text_XY(bigCenterX - 4, bigCenterY + d - 8);
    ER5517.Show_String((char*)"-");
    setupGraphicMode();

    // Now place the 3 labelled circles:
    // group center sits closer to the big circle (2/3 of the way from screen center to green circle's left edge).
    const uint16_t screenMidX = LCD_XSIZE_TFT / 2;
    const uint16_t bigLeftEdgeX = (bigCenterX > bigR) ? (bigCenterX - bigR) : bigAreaX0;
    const uint16_t groupCenterX = screenMidX + ((bigLeftEdgeX - screenMidX) * 2) / 3;  // Closer to green circle
    const uint16_t smallStep = (smallR * 3) + 22;
    const uint16_t c2x = groupCenterX;
    const uint16_t c1x = (groupCenterX > smallStep) ? (groupCenterX - smallStep) : groupCenterX;
    const uint16_t c3x = groupCenterX + smallStep;

    // Make the 3 bottom circles darker grey
    ER5517.Foreground_color_65k(darkerGrey);
    ER5517.DrawCircle_Fill(c1x, centerY, smallR, darkerGrey);
    ER5517.DrawCircle_Fill(c2x, centerY, smallR, darkerGrey);
    ER5517.DrawCircle_Fill(c3x, centerY, smallR, darkerGrey);

    // labels (Orange_Coral)
    setupTextMode(Orange_Coral, Black);
    ER5517.Goto_Text_XY(c1x - 12, labelY);
    ER5517.Show_String((char*)"ext");
    ER5517.Goto_Text_XY(c2x - 16, labelY);
    ER5517.Show_String((char*)"midi");
    ER5517.Goto_Text_XY(c3x - 20, labelY);
    ER5517.Show_String((char*)"audio");
    setupGraphicMode();
  }
}

void DisplayLayout::drawPage() {
  // Draw a page box covering the middle section, but leave room for purple circle at bottom
  // Calculate purple circle position to determine how much space to leave
  const uint16_t sectionH = BOTTOM_SECTION_HEIGHT;
  const uint16_t centerY = BOTTOM_SECTION_Y + (sectionH / 2);
  const uint16_t bigR = ((sectionH >= 50) ? 20 : (sectionH >= 40 ? 16 : 14)) + 16;
  const uint16_t bigCenterY = centerY - 1;
  const uint16_t purpleCircleTop = bigCenterY - bigR;  // Top edge of purple circle
  
  // Calculate purple circle X position to avoid drawing over it
  const uint16_t bigAreaX0 = (LCD_XSIZE_TFT * 2 / 3);
  const uint16_t bigAreaX1 = LCD_XSIZE_TFT - 1;
  const uint16_t bigCenterX = (bigAreaX1 > (bigR + 5)) ? (bigAreaX1 - bigR - 5) : (bigAreaX0 + ((bigAreaX1 - bigAreaX0) / 2));
  const uint16_t boxWidth = (bigR * 2) + 1;
  const uint16_t purpleCircleLeft = bigCenterX - (boxWidth / 2);  // Left edge of purple circle box
  
  const uint16_t pageX0 = 0;  // Start from left edge
  // Don't extend page box to right edge if purple circle extends into middle section
  uint16_t pageX1 = LCD_XSIZE_TFT - 1;  // End at right edge (will be adjusted if needed)
  if (purpleCircleTop < BOTTOM_SECTION_Y && purpleCircleLeft < LCD_XSIZE_TFT) {
    // Purple circle extends into middle section, don't draw page box over it
    pageX1 = purpleCircleLeft - 5;  // Leave 5px gap before purple circle
  }
  const uint16_t pageY0 = MIDDLE_SECTION_Y;  // Start at top of middle section
  // Leave 5px gap above purple circle top to avoid cutting it off
  uint16_t pageY1 = (purpleCircleTop < BOTTOM_SECTION_Y) ? (purpleCircleTop - 5) : (BOTTOM_SECTION_Y - 1);
  
  setupGraphicMode();
  // Draw page background (lighter grey - mainGrey)
  ER5517.Foreground_color_65k(mainGrey);
  ER5517.Line_Start_XY(pageX0, pageY0);
  ER5517.Line_End_XY(pageX1, pageY1);
  ER5517.Start_Square_Fill();
  
  // Draw page border outline (white or lighter color for visibility)
  ER5517.Foreground_color_65k(White);
  ER5517.Line_Start_XY(pageX0, pageY0);
  ER5517.Line_End_XY(pageX1, pageY0);
  ER5517.Start_Line();
  ER5517.Line_Start_XY(pageX0, pageY1);
  ER5517.Line_End_XY(pageX1, pageY1);
  ER5517.Start_Line();
  ER5517.Line_Start_XY(pageX0, pageY0);
  ER5517.Line_End_XY(pageX0, pageY1);
  ER5517.Start_Line();
  ER5517.Line_Start_XY(pageX1, pageY0);
  ER5517.Line_End_XY(pageX1, pageY1);
  ER5517.Start_Line();
}

void DisplayLayout::drawTestPage() {
  // Get page dimensions (same as drawPage)
  const uint16_t pageGapHorizontal = 5;
  const uint16_t pageGapTop = 0;
  const uint16_t pageGapBottom = 50;  // Increased gap at bottom to prevent cutting off purple circle
  const uint16_t pageX0 = pageGapHorizontal;
  const uint16_t pageX1 = LCD_XSIZE_TFT - 1 - pageGapHorizontal;
  const uint16_t pageY0 = MIDDLE_SECTION_Y + pageGapTop;
  const uint16_t pageY1 = BOTTOM_SECTION_Y - 1 - pageGapBottom;
  
  const uint16_t pageWidth = pageX1 - pageX0 + 1;
  const uint16_t pageHeight = pageY1 - pageY0 + 1;
  
  // Grid: 6 columns, 5 rows (top row is thinner)
  const uint8_t gridCols = 6;
  const uint8_t gridRows = 5;
  const uint16_t topRowHeight = (pageHeight / 10) + 10;  // Top row is thinner (1/10 of height) + 10 pixels
  const uint16_t normalRowHeight = (pageHeight - topRowHeight) / (gridRows - 1);  // Remaining rows share the rest
  
  const uint16_t colWidth = pageWidth / gridCols;
  
  setupGraphicMode();
  
  // Calculate top row bottom position
  uint16_t topRowBottom = pageY0 + topRowHeight;
  
  // Draw buttons in top row with text: "all", "none", "back", "all", "none", "back"
  const char* buttonTexts[6] = {"all", "none", "back", "all", "none", "back"};
  const uint16_t topButtonHeight = topRowHeight - 4;  // Slightly smaller than row height
  const uint16_t topButtonY = pageY0 + 2;  // Centered in top row
  
  for (uint8_t col = 0; col < gridCols; col++) {
    uint16_t buttonX0 = pageX0 + (col * colWidth) + 2;
    uint16_t buttonX1 = buttonX0 + colWidth - 5;
    uint16_t buttonCenterY = topButtonY + (topButtonHeight / 2);
    
    // Draw button background (darker grey)
    ER5517.Foreground_color_65k(darkerGrey);
    ER5517.Line_Start_XY(buttonX0, topButtonY);
    ER5517.Line_End_XY(buttonX1, topButtonY + topButtonHeight - 1);
    ER5517.Start_Square_Fill();
    
    // Draw button text
    setupTextMode(White, darkerGrey);
    uint16_t textX = buttonX0 + ((buttonX1 - buttonX0 + 1) / 2) - (strlen(buttonTexts[col]) * 4);
    uint16_t textY = buttonCenterY - 8;
    ER5517.Goto_Text_XY(textX, textY);
    ER5517.Show_String((char*)buttonTexts[col]);
  }
  
  // Draw red buttons in the remaining 4 rows
  const uint16_t redButtonHeight = normalRowHeight - 4;  // Slightly smaller than row height
  
  for (uint8_t row = 1; row < gridRows; row++) {
    uint16_t rowY0 = topRowBottom + ((row - 1) * normalRowHeight) + 2;
    
    for (uint8_t col = 0; col < gridCols; col++) {
      uint16_t buttonX0 = pageX0 + (col * colWidth) + 2;
      uint16_t buttonX1 = buttonX0 + colWidth - 5;
      
      // Draw red button background (using Orange_dark from bottom right top button)
      ER5517.Foreground_color_65k(Orange_dark);
      ER5517.Line_Start_XY(buttonX0, rowY0);
      ER5517.Line_End_XY(buttonX1, rowY0 + redButtonHeight - 1);
      ER5517.Start_Square_Fill();
    }
  }
  
  setupGraphicMode();
}

void DisplayLayout::setupTextMode(uint16_t fgColor, uint16_t bgColor) {
  ER5517.Foreground_color_65k(fgColor);
  ER5517.Background_color_65k(bgColor);
  ER5517.CGROM_Select_Internal_CGROM();
  ER5517.Font_Select_8x16_16x16();
  ER5517.Font_Width_X1();  // Back to smaller text
  ER5517.Font_Height_X1(); // Back to smaller text
  ER5517.Text_Mode();
}

void DisplayLayout::setActiveTab(uint8_t index) {
  // Only allow valid tab indices or 255 to deactivate
  if (index < CIRCLE_COUNT || index == 255) {
    activeTabIndex = index;
  }
}

uint8_t DisplayLayout::getTouchedTab(uint16_t x, uint16_t y) {
  // Check if touch is within the tab area (from top bar down to circle center)
  // Tabs start at y=17 (below top bar) and go down to circle center
  
  uint16_t baseCircleY = CIRCLE_ROW_Y + (TOP_SECTION_PART_HEIGHT / 2);
  uint16_t tabTopY = 17;
  uint16_t maxTabY = baseCircleY + 20;  // Maximum Y (accounting for active tab drop)
  
  // Check if touch is in the vertical range of tabs
  if (y < tabTopY || y > maxTabY) {
    return 255;  // Not in tab area
  }
  
  // Check each tab's horizontal bounds
  for (uint8_t i = 0; i < CIRCLE_COUNT; i++) {
    uint16_t circleX = calculateCircleX(i);
    uint16_t tabX = circleX - (CIRCLE_TAB_WIDTH / 2);
    uint16_t tabRightX = tabX + CIRCLE_TAB_WIDTH - 1;
    
    if (x >= tabX && x <= tabRightX) {
      return i;  // Touch is on this tab
    }
  }
  
  return 255;  // Not on any tab
}

void DisplayLayout::setupGraphicMode() {
  ER5517.Graphic_Mode();
}

uint16_t DisplayLayout::calculateButtonX(uint8_t col) {
  // Calculate button X position - buttons are positioned with consistent horizontal spacing
  // Start from BUTTON_GRID_START_X and add spacing between buttons
  return BUTTON_GRID_START_X + (col * (BUTTON_BOX_WIDTH + BUTTON_HORIZONTAL_SPACING));
}

uint16_t DisplayLayout::calculateButtonY(uint8_t row) {
  // Calculate button Y position - buttons are positioned with consistent vertical spacing
  // Start from BUTTON_GRID_START_Y and add spacing between buttons (reduced spacing)
  uint16_t verticalGap = 16;  // Gap between buttons
  return BUTTON_GRID_START_Y + (row * (BUTTON_BOX_HEIGHT + verticalGap));
}

void DisplayLayout::drawButtonBackground(uint16_t color) {
  // Calculate the bounds of all buttons
  uint16_t firstButtonX = calculateButtonX(0);
  uint16_t lastButtonX = calculateButtonX(BUTTON_GRID_WIDTH - 1) + BUTTON_BOX_WIDTH - 1;
  uint16_t backgroundWidth = lastButtonX - firstButtonX + 1;
  
  // Draw full-height rectangle from top of screen (y=0) to bottom of top section
  uint16_t backgroundBottomY = TOP_SECTION_Y + TOP_SECTION_HEIGHT - 1;
  
  setupGraphicMode();
  ER5517.Foreground_color_65k(color);
  ER5517.Line_Start_XY(firstButtonX, 0);
  ER5517.Line_End_XY(lastButtonX, backgroundBottomY);
  ER5517.Start_Square_Fill();
}

void DisplayLayout::setButtonActive(uint8_t row, uint8_t col, bool active) {
  if (row < BUTTON_GRID_HEIGHT && col < BUTTON_GRID_WIDTH) {
    buttonActiveState[row][col] = active;
  }
}

bool DisplayLayout::isButtonActive(uint8_t row, uint8_t col) {
  if (row < BUTTON_GRID_HEIGHT && col < BUTTON_GRID_WIDTH) {
    return buttonActiveState[row][col];
  }
  return false;
}

bool DisplayLayout::getTouchedButton(uint16_t x, uint16_t y, uint8_t* outRow, uint8_t* outCol) {
  // Check each button directly (no bounds check needed, individual button checks are sufficient)
  for (uint8_t row = 0; row < BUTTON_GRID_HEIGHT; row++) {
    for (uint8_t col = 0; col < BUTTON_GRID_WIDTH; col++) {
      uint16_t btnX = calculateButtonX(col);
      uint16_t btnY = calculateButtonY(row);
      uint16_t btnRightX = btnX + BUTTON_BOX_WIDTH - 1;
      uint16_t btnBottomY = btnY + BUTTON_BOX_HEIGHT - 1;
      
      if (x >= btnX && x <= btnRightX && y >= btnY && y <= btnBottomY) {
        *outRow = row;
        *outCol = col;
        return true;
      }
    }
  }
  
  return false;
}

uint16_t DisplayLayout::calculateCircleX(uint8_t index) {
  // Start from middle of screen, space circles evenly in right half
  // First circle starts at CIRCLE_AREA_START_X + CIRCLE_SPACING
  return CIRCLE_AREA_START_X + CIRCLE_SPACING + (index * CIRCLE_SPACING);
}

void DisplayLayout::setCurrentPage(PageType page) {
  if (page < PAGE_COUNT) {
    currentPage = page;
  }
}

const char* DisplayLayout::getCurrentPageName() {
  switch (currentPage) {
    case PAGE_GLOBAL: return "global";
    case PAGE_EXT: return "ext";
    case PAGE_MIDI: return "midi";
    case PAGE_SETTINGS: return "settings";
    case PAGE_DIGITAL: return "digital";
    case PAGE_ANALOG: return "analog";
    case PAGE_SHAPES: return "shapes";
    case PAGE_OSCILLATOR: return "osc";
    case PAGE_CENTRAL: return "pages";
    default: return "unknown";
  }
}

void DisplayLayout::drawPageContent() {
  // Clear middle section completely with black first
  clearMiddleSection();
  ER5517.Check_2D_Busy();  // Wait for clear to complete
  
  if (currentPage == PAGE_CENTRAL) {
    // Calculate page dimensions (no page box, just use full middle section)
    const uint16_t sectionH = BOTTOM_SECTION_HEIGHT;
    const uint16_t centerY = BOTTOM_SECTION_Y + (sectionH / 2);
    const uint16_t bigR = ((sectionH >= 50) ? 20 : (sectionH >= 40 ? 16 : 14)) + 16;
    const uint16_t bigCenterY = centerY - 1;
    const uint16_t purpleCircleTop = bigCenterY - bigR;
    
    const uint16_t pageX0 = 0;
    const uint16_t pageX1 = LCD_XSIZE_TFT - 1;
    const uint16_t pageY0 = MIDDLE_SECTION_Y;
    const uint16_t pageY1 = (purpleCircleTop < BOTTOM_SECTION_Y) ? (purpleCircleTop - 5) : (BOTTOM_SECTION_Y - 1);
    
    // Draw central page with buttons for all pages
    
    const uint8_t gridCols = 3;
    const uint8_t gridRows = 3;
    const uint16_t pageWidth = pageX1 - pageX0 + 1;
    const uint16_t pageHeight = pageY1 - pageY0 + 1;
    const uint16_t buttonSpacingX = 10;
    const uint16_t buttonSpacingY = 10;
    
    // Calculate balanced margins - ensure left and right are equal
    const uint16_t totalHorizontalMargin = 40;  // Total margin (20px on each side)
    const uint16_t totalVerticalMargin = 40;    // Total margin (20px on each side)
    const uint16_t buttonWidth = (pageWidth - totalHorizontalMargin - (buttonSpacingX * (gridCols - 1))) / gridCols;
    const uint16_t buttonHeight = (pageHeight - totalVerticalMargin - (buttonSpacingY * (gridRows - 1))) / gridRows;
    
    // Calculate start position to center the grid with equal margins
    const uint16_t usedWidth = (buttonWidth * gridCols) + (buttonSpacingX * (gridCols - 1));
    const uint16_t usedHeight = (buttonHeight * gridRows) + (buttonSpacingY * (gridRows - 1));
    const uint16_t startX = pageX0 + (pageWidth - usedWidth) / 2;  // Centered with equal margins
    const uint16_t startY = pageY0 + (pageHeight - usedHeight) / 2;  // Centered with equal margins
    
    // Page names (excluding PAGE_CENTRAL)
    const char* pageNames[PAGE_COUNT - 1] = {
      "global", "ext", "midi", "settings", "digital", "analog", "shapes", "osc"
    };
    
    // Button colors
    uint16_t buttonColors[PAGE_COUNT - 1] = {
      Green_Olive_Dark, Purple_Dark, Magenta_Dark, Orange_dark,
      Pink_Magenta, Green_Lime, darkerGrey, Pink_Pastel
    };
    
    setupGraphicMode();
    
    // Draw buttons for each page (3x3 grid, 8 buttons total)
    for (uint8_t i = 0; i < PAGE_COUNT - 1; i++) {
      uint8_t row = i / gridCols;
      uint8_t col = i % gridCols;
      
      uint16_t btnX0 = startX + col * (buttonWidth + buttonSpacingX);
      uint16_t btnY0 = startY + row * (buttonHeight + buttonSpacingY);
      uint16_t btnX1 = btnX0 + buttonWidth - 1;
      uint16_t btnY1 = btnY0 + buttonHeight - 1;
      
      // Draw button background
      ER5517.Foreground_color_65k(buttonColors[i]);
      ER5517.Line_Start_XY(btnX0, btnY0);
      ER5517.Line_End_XY(btnX1, btnY1);
      ER5517.Start_Square_Fill();
      
      // Draw button text
      setupTextMode(White, buttonColors[i]);
      const char* pageName = pageNames[i];
      uint16_t textX = btnX0 + ((btnX1 - btnX0 + 1) / 2) - (strlen(pageName) * 4) / 2;
      uint16_t textY = btnY0 + ((btnY1 - btnY0 + 1) / 2) - 8;
      ER5517.Goto_Text_XY(textX, textY);
      ER5517.Show_String((char*)pageName);
    }
    
    // Draw "back" button in the last position (row 2, col 2)
    uint8_t backRow = 2;
    uint8_t backCol = 2;
    uint16_t btnX0 = startX + backCol * (buttonWidth + buttonSpacingX);
    uint16_t btnY0 = startY + backRow * (buttonHeight + buttonSpacingY);
    uint16_t btnX1 = btnX0 + buttonWidth - 1;
    uint16_t btnY1 = btnY0 + buttonHeight - 1;
    
    ER5517.Foreground_color_65k(Black);
    ER5517.Line_Start_XY(btnX0, btnY0);
    ER5517.Line_End_XY(btnX1, btnY1);
    ER5517.Start_Square_Fill();
    
    setupTextMode(White, Black);
    const char* backText = "back";
    uint16_t textX = btnX0 + ((btnX1 - btnX0 + 1) / 2) - (strlen(backText) * 4) / 2;
    uint16_t textY = btnY0 + ((btnY1 - btnY0 + 1) / 2) - 8;
    ER5517.Goto_Text_XY(textX, textY);
    ER5517.Show_String((char*)backText);
    
    setupGraphicMode();
  } else {
    // Calculate available page area (avoiding purple circle)
    const uint16_t sectionH = BOTTOM_SECTION_HEIGHT;
    const uint16_t centerY = BOTTOM_SECTION_Y + (sectionH / 2);
    const uint16_t bigR = ((sectionH >= 50) ? 20 : (sectionH >= 40 ? 16 : 14)) + 16;
    const uint16_t bigCenterY = centerY - 1;
    const uint16_t purpleCircleTop = bigCenterY - bigR;
    
    const uint16_t pageX0 = 0;
    const uint16_t pageX1 = LCD_XSIZE_TFT - 1;
    const uint16_t pageY0 = MIDDLE_SECTION_Y;
    const uint16_t pageY1 = (purpleCircleTop < BOTTOM_SECTION_Y) ? (purpleCircleTop - 5) : (BOTTOM_SECTION_Y - 1);
    
    const uint16_t pageWidth = pageX1 - pageX0 + 1;
    const uint16_t pageHeight = pageY1 - pageY0 + 1;
    
    // Common border size for all blocks
    const uint16_t borderSize = 5;
    
    // Draw page-specific layouts
    switch (currentPage) {
      case PAGE_SETTINGS: {
        // Single background block
        drawPageBlock(pageX0 + borderSize, pageY0 + borderSize, 
                     pageX1 - borderSize, pageY1 - borderSize, 
                     "settings", darkerGrey);
        break;
      }
      
      case PAGE_EXT: {
        // 2 blocks next to each other: 'audio' and 'cv/trig'
        const uint16_t blockWidth = (pageWidth - (borderSize * 3)) / 2;  // 3 borders: left, middle, right
        const uint16_t blockHeight = pageHeight - (borderSize * 2);  // top and bottom borders
        
        // Left block: 'audio'
        drawPageBlock(pageX0 + borderSize, pageY0 + borderSize,
                     pageX0 + borderSize + blockWidth - 1, pageY0 + borderSize + blockHeight - 1,
                     "audio", darkerGrey);
        
        // Right block: 'cv/trig'
        drawPageBlock(pageX0 + borderSize + blockWidth + borderSize, pageY0 + borderSize,
                     pageX1 - borderSize, pageY0 + borderSize + blockHeight - 1,
                     "cv/trig", darkerGrey);
        break;
      }
      
      case PAGE_MIDI: {
        // 2 blocks next to each other: 'midi' and 'seq'
        const uint16_t blockWidth = (pageWidth - (borderSize * 3)) / 2;
        const uint16_t blockHeight = pageHeight - (borderSize * 2);
        
        // Left block: 'midi'
        drawPageBlock(pageX0 + borderSize, pageY0 + borderSize,
                     pageX0 + borderSize + blockWidth - 1, pageY0 + borderSize + blockHeight - 1,
                     "midi", darkerGrey);
        
        // Right block: 'seq'
        drawPageBlock(pageX0 + borderSize + blockWidth + borderSize, pageY0 + borderSize,
                     pageX1 - borderSize, pageY0 + borderSize + blockHeight - 1,
                     "seq", darkerGrey);
        break;
      }
      
      case PAGE_OSCILLATOR: {
        // 3 columns: 'oc1', 'osc2', 'rnd'
        const uint16_t blockWidth = (pageWidth - (borderSize * 4)) / 3;  // 4 borders: left, 2 middle, right
        const uint16_t blockHeight = pageHeight - (borderSize * 2);
        
        // Left block: 'oc1'
        drawPageBlock(pageX0 + borderSize, pageY0 + borderSize,
                     pageX0 + borderSize + blockWidth - 1, pageY0 + borderSize + blockHeight - 1,
                     "oc1", darkerGrey);
        
        // Middle block: 'osc2'
        drawPageBlock(pageX0 + borderSize + blockWidth + borderSize, pageY0 + borderSize,
                     pageX0 + borderSize + (blockWidth * 2) + borderSize - 1, pageY0 + borderSize + blockHeight - 1,
                     "osc2", darkerGrey);
        
        // Right block: 'rnd'
        drawPageBlock(pageX0 + borderSize + (blockWidth * 2) + (borderSize * 2), pageY0 + borderSize,
                     pageX1 - borderSize, pageY0 + borderSize + blockHeight - 1,
                     "rnd", darkerGrey);
        break;
      }
      
      case PAGE_SHAPES: {
        // 2 columns: 'shape1' and 'shape2'
        const uint16_t blockWidth = (pageWidth - (borderSize * 3)) / 2;
        const uint16_t blockHeight = pageHeight - (borderSize * 2);
        
        // Left block: 'shape1'
        drawPageBlock(pageX0 + borderSize, pageY0 + borderSize,
                     pageX0 + borderSize + blockWidth - 1, pageY0 + borderSize + blockHeight - 1,
                     "shape1", darkerGrey);
        
        // Right block: 'shape2'
        drawPageBlock(pageX0 + borderSize + blockWidth + borderSize, pageY0 + borderSize,
                     pageX1 - borderSize, pageY0 + borderSize + blockHeight - 1,
                     "shape2", darkerGrey);
        break;
      }
      
      default: {
        // For other pages, just print the page name
        setupTextMode(White, Black);
        const char* pageName = getCurrentPageName();
        uint16_t textX = (LCD_XSIZE_TFT / 2) - (strlen(pageName) * 4);
        uint16_t textY = MIDDLE_SECTION_Y + (MIDDLE_SECTION_HEIGHT / 2) - 8;
        ER5517.Goto_Text_XY(textX, textY);
        ER5517.Show_String((char*)pageName);
        setupGraphicMode();
        break;
      }
    }
  }
}

void DisplayLayout::drawPageBlock(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1, const char* label, uint16_t bgColor) {
  setupGraphicMode();
  
  // Draw block background
  ER5517.Foreground_color_65k(bgColor);
  ER5517.Line_Start_XY(x0, y0);
  ER5517.Line_End_XY(x1, y1);
  ER5517.Start_Square_Fill();
  
  // Draw border (white outline)
  ER5517.Foreground_color_65k(White);
  // Top border
  ER5517.Line_Start_XY(x0, y0);
  ER5517.Line_End_XY(x1, y0);
  ER5517.Start_Line();
  // Bottom border
  ER5517.Line_Start_XY(x0, y1);
  ER5517.Line_End_XY(x1, y1);
  ER5517.Start_Line();
  // Left border
  ER5517.Line_Start_XY(x0, y0);
  ER5517.Line_End_XY(x0, y1);
  ER5517.Start_Line();
  // Right border
  ER5517.Line_Start_XY(x1, y0);
  ER5517.Line_End_XY(x1, y1);
  ER5517.Start_Line();
  
  // Draw label at top of block
  if (label != nullptr && strlen(label) > 0) {
    setupTextMode(White, bgColor);
    uint16_t textX = x0 + ((x1 - x0 + 1) / 2) - (strlen(label) * 4) / 2;
    uint16_t textY = y0 + 10;  // Small offset from top
    ER5517.Goto_Text_XY(textX, textY);
    ER5517.Show_String((char*)label);
    setupGraphicMode();
  }
}

