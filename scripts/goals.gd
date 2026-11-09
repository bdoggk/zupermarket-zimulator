class_name Goals
extends RefCounted
## Today's goals (0.18). Every morning from day FROM_DAY (day 1 has the
## first-day tips instead) three goals come up, picked to suit the store:
## serve so many shoppers, sell so many of something, serve so many
## witches, mop up, ring people up yourself, throw out a spy, close with a
## clean floor... The numbers grow with the store (and with how yesterday
## went), and each one pays cash and XP the moment it's done; a few can only
## be checked at closing time. Doing all three is a Perfect Day, which pays
## a bonus that grows the more of them you string together (the streak).
##
## Game.goals is the one in play. The HUD shows the list in the top left
## and the computer's Goals app shows it with the rating and trophies.

signal changed
signal done(goal: Dictionary)  # a goal was just done (its reward's been paid)

const FROM_DAY := 2
const COUNT := 3
## Every kind of goal: how often it's picked (by weight), how hard it is
## (scales the reward), and "close": checked at closing time.
const TYPES := {
	"serve": {"weight": 3.0, "hard": 1.0},
	"revenue": {"weight": 3.0, "hard": 1.0},
	"sell": {"weight": 3.0, "hard": 0.8},
	"kind": {"weight": 2.0, "hard": 0.9},
	"happy": {"weight": 2.0, "hard": 1.0},
	"mop": {"weight": 1.5, "hard": 0.6},
	"ring": {"weight": 1.5, "hard": 0.7},
	"spy": {"weight": 1.0, "hard": 0.8},
	"upsell": {"weight": 1.5, "hard": 0.8},
	"license": {"weight": 1.5, "hard": 0.5},
	"decorate": {"weight": 1.0, "hard": 0.4},
	"hire": {"weight": 1.0, "hard": 0.4},
	"knockouts": {"weight": 2.0, "hard": 1.2},
	"raid": {"weight": 1.0, "hard": 1.5},
	"snake": {"weight": 0.5, "hard": 0.5, "fun": true},
	"zomtok": {"weight": 0.4, "hard": 0.3, "fun": true},
	"no_walkouts": {"weight": 1.5, "hard": 1.2, "close": true},
	"clean": {"weight": 1.5, "hard": 1.0, "close": true},
	"profit": {"weight": 1.5, "hard": 1.2, "close": true},
	"rating": {"weight": 1.5, "hard": 1.2, "close": true},
	"inspection": {"weight": 6.0, "hard": 1.0},  # only on the inspector's day (0.19)
	"catch_ghost": {"weight": 6.0, "hard": 0.8},  # only on a ghost day
}
const CASH := 20.0  # a goal pays this (times how hard it is)...
const CASH_PER_LEVEL := 10.0  # ...plus this for every store level
const XP := 15.0
const XP_PER_LEVEL := 6.0
const PERFECT_CASH := 20.0  # a Perfect Day pays this...
const PERFECT_CASH_PER_LEVEL := 10.0  # ...plus this per store level...
const STREAK_STEP := 0.25  # ...and this much more for each one in a row before it...
const STREAK_MAX := 2.5  # ...up to this many times as much
const CLOSE_MIN_SERVED := 10  # "close with nobody walking out" and "a clean floor" need this many shoppers served

var day := 0  # the day `list` is for (0: none yet)
var list: Array[Dictionary] = []  # today's: {type, target, product, kind, cash, xp, done}
var streak := 0  # Perfect Days in a row
var best_streak := 0
var perfect_days := 0
var completed := 0  # goals done, ever
var last_served := 0  # how many shoppers yesterday (the numbers grow from there)
var last_revenue := 0.0
var last_profit := 0.0


## Picks today's goals (if it's a day for them and they aren't picked yet).
func roll() -> void:
	if Game.day < FROM_DAY:  # (none yet: `day` stays 0)
		if day != 0 or not list.is_empty():
			day = 0
			list.clear()
			changed.emit()
		return
	if day == Game.day:
		return
	day = Game.day
	list.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Game.day, Game.level, Game.play_time > 0.0, "goals"])
	var picked := {}
	var closes := 0
	var funs := 0
	for i in COUNT:
		var pool: Array[String] = []
		var weights: Array[float] = []
		for t: String in TYPES:
			var info: Dictionary = TYPES[t]
			if picked.has(t) or not can_pick(t):
				continue
			if info.get("close", false) and closes >= 1:
				continue
			if info.get("fun", false) and funs >= 1:
				continue
			pool.append(t)
			weights.append(float(info.weight))
		if pool.is_empty():
			break
		var t := pool[rng.rand_weighted(PackedFloat32Array(weights))]
		picked[t] = true
		if TYPES[t].get("close", false):
			closes += 1
		if TYPES[t].get("fun", false):
			funs += 1
		list.append(_make(t, rng))
	changed.emit()


## Whether a kind of goal makes sense for the store right now.
func can_pick(t: String) -> bool:
	var war_on: bool = Game.war.on
	match t:
		"mop", "clean":
			return Brand.SPILLS
		"kind":
			return not _kinds().is_empty()
		"spy":
			return Game.in_game() and Game.store.town != null and not Game.war.rival_closed
		"license":
			return Game.licensable_ids().any(func(id): return Game.can_license(id))
		"decorate":
			return Game.level < 12
		"hire":
			return Game.staff.size() < 4 and ["stocker", "cashier", "janitor"].any(func(r): return Game.hire_problem(r) == "")
		"knockouts", "raid":
			return war_on
		"rating":
			return Game.rating.stars() < 4.3
		"inspection":
			return Game.calendar.event() == "inspector"
		"catch_ghost":
			return Game.calendar.event() == "ghost"
	return true


## The kinds of shopper (other than plain zombies) who come to a store of
## this level, as Brand.SHOPPERS ids.
func _kinds() -> Array:
	var out: Array = []
	for id: String in Brand.SHOPPERS:
		var k: Dictionary = Brand.SHOPPERS[id]
		if id != "zombie" and Game.level >= int(k.level) and float(k.weight) >= 1.0:
			out.append(id)
	return out


func _make(t: String, rng: RandomNumberGenerator) -> Dictionary:
	var lv := Game.level
	var served := maxf(float(last_served), 10.0 + 4.0 * lv)  # what a day's like
	var g := {"type": t, "target": 1, "product": "", "kind": "", "done": false}
	match t:
		"serve":
			g.target = maxi(8, roundi(served * rng.randf_range(1.0, 1.15)))
		"revenue":
			var made := maxf(last_revenue, 40.0 + 45.0 * lv)
			g.target = maxi(50, roundi(made * rng.randf_range(1.0, 1.15) / 10.0) * 10)
		"sell":
			var ids: Array = Game.unlocked_ids()
			var hot := ""
			for id: String in ids:
				if float(Game.market.demand.get(id, 1.0)) > 1.25:
					hot = id
			g.product = hot if hot != "" and rng.randf() < 0.6 else ids[rng.randi() % ids.size()]
			g.target = clampi(4 + lv + rng.randi_range(0, 3), 5, 30)
		"kind":
			var kinds := _kinds()
			g.kind = kinds[rng.randi() % kinds.size()]
			var w := float(Brand.SHOPPERS[g.kind].weight)
			g.target = clampi(roundi(served * w / 25.0 * rng.randf_range(0.8, 1.1)), 2, 12)
		"happy":
			g.target = maxi(5, roundi(served * 0.6))
		"mop":
			g.target = clampi(3 + floori(lv / 3.0), 3, 12)
		"ring":
			g.target = clampi(5 + lv, 5, 20)
		"upsell":
			g.target = clampi(4 + lv, 5, 25)
		"knockouts":
			g.target = rng.randi_range(3, 5)
		"snake":
			g.target = clampi(10 + floori(Game.snake_best / 4.0), 10, 25)
		"zomtok":
			g.target = 5
		"profit":
			g.target = maxi(50, roundi(maxf(last_profit, 30.0 + 30.0 * lv) * rng.randf_range(1.0, 1.1) / 10.0) * 10)
		"rating":
			g.target = clampf(ceilf((Game.rating.stars() + 0.25) * 2.0) / 2.0, 3.5, 4.5)  # (a little better than now)
	var hard := float(TYPES[t].hard)
	g.cash = roundf((CASH + CASH_PER_LEVEL * lv) * hard)
	g.xp = roundf((XP + XP_PER_LEVEL * lv) * hard)
	return g


## What a goal says: "Serve 40 shoppers".
static func text(g: Dictionary) -> String:
	var f: String = Brand.GOALS.get(g.type, g.type)
	match str(g.type):
		"sell":
			return f % [int(g.target), Game.product_name(g.product)]
		"kind":
			var k: Dictionary = Brand.SHOPPERS.get(g.kind, {})
			return f % [int(g.target), Game.shopper_plural(k) if not k.is_empty() else "shoppers"]
		"rating":
			return f % ("%.1f" % float(g.target)).replace(".0", "")
		"spy", "license", "decorate", "hire", "raid", "no_walkouts", "clean", "inspection", "catch_ghost":
			return f
	return f % int(g.target)


## How far along a goal is today (the same units as its target).
static func progress(g: Dictionary) -> float:
	var st: Dictionary = Game.stats
	match str(g.type):
		"serve":
			return float(st.get("customers", 0))
		"revenue":
			return floorf(float(st.get("revenue", 0.0)))
		"sell":
			return float(st.get("sold", {}).get(g.product, 0))
		"kind":
			return float(st.get("served_kinds", {}).get(g.kind, 0))
		"happy":
			return float(st.get("happy", 0))
		"mop":
			return float(st.get("you_cleaned", 0))
		"ring":
			return float(st.get("you_rang", 0))
		"spy":
			return float(st.get("spies_caught", 0))
		"upsell":
			return float(st.get("over_market", 0))
		"license":
			return float(st.get("licenses", 0))
		"decorate":
			return float(st.get("decor_bought", 0))
		"hire":
			return float(st.get("hired", 0))
		"knockouts":
			return float(st.get("knockouts", 0))
		"raid":
			return float(st.get("raids_won", 0))
		"snake":
			return float(st.get("snake", 0))
		"zomtok":
			return float(st.get("zt_likes", 0))
		"no_walkouts", "clean":
			return 1.0 if close_ok(g) else 0.0
		"profit":
			return floorf(Game.profit_today())
		"rating":
			return Game.rating.stars()
		"inspection":
			return 1.0 if str(st.get("inspection", "")) in ["A", "B"] else 0.0
		"catch_ghost":
			return float(st.get("ghosts_caught", 0))
	return 0.0


## "12/40" (or "" for a goal that's done or can only be checked at closing).
static func progress_text(g: Dictionary) -> String:
	if g.done:
		return ""
	match str(g.type):
		"no_walkouts":
			return "%d walked out" % int(Game.stats.get("walkouts", 0)) if int(Game.stats.get("walkouts", 0)) > 0 else "at closing"
		"clean":
			return "at closing"
		"revenue", "profit":
			var now := int(progress(g))
			return "%s$%d/$%d" % ["-" if now < 0 else "", absi(now), int(g.target)]
		"rating":
			return "%s now" % ("%.1f" % Game.rating.stars())
		"spy", "license", "decorate", "hire", "raid", "inspection", "catch_ghost":
			return ""
	return "%d/%d" % [mini(int(progress(g)), int(g.target)), int(g.target)]


## A closing-time goal would be met if the store closed right now.
static func close_ok(g: Dictionary) -> bool:
	var st: Dictionary = Game.stats
	match str(g.type):
		"no_walkouts":
			return int(st.get("walkouts", 0)) == 0 and int(st.get("customers", 0)) >= CLOSE_MIN_SERVED
		"clean":
			return Game.in_game() and Game.store.spills.is_empty() and int(st.get("customers", 0)) >= CLOSE_MIN_SERVED
	return false


## Pays for any goal that's just been done (not the closing-time ones).
func check() -> void:
	for g in list:
		if g.done or TYPES[g.type].get("close", false):
			continue
		if progress(g) >= float(g.target):
			_complete(g)


func _complete(g: Dictionary) -> void:
	g.done = true
	completed += 1
	Game.money += float(g.cash)
	Game.add_xp(float(g.xp))
	Game.stats.goals_done = int(Game.stats.get("goals_done", 0)) + 1
	Game.stats.goal_cash = float(Game.stats.get("goal_cash", 0.0)) + float(g.cash)
	done.emit(g)
	changed.emit()


func done_count() -> int:
	return list.filter(func(g): return g.done).size()


## Closing time: checks the closing-time goals, then whether it was a
## Perfect Day (the streak goes on, or starts over). Returns what happened
## for the day's summary: {done, of, perfect, streak, bonus, broke (the
## streak that just ended, or 0)}.
func close() -> Dictionary:
	if list.is_empty():
		return {}
	for g in list:
		if not g.done and TYPES[g.type].get("close", false):
			var ok := close_ok(g) if g.type in ["no_walkouts", "clean"] else progress(g) >= float(g.target)
			if ok:
				_complete(g)
	var all := done_count() == list.size()
	var bonus := 0.0
	var broke := 0 if all else streak  # (a streak that's just ended)
	if all:
		streak += 1
		perfect_days += 1
		best_streak = maxi(best_streak, streak)
		bonus = perfect_bonus(streak)
		Game.money += bonus
		Game.stats.goal_cash = float(Game.stats.get("goal_cash", 0.0)) + bonus
	else:
		streak = 0
	changed.emit()
	return {"done": done_count(), "of": list.size(), "perfect": all, "streak": streak, "bonus": bonus, "broke": broke}


## What a Perfect Day pays, `n` in a row.
static func perfect_bonus(n: int) -> float:
	var times := minf(STREAK_MAX, 1.0 + STREAK_STEP * (n - 1))
	return roundf((PERFECT_CASH + PERFECT_CASH_PER_LEVEL * Game.level) * times)


## How the day went (for tomorrow's numbers).
func remember(served: int, revenue: float, profit: float) -> void:
	last_served = served
	last_revenue = revenue
	last_profit = profit


func to_dict() -> Dictionary:
	return {"day": day, "list": list, "streak": streak, "best_streak": best_streak, "perfect": perfect_days,
		"completed": completed, "last_served": last_served, "last_revenue": last_revenue, "last_profit": last_profit}


func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", 0))
	list.clear()
	for g in d.get("list", []):
		if g is Dictionary and TYPES.has(str(g.get("type", ""))):
			var t := str(g.type)
			if t == "sell" and not Game.PRODUCTS.has(str(g.get("product", ""))):
				continue
			if t == "kind" and not Brand.SHOPPERS.has(str(g.get("kind", ""))):
				continue
			list.append({"type": t, "target": float(g.get("target", 1)) if t == "rating" else int(g.get("target", 1)),
				"product": str(g.get("product", "")), "kind": str(g.get("kind", "")),
				"cash": float(g.get("cash", 0.0)), "xp": float(g.get("xp", 0.0)), "done": bool(g.get("done", false))})
	streak = maxi(0, int(d.get("streak", 0)))
	best_streak = maxi(streak, int(d.get("best_streak", 0)))
	perfect_days = maxi(0, int(d.get("perfect", 0)))
	completed = maxi(0, int(d.get("completed", 0)))
	last_served = maxi(0, int(d.get("last_served", 0)))
	last_revenue = maxf(0.0, float(d.get("last_revenue", 0.0)))
	last_profit = float(d.get("last_profit", 0.0))
