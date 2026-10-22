GODOT ?= godot

.PHONY: import test smoke perf frames ui-shots run run-zh

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
