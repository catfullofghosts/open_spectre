# Serial Communication GUI Application

A cross-platform Python GUI application for serial communication with USB devices, featuring buttons, sliders, and a flexible grid interface.

## Features

- **Serial Communication**: Connect to USB serial ports with selectable baud rates
- **Manual Message Sending**: Send custom messages through the serial connection
- **Action Buttons**: Pre-configured buttons for common commands (Start, Stop, Reset, etc.)
- **Sliders**: Three sliders (0-255 range) with individual send buttons
- **Flexible Grid**: Configurable grid of buttons with named rows and columns
- **Real-time Data Display**: View received serial data in real-time
- **Cross-platform**: Works on Windows, macOS, and Linux

## Installation

1. **Install Python Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Run the Application**:
   ```bash
   python serial_gui_app.py
   ```

## Usage

### Serial Connection
1. Select your USB serial port from the dropdown menu
2. Choose the appropriate baud rate (default: 115200)
3. Click "Connect" to establish the connection
4. Use "Refresh" to update the list of available ports

### Manual Messages
- Type your message in the "Manual Message" text field
- Press Enter or click "Send" to transmit the message

### Action Buttons
- Click any of the action buttons (Start, Stop, Reset, Status, Config, Test) to send predefined commands
- Each button sends a specific command string over serial

### Sliders
- Adjust the three sliders to set values (0-255)
- Click the corresponding "Send S1", "Send S2", or "Send S3" button to transmit the slider value
- Slider values are sent in the format: `S1:value`, `S2:value`, `S3:value`

### Flexible Grid
- Set the number of rows and columns using the spin boxes
- Click "Create Grid" to generate a new grid layout
- Grid buttons are labeled as "R1C1", "R2C1", etc. (Row X, Column Y)
- Click any grid button to send a command in the format: `GRID:row,column`
- Use "Clear Grid" to remove all grid buttons

### Received Data
- All received serial data is displayed in the "Received Data" area
- Use the "Clear" button to clear the received data display

## Message Formats

The application sends the following message formats over serial:

- **Manual messages**: Raw text as entered
- **Action buttons**: `START`, `STOP`, `RESET`, `STATUS`, `CONFIG`, `TEST`
- **Slider values**: `S1:value`, `S2:value`, `S3:value` (where value is 0-255)
- **Grid buttons**: `GRID:row,column` (where row and column are 1-based indices)

All messages are automatically terminated with a newline character (`\n`).

## Requirements

- Python 3.7 or higher
- PySide6 (Qt6 bindings for Python)
- pyserial (serial communication library)

## Troubleshooting

### No Serial Ports Detected
- Ensure your USB device is properly connected
- Check if the device requires drivers to be installed
- Try refreshing the port list

### Connection Failed
- Verify the port is not being used by another application
- Check if the baud rate matches your device's configuration
- Ensure you have permission to access the serial port

### Cross-platform Notes
- **Windows**: Serial ports are typically named `COM1`, `COM2`, etc.
- **macOS**: Serial ports are typically named `/dev/tty.usbserial-*`
- **Linux**: Serial ports are typically named `/dev/ttyUSB*` or `/dev/ttyACM*`

## Customization

You can easily modify the application by editing the source code:

- Add more action buttons by modifying the `action_buttons` list
- Change slider ranges by modifying the `setRange()` calls
- Customize message formats in the send functions
- Modify the UI layout in the `init_ui()` method

## License

This project is open source and available under the MIT License. 