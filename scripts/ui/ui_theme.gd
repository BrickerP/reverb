class_name UiTheme
extends RefCounted

# The game ships Noto Sans CJK SC so Windows, Linux and Steam Deck do not depend on a
# system CJK font. The system list remains a fallback for stripped-down builds.
# PingFang SC is deliberately late in the list: the engine loads the first face of PingFang.ttc
# on macOS, which is the Hong Kong one and lacks simplified-only glyphs such as 杀.
const BUNDLED_FONT := "res://assets/fonts/NotoSansCJKsc-Regular.otf"
const SURFACE_PANEL_PATH := "res://assets/presentation/surfaces/panel_skin.png"
const SURFACE_PANEL_TEXTURE_MARGIN := 32.0
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
static var _surface_panel: StyleBoxTexture


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


static func title_font() -> FontVariation:
	if _title_font == null:
		_title_font = FontVariation.new()
		_title_font.base_font = font()
		_title_font.variation_embolden = 1.15
		_title_font.spacing_glyph = 1
	return _title_font


static func label(text: String, size: int = 18, color: Color = INK,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size >= 28:
		l.add_theme_font_override("font", title_font())
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
	var visible := PresentationAssets.region(key)
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


static func surface_panel() -> StyleBoxTexture:
	if _surface_panel != null:
		return _surface_panel
	var texture := load(SURFACE_PANEL_PATH) as Texture2D
	if texture == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = SURFACE_PANEL_TEXTURE_MARGIN
	style.texture_margin_top = SURFACE_PANEL_TEXTURE_MARGIN
	style.texture_margin_right = SURFACE_PANEL_TEXTURE_MARGIN
	style.texture_margin_bottom = SURFACE_PANEL_TEXTURE_MARGIN
	style.content_margin_left = 14.0
	style.content_margin_top = 12.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 12.0
	_surface_panel = style
	return _surface_panel


# Briefly tint a control and fade back: used when a shop action is blocked.
static func flash(control: Control) -> void:
	if control == null:
		return
	var alpha := control.modulate.a
	control.modulate = Color(WARN.r, WARN.g, WARN.b, alpha)
	var tween := control.create_tween()
	tween.tween_property(control, "modulate", Color(1, 1, 1, alpha), 0.45).set_ease(Tween.EASE_OUT)


static func box(fill: Color, border: Color, border_width: int = 2, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


# Reusable paper stock: heavy ink edges and a small offset shadow, like a pasted form.
static func paper_panel(fill: Color = CARD) -> StyleBoxFlat:
	var style := box(fill, EDGE, 3, 3)
	style.set_border_width(SIDE_BOTTOM, 5)
	style.shadow_color = Color(EDGE, 0.24)
	style.shadow_size = 1
	style.shadow_offset = Vector2(3.0, 4.0)
	return style


static func section_label(text: String, size: int = 20, color: Color = INK) -> Label:
	var title := label(text, size, color)
	title.add_theme_constant_override("outline_size", 0)
	return title


static func stamp_button(button: Button, color: Color = ACCENT) -> void:
	button.add_theme_stylebox_override("normal", paper_panel(color))
	button.add_theme_stylebox_override("hover", paper_panel(color.lightened(0.10)))
	button.add_theme_stylebox_override("pressed", box(color.darkened(0.12), EDGE, 3, 2))
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


static func build() -> Theme:
	var th := Theme.new()
	th.default_font = font()
	th.default_font_size = 18
	th.set_stylebox("normal", "Button", paper_panel(CARD))
	th.set_stylebox("hover", "Button", paper_panel(PAPER.lightened(0.08)))
	th.set_stylebox("pressed", "Button", box(SURFACE, EDGE, 3, 2))
	th.set_stylebox("disabled", "Button", box(SURFACE, DIM, 2, 3))
	var focus := box(Color(0, 0, 0, 0), WARN, 3, 3)
	focus.draw_center = false
	focus.set_expand_margin_all(3.0)
	th.set_stylebox("focus", "Button", focus)
	for type_name in ["Button", "Label", "CheckButton", "CheckBox", "OptionButton"]:
		th.set_color("font_color", type_name, INK)
		th.set_color("font_hover_color", type_name, INK)
		th.set_color("font_pressed_color", type_name, INK)
		th.set_color("font_focus_color", type_name, INK)
		th.set_color("font_hover_pressed_color", type_name, INK)
		th.set_color("font_disabled_color", type_name, DIM)
	th.set_stylebox("panel", "PanelContainer", paper_panel())
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
	for type_name in ["VScrollBar", "HScrollBar"]:
		th.set_stylebox("scroll", type_name, box(SURFACE, EDGE, 1, 1))
		th.set_stylebox("grabber", type_name, box(DIM, EDGE, 1, 1))
		th.set_stylebox("grabber_highlight", type_name, box(ACCENT, EDGE, 1, 1))
		th.set_stylebox("grabber_pressed", type_name, box(WARN, EDGE, 1, 1))
	th.set_stylebox("slider", "HSlider", box(SURFACE, EDGE, 2, 2))
	th.set_stylebox("grabber_area", "HSlider", box(ACCENT, EDGE, 1, 2))
	th.set_stylebox("grabber_area_highlight", "HSlider", box(COIN, EDGE, 1, 2))
	th.set_stylebox("background", "ProgressBar", box(SURFACE, EDGE, 2, 2))
	th.set_stylebox("fill", "ProgressBar", box(ACCENT, EDGE, 1, 2))
	th.set_color("font_color", "ProgressBar", INK)
	th.set_color("font_outline_color", "ProgressBar", CARD)
	return th
