extends RefCounted
## Breadth-first search on the hex grid. Every step costs the same, so BFS gives the
## same shortest routes as A*, plus the full distance field needed for alternative
## stopping positions. Neighbour order is fixed, so results are deterministic.

const Hex = preload("res://sim/hex.gd")


## Distance from the nearest seed to every passable tile not in `blocked`.
static func distance_field(grid, seeds: Array, start_dist: int, blocked: Dictionary) -> Dictionary:
	var dist := {}
	var queue: Array[Vector2i] = []
	for s in seeds:
		if not dist.has(s):
			dist[s] = start_dist
			queue.append(s)
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		var d: int = dist[t] + 1
		for n in Hex.neighbors(t):
			if dist.has(n) or blocked.has(n) or not grid.is_passable(n):
				continue
			dist[n] = d
			queue.append(n)
	return dist


## Multi-source search that also records which source reached each tile first.
## Sources are processed in the given order, so ties go to earlier sources.
static func labelled_field(grid, sources: Array, labels: Array) -> Dictionary:
	var dist := {}
	var label := {}
	var queue: Array[Vector2i] = []
	for i in range(sources.size()):
		var s: Vector2i = sources[i]
		if not dist.has(s):
			dist[s] = 0
			label[s] = labels[i]
			queue.append(s)
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		for n in Hex.neighbors(t):
			if dist.has(n) or not grid.is_passable(n):
				continue
			dist[n] = dist[t] + 1
			label[n] = label[t]
			queue.append(n)
	return {"dist": dist, "label": label}


## Search from `start` over passable tiles not in `blocked`. The start tile is always
## included. When `prefer_first` is a neighbour of start, it is expanded first, so any
## shortest route that can begin with that step will begin with it.
static func search(grid, start: Vector2i, blocked: Dictionary, prefer_first: Variant = null) -> Dictionary:
	var dist := {start: 0}
	var parent := {}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		var nbs := Hex.neighbors(t)
		if t == start and prefer_first != null:
			var i := nbs.find(prefer_first)
			if i > 0:
				nbs.remove_at(i)
				nbs.push_front(prefer_first)
		for n in nbs:
			if dist.has(n) or blocked.has(n) or not grid.is_passable(n):
				continue
			dist[n] = dist[t] + 1
			parent[n] = t
			queue.append(n)
	return {"dist": dist, "parent": parent, "start": start}


## Route from the search start to goal, inclusive of both ends; empty if unreachable.
static func route(result: Dictionary, goal: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not result.dist.has(goal):
		return out
	var t := goal
	out.append(t)
	while t != result.start:
		t = result.parent[t]
		out.append(t)
	out.reverse()
	return out


## Convenience: shortest route on terrain only.
static func find_route(grid, from: Vector2i, to: Vector2i, blocked: Dictionary = {}) -> Array[Vector2i]:
	return route(search(grid, from, blocked), to)
