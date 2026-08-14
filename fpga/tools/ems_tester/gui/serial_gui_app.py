import sys
import os
# Add parent directory to path to import ems_tester_xsdb
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from PySide6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                               QHBoxLayout, QGridLayout, QPushButton, QSlider, 
                               QLabel, QComboBox, QTextEdit, QLineEdit, QSpinBox,
                               QGroupBox, QMessageBox, QScrollArea, QToolTip, QDialog, QDialogButtonBox)
from PySide6.QtCore import Qt, QTimer, Signal, QThread, QPoint
from PySide6.QtGui import QFont, QTransform, QPainter, QCursor

# Import XSDB backend
from core import Xsct
import ems_tester_xsdb
from ems_tester_xsdb import (MATRIX_IN_MAP, MATRIX_OUT_MAP, 
                             resolve_matrix_in, resolve_matrix_out,
                             prog_digital_side_matrix, rst_digital_side_matrix)

# Create reverse mappings for getting names from indices
ROW_NAMES = {}  # Maps index -> name for matrix inputs
COL_NAMES = {}  # Maps index -> name for matrix outputs

# Build reverse mapping for inputs (rows)
for name, index in MATRIX_IN_MAP.items():
    ROW_NAMES[index] = name

# Build reverse mapping for outputs (columns)
for name, index in MATRIX_OUT_MAP.items():
    COL_NAMES[index] = name


class VerticalLabel(QLabel):
    """Custom QLabel for vertical text display"""
    def __init__(self, text, parent=None):
        super().__init__(text, parent)
        self.setAlignment(Qt.AlignCenter)
        
    def paintEvent(self, event):
        painter = QPainter(self)
        painter.save()
        
        # Set up the painter
        painter.setPen(self.palette().color(self.foregroundRole()))
        painter.setFont(self.font())
        
        # Calculate center point
        center_x = self.width() / 2
        center_y = self.height() / 2
        
        # Rotate 90 degrees around the center
        painter.translate(center_x, center_y)
        painter.rotate(90)
        painter.translate(-center_x, -center_y)
        
        # Draw the text
        rect = self.rect()
        painter.drawText(rect, Qt.AlignCenter, self.text())
        
        painter.restore()


class CustomToolTip(QLabel):
    """Custom tooltip widget that appears next to the cursor"""
    def __init__(self, text, parent=None):
        super().__init__(text, parent)
        self.setStyleSheet("""
            QLabel {
                background-color: #000000;
                color: #ffffff;
                border: 2px solid #666666;
                border-radius: 6px;
                padding: 8px 10px;
                font-weight: bold;
                font-size: 12px;
                font-family: 'Segoe UI', Arial, sans-serif;
            }
        """)
        self.setWindowFlags(Qt.ToolTip | Qt.FramelessWindowHint)
        # Remove translucent background to ensure solid background
        self.setAutoFillBackground(True)
        
    def showAtCursor(self, text):
        """Show tooltip at current cursor position"""
        self.setText(text)
        self.adjustSize()
        
        # Get cursor position
        cursor_pos = QCursor.pos()
        
        # Position tooltip to the right and slightly below cursor
        tooltip_x = cursor_pos.x() + 15
        tooltip_y = cursor_pos.y() + 15
        
        # Ensure tooltip doesn't go off screen
        screen_geometry = QApplication.primaryScreen().geometry()
        if tooltip_x + self.width() > screen_geometry.right():
            tooltip_x = cursor_pos.x() - self.width() - 5
        if tooltip_y + self.height() > screen_geometry.bottom():
            tooltip_y = cursor_pos.y() - self.height() - 5
            
        self.move(tooltip_x, tooltip_y)
        self.show()


class TargetSelectionDialog(QDialog):
    """Dialog for selecting XSDB target"""
    def __init__(self, targets_list, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Select XSDB Target")
        self.setModal(True)
        
        layout = QVBoxLayout(self)
        layout.addWidget(QLabel("Select the target to use:"))
        
        self.target_combo = QComboBox()
        self.target_combo.addItems(targets_list)
        layout.addWidget(self.target_combo)
        
        buttons = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)
        
    def get_selected_target(self):
        return self.target_combo.currentIndex()


class SerialGUIApp(QMainWindow):
    # Grid configuration - matrix inputs (rows) and outputs (columns)
    GRID_ROWS = 64  # matrix_in: 0-63
    GRID_COLS = 57  # matrix_out: 0-56
    
    # # Visible area configuration - control how many rows/columns are visible before scrolling
    # VISIBLE_ROWS = 15  # Number of rows visible in the scroll area
    # VISIBLE_COLS = 20  # Number of columns visible in the scroll area
    
    def __init__(self):
        super().__init__()
        self.xsct = None
        self.grid_buttons = {}  # Store grid buttons
        self.grid_states = {}  # Store button toggle states
        self.output_connections = {}  # Track multiple inputs per output: {col: set([row1, row2, ...])}
        self.tooltip = CustomToolTip("")  # Custom tooltip for hover info
        self.connected = False
        self.init_ui()
        
    def init_ui(self):
        self.setWindowTitle("EMS Tester XSDB GUI")
        self.setGeometry(100, 100, 800, 500)
        
        # Main widget and layout
        main_widget = QWidget()
        self.setCentralWidget(main_widget)
        main_layout = QHBoxLayout(main_widget)
        
        # Left panel for XSDB controls and communication
        left_panel = QWidget()
        left_panel.setMaximumWidth(300)  # Limit left panel width
        left_layout = QVBoxLayout(left_panel)
        
        # XSDB connection group
        xsdb_group = QGroupBox("XSDB Connection")
        xsdb_layout = QVBoxLayout(xsdb_group)
        
        # Host selection
        host_layout = QHBoxLayout()
        host_layout.addWidget(QLabel("Host:"))
        self.host_input = QLineEdit("localhost")
        host_layout.addWidget(self.host_input)
        xsdb_layout.addLayout(host_layout)
        
        # Port selection
        port_layout = QHBoxLayout()
        port_layout.addWidget(QLabel("Port:"))
        self.port_input = QLineEdit("3010")
        port_layout.addWidget(self.port_input)
        xsdb_layout.addLayout(port_layout)
        
        # Connect/Disconnect button
        self.connect_btn = QPushButton("Connect")
        self.connect_btn.clicked.connect(self.toggle_connection)
        xsdb_layout.addWidget(self.connect_btn)
        
        # Connection status
        self.status_label = QLabel("Not connected")
        self.status_label.setStyleSheet("color: red; font-weight: bold;")
        xsdb_layout.addWidget(self.status_label)
        
        left_layout.addWidget(xsdb_group)
        
        # Manual register write
        register_group = QGroupBox("Manual Register Write")
        register_layout = QVBoxLayout(register_group)
        
        addr_layout = QHBoxLayout()
        addr_layout.addWidget(QLabel("Addr:"))
        self.addr_input = QLineEdit()
        self.addr_input.setPlaceholderText("0x40000000")
        addr_layout.addWidget(self.addr_input)
        register_layout.addLayout(addr_layout)
        
        val_layout = QHBoxLayout()
        val_layout.addWidget(QLabel("Value:"))
        self.val_input = QLineEdit()
        self.val_input.setPlaceholderText("0x0")
        val_layout.addWidget(self.val_input)
        register_layout.addLayout(val_layout)
        
        send_btn = QPushButton("Write Register")
        send_btn.clicked.connect(self.write_register)
        register_layout.addWidget(send_btn)
        
        left_layout.addWidget(register_group)
        
        # Manual register read
        read_register_group = QGroupBox("Manual Register Read")
        read_register_layout = QVBoxLayout(read_register_group)
        
        read_addr_layout = QHBoxLayout()
        read_addr_layout.addWidget(QLabel("Addr:"))
        self.read_addr_input = QLineEdit()
        self.read_addr_input.setPlaceholderText("0x40000000")
        read_addr_layout.addWidget(self.read_addr_input)
        read_register_layout.addLayout(read_addr_layout)
        
        read_btn = QPushButton("Read Register")
        read_btn.clicked.connect(self.read_register)
        read_register_layout.addWidget(read_btn)
        
        # Display area for read value
        read_value_layout = QHBoxLayout()
        read_value_layout.addWidget(QLabel("Value:"))
        self.read_value_label = QLabel("--")
        self.read_value_label.setStyleSheet("""
            QLabel {
                background-color: #f0f0f0;
                border: 1px solid #cccccc;
                padding: 5px;
                border-radius: 3px;
                font-family: 'Courier New', monospace;
                font-weight: bold;
                color: #000000;
            }
        """)
        read_value_layout.addWidget(self.read_value_label)
        read_register_layout.addLayout(read_value_layout)
        
        left_layout.addWidget(read_register_group)
        
        # Log display
        log_group = QGroupBox("Log")
        log_layout = QVBoxLayout(log_group)
        
        self.log_text = QTextEdit()
        self.log_text.setMaximumHeight(150)
        self.log_text.setReadOnly(True)
        log_layout.addWidget(self.log_text)
        
        clear_btn = QPushButton("Clear")
        clear_btn.clicked.connect(self.log_text.clear)
        log_layout.addWidget(clear_btn)
        
        left_layout.addWidget(log_group)
        
        # Add left panel to main layout
        main_layout.addWidget(left_panel, 1)
        
        # Right panel for flexible grid
        right_panel = QWidget()
        right_layout = QVBoxLayout(right_panel)
        
        # Grid controls
        grid_controls = QGroupBox(f"{self.GRID_ROWS}x{self.GRID_COLS} Digital Matrix")
        grid_controls_layout = QVBoxLayout(grid_controls)
        
        # Top row with clear button and hover info display
        top_row = QHBoxLayout()
        top_row.addWidget(QLabel(f"Matrix: {self.GRID_ROWS} inputs x {self.GRID_COLS} outputs"))
        
        # Hover info display area
        self.hover_info_label = QLabel(f"Grid: {self.GRID_ROWS}x{self.GRID_COLS} buttons (hover for row/col)")
        self.hover_info_label.setStyleSheet("""
            QLabel {
                background-color: #f0f0f0;
                border: 1px solid #cccccc;
                padding: 5px;
                border-radius: 3px;
                font-weight: bold;
                color: #333333;
            }
        """)
        top_row.addWidget(self.hover_info_label)
        
        clear_grid_btn = QPushButton("Reset All")
        clear_grid_btn.clicked.connect(self.reset_all_matrix)
        top_row.addWidget(clear_grid_btn)
        grid_controls_layout.addLayout(top_row)
        

        
        right_layout.addWidget(grid_controls)
        
        # Fixed grid area (no scrolling)
        self.grid_widget = QWidget()
        self.grid_layout = QGridLayout(self.grid_widget)
        self.grid_layout.setSpacing(0)  # No spacing between buttons
        self.grid_layout.setContentsMargins(0, 0, 0, 0)  # No padding around grid
        self.grid_layout.setHorizontalSpacing(0)  # Ensure no horizontal spacing
        self.grid_layout.setVerticalSpacing(0)    # Ensure no vertical spacing
        
        # Calculate button size to fit all buttons in the available space
        # Start with a reasonable minimum size and let the layout handle the rest
        self.button_width = 15  # Very small buttons
        self.button_height = 15  # Very small buttons
        
        # Set the grid widget size to accommodate all buttons
        total_width = self.GRID_COLS * self.button_width
        total_height = self.GRID_ROWS * self.button_height
        
        self.grid_widget.setMinimumSize(total_width, total_height)
        self.grid_widget.setMaximumSize(total_width, total_height)
        
        right_layout.addWidget(self.grid_widget)
        
        # Add right panel to main layout
        main_layout.addWidget(right_panel, 2)
        
        # Create initial grid
        self.create_grid()
        
    def toggle_connection(self):
        """Connect or disconnect from XSDB"""
        if not self.connected:
            self.connect_xsdb()
        else:
            self.disconnect_xsdb()
            
    def connect_xsdb(self):
        """Connect to XSDB and select target"""
        try:
            host = self.host_input.text() or "localhost"
            port = int(self.port_input.text() or "3010")
            
            self.log_text.append(f"Connecting to XSDB at {host}:{port}...")
            QApplication.processEvents()
            
            self.xsct = Xsct(host, port)
            self.log_text.append(f"Connected. XSCT PID: {self.xsct.do('pid')}")
            
            # Connect to target
            self.xsct.do("connect")
            self.log_text.append("Connected to target")
            
            # Get available targets
            targets_output = self.xsct.do("targets")
            # Handle both \n and \\n (escaped) newlines
            targets_list = []
            for line in targets_output.replace('\\n', '\n').split('\n'):
                line = line.strip()
                if line:
                    targets_list.append(line)
            
            if not targets_list:
                self.log_text.append("No targets found, using default target")
            else:
                # Show target selection dialog
                dialog = TargetSelectionDialog(targets_list, self)
                if dialog.exec() == QDialog.Accepted:
                    target_index = dialog.get_selected_target()
                    if target_index >= 0 and target_index < len(targets_list):
                        self.xsct.do(f"target {target_index}")
                        try:
                            target_info = self.xsct.do(f"target -index {target_index}")
                            self.log_text.append(f"Selected target: {target_info}")
                        except:
                            self.log_text.append(f"Selected target index {target_index}")
                    else:
                        self.log_text.append("No target selected, using default")
                else:
                    self.log_text.append("Target selection cancelled, using default")
            
            # Set xsct instance for matrix functions to use
            ems_tester_xsdb.xsct = self.xsct
            
            self.connected = True
            self.connect_btn.setText("Disconnect")
            self.host_input.setEnabled(False)
            self.port_input.setEnabled(False)
            self.status_label.setText("Connected")
            self.status_label.setStyleSheet("color: green; font-weight: bold;")
            
            # Reset matrix on connect
            self.log_text.append("Resetting digital matrix...")
            QApplication.processEvents()
            rst_digital_side_matrix()
            self.log_text.append("Matrix reset complete")
            
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to connect: {str(e)}")
            self.log_text.append(f"Connection error: {str(e)}")
            if self.xsct:
                try:
                    self.xsct.close()
                except:
                    pass
                self.xsct = None
            
    def disconnect_xsdb(self):
        """Disconnect from XSDB"""
        if self.xsct:
            try:
                self.xsct.close()
            except Exception as e:
                self.log_text.append(f"Error closing connection: {str(e)}")
            
        # Clear xsct reference in ems_tester_xsdb module
        if hasattr(ems_tester_xsdb, 'xsct'):
            ems_tester_xsdb.xsct = None
            
        self.xsct = None
        self.connected = False
        
        self.connect_btn.setText("Connect")
        self.host_input.setEnabled(True)
        self.port_input.setEnabled(True)
        self.status_label.setText("Not connected")
        self.status_label.setStyleSheet("color: red; font-weight: bold;")
        
        self.log_text.append("Disconnected from XSDB")
        
    def write_register(self):
        """Write to a register manually"""
        if not self.connected or not self.xsct:
            QMessageBox.warning(self, "Warning", "Not connected to XSDB")
            return
            
        try:
            addr = self.addr_input.text().strip()
            val = self.val_input.text().strip()
            
            if not addr or not val:
                QMessageBox.warning(self, "Warning", "Please enter address and value")
                return
            
            # Convert to hex if needed
            if not addr.startswith('0x'):
                addr = f"0x{addr}"
            if not val.startswith('0x'):
                val = f"0x{val}"
            
            command = f"mwr -force {addr} {val}"
            self.xsct.do(command)
            self.log_text.append(f"Wrote {val} to {addr}")
            
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to write register: {str(e)}")
            self.log_text.append(f"Register write error: {str(e)}")
    
    def read_register(self):
        """Read from a register manually"""
        if not self.connected or not self.xsct:
            QMessageBox.warning(self, "Warning", "Not connected to XSDB")
            return
            
        try:
            addr = self.read_addr_input.text().strip()
            
            if not addr:
                QMessageBox.warning(self, "Warning", "Please enter address")
                return
            
            # Convert to hex if needed
            if not addr.startswith('0x'):
                addr = f"0x{addr}"
            
            # Read register using XSCT mrd command
            command = f"mrd {addr}"
            result = self.xsct.do(command)
            
            # Parse the result - mrd typically returns something like "0x40000000: 0x00000000"
            # Extract the value part
            value = result.strip()
            if ':' in value:
                # Format: "0x40000000: 0x00000000"
                parts = value.split(':')
                if len(parts) > 1:
                    value = parts[1].strip()
            
            self.read_value_label.setText(value)
            self.log_text.append(f"Read {addr}: {value}")
            
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to read register: {str(e)}")
            self.log_text.append(f"Register read error: {str(e)}")
            self.read_value_label.setText("Error")
        
    def get_row_block_index(self, row):
        """Get the block index for a row to determine alternating pattern"""
        # Define input blocks based on MATRIX_IN_MAP structure
        if 0 <= row <= 17:  # xy_inv_out
            return 0
        elif 18 <= row <= 23:  # slow_cnt
            return 1
        elif 24 <= row <= 27:  # overlay_gate_out
            return 2
        elif 28 <= row <= 31:  # inv_out
            return 3
        elif 32 <= row <= 35:  # edge_detector_out
            return 4
        elif 36 <= row <= 38:  # delay_out, ff_out
            return 5
        elif 39 <= row <= 40:  # shapes1
            return 6
        elif 41 <= row <= 42:  # shapes2
            return 7
        elif 43 <= row <= 49:  # comp_output
            return 8
        elif row == 50:  # gnd
            return 9
        elif 51 <= row <= 52:  # osc
            return 10
        elif 53 <= row <= 54:  # random
            return 11
        elif 55 <= row <= 56:  # audio
            return 12
        elif row == 57:  # ca_out
            return 13
        elif 58 <= row <= 62:  # gap
            return 14
        elif row == 63:  # vcc
            return 15
        return 0
    
    def get_col_block_index(self, col):
        """Get the block index for a column to determine alternating pattern"""
        # Define output blocks based on MATRIX_OUT_MAP structure
        if 0 <= col <= 17:  # xy_inv_in
            return 0
        elif 18 <= col <= 25:  # overlay_gate
            return 1
        elif 26 <= col <= 29:  # inv_in
            return 2
        elif 30 <= col <= 33:  # edge_detector_in, delay_in, ff_in
            return 3
        elif 34 <= col <= 35:  # acm_out
            return 4
        elif 36 <= col <= 39:  # luma_in1
            return 5
        elif 40 <= col <= 45:  # chroma_mux_in1
            return 6
        elif 46 <= col <= 49:  # luma_in2
            return 7
        elif 50 <= col <= 55:  # chroma_mux_in2
            return 8
        elif col == 56:  # chrom_swap
            return 9
        return 0
    
    def get_column_color(self, col, row=None):
        """Get the base background color for a column, optionally darkened by row block"""
        # Luma columns: darker blue for better visibility
        if 36 <= col <= 39 or 46 <= col <= 49:  # luma_in1, luma_in2
            base_color = "#8DC8D6"  # Darker blue
            # Darken further if row block is specified (for horizontal tracking)
            if row is not None:
                row_block = self.get_row_block_index(row)
                # Darken based on row block to show horizontal intersections
                if row_block % 2 == 1:  # Alternate row blocks darken
                    return "#6BA8B6"  # Even darker blue
            return base_color
        
        # Chroma columns: alternating darker pink and darker green
        elif 40 <= col <= 45:  # chroma_mux_in1
            # Alternate within the block
            if (col - 40) % 2 == 0:
                base_color = "#E0A6B1"  # Darker pink
                if row is not None:
                    row_block = self.get_row_block_index(row)
                    if row_block % 2 == 1:  # Alternate row blocks darken
                        return "#C08691"  # Even darker pink
            else:
                base_color = "#80DE80"  # Darker green
                if row is not None:
                    row_block = self.get_row_block_index(row)
                    if row_block % 2 == 1:  # Alternate row blocks darken
                        return "#60BE70"  # Even darker green
            return base_color
        elif 50 <= col <= 55:  # chroma_mux_in2
            # Alternate within the block
            if (col - 50) % 2 == 0:
                base_color = "#E0A6B1"  # Darker pink
                if row is not None:
                    row_block = self.get_row_block_index(row)
                    if row_block % 2 == 1:  # Alternate row blocks darken
                        return "#C08691"  # Even darker pink
            else:
                base_color = "#80DE80"  # Darker green
                if row is not None:
                    row_block = self.get_row_block_index(row)
                    if row_block % 2 == 1:  # Alternate row blocks darken
                        return "#60BE70"  # Even darker green
            return base_color
        
        # Default: white or light grey based on block
        return None
    
    def create_grid(self):
        """Create a grid of toggle buttons with hover info display"""
        self.clear_grid()
        
        # Create grid of toggle buttons (no headers)
        for row in range(self.GRID_ROWS):
            for col in range(self.GRID_COLS):
                btn = QPushButton("")  # Empty text
                btn.setCheckable(True)  # Make it a toggle button
                btn.setMinimumSize(self.button_width, self.button_height)
                btn.setMaximumSize(self.button_width, self.button_height)
                
                # Determine base background color (pass row to darken luma/chroma intersections)
                base_color = self.get_column_color(col, row)
                
                # If no special column color, alternate by block for easier tracking
                if base_color is None:
                    row_block = self.get_row_block_index(row)
                    col_block = self.get_col_block_index(col)
                    # Alternate white/light grey based on block combination
                    # This creates a checkerboard pattern that helps track position
                    if (row_block + col_block) % 2 == 0:
                        base_color = "#FFFFFF"  # White
                    else:
                        base_color = "#E0E0E0"  # Light grey
                
                # Create stylesheet with dynamic colors
                stylesheet = f"""
                    QPushButton {{
                        border: 1px solid #666666;
                        background-color: {base_color};
                        margin: 0px;
                        padding: 0px;
                        border-radius: 0px;
                    }}
                    QPushButton:hover {{
                        background-color: #e6e6e6;
                        border: 1px solid #333333;
                    }}
                    QPushButton:checked {{
                        background-color: #4CAF50;
                        border: 1px solid #45a049;
                    }}
                    QPushButton:checked:hover {{
                        background-color: #45a049;
                    }}
                """
                btn.setStyleSheet(stylesheet)
                btn.clicked.connect(lambda checked, r=row, c=col: self.toggle_grid_button(r, c))
                
                # Add hover events
                btn.enterEvent = lambda event, r=row, c=col: self.on_button_hover_enter(r, c)
                btn.leaveEvent = lambda event: self.on_button_hover_leave()
                
                self.grid_layout.addWidget(btn, row, col)  # No offset needed since no headers
                self.grid_buttons[(row, col)] = btn
                self.grid_states[(row, col)] = False  # Initialize as not activated
                
    def clear_grid(self):
        """Clear the grid of buttons and headers"""
        # Remove all widgets from grid layout
        while self.grid_layout.count():
            child = self.grid_layout.takeAt(0)
            if child.widget():
                child.widget().deleteLater()
        
        self.grid_buttons.clear()
        self.grid_states.clear()
        
    def reset_all_matrix(self):
        """Reset all matrix connections"""
        if not self.connected or not self.xsct:
            QMessageBox.warning(self, "Warning", "Not connected to XSDB")
            return
            
        try:
            self.log_text.append("Resetting all matrix connections...")
            QApplication.processEvents()
            
            # Reset all matrix outputs
            rst_digital_side_matrix()
            
            # Clear all button states
            for (row, col), btn in self.grid_buttons.items():
                if btn.isChecked():
                    btn.setChecked(False)
                    self.grid_states[(row, col)] = False
            
            # Clear connection tracking
            self.output_connections.clear()
            
            self.log_text.append("Matrix reset complete")
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to reset matrix: {str(e)}")
            self.log_text.append(f"Reset error: {str(e)}")
        


        
    def get_row_name(self, row):
        """Get the custom name for a row (matrix input), or return the row number if no custom name"""
        return ROW_NAMES.get(row, f"in_{row}")
    
    def get_col_name(self, col):
        """Get the custom name for a column (matrix output), or return the column number if no custom name"""
        return COL_NAMES.get(col, f"out_{col}")
    
    def on_button_hover_enter(self, row, col):
        """Handle button hover enter event"""
        row_name = self.get_row_name(row)
        col_name = self.get_col_name(col)
        self.hover_info_label.setText(f"{row_name}, {col_name}")
        # Show custom tooltip next to cursor
        self.tooltip.showAtCursor(f"{row_name}, {col_name}")
        
    def on_button_hover_leave(self):
        """Handle button hover leave event"""
        # Show total grid size when not hovering
        self.hover_info_label.setText(f"Grid: {self.GRID_ROWS}x{self.GRID_COLS} buttons (hover for row/col)")
        # Hide custom tooltip
        self.tooltip.hide()
        
    def toggle_grid_button(self, row, col):
        """Handle toggle button press in grid - row is matrix_in, col is matrix_out"""
        btn = self.grid_buttons[(row, col)]
        is_checked = btn.isChecked()
        self.grid_states[(row, col)] = is_checked
        
        if not self.connected or not self.xsct:
            status = "ON" if is_checked else "OFF"
            row_name = self.get_row_name(row)
            col_name = self.get_col_name(col)
            self.log_text.append(f"Button {status}: {row_name} -> {col_name} (not connected)")
            return
        
        try:
            row_name = self.get_row_name(row)
            col_name = self.get_col_name(col)
            
            # Initialize output connections set if needed
            if col not in self.output_connections:
                self.output_connections[col] = set()
            
            if is_checked:
                # Add this input to the output's connection set
                self.output_connections[col].add(row)
                
                # Get all active inputs for this output and pass as list
                active_inputs = list(self.output_connections[col])
                
                # Program matrix: connect matrix_out (col) to multiple matrix_in (rows)
                # The function will OR all the inputs together
                prog_digital_side_matrix(col, active_inputs)
                
                if len(active_inputs) > 1:
                    input_names = [self.get_row_name(r) for r in active_inputs]
                    self.log_text.append(f"Connected: {', '.join(input_names)} -> {col_name} (OR'd)")
                else:
                    self.log_text.append(f"Connected: {row_name} -> {col_name}")
            else:
                # Remove this input from the output's connection set
                self.output_connections[col].discard(row)
                
                # Get remaining active inputs for this output
                active_inputs = list(self.output_connections[col])
                
                if len(active_inputs) > 0:
                    # Still have other inputs connected, update with remaining inputs
                    prog_digital_side_matrix(col, active_inputs)
                    input_names = [self.get_row_name(r) for r in active_inputs]
                    self.log_text.append(f"Disconnected {row_name}, remaining: {', '.join(input_names)} -> {col_name}")
                else:
                    # No more inputs, reset the output
                    rst_digital_side_matrix(col)
                    self.log_text.append(f"Disconnected: {col_name} (all inputs removed)")
                    # Clean up empty set
                    del self.output_connections[col]
                
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to program matrix: {str(e)}")
            self.log_text.append(f"Matrix error: {str(e)}")
            # Revert button state on error
            btn.setChecked(not is_checked)
            self.grid_states[(row, col)] = not is_checked
            # Revert connection tracking
            if is_checked:
                self.output_connections[col].discard(row)
                if len(self.output_connections.get(col, set())) == 0:
                    self.output_connections.pop(col, None)
            else:
                if col not in self.output_connections:
                    self.output_connections[col] = set()
                self.output_connections[col].add(row)
                
    def closeEvent(self, event):
        """Handle application close event"""
        self.disconnect_xsdb()
        self.tooltip.hide()  # Hide tooltip when closing
        event.accept()


def main():
    app = QApplication(sys.argv)
    app.setStyle('Fusion')  # Use Fusion style for better cross-platform appearance
    
    # Set application font
    font = QFont("Segoe UI", 9)
    app.setFont(font)
    
    window = SerialGUIApp()
    window.show()
    
    sys.exit(app.exec())


if __name__ == "__main__":
    main() 