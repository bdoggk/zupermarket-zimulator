class_name Trophies
extends RefCounted
## Trophies (0.18): long-term goals for the whole game (Brand.TROPHIES):
## serve 1,000 shoppers, reach a 5-star rating, string together a Perfect
## Week, knock out 50 skeletons... Each one pays cash when you earn it, and
## a few let you build a trophy decoration (Brand.FURNITURE "trophy").
##
## Most of them count things over the whole game: Game.career keeps the
## totals of the days that are over, and today's Game.stats are added on
## top (value()).

signal earned(trophy: Dictionary)

var have := {}  # trophy id -> the day you earned it


func is_earned(id: String) -> bool:
	return have.has(id)


func count() -> int:
	return have.size()


static func total() -> int:
	return Brand.TROPHIES.size()


static func find(id: String) -> Dictionary:
	for t: Dictionary in Brand.TROPHIES:
		if t.id == id:
			return t
	return {}


## How much of a trophy's stat you have now.
static func value(stat: String) -> float:
	var st: Dictionary = Game.stats
	var c: Dictionary = Game.career
	match stat:
		"customers", "revenue", "happy", "you_cleaned", "knockouts", "zt_likes":
			return float(c.get(stat, 0.0)) + float(st.get(stat, 0.0))
		"spies":
			return float(c.get("spies", 0)) + float(st.get("spies_caught", 0))
		"raids":
			return float(c.get("raids", 0)) + float(st.get("raids_won", 0))
		"zomtok":
			return float(c.get("zt_likes", 0)) + float(st.get("zt_likes", 0))
		"clean_closes", "loans_repaid":
			return float(c.get(stat, 0))
		"level":
			return float(Game.level)
		"day":
			return float(Game.day)
		"licensed":
			return float(Game.licensed.size())
		"goals":
			return float(Game.goals.completed)
		"streak":
			return float(Game.goals.best_streak)
		"stars":
			return Game.rating.best
		"registers":
			return float(Game.store.registers.size()) if Game.in_game() else 0.0
		"staff":
			return float(Game.staff.size())
		"staff_level":
			var top := 0
			for e: Dictionary in Game.staff:
				top = maxi(top, int(e.get("level", 1)))
			return float(top)
		"lots":
			return float(Game.expansions)
		"hearse":
			return 1.0 if Game.has_upgrade("hearse") else 0.0
		"vampires_today":
			return float(st.get("served_kinds", {}).get("vampire", 0))
		"plots":
			return float(Game.war.plots.count(GangWar.YOU))
		"snake":
			return float(Game.snake_best)
	return 0.0


## How far along a trophy is, 0 to 1.
static func fraction(t: Dictionary) -> float:
	return clampf(value(t.stat) / float(t.target), 0.0, 1.0)


## Awards every trophy you've just earned (cash and all).
func check() -> void:
	if not Game.in_game():
		return
	for t: Dictionary in Brand.TROPHIES:
		if have.has(t.id):
			continue
		if value(t.stat) >= float(t.target) - 0.0001:
			have[t.id] = Game.day
			Game.money += float(t.cash)
			earned.emit(t)


## The trophy decorations you can build (Brand.FURNITURE "trophy").
func decor_unlocked(furniture_id: String) -> bool:
	var need: String = Game.FURNITURE.get(furniture_id, {}).get("trophy", "")
	return need == "" or have.has(need)


func to_dict() -> Dictionary:
	return {"have": have}


func from_dict(d: Dictionary) -> void:
	have.clear()
	var h: Variant = d.get("have", {})
	if h is Dictionary:
		for id: String in h:
			if not find(id).is_empty():
				have[id] = int(h[id])
