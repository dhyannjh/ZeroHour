extends Control
signal contact_swept
const GREEN := Color("#5fffd3")
const AMBER := Color("#ffc36a")
const RED := Color("#ff637a")
const CRITICAL := Color("#ff2f59")

# Godot retains these drawing commands until the size or band changes.
# Drawing behind the parent preserves the original order below the sweep.
class RadarGrid extends Control:
	var active := GREEN
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.44
		draw_circle(c, r, Color(0.02, 0.10, 0.13, 0.72))
		for n in range(1, 6):
			draw_arc(c, r * float(n) / 5.0, 0.0, TAU, 120, Color(active, 0.28 if n < 5 else 0.55), 1.2 if n % 2 == 0 else 0.9)
		draw_line(Vector2(c.x-r,c.y),Vector2(c.x+r,c.y),Color(0.30,0.85,0.78,0.32),1.0)
		draw_line(Vector2(c.x,c.y-r),Vector2(c.x,c.y+r),Color(0.30,0.85,0.78,0.32),1.0)
		for spoke in range(8):
			var a := TAU * float(spoke) / 8.0
			draw_line(c+Vector2(cos(a),sin(a))*r*0.78,c+Vector2(cos(a),sin(a))*r,Color(0.23,0.72,0.69,0.28),0.8)

var sweep := 0.0
var phase := 0.0
var exposure := 0.0
var active := GREEN
var center := Vector2.ZERO
var radius := 0.0
var contact_one := Vector2.ZERO
var contact_two := Vector2.ZERO
var grid: RadarGrid

func _ready() -> void:
	grid = RadarGrid.new()
	grid.active = active
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.show_behind_parent = true
	add_child(grid)
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_cache_geometry)
	_cache_geometry()

func _cache_geometry() -> void:
	center = size * 0.5
	radius = minf(size.x, size.y) * 0.44
	contact_one = center + Vector2(radius*0.38,-radius*0.20)
	contact_two = center + Vector2(-radius*0.47,radius*0.28)

func _process(delta: float) -> void:
	var old := sweep
	sweep = fposmod(sweep + delta * 1.15, TAU)
	phase = fposmod(phase + delta, 2.0)
	if old < 5.05 and sweep >= 5.05:
		contact_swept.emit()
	queue_redraw()
func set_exposure(value: float) -> void:
	exposure = clampf(value, 0.0, 100.0)
	var next_active := CRITICAL if exposure >= 95.0 else RED if exposure >= 80.0 else AMBER if exposure >= 65.0 else GREEN
	if active != next_active:
		active = next_active
		if is_instance_valid(grid):
			grid.active = active
			grid.queue_redraw()
		queue_redraw()
func _draw() -> void:
	var c := center
	var r := radius
	for tail in range(18, 0, -1):
		var a1 := sweep - float(tail - 1) * 0.035
		var a2 := sweep - float(tail) * 0.035
		var alpha := 0.035 + 0.25 * (1.0 - float(tail) / 18.0)
		draw_colored_polygon(PackedVector2Array([c,c+Vector2(cos(a1),sin(a1))*r,c+Vector2(cos(a2),sin(a2))*r]),Color(GREEN,alpha))
	draw_line(c,c+Vector2(cos(sweep),sin(sweep))*r,Color(GREEN,1.0),2.6)
	var ping := 0.5 + 0.5 * sin(phase * PI)
	var p1 := contact_one
	var p2 := contact_two
	draw_circle(p1,7.0+ping*3.0,Color(active,0.22))
	draw_circle(p1,3.4+ping*0.8,active)
	draw_circle(p2,5.0,Color("#74cfff"))
	draw_circle(c,3.2,Color("#e9fff9"))
