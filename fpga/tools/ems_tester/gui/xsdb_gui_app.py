import sys
import os
# Add parent directory to path to import ems_tester_xsdb
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from PySide6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                               QHBoxLayout, QGridLayout, QPushButton, QSlider, 
                               QLabel, QComboBox, QTextEdit, QLineEdit, QSpinBox,
                               QGroupBox, QMessageBox, QScrollArea, QToolTip, QDialog, 
                               QDialogButtonBox, QTabWidget)
from PySide6.QtCore import Qt, QTimer, Signal, QThread, QPoint, QObject, QEvent
from PySide6.QtGui import QFont, QTransform, QPainter, QCursor, QKeyEvent

# Import XSDB backend
from core import Xsct
import ems_tester_xsdb
from ems_tester_xsdb import (MATRIX_IN_MAP, MATRIX_OUT_MAP, 
                             resolve_matrix_in, resolve_matrix_out,
                             prog_digital_side_matrix, rst_digital_side_matrix,
                             prog_annaloge_side_matrix, rst_annaloge_side_matrix)

# Create reverse mappings for getting names from indices
ROW_NAMES = {}  # Maps index -> name for matrix inputs
COL_NAMES = {}  # Maps index -> name for matrix outputs

# Build reverse mapping for inputs (rows)
for name, index in MATRIX_IN_MAP.items():
    ROW_NAMES[index] = name

# Build reverse mapping for outputs (columns)
for name, index in MATRIX_OUT_MAP.items():
    COL_NAMES[index] = name

# Analog matrix mappings from analog_side.vhd
# mixer_inputs: array_12(15 downto 0) - 11 inputs used (0-10)
ANALOG_IN_NAMES = {
    0: "osc1_sq",
    1: "osc1_sin",
    2: "osc2_sq",
    3: "osc2_sin",
    4: "noise_1",
    5: "noise_2",
    6: "audio_in_t",
    7: "audio_in_b",
    8: "audio_in_sig",
    9: "dsm_hi",
    10: "dsm_lo"
}

# outputs: array_12(19 downto 0) - 20 outputs
ANALOG_OUT_NAMES = {
    0: "pos_h_1",
    1: "pos_v_1",
    2: "zoom_h_1",
    3: "zoom_v_1",
    4: "circle_1",
    5: "gear_1",
    6: "lantern_1",
    7: "unused_7",
    8: "fizz_1_pos_h_2",
    9: "pos_h_2",
    10: "pos_v_2",
    11: "zoom_h_2",
    12: "zoom_v_2",
    13: "circle_2",
    14: "gear_2",
    15: "lantern_2",
    16: "fizz_2_y_anna",
    17: "u_anna",
    18: "v_anna",
    19: "vid_span"
}


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


class MatrixGridWidget(QWidget):
    """Widget containing a matrix grid with buttons"""
    def __init__(self, rows, cols, get_row_name, get_col_name, matrix_type="digital", parent=None):
        super().__init__(parent)
        self.rows = rows
        self.cols = cols
        self.get_row_name = get_row_name
        self.get_col_name = get_col_name
        self.matrix_type = matrix_type
        self.grid_buttons = {}
        self.grid_states = {}
        self.output_connections = {}  # Track multiple inputs per output: {col: set([row1, row2, ...])}
        self.tooltip = CustomToolTip("")
        self.button_width = 15
        self.button_height = 15
        
        self.init_ui()
        
    def init_ui(self):
        layout = QVBoxLayout(self)
        
        # Grid controls
        grid_controls = QGroupBox(f"{self.rows}x{self.cols} {self.matrix_type.capitalize()} Matrix")
        grid_controls_layout = QVBoxLayout(grid_controls)
        
        # Top row with info display and clear button
        top_row = QHBoxLayout()
        top_row.addWidget(QLabel(f"Matrix: {self.rows} inputs x {self.cols} outputs"))
        
        # Hover info display area
        self.hover_info_label = QLabel(f"Grid: {self.rows}x{self.cols} buttons (hover for row/col)")
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
        
        layout.addWidget(grid_controls)
        
        # Grid area
        self.grid_widget = QWidget()
        self.grid_layout = QGridLayout(self.grid_widget)
        self.grid_layout.setSpacing(0)
        self.grid_layout.setContentsMargins(0, 0, 0, 0)
        self.grid_layout.setHorizontalSpacing(0)
        self.grid_layout.setVerticalSpacing(0)
        
        # Set the grid widget size
        total_width = self.cols * self.button_width
        total_height = self.rows * self.button_height
        
        self.grid_widget.setMinimumSize(total_width, total_height)
        self.grid_widget.setMaximumSize(total_width, total_height)
        
        layout.addWidget(self.grid_widget)
        
        # Create initial grid
        self.create_grid()
        
    def get_row_block_index(self, row):
        """Get the block index for a row to determine alternating pattern"""
        if self.matrix_type == "digital":
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
            elif 58 <= row <= 62:  # spare
                return 14
            elif row == 63:  # vcc
                return 15
        else:  # analog
            # Simple grouping for analog inputs
            if row <= 2:
                return 0
            elif row <= 5:
                return 1
            elif row <= 8:
                return 2
            else:
                return 3
        return 0
    
    def get_col_block_index(self, col):
        """Get the block index for a column to determine alternating pattern"""
        if self.matrix_type == "digital":
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
        else:  # analog
            # Simple grouping for analog outputs
            if col <= 5:
                return 0
            elif col <= 11:
                return 1
            else:
                return 2
        return 0
    
    def get_column_color(self, col, row=None):
        """Get the base background color for a column, optionally darkened by row block"""
        if self.matrix_type == "digital":
            # Luma columns: darker blue for better visibility
            if 36 <= col <= 39 or 46 <= col <= 49:  # luma_in1, luma_in2
                base_color = "#8DC8D6"  # Darker blue
                if row is not None:
                    row_block = self.get_row_block_index(row)
                    if row_block % 2 == 1:
                        return "#6BA8B6"  # Even darker blue
                return base_color
            
            # Chroma columns: alternating darker pink and darker green
            elif 40 <= col <= 45:  # chroma_mux_in1
                if (col - 40) % 2 == 0:
                    base_color = "#E0A6B1"  # Darker pink
                    if row is not None:
                        row_block = self.get_row_block_index(row)
                        if row_block % 2 == 1:
                            return "#C08691"  # Even darker pink
                else:
                    base_color = "#80DE80"  # Darker green
                    if row is not None:
                        row_block = self.get_row_block_index(row)
                        if row_block % 2 == 1:
                            return "#60BE70"  # Even darker green
                return base_color
            elif 50 <= col <= 55:  # chroma_mux_in2
                if (col - 50) % 2 == 0:
                    base_color = "#E0A6B1"  # Darker pink
                    if row is not None:
                        row_block = self.get_row_block_index(row)
                        if row_block % 2 == 1:
                            return "#C08691"  # Even darker pink
                else:
                    base_color = "#80DE80"  # Darker green
                    if row is not None:
                        row_block = self.get_row_block_index(row)
                        if row_block % 2 == 1:
                            return "#60BE70"  # Even darker green
                return base_color
        
        # Default: white or light grey based on block
        return None
    
    def create_grid(self):
        """Create a grid of toggle buttons with hover info display"""
        self.clear_grid()
        
        # Create grid of toggle buttons
        for row in range(self.rows):
            for col in range(self.cols):
                btn = QPushButton("")
                btn.setCheckable(True)
                btn.setMinimumSize(self.button_width, self.button_height)
                btn.setMaximumSize(self.button_width, self.button_height)
                
                # Determine base background color
                base_color = self.get_column_color(col, row)
                
                # If no special column color, alternate by block
                if base_color is None:
                    row_block = self.get_row_block_index(row)
                    col_block = self.get_col_block_index(col)
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
                
                self.grid_layout.addWidget(btn, row, col)
                self.grid_buttons[(row, col)] = btn
                self.grid_states[(row, col)] = False
        
    def clear_grid(self):
        """Clear the grid of buttons"""
        while self.grid_layout.count():
            child = self.grid_layout.takeAt(0)
            if child.widget():
                child.widget().deleteLater()
        
        self.grid_buttons.clear()
        self.grid_states.clear()
        
    def reset_all_matrix(self):
        """Reset all matrix connections"""
        parent = self.parent()
        while parent and not isinstance(parent, XSDBGUIApp):
            parent = parent.parent()
        
        if not parent or not parent.connected or not parent.xsct:
            QMessageBox.warning(self, "Warning", "Not connected to XSDB")
            return
            
        try:
            parent.log_text.append(f"Resetting all {self.matrix_type} matrix connections...")
            QApplication.processEvents()
            
            # Reset all matrix outputs
            if self.matrix_type == "digital":
                rst_digital_side_matrix()
            else:  # analog
                # Reset all analog outputs (0-19)
                for out_val in range(20):
                    rst_annaloge_side_matrix(out_val)
            
            # Clear all button states
            for (row, col), btn in self.grid_buttons.items():
                if btn.isChecked():
                    btn.setChecked(False)
                    self.grid_states[(row, col)] = False
            
            # Clear connection tracking
            self.output_connections.clear()
            
            parent.log_text.append(f"{self.matrix_type.capitalize()} matrix reset complete")
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to reset matrix: {str(e)}")
            if parent:
                parent.log_text.append(f"Reset error: {str(e)}")
    
    def on_button_hover_enter(self, row, col):
        """Handle button hover enter event"""
        row_name = self.get_row_name(row)
        col_name = self.get_col_name(col)
        self.hover_info_label.setText(f"{row_name}, {col_name}")
        self.tooltip.showAtCursor(f"{row_name}, {col_name}")
        
    def on_button_hover_leave(self):
        """Handle button hover leave event"""
        self.hover_info_label.setText(f"Grid: {self.rows}x{self.cols} buttons (hover for row/col)")
        self.tooltip.hide()
        
    def toggle_grid_button(self, row, col):
        """Handle toggle button press in grid"""
        parent = self.parent()
        while parent and not isinstance(parent, XSDBGUIApp):
            parent = parent.parent()
        
        btn = self.grid_buttons[(row, col)]
        is_checked = btn.isChecked()
        self.grid_states[(row, col)] = is_checked
        
        if not parent or not parent.connected or not parent.xsct:
            status = "ON" if is_checked else "OFF"
            row_name = self.get_row_name(row)
            col_name = self.get_col_name(col)
            if parent:
                parent.log_text.append(f"Button {status}: {row_name} -> {col_name} (not connected)")
            return
        
        try:
            row_name = self.get_row_name(row)
            col_name = self.get_col_name(col)
            
            if self.matrix_type == "digital":
                # Initialize output connections set if needed
                if col not in self.output_connections:
                    self.output_connections[col] = set()
                
                if is_checked:
                    # Add this input to the output's connection set
                    self.output_connections[col].add(row)
                    
                    # Get all active inputs for this output and pass as list
                    active_inputs = list(self.output_connections[col])
                    
                    # Program matrix: connect matrix_out (col) to multiple matrix_in (rows)
                    prog_digital_side_matrix(col, active_inputs)
                    
                    if len(active_inputs) > 1:
                        input_names = [self.get_row_name(r) for r in active_inputs]
                        parent.log_text.append(f"Connected: {', '.join(input_names)} -> {col_name} (OR'd)")
                    else:
                        parent.log_text.append(f"Connected: {row_name} -> {col_name}")
                else:
                    # Remove this input from the output's connection set
                    self.output_connections[col].discard(row)
                    
                    # Get remaining active inputs for this output
                    active_inputs = list(self.output_connections[col])
                    
                    if len(active_inputs) > 0:
                        # Still have other inputs connected, update with remaining inputs
                        prog_digital_side_matrix(col, active_inputs)
                        input_names = [self.get_row_name(r) for r in active_inputs]
                        parent.log_text.append(f"Disconnected {row_name}, remaining: {', '.join(input_names)} -> {col_name}")
                    else:
                        # No more inputs, reset the output
                        rst_digital_side_matrix(col)
                        parent.log_text.append(f"Disconnected: {col_name} (all inputs removed)")
                        del self.output_connections[col]
            else:  # analog
                if is_checked:
                    # Program analog matrix
                    prog_annaloge_side_matrix(col, row)
                    parent.log_text.append(f"Connected: {row_name} -> {col_name}")
                else:
                    # Reset analog matrix output
                    rst_annaloge_side_matrix(col)
                    parent.log_text.append(f"Disconnected: {col_name}")
                    # Remove from tracking if exists
                    if col in self.output_connections:
                        self.output_connections[col].discard(row)
                        if len(self.output_connections[col]) == 0:
                            del self.output_connections[col]
                
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to program matrix: {str(e)}")
            if parent:
                parent.log_text.append(f"Matrix error: {str(e)}")
            # Revert button state on error
            btn.setChecked(not is_checked)
            self.grid_states[(row, col)] = not is_checked


class SpinBoxEnterFilter(QObject):
    """Event filter to catch Enter key presses in QSpinBox"""
    def __init__(self, callback, parent=None):
        super().__init__(parent)
        self.callback = callback
    
    def eventFilter(self, obj, event):
        if event.type() == QEvent.KeyPress:
            if event.key() == Qt.Key_Return or event.key() == Qt.Key_Enter:
                self.callback()
                return True
        return super().eventFilter(obj, event)


class RegisterControlWidget(QWidget):
    """Widget for controlling registers with sliders and number boxes"""
    SHAPE_SLIDER_MAX = 1000

    def __init__(self, parent=None):
        super().__init__(parent)
        self.registers = {}
        self.register_values = {}  # Track current value of each register address: {addr: value}
        self.init_ui()

    def _track_register(self, addr, name, bits, bit_offset, reg_widget):
        self.registers[name] = {
            'addr': addr,
            'bits': bits,
            'bit_offset': bit_offset,
            'widget': reg_widget,
        }
        if addr.startswith('0x') or addr.startswith('0X'):
            offset = addr[2:]
        else:
            offset = addr
        full_addr = f"0x400000{offset}"
        if full_addr not in self.register_values:
            self.register_values[full_addr] = 0

    def _add_section(self, scroll_layout, title, register_defs):
        section = QGroupBox(title)
        section_layout = QVBoxLayout(section)
        for reg_def in register_defs:
            addr, name, label, bits, min_val, max_val, bit_offset = reg_def
            reg_widget = self.create_register_control(
                addr, name, label, bits, min_val, max_val, bit_offset
            )
            section_layout.addWidget(reg_widget)
            self._track_register(addr, name, bits, bit_offset, reg_widget)
        scroll_layout.addWidget(section)
        
    def init_ui(self):
        layout = QVBoxLayout(self)
        
        # Scroll area for register controls
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll_widget = QWidget()
        scroll_layout = QVBoxLayout(scroll_widget)

        shape_max = self.SHAPE_SLIDER_MAX
        shape1_defs = [
            ("0x38", "pos_h_1", "Position H", 12, 0, shape_max, 0),
            ("0x3C", "pos_v_1", "Position V", 12, 0, shape_max, 0),
            ("0x40", "zoom_h_1", "Zoom H", 12, 0, shape_max, 0),
            ("0x44", "zoom_v_1", "Zoom V", 12, 0, shape_max, 0),
            ("0x48", "circle_1", "Circle", 12, 0, shape_max, 0),
            ("0x4C", "gear_1", "Gear", 12, 0, shape_max, 0),
            ("0x50", "lantern_1", "Lantern", 12, 0, shape_max, 0),
            ("0x54", "fizz_1", "Fizz", 12, 0, shape_max, 0),
            ("0xE0", "shape1_a_sel", "Shape A Select", 4, 0, 15, 0),
            ("0xE0", "shape1_b_sel", "Shape B Select", 4, 0, 15, 4),
        ]
        shape2_defs = [
            ("0x38", "pos_h_2", "Position H", 12, 0, shape_max, 16),
            ("0x3C", "pos_v_2", "Position V", 12, 0, shape_max, 16),
            ("0x40", "zoom_h_2", "Zoom H", 12, 0, shape_max, 16),
            ("0x44", "zoom_v_2", "Zoom V", 12, 0, shape_max, 16),
            ("0x48", "circle_2", "Circle", 12, 0, shape_max, 16),
            ("0x4C", "gear_2", "Gear", 12, 0, shape_max, 16),
            ("0x50", "lantern_2", "Lantern", 12, 0, shape_max, 16),
            ("0x54", "fizz_2", "Fizz", 12, 0, shape_max, 16),
            ("0xE0", "shape2_a_sel", "Shape A Select", 4, 0, 15, 8),
            ("0xE0", "shape2_b_sel", "Shape B Select", 4, 0, 15, 12),
        ]
        osc1_defs = [
            ("0x68", "osc_1_freq", "Frequency", 14, 0, 16383, 0),
            ("0x68", "osc_1_derv", "Derivative", 8, 0, 255, 16),
            ("0x68", "sync_sel_osc1", "Sync Select", 2, 0, 3, 30),
            ("0x68", "speed1", "Speed", 1, 0, 1, 28),
            ("0x70", "osc_1_pwm_duty", "PWM Duty", 9, 0, 511, 0),
            ("0x70", "osc_1_wave_sel", "Wave Select", 2, 0, 3, 10),
            ("0xCC", "osc1_alpha", "Alpha", 12, 0, 4095, 0),
        ]
        osc2_defs = [
            ("0x6C", "osc_2_freq", "Frequency", 14, 0, 16383, 0),
            ("0x6C", "osc_2_derv", "Derivative", 8, 0, 255, 16),
            ("0x6C", "sync_sel_osc2", "Sync Select", 2, 0, 3, 30),
            ("0x6C", "speed2", "Speed", 1, 0, 1, 28),
            ("0x74", "osc_2_pwm_duty", "PWM Duty", 9, 0, 511, 0),
            ("0x74", "osc_2_wave_sel", "Wave Select", 2, 0, 3, 10),
            ("0xD0", "osc2_alpha", "Alpha", 12, 0, 4095, 0),
        ]
        other_defs = [
            ("0x24", "vid_span", "Video Span", 8, 0, 255, 0),
            ("0x60", "noise_freq", "Noise Frequency", 14, 0, 16383, 0),
            ("0x60", "slew_in", "Slew In", 3, 0, 7, 17),
            ("0x60", "slowdown_sel", "Slowdown Select", 2, 0, 3, 28),
            ("0x64", "cycle_recycle", "Cycle Recycle", 1, 0, 1, 0),
            ("0x64", "noise_rst", "Noise Reset", 1, 0, 1, 1),
            ("0x58", "y_level", "Y Level", 12, 0, 4095, 0),
            ("0x58", "cr_level", "Cr Level", 12, 0, 4095, 16),
            ("0x5C", "cb_level", "Cb Level", 12, 0, 4095, 0),
            ("0x78", "video_active", "Video Active", 1, 0, 1, 0),
            ("0x78", "col_en_bypass", "Color Enable Bypass", 1, 0, 1, 1),
            ("0x78", "pix_clk_div_sel", "Pixel/Line Div Select (/2 or /4)", 1, 0, 1, 2),
            ("0x78", "ext_vid_in_mux_sel", "External Video In Mux Select", 1, 0, 1, 3),
            ("0x78", "edge_width_sel", "Edge Detect Width (2/4/6/8 px)", 2, 0, 3, 4),
            ("0xC8", "luma_key_enable", "Luma Key Enable", 1, 0, 1, 31),
            ("0xC8", "luma_key_direction", "Luma Key Direction", 1, 0, 1, 30),
            ("0xC8", "luma_key_thresh_high", "Luma Key Threshold High", 8, 0, 255, 8),
            ("0xC8", "luma_key_thresh_low", "Luma Key Threshold Low", 8, 0, 255, 0),
            ("0xD4", "dsm_hi_alpha", "DSM High Alpha", 12, 0, 4095, 0),
            ("0xD8", "dsm_lo_alpha", "DSM Low Alpha", 12, 0, 4095, 0),
            ("0xDC", "noise_alpha", "Noise Alpha", 12, 0, 4095, 0),
        ]
        digital_defs = [
            ("0x100", "ca_rule", "1D CA Rule (Wolfram 0-255)", 8, 0, 255, 0),
        ]

        self._add_section(scroll_layout, "Shape Gen 1", shape1_defs)
        self._add_section(scroll_layout, "Shape Gen 2", shape2_defs)
        self._add_section(scroll_layout, "OSC 1", osc1_defs)
        self._add_section(scroll_layout, "OSC 2", osc2_defs)
        self._add_section(scroll_layout, "Digital Matrix", digital_defs)
        self._add_section(scroll_layout, "Other Controls", other_defs)
        
        scroll_layout.addStretch()
        scroll.setWidget(scroll_widget)
        layout.addWidget(scroll)
        
    def create_register_control(self, addr, name, label, bits, min_val, max_val, bit_offset=0):
        """Create a row with label, slider, and number box for a register field."""
        row = QWidget()
        layout = QHBoxLayout(row)
        layout.setContentsMargins(0, 0, 0, 0)

        label_widget = QLabel(f"{label} ({addr}):")
        label_widget.setMinimumWidth(180)
        layout.addWidget(label_widget)
        
        # Slider
        slider = QSlider(Qt.Horizontal)
        slider.setMinimum(min_val)
        slider.setMaximum(max_val)
        slider.setValue(0)
        slider.setMinimumWidth(200)
        
        # Number box
        number_box = QSpinBox()
        number_box.setMinimum(min_val)
        number_box.setMaximum(max_val)
        number_box.setValue(0)
        number_box.setMinimumWidth(100)
        
        # Store references
        slider.reg_name = name
        slider.reg_addr = addr
        slider.reg_bits = bits
        slider.reg_bit_offset = bit_offset
        slider.number_box = number_box
        
        number_box.reg_name = name
        number_box.reg_addr = addr
        number_box.reg_bits = bits
        number_box.reg_bit_offset = bit_offset
        number_box.slider = slider
        
        # Connect signals - use helper functions to prevent feedback loops
        def update_number_box(val):
            number_box.blockSignals(True)
            number_box.setValue(val)
            number_box.blockSignals(False)
        
        def update_slider(val):
            slider.blockSignals(True)
            slider.setValue(val)
            slider.blockSignals(False)
        
        slider.valueChanged.connect(update_number_box)
        slider.sliderReleased.connect(lambda s=slider: self.on_slider_released(s))

        # Sync slider from spinbox while typing; commit + write on Enter only
        number_box.valueChanged.connect(update_slider)
        number_box.lineEdit().returnPressed.connect(
            lambda nb=number_box: self.on_spinbox_commit(nb)
        )
        enter_filter = SpinBoxEnterFilter(
            lambda nb=number_box: self.on_spinbox_commit(nb)
        )
        number_box.installEventFilter(enter_filter)
        
        layout.addWidget(slider)
        layout.addWidget(number_box)
        layout.addStretch()

        return row
    
    def on_spinbox_commit(self, number_box):
        """Commit typed value and write register (same as slider release)."""
        number_box.interpretText()
        slider = number_box.slider
        slider.blockSignals(True)
        slider.setValue(number_box.value())
        slider.blockSignals(False)
        self.on_slider_released(slider)

    def on_slider_released(self, slider):
        """Handle slider release - send register write command"""
        print(f"[Register Control] Slider released: {slider.reg_name}")
        parent = self.parent()
        while parent and not isinstance(parent, XSDBGUIApp):
            parent = parent.parent()
        
        if not parent or not parent.connected or not parent.xsct:
            QMessageBox.warning(self, "Warning", "Not connected to XSDB")
            return
        
        try:
            value = slider.value()
            addr = slider.reg_addr
            bits = slider.reg_bits
            bit_offset = slider.reg_bit_offset
            print(f"[Register Control] Writing {slider.reg_name}: value={value}, addr={addr}, bits={bits}, bit_offset={bit_offset}")
            
            # Construct full address: 0x400000{offset}
            if addr.startswith('0x') or addr.startswith('0X'):
                offset = addr[2:]
            else:
                offset = addr
            full_addr = f"0x400000{offset}"
            
            # Get current tracked value for this register (not from hardware)
            current_val = self.register_values.get(full_addr, 0)
            
            # Create mask for the bits we're updating
            mask = ((1 << bits) - 1) << bit_offset
            # Clear the bits we're updating
            new_val = current_val & ~mask
            # Set the new bits
            new_val = new_val | ((value & ((1 << bits) - 1)) << bit_offset)
            
            # Update tracked value
            self.register_values[full_addr] = new_val
            
            # Write the full register value to hardware
            command = f"mwr -force {full_addr} {hex(new_val)}"
            print(f"[Register Control] {command}")  # Print to terminal
            if bit_offset == 0 and bits == 32:
                print(f"[Register Control] Writing full register {full_addr} = {hex(new_val)}")
            else:
                print(f"[Register Control] Updated field {slider.reg_name} = {value} (bits {bit_offset+bits-1}:{bit_offset}), full register value: {hex(new_val)}")
            
            parent.xsct.do(command)
            parent.log_text.append(f"[Slider] Wrote {slider.reg_name} = {value} to {full_addr} (full value: {hex(new_val)})")
            QApplication.processEvents()  # Update UI
                
        except Exception as e:
            if parent:
                parent.log_text.append(f"Register write error ({slider.reg_name}): {str(e)}")
                QMessageBox.critical(self, "Error", f"Failed to write register: {str(e)}")


class XSDBGUIApp(QMainWindow):
    # Grid configuration
    DIGITAL_GRID_ROWS = 64  # matrix_in: 0-63
    DIGITAL_GRID_COLS = 57  # matrix_out: 0-56
    ANALOG_GRID_ROWS = 11   # analog inputs: 0-10
    ANALOG_GRID_COLS = 20   # analog outputs: 0-19
    
    def __init__(self):
        super().__init__()
        self.xsct = None
        self.connected = False
        self.init_ui()
        
    def init_ui(self):
        self.setWindowTitle("EMS Tester XSDB GUI")
        self.setGeometry(100, 100, 1000, 700)
        
        # Main widget and layout
        main_widget = QWidget()
        self.setCentralWidget(main_widget)
        main_layout = QHBoxLayout(main_widget)
        
        # Left panel for XSDB controls and communication
        left_panel = QWidget()
        left_panel.setMaximumWidth(300)
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
        
        # Right panel with tabs for Digital and Analog matrices
        right_panel = QWidget()
        right_layout = QVBoxLayout(right_panel)
        
        # Create tab widget
        self.tab_widget = QTabWidget()
        
        # Digital matrix tab
        self.digital_grid = MatrixGridWidget(
            self.DIGITAL_GRID_ROWS, 
            self.DIGITAL_GRID_COLS,
            self.get_digital_row_name,
            self.get_digital_col_name,
            "digital"
        )
        self.tab_widget.addTab(self.digital_grid, "Digital Matrix")
        
        # Analog matrix tab
        self.analog_grid = MatrixGridWidget(
            self.ANALOG_GRID_ROWS,
            self.ANALOG_GRID_COLS,
            self.get_analog_row_name,
            self.get_analog_col_name,
            "analog"
        )
        self.tab_widget.addTab(self.analog_grid, "Analog Matrix")
        
        # Register control tab
        self.register_control = RegisterControlWidget()
        self.tab_widget.addTab(self.register_control, "Register Control")
        
        right_layout.addWidget(self.tab_widget)
        
        # Add right panel to main layout
        main_layout.addWidget(right_panel, 2)
        
    def get_digital_row_name(self, row):
        """Get the custom name for a digital row (matrix input)"""
        return ROW_NAMES.get(row, f"in_{row}")
    
    def get_digital_col_name(self, col):
        """Get the custom name for a digital column (matrix output)"""
        return COL_NAMES.get(col, f"out_{col}")
    
    def get_analog_row_name(self, row):
        """Get the name for an analog row (input)"""
        return ANALOG_IN_NAMES.get(row, f"analog_in_{row}")
    
    def get_analog_col_name(self, col):
        """Get the name for an analog column (output)"""
        return ANALOG_OUT_NAMES.get(col, f"analog_out_{col}")
        
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
            
            # Reset matrices on connect
            self.log_text.append("Resetting digital matrix...")
            QApplication.processEvents()
            rst_digital_side_matrix()
            self.log_text.append("Digital matrix reset complete")
            
            self.log_text.append("Resetting analog matrix...")
            QApplication.processEvents()
            # Reset all analog outputs (0-19)
            for out_val in range(20):
                rst_annaloge_side_matrix(out_val)
            self.log_text.append("Analog matrix reset complete")
            
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
            value = result.strip()
            if ':' in value:
                parts = value.split(':')
                if len(parts) > 1:
                    value = parts[1].strip()
            
            self.read_value_label.setText(value)
            self.log_text.append(f"Read {addr}: {value}")
            
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to read register: {str(e)}")
            self.log_text.append(f"Register read error: {str(e)}")
            self.read_value_label.setText("Error")
            
    def closeEvent(self, event):
        """Handle application close event"""
        self.disconnect_xsdb()
        # Hide tooltips from both grids
        if hasattr(self, 'digital_grid'):
            self.digital_grid.tooltip.hide()
        if hasattr(self, 'analog_grid'):
            self.analog_grid.tooltip.hide()
        event.accept()


def main():
    app = QApplication(sys.argv)
    app.setStyle('Fusion')
    
    # Set application font
    font = QFont("Segoe UI", 9)
    app.setFont(font)
    
    window = XSDBGUIApp()
    window.show()
    
    sys.exit(app.exec())


if __name__ == "__main__":
    main()

