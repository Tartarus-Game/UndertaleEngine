@tool
extends CharacterBody2D

@export var box: Panel
@export var size := Vector2(100, 100)
@export var Left: CollisionShape2D
@export var Right: CollisionShape2D
@export var Down: CollisionShape2D
@export var Up: CollisionShape2D
@export var frame_width := 2.0
var polygon := PackedVector2Array()
var polygon_edges: Array[CollisionShape2D] = []


func _ready() -> void:
	_update_box()


func _physics_process(_delta: float) -> void:
	_update_box()


# Vertices are local to the box; provide a simple non-self-intersecting polygon.
func set_polygon(points: PackedVector2Array) -> bool:
	if points.size() > 32 or (not points.is_empty() and (points.size() < 3 or Geometry2D.triangulate_polygon(points).is_empty())):
		return false
	polygon = points.duplicate()
	for edge in polygon_edges: edge.queue_free()
	polygon_edges.clear()
	var polygon_enabled := not polygon.is_empty()
	box.visible = not polygon_enabled
	for side in [Left, Right, Up, Down]: side.set_deferred("disabled", polygon_enabled)
	if polygon_enabled:
		for i in range(polygon.size()):
			var segment := SegmentShape2D.new()
			segment.a = polygon[i]
			segment.b = polygon[(i + 1) % polygon.size()]
			var collision := CollisionShape2D.new()
			collision.shape = segment
			add_child(collision)
			polygon_edges.append(collision)
	queue_redraw()
	return true


func _update_box() -> void:
	Left.position = -Vector2(size.x/2-frame_width/2, 0)
	Left.scale = Vector2(1, size.y/50)
	Right.position = Vector2(size.x/2-frame_width/2, 0)
	Right.scale = Vector2(1, size.y/50)
	Up.position = Vector2(0, size.y/2-frame_width/2)
	Up.scale.y = size.x/50
	Down.position = -Vector2(0, size.y/2-frame_width/2)
	Down.scale.y = size.x/50
	box.size = size
	box.position = -size/2


func _draw() -> void:
	if not polygon.is_empty():
		draw_colored_polygon(polygon, Color.BLACK)
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		draw_polyline(outline, Color.WHITE, frame_width, true)
