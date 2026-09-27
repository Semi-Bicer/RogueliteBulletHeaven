extends Node2D
## Floor 1 of the T-shaped building. The map itself is painted in the editor on
## the TileMapLayers; this script only answers what gameplay asks the level:
## where the player starts, where enemies may spawn, and which way an enemy
## should walk to reach the player around walls.
##
## Walkable = a cell on `Floor` with nothing on `Walls` and no furniture body
## (group `obstacles`) covering it. Enemy steering uses a
## flow field: a BFS from the player's cell over walkable cells, rebuilt only
## when the player moves to another cell. Enemies with no wall between them
## and the player ignore it and walk straight.

const NEIGHBORS_4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const NEIGHBORS_8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

@onready var floor_layer: TileMapLayer = $Floor
@onready var walls_layer: TileMapLayer = $Walls
@onready var spawn_marker: Marker2D = $PlayerSpawn

var _walkable: Dictionary = {}   ## Vector2i cell -> true
var _cells: Array[Vector2i] = []
var _flow: Dictionary = {}       ## Vector2i cell -> steps to the player's cell
var _flow_origin := Vector2i(1 << 30, 0)


func _ready() -> void:
	add_to_group("level")
	var blocked := _obstacle_cells()
	for cell in floor_layer.get_used_cells():
		if walls_layer.get_cell_source_id(cell) == -1 and not blocked.has(cell):
			_walkable[cell] = true
			_cells.append(cell)


## Cells overlapped by a furniture collision rect. Each cell is shrunk by a few
## pixels first, so a rect that merely touches a cell's edge does not close it.
func _obstacle_cells() -> Dictionary:
	const SHRINK := 4.0
	var tile := Vector2(floor_layer.tile_set.tile_size)
	var out := {}
	for body in get_tree().get_nodes_in_group("obstacles"):
		if not is_ancestor_of(body):
			continue
		for shape_node in body.get_children():
			var rect_shape := (shape_node as CollisionShape2D).shape as RectangleShape2D
			if rect_shape == null:
				continue
			var center := to_local(shape_node.global_position)
			var rect := Rect2(center - rect_shape.size / 2.0, rect_shape.size)
			var first := floor_layer.local_to_map(rect.position)
			var last := floor_layer.local_to_map(rect.end)
			for x in range(first.x, last.x + 1):
				for y in range(first.y, last.y + 1):
					var cell_rect := Rect2(Vector2(x, y) * tile, tile).grow(-SHRINK)
					if cell_rect.intersects(rect):
						out[Vector2i(x, y)] = true
	return out


func player_spawn() -> Vector2:
	return spawn_marker.global_position


## A walkable point between `r_min` and `r_max` from `origin`. With `near`
## set, it is picked within `spread` of that point instead, so one batch
## arrives from one side. Falls back to the farthest-reaching cells when the
## ring holds no floor (e.g. the player stands in a corner of the map).
func random_spawn_point(origin: Vector2, r_min: float, r_max: float,
		near: Vector2 = Vector2.INF, spread: float = 0.0) -> Vector2:
	var candidates: Array[Vector2] = []
	var far_ok: Array[Vector2] = []
	for cell in _cells:
		var p := to_global(floor_layer.map_to_local(cell))
		var d := p.distance_to(origin)
		if d < r_min * 0.6:
			continue
		far_ok.append(p)
		if near != Vector2.INF:
			if p.distance_to(near) <= spread and d >= r_min * 0.6:
				candidates.append(p)
		elif d >= r_min and d <= r_max:
			candidates.append(p)
	if not candidates.is_empty():
		return candidates.pick_random()
	if not far_ok.is_empty():
		return far_ok.pick_random()
	return to_global(floor_layer.map_to_local(_cells.pick_random()))


## Unit vector an enemy at `from` should move along to reach `target`.
func flow_direction(from: Vector2, target: Vector2) -> Vector2:
	var goal := floor_layer.local_to_map(to_local(target))
	if goal != _flow_origin and _walkable.has(goal):
		_rebuild_flow(goal)
	var cell := floor_layer.local_to_map(to_local(from))
	if cell == goal or not _flow.has(cell):
		return from.direction_to(target)
	# Open ground: BFS steps equal the Manhattan distance only when no wall is
	# in the way, so head straight at the player and keep the swarm spread out.
	# Follow the field only when a detour is actually needed.
	var gap := goal - cell
	if _flow[cell] <= absi(gap.x) + absi(gap.y):
		return from.direction_to(target)
	var best := cell
	var best_steps: int = _flow[cell]
	for n in NEIGHBORS_8:
		var next: Vector2i = cell + n
		if not _flow.has(next) or _flow[next] >= best_steps:
			continue
		# No diagonal corner-cutting: both orthogonal cells must be open.
		if n.x != 0 and n.y != 0 and not (_walkable.has(cell + Vector2i(n.x, 0)) and _walkable.has(cell + Vector2i(0, n.y))):
			continue
		best = next
		best_steps = _flow[next]
	if best == cell:
		return from.direction_to(target)
	return from.direction_to(to_global(floor_layer.map_to_local(best)))


func _rebuild_flow(goal: Vector2i) -> void:
	_flow_origin = goal
	_flow = {goal: 0}
	var queue: Array[Vector2i] = [goal]
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for n in NEIGHBORS_4:
			var next: Vector2i = cell + n
			if _walkable.has(next) and not _flow.has(next):
				_flow[next] = _flow[cell] + 1
				queue.append(next)
