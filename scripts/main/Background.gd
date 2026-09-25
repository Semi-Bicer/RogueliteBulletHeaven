extends Node2D
## Static grid floor drawn once. Cheap, and it gives movement a sense of
## speed without needing any art assets.

const CELL := 128.0
const LINE_COLOR := Color(1, 1, 1, 0.045)
const EDGE_COLOR := Color(0.98, 0.35, 0.40, 0.35)


func _draw() -> void:
	var r: Rect2 = Player.ARENA
	var x := r.position.x
	while x <= r.end.x:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), LINE_COLOR, 1.0)
		x += CELL
	var y := r.position.y
	while y <= r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), LINE_COLOR, 1.0)
		y += CELL
	draw_rect(r, EDGE_COLOR, false, 6.0)
