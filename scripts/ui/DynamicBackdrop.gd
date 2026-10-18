extends Control
const SPACING := 54.0
var phase := 0.0
var exposure := 0.0
var canvas_rect := Rect2()
var tint_rect := Rect2()
var wrap_size := Vector2.ONE
var ring_center := Vector2.ZERO
var ring_radius := 0.0
var grid_columns := 0
var grid_rows := 0
var grid_slant := 0.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_cache_geometry)
	_cache_geometry()
func _cache_geometry() -> void:
	canvas_rect = Rect2(Vector2.ZERO, size)
	tint_rect = Rect2(Vector2(size.x * 0.56, 0), Vector2(size.x * 0.44, size.y))
	wrap_size = Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	ring_center = Vector2(size.x * 0.87, size.y * 0.72)
	ring_radius = minf(size.x, size.y) * 0.34
	grid_columns = int(size.x / SPACING) + 2
	grid_rows = int(size.y / SPACING) + 2
	grid_slant = size.y * 0.2
func _process(delta: float) -> void:
	phase = fposmod(phase + delta * 0.10, 10000.0)
	queue_redraw()
func set_exposure(value: float) -> void:
	var next_exposure := clampf(value, 0.0, 100.0)
	if exposure != next_exposure:
		exposure = next_exposure
		queue_redraw()
func _draw() -> void:
	draw_rect(canvas_rect, Color("#050912"))
	var hot := exposure / 100.0
	draw_rect(tint_rect, Color(0.08, 0.20, 0.31, 0.07 + hot * 0.1))
	var drift := fposmod(phase * 22.0, SPACING)
	var vertical_drift := fposmod(phase * 8.0, SPACING)
	for x in range(-1, grid_columns):
		var px := float(x) * SPACING + drift
		draw_line(Vector2(px, 0), Vector2(px - grid_slant, size.y), Color(0.14, 0.55, 0.60, 0.09), 1.0)
	for y in range(-1, grid_rows):
		var py := float(y) * SPACING + vertical_drift
		draw_line(Vector2(0, py), Vector2(size.x, py), Color(0.12, 0.45, 0.55, 0.06), 1.0)
	for i in range(24):
		var px := fposmod(float(i * 173) + phase * float(31 + i % 5), wrap_size.x)
		var py := fposmod(float(i * 97) + phase * float(17 + i % 7), wrap_size.y)
		var alpha := 0.16 + 0.27 * (0.5 + 0.5 * sin(phase * 3.2 + float(i)))
		draw_circle(Vector2(px, py), 1.0 + float(i % 3) * 0.35, Color(0.34, 0.95, 0.83, alpha))
	var beam_y := fposmod(phase * 95.0, wrap_size.y)
	draw_rect(Rect2(0, beam_y, size.x, 2.0), Color(0.25, 0.93, 0.78, 0.15))
	draw_rect(Rect2(0, beam_y - 7.0, size.x, 9.0), Color(0.15, 0.62, 0.66, 0.045))
	var center := ring_center
	var radius := ring_radius
	for ring in range(1, 5):
		draw_arc(center, radius * float(ring) / 4.0, 0.0, TAU, 80, Color(0.18, 0.68, 0.66, 0.08), 1.0)
	var angle := phase * 0.85
	draw_line(center, center + Vector2(cos(angle), sin(angle)) * radius, Color(0.30, 0.94, 0.80, 0.13), 1.0)
