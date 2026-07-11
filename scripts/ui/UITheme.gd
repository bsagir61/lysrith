extends Node
## UITheme.gd - the single visual system for LYSRITH.
## Central colors, spacing, font sizes and styled-widget factories.
## Every panel and screen builds its widgets through these helpers so the
## whole game shares one look: dark dossier surfaces and restrained signal color.

# ---------- Palette ----------
const BG_DEEP := Color("080c0f")
const BG_PANEL := Color("0e171d")
const CARD := Color("142027")
const CARD_RAISED := Color("1a2931")
const EDGE := Color("31434b")
const EDGE_BRIGHT := Color("49606a")
const TEXT := Color("e7e2d6")
const TEXT_DIM := Color("9ca8a8")
const ACCENT := Color("4fb7a6")
const ACCENT_BRIGHT := Color("81d0c1")
const ACCENT_DIM := Color("326f68")
const WARN := Color("d0a453")
const DANGER := Color("d86452")
const SAFE := Color("7fab78")
const COLLAPSED := Color("59666a")

# ---------- Spacing / metrics ----------
const SPACE_XXS := 4
const SPACE_XS := 8
const SPACE_S := 16
const SPACE_M := 24
const SPACE_L := 36
const SPACE_XL := 56
const RADIUS := 6
const RADIUS_COMPACT := 4
const CARD_PADDING := 22
const SAFE_MARGIN := 24
const CHIP_MIN_HEIGHT := 64
const STATUS_MIN_HEIGHT := 48
const SECTION_MARKER_WIDTH := 6
const MAP_IDENTITY_MARKER_SIZE := 10.0
const RISK_BADGE_WIDTH := 180
const BUTTON_HEIGHT := 108
const BUTTON_HEIGHT_SMALL := 88
const TOUCH_MIN := 88.0
const MAP_MIN_HEIGHT := 820
const BOTTOM_SHEET_HEIGHT := 1240
const MODAL_WIDTH := 920
const MODAL_HEIGHT := 1420
const INFO_MODAL_HEIGHT := 900
const OVERLAY_OPACITY := 0.62

# ---------- Animation durations ----------
const ANIM_FAST := 0.12
const ANIM_MED := 0.25
const ANIM_SLOW := 0.5

# ---------- Font sizes (before text-scale) ----------
const FS_MICRO := 20
const FS_TINY := 22
const FS_SMALL := 26
const FS_BODY := 30
const FS_LARGE := 36
const FS_TITLE := 46
const FS_HUGE := 70

# Semantic typography tiers. Existing size constants remain available for
# compact legacy surfaces; new screens should prefer these names.
const FS_CAPTION := FS_TINY
const FS_SUPPORTING := FS_SMALL
const FS_PRIMARY_VALUE := FS_LARGE
const FS_SECTION := FS_BODY
const FS_SCREEN_TITLE := FS_TITLE


func fs(base: int) -> int:
	return int(round(base * SettingsManager.text_scale()))


# ---------- StyleBox factories ----------
func panel_style(bg: Color = BG_PANEL, border: Color = EDGE, radius: int = RADIUS) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(SPACE_M)
	return sb


func card_style(border: Color = EDGE) -> StyleBoxFlat:
	var sb := panel_style(CARD, border)
	sb.set_content_margin_all(CARD_PADDING)
	return sb


func glass_style() -> StyleBoxFlat:
	# Kept for caller compatibility; the dossier system uses an opaque raised surface.
	var sb := panel_style(CARD_RAISED, EDGE)
	return sb


func chip_style(color: Color, emphasized: bool = false) -> StyleBoxFlat:
	var tint: float = 0.16 if emphasized else 0.08
	var base: Color = CARD_RAISED if emphasized else CARD
	var sb := panel_style(base.lerp(color, tint), color.lerp(EDGE, 0.35), RADIUS_COMPACT)
	sb.set_content_margin_all(SPACE_XS)
	return sb


# ---------- Widget factories ----------
func label(text: String, size: int = FS_BODY, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func title(text: String, size: int = FS_TITLE, color: Color = ACCENT_BRIGHT) -> Label:
	var l := label(text.to_upper(), size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func section_header(text: String, color: Color = ACCENT) -> Label:
	var l := label(text, FS_SECTION, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## kind: "primary" | "ghost" | "danger" | "warn"
func button(text: String, kind: String = "ghost", small: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.clip_text = true
	style_button(b, kind, small)
	b.pressed.connect(func() -> void:
		AudioManager.play_click()
		SettingsManager.vibrate(18)
	)
	return b


func style_button(b: Button, kind: String = "ghost", small: bool = false) -> void:
	var accent := ACCENT
	var fill := CARD_RAISED.lerp(ACCENT, 0.16)
	var edge := ACCENT
	match kind:
		"danger":
			accent = DANGER
			fill = CARD_RAISED.lerp(DANGER, 0.14)
			edge = DANGER
		"warn":
			accent = WARN
			fill = CARD_RAISED.lerp(WARN, 0.14)
			edge = WARN
		"ghost":
			accent = TEXT
			fill = CARD
			edge = EDGE_BRIGHT
	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_color = edge
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(RADIUS_COMPACT)
	normal.set_content_margin_all(SPACE_S)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = fill.lerp(accent, 0.14)
	pressed.border_color = accent
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = CARD
	disabled.border_color = EDGE
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", normal)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", accent)
	b.add_theme_color_override("font_pressed_color", accent)
	b.add_theme_color_override("font_hover_color", accent)
	b.add_theme_color_override("font_disabled_color", TEXT_DIM)
	b.add_theme_font_size_override("font_size", fs(FS_BODY if not small else FS_SMALL))
	b.custom_minimum_size = Vector2(0, BUTTON_HEIGHT_SMALL if small else BUTTON_HEIGHT)


func progress_bar(color: Color, height: float = 26.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.show_percentage = false
	bar.max_value = 100
	style_bar(bar, color)
	return bar


func style_bar(bar: ProgressBar, color: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = BG_DEEP
	bg.border_color = EDGE
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(color.r, color.g, color.b, 0.75)
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)


func spacer(h: int = SPACE_M) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func hseparator() -> HSeparator:
	var s := HSeparator.new()
	var sb := StyleBoxLine.new()
	sb.color = EDGE
	sb.thickness = 1
	s.add_theme_stylebox_override("separator", sb)
	return s


func info_card(border: Color = EDGE, raised: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(CARD_RAISED if raised else CARD, border, RADIUS_COMPACT))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel


func status_chip(text_value: String, color: Color, emphasized: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", chip_style(color, emphasized))
	panel.custom_minimum_size = Vector2(0, STATUS_MIN_HEIGHT)
	var value_label := label(text_value, FS_MICRO, color)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.add_child(value_label)
	return panel


func metric_chip(caption: String, value: String, color: Color, emphasized: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", chip_style(color, emphasized))
	panel.custom_minimum_size = Vector2(0, CHIP_MIN_HEIGHT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SPACE_XXS)
	panel.add_child(box)
	var caption_label := label(caption, FS_MICRO, TEXT_DIM)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(caption_label)
	var value_label := label(value, FS_SMALL, color)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(value_label)
	return panel


func modifier_row(caption: String, value: String, color: Color = TEXT) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SPACE_S)
	var caption_label := label(caption, FS_CAPTION, TEXT_DIM)
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption_label)
	var value_label := label(value, FS_CAPTION, color)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(value_label)
	return row


func compact_progress_row(caption: String, value: float, color: Color, value_text: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SPACE_S)
	var caption_label := label(caption, FS_CAPTION, TEXT_DIM)
	caption_label.custom_minimum_size = Vector2(210, 0)
	row.add_child(caption_label)
	var bar := progress_bar(color, 18.0)
	bar.value = value
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var shown_value := value_text if value_text != "" else str(int(value))
	var value_label := label(shown_value, FS_CAPTION, color)
	value_label.custom_minimum_size = Vector2(78, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(value_label)
	return row


func empty_state(text_value: String) -> PanelContainer:
	var panel := info_card(EDGE)
	var state_label := label(text_value, FS_SUPPORTING, TEXT_DIM)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(state_label)
	return panel


func safe_area_margin(margin_size: int = SAFE_MARGIN) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", margin_size)
	margin.add_theme_constant_override("margin_right", margin_size)
	margin.add_theme_constant_override("margin_top", margin_size)
	margin.add_theme_constant_override("margin_bottom", margin_size)
	return margin


func semantic_value_color(value: float, high_is_good: bool = true) -> Color:
	return level_color(value) if high_is_good else danger_color(value)


func semantic_risk_color(risk: String) -> Color:
	match risk:
		"favorable":
			return SAFE
		"uncertain":
			return ACCENT
		"risky":
			return WARN
		"severe":
			return DANGER
	return TEXT_DIM


## Semantic color for a 0-100 "goodness" value (high = good).
func level_color(value: float) -> Color:
	if value >= 60.0:
		return SAFE
	if value >= 35.0:
		return WARN
	return DANGER


## Semantic color for a 0-100 "danger" value (high = bad).
func danger_color(value: float) -> Color:
	if value >= 65.0:
		return DANGER
	if value >= 35.0:
		return WARN
	return ACCENT
