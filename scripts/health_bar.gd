extends Control
class_name HealthBar

const COLOR_FILL_HEALTHY := Color("#6bbf59")
const COLOR_FILL_CRITICAL := Color("#c44b33")
const COLOR_BG := Color("#1a1208")
const COLOR_BORDER := Color("#3d2817")
const CRITICAL_THRESHOLD := 0.3
const TWEEN_DURATION := 0.25

@export var bar_width: int = 48
@export var bar_height: int = 6
@export var fill_inset: int = 1

@onready var label_player: Label = $LabelPlayer
@onready var bar_background: ColorRect = $BarBackground
@onready var bar_fill: ColorRect = $BarBackground/BarFill
@onready var label_percent: Label = $LabelPercent

var _display_ratio: float = 1.0
var _tween: Tween
var _bound_player: PlayerBase


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_background.custom_minimum_size = Vector2(bar_width, bar_height)
	bar_background.size = Vector2(bar_width, bar_height)
	bar_background.color = COLOR_BORDER
	_apply_fill_width(_display_ratio)


func set_player_label(text: String) -> void:
	label_player.text = text


func bind_player(player: PlayerBase) -> void:
	if _bound_player and is_instance_valid(_bound_player):
		if _bound_player.health_changed.is_connected(_on_health_changed):
			_bound_player.health_changed.disconnect(_on_health_changed)

	_bound_player = player
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.max_health)


func set_ratio(ratio: float, animate: bool = true) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	label_percent.text = "%d%%" % roundi(clamped * 100.0)

	if not animate or is_equal_approx(_display_ratio, clamped):
		_display_ratio = clamped
		_apply_fill_width(_display_ratio)
		return

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.tween_method(_apply_fill_width, _display_ratio, clamped, TWEEN_DURATION)
	_tween.finished.connect(func() -> void:
		_display_ratio = clamped
	)


func _on_health_changed(current: int, maximum: int) -> void:
	var ratio := 0.0 if maximum <= 0 else float(current) / float(maximum)
	set_ratio(ratio)


func _apply_fill_width(ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	var inner_width := bar_width - fill_inset * 2
	var fill_width := roundi(inner_width * clamped)
	bar_fill.position = Vector2(fill_inset, fill_inset)
	bar_fill.size = Vector2(fill_width, bar_height - fill_inset * 2)
	bar_fill.color = _get_fill_color(clamped)


func _get_fill_color(ratio: float) -> Color:
	if ratio <= 0.0:
		return COLOR_BG
	if ratio < CRITICAL_THRESHOLD:
		return COLOR_FILL_CRITICAL.lerp(COLOR_FILL_HEALTHY, ratio / CRITICAL_THRESHOLD)
	return COLOR_FILL_HEALTHY
