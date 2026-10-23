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
	$(GODOT) --headless --path . --export-release "macOS" export/macos/TakeStack.zip
	zip -j -q export/macos/TakeStack.zip assets/fonts/OFL.txt
	$(GODOT) --headless --path . --export-release "Windows" export/windows/TakeStack.exe
	cp assets/fonts/OFL.txt export/windows/NotoSansCJKsc-OFL.txt
	cd export/windows && zip -9 -q TakeStack-windows.zip TakeStack.exe TakeStack.pck NotoSansCJKsc-OFL.txt
	$(GODOT) --headless --path . --export-release "Linux" export/linux/TakeStack.x86_64
	cp assets/fonts/OFL.txt export/linux/NotoSansCJKsc-OFL.txt
	cd export/linux && zip -9 -q TakeStack-linux.zip TakeStack.x86_64 TakeStack.pck NotoSansCJKsc-OFL.txt
