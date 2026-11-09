class_name DayEvents
extends Node
## Makes today's event happen (0.19): at the time on the calendar
## (Game.calendar), once the store is open, it starts:
##   bus        the tour bus (TourBus) drops off a crowd of tourists
##   inspector  the health inspector (Inspector) looks round and grades the
##              store (grade): A pays and brings shoppers, C is a fine
##   outage     a power cut: the registers stop and the lights go out until
##              you fix the fuse box at the computer (fix_power), or the
##              power company does after a couple of hours
##   ghost      a ghost shoplifter (GhostThief), two from level 8
##   celeb      a celebrity comes shopping; how they rate the visit goes
##              viral (more shoppers tomorrow) or the other way
##   moon       a full moon (the effects are in Game.shopper_weight)
## The store adds it as a child (Store.events).

signal power_changed(on: bool)

const TOURISTS := [7, 11]
const SECOND_GHOST_LEVEL := 8
const SECOND_GHOST_AFTER := 90.0  # game minutes after the first
const POWER_BACK_AFTER := 120.0  # game minutes: the power company fixes it if you don't
const GRADE_A := 85  # inspection points (out of 100) for an A...
const GRADE_B := 60  # ...and a B (less is a C)
const BOOST_A := 1.15  # shoppers for the rest of the day after an A...
const BOOST_C := 0.85  # ...and a C
const CELEB_GOOD := 4.0  # the celebrity's stars for a viral post...
const CELEB_BAD := 2.5  # ...and for a bad one
const SOUNDS := {
	"bus": preload("res://assets/sounds/bus_horn.wav"),
	"power_down": preload("res://assets/sounds/power_down.wav"),
	"power_up": preload("res://assets/sounds/power_up.wav"),
	"ghost": preload("res://assets/sounds/ghost_boo.wav"),
	"camera": preload("res://assets/sounds/camera.wav"),
	"howl": preload("res://assets/sounds/howl.wav"),
}

var store: Store
var _ghost_due := -1.0  # game minute the second ghost comes (-1: none)
var _power_off_at := 0.0  # game minute the power went off


func _ready() -> void:
	store = get_parent()


func _process(_delta: float) -> void:
	if not Game.in_game() or Game.day_over or Game.cutscene:
		return
	var cal := Game.calendar
	var e := cal.event()
	if e != "" and cal.started != Game.day and Game.is_open and Game.minute >= cal.event_minute():
		start(e)
	if cal.power_out and Game.minute - _power_off_at >= POWER_BACK_AFTER:
		restore_power("The power company got the lights back on.")
	if _ghost_due >= 0.0 and Game.is_open and Game.minute >= _ghost_due:
		_ghost_due = -1.0
		send_ghost()


## Starts event `e` now.
func start(e: String) -> void:
	var cal := Game.calendar
	cal.started = Game.day
	var info: Dictionary = Brand.CALENDAR.events.get(e, {})
	if info.has("starts"):
		Game.message.emit(info.starts)
	match e:
		"bus":
			send_bus()
		"inspector":
			send_inspector()
		"outage":
			power_cut()
		"ghost":
			send_ghost()
			if Game.level >= SECOND_GHOST_LEVEL:
				_ghost_due = Game.minute + SECOND_GHOST_AFTER
		"celeb":
			send_celebrity()
		"moon":
			cal.outcome = "A full moon brought out the werewolves and vampires."
			play("howl")
	Game.event_started.emit(e)


# ---------------------------------------------------------------- the bus

func send_bus() -> TourBus:
	if store.town == null:
		for i in randi_range(TOURISTS[0], TOURISTS[1]):  # (no town: they just walk in)
			tourist_off(store.door_cell)
		return null
	var bus := TourBus.new()
	bus.setup(store, randi_range(TOURISTS[0], TOURISTS[1]))
	Game.calendar.outcome = "A tour bus brought a crowd of tourists."
	return bus


## A tourist gets off the bus at `at`.
func tourist_off(at: Vector2i) -> Customer:
	var kind: Dictionary = Brand.EVENT_SHOPPERS.tourist
	var c := store.spawn_customer(kind, [], at)
	Game.count("tourists")
	return c


# ---------------------------------------------------------------- the inspector

func send_inspector() -> Inspector:
	var who := Inspector.new()
	var from := store.exit_cell_near(store.door_cell)
	who.setup(store, from, Brand.INSPECTOR.texture)
	return who


## The store's inspection points out of 100 right now, and what lost them:
## [points, [reasons]].
func inspection() -> Array:
	var points := 100
	var why: Array[String] = []
	var blood := mini(5, store.spills.size())
	if blood > 0:
		points -= 10 * blood
		why.append("%d puddle%s of blood" % [blood, "" if blood == 1 else "s"])
	var empty := mini(5, store.shelves.filter(func(s: Shelf): return s.stock <= 0).size())
	if empty > 0:
		points -= 8 * empty
		why.append("%d empty shel%s" % [empty, "f" if empty == 1 else "ves"])
	var longest := 0
	for r: Register in store.registers:
		longest = maxi(longest, r.line.size())
	if longest >= 4:
		points -= 20 if longest >= 6 else 10
		why.append("a long line")
	var loose := 0
	for c: Vector2i in store.boxes:
		if not c in store.delivery_cells:
			loose += 1
	if loose > 0:
		points -= 3 * mini(5, loose)
		why.append("boxes on the floor")
	return [maxi(0, points), why]


## The inspector's done: the grade, and what it does.
func grade() -> String:
	var result := inspection()
	var points: int = result[0]
	var why: Array = result[1]
	var g := "A" if points >= GRADE_A else ("B" if points >= GRADE_B else "C")
	var cal := Game.calendar
	var line: String = Brand.INSPECTOR.grades[g]
	match g:
		"A":
			var pay := roundf(50.0 + 25.0 * Game.level)
			Game.money += pay
			cal.boost = BOOST_A
			Game.message.emit(line % Game.cash(pay))
			Game.count("inspections_a")
		"B":
			Game.message.emit(line)
		"C":
			var fine := roundf(30.0 + 15.0 * Game.level)
			Game.money -= fine
			cal.boost = BOOST_C
			Game.message.emit(line % Game.cash(fine))
	if not why.is_empty() and g != "A":
		Game.message.emit("The inspector noted: %s." % ", ".join(why))
	cal.outcome = "The health inspector gave the store %s %s (%d points)." % ["an" if g == "A" else "a", g, points]
	Game.stats.inspection = g
	return g


# ---------------------------------------------------------------- the power

func power_cut() -> void:
	var cal := Game.calendar
	if cal.power_out:
		return
	cal.power_out = true
	_power_off_at = Game.minute
	cal.outcome = "The power went out."
	play("power_down")
	power_changed.emit(false)


## You fixed the fuse box (at the computer).
func fix_power() -> void:
	if Game.calendar.power_out:
		Game.count("fuses_fixed")
		restore_power("You fixed the fuse box! The power's back on.")
		Game.calendar.outcome = "The power went out, and you fixed the fuse box."


func restore_power(say: String) -> void:
	var cal := Game.calendar
	if not cal.power_out:
		return
	cal.power_out = false
	Game.message.emit(say)
	play("power_up")
	power_changed.emit(true)


# ---------------------------------------------------------------- ghosts

func send_ghost() -> GhostThief:
	var ghost := GhostThief.new()
	ghost.setup(store, _town_entry(), Brand.GHOST_THIEF.texture)
	if Game.calendar.outcome == "":
		Game.calendar.outcome = "A ghost came shoplifting."
	return ghost


## An edge of town with a way to the store's door (else just outside it).
func _town_entry() -> Vector2i:
	if store.town and not store.town.spawns.is_empty():
		var spawns: Array = store.town.spawns.duplicate()
		spawns.shuffle()
		for c: Vector2i in spawns:
			if not store.find_path(c, store.door_cell).is_empty():
				return c
	return store.exit_cell_near(store.door_cell)


# ---------------------------------------------------------------- the celebrity

func send_celebrity() -> Customer:
	var kind: Dictionary = Brand.EVENT_SHOPPERS.celebrity
	var c := store.spawn_customer(kind)
	c.emote("star", 4.0)
	play("camera")
	Game.calendar.outcome = "%s came shopping." % kind.name
	return c


## The celebrity left, rating the visit `stars`: it goes up on ZomTok.
func celebrity_rated(stars: float) -> void:
	var cal := Game.calendar
	var name: String = Brand.EVENT_SHOPPERS.celebrity.name
	var tomorrow := Game.day + 1
	cal.post = {"day": tomorrow, "stars": roundi(stars)}
	if roundi(stars) >= 5:
		Game.count("viral")
	if stars >= CELEB_GOOD:
		cal.buzz[tomorrow] = Calendar.VIRAL
		Game.message.emit("%s loved your store (%d stars)! Their post is going viral: more shoppers tomorrow." % [name, roundi(stars)])
		cal.outcome = "%s gave the store %d stars and posted about it: more shoppers tomorrow." % [name, roundi(stars)]
	elif stars <= CELEB_BAD:
		cal.buzz[tomorrow] = Calendar.ROASTED
		Game.message.emit("%s roasted your store on ZomTok (%d stars). Fewer shoppers tomorrow." % [name, roundi(stars)])
		cal.outcome = "%s gave the store %d stars and roasted it on ZomTok: fewer shoppers tomorrow." % [name, roundi(stars)]
	else:
		Game.message.emit("%s gave your store %d stars. Nice, but nothing to post about." % [name, roundi(stars)])
		cal.outcome = "%s gave the store %d stars." % [name, roundi(stars)]


## Plays one of SOUNDS.
func play(sound: String) -> void:
	if not SOUNDS.has(sound):
		return
	var pl := AudioStreamPlayer.new()
	pl.stream = SOUNDS[sound]
	add_child(pl)
	pl.finished.connect(pl.queue_free)
	pl.play()


## A new day: nothing's due from yesterday.
func morning() -> void:
	_ghost_due = -1.0
	if Game.calendar.power_out:
		restore_power("The power's back on.")
