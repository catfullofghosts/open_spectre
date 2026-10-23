"""Digital / analog matrix grids for the MIDI tester (XSDB-style UI)."""

from PySide6.QtCore import Qt
from PySide6.QtGui import QCursor
from PySide6.QtWidgets import (
    QApplication,
    QGridLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QVBoxLayout,
    QWidget,
)

DIGITAL_IN_NAMES = {i: f"xy_inv_out_{i}" for i in range(18)}
DIGITAL_IN_NAMES.update({
    18: "slow_cnt_6",
    19: "slow_cnt_3",
    20: "slow_cnt_1_5",
    21: "slow_cnt_0_6",
    22: "slow_cnt_0_4",
    23: "slow_cnt_0_2",
})
for i in range(4):
    DIGITAL_IN_NAMES[24 + i] = f"overlay_gate_out_{i}"
    DIGITAL_IN_NAMES[28 + i] = f"inv_out_{i}"
    DIGITAL_IN_NAMES[32 + i] = f"edge_detector_out_{i}"
DIGITAL_IN_NAMES.update({
    36: "delay_out",
    37: "ff_out_a",
    38: "ff_out_b",
    39: "shape1_a",
    40: "shape1_b",
    41: "shape2_a",
    42: "shape2_b",
})
for i in range(7):
    DIGITAL_IN_NAMES[43 + i] = f"comp_output_{i}"
DIGITAL_IN_NAMES.update({
    50: "gnd",
    51: "osc1_sqr",
    52: "osc2_sqr",
    53: "random1",
    54: "random2",
    55: "audio_T",
    56: "audio_B",
    57: "ca_out",
    63: "vcc",
})

DIGITAL_OUT_NAMES = {i: f"xy_inv_in_{i}" for i in range(18)}
DIGITAL_OUT_NAMES.update({
    18: "overlay_gate1_0",
    19: "overlay_gate2_0",
    20: "overlay_gate1_1",
    21: "overlay_gate2_1",
    22: "overlay_gate1_2",
    23: "overlay_gate2_2",
    24: "overlay_gate1_3",
    25: "overlay_gate2_3",
})
for i in range(4):
    DIGITAL_OUT_NAMES[26 + i] = f"inv_in_{i}"
DIGITAL_OUT_NAMES.update({
    30: "edge_detector_in",
    31: "delay_in",
    32: "ff_in_a",
    33: "ff_in_b",
    34: "acm_out1",
    35: "acm_out2",
})
for i in range(4):
    DIGITAL_OUT_NAMES[39 - i] = f"luma_in1_{i}"
for i in range(3):
    DIGITAL_OUT_NAMES[42 - i] = f"chroma_mux_in1_{i}"
    DIGITAL_OUT_NAMES[45 - i] = f"chroma_mux_in1_{i + 3}"
for i in range(4):
    DIGITAL_OUT_NAMES[49 - i] = f"luma_in2_{i}"
for i in range(3):
    DIGITAL_OUT_NAMES[52 - i] = f"chroma_mux_in2_{i}"
    DIGITAL_OUT_NAMES[55 - i] = f"chroma_mux_in2_{i + 3}"
DIGITAL_OUT_NAMES[56] = "chrom_swap"

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
    10: "dsm_lo",
}

ANALOG_OUT_NAMES = {
    0: "pos_h_1",
    1: "pos_v_1",
    2: "zoom_h_1",
    3: "zoom_v_1",
    4: "circle_1",
    5: "gear_1",
    6: "lantern_1",
    7: "fizz_1",
    8: "pos_h_2",
    9: "pos_v_2",
    10: "zoom_h_2",
    11: "zoom_v_2",
    12: "circle_2",
    13: "gear_2",
    14: "lantern_2",
    15: "fizz_2",
    16: "y_anna",
    17: "u_anna",
    18: "v_anna",
    19: "vid_span",
}


def digital_in_name(row):
    return DIGITAL_IN_NAMES.get(row, f"in_{row}")


def digital_out_name(col):
    return DIGITAL_OUT_NAMES.get(col, f"out_{col}")


def analog_in_name(row):
    return ANALOG_IN_NAMES.get(row, f"analog_in_{row}")


def analog_out_name(col):
    return ANALOG_OUT_NAMES.get(col, f"analog_out_{col}")


class CustomToolTip(QLabel):
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
        self.setText(text)
        self.adjustSize()
        cursor_pos = QCursor.pos()
        tooltip_x = cursor_pos.x() + 15
        tooltip_y = cursor_pos.y() + 15
        screen = QApplication.primaryScreen().geometry()
        if tooltip_x + self.width() > screen.right():
            tooltip_x = cursor_pos.x() - self.width() - 5
        if tooltip_y + self.height() > screen.bottom():
            tooltip_y = cursor_pos.y() - self.height() - 5
        self.move(tooltip_x, tooltip_y)
        self.show()


class MatrixGridWidget(QWidget):
    """64x57 digital or 11x20 analog pin grid. Row=input, col=output."""

    def __init__(self, rows, cols, get_row_name, get_col_name, matrix_type="digital", parent=None):
        super().__init__(parent)
        self.rows = rows
        self.cols = cols
        self.get_row_name = get_row_name
        self.get_col_name = get_col_name
        self.matrix_type = matrix_type
        self.on_cell = None
        self.on_reset_all = None
        self.grid_buttons = {}
        self.grid_states = {}
        self.tooltip = CustomToolTip("")
        self.button_width = 15
        self.button_height = 15
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self)

        controls = QGroupBox(f"{self.rows}x{self.cols} {self.matrix_type.capitalize()} Matrix")
        controls_layout = QVBoxLayout(controls)
        top_row = QHBoxLayout()
        top_row.addWidget(QLabel(f"Matrix: {self.rows} inputs x {self.cols} outputs"))

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
        controls_layout.addLayout(top_row)
        layout.addWidget(controls)

        self.grid_widget = QWidget()
        self.grid_layout = QGridLayout(self.grid_widget)
        self.grid_layout.setSpacing(0)
        self.grid_layout.setContentsMargins(0, 0, 0, 0)
        self.grid_layout.setHorizontalSpacing(0)
        self.grid_layout.setVerticalSpacing(0)

        total_width = self.cols * self.button_width
        total_height = self.rows * self.button_height
        self.grid_widget.setMinimumSize(total_width, total_height)
        self.grid_widget.setMaximumSize(total_width, total_height)
        layout.addWidget(self.grid_widget)
        self.create_grid()

    def get_row_block_index(self, row):
        if self.matrix_type == "digital":
            if 0 <= row <= 17:
                return 0
            if 18 <= row <= 23:
                return 1
            if 24 <= row <= 27:
                return 2
            if 28 <= row <= 31:
                return 3
            if 32 <= row <= 35:
                return 4
            if 36 <= row <= 38:
                return 5
            if 39 <= row <= 40:
                return 6
            if 41 <= row <= 42:
                return 7
            if 43 <= row <= 49:
                return 8
            if row == 50:
                return 9
            if 51 <= row <= 52:
                return 10
            if 53 <= row <= 54:
                return 11
            if 55 <= row <= 56:
                return 12
            if row == 57:
                return 13
            if 58 <= row <= 62:
                return 14
            if row == 63:
                return 15
        else:
            if row <= 2:
                return 0
            if row <= 5:
                return 1
            if row <= 8:
                return 2
            return 3
        return 0

    def get_col_block_index(self, col):
        if self.matrix_type == "digital":
            if 0 <= col <= 17:
                return 0
            if 18 <= col <= 25:
                return 1
            if 26 <= col <= 29:
                return 2
            if 30 <= col <= 33:
                return 3
            if 34 <= col <= 35:
                return 4
            if 36 <= col <= 39:
                return 5
            if 40 <= col <= 45:
                return 6
            if 46 <= col <= 49:
                return 7
            if 50 <= col <= 55:
                return 8
            if col == 56:
                return 9
        else:
            if col <= 5:
                return 0
            if col <= 11:
                return 1
            return 2
        return 0

    def get_column_color(self, col, row=None):
        if self.matrix_type != "digital":
            return None
        if 36 <= col <= 39 or 46 <= col <= 49:
            if row is not None and self.get_row_block_index(row) % 2 == 1:
                return "#6BA8B6"
            return "#8DC8D6"
        if 40 <= col <= 45:
            even = (col - 40) % 2 == 0
            odd_row = row is not None and self.get_row_block_index(row) % 2 == 1
            if even:
                return "#C08691" if odd_row else "#E0A6B1"
            return "#60BE70" if odd_row else "#80DE80"
        if 50 <= col <= 55:
            even = (col - 50) % 2 == 0
            odd_row = row is not None and self.get_row_block_index(row) % 2 == 1
            if even:
                return "#C08691" if odd_row else "#E0A6B1"
            return "#60BE70" if odd_row else "#80DE80"
        return None

    def create_grid(self):
        self.clear_grid()
        for row in range(self.rows):
            for col in range(self.cols):
                btn = QPushButton("")
                btn.setCheckable(True)
                btn.setMinimumSize(self.button_width, self.button_height)
                btn.setMaximumSize(self.button_width, self.button_height)

                base_color = self.get_column_color(col, row)
                if base_color is None:
                    if (self.get_row_block_index(row) + self.get_col_block_index(col)) % 2 == 0:
                        base_color = "#FFFFFF"
                    else:
                        base_color = "#E0E0E0"

                btn.setStyleSheet(f"""
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
                """)
                btn.clicked.connect(lambda checked, r=row, c=col: self.toggle_grid_button(r, c))
                btn.enterEvent = lambda event, r=row, c=col: self.on_button_hover_enter(r, c)
                btn.leaveEvent = lambda event: self.on_button_hover_leave()
                self.grid_layout.addWidget(btn, row, col)
                self.grid_buttons[(row, col)] = btn
                self.grid_states[(row, col)] = False

    def clear_grid(self):
        while self.grid_layout.count():
            child = self.grid_layout.takeAt(0)
            if child.widget():
                child.widget().deleteLater()
        self.grid_buttons.clear()
        self.grid_states.clear()

    def clear_local_states(self):
        for (row, col), btn in self.grid_buttons.items():
            if btn.isChecked():
                btn.setChecked(False)
            self.grid_states[(row, col)] = False

    def reset_all_matrix(self):
        if self.on_reset_all is None:
            return
        if not self.on_reset_all():
            return
        self.clear_local_states()

    def on_button_hover_enter(self, row, col):
        text = f"{self.get_row_name(row)}, {self.get_col_name(col)}"
        self.hover_info_label.setText(text)
        self.tooltip.showAtCursor(text)

    def on_button_hover_leave(self):
        self.hover_info_label.setText(f"Grid: {self.rows}x{self.cols} buttons (hover for row/col)")
        self.tooltip.hide()

    def toggle_grid_button(self, row, col):
        btn = self.grid_buttons[(row, col)]
        is_checked = btn.isChecked()
        self.grid_states[(row, col)] = is_checked
        if self.on_cell is not None:
            self.on_cell(row, col, is_checked)
