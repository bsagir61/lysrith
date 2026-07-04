extends Node
## UITheme.gd - the single visual system for LYSRITH.
## Central colors, spacing, font sizes and styled-widget factories.
## Every panel and screen builds its widgets through these helpers so the
## whole game shares one look: dark navy, glass cards, pale cyan accents.

# ---------- Palette ----------
const BG_DEEP := Color("060a12")
const BG_PANEL := Color("0a101b")
const CARD := Color("111a29")
const CARD_RAISED := Color("16223468")   # glass-like, semi-transparent
const EDGE := Color("223349")
const EDGE_BRIGHT := Color("35506e")
const TEXT := Color("d9e6ee")
const TEXT_DIM := Color("7f92a6")
const ACCENT := Color("8fd8e8")          # pale cyan
const ACCENT_DIM := Color("3f6b7d")
const WARN := Color("d8a44c")            # muted amber
const DANGER := Color("c85555")          # restrained red
const SAFE := Color("74c3ad")
const COLLAPSED := Color("55606c")

# ---------- Spacing / metrics ----------
const SPACE_XS := 8
const SPACE_S := 16
const SPACE_M := 24
const SPACE_L := 36
const SPACE_XL := 56
const RADIUS := 16
const BUTTON_HEIGHT := 108
const BUTTON_HEIGHT_SMALL := 84
const TOUCH_MIN := 88.0
const MAP_MIN_HEIGHT := 820
const BOTTOM_SHEET_HEIGHT := 820
const MODAL_WIDTH := 920
const MODAL_HEIGHT := 1040

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
	sb.set_content_margin_all(SPACE_S + 6)
	return sb


func glass_style() -> StyleBoxFlat:
	var sb := panel_style(CARD_RAISED, EDGE)
	return sb


# ---------- Widget factories ----------
func label(text: String, size: int = FS_BODY, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func title(text: String, size: int = FS_TITLE, color: Color = ACCENT) -> Label:
	var l := label(text.to_upper(), size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	var fill := Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.10)
	var edge := ACCENT_DIM
	match kind:
		"danger":
			accent = DANGER
			fill = Color(DANGER.r, DANGER.g, DANGER.b, 0.10)
			edge = Color(DANGER.r, DANGER.g, DANGER.b, 0.45)
		"warn":
			accent = WARN
			fill = Color(WARN.r, WARN.g, WARN.b, 0.10)
			edge = Color(WARN.r, WARN.g, WARN.b, 0.45)
		"ghost":
			accent = TEXT
			fill = Color(CARD.r, CARD.g, CARD.b, 0.85)
			edge = EDGE_BRIGHT
	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_color = edge
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(RADIUS - 4)
	normal.set_content_margin_all(SPACE_S)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(fill.r, fill.g, fill.b, minf(fill.a + 0.15, 1.0))
	pressed.border_color = accent
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(CARD.r, CARD.g, CARD.b, 0.4)
	disabled.border_color = EDGE
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", normal)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", accent)
	b.add_theme_color_override("font_pressed_color", ACCENT if kind != "danger" else DANGER)
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
	bg.bg_color = Color(0, 0, 0, 0.45)
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
