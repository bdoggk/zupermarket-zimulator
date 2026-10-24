class_name GangWar
extends RefCounted
## The gang war (Brand.WAR): from store level LEVEL, Bone Mart's skeleton
## gang against your zombie gang. This keeps the score: who owns the land
## east of Bone Mart (each plot is a branch store that runs itself), your
## gang, your weapons, today's raids, and whether Bone Mart is closed after
## your gang smashed it up. Game.war is the one in play; Turf
## (scripts/turf.gd) plays it out in town, and ui/war_cutscene.gd starts it.

signal started  # the cutscene is over: it's war
signal changed  # land, gang or weapons changed (the Turf app redraws)
signal plot_changed(i: int)  # plot i has a new owner (the town rebuilds it)
signal raid_due(target: int)  # a Bone Mart gang sets off for your store (MAIN) or branch `target`
signal raid_sent(target: int)  # you sent your gang to Bone Mart (MAIN) or its branch `target`
signal rival_closed_changed  # Bone Mart closed (smashed up) or open again

const LEVEL := 15  # the store level the war starts at
const MAIN := -1  # a raid on the main store (yours or Bone Mart's), not a branch
const YOU := "you"
const BONE := "bone"
## Land gets dearer as it runs out: the 1st plot anyone buys, the 2nd...
const PLOT_COST := [5000.0, 6500.0, 8000.0, 9500.0]
const BRANCH_TAKE := 400.0  # what a branch makes each day, after its crew's wages...
const BRANCH_TAKE_PER_LEVEL := 25.0  # ...plus this for every store level past LEVEL
const BRANCH_PULL := 0.03  # each branch of Bone Mart's sends this many more shoppers there (each of yours, fewer)
const BONE_BUYS_EVERY := 3  # days between Bone Mart buying land (while there's any left)
const GANG_MAX := 6
const GANG_HIRE := 300.0
const GANG_WAGE := 80.0
const RAID_FROM := 9 * 60 + 30  # Bone Mart's gangs come between 9:30 AM...
const RAID_TO := 18 * 60  # ...and 6 PM
const BRANCH_RAID_CHANCE := 0.35  # a raid goes for one of your branches (if you have any)
const ROB_SHARE := 0.15  # a robbery takes this much of your money...
const ROB_MIN := 50.0
const ROB_MAX := 2500.0  # ...up to this
const LOOT := 500.0  # what your gang takes from Bone Mart's till...
const LOOT_PER_LEVEL := 50.0  # ...plus this for every store level past LEVEL
const WIN_XP := 10.0  # for every skeleton you (or your gang) knock out

var on := false  # the war has started (the cutscene played)
var pending := false  # the store reached LEVEL: the cutscene is waiting to play
var plots: Array[String] = []  # who owns each plot: "", YOU or BONE
var gang: Array[Dictionary] = []  # your gang: [{id, name, look, out}] (out: knocked out until that day)
var weapons := {}  # "nunchucks" / "glock" -> true once bought
var raids: Array = []  # today's raids on you: [[game minute, target]], soonest first
var rival_closed := false  # Bone Mart is closed for the rest of today
var bone_bought_day := 0  # when Bone Mart last bought land
var bought_back := false  # you'd bought Bone Mart (before 0.13): Mr. Bones bought it back
var _next_id := 1


func _init() -> void:
	for i in plot_count():
		plots.append("")


static func plot_count() -> int:
	return (Brand.WAR.plot_names as Array).size() if not Brand.WAR.is_empty() else 0


static func plot_name(i: int) -> String:
	return str(Brand.WAR.plot_names[i]) if i >= 0 and i < plot_count() else "?"


# ---------------------------------------------------------------- starting

## The store went up a level: at LEVEL the war is coming (the HUD plays the
## cutscene as soon as nothing's in the way).
func check_level(level: int) -> void:
	if not on and not pending and level >= LEVEL and not Brand.WAR.is_empty():
		pending = true


## The cutscene is over: it's war. Bone Mart buys its first plot straight away.
func begin() -> void:
	if on:
		return
	on = true
	pending = false
	Game.message.emit(Brand.WAR.started)
	_bone_buys(true)
	if Game.is_open:  # mid-day: the first gang comes a little later today
		var at := maxi(int(Game.minute) + 90, RAID_FROM)
		if at < RAID_TO:
			raids = [[at, MAIN]]
	started.emit()
	changed.emit()


# ---------------------------------------------------------------- land

func owned_by(who: String) -> Array[int]:
	var out: Array[int] = []
	for i in plots.size():
		if plots[i] == who:
			out.append(i)
	return out


func free_plots() -> Array[int]:
	return owned_by("")


## What the next plot costs (land gets dearer as it runs out).
func plot_cost() -> float:
	var taken := plots.size() - free_plots().size()
	return PLOT_COST[mini(taken, PLOT_COST.size() - 1)]


## Why you can't buy plot `i` ("" means you can).
func buy_problem(i: int) -> String:
	if not on:
		return "Not for sale until the gang war (store level %d)" % LEVEL
	if i < 0 or i >= plots.size():
		return "No such land"
	if plots[i] == YOU:
		return "It's yours"
	if plots[i] == BONE:
		return "%s owns it: send your gang to take it" % Brand.RIVAL.name
	if Game.money + 0.001 < plot_cost():
		return "Not enough money"
	return ""


func buy_plot(i: int) -> bool:
	if buy_problem(i) != "" or not Game.spend(plot_cost()):
		return false
	set_plot(i, YOU)
	Game.message.emit(Brand.WAR.bought_plot % [plot_name(i), Brand.WAR.your_branch])
	Settings.vibrate(0.6, 0.3)
	return true


func set_plot(i: int, who: String) -> void:
	if plots[i] == who:
		return
	plots[i] = who
	plot_changed.emit(i)
	changed.emit()


## Bone Mart buys land: right away when the war starts, then every
## BONE_BUYS_EVERY days while there's any left.
func _bone_buys(now := false) -> void:
	var free := free_plots()
	if free.is_empty() or (not now and Game.day - bone_bought_day < BONE_BUYS_EVERY):
		return
	var i: int = free[1] if free.size() > 1 and now else free.pick_random()  # (the far north lot first)
	bone_bought_day = Game.day
	set_plot(i, BONE)
	Game.message.emit(Brand.WAR.bone_bought % [plot_name(i), Brand.WAR.bone_branch])


## What one of your branches makes in a day.
func branch_take() -> float:
	return BRANCH_TAKE + BRANCH_TAKE_PER_LEVEL * maxi(0, Game.level - LEVEL)


## Shoppers: Bone Mart's branches send more of them its way, yours fewer.
func rival_pull_change() -> float:
	return BRANCH_PULL * (owned_by(BONE).size() - owned_by(YOU).size())


# ---------------------------------------------------------------- your gang

func gang_size() -> int:
	return gang.size()


func ready_gang() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in gang:
		if is_ready(g):
			out.append(g)
	return out


func is_ready(g: Dictionary) -> bool:
	return Game.day >= int(g.get("out", 0))


func hire_problem() -> String:
	if not on:
		return "Not until the gang war"
	if gang.size() >= GANG_MAX:
		return "Your gang is as big as it gets"
	if Game.money + 0.001 < GANG_HIRE:
		return "Not enough money"
	return ""


func hire() -> Dictionary:
	if hire_problem() != "" or not Game.spend(GANG_HIRE):
		return {}
	var names: Array = (Brand.WAR.zombie_names as Array).filter(func(n): return not gang.any(func(g): return g.name == n))
	var entry := {"id": _next_id, "name": str(names.pick_random()) if not names.is_empty() else "Rotter %d" % _next_id,
		"look": randi() % (Brand.WAR.textures.zombie_gang as Array).size(), "out": 0}
	_next_id += 1
	gang.append(entry)
	Game.message.emit(Brand.WAR.hired % [entry.name, int(GANG_WAGE)])
	changed.emit()
	return entry


func fire(id: int) -> void:
	for g in gang:
		if int(g.id) == id:
			gang.erase(g)
			Game.message.emit(Brand.WAR.fired % g.name)
			changed.emit()
			return


## Gang member `id` got knocked out: out cold until tomorrow.
func knocked_out(id: int) -> void:
	for g in gang:
		if int(g.id) == id:
			g.out = Game.day + 1
			Game.message.emit(Brand.WAR.gangster_out % g.name)
			changed.emit()
			return


func wages() -> float:
	return GANG_WAGE * gang.size()


# ---------------------------------------------------------------- weapons

func weapon() -> String:
	if weapons.has("glock"):
		return "glock"
	if weapons.has("nunchucks"):
		return "nunchucks"
	return "fists"


func weapon_problem(id: String) -> String:
	if not on:
		return "Not until the gang war"
	if weapons.has(id):
		return "You have one"
	if Game.money + 0.001 < float(Brand.WAR.weapons[id].cost):
		return "Not enough money"
	return ""


func buy_weapon(id: String) -> bool:
	if weapon_problem(id) != "" or not Game.spend(float(Brand.WAR.weapons[id].cost)):
		return false
	weapons[id] = true
	Game.message.emit(Brand.WAR.weapons[id].bought)
	Settings.vibrate(0.4, 0.15)
	changed.emit()
	return true


# ---------------------------------------------------------------- raids

## Each morning: who's back on their feet, Bone Mart open again, maybe
## buying more land, and when its gangs come today.
func morning() -> void:
	if not on:
		return
	var back: Array[String] = []
	for g in gang:
		if int(g.get("out", 0)) == Game.day:
			back.append(str(g.name))
	if not back.is_empty():
		Game.message.emit(Brand.WAR.gang_back % Staff._list(back))
	if rival_closed:
		rival_closed = false
		rival_closed_changed.emit()
		Game.message.emit(Brand.WAR.bone_reopened)
	_bone_buys()
	roll_raids()
	changed.emit()


## Today's raids: one, or two once Bone Mart has a couple of branches, at
## random times while you're open.
func roll_raids() -> void:
	raids = []
	if not on:
		return
	var count := 2 if owned_by(BONE).size() >= 2 else 1
	var span := RAID_TO - RAID_FROM
	for k in count:
		var lo := RAID_FROM + span * k / count
		var target := MAIN
		var mine := owned_by(YOU)
		if not mine.is_empty() and randf() < BRANCH_RAID_CHANCE:
			target = mine.pick_random()
		raids.append([randi_range(lo + 10, lo + span / count - 10), target])


## Called while you're open: a gang sets off when one's due (unless a fight
## is already on, or a cutscene: then it waits).
func check_raids(fighting: bool) -> void:
	if raids.is_empty() or Game.cutscene or Game.minute < float(raids[0][0]):
		return
	if fighting:
		return
	var r: Array = raids.pop_front()
	var target: int = r[1]
	if target != MAIN and (target >= plots.size() or plots[target] != YOU):
		target = MAIN  # that branch isn't yours anymore
	raid_due.emit(target)


## How many skeletons come: more as Bone Mart grows and your store does.
func raid_size() -> int:
	return clampi(2 + owned_by(BONE).size() / 2 + (Game.level - LEVEL) / 5, 2, 5)


## How many skeletons guard Bone Mart (MAIN) or one of its branches.
func defenders(target: int) -> int:
	if target == MAIN:
		return clampi(3 + (Game.level - LEVEL) / 5, 3, 5)
	return 2


## Bone Mart's gang robbed your register: what they take.
func robbed() -> float:
	var take := clampf(Game.money * ROB_SHARE, minf(ROB_MIN, maxf(0.0, Game.money)), ROB_MAX)
	take = floorf(maxf(0.0, minf(take, Game.money)))
	Game.money -= take
	Game.stats.robbed = float(Game.stats.get("robbed", 0.0)) + take
	if take > 0.0:
		Game.message.emit(Brand.WAR.robbed % Game.cash(take))
	else:
		Game.message.emit(Brand.WAR.robbed_nothing)
	return take


## A Bone Mart gang got beaten: `downed` skeletons knocked out.
func defended(target: int, downed: int) -> void:
	Game.stats.raids_won = int(Game.stats.get("raids_won", 0)) + 1
	Game.add_xp(WIN_XP * downed)
	if target == MAIN:
		Game.message.emit(Brand.WAR.raid_won)
	else:
		Game.message.emit(Brand.WAR.raid_won_branch % ("your %s on %s" % [Brand.WAR.your_branch, plot_name(target)]))


## Bone Mart's gang took your branch over.
func branch_lost(i: int) -> void:
	Game.stats.raids_lost = int(Game.stats.get("raids_lost", 0)) + 1
	set_plot(i, BONE)
	Game.message.emit(Brand.WAR.branch_lost % [plot_name(i), Brand.WAR.bone_branch])


## Why you can't send your gang to `target` right now ("" means you can).
func send_problem(target: int, fighting: bool) -> String:
	if not on:
		return "Not until the gang war"
	if ready_gang().is_empty():
		return "Nobody in your gang is ready" if not gang.is_empty() else "Hire a gang first"
	if not Game.is_open:
		return "Only while you're open"
	if fighting:
		return "There's a fight on"
	if target == MAIN:
		if rival_closed:
			return "It's closed for today"
	elif target < 0 or target >= plots.size() or plots[target] != BONE:
		return "%s doesn't own it" % Brand.RIVAL.name
	return ""


func send_raid(target: int, fighting: bool) -> bool:
	if send_problem(target, fighting) != "":
		return false
	var where: String = Brand.RIVAL.name if target == MAIN else "%s on %s" % [Brand.WAR.bone_branch, plot_name(target)]
	Game.message.emit(Brand.WAR.your_raid_off % where)
	raid_sent.emit(target)
	return true


## Your gang won at `target`: Bone Mart closes for the day (and you take its
## till), or its branch is yours.
func raid_won(target: int, downed: int) -> void:
	Game.stats.raids_won = int(Game.stats.get("raids_won", 0)) + 1
	Game.add_xp(WIN_XP * downed)
	if target == MAIN:
		var loot := LOOT + LOOT_PER_LEVEL * maxi(0, Game.level - LEVEL)
		Game.money += loot
		Game.stats.looted = float(Game.stats.get("looted", 0.0)) + loot
		rival_closed = true
		rival_closed_changed.emit()
		Game.message.emit(Brand.WAR.your_raid_won_main % Game.cash(loot))
	else:
		set_plot(target, YOU)
		Game.message.emit(Brand.WAR.your_raid_won_branch % [Brand.WAR.bone_branch, plot_name(target), Brand.WAR.your_branch])
	changed.emit()


func raid_lost() -> void:
	Game.stats.raids_lost = int(Game.stats.get("raids_lost", 0)) + 1
	Game.message.emit(Brand.WAR.your_raid_lost)


# ---------------------------------------------------------------- the end of the day

## What your branches made today (added to your money at closing).
func branch_income() -> float:
	return branch_take() * owned_by(YOU).size() if on else 0.0


# ---------------------------------------------------------------- saving

func to_dict() -> Dictionary:
	return {"on": on, "plots": plots.duplicate(), "gang": gang.duplicate(true), "weapons": weapons.keys(),
		"raids": raids.duplicate(true), "closed": rival_closed, "bone_day": bone_bought_day, "next_id": _next_id,
		"bought_back": bought_back}


func from_dict(d: Dictionary, level: int) -> void:
	on = bool(d.get("on", false))
	var saved: Array = d.get("plots", [])
	for i in mini(saved.size(), plots.size()):
		plots[i] = str(saved[i]) if str(saved[i]) in [YOU, BONE] else ""
	for g: Variant in d.get("gang", []):
		if g is Dictionary:
			gang.append({"id": int(g.get("id", 0)), "name": str(g.get("name", "?")), "look": int(g.get("look", 0)) % 3, "out": int(g.get("out", 0))})
			_next_id = maxi(_next_id, int(g.get("id", 0)) + 1)
	_next_id = maxi(_next_id, int(d.get("next_id", 1)))
	for id: Variant in d.get("weapons", []):
		if str(id) in ["nunchucks", "glock"]:
			weapons[str(id)] = true
	for r: Variant in d.get("raids", []):
		if r is Array and r.size() >= 2:
			raids.append([int(r[0]), int(r[1])])
	rival_closed = bool(d.get("closed", false))
	bone_bought_day = int(d.get("bone_day", 0))
	bought_back = bool(d.get("bought_back", false))
	pending = false
	check_level(level)
