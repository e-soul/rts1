extends "res://tests/test_base.gd"
## Section 5: cancelling frees the destination immediately; form changes.


func test_reversal_returns_to_source_and_releases_claim() -> void:
	var s := load_scenario("mid_step_reversal")
	var u = s.get_unit(3)  # shaper at (6,5): 8 ticks per step
	order(s, u, "move", 7, 5)
	run(s, 4)  # step started on tick 1, progress 3/8
	eq(s.occupancy.claim_owner(0, T(7, 5)), u.id, "final step holds the stopping claim")
	order(s, u, "move", 3, 5)
	check(u.step.returning, "new route does not start with the current step: return")
	eq(s.occupancy.claim_owner(0, T(7, 5)), -1, "stopping claim released immediately")
	eq(u.tile, T(6, 5), "logical occupancy stays at the source")
	eq(s.occupancy.claim_owner(0, T(6, 5)), u.id, "source claim kept (first step never completed)")
	var back := run_until(s, func(): return u.step == null or not u.step.returning)
	eq(back, 3, "return takes as long as the distance travelled")
	eq(u.tile, T(6, 5))
	run_until(s, func(): return u.order == null)
	check(settled_at(u, 3, 5), "then went the new way")


func test_retarget_continuing_the_step_keeps_going() -> void:
	var s := load_scenario("mid_step_reversal")
	var u = s.get_unit(3)
	order(s, u, "move", 7, 5)
	run(s, 3)
	order(s, u, "move", 9, 5)
	check(not u.step.returning, "route starts with the current step: continue")
	eq(s.occupancy.claim_owner(0, T(7, 5)), -1, "no longer stops at B: claim released")
	var total := 3 + run_until(s, func(): return u.order == null)
	eq(total, 1 + 3 * 8, "no time lost")
	check(settled_at(u, 9, 5), "arrived")


func test_orders_during_return_replace_pending_order_only() -> void:
	var s := load_scenario("mid_step_reversal")
	var u = s.get_unit(3)
	order(s, u, "move", 7, 5)
	run(s, 5)
	order(s, u, "move", 3, 5)
	check(u.step.returning, "returning")
	order(s, u, "move", 9, 5)  # would continue the original step, but the return is not interrupted
	check(u.step.returning, "return not interrupted")
	eq(u.order.target, T(9, 5), "pending order replaced")
	eq(s.occupancy.claim_owner(0, T(7, 5)), -1, "B needs a fresh step check")
	run_until(s, func(): return u.step == null or not u.step.returning)
	eq(u.tile, T(6, 5), "back at source")
	run_until(s, func(): return u.order == null)
	check(settled_at(u, 9, 5), "then executed the replacement order")


func test_repeated_cancellation_gains_no_speed() -> void:
	var s := load_scenario("mid_step_reversal")
	var u = s.get_unit(3)
	# Flip the order every 3 ticks for 60 ticks: the unit never completes a step.
	for i in range(20):
		order(s, u, "move", 11 if i % 2 == 0 else 1, 5)
		run(s, 3)
		eq(u.tile, T(6, 5), "logical position never advanced (flip %d)" % i)
	var t := run_until(s, func(): return u.order == null)
	var direct := load_scenario("mid_step_reversal")
	var d = direct.get_unit(3)
	direct.issue_order(d, "move", T(1, 5))
	var t_direct := run_until(direct, func(): return d.order == null)
	# The last order was given 3 ticks before t started counting.
	check(t + 3 >= t_direct, "after cancellations the unit is not faster than a direct move (%d+3 vs %d)" % [t, t_direct])
	check(settled_at(u, 1, 5), "arrived at last target")


func test_form_change_takes_time_and_defers_orders() -> void:
	var s := load_scenario("mid_step_reversal")
	var u = s.get_unit(1)
	s.kill(s.enemy_units()[0])
	eq(s.command_toggle_form(u.id).ok, true, "form change starts when settled")
	check(not s.command_toggle_form(u.id).ok, "cannot be cancelled or restarted")
	s.issue_order(u, "attack_move", T(1, 3))
	var ticks := int(round(float(s.tuning.form_change_time) / s.dt))
	run(s, ticks - 1)
	eq(u.form, "assault", "still changing")
	eq(u.tile, T(4, 3), "order waits for the form change")
	check(u.step == null, "not moving during form change")
	run(s, 1)
	eq(u.form, "guard", "form changed")
	eq(u.max_hp, float(s.tuning.units.striker_guard.hp))
	run_until(s, func(): return u.order == null, 400)
	check(settled_at(u, 1, 3), "deferred order executed after the change")


func test_form_change_rejected_in_transit() -> void:
	var s := load_scenario("mid_step_reversal")
	s.kill(s.enemy_units()[0])
	var u = s.get_unit(1)
	s.issue_order(u, "attack_move", T(1, 3))
	run(s, 2)
	var r := s.command_toggle_form(u.id)
	check(not r.ok, "rejected while moving")
	check(r.reason.contains("transit"), "explains why: " + r.reason)
	var shaper := s.command_toggle_form(3)
	check(not shaper.ok, "shapers have no form change")
