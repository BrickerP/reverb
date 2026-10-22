GODOT ?= godot

.PHONY: import test smoke perf frames run run-zh

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

run:
	$(GODOT) --path .

run-zh:
	REVERB_LANG=zh $(GODOT) --path .
