extends RefCounted


func _root() -> Window:
	return Engine.get_main_loop().root


func test_feedback_form_validates_and_preserves_failed_note(c: Check) -> void:
	var ui := FeedbackUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open_for_run("fixture-run-123", true, false)
	c.eq(ui.category_option.item_count, 6, "all feedback categories are available")
	c.eq(ui.rating_option.item_count, 3, "all feedback feelings are available")
	c.ok(ui.category_option.has_focus(), "feedback starts on category")
	c.ok(not ui.save_button.disabled, "saved run can submit feedback")
	c.ok(ui.note_edit.focus_next != NodePath() and ui.note_edit.focus_previous != NodePath(),
			"note participates in the full Tab cycle")
	c.ok(not ui.note_edit.tab_input_mode, "physical Tab leaves the note editor for modal traversal")
	c.ok(ui.note_edit.focus_neighbor_left == NodePath()
			and ui.note_edit.focus_neighbor_right == NodePath()
			and ui.note_edit.focus_neighbor_top == NodePath()
			and ui.note_edit.focus_neighbor_bottom == NodePath(),
			"note keeps native caret-direction navigation")
	ui.note_edit.text = "x".repeat(FeedbackUi.MAX_NOTE_LENGTH + 1)
	ui.note_edit.text_changed.emit()
	c.ok(ui.save_button.disabled, "overlong note blocks submission")
	var note := "回响路线很清楚 — retry text"
	ui.note_edit.text = note
	ui.note_edit.text_changed.emit()
	var submissions: Array[Dictionary] = []
	ui.submit_requested.connect(func(category: StringName, rating: StringName, text: String) -> void:
		submissions.append({"category": category, "rating": rating, "note": text}))
	ui.save_button.pressed.emit()
	c.eq(submissions.size(), 1, "save emits one submission")
	c.eq(submissions[0]["note"], note, "Unicode note is submitted unchanged")
	ui.set_submission_result({"ok": false, "reason": "write_failed", "record": {}})
	c.eq(ui.note_edit.text, note, "write failure retains the note for retry")
	c.ok(not ui.save_button.disabled, "write failure remains retryable")
	ui.set_submission_result({"ok": true, "reason": "", "record": {"run_id": "fixture-run-123"}})
	c.ok(ui.save_button.disabled and ui.open_log_button.visible,
			"success disables duplicate save and exposes the local folder")
	c.ok(ui.category_option.disabled and ui.rating_option.disabled and not ui.note_edit.editable,
			"saved feedback becomes a read-only snapshot")
	c.ok(ui.open_log_button.has_focus(), "saved feedback focuses an available action")
	c.ok(ui.open_log_button.focus_next != NodePath() and ui.cancel_button.focus_next != NodePath(),
			"read-only feedback cycles between folder and close actions")
	ui.free()


func test_feedback_reset_and_duplicate_state_are_safe(c: Check) -> void:
	var ui := FeedbackUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open_for_run("fixture-run-456", true, true)
	c.ok(ui.save_button.disabled, "duplicate run cannot submit twice")
	c.ok(ui.status_label.visible, "duplicate state is explained")
	c.ok(ui.category_option.disabled and ui.rating_option.disabled and not ui.note_edit.editable,
			"duplicate feedback reopens read-only")
	c.ok(ui.open_log_button.has_focus(), "duplicate state keeps folder and close traversal available")
	ui.note_edit.text = "temporary" # Programmatic fixture mutation; players cannot edit the field.
	ui.reset()
	c.ok(not ui.visible and ui.note_edit.text.is_empty(), "new-run reset clears modal state")
	ui.open_for_run("", false, false)
	c.ok(ui.save_button.disabled, "missing saved run keeps feedback unavailable")
	ui.reset()
	c.ok(not ui.category_option.disabled and not ui.rating_option.disabled and ui.note_edit.editable,
			"reset restores editing for the next recorded run")
	ui.free()
