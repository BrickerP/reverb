extends RefCounted


func test_soft_silhouettes_triangulate_and_have_no_hard_corners(c: Check) -> void:
	var style := InkStyleBox.new()
	for shape in InkStyleBox.Shape.values():
		style.shape = shape
		for size in [Vector2(18.0, 18.0), Vector2(160.0, 40.0),
				Vector2(252.0, 332.0), Vector2(1176.0, 650.0)]:
			var rect := Rect2(Vector2.ZERO, size)
			var points := style.outline(rect)
			c.ok(points.size() >= 32, "silhouette is a sampled curve, not a four-corner box")
			c.ok(not Geometry2D.triangulate_polygon(points).is_empty(), "visible soft face is a valid filled polygon")
			c.ok(style.test_mask(size * 0.5, rect), "centre of every silhouette remains clickable")
			c.ok(not style.test_mask(Vector2.ZERO, rect), "transparent outer corner is not part of the face")
			var sharpest := 0.0
			for index in points.size():
				var incoming := points[index] - points[(index - 1 + points.size()) % points.size()]
				var outgoing := points[(index + 1) % points.size()] - points[index]
				c.ok(points[index].is_finite(), "outline contains no non-finite vertex")
				sharpest = maxf(sharpest, absf(incoming.angle_to(outgoing)))
			c.ok(sharpest < deg_to_rad(55.0), "sampled curve has no sharp right-angle turns")


func test_variants_are_stable_without_moving_the_content_rect(c: Check) -> void:
	var style := InkStyleBox.new()
	var rect := Rect2(20.0, 40.0, 180.0, 56.0)
	style.variant = 2
	var first := style.outline(rect)
	c.eq(style.outline(rect), first, "a still control never jitters between redraws")
	style.variant = 7
	c.ok(style.outline(rect) != first, "distinct paper scraps have a distinct authored curve")
	c.ok(style.test_mask(rect.get_center(), rect), "shape variation keeps the centre hit region usable")
	c.eq(rect, Rect2(20.0, 40.0, 180.0, 56.0), "drawing never rewrites layout geometry")


func test_tiny_and_invalid_sizes_do_not_submit_degenerate_shapes(c: Check) -> void:
	var style := InkStyleBox.new()
	for size in [Vector2.ZERO, Vector2(-1.0, 20.0), Vector2(20.0, -1.0),
			Vector2(0.00001, 20.0), Vector2(NAN, 20.0), Vector2(INF, 20.0)]:
		c.ok(style.outline(Rect2(Vector2.ZERO, size)).is_empty(), "invalid or subpixel shape has no vertices")
		style._draw(RID(), Rect2(Vector2.ZERO, size))
	for shape in InkStyleBox.Shape.values():
		style.shape = shape
		for size in [Vector2(1.0, 40.0), Vector2(40.0, 1.0), Vector2(1.0, 1.0)]:
			var points := style.outline(Rect2(Vector2.ZERO, size))
			c.ok(not Geometry2D.triangulate_polygon(points).is_empty(), "thin slider and scrollbar shapes stay valid")


func test_render_mesh_uses_local_coordinates_and_updates_on_resize(c: Check) -> void:
	var style := InkStyleBox.new()
	var canvas := RenderingServer.canvas_item_create()
	style._draw(canvas, Rect2(1000000.0, 1000000.0, 48.0, 36.0))
	c.ok(not style._mesh_triangles.is_empty(), "large canvas offsets do not break local triangulation")
	c.eq(style._mesh_size, Vector2(48.0, 36.0), "mesh cache stores size rather than absolute position")
	style.bg_color = Color("4d6045")
	style._draw(canvas, Rect2(5.0, 8.0, 48.0, 36.0))
	c.eq(style._mesh_size, Vector2(48.0, 36.0), "colour and position preserve the reusable local mesh")
	style._draw(canvas, Rect2(5.0, 8.0, 240.0, 60.0))
	c.eq(style._mesh_size, Vector2(240.0, 60.0), "resizing regenerates the correct silhouette")
	RenderingServer.free_rid(canvas)


func test_duplicate_preserves_hand_drawn_shape_and_padding(c: Check) -> void:
	var original := InkStyleBox.new()
	original.shape = InkStyleBox.Shape.BLOB
	original.variant = 6
	original.bg_color = Color("c9bea1")
	original.content_margin_left = 17.0
	original.set_border_width_all(3.0)
	var copy := original.duplicate() as InkStyleBox
	c.eq(copy.shape, original.shape, "panel duplication preserves the organic shape")
	c.eq(copy.variant, original.variant, "panel duplication preserves its hand-drawn variant")
	c.eq(copy.bg_color, original.bg_color, "panel duplication preserves its fill")
	c.eq(copy.get_margin(SIDE_LEFT), 17.0, "duplicated panels preserve content padding")
	c.eq(copy.get_border_width_min(), 3.0, "duplicated focus marks retain ink weight")
	c.eq(copy.outline(Rect2(0, 0, 160, 80)), original.outline(Rect2(0, 0, 160, 80)),
			"duplicate draws the same silhouette before independent changes")
	copy.variant = 7
	c.ok(copy.outline(Rect2(0, 0, 160, 80)) != original.outline(Rect2(0, 0, 160, 80)),
			"one panel's variation does not mutate another panel")


func test_scroll_grip_is_a_small_mark_without_shrinking_its_drag_target(c: Check) -> void:
	var style := InkStyleBox.new()
	var minimum := style.get_minimum_size()
	style.grip_mark = true
	for rect in [Rect2(0, 0, 24, 240), Rect2(0, 0, 240, 24)]:
		var mark := style.visual_rect(rect)
		c.ok(rect.encloses(mark), "small ink mark remains inside the native grabber")
		c.ok(maxf(mark.size.x, mark.size.y) <= 27.0, "visible grip cannot become a long system thumb")
		c.eq(mark.get_center(), rect.get_center(), "mark follows the native thumb position")
		c.ok(style.test_mask(rect.position + Vector2(4.0, 4.0), rect),
				"native drag rectangle stays usable outside the small visible mark")
	c.eq(style.get_minimum_size(), minimum, "grip styling does not change native layout or hit dimensions")
