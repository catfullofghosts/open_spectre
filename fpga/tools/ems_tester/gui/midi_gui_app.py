"""Open Spectre MIDI panel — Channel 1 CCs 1–86 via the Pico USB gadget."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PySide6.QtCore import Qt, QTimer
from PySide6.QtGui import QFont
from PySide6.QtWidgets import (
    QApplication,
    QButtonGroup,
    QComboBox,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QScrollArea,
    QSlider,
    QSpinBox,
    QTabWidget,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from midi_matrix_grid import (
    MatrixGridWidget,
    analog_in_name,
    analog_out_name,
    digital_in_name,
    digital_out_name,
)

try:
    import mido
    _MIDO_ERROR = None
except ImportError as exc:
    mido = None
    _MIDO_ERROR = f"{exc}\nRunning: {sys.executable}\nInstall with:\n  {sys.executable} -m pip install mido python-rtmidi"

MIDI_CHANNEL = 0  # Channel 1
PREFERRED_PORT = "OPEN SPECTRE"
SYSEX_HDR = [0x7D, 0x53, 0x50]  # educational 0x7D, "SP"
MAT_DIGITAL = 0
MAT_ANALOG = 1
DIGITAL_GRID_ROWS = 64  # matrix_in 0-63
DIGITAL_GRID_COLS = 57  # matrix_out 0-56
ANALOG_GRID_ROWS = 11   # analog inputs 0-10
ANALOG_GRID_COLS = 20   # analog outputs 0-19


def encode_u14(value):
    value = max(0, min(16383, int(value)))
    return (value >> 7) & 0x7F, value & 0x7F


def encode_u12(value):
    """Match Zynq MidiSplit12: 12-bit field packed as 14-bit << 2."""
    return encode_u14(max(0, min(4095, int(value))) << 2)


def scale_to_cc(value, maxv):
    """Inverse of Zynq MidiScale(cc, maxv)."""
    if maxv <= 0:
        return 0
    return max(0, min(127, int(round(int(value) * 127 / maxv))))


def enum_to_cc(index, bits):
    """Zynq reads these as val >> (7 - bits)."""
    shift = 7 - bits
    return max(0, min(127, int(index) << shift))


def gate_to_cc(on):
    return 127 if on else 0


def rot_to_cc(steps):
    """0 = none, +1..+7 toward MSB, -1..-7 toward LSB."""
    steps = int(steps)
    if steps > 0:
        code = min(7, steps)
    elif steps < 0:
        code = min(14, 7 - steps)
    else:
        code = 0
    return enum_to_cc(code, 4)


class MidiGUIApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.port = None
        self._pending = {}
        self._flush_timer = QTimer(self)
        self._flush_timer.setInterval(15)
        self._flush_timer.timeout.connect(self._flush_midi)
        self._senders = []
        self.init_ui()
        self.refresh_ports()

    def init_ui(self):
        self.setWindowTitle("Open Spectre MIDI")
        self.setGeometry(80, 80, 1560, 860)

        main = QWidget()
        self.setCentralWidget(main)
        layout = QHBoxLayout(main)

        left = QWidget()
        left.setMaximumWidth(300)
        left_layout = QVBoxLayout(left)

        midi_group = QGroupBox("MIDI Output")
        midi_layout = QVBoxLayout(midi_group)

        midi_layout.addWidget(QLabel("Port:"))
        self.port_combo = QComboBox()
        midi_layout.addWidget(self.port_combo)

        btn_row = QHBoxLayout()
        self.refresh_btn = QPushButton("Refresh")
        self.refresh_btn.clicked.connect(self.refresh_ports)
        self.connect_btn = QPushButton("Connect")
        self.connect_btn.clicked.connect(self.toggle_connection)
        btn_row.addWidget(self.refresh_btn)
        btn_row.addWidget(self.connect_btn)
        midi_layout.addLayout(btn_row)

        self.status_label = QLabel("Not connected")
        self.status_label.setStyleSheet("color: red; font-weight: bold;")
        midi_layout.addWidget(self.status_label)
        midi_layout.addWidget(QLabel("Channel 1  ·  CCs 1–104"))
        midi_layout.addWidget(QLabel("Matrix  ·  SysEx 7D 53 50"))

        self.send_all_btn = QPushButton("Send all")
        self.send_all_btn.clicked.connect(self.send_all)
        self.send_all_btn.setEnabled(False)
        midi_layout.addWidget(self.send_all_btn)
        left_layout.addWidget(midi_group)

        log_group = QGroupBox("Log")
        log_layout = QVBoxLayout(log_group)
        self.log_text = QTextEdit()
        self.log_text.setReadOnly(True)
        log_layout.addWidget(self.log_text)
        clear_btn = QPushButton("Clear")
        clear_btn.clicked.connect(self.log_text.clear)
        log_layout.addWidget(clear_btn)
        left_layout.addWidget(log_group)
        layout.addWidget(left)

        tabs = QTabWidget()
        tabs.addTab(self._cc_panel(), "CC Controls")
        tabs.addTab(self._video_fx_panel(), "Video FX")
        tabs.addTab(self._wipe_panel(), "Mix / Wipe")

        self.digital_grid = MatrixGridWidget(
            DIGITAL_GRID_ROWS,
            DIGITAL_GRID_COLS,
            digital_in_name,
            digital_out_name,
            "digital",
        )
        self.digital_grid.on_cell = lambda row, col, on: self.matrix_set_cell(
            MAT_DIGITAL, col, row, on
        )
        self.digital_grid.on_reset_all = lambda: self.matrix_reset_all(MAT_DIGITAL)
        tabs.addTab(self._scroll_wrap(self.digital_grid), "Digital Matrix")

        self.analog_grid = MatrixGridWidget(
            ANALOG_GRID_ROWS,
            ANALOG_GRID_COLS,
            analog_in_name,
            analog_out_name,
            "analog",
        )
        self.analog_grid.on_cell = lambda row, col, on: self.matrix_set_cell(
            MAT_ANALOG, col, row, on
        )
        self.analog_grid.on_reset_all = lambda: self.matrix_reset_all(MAT_ANALOG)
        tabs.addTab(self._scroll_wrap(self.analog_grid), "Analog Matrix")

        layout.addWidget(tabs, 1)

    def _scroll_wrap(self, widget):
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setWidget(widget)
        return scroll

    def _cc_panel(self):
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        body = QWidget()
        body_layout = QHBoxLayout(body)
        col_a = QVBoxLayout()
        col_b = QVBoxLayout()
        col_c = QVBoxLayout()

        col_a.addWidget(self._osc_group("Osc 1", 1))
        col_a.addWidget(self._osc_group("Osc 2", 9))
        col_a.addWidget(self._noise_group())
        col_a.addStretch()

        col_b.addWidget(self._audio_group())
        col_b.addWidget(self._yuv_group())
        col_b.addWidget(self._digital_group())
        col_b.addStretch()

        col_c.addWidget(self._shape_group("Shape Gen 1", 38))
        col_c.addWidget(self._shape_group("Shape Gen 2", 48))
        col_c.addStretch()

        body_layout.addLayout(col_a)
        body_layout.addLayout(col_b)
        body_layout.addLayout(col_c)
        scroll.setWidget(body)
        return scroll

    def _video_fx_panel(self):
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        body = QWidget()
        body_layout = QHBoxLayout(body)
        col_a = QVBoxLayout()
        col_b = QVBoxLayout()
        col_a.addWidget(self._fx_rot_group())
        col_a.addWidget(self._fx_color_group())
        col_a.addWidget(self._fx_scan_group())
        col_a.addWidget(self._fx_smear_group())
        col_a.addWidget(self._fx_bitplane_group())
        col_a.addStretch()
        col_b.addWidget(self._fx_dither_group())
        col_b.addWidget(self._fx_mirror_group())
        col_b.addWidget(self._fx_chromatic_group())
        col_b.addWidget(self._fx_emboss_group())
        col_b.addStretch()
        body_layout.addLayout(col_a)
        body_layout.addLayout(col_b)
        scroll.setWidget(body)
        return scroll

    def _wipe_panel(self):
        self._wipe_dir = 0
        self._wipe_band = 0
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        body = QWidget()
        layout = QVBoxLayout(body)
        layout.addWidget(QLabel(
            "A is the spectron picture. B is the external input. "
            "Mix position 0 shows the spectron; 4095 shows the external input."
        ))
        self._add_combo(
            layout,
            "Mode",
            [
                "Mix",
                "Horizontal",
                "Vertical",
                "Square",
                "Diagonal",
                "Diamond",
                "Cross",
                "Barn doors",
                "Blinds",
            ],
            lambda i: self.queue_cc(99, enum_to_cc(i, 4)),
        )
        self._add_slider(
            layout,
            "Position",
            0,
            4095,
            0,
            lambda v: self.send_u14(103, 104, v),
        )
        self._add_slider(
            layout,
            "Soft edge",
            0,
            255,
            0,
            lambda v: self.queue_cc(102, scale_to_cc(v, 255)),
        )
        self._add_toggle(layout, "Invert", False, lambda on: self.queue_cc(100, gate_to_cc(on)))
        layout.addWidget(QLabel(
            "Direction 0–3 picks an edge. Compass points are for square, diamond and cross. "
            "Barn doors use 0 for left/right and 1 for up/down. "
            "Blinds use direction 0–3 (columns, rows, diagonal, other diagonal) plus the band."
        ))
        self._add_combo(
            layout,
            "Direction",
            [
                "0 centre / left / top / TL",
                "1 north / right / bottom / TR",
                "2 east / BL",
                "3 south / BR",
                "4 west",
                "5 NE",
                "6 SE",
                "7 SW",
                "8 NW",
            ],
            self._wipe_set_dir,
        )
        self._add_combo(
            layout,
            "Blinds band",
            ["4 px", "8 px", "16 px", "32 px"],
            self._wipe_set_band,
        )
        layout.addStretch()
        scroll.setWidget(body)
        return scroll

    def _wipe_set_dir(self, index):
        self._wipe_dir = index
        self._wipe_send_origin()

    def _wipe_set_band(self, index):
        self._wipe_band = index
        self._wipe_send_origin()

    def _wipe_send_origin(self):
        if self._wipe_dir <= 3:
            code = (self._wipe_band << 2) | self._wipe_dir
        else:
            code = self._wipe_dir
        self.queue_cc(101, enum_to_cc(code, 4))

    def _fx_rot_group(self):
        group = QGroupBox("Bit rotate")
        layout = QVBoxLayout(group)
        layout.addWidget(QLabel("Runs first. Negative rotates toward the LSB, positive toward the MSB, with wrap."))
        self._add_slider(layout, "R rotate", -7, 7, 0, lambda v: self.queue_cc(92, rot_to_cc(v)))
        self._add_slider(layout, "G rotate", -7, 7, 0, lambda v: self.queue_cc(93, rot_to_cc(v)))
        self._add_slider(layout, "B rotate", -7, 7, 0, lambda v: self.queue_cc(94, rot_to_cc(v)))
        return group

    def _fx_color_group(self):
        group = QGroupBox("Color")
        layout = QVBoxLayout(group)
        self._add_toggle(layout, "Invert R", False, lambda on: self.queue_cc(59, gate_to_cc(on)))
        self._add_toggle(layout, "Invert G", False, lambda on: self.queue_cc(60, gate_to_cc(on)))
        self._add_toggle(layout, "Invert B", False, lambda on: self.queue_cc(61, gate_to_cc(on)))
        self._add_choice(
            layout,
            "Swap",
            ["RGB", "BGR", "GRB", "RBG"],
            lambda i: self.queue_cc(62, enum_to_cc(i, 2)),
        )
        self._add_toggle(layout, "Bit reverse R", False, lambda on: self.queue_cc(63, gate_to_cc(on)))
        self._add_toggle(layout, "Bit reverse G", False, lambda on: self.queue_cc(64, gate_to_cc(on)))
        self._add_toggle(layout, "Bit reverse B", False, lambda on: self.queue_cc(65, gate_to_cc(on)))
        return group

    def _fx_scan_group(self):
        group = QGroupBox("Scanline and previous pixel")
        layout = QVBoxLayout(group)
        self._add_toggle(layout, "Scanlines", False, lambda on: self.queue_cc(66, gate_to_cc(on)))
        self._add_slider(layout, "Scan delay", 0, 16, 0, lambda v: self.queue_cc(67, enum_to_cc(v, 5)))
        self._add_combo(
            layout,
            "Shifted lines",
            ["Single lines", "Groups of 2", "Groups of 4", "Groups of 8", "Groups of 16"],
            lambda i: self.queue_cc(90, enum_to_cc(i, 3)),
        )
        self._add_toggle(layout, "CRT darken", False, lambda on: self.queue_cc(91, gate_to_cc(on)))
        self._add_choice(
            layout,
            "With previous",
            ["Off", "OR", "AND", "XOR"],
            lambda i: self.queue_cc(68, enum_to_cc(i, 2)),
        )
        return group

    def _fx_smear_group(self):
        group = QGroupBox("Smear")
        layout = QVBoxLayout(group)
        layout.addWidget(QLabel("Repeat 0 is off. A channel above its threshold is drawn that many pixels in a row."))
        self._add_slider(layout, "Repeat", 0, 64, 0, lambda v: self.queue_cc(95, v))
        self._add_slider(layout, "R threshold", 0, 255, 128, lambda v: self.queue_cc(96, scale_to_cc(v, 255)))
        self._add_slider(layout, "G threshold", 0, 255, 128, lambda v: self.queue_cc(97, scale_to_cc(v, 255)))
        self._add_slider(layout, "B threshold", 0, 255, 128, lambda v: self.queue_cc(98, scale_to_cc(v, 255)))
        return group

    def _fx_bitplane_group(self):
        group = QGroupBox("Bit plane")
        layout = QVBoxLayout(group)
        layout.addWidget(QLabel("Bypass on keeps the full 8-bit channel."))
        self._add_toggle(layout, "R bypass", True, lambda on: self.queue_cc(69, gate_to_cc(on)))
        self._add_slider(layout, "R bit", 0, 7, 0, lambda v: self.queue_cc(70, enum_to_cc(v, 3)))
        self._add_toggle(layout, "G bypass", True, lambda on: self.queue_cc(71, gate_to_cc(on)))
        self._add_slider(layout, "G bit", 0, 7, 0, lambda v: self.queue_cc(72, enum_to_cc(v, 3)))
        self._add_toggle(layout, "B bypass", True, lambda on: self.queue_cc(73, gate_to_cc(on)))
        self._add_slider(layout, "B bit", 0, 7, 0, lambda v: self.queue_cc(74, enum_to_cc(v, 3)))
        return group

    def _fx_dither_group(self):
        group = QGroupBox("Dither")
        layout = QVBoxLayout(group)
        self._add_toggle(layout, "Enable", False, lambda on: self.queue_cc(75, gate_to_cc(on)))
        self._add_choice(
            layout,
            "Depth",
            ["6-bit", "5-bit", "4-bit", "3-bit"],
            lambda i: self.queue_cc(76, enum_to_cc(i, 2)),
        )
        self._add_combo(
            layout,
            "Posterize",
            ["Off", "7-bit", "6-bit", "5-bit", "4-bit", "3-bit", "2-bit", "1-bit"],
            lambda i: self.queue_cc(89, enum_to_cc(i, 3)),
        )
        return group

    def _fx_mirror_group(self):
        group = QGroupBox("Horizontal mirror")
        layout = QVBoxLayout(group)
        self._add_toggle(layout, "Enable", False, lambda on: self.queue_cc(77, gate_to_cc(on)))
        self._add_slider(layout, "Half width", 0, 960, 360, lambda v: self.send_u14(78, 79, v))
        return group

    def _fx_chromatic_group(self):
        group = QGroupBox("Chromatic aberration")
        layout = QVBoxLayout(group)
        self._add_toggle(layout, "Enable", False, lambda on: self.queue_cc(80, gate_to_cc(on)))
        self._add_slider(layout, "Green delay", 0, 32, 0, lambda v: self.queue_cc(81, enum_to_cc(v, 6)))
        self._add_slider(layout, "Blue delay", 0, 32, 0, lambda v: self.queue_cc(82, enum_to_cc(v, 6)))
        return group

    def _fx_emboss_group(self):
        group = QGroupBox("Emboss and shadow")
        layout = QVBoxLayout(group)
        layout.addWidget(QLabel("Threshold 0 and strength 0 use the hardware defaults (32 and 80)."))
        self._add_toggle(layout, "Emboss", False, lambda on: self.queue_cc(83, gate_to_cc(on)))
        self._add_toggle(layout, "Shadow", False, lambda on: self.queue_cc(84, gate_to_cc(on)))
        self._add_slider(layout, "Threshold", 0, 255, 0, lambda v: self.queue_cc(85, scale_to_cc(v, 255)))
        self._add_slider(layout, "Strength", 0, 255, 0, lambda v: self.queue_cc(86, scale_to_cc(v, 255)))
        self._add_toggle(layout, "Color fringe", False, lambda on: self.queue_cc(87, gate_to_cc(on)))
        self._add_combo(
            layout,
            "Fringe color",
            [
                "Black", "Grey", "White", "Red", "Green", "Blue",
                "Yellow", "Cyan", "Magenta", "Orange", "Rose",
                "Purple", "Lime", "Teal", "Brown", "Dark grey",
            ],
            lambda i: self.queue_cc(88, enum_to_cc(i, 4)),
        )
        return group

    def _osc_group(self, title, base_cc):
        group = QGroupBox(title)
        layout = QVBoxLayout(group)
        self._add_slider(layout, "Frequency", 0, 16383, 0, lambda v, cc=base_cc: self.send_u14(cc, cc + 1, v))
        self._add_slider(layout, "Derivative", 0, 127, 0, lambda v, cc=base_cc + 2: self.queue_cc(cc, v))
        self._add_slider(layout, "PWM duty (°)", 0, 360, 0, lambda v, cc=base_cc + 3: self.queue_cc(cc, scale_to_cc(v, 360)))
        self._add_choice(layout, "Wave", ["Sine", "Ramp up", "Ramp down", "Triangle"],
                         lambda i, cc=base_cc + 4: self.queue_cc(cc, enum_to_cc(i, 2)))
        self._add_choice(layout, "Sync", ["0", "1", "2", "3"],
                         lambda i, cc=base_cc + 5: self.queue_cc(cc, enum_to_cc(i, 2)))
        self._add_toggle(layout, "Speed", False, lambda on, cc=base_cc + 6: self.queue_cc(cc, gate_to_cc(on)))
        self._add_slider(layout, "Alpha", 0, 4095, 0, lambda v, cc=base_cc + 7: self.queue_cc(cc, scale_to_cc(v, 4095)))
        return group

    def _noise_group(self):
        group = QGroupBox("Noise")
        layout = QVBoxLayout(group)
        self._add_slider(layout, "Frequency", 0, 16383, 0, lambda v: self.send_u14(17, 18, v))
        self._add_slider(layout, "Slew", 0, 7, 0, lambda v: self.queue_cc(19, enum_to_cc(v, 3)))
        self._add_slider(layout, "Slowdown", 0, 3, 0, lambda v: self.queue_cc(20, enum_to_cc(v, 2)))
        self._add_toggle(layout, "Recycle", False, lambda on: self.queue_cc(21, gate_to_cc(on)))
        self._add_slider(layout, "Alpha", 0, 4095, 0, lambda v: self.queue_cc(22, scale_to_cc(v, 4095)))
        self._add_toggle(layout, "Reset", False, lambda on: self.queue_cc(37, gate_to_cc(on)))
        return group

    def _audio_group(self):
        group = QGroupBox("Audio")
        layout = QVBoxLayout(group)
        self._add_slider(layout, "Crossover", 0, 255, 0, lambda v: self.queue_cc(23, scale_to_cc(v, 255)))
        self._add_slider(layout, "T thresh", 0, 7, 0, lambda v: self.queue_cc(24, enum_to_cc(v, 3)))
        self._add_slider(layout, "B thresh", 0, 7, 0, lambda v: self.queue_cc(25, enum_to_cc(v, 3)))
        return group

    def _yuv_group(self):
        group = QGroupBox("YUV")
        layout = QVBoxLayout(group)
        self._add_slider(layout, "Y", 0, 4095, 0, lambda v: self.send_u12(26, 27, v))
        self._add_slider(layout, "Cr", 0, 4095, 0, lambda v: self.send_u12(28, 29, v))
        self._add_slider(layout, "Cb", 0, 4095, 0, lambda v: self.send_u12(30, 31, v))
        self._add_slider(layout, "Span", 0, 255, 0, lambda v: self.queue_cc(58, scale_to_cc(v, 255)))
        return group

    def _digital_group(self):
        group = QGroupBox("Digital")
        layout = QVBoxLayout(group)
        self._add_choice(layout, "Edge width", ["2 px", "4 px", "6 px", "8 px"],
                         lambda i: self.queue_cc(32, enum_to_cc(i, 2)))
        self._add_toggle(layout, "Slow-cnt frame", False, lambda on: self.queue_cc(33, gate_to_cc(on)))
        self._add_toggle(layout, "Slow-cnt /4", False, lambda on: self.queue_cc(34, gate_to_cc(on)))
        self._add_slider(layout, "CA rule", 0, 127, 30, lambda v: self.queue_cc(35, v))
        self._add_toggle(layout, "Classic mode", False, lambda on: self.queue_cc(36, gate_to_cc(on)))
        return group

    def _shape_group(self, title, base_cc):
        group = QGroupBox(title)
        layout = QVBoxLayout(group)
        names = (
            "Position H",
            "Position V",
            "Zoom H",
            "Zoom V",
            "Circle",
            "Gear",
            "Lantern",
            "Fizz",
        )
        for i, name in enumerate(names):
            self._add_slider(
                layout,
                name,
                0,
                1000,
                0,
                lambda v, cc=base_cc + i: self.queue_cc(cc, scale_to_cc(v, 1000)),
            )
        self._add_slider(
            layout,
            "Shape A",
            0,
            15,
            0,
            lambda v, cc=base_cc + 8: self.queue_cc(cc, scale_to_cc(v, 15)),
        )
        self._add_slider(
            layout,
            "Shape B",
            0,
            15,
            0,
            lambda v, cc=base_cc + 9: self.queue_cc(cc, scale_to_cc(v, 15)),
        )
        return group

    def _add_slider(self, parent, label, lo, hi, initial, on_value):
        row = QWidget()
        layout = QHBoxLayout(row)
        layout.setContentsMargins(0, 0, 0, 0)
        name = QLabel(f"{label}:")
        name.setMinimumWidth(120)
        layout.addWidget(name)

        slider = QSlider(Qt.Horizontal)
        slider.setRange(lo, hi)
        slider.setValue(initial)
        slider.setMinimumWidth(180)

        box = QSpinBox()
        box.setRange(lo, hi)
        box.setValue(initial)
        box.setMinimumWidth(80)

        def from_slider(val):
            box.blockSignals(True)
            box.setValue(val)
            box.blockSignals(False)
            on_value(val)

        def from_box(val):
            slider.blockSignals(True)
            slider.setValue(val)
            slider.blockSignals(False)
            on_value(val)

        slider.valueChanged.connect(from_slider)
        box.valueChanged.connect(from_box)
        layout.addWidget(slider, 1)
        layout.addWidget(box)
        parent.addWidget(row)
        self._senders.append(lambda v=initial, fn=on_value, s=slider: fn(s.value()))

    def _add_choice(self, parent, label, names, on_index):
        row = QWidget()
        layout = QHBoxLayout(row)
        layout.setContentsMargins(0, 0, 0, 0)
        name = QLabel(f"{label}:")
        name.setMinimumWidth(120)
        layout.addWidget(name)

        group = QButtonGroup(row)
        group.setExclusive(True)
        buttons = []
        for i, text in enumerate(names):
            btn = QPushButton(text)
            btn.setCheckable(True)
            if i == 0:
                btn.setChecked(True)
            group.addButton(btn, i)
            layout.addWidget(btn)
            buttons.append(btn)

        def changed(id_):
            if group.button(id_).isChecked():
                on_index(id_)

        group.idClicked.connect(changed)
        parent.addWidget(row)
        self._senders.append(lambda fn=on_index, g=group: fn(g.checkedId() if g.checkedId() >= 0 else 0))

    def _add_combo(self, parent, label, names, on_index):
        row = QWidget()
        layout = QHBoxLayout(row)
        layout.setContentsMargins(0, 0, 0, 0)
        name = QLabel(f"{label}:")
        name.setMinimumWidth(120)
        layout.addWidget(name)
        combo = QComboBox()
        combo.addItems(names)
        combo.currentIndexChanged.connect(on_index)
        layout.addWidget(combo)
        parent.addWidget(row)
        self._senders.append(lambda fn=on_index, box=combo: fn(box.currentIndex()))

    def _add_toggle(self, parent, label, initial, on_toggle):
        row = QWidget()
        layout = QHBoxLayout(row)
        layout.setContentsMargins(0, 0, 0, 0)
        name = QLabel(f"{label}:")
        name.setMinimumWidth(120)
        layout.addWidget(name)
        btn = QPushButton("Off")
        btn.setCheckable(True)
        btn.setChecked(initial)
        if initial:
            btn.setText("On")

        def changed(on):
            btn.setText("On" if on else "Off")
            on_toggle(on)

        btn.toggled.connect(changed)
        layout.addWidget(btn)
        layout.addStretch()
        parent.addWidget(row)
        self._senders.append(lambda fn=on_toggle, b=btn: fn(b.isChecked()))

    def log(self, text):
        self.log_text.append(text)

    def refresh_ports(self):
        self.port_combo.clear()
        if mido is None:
            self.port_combo.addItem("(mido missing — see log)")
            self.log(_MIDO_ERROR or "mido is not installed")
            return
        names = mido.get_output_names()
        if not names:
            self.port_combo.addItem("(no MIDI outputs)")
            return
        preferred = 0
        for i, name in enumerate(names):
            self.port_combo.addItem(name)
            if PREFERRED_PORT.lower() in name.lower():
                preferred = i
        self.port_combo.setCurrentIndex(preferred)

    def toggle_connection(self):
        if self.port is not None:
            self.disconnect_midi()
            return
        self.connect_midi()

    def connect_midi(self):
        if mido is None:
            QMessageBox.critical(
                self,
                "Missing package",
                _MIDO_ERROR or "mido is not installed",
            )
            return
        name = self.port_combo.currentText()
        if not name or name.startswith("("):
            QMessageBox.warning(self, "MIDI", "No MIDI output selected.")
            return
        try:
            self.port = mido.open_output(name)
        except Exception as exc:
            QMessageBox.critical(self, "MIDI", f"Failed to open {name}:\n{exc}")
            return
        self.connect_btn.setText("Disconnect")
        self.status_label.setText(f"Connected: {name}")
        self.status_label.setStyleSheet("color: green; font-weight: bold;")
        self.send_all_btn.setEnabled(True)
        self.log(f"Opened {name}")

    def disconnect_midi(self):
        self._flush_timer.stop()
        self._pending.clear()
        if self.port is not None:
            try:
                self.port.close()
            except Exception:
                pass
            self.port = None
        self.connect_btn.setText("Connect")
        self.status_label.setText("Not connected")
        self.status_label.setStyleSheet("color: red; font-weight: bold;")
        self.send_all_btn.setEnabled(False)
        self.log("Disconnected")

    def queue_cc(self, cc, value):
        self._pending[int(cc)] = max(0, min(127, int(value)))
        if not self._flush_timer.isActive():
            self._flush_timer.start()

    def send_u14(self, msb_cc, lsb_cc, value):
        msb, lsb = encode_u14(value)
        self.queue_cc(msb_cc, msb)
        self.queue_cc(lsb_cc, lsb)

    def send_u12(self, msb_cc, lsb_cc, value):
        msb, lsb = encode_u12(value)
        self.queue_cc(msb_cc, msb)
        self.queue_cc(lsb_cc, lsb)

    def _flush_midi(self):
        self._flush_timer.stop()
        pending = self._pending
        self._pending = {}
        if self.port is None or not pending:
            return
        for cc in sorted(pending):
            val = pending[cc]
            try:
                self.port.send(mido.Message(
                    "control_change",
                    channel=MIDI_CHANNEL,
                    control=cc,
                    value=val,
                ))
            except Exception as exc:
                self.log(f"Send error CC {cc}: {exc}")
                return
            self.log(f"CH1 CC {cc:2d} = {val}")

    def send_all(self):
        if self.port is None:
            return
        for fn in self._senders:
            fn()
        self._flush_midi()

    def send_sysex(self, data):
        if self.port is None or mido is None:
            return False
        self._flush_midi()
        try:
            self.port.send(mido.Message("sysex", data=data))
        except Exception as exc:
            self.log(f"SysEx error: {exc}")
            return False
        return True

    def matrix_set_cell(self, mat, out_idx, in_idx, on):
        name_in = digital_in_name(in_idx) if mat == MAT_DIGITAL else analog_in_name(in_idx)
        name_out = digital_out_name(out_idx) if mat == MAT_DIGITAL else analog_out_name(out_idx)
        status = "ON" if on else "OFF"
        if self.port is None:
            self.log(f"Matrix {status}: {name_in} -> {name_out} (not connected)")
            return False
        data = SYSEX_HDR + [0x20, mat, int(out_idx), int(in_idx), 1 if on else 0]
        if not self.send_sysex(data):
            return False
        self.log(f"Matrix {status}: {name_in} -> {name_out}")
        return True

    def matrix_reset_all(self, mat):
        kind = "digital" if mat == MAT_DIGITAL else "analog"
        if self.port is None:
            QMessageBox.warning(self, "Warning", "Not connected to MIDI")
            return False
        if not self.send_sysex(SYSEX_HDR + [0x21, mat, 127]):
            return False
        self.log(f"{kind.capitalize()} matrix reset")
        return True

    def closeEvent(self, event):
        self.disconnect_midi()
        event.accept()


def main():
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    app.setFont(QFont("Segoe UI", 9))
    window = MidiGUIApp()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
