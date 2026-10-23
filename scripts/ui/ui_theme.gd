class_name UiTheme
extends RefCounted

# The game ships Noto Sans CJK SC so Windows, Linux and Steam Deck do not depend on a
# system CJK font. The system list remains a fallback for stripped-down builds.
# PingFang SC is deliberately late in the list: the engine loads the first face of PingFang.ttc
# on macOS, which is the Hong Kong one and lacks simplified-only glyphs such as 杀.
const BUNDLED_FONT := "res://assets/fonts/NotoSansCJKsc-Regular.otf"
const FONT_NAMES: Array[String] = [
	"Hiragino Sans GB", "Noto Sans CJK SC", "Source Han Sans SC", "Microsoft YaHei",
	"WenQuanYi Micro Hei", "PingFang SC", "sans-serif",
]
const INK := Color(0.94, 0.93, 0.89)
const DIM := Color(0.65, 0.69, 0.74)
const ACCENT := Color(0.36, 0.83, 0.88)
const WARN := Color(1.0, 0.45, 0.5)
const COIN := Color(0.93, 0.77, 0.43)
const ECHO := Color(1.0, 0.55, 0.9)

static var _font: Font


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


static func label(text: String, size: int = 18, color: Color = INK,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


static func build() -> Theme:
	var th := Theme.new()
	th.default_font = font()
	th.default_font_size = 18
	var normal := box(Color(0.105, 0.125, 0.145), Color(0.31, 0.36, 0.40), 1, 7)
	normal.set_border_width(SIDE_BOTTOM, 3)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	normal.shadow_size = 3
	normal.shadow_offset = Vector2(0.0, 2.0)
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", box(Color(0.15, 0.19, 0.21), ACCENT, 1, 7))
	th.set_stylebox("pressed", "Button", box(Color(0.065, 0.09, 0.11), ACCENT, 1, 7))
	th.set_stylebox("disabled", "Button", box(Color(0.055, 0.065, 0.075), Color(0.18, 0.21, 0.24), 1, 7))
	var focus := box(Color(0, 0, 0, 0), Color(1.0, 0.9, 0.4), 3)
	focus.draw_center = false
	th.set_stylebox("focus", "Button", focus)
	th.set_color("font_color", "Button", INK)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(0.42, 0.45, 0.58))
	th.set_color("font_color", "Label", INK)
	th.set_stylebox("panel", "PanelContainer", box(Color(0.055, 0.07, 0.085, 0.98), Color(0.25, 0.30, 0.34), 1, 8))
	th.set_stylebox("normal", "LineEdit", box(Color(0.04, 0.055, 0.065), Color(0.25, 0.30, 0.34), 1))
	th.set_stylebox("focus", "LineEdit", box(Color(0.04, 0.055, 0.065), ACCENT, 1))
	th.set_color("font_color", "LineEdit", INK)
	th.set_color("font_placeholder_color", "LineEdit", DIM)
	th.set_color("caret_color", "LineEdit", ACCENT)
	th.set_color("selection_color", "LineEdit", Color(ACCENT, 0.3))
	return th
