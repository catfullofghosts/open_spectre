# in Your vivado bin folder (windows) open a terminal and run 'xsdb' 
# This starts a XSDB session, Now enter "xsdbserver start -port 3010"

"""EMS Tester XSDB GUI with colored digital-matrix pins and per-color presets.

Extended copy of xsdb_gui_app.py. Each paint color tracks the pins it has
written so a color can be cleared and recalled without touching the others.
Digital presets are stored in digital_matrix_presets.json; analog uses a
single preset list in analog_matrix_presets.json.
"""
import sys
import os
import json
# Add parent directory to path to import ems_tester_xsdb
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from PySide6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                               QHBoxLayout, QGridLayout, QPushButton, QSlider, 
                               QLabel, QComboBox, QTextEdit, QLineEdit, QSpinBox,
                               QGroupBox, QMessageBox, QScrollArea, QToolTip, QDialog, 
                               QDialogButtonBox, QTabWidget, QButtonGroup, QSizePolicy)
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
    19: "vid_span"
}

# Paint colors for digital-matrix pins. Each color owns its own live pin set
# and can store named presets independently of the others.
PIN_COLORS = [
    ("red", "Red", "#E53935", "#C62828"),
    ("orange", "Orange", "#FB8C00", "#EF6C00"),
    ("yellow", "Yellow", "#F9A825", "#F57F17"),
    ("green", "Green", "#43A047", "#2E7D32"),
    ("cyan", "Cyan", "#00ACC1", "#00838F"),
    ("blue", "Blue", "#1E88E5", "#1565C0"),
    ("purple", "Purple", "#8E24AA", "#6A1B9A"),
    ("magenta", "Magenta", "#D81B60", "#AD1457"),
]
PIN_COLOR_MAP = {
    cid: {"name": name, "hex": hexv, "hover": hover}
    for cid, name, hexv, hover in PIN_COLORS
}
PRESETS_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "digital_matrix_presets.json",
)
ANALOG_PRESETS_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "analog_matrix_presets.json",
)

# Digital-matrix visual spacers: 2 background cells, not clickable.
# Rows: after slow counters (18-23). Columns: after inv_in plus the next invert (col 30).
DIGITAL_ROW_SPACER_AFTER = 23
DIGITAL_COL_SPACER_AFTER = 30
DIGITAL_SPACER_CELLS = 2


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


class ColorSwatchButton(QPushButton):
    """Paint-color button; double-click recalls that color's selected preset."""
    doubleClicked = Signal()

    def mouseDoubleClickEvent(self, event):
        self.doubleClicked.emit()
        super().mouseDoubleClickEvent(event)


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

        # Per-color live pin tracking and named presets (digital matrix only)
        self.current_color = PIN_COLORS[0][0] if matrix_type == "digital" else None
        self.pin_colors = {}  # (row, col) -> color_id for pins currently written
        self.color_pins = {cid: set() for cid, *_ in PIN_COLORS}
        self.color_buttons = {}
        self.live_pins = set()  # analog: pins currently written
        if matrix_type == "digital":
            self.presets = {cid: {} for cid, *_ in PIN_COLORS}
            self.selected_preset_name = {cid: "" for cid, *_ in PIN_COLORS}
        else:
            self.presets = {}
            self.selected_preset_name = ""
        
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

        if self.matrix_type == "digital":
            self._init_color_preset_ui(grid_controls_layout)
        else:
            self._init_analog_preset_ui(grid_controls_layout)
        
        layout.addWidget(grid_controls)
        
        # Grid area
        self.grid_widget = QWidget()
        self.grid_widget.setStyleSheet("background-color: transparent;")
        self.grid_layout = QGridLayout(self.grid_widget)
        self.grid_layout.setSpacing(0)
        self.grid_layout.setContentsMargins(0, 0, 0, 0)
        self.grid_layout.setHorizontalSpacing(0)
        self.grid_layout.setVerticalSpacing(0)
        
        self._apply_grid_widget_size()

        grid_scroll = QScrollArea()
        grid_scroll.setWidget(self.grid_widget)
        grid_scroll.setWidgetResizable(False)
        grid_scroll.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        layout.addWidget(grid_scroll)
        
        # Create initial grid
        self.create_grid()

        if self.matrix_type == "digital":
            self._load_presets()
            self._refresh_color_ui()
        else:
            self._load_analog_presets()
            self._refresh_analog_preset_ui()

    def _find_app(self):
        parent = self.parent()
        while parent and not isinstance(parent, XSDBGUIApp):
            parent = parent.parent()
        return parent

    def _log(self, message):
        parent = self._find_app()
        if parent:
            parent.log_text.append(message)

    def _init_color_preset_ui(self, parent_layout):
        """Color palette plus per-color preset save/recall controls."""
        color_row = QHBoxLayout()
        color_row.addWidget(QLabel("Pin color:"))

        self.color_button_group = QButtonGroup(self)
        self.color_button_group.setExclusive(True)
        for cid, name, hexv, hover in PIN_COLORS:
            btn = ColorSwatchButton(f"{name} (0)")
            btn.setCheckable(True)
            btn.setMinimumWidth(88)
            btn.setToolTip(
                f"Click to paint with {name}. Double-click to recall {name}'s selected preset."
            )
            if cid == self.current_color:
                btn.setChecked(True)
            btn.clicked.connect(lambda checked, c=cid: self._select_color(c))
            btn.doubleClicked.connect(lambda c=cid: self._recall_color_preset(c))
            self.color_button_group.addButton(btn)
            self.color_buttons[cid] = btn
            color_row.addWidget(btn)
        color_row.addStretch()
        parent_layout.addLayout(color_row)

        preset_row = QHBoxLayout()
        self.preset_color_label = QLabel("Red preset:")
        self.preset_color_label.setMinimumWidth(90)
        preset_row.addWidget(self.preset_color_label)

        self.preset_combo = QComboBox()
        self.preset_combo.setEditable(True)
        self.preset_combo.setMinimumWidth(180)
        self.preset_combo.setInsertPolicy(QComboBox.NoInsert)
        self.preset_combo.currentTextChanged.connect(self._on_preset_text_changed)
        preset_row.addWidget(self.preset_combo)

        save_btn = QPushButton("Save")
        save_btn.setToolTip("Save the current color's written pins as this preset")
        save_btn.clicked.connect(self._save_current_color_preset)
        preset_row.addWidget(save_btn)

        recall_btn = QPushButton("Recall")
        recall_btn.setToolTip("Clear this color's live pins, then program the selected preset")
        recall_btn.clicked.connect(lambda: self._recall_color_preset())
        preset_row.addWidget(recall_btn)

        clear_color_btn = QPushButton("Clear Color")
        clear_color_btn.setToolTip("Clear only the pins written by the selected color")
        clear_color_btn.clicked.connect(lambda: self._clear_color_pins())
        preset_row.addWidget(clear_color_btn)

        delete_btn = QPushButton("Delete Preset")
        delete_btn.clicked.connect(self._delete_current_preset)
        preset_row.addWidget(delete_btn)

        recall_all_btn = QPushButton("Recall All")
        recall_all_btn.setToolTip(
            "Recall every color's selected preset. Each color only clears/reprograms its own pins."
        )
        recall_all_btn.clicked.connect(self._recall_all_presets)
        preset_row.addWidget(recall_all_btn)
        preset_row.addStretch()
        parent_layout.addLayout(preset_row)

        self.color_status_label = QLabel("")
        self.color_status_label.setStyleSheet("color: #444444;")
        parent_layout.addWidget(self.color_status_label)

    def _init_analog_preset_ui(self, parent_layout):
        """Single preset list for the analog matrix (no color layers)."""
        preset_row = QHBoxLayout()
        preset_row.addWidget(QLabel("Preset:"))

        self.preset_combo = QComboBox()
        self.preset_combo.setEditable(True)
        self.preset_combo.setMinimumWidth(180)
        self.preset_combo.setInsertPolicy(QComboBox.NoInsert)
        self.preset_combo.currentTextChanged.connect(self._on_analog_preset_text_changed)
        preset_row.addWidget(self.preset_combo)

        save_btn = QPushButton("Save")
        save_btn.setToolTip("Save the current analog pins as this preset")
        save_btn.clicked.connect(self._save_analog_preset)
        preset_row.addWidget(save_btn)

        recall_btn = QPushButton("Recall")
        recall_btn.setToolTip("Clear the analog pins last written, then program this preset")
        recall_btn.clicked.connect(self._recall_analog_preset)
        preset_row.addWidget(recall_btn)

        clear_btn = QPushButton("Clear Pins")
        clear_btn.setToolTip("Clear the analog pins currently written")
        clear_btn.clicked.connect(self._clear_analog_pins)
        preset_row.addWidget(clear_btn)

        delete_btn = QPushButton("Delete Preset")
        delete_btn.clicked.connect(self._delete_analog_preset)
        preset_row.addWidget(delete_btn)
        preset_row.addStretch()
        parent_layout.addLayout(preset_row)

        self.analog_status_label = QLabel("")
        self.analog_status_label.setStyleSheet("color: #444444;")
        parent_layout.addWidget(self.analog_status_label)

    def _swatch_stylesheet(self, color_id, selected):
        info = PIN_COLOR_MAP[color_id]
        text = "#222222" if color_id in ("yellow", "orange", "cyan") else "#ffffff"
        border = "#111111" if selected else "#666666"
        border_w = 3 if selected else 1
        return f"""
            QPushButton {{
                background-color: {info['hex']};
                color: {text};
                font-weight: bold;
                border: {border_w}px solid {border};
                border-radius: 3px;
                padding: 3px 6px;
            }}
            QPushButton:checked {{
                border: 3px solid #111111;
            }}
            QPushButton:hover {{
                background-color: {info['hover']};
            }}
        """

    def _select_color(self, color_id):
        self.current_color = color_id
        self._refresh_color_ui()

    def _on_preset_text_changed(self, text):
        if self.current_color:
            self.selected_preset_name[self.current_color] = text

    def _refresh_color_ui(self):
        if self.matrix_type != "digital":
            return
        for cid, name, *_ in PIN_COLORS:
            count = len(self.color_pins[cid])
            btn = self.color_buttons[cid]
            btn.setText(f"{name} ({count})")
            btn.setChecked(cid == self.current_color)
            btn.setStyleSheet(self._swatch_stylesheet(cid, cid == self.current_color))
            preset = self.selected_preset_name.get(cid, "") or "(none)"
            btn.setToolTip(
                f"{name}: {count} live pins, selected preset '{preset}'. "
                "Click to paint. Double-click to recall."
            )

        color_name = PIN_COLOR_MAP[self.current_color]["name"]
        self.preset_color_label.setText(f"{color_name} preset:")

        self.preset_combo.blockSignals(True)
        self.preset_combo.clear()
        names = sorted(self.presets[self.current_color].keys())
        self.preset_combo.addItems(names)
        current = self.selected_preset_name.get(self.current_color, "")
        if current:
            idx = self.preset_combo.findText(current)
            if idx >= 0:
                self.preset_combo.setCurrentIndex(idx)
            else:
                self.preset_combo.setEditText(current)
        self.preset_combo.blockSignals(False)

        live = len(self.color_pins[self.current_color])
        saved = len(self.presets[self.current_color])
        self.color_status_label.setText(
            f"Painting with {color_name}. {live} live pin(s) written for this color, "
            f"{saved} saved preset(s). Recall clears only this color's pins, then programs the preset."
        )

    def _load_presets(self):
        if not os.path.isfile(PRESETS_PATH):
            return
        try:
            with open(PRESETS_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
            colors = data.get("colors", {})
            for cid in PIN_COLOR_MAP:
                entry = colors.get(cid, {})
                loaded = {}
                for name, pins in entry.get("presets", {}).items():
                    loaded[name] = [tuple(p) for p in pins]
                self.presets[cid] = loaded
                self.selected_preset_name[cid] = entry.get("last_recalled", "")
        except Exception as e:
            self._log(f"Failed to load presets: {e}")

    def _save_presets_file(self):
        data = {"version": 1, "colors": {}}
        for cid in PIN_COLOR_MAP:
            data["colors"][cid] = {
                "presets": {
                    name: [list(p) for p in pins]
                    for name, pins in self.presets[cid].items()
                },
                "last_recalled": self.selected_preset_name.get(cid, ""),
            }
        try:
            with open(PRESETS_PATH, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to save presets: {e}")

    def _save_current_color_preset(self):
        name = self.preset_combo.currentText().strip()
        if not name:
            QMessageBox.warning(self, "Warning", "Enter a preset name before saving")
            return
        pins = sorted(self.color_pins[self.current_color])
        self.presets[self.current_color][name] = pins
        self.selected_preset_name[self.current_color] = name
        self._save_presets_file()
        self._refresh_color_ui()
        color_name = PIN_COLOR_MAP[self.current_color]["name"]
        self._log(f"Saved {color_name} preset '{name}' ({len(pins)} pins)")

    def _delete_current_preset(self):
        name = self.preset_combo.currentText().strip()
        if name not in self.presets[self.current_color]:
            QMessageBox.warning(self, "Warning", f"No saved preset named '{name}'")
            return
        del self.presets[self.current_color][name]
        if self.selected_preset_name.get(self.current_color) == name:
            self.selected_preset_name[self.current_color] = ""
        self._save_presets_file()
        self._refresh_color_ui()
        color_name = PIN_COLOR_MAP[self.current_color]["name"]
        self._log(f"Deleted {color_name} preset '{name}'")

    def _clear_color_pins(self, color_id=None):
        color_id = color_id or self.current_color
        count = len(self.color_pins[color_id])
        self._apply_color_pins(color_id, set())
        self._refresh_color_ui()
        color_name = PIN_COLOR_MAP[color_id]["name"]
        self._log(f"Cleared {count} {color_name} pin(s)")

    def _recall_color_preset(self, color_id=None):
        color_id = color_id or self.current_color
        if color_id == self.current_color:
            name = self.preset_combo.currentText().strip()
            self.selected_preset_name[color_id] = name
        else:
            name = self.selected_preset_name.get(color_id, "").strip()
        if name not in self.presets[color_id]:
            color_name = PIN_COLOR_MAP[color_id]["name"]
            QMessageBox.warning(
                self, "Warning",
                f"No saved preset '{name}' for {color_name}" if name
                else f"Select a saved preset for {color_name} first",
            )
            return
        new_pins = set(tuple(p) for p in self.presets[color_id][name])
        self._apply_color_pins(color_id, new_pins)
        self._save_presets_file()
        self._refresh_color_ui()
        color_name = PIN_COLOR_MAP[color_id]["name"]
        self._log(f"Recalled {color_name} preset '{name}' ({len(new_pins)} pins)")

    def _recall_all_presets(self):
        recalled = []
        missing = []
        all_affected = set()
        for cid, name, *_ in PIN_COLORS:
            if cid == self.current_color:
                self.selected_preset_name[cid] = self.preset_combo.currentText().strip()
            pname = self.selected_preset_name.get(cid, "").strip()
            if not pname:
                continue
            if pname not in self.presets[cid]:
                missing.append(f"{name} '{pname}'")
                continue
            new_pins = set(tuple(p) for p in self.presets[cid][pname])
            all_affected |= self._apply_color_pins(cid, new_pins, program=False)
            recalled.append(f"{name} '{pname}'")

        parent = self._find_app()
        self._program_columns(all_affected, parent)
        self._save_presets_file()
        self._refresh_color_ui()

        if recalled:
            self._log(f"Recalled all: {', '.join(recalled)}")
        if missing:
            QMessageBox.warning(self, "Recall All", "Missing presets: " + ", ".join(missing))
        if not recalled and not missing:
            QMessageBox.information(
                self, "Recall All",
                "No color has a selected preset name to recall.",
            )

    def _on_analog_preset_text_changed(self, text):
        self.selected_preset_name = text

    def _refresh_analog_preset_ui(self):
        if self.matrix_type != "analog":
            return
        self.preset_combo.blockSignals(True)
        self.preset_combo.clear()
        names = sorted(self.presets.keys())
        self.preset_combo.addItems(names)
        current = self.selected_preset_name or ""
        if current:
            idx = self.preset_combo.findText(current)
            if idx >= 0:
                self.preset_combo.setCurrentIndex(idx)
            else:
                self.preset_combo.setEditText(current)
        self.preset_combo.blockSignals(False)
        self.analog_status_label.setText(
            f"{len(self.live_pins)} live pin(s) written, "
            f"{len(self.presets)} saved preset(s). "
            "Recall clears only the analog pins last written, then programs the preset."
        )

    def _load_analog_presets(self):
        if not os.path.isfile(ANALOG_PRESETS_PATH):
            return
        try:
            with open(ANALOG_PRESETS_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
            loaded = {}
            for name, pins in data.get("presets", {}).items():
                loaded[name] = [tuple(p) for p in pins]
            self.presets = loaded
            self.selected_preset_name = data.get("last_recalled", "")
        except Exception as e:
            self._log(f"Failed to load analog presets: {e}")

    def _save_analog_presets_file(self):
        data = {
            "version": 1,
            "presets": {
                name: [list(p) for p in pins]
                for name, pins in self.presets.items()
            },
            "last_recalled": self.selected_preset_name or "",
        }
        try:
            with open(ANALOG_PRESETS_PATH, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to save analog presets: {e}")

    def _save_analog_preset(self):
        name = self.preset_combo.currentText().strip()
        if not name:
            QMessageBox.warning(self, "Warning", "Enter a preset name before saving")
            return
        pins = sorted(self.live_pins)
        self.presets[name] = pins
        self.selected_preset_name = name
        self._save_analog_presets_file()
        self._refresh_analog_preset_ui()
        self._log(f"Saved analog preset '{name}' ({len(pins)} pins)")

    def _delete_analog_preset(self):
        name = self.preset_combo.currentText().strip()
        if name not in self.presets:
            QMessageBox.warning(self, "Warning", f"No saved analog preset named '{name}'")
            return
        del self.presets[name]
        if self.selected_preset_name == name:
            self.selected_preset_name = ""
        self._save_analog_presets_file()
        self._refresh_analog_preset_ui()
        self._log(f"Deleted analog preset '{name}'")

    def _clear_analog_pins(self):
        count = len(self.live_pins)
        self._apply_analog_pins(set())
        self._refresh_analog_preset_ui()
        self._log(f"Cleared {count} analog pin(s)")

    def _recall_analog_preset(self):
        name = self.preset_combo.currentText().strip()
        self.selected_preset_name = name
        if name not in self.presets:
            QMessageBox.warning(
                self, "Warning",
                f"No saved analog preset '{name}'" if name
                else "Select a saved analog preset first",
            )
            return
        new_pins = set(tuple(p) for p in self.presets[name])
        self._apply_analog_pins(new_pins)
        self._save_analog_presets_file()
        self._refresh_analog_preset_ui()
        self._log(f"Recalled analog preset '{name}' ({len(new_pins)} pins)")

    def _program_analog_columns(self, cols, parent):
        """Reprogram only the affected analog outputs from live_pins."""
        if not cols:
            return
        connected = bool(parent and parent.connected and parent.xsct)
        for col in sorted(cols):
            rows = self.output_connections.get(col, set())
            if not connected:
                continue
            try:
                if rows:
                    prog_annaloge_side_matrix(col, list(rows))
                else:
                    rst_annaloge_side_matrix(col)
            except Exception as e:
                QMessageBox.critical(self, "Error", f"Failed to program analog matrix: {e}")
                self._log(f"Analog matrix error: {e}")
                return

    def _apply_analog_pins(self, new_pins, program=True):
        """Replace analog live pins. Returns affected output columns."""
        old_pins = set(self.live_pins)
        new_pins = set(tuple(p) for p in new_pins)
        affected_cols = {c for _, c in old_pins} | {c for _, c in new_pins}

        self.live_pins = set(new_pins)
        self.output_connections.clear()
        for row, col in new_pins:
            self.output_connections.setdefault(col, set()).add(row)
            self.grid_states[(row, col)] = True
            self._refresh_button(row, col)
        for row, col in old_pins - new_pins:
            self.grid_states[(row, col)] = False
            self._refresh_button(row, col)

        if program:
            self._program_analog_columns(affected_cols, self._find_app())
        return affected_cols

    def _union_inputs_for_col(self, col):
        """Rows currently written to this output across every color."""
        rows = set()
        for pins in self.color_pins.values():
            for row, pin_col in pins:
                if pin_col == col:
                    rows.add(row)
        return rows

    def _program_columns(self, cols, parent):
        """Reprogram only the affected outputs from the live per-color pin sets."""
        if not cols:
            return
        connected = bool(parent and parent.connected and parent.xsct)
        for col in sorted(cols):
            rows = self._union_inputs_for_col(col)
            if rows:
                self.output_connections[col] = set(rows)
            else:
                self.output_connections.pop(col, None)
            if not connected:
                continue
            try:
                if rows:
                    prog_digital_side_matrix(col, list(rows))
                else:
                    rst_digital_side_matrix(col)
            except Exception as e:
                QMessageBox.critical(self, "Error", f"Failed to program matrix: {e}")
                self._log(f"Matrix error: {e}")
                return

    def _apply_color_pins(self, color_id, new_pins, program=True):
        """Replace one color's live pins. Other colors are left alone.

        Returns the set of output columns that changed so hardware can be
        updated only for those outputs.
        """
        old_pins = set(self.color_pins[color_id])
        new_pins = set(tuple(p) for p in new_pins)
        affected_cols = {c for _, c in old_pins} | {c for _, c in new_pins}

        for pin in old_pins:
            if self.pin_colors.get(pin) == color_id:
                del self.pin_colors[pin]
                self.grid_states[pin] = False
            self.color_pins[color_id].discard(pin)
            self._refresh_button(*pin)

        for pin in new_pins:
            old_owner = self.pin_colors.get(pin)
            if old_owner and old_owner != color_id:
                self.color_pins[old_owner].discard(pin)
            self.color_pins[color_id].add(pin)
            self.pin_colors[pin] = color_id
            self.grid_states[pin] = True
            self._refresh_button(*pin)

        if program:
            self._program_columns(affected_cols, self._find_app())
        return affected_cols

    def _button_stylesheet(self, row, col, color_id=None):
        base_color = self.get_column_color(col, row)
        if base_color is None:
            row_block = self.get_row_block_index(row)
            col_block = self.get_col_block_index(col)
            base_color = "#FFFFFF" if (row_block + col_block) % 2 == 0 else "#E0E0E0"
        if color_id:
            pin = PIN_COLOR_MAP[color_id]
            return f"""
                QPushButton {{
                    border: 1px solid #333333;
                    background-color: {pin['hex']};
                    margin: 0px;
                    padding: 0px;
                    border-radius: 0px;
                }}
                QPushButton:hover {{
                    background-color: {pin['hover']};
                    border: 1px solid #000000;
                }}
            """
        return f"""
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

    def _refresh_button(self, row, col):
        btn = self.grid_buttons.get((row, col))
        if not btn:
            return
        if self.matrix_type == "digital":
            color_id = self.pin_colors.get((row, col))
            is_on = color_id is not None
        else:
            color_id = None
            is_on = (row, col) in self.live_pins
        btn.blockSignals(True)
        btn.setChecked(is_on)
        btn.blockSignals(False)
        btn.setStyleSheet(self._button_stylesheet(row, col, color_id))
        
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
    
    def _visual_size(self):
        extra = DIGITAL_SPACER_CELLS if self.matrix_type == "digital" else 0
        return self.rows + extra, self.cols + extra

    def _apply_grid_widget_size(self):
        vis_rows, vis_cols = self._visual_size()
        total_width = vis_cols * self.button_width
        total_height = vis_rows * self.button_height
        self.grid_widget.setMinimumSize(total_width, total_height)
        self.grid_widget.setMaximumSize(total_width, total_height)

    def _visual_pos(self, row, col):
        """Map hardware matrix (row, col) to visual grid coordinates."""
        vis_row, vis_col = row, col
        if self.matrix_type == "digital":
            if row > DIGITAL_ROW_SPACER_AFTER:
                vis_row += DIGITAL_SPACER_CELLS
            if col > DIGITAL_COL_SPACER_AFTER:
                vis_col += DIGITAL_SPACER_CELLS
        return vis_row, vis_col

    def _is_spacer_visual(self, vis_row, vis_col):
        if self.matrix_type != "digital":
            return False
        if DIGITAL_ROW_SPACER_AFTER < vis_row <= DIGITAL_ROW_SPACER_AFTER + DIGITAL_SPACER_CELLS:
            return True
        if DIGITAL_COL_SPACER_AFTER < vis_col <= DIGITAL_COL_SPACER_AFTER + DIGITAL_SPACER_CELLS:
            return True
        return False

    def _make_spacer_cell(self):
        cell = QWidget()
        cell.setMinimumSize(self.button_width, self.button_height)
        cell.setMaximumSize(self.button_width, self.button_height)
        cell.setAttribute(Qt.WA_TransparentForMouseEvents, True)
        cell.setStyleSheet("background: transparent; border: none;")
        return cell

    def get_column_color(self, col, row=None):
        """Get the base background color for a column, optionally darkened by row block"""
        if self.matrix_type == "digital":
            odd_row = False
            if row is not None:
                odd_row = self.get_row_block_index(row) % 2 == 1

            # Y / luma: dark yellow; second luma bank is a darker yellow
            if 36 <= col <= 39:  # luma_in1
                return "#9A7A10" if odd_row else "#C4A017"
            if 46 <= col <= 49:  # luma_in2
                return "#5C4808" if odd_row else "#7A6410"

            # Chroma: U = red,red,red then V = blue,blue,blue
            # Second chroma bank is a darker red / blue
            if 40 <= col <= 42:  # chroma_mux_in1 U
                return "#A32020" if odd_row else "#C62828"
            if 43 <= col <= 45:  # chroma_mux_in1 V
                return "#0D47A1" if odd_row else "#1565C0"
            if 50 <= col <= 52:  # chroma_mux_in2 U
                return "#6D1515" if odd_row else "#8E1B1B"
            if 53 <= col <= 55:  # chroma_mux_in2 V
                return "#0A2C5C" if odd_row else "#0D3A7A"
        
        # Default: white or light grey based on block
        return None
    
    def create_grid(self):
        """Create a grid of toggle buttons with hover info display"""
        self.clear_grid()
        self._apply_grid_widget_size()

        vis_rows, vis_cols = self._visual_size()
        if self.matrix_type == "digital":
            for vis_row in range(vis_rows):
                for vis_col in range(vis_cols):
                    if self._is_spacer_visual(vis_row, vis_col):
                        self.grid_layout.addWidget(
                            self._make_spacer_cell(), vis_row, vis_col
                        )
        
        # Create grid of toggle buttons at visual positions (spacers shift later cells)
        for row in range(self.rows):
            for col in range(self.cols):
                btn = QPushButton("")
                btn.setCheckable(True)
                btn.setMinimumSize(self.button_width, self.button_height)
                btn.setMaximumSize(self.button_width, self.button_height)
                
                btn.setStyleSheet(self._button_stylesheet(row, col))
                btn.clicked.connect(lambda checked, r=row, c=col: self.toggle_grid_button(r, c))
                
                # Add hover events
                btn.enterEvent = lambda event, r=row, c=col: self.on_button_hover_enter(r, c)
                btn.leaveEvent = lambda event: self.on_button_hover_leave()

                vis_row, vis_col = self._visual_pos(row, col)
                self.grid_layout.addWidget(btn, vis_row, vis_col)
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

    def clear_live_state(self):
        """Clear live pin colors and button state. Does not touch saved presets."""
        self.pin_colors.clear()
        for cid in self.color_pins:
            self.color_pins[cid].clear()
        self.live_pins.clear()
        self.output_connections.clear()
        for (row, col) in list(self.grid_buttons.keys()):
            self.grid_states[(row, col)] = False
            self._refresh_button(row, col)
        if self.matrix_type == "digital":
            self._refresh_color_ui()
        else:
            self._refresh_analog_preset_ui()
        
    def reset_all_matrix(self):
        """Reset all matrix connections and live pin colors. Saved presets are kept."""
        parent = self._find_app()
        connected = bool(parent and parent.connected and parent.xsct)

        try:
            if connected:
                parent.log_text.append(f"Resetting all {self.matrix_type} matrix connections...")
                QApplication.processEvents()
                if self.matrix_type == "digital":
                    rst_digital_side_matrix()
                else:
                    for out_val in range(20):
                        rst_annaloge_side_matrix(out_val)
            self.clear_live_state()
            self._log(
                f"{self.matrix_type.capitalize()} matrix reset complete"
                + ("" if connected else " (GUI only, not connected)")
            )
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to reset matrix: {str(e)}")
            self._log(f"Reset error: {str(e)}")
    
    def on_button_hover_enter(self, row, col):
        """Handle button hover enter event"""
        row_name = self.get_row_name(row)
        col_name = self.get_col_name(col)
        color_id = self.pin_colors.get((row, col))
        if color_id:
            color_name = PIN_COLOR_MAP[color_id]["name"]
            text = f"{row_name}, {col_name}  [{color_name}]"
        else:
            text = f"{row_name}, {col_name}"
        self.hover_info_label.setText(text)
        self.tooltip.showAtCursor(text)
        
    def on_button_hover_leave(self):
        """Handle button hover leave event"""
        self.hover_info_label.setText(f"Grid: {self.rows}x{self.cols} buttons (hover for row/col)")
        self.tooltip.hide()
        
    def _toggle_digital_pin(self, row, col, parent):
        """Paint or clear one digital pin using the selected color.

        Live pins for other colors are left in place. Hardware is rewritten
        only for this output, using the union of every color's pins.
        """
        pin = (row, col)
        existing = self.pin_colors.get(pin)
        row_name = self.get_row_name(row)
        col_name = self.get_col_name(col)
        color_name = PIN_COLOR_MAP[self.current_color]["name"]
        connected = bool(parent and parent.connected and parent.xsct)

        if existing == self.current_color:
            self.color_pins[self.current_color].discard(pin)
            self.pin_colors.pop(pin, None)
            self.grid_states[pin] = False
            action = "cleared"
        else:
            if existing:
                self.color_pins[existing].discard(pin)
            self.color_pins[self.current_color].add(pin)
            self.pin_colors[pin] = self.current_color
            self.grid_states[pin] = True
            action = "wrote"

        self._refresh_button(row, col)
        self._program_columns({col}, parent)
        self._refresh_color_ui()

        suffix = "" if connected else " (not connected)"
        remaining = self._union_inputs_for_col(col)
        if action == "cleared":
            if remaining:
                input_names = [self.get_row_name(r) for r in sorted(remaining)]
                self._log(
                    f"{color_name} cleared {row_name} -> {col_name}; "
                    f"remaining: {', '.join(input_names)}{suffix}"
                )
            else:
                self._log(f"{color_name} cleared {row_name} -> {col_name}{suffix}")
        else:
            if existing and existing != self.current_color:
                prev = PIN_COLOR_MAP[existing]["name"]
                self._log(
                    f"{color_name} took {row_name} -> {col_name} from {prev}{suffix}"
                )
            else:
                self._log(f"{color_name} {action} {row_name} -> {col_name}{suffix}")

    def toggle_grid_button(self, row, col):
        """Handle toggle button press in grid"""
        parent = self._find_app()
        
        btn = self.grid_buttons[(row, col)]
        is_checked = btn.isChecked()
        self.grid_states[(row, col)] = is_checked

        if self.matrix_type == "digital":
            self._toggle_digital_pin(row, col, parent)
            return

        self._toggle_analog_pin(row, col, parent, is_checked)

    def _toggle_analog_pin(self, row, col, parent, is_checked):
        """Toggle one analog pin and reprogram only that output."""
        pin = (row, col)
        row_name = self.get_row_name(row)
        col_name = self.get_col_name(col)
        connected = bool(parent and parent.connected and parent.xsct)

        if is_checked:
            self.live_pins.add(pin)
            self.output_connections.setdefault(col, set()).add(row)
        else:
            self.live_pins.discard(pin)
            if col in self.output_connections:
                self.output_connections[col].discard(row)
                if not self.output_connections[col]:
                    del self.output_connections[col]

        self.grid_states[pin] = is_checked
        self._refresh_button(row, col)
        self._program_analog_columns({col}, parent)
        self._refresh_analog_preset_ui()

        suffix = "" if connected else " (not connected)"
        remaining = sorted(self.output_connections.get(col, set()))
        if is_checked:
            if len(remaining) > 1:
                input_names = [self.get_row_name(r) for r in remaining]
                self._log(f"Connected: {', '.join(input_names)} -> {col_name} (OR'd){suffix}")
            else:
                self._log(f"Connected: {row_name} -> {col_name}{suffix}")
        elif remaining:
            input_names = [self.get_row_name(r) for r in remaining]
            self._log(
                f"Disconnected {row_name}, remaining: {', '.join(input_names)} -> {col_name}{suffix}"
            )
        else:
            self._log(f"Disconnected: {col_name} (all inputs removed){suffix}")


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
    REG_BASE_ADDR = 0x40000000

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
        full_addr = self._resolve_full_addr(addr)
        if full_addr not in self.register_values:
            self.register_values[full_addr] = 0

    def _resolve_full_addr(self, addr):
        """Resolve register offset string to absolute 32-bit AXI address."""
        offset = int(addr, 16) if isinstance(addr, str) else int(addr)
        return f"0x{(self.REG_BASE_ADDR + offset):08X}"

    def _init_ca_register_defaults(self):
        """Match FPGA default ca_cfg = 0x021E (rule 30, rule_xor_y)."""
        full_addr = self._resolve_full_addr("0x18")
        self.register_values[full_addr] = 0x021E
        ca_defaults = {
            "ca_rule": 30,
            "ca_rule_xor_y": 1,
            "ca_rule_xor_x": 0,
        }
        for name, value in ca_defaults.items():
            slider = self.registers[name]["widget"].findChild(QSlider)
            spinbox = self.registers[name]["widget"].findChild(QSpinBox)
            if slider is not None:
                slider.setValue(value)
            if spinbox is not None:
                spinbox.setValue(value)

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
            ("0x78", "sync_hv_invert", "Sync H/V Invert (1=640 neg, 0=720 pos)", 1, 0, 1, 6),
            ("0x78", "slow_cnt_frame_sel", "Slow Cnt Frame Mode (0=Hz, 1=frame 2/4/8/16/32/64)", 1, 0, 1, 7),
            ("0x78", "slow_cnt_div4", "Slow Cnt /4 (Hz and frame)", 1, 0, 1, 8),
            ("0xC8", "luma_key_enable", "Luma Key Enable", 1, 0, 1, 31),
            ("0xC8", "luma_key_direction", "Luma Key Direction", 1, 0, 1, 30),
            ("0xC8", "luma_key_thresh_high", "Luma Key Threshold High", 8, 0, 255, 8),
            ("0xC8", "luma_key_thresh_low", "Luma Key Threshold Low", 8, 0, 255, 0),
            ("0xD4", "dsm_hi_alpha", "DSM High Alpha", 12, 0, 4095, 0),
            ("0xD8", "dsm_lo_alpha", "DSM Low Alpha", 12, 0, 4095, 0),
            ("0xDC", "noise_alpha", "Noise Alpha", 12, 0, 4095, 0),
            ("0x198", "dirt_depth", "Dirt Depth (0=off, 1-3 bits [2]/[3:2]/[4:2])", 2, 0, 3, 0),
            ("0x198", "dirt_y_en", "Dirt Y Enable", 1, 0, 1, 2),
            ("0x198", "dirt_u_en", "Dirt U Enable", 1, 0, 1, 3),
            ("0x198", "dirt_v_en", "Dirt V Enable", 1, 0, 1, 4),
        ]
        digital_defs = [
            ("0x0C", "audio_crossover", "Audio T/B Crossover", 8, 0, 255, 0),
            ("0x0C", "audio_b_thresh", "Audio Bass Dig Thresh (0=~12%..7=~94%)", 3, 0, 7, 8),
            ("0x0C", "audio_t_thresh", "Audio Treb Dig Thresh (0=~12%..7=~94%)", 3, 0, 7, 11),
            ("0xFC", "overlay_global_en", "Overlay Enable", 1, 0, 1, 0),
            ("0xFC", "overlay_block_div", "Overlay Block Div (0=/1..4=/16)", 3, 0, 4, 1),
            ("0x100", "sprite0_enable", "Sprite0 Enable", 1, 0, 1, 0),
            ("0x100", "sprite0_x", "Sprite0 X", 11, 0, 2047, 1),
            ("0x100", "sprite0_y", "Sprite0 Y", 11, 0, 2047, 12),
            ("0x104", "sprite0_width", "Sprite0 Width", 11, 0, 2047, 0),
            ("0x104", "sprite0_height", "Sprite0 Height", 11, 0, 2047, 11),
            ("0x108", "sprite0_base", "Sprite0 BRAM Base", 11, 0, 2047, 0),
        ]
        ca_defs = [
            ("0x18", "ca_rule", "CA Wolfram Rule", 8, 0, 255, 0),
            ("0x18", "ca_inject_xor_luma", "CA Inject XOR Luma MSB (2FF)", 1, 0, 1, 8),
            ("0x18", "ca_rule_xor_y", "CA Rule XOR Y", 1, 0, 1, 9),
            ("0x18", "ca_rule_xor_x", "CA Rule XOR X", 1, 0, 1, 10),
        ]

        self._add_section(scroll_layout, "Shape Gen 1", shape1_defs)
        self._add_section(scroll_layout, "Shape Gen 2", shape2_defs)
        self._add_section(scroll_layout, "OSC 1", osc1_defs)
        self._add_section(scroll_layout, "OSC 2", osc2_defs)
        self._add_section(scroll_layout, "1D CA", ca_defs)
        self._init_ca_register_defaults()
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
            
            # Construct full address from register offset.
            full_addr = self._resolve_full_addr(addr)
            
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
        self.setWindowTitle("EMS Tester XSDB GUI — Color Presets")
        self.setGeometry(100, 100, 1200, 800)
        
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
            self.digital_grid.clear_live_state()
            self.log_text.append("Digital matrix reset complete")
            
            self.log_text.append("Resetting analog matrix...")
            QApplication.processEvents()
            # Reset all analog outputs (0-19)
            for out_val in range(20):
                rst_annaloge_side_matrix(out_val)
            self.analog_grid.clear_live_state()
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

