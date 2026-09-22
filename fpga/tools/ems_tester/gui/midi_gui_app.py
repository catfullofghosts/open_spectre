"""Open Spectre MIDI panel — Channel 1 CCs 1–35 via the Pico USB gadget."""

import sys

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
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

try:
    import mido
    _MIDO_ERROR = None
except ImportError as exc:
    mido = None
    _MIDO_ERROR = f"{exc}\nRunning: {sys.executable}\nInstall with:\n  {sys.executable} -m pip install mido python-rtmidi"

MIDI_CHANNEL = 0  # Channel 1
PREFERRED_PORT = "OPEN SPECTRE"


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
        self.setGeometry(80, 80, 1100, 720)

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
        midi_layout.addWidget(QLabel("Channel 1  ·  CCs 1–35"))

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

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        body = QWidget()
        body_layout = QHBoxLayout(body)
        col_a = QVBoxLayout()
        col_b = QVBoxLayout()

        col_a.addWidget(self._osc_group("Osc 1", 1))
        col_a.addWidget(self._osc_group("Osc 2", 9))
        col_a.addWidget(self._noise_group())
        col_a.addStretch()

        col_b.addWidget(self._audio_group())
        col_b.addWidget(self._yuv_group())
        col_b.addWidget(self._digital_group())
        col_b.addStretch()

        body_layout.addLayout(col_a)
        body_layout.addLayout(col_b)
        scroll.setWidget(body)
        layout.addWidget(scroll, 1)

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
        return group

    def _digital_group(self):
        group = QGroupBox("Digital")
        layout = QVBoxLayout(group)
        self._add_choice(layout, "Edge width", ["2 px", "4 px", "6 px", "8 px"],
                         lambda i: self.queue_cc(32, enum_to_cc(i, 2)))
        self._add_toggle(layout, "Slow-cnt frame", False, lambda on: self.queue_cc(33, gate_to_cc(on)))
        self._add_toggle(layout, "Slow-cnt /4", False, lambda on: self.queue_cc(34, gate_to_cc(on)))
        self._add_slider(layout, "CA rule", 0, 127, 30, lambda v: self.queue_cc(35, v))
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
