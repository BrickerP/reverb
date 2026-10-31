class_name UiTheme
extends RefCounted

# The game ships Noto Sans CJK SC so Windows, Linux and Steam Deck do not depend on a
# system CJK font. The system list remains a fallback for stripped-down builds.
# PingFang SC is deliberately late in the list: the engine loads the first face of PingFang.ttc
# on macOS, which is the Hong Kong one and lacks simplified-only glyphs such as 杀.
const BUNDLED_FONT := "res://assets/fonts/NotoSansCJKsc-Regular.otf"
const TITLE_EN := "res://assets/fonts/AmaticSC-Bold.ttf"
const TITLE_ZH := "res://assets/fonts/ZCOOLKuaiLe-Regular.ttf"
const FONT_NAMES: Array[String] = [
	"Hiragino Sans GB", "Noto Sans CJK SC", "Source Han Sans SC", "Microsoft YaHei",
	"WenQuanYi Micro Hei", "PingFang SC", "sans-serif",
]
const INK := Color("292720")
const DIM := Color("605d50")
const ACCENT := Color("4d6045")
const WARN := Color("a33d32")
const COIN := Color("805522")
const ECHO := Color("6a5374")
const PAPER := Color("e5d8b8")
const CARD := Color("f5e8c7")
const SURFACE := Color("c9bea1")
const EDGE := Color("28261f")

static var _font: Font
static var _title_font: FontVariation
static var _title_zh_font: FontVariation
static var _control_icons: Dictionary = {}


static func font() -> Font:
	if _font != null:
		return _font
	var bundled := load(BUNDLED_FONT) as Font
	if bundled != null:
		_font = bundled
	else:
		var system := SystemFont.new()
		system.font_names = PackedStringArray(FONT_NAMES)
		_font = system
	return _font


static func title_font(text: String = "") -> FontVariation:
	var use_chinese := Loc.lang == "zh"
	if not text.is_empty():
		use_chinese = false
		for index in text.length():
			var code := text.unicode_at(index)
			if code >= 0x2e80 and code <= 0x9fff:
				use_chinese = true
				break
	var cached := _title_zh_font if use_chinese else _title_font
	if cached != null:
		return cached
	var title := FontVariation.new()
	title.base_font = load(TITLE_ZH if use_chinese else TITLE_EN) as Font
	var alternate := load(TITLE_EN if use_chinese else TITLE_ZH) as Font
	var alternatives: Array[Font] = [alternate, font()]
	title.fallbacks = alternatives
	title.variation_embolden = 0.0 if use_chinese else 0.35
	title.spacing_glyph = 0 if use_chinese else 1
	if use_chinese:
		_title_zh_font = title
	else:
		_title_font = title
	return title

static func label(text: String, size: int = 18, color: Color = INK,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size >= 28:
		l.add_theme_font_override("font", title_font(text))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


static func art_icon(key: StringName, icon_size: Vector2 = Vector2(48.0, 32.0)) -> TextureRect:
	var icon := TextureRect.new()
	var texture := PresentationAssets.texture(key)
	var visible := PresentationAssets.idle_region(key)
	if texture != null and visible.has_area():
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = visible
		icon.texture = atlas
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.custom_minimum_size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_meta(&"presentation_key", key)
	return icon


static func weapon_icon(weapon: WeaponDef, icon_size: Vector2 = Vector2(48.0, 32.0)) -> TextureRect:
	return art_icon(PresentationAssets.weapon_key(weapon), icon_size)


static func item_icon(item: ItemDef, icon_size: Vector2 = Vector2(36.0, 36.0)) -> TextureRect:
	return art_icon(PresentationAssets.item_key(item), icon_size)


static func character_icon(id: StringName, icon_size: Vector2 = Vector2(72.0, 84.0)) -> TextureRect:
	return art_icon(PresentationAssets.character_key(id), icon_size)


static func cartridge_icon(icon_size: Vector2 = Vector2(72.0, 48.0)) -> TextureRect:
	return art_icon(&"recording_cartridge", icon_size)


static func surface_panel() -> InkStyleBox:
	# A screen owns its sheet; changing its silhouette cannot change another modal.
	var style := paper_panel(PAPER)
	style.softness = 34.0
	style.set_border_width_all(3.0)
	style.variant = 3
	style.sketch = true
	style.content_margin_left = 16.0
	style.content_margin_top = 14.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 14.0
	return style

static func box(fill: Color, border: Color, border_width: int = 2, radius: int = 6) -> InkStyleBox:
	var style := InkStyleBox.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.softness = clampf(14.0 + float(radius) * 0.9, 14.0, 30.0)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


static func paper_panel(fill: Color = CARD) -> InkStyleBox:
	var style := box(fill, EDGE, 2, 18)
	style.shadow_color = Color(EDGE, 0.14)
	style.shadow_offset = Vector2(1.5, 2.0)
	return style

static func section_label(text: String, size: int = 20, color: Color = INK) -> Label:
	var title := label(text, size, color)
	title.add_theme_font_override("font", title_font(text))
	title.add_theme_constant_override("outline_size", 0)
	return title


static func stamp_button(button: Button, color: Color = ACCENT) -> void:
	var normal := paper_panel(color)
	normal.shape = InkStyleBox.Shape.TAG
	normal.variant = 4
	var hover := paper_panel(color.lightened(0.07))
	hover.shape = InkStyleBox.Shape.TAG
	hover.variant = 5
	var pressed := box(color.darkened(0.12), EDGE, 3, 16)
	pressed.shape = InkStyleBox.Shape.TAG
	pressed.variant = 6
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", CARD)
	button.add_theme_color_override("font_hover_color", CARD)
	button.add_theme_color_override("font_pressed_color", CARD)
	button.add_theme_color_override("font_focus_color", CARD)
	button.add_theme_color_override("font_hover_pressed_color", CARD)


static func character_color(id: StringName) -> Color:
	match id:
		&"solo": return WARN
		&"mirror": return ECHO
		&"conductor": return ACCENT
	return COIN


static func animate_open(control: Control, reduced: bool = false) -> void:
	# Alpha-only: layout, focus and input remain usable for the whole transition.
	if control.has_meta(&"paper_open_tween"):
		var old: Tween = control.get_meta(&"paper_open_tween")
		if old != null and old.is_valid():
			old.kill()
	control.modulate = Color.WHITE
	if reduced:
		return
	control.modulate.a = 0.0
	var tween := control.create_tween()
	control.set_meta(&"paper_open_tween", tween)
	tween.tween_property(control, "modulate:a", 1.0, 0.16).set_ease(Tween.EASE_OUT)


static func _control_icon(kind: StringName, tint: Color = Color.WHITE) -> Texture2D:
	var key := StringName("%s:%s" % [kind, tint.to_html()])
	if _control_icons.has(key):
		return _control_icons[key] as Texture2D
	var body := ""
	var size := Vector2i(24, 24)
	match kind:
		&"arrow":
			size = Vector2i(20, 20)
			body = '<path d="M4 7 Q10 16 16 7" fill="none" stroke="white" stroke-width="2.6" stroke-linecap="round"/>'
		&"checked", &"unchecked":
			body = '<path d="M5 4 C12 1 21 3 21 10 L20 19 Q12 23 4 20 Q1 12 5 4Z" fill="none" stroke="white" stroke-width="2.2" stroke-linejoin="round"/>'
			if kind == &"checked":
				body += '<path d="M6 11 Q9 18 17 7" fill="none" stroke="white" stroke-width="2.8" stroke-linecap="round"/>'
		&"radio_checked", &"radio_unchecked":
			body = '<path d="M12 3 C6 2 2 7 3 14 C4 22 17 24 21 16 C25 8 18 2 12 3Z" fill="none" stroke="white" stroke-width="2.1" stroke-linecap="round"/>'
			if kind == &"radio_checked":
				body += '<ellipse cx="12.2" cy="12.4" rx="3.5" ry="3.8" fill="white"/>'
		&"submenu", &"submenu_mirrored":
			size = Vector2i(20, 20)
			var curve := "M7 4 C10 6 13 7 13 10 C13 13 10 14 7 16"
			if kind == &"submenu_mirrored":
				curve = "M13 4 C10 6 7 7 7 10 C7 13 10 14 13 16"
			body = '<path d="%s" fill="none" stroke="white" stroke-width="2.6" stroke-linecap="round"/>' % curve
		&"toggle_on", &"toggle_off":
			size = Vector2i(42, 24)
			body = '<path d="M13 4 C4 2 1 12 5 18 C10 23 30 22 37 18 C43 12 38 3 29 3Z" fill="none" stroke="white" stroke-width="2"/>'
			var centre := 29 if kind == &"toggle_on" else 12
			body += '<ellipse cx="%d" cy="12" rx="6" ry="6.5" fill="white"/>' % centre
		&"grabber", &"grabber_focus":
			size = Vector2i(22, 26)
			var ink := (WARN if kind == &"grabber_focus" else INK).to_html(false)
			body = '<path d="M8 3 C18 0 22 10 18 20 Q10 28 4 20 C0 14 1 6 8 3Z" fill="#%s" stroke="#%s" stroke-width="2.1"/><path d="M8 9 Q12 12 8 17 M12 8 Q15 12 12 17" fill="none" stroke="#%s" stroke-width="1.2" stroke-linecap="round"/>' % [CARD.to_html(false), ink, ink]
		_:
			return null
	body = body.replace("white", "#" + tint.to_html(false))
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>' % [size.x, size.y, size.x, size.y, body]
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK:
		push_error("Cannot load built-in ink control mark: %s" % kind)
		return null
	var texture := ImageTexture.create_from_image(image)
	_control_icons[key] = texture
	return texture


static func build() -> Theme:
	var th := Theme.new()
	th.default_font = font()
	th.default_font_size = 18
	var normal := paper_panel(CARD)
	normal.shape = InkStyleBox.Shape.TAG
	var hover := paper_panel(PAPER.lightened(0.05))
	hover.shape = InkStyleBox.Shape.TAG
	hover.variant = 2
	var pressed := box(SURFACE, EDGE, 3, 16)
	pressed.shape = InkStyleBox.Shape.TAG
	var disabled := box(SURFACE, DIM, 1, 16)
	disabled.shape = InkStyleBox.Shape.TAG
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", disabled)
	var focus := box(Color(0, 0, 0, 0), WARN, 3, 3)
	focus.draw_center = false
	focus.focus_marks = true
	focus.expand_margin = 3.0
	th.set_stylebox("focus", "Button", focus)
	for type_name in ["Button", "Label", "CheckButton", "CheckBox", "OptionButton"]:
		th.set_color("font_color", type_name, INK)
		th.set_color("font_hover_color", type_name, INK)
		th.set_color("font_pressed_color", type_name, INK)
		th.set_color("font_focus_color", type_name, INK)
		th.set_color("font_hover_pressed_color", type_name, INK)
		th.set_color("font_disabled_color", type_name, DIM)
		th.set_color("icon_normal_color", type_name, INK)
		th.set_color("icon_hover_color", type_name, INK)
		th.set_color("icon_focus_color", type_name, INK)
		th.set_color("icon_pressed_color", type_name, INK)
		th.set_color("icon_disabled_color", type_name, DIM)
	th.set_icon("arrow", "OptionButton", _control_icon(&"arrow"))
	th.set_constant("modulate_arrow", "OptionButton", 1)
	th.set_constant("arrow_margin", "OptionButton", 9)
	for state in ["checked", "unchecked"]:
		var mark := _control_icon(StringName(state))
		th.set_icon(state, "CheckBox", mark)
		th.set_icon(state + "_disabled", "CheckBox", mark)
		var toggle := _control_icon(&"toggle_on" if state == "checked" else &"toggle_off")
		th.set_icon(state, "CheckButton", toggle)
		th.set_icon(state + "_disabled", "CheckButton", toggle)
		th.set_icon(state + "_mirrored", "CheckButton", toggle)
		th.set_icon(state + "_disabled_mirrored", "CheckButton", toggle)
	th.set_color("button_checked_color", "CheckButton", INK)
	th.set_color("button_unchecked_color", "CheckButton", DIM)
	th.set_stylebox("panel", "PanelContainer", paper_panel())
	th.set_stylebox("panel", "TooltipPanel", paper_panel(CARD))
	th.set_color("font_color", "TooltipLabel", INK)
	th.set_font_size("font_size", "TooltipLabel", 14)
	th.set_stylebox("normal", "LineEdit", box(CARD, EDGE, 2, 2))
	th.set_stylebox("focus", "LineEdit", focus)
	th.set_stylebox("read_only", "LineEdit", box(SURFACE, DIM, 2, 2))
	th.set_color("font_color", "LineEdit", INK)
	th.set_color("font_placeholder_color", "LineEdit", DIM)
	th.set_color("caret_color", "LineEdit", INK)
	th.set_color("selection_color", "LineEdit", Color(ACCENT, 0.3))
	th.set_stylebox("normal", "TextEdit", box(CARD, EDGE, 2, 2))
	th.set_stylebox("focus", "TextEdit", focus)
	th.set_stylebox("read_only", "TextEdit", box(PAPER, DIM, 2, 2))
	th.set_color("font_color", "TextEdit", INK)
	th.set_color("font_placeholder_color", "TextEdit", DIM)
	th.set_color("caret_color", "TextEdit", INK)
	th.set_color("selection_color", "TextEdit", Color(ACCENT, 0.3))
	th.set_stylebox("panel", "PopupMenu", paper_panel())
	th.set_stylebox("hover", "PopupMenu", box(SURFACE, EDGE, 1, 1))
	th.set_color("font_color", "PopupMenu", INK)
	th.set_color("font_hover_color", "PopupMenu", INK)
	th.set_color("font_disabled_color", "PopupMenu", DIM)
	# PopupMenu draws its own check/radio textures, separate from the closed option.
	# These are already ink-coloured because popup marks have no icon-colour theme field.
	for state in ["checked", "unchecked", "radio_checked", "radio_unchecked"]:
		th.set_icon(state, "PopupMenu", _control_icon(StringName(state), INK))
		th.set_icon(state + "_disabled", "PopupMenu", _control_icon(StringName(state), DIM))
	th.set_icon("submenu", "PopupMenu", _control_icon(&"submenu", INK))
	th.set_icon("submenu_mirrored", "PopupMenu", _control_icon(&"submenu_mirrored", INK))
	for type_name in ["VScrollBar", "HScrollBar"]:
		# The full native bar remains the drag target; the visible mark is a small ink scrap.
		var track := box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 1)
		track.draw_center = false
		track.shadow_color = Color.TRANSPARENT
		th.set_stylebox("scroll", type_name, track)
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			var colour := ACCENT if state == "grabber_highlight" else INK
			var grip := box(colour, Color.TRANSPARENT, 0, 12)
			grip.shape = InkStyleBox.Shape.BLOB
			grip.variant = 7
			grip.grip_mark = true
			grip.shadow_color = Color.TRANSPARENT
			th.set_stylebox(state, type_name, grip)
	th.set_stylebox("slider", "HSlider", box(SURFACE, EDGE, 2, 2))
	th.set_stylebox("grabber_area", "HSlider", box(ACCENT, EDGE, 1, 2))
	th.set_stylebox("grabber_area_highlight", "HSlider", box(COIN, EDGE, 1, 2))
	th.set_icon("grabber", "HSlider", _control_icon(&"grabber"))
	th.set_icon("grabber_highlight", "HSlider", _control_icon(&"grabber_focus"))
	th.set_icon("grabber_disabled", "HSlider", _control_icon(&"grabber"))
	th.set_stylebox("background", "ProgressBar", box(SURFACE, EDGE, 2, 2))
	th.set_stylebox("fill", "ProgressBar", box(ACCENT, EDGE, 1, 2))
	th.set_color("font_color", "ProgressBar", INK)
	th.set_color("font_outline_color", "ProgressBar", CARD)
	return th
