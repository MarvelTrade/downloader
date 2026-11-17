import os
import re
import subprocess
import sys
from pathlib import Path

from PySide6.QtCore import Qt, QThread, Signal
from PySide6.QtGui import QFont
from PySide6.QtWidgets import (
    QApplication,
    QComboBox,
    QFileDialog,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMainWindow,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QVBoxLayout,
    QWidget,
)


def resource_bin(name: str) -> str:
    if hasattr(sys, "_MEIPASS"):
        candidate = Path(sys._MEIPASS) / "bin" / name
        if candidate.exists():
            return str(candidate)
    local = Path(__file__).resolve().parent / "bin" / name
    if local.exists():
        return str(local)
    return name


class DownloadWorker(QThread):
    progress = Signal(int, str)
    finished_ok = Signal(str)
    failed = Signal(str)

    def __init__(self, url: str, out_dir: Path, quality: str):
        super().__init__()
        self.url = url
        self.out_dir = out_dir
        self.quality = quality
        self._proc = None
        self._cancelled = False

    def cancel(self):
        self._cancelled = True
        if self._proc and self._proc.poll() is None:
            self._proc.terminate()

    def run(self):
        ytdlp = resource_bin("yt-dlp.exe" if os.name == "nt" else "yt-dlp")
        ffmpeg = resource_bin("ffmpeg.exe" if os.name == "nt" else "ffmpeg")
        self.out_dir.mkdir(parents=True, exist_ok=True)

        cmd = [
            ytdlp,
            "--no-playlist",
            "--newline",
            "--ffmpeg-location",
            str(Path(ffmpeg).parent) if Path(ffmpeg).exists() else "",
            "-o",
            str(self.out_dir / "%(title).120s [%(id)s].%(ext)s"),
        ]
        # Remove empty --ffmpeg-location if system ffmpeg is used
        if cmd[4] == "":
            del cmd[3:5]

        if self.quality == "MP3 (только аудио)":
            cmd += ["-x", "--audio-format", "mp3", "--audio-quality", "0"]
        elif self.quality == "1080p MP4":
            cmd += ["-f", "bv*[height<=1080][ext=mp4]+ba[ext=m4a]/b[height<=1080][ext=mp4]/bv*[height<=1080]+ba/b", "--merge-output-format", "mp4"]
        elif self.quality == "720p MP4":
            cmd += ["-f", "bv*[height<=720][ext=mp4]+ba[ext=m4a]/b[height<=720][ext=mp4]/bv*[height<=720]+ba/b", "--merge-output-format", "mp4"]
        else:
            cmd += ["-f", "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b", "--merge-output-format", "mp4"]

        cmd.append(self.url)

        creationflags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
        try:
            self._proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                creationflags=creationflags,
            )
            last_lines = []
            for line in self._proc.stdout:
                if self._cancelled:
                    break
                line = line.strip()
                if line:
                    last_lines.append(line)
                    last_lines = last_lines[-15:]
                m = re.search(r"(\d+(?:\.\d+)?)%", line)
                if m:
                    pct = int(float(m.group(1)))
                    self.progress.emit(min(pct, 99), line[:90])
                elif "[Merger]" in line or "[ExtractAudio]" in line:
                    self.progress.emit(99, "Финальная сборка файла…")

            rc = self._proc.wait()
            if self._cancelled:
                self.failed.emit("Загрузка отменена")
            elif rc == 0:
                self.progress.emit(100, "Готово!")
                self.finished_ok.emit(f"Сохранено в {self.out_dir}")
            else:
                self.failed.emit("\n".join(last_lines[-4:]) or f"Ошибка yt-dlp (код {rc})")
        except Exception as e:
            self.failed.emit(str(e))


class DownloaderWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Загрузчик видео — Антон Белый")
        self.resize(780, 520)
        self.out_dir = Path.home() / "Downloads" / "Загрузчик"
        self.worker = None

        self.setStyleSheet("""
            QMainWindow, QWidget { background-color: #0b0e14; color: #f8fafc; font-family: 'Segoe UI', sans-serif; }
            QLineEdit, QComboBox, QListWidget {
                background-color: #131824; border: 1px solid rgba(255,255,255,0.12);
                border-radius: 8px; padding: 9px 12px; color: #f8fafc; font-size: 13px;
            }
            QLineEdit:focus { border-color: #f59e0b; }
            QPushButton {
                background-color: #1e2638; border: 1px solid rgba(255,255,255,0.12);
                border-radius: 8px; padding: 9px 16px; color: #f8fafc; font-weight: 600;
            }
            QPushButton:hover { background-color: #273147; }
            QPushButton#primaryBtn { background-color: #f59e0b; color: #0b0e14; border: none; }
            QPushButton#primaryBtn:hover { background-color: #fbbf24; }
            QPushButton#primaryBtn:disabled { background-color: #475569; color: #94a3b8; }
            QProgressBar {
                background-color: #131824; border: 1px solid rgba(255,255,255,0.08);
                border-radius: 6px; text-align: center; height: 20px;
            }
            QProgressBar::chunk { background-color: #f59e0b; border-radius: 5px; }
        """)

        root = QWidget()
        self.setCentralWidget(root)
        layout = QVBoxLayout(root)
        layout.setContentsMargins(24, 22, 24, 16)
        layout.setSpacing(14)

        title = QLabel("Загрузчик видео")
        title.setFont(QFont("Segoe UI", 20, QFont.Bold))
        subtitle = QLabel("YouTube, VK Видео, Instagram, TikTok, RuTube, Одноклассники · без рекламы и облаков")
        subtitle.setStyleSheet("color: #94a3b8; font-size: 13px;")
        layout.addWidget(title)
        layout.addWidget(subtitle)

        url_row = QHBoxLayout()
        self.url_input = QLineEdit()
        self.url_input.setPlaceholderText("Вставьте ссылку на видео (https://...) и нажмите «Скачать»")
        self.url_input.returnPressed.connect(self.start_download)

        self.quality_box = QComboBox()
        self.quality_box.addItems(["Лучшее качество MP4", "1080p MP4", "720p MP4", "MP3 (только аудио)"])
        self.quality_box.setFixedWidth(185)

        self.dl_btn = QPushButton("⬇ Скачать")
        self.dl_btn.setObjectName("primaryBtn")
        self.dl_btn.setFixedWidth(130)
        self.dl_btn.clicked.connect(self.start_download)

        url_row.addWidget(self.url_input)
        url_row.addWidget(self.quality_box)
        url_row.addWidget(self.dl_btn)
        layout.addLayout(url_row)

        dir_row = QHBoxLayout()
        self.dir_label = QLabel(f"Папка: {self.out_dir}")
        self.dir_label.setStyleSheet("color: #94a3b8; font-size: 12px;")
        choose_btn = QPushButton("Выбрать папку…")
        choose_btn.clicked.connect(self.choose_folder)
        open_btn = QPushButton("Открыть папку")
        open_btn.clicked.connect(self.open_folder)
        dir_row.addWidget(self.dir_label, 1)
        dir_row.addWidget(choose_btn)
        dir_row.addWidget(open_btn)
        layout.addLayout(dir_row)

        self.progress_bar = QProgressBar()
        self.progress_bar.setValue(0)
        self.status_label = QLabel("Готов к загрузке")
        self.status_label.setStyleSheet("color: #cbd5e1; font-size: 12px;")

        prog_row = QHBoxLayout()
        prog_row.addWidget(self.progress_bar, 1)
        self.cancel_btn = QPushButton("Отмена")
        self.cancel_btn.setEnabled(False)
        self.cancel_btn.clicked.connect(self.cancel_download)
        prog_row.addWidget(self.cancel_btn)
        layout.addLayout(prog_row)
        layout.addWidget(self.status_label)

        hist_label = QLabel("История текущей сессии")
        hist_label.setStyleSheet("color: #94a3b8; font-size: 12px; font-weight: 600; margin-top: 6px;")
        layout.addWidget(hist_label)

        self.history_list = QListWidget()
        layout.addWidget(self.history_list, 1)

        footer = QLabel("Антон Белый")
        footer.setAlignment(Qt.AlignCenter)
        footer.setStyleSheet("color: #64748b; font-size: 11px;")
        layout.addWidget(footer)

    def choose_folder(self):
        folder = QFileDialog.getExistingDirectory(self, "Выберите папку для сохранения", str(self.out_dir))
        if folder:
            self.out_dir = Path(folder)
            self.dir_label.setText(f"Папка: {self.out_dir}")

    def open_folder(self):
        self.out_dir.mkdir(parents=True, exist_ok=True)
        if os.name == "nt":
            os.startfile(str(self.out_dir))
        else:
            subprocess.Popen(["open", str(self.out_dir)])

    def start_download(self):
        url = self.url_input.text().strip()
        if not url:
            return
        if not url.startswith(("http://", "https://")):
            url = "https://" + url
        self.dl_btn.setEnabled(False)
        self.cancel_btn.setEnabled(True)
        self.progress_bar.setValue(0)
        self.status_label.setText("Запуск загрузки…")

        self.worker = DownloadWorker(url, self.out_dir, self.quality_box.currentText())
        self.worker.progress.connect(self.on_progress)
        self.worker.finished_ok.connect(lambda msg: self.on_done(url, True, msg))
        self.worker.failed.connect(lambda msg: self.on_done(url, False, msg))
        self.worker.start()

    def cancel_download(self):
        if self.worker:
            self.worker.cancel()

    def on_progress(self, pct: int, text: str):
        self.progress_bar.setValue(pct)
        self.status_label.setText(text)

    def on_done(self, url: str, ok: bool, msg: str):
        self.dl_btn.setEnabled(True)
        self.cancel_btn.setEnabled(False)
        if ok:
            self.progress_bar.setValue(100)
            self.status_label.setText("✅ " + msg)
            self.history_list.insertItem(0, QListWidgetItem(f"✅ {url}"))
            self.url_input.clear()
        else:
            self.status_label.setText("❌ Ошибка")
            self.history_list.insertItem(0, QListWidgetItem(f"❌ {url} — {msg[:80]}"))
            QMessageBox.warning(self, "Загрузчик", msg)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    w = DownloaderWindow()
    w.show()
    sys.exit(app.exec())
