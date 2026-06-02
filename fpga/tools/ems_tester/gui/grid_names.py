# Grid Names Configuration
# Customize the names for rows and columns in your digital matrix

# Row names - map row numbers to custom names
ROW_NAMES = {
    # Example: map row numbers to custom names
    0: "A1", 1: "A2", 2: "A3", 3: "A4", 4: "A5",
    5: "B1", 6: "B2", 7: "B3", 8: "B4", 9: "B5",
    10: "C1", 11: "C2", 12: "C3", 13: "C4", 14: "C5",
    # Add more as needed, or use a pattern
    # You can add up to 53 rows (0-52)
}

# Column names - map column numbers to custom names
COL_NAMES = {
    # Example: map column numbers to custom names
    0: "X1", 1: "X2", 2: "X3", 3: "X4", 4: "X5",
    5: "Y1", 6: "Y2", 7: "Y3", 8: "Y4", 9: "Y5",
    10: "Z1", 11: "Z2", 12: "Z3", 13: "Z4", 14: "Z5",
    # Add more as needed, or use a pattern
    # You can add up to 52 columns (0-51)
}

# Example configurations you can use:

# For a sensor grid:
# ROW_NAMES = {
#     0: "Temp_Sensor", 1: "Humidity_Sensor", 2: "Pressure_Sensor",
#     3: "Light_Sensor", 4: "Motion_Sensor", 5: "Sound_Sensor"
# }
# COL_NAMES = {
#     0: "Zone_1", 1: "Zone_2", 2: "Zone_3", 3: "Zone_4",
#     4: "Zone_5", 5: "Zone_6", 6: "Zone_7", 7: "Zone_8"
# }

# For a control panel:
# ROW_NAMES = {
#     0: "Power", 1: "Mode", 2: "Speed", 3: "Direction",
#     4: "Volume", 5: "Brightness", 6: "Temperature", 7: "Fan"
# }
# COL_NAMES = {
#     0: "On", 1: "Off", 2: "Auto", 3: "Manual",
#     4: "High", 5: "Medium", 6: "Low", 7: "Emergency"
# }

# For a LED matrix:
# ROW_NAMES = {i: f"LED_Row_{i+1}" for i in range(53)}
# COL_NAMES = {i: f"LED_Col_{i+1}" for i in range(52)} 