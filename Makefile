GODOT ?= godot

.PHONY: import test smoke perf frames ui-shots run run-zh export

import:
	$(GODOT) --headless --path . --import

test: import
	./tools/test.sh

smoke: import
	./tools/smoke.sh

perf: import
	$(GODOT) --headless --path . --script res://tools/perf.gd

frames: import
	$(GODOT) --path . --fixed-fps 60 --disable-vsync --script res://tools/frame_probe.gd

ui-shots: import
	$(GODOT) --path . --fixed-fps 60 --disable-vsync --script res://tools/ui_shots.gd

run:
	$(GODOT) --path .

run-zh:
	REVERB_LANG=zh $(GODOT) --path .

export: import
	mkdir -p export/macos export/windows export/linux
	$(GODOT) --headless --path . --export-release "macOS" export/macos/Reverb.zip
	$(GODOT) --headless --path . --export-release "Windows" export/windows/Reverb.exe
	cd export/windows && zip -9 -q Reverb-windows.zip Reverb.exe Reverb.pck
	$(GODOT) --headless --path . --export-release "Linux" export/linux/Reverb.x86_64
	cd export/linux && zip -9 -q Reverb-linux.zip Reverb.x86_64 Reverb.pck
