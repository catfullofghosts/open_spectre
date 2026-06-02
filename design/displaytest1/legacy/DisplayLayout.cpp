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
          textColor = 0xC618;  // Active: light grey text
        } else {
          bgColor = 0xC618;  // Inactive: light grey background
          textColor = Orange_Coral;  // Inactive: orange text
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
  
  // Redraw the top bar section for this tab (since we cleared it)
  // The top bar spans the full width, so we need to redraw it
  drawTopBar(Green_Olive_Dark);
}

void DisplayLayout::clearMiddleSection() {
  setupGraphicMode();
  ER5517.Foreground_color_65k(0x0000);  // Black
  ER5517.Line_Start_XY(GRID_START_X, MIDDLE_SECTION_Y);
  ER5517.Line_End_XY(GRID_END_X, MIDDLE_SECTION_Y + MIDDLE_SECTION_HEIGHT - 1);
  ER5517.Start_Square_Fill();
}

void DisplayLayout::clearBottomSection() {
  setupGraphicMode();
  ER5517.Foreground_color_65k(0x0000);  // Black
  ER5517.Line_Start_XY(GRID_START_X, BOTTOM_SECTION_Y);
  ER5517.Line_End_XY(GRID_END_X, BOTTOM_SECTION_Y + BOTTOM_SECTION_HEIGHT - 1);
  ER5517.Start_Square_Fill();
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

