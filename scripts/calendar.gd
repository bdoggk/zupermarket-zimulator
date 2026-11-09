class_name Calendar
extends RefCounted
## The week (0.19): what day of the week it is (Brand.CALENDAR.days: the
## weekend's busy, Moanday's quiet), the weather, and what's happening each
## day: the health inspector, a bus tour, a power cut, a ghost shoplifter, a
## celebrity, the full moon (Brand.CALENDAR.events). The week ahead is known,
## so you can plan: the computer's Calendar app shows it, and the morning
## message says what today brings. DayEvents (in the store) makes the day's
## event happen; Game.calendar is the one in play.
##
## Each day's weather is picked once, when it first comes onto the calendar
## (seeded, so a game keeps the same week), and saved. Its event is settled
## FIRM days ahead: before that it's picked again each morning, as the store
## grows into new kinds of events, and the Calendar app shows a "?".

signal changed

const AHEAD := 7  # days on the calendar, today included...
const FIRM := 3  # ...of which this many are settled (further off, the weather's known, the event isn't yet)
const EVENTS_FROM := 3  # no events on the first two days (there's enough to learn)
const EVENT_CHANCE := 0.6  # a day that isn't a full moon has an event this often
const MOON_EVERY := 7  # a full moon every seventh day (a Sundead)
const EVENT_STEPS := [40, 64]  # events start between 10 AM and 4 PM (in 15-minute steps)

## The weather: how many shoppers come, and what else it does.
const WEATHER := {
	"clear": {"weight": 55.0, "traffic": 1.0},
	"rain": {"weight": 20.0, "traffic": 0.85, "leaky": 1.6},  # wet, bloody footprints: more mopping
	"fog": {"weight": 15.0, "traffic": 0.95, "ghosts": 3.0, "spies": 2.0},  # ghosts love it, spies sneak in
	"heat": {"weight": 10.0, "traffic": 1.05, "cold": 1.8},  # everyone wants something from the cooler
}
## The events: from which store level, and how often (by weight).
const EVENTS := {
	"bus": {"level": 3, "weight": 3.0},
	"inspector": {"level": 3, "weight": 3.0},
	"outage": {"level": 2, "weight": 2.0},
	"ghost": {"level": 4, "weight": 2.5},
	"celeb": {"level": 5, "weight": 2.0},
}
const MOON_WEREWOLF_LEVEL := 5  # on a full moon, werewolves come from this level (not 11)
const MOON_NIGHT_PULL := 2.5  # ...and night owls are this much more common after dusk
const VIRAL := 1.3  # the day after a celebrity loved your store: this many more shoppers
const ROASTED := 0.85  # ...or hated it

var seed := 0  # picked for each new game
var days := {}  # day -> {weather, event, minute}
var started := 0  # the day whose event has started (so it doesn't start twice)
var power_out := false  # a power cut is on (DayEvents, the fuse box at the computer)
var boost := 1.0  # today's shoppers from the inspector's grade (1 = no change)
var buzz := {}  # day -> shoppers that day from a celebrity's post
var outcome := ""  # how today's event went, for the day's summary
var post := {}  # a celebrity's ZomTok post about the store: {day (it's on that day's feed), stars}


func _init() -> void:
	seed = randi()


## Whether day `d`'s event is settled (or still might change).
static func is_firm(d: int) -> bool:
	return d < Game.day + FIRM or is_moon_day(d)


## A day's {weather, event, minute} (picked the first time it's asked for).
func day_info(d: int) -> Dictionary:
	if not days.has(d):
		days[d] = _pick(d)
	return days[d]


func weather(d := -1) -> String:
	return str(day_info(Game.day if d < 0 else d).weather)


func event(d := -1) -> String:
	return str(day_info(Game.day if d < 0 else d).event)


## When today's (or day `d`'s) event is due, in minutes after midnight.
func event_minute(d := -1) -> int:
	return int(day_info(Game.day if d < 0 else d).minute)


## The weekday: "Wednesdead".
static func weekday(d: int) -> String:
	var names: Array = Brand.CALENDAR.days
	return names[posmod(d - 1, names.size())]


## How busy a day of the week is (1 = normal).
static func weekday_traffic(d: int) -> float:
	var t: Array = Brand.CALENDAR.traffic
	return float(t[posmod(d - 1, t.size())])


static func is_moon_day(d: int) -> bool:
	return d > 0 and d % MOON_EVERY == 0


## How many shoppers today brings: the day of the week, the weather, a
## celebrity's post, the inspector's grade.
func traffic_factor() -> float:
	return weekday_traffic(Game.day) * float(WEATHER[weather()].traffic) * float(buzz.get(Game.day, 1.0)) * boost


## Something today's weather does ("leaky", "ghosts", "spies", "cold"), or 1.
func weather_effect(key: String) -> float:
	return float(WEATHER[weather()].get(key, 1.0))


## Tonight's a full moon and it's dark: werewolves and vampires come out.
func moon_out() -> bool:
	return event() == "moon" and Game.minute >= Game.NIGHT_MINUTE


## "Wednesdead, day 10".
static func day_name(d: int) -> String:
	return "%s, day %d" % [weekday(d), d]


## What today brings, for the morning message: the weather (unless it's
## clear) and the event.
func morning_text() -> String:
	var parts: Array[String] = []
	var w := weather()
	if w != "clear":
		parts.append(str(Brand.CALENDAR.weather[w].says))
	var e := event()
	if e != "":
		parts.append(event_says(Game.day))
	return " ".join(parts)


## What day `d`'s event says ("The health inspector visits around 2:15 PM...").
func event_says(d: int) -> String:
	var e := event(d)
	if e == "":
		return ""
	var says: String = Brand.CALENDAR.events[e].says
	return says % Game.clock_text_at(event_minute(d)) if says.contains("%s") else says


## A new morning: the week ahead goes on the calendar, yesterday's goes.
func morning() -> void:
	started = 0
	power_out = false
	boost = 1.0
	outcome = ""
	fill_week(true)


## Makes sure the week ahead is on the calendar, and forgets past days;
## each morning (`repick`) the days that aren't settled yet are picked again.
func fill_week(repick := false) -> void:
	for d in range(Game.day, Game.day + AHEAD):
		var info := day_info(d)
		if repick and d >= Game.day + FIRM:  # (not settled yet: the store may have grown into more events)
			var again := _pick(d)
			info.event = again.event
			info.minute = again.minute
	for d: int in days.keys():
		if d < Game.day:
			days.erase(d)
	for d: int in buzz.keys():
		if d < Game.day:
			buzz.erase(d)
	changed.emit()


func _pick(d: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, d, "calendar"])
	var names: Array = WEATHER.keys()
	var weights := PackedFloat32Array(names.map(func(k): return float(WEATHER[k].weight)))
	var info := {"weather": "clear" if d <= 1 else str(names[rng.rand_weighted(weights)]), "event": "", "minute": 0}
	if is_moon_day(d):
		info.event = "moon"
		info.minute = Game.NIGHT_MINUTE
	elif d >= EVENTS_FROM and rng.randf() < EVENT_CHANCE:
		var pool: Array[String] = []
		var odds: Array[float] = []
		var yesterday := str(days.get(d - 1, {}).get("event", ""))
		for e: String in EVENTS:
			if Game.level >= int(EVENTS[e].level) and e != yesterday:
				pool.append(e)
				odds.append(float(EVENTS[e].weight))
		if not pool.is_empty():
			info.event = pool[rng.rand_weighted(PackedFloat32Array(odds))]
			info.minute = rng.randi_range(EVENT_STEPS[0], EVENT_STEPS[1]) * 15
	return info


func to_dict() -> Dictionary:
	var out := {}
	for d: int in days:
		out[str(d)] = days[d]
	var bz := {}
	for d: int in buzz:
		bz[str(d)] = buzz[d]
	return {"seed": seed, "days": out, "started": started, "power_out": power_out, "boost": boost, "buzz": bz, "outcome": outcome, "post": post}


func from_dict(dict: Dictionary) -> void:
	seed = int(dict.get("seed", seed))
	days.clear()
	var dd: Variant = dict.get("days", {})
	if dd is Dictionary:
		for k: String in dd:
			var v: Variant = dd[k]
			if v is Dictionary and WEATHER.has(str(v.get("weather", ""))):
				var e := str(v.get("event", ""))
				days[int(k)] = {"weather": str(v.weather), "event": e if (EVENTS.has(e) or e in ["moon", "showdown"]) else "", "minute": int(v.get("minute", 0))}
	started = int(dict.get("started", 0))
	power_out = bool(dict.get("power_out", false))
	boost = clampf(float(dict.get("boost", 1.0)), 0.5, 2.0)
	buzz.clear()
	var bz: Variant = dict.get("buzz", {})
	if bz is Dictionary:
		for k: String in bz:
			buzz[int(k)] = clampf(float(bz[k]), 0.5, 2.0)
	outcome = str(dict.get("outcome", ""))
	var p: Variant = dict.get("post", {})
	post = {"day": int(p.get("day", 0)), "stars": clampi(int(p.get("stars", 3)), 1, 5)} if p is Dictionary and p.has("day") else {}
