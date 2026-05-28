extends Control
class_name EnemyHealthBar

const COLOR_FILL := Color("#c44b33")
const COLOR_BORDER := Color("#000000")
const COLOR_TRACK := Color("#3d1515")
const TWEEN_DURATION := 0.2

@export var bar_width: int = 24
@export var bar_height: int = 5
@export var border_width: int = 1

var _display_ratio: float = 1.0
var _tween: Tween
var _bound_host: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST
	_update_size()
	set_ratio(1.0, false)


func _update_size() -> void:
	var total_w := bar_width + border_width * 2
	var total_h := bar_height + border_width * 2
	custom_minimum_size = Vector2(total_w, total_h)
	size = Vector2(total_w, total_h)


func bind_host(host: Node) -> void:
	if _bound_host and is_instance_valid(_bound_host):
		if _bound_host.health_changed.is_connected(_on_health_changed):
			_bound_host.health_changed.disconnect(_on_health_changed)

	_bound_host = host
	if host.has_signal("health_changed"):
		host.health_changed.connect(_on_health_changed)
	if "health" in host and "max_health" in host:
		_on_health_changed(host.health, host.max_health)


func set_ratio(ratio: float, animate: bool = true) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)

	if not animate or is_equal_approx(_display_ratio, clamped):
		_display_ratio = clamped
		queue_redraw()
		return

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.tween_method(_set_display_ratio, _display_ratio, clamped, TWEEN_DURATION)
	_tween.finished.connect(func() -> void:
		_display_ratio = clamped
	)


func _set_display_ratio(ratio: float) -> void:
	_display_ratio = ratio
	queue_redraw()


func _on_health_changed(current: int, maximum: int) -> void:
	var ratio := 0.0 if maximum <= 0 else float(current) / float(maximum)
	set_ratio(ratio)


func _is_inner_pixel(ix: int, iy: int) -> bool:
	if bar_height <= 1:
		return ix >= 0 and ix < bar_width
	if bar_height == 2:
		if iy == 0:
			return ix >= 1 and ix < bar_width - 1
		return ix >= 0 and ix < bar_width

	var inset := 0
	if iy == 0 or iy == bar_height - 1:
		inset = mini(2, maxi(0, (bar_width - 4) / 2))
	elif iy == 1 or iy == bar_height - 2:
		inset = 1
	return ix >= inset and ix < bar_width - inset


func _is_border_pixel(x: int, y: int) -> bool:
	var ix := x - border_width
	var iy := y - border_width
	if ix >= 0 and ix < bar_width and iy >= 0 and iy < bar_height and _is_inner_pixel(ix, iy):
		return false

	for dy in range(-border_width, border_width + 1):
		for dx in range(-border_width, border_width + 1):
			var nix := ix + dx
			var niy := iy + dy
			if nix >= 0 and nix < bar_width and niy >= 0 and niy < bar_height and _is_inner_pixel(nix, niy):
				return true
	return false


func _draw() -> void:
	var bw := border_width
	var total_w := bar_width + bw * 2
	var total_h := bar_height + bw * 2
	var fill_w := roundi(bar_width * _display_ratio)

	for y in range(total_h):
		for x in range(total_w):
			if _is_border_pixel(x, y):
				draw_rect(Rect2i(x, y, 1, 1), COLOR_BORDER)

	for iy in range(bar_height):
		for ix in range(bar_width):
			if not _is_inner_pixel(ix, iy):
				continue
			var px := ix + bw
			var py := iy + bw
			var color := COLOR_FILL if ix < fill_w else COLOR_TRACK
			draw_rect(Rect2i(px, py, 1, 1), color)
