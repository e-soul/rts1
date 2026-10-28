extends "res://tests/test_base.gd"
## The player control model: selection cycling, default action, rejections, cancel.


func _three() -> Sim:
	return make(field(10, 6), [["shaper", 1, 1], ["striker", 2, 1, "assault"], ["shaper", 3, 1]])


func test_cycling_wraps_and_preserves_cursor() -> void:
	var s := _three()
	var c := PlayerControl.new(s)
	eq(c.selected_id, 1, "first unit selected")
	c.set_cursor(T(7, 4))
	c.select_next()
	eq(c.selected_id, 2)
	c.select_next()
	c.select_next()
	eq(c.selected_id, 1, "wraps forward")
	c.select_prev()
	eq(c.selected_id, 3, "wraps backward")
	eq(c.cursor, T(7, 4), "tile preserved")


func test_a_rb_a_rb_a_sends_three_units() -> void:
	var s := _three()
	var c := PlayerControl.new(s)
	c.set_cursor(T(7, 4))
	c.default_action()
	c.select_next()
	c.default_action()
	c.select_next()
	c.default_action()
	for u in s.player_units():
		check(u.order != null and u.order.target == T(7, 4), "unit %d ordered to the tile" % u.id)
	run_until(s, func(): return s.player_units().all(func(u): return u.order == null and u.is_settled()), 400)
	var tiles := {}
	for u in s.player_units():
		tiles[u.tile] = true
	eq(tiles.size(), 3, "three distinct stopping positions")
	check(tiles.has(T(7, 4)), "one unit on the target")


func test_preview_reports_alternative() -> void:
	var s := _three()
	var c := PlayerControl.new(s)
	c.set_cursor(T(2, 1))
	var p := c.preview()
	check(p.ok, "own unit tile is a valid target")
	eq(p.kind, "alternative")
	check(p.text.contains("destination taken"), p.text)
	check(p.stop != T(2, 1), "stops nearby")


func test_rejection_gives_reason_and_keeps_order() -> void:
	var s := make(["#####", "#...#", "#####"], [["striker", 1, 1, "assault"]])
	var c := PlayerControl.new(s)
	c.set_cursor(T(3, 1))
	c.default_action()
	var before = s.get_unit(1).order
	c.set_cursor(T(2, 0))
	var res := c.default_action()
	check(not res.ok, "blocked terrain rejected for a Striker")
	check(res.reason != "", "has a reason")
	check(s.get_unit(1).order == before, "existing order kept")


func test_cancel_never_stops_units() -> void:
	var s := _three()
	var c := PlayerControl.new(s)
	c.set_cursor(T(8, 4))
	c.default_action()
	var res := c.cancel()
	check(not res.ok and res.reason == "Nothing to cancel")
	check(s.get_unit(1).order != null, "order kept")
	eq(c.selected_id, 1, "selection kept")


func test_selection_moves_on_when_selected_unit_dies() -> void:
	var s := _three()
	var c := PlayerControl.new(s)
	c.select_next()
	s.kill(s.get_unit(2))
	c.ensure_selection()
	eq(c.selected_id, 3, "next unit selected")
	s.kill(s.get_unit(3))
	c.ensure_selection()
	eq(c.selected_id, 1, "wraps to the first")
	s.kill(s.get_unit(1))
	c.ensure_selection()
	eq(c.selected_id, -1, "no units left")


func test_ability_toggles_striker_form_only() -> void:
	var s := _three()
	var c := PlayerControl.new(s)
	var res := c.ability()
	check(not res.ok, "shapers have no form change")
	c.select_next()
	res = c.ability()
	check(res.ok, "striker form change accepted")
	check(s.get_unit(2).is_changing_form())


func test_cursor_stays_on_map() -> void:
	var s := _three()
	var c := PlayerControl.new(s)
	c.set_cursor(T(0, 0))
	check(not c.move_cursor(Hex.W), "cannot leave the map")
	eq(c.cursor, T(0, 0))
	check(c.move_cursor(Hex.E))
	eq(c.cursor, T(1, 0))
