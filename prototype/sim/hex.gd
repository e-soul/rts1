extends RefCounted
## Pointy-top hex maths on axial coordinates stored as Vector2i(q, r).
## Follows the Red Blob Games hex grid guide.

## Directions in screen order: E, NE, NW, W, SW, SE (angle 0, -60, -120, 180, 120, 60 degrees).
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
const DIRECTION_NAMES: Array[String] = ["E", "NE", "NW", "W", "SW", "SE"]
const E := 0
const NE := 1
const NW := 2
const W := 3
const SW := 4
const SE := 5
const SQRT3 := 1.7320508075688772


static func neighbor(t: Vector2i, dir: int) -> Vector2i:
	return t + DIRECTIONS[posmod(dir, 6)]


static func neighbors(t: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRECTIONS:
		out.append(t + d)
	return out


static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2


## Stable tile order: by r, then q.
static func less(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


static func sorted(tiles: Array) -> Array:
	var copy := tiles.duplicate()
	copy.sort_custom(less)
	return copy


## Direction index from a to an adjacent b, or -1.
static func direction_to(a: Vector2i, b: Vector2i) -> int:
	return DIRECTIONS.find(b - a)


## Direction index for a screen-space vector (y down), snapped to six sectors.
static func direction_from_vector(v: Vector2) -> int:
	var angle := atan2(v.y, v.x)
	var sector := int(round(angle / (PI / 3.0)))
	# sector: 0=E, 1=SE, 2=SW, 3/-3=W, -1=NE, -2=NW
	match posmod(sector, 6):
		0: return 0
		1: return 5
		2: return 4
		3: return 3
		4: return 2
		5: return 1
	return 0


static func to_pixel(t: Vector2i, size: float) -> Vector2:
	return Vector2(size * SQRT3 * (t.x + t.y / 2.0), size * 1.5 * t.y)


static func from_pixel(p: Vector2, size: float) -> Vector2i:
	var q := (SQRT3 / 3.0 * p.x - p.y / 3.0) / size
	var r := (2.0 / 3.0 * p.y) / size
	return round_axial(q, r)


static func round_axial(qf: float, rf: float) -> Vector2i:
	var sf := -qf - rf
	var q := roundf(qf)
	var r := roundf(rf)
	var s := roundf(sf)
	var dq := absf(q - qf)
	var dr := absf(r - rf)
	var ds := absf(s - sf)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	return Vector2i(int(q), int(r))


## Tiles on the straight line from a to b, inclusive.
static func line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var n := distance(a, b)
	var out: Array[Vector2i] = []
	for i in range(n + 1):
		var t := 0.0 if n == 0 else float(i) / n
		var qf := lerpf(a.x + 1e-6, b.x + 1e-6, t)
		var rf := lerpf(a.y + 1e-6, b.y + 1e-6, t)
		out.append(round_axial(qf, rf))
	return out


## Odd-r offset (col, row) to axial. Map files use offset coordinates.
static func offset_to_axial(col: int, row: int) -> Vector2i:
	return Vector2i(col - (row - (row & 1)) / 2, row)


static func axial_to_offset(t: Vector2i) -> Vector2i:
	return Vector2i(t.x + (t.y - (t.y & 1)) / 2, t.y)


static func corners(center: Vector2, size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(6):
		var angle := deg_to_rad(60.0 * i - 30.0)
		pts.append(center + Vector2(cos(angle), sin(angle)) * size)
	return pts
