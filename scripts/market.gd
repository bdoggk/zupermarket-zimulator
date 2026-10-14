class_name Market
extends RefCounted
## Market prices go up and down over time.
##
## Every product has a "factor": 1.0 is its normal price, 1.2 is 20% above
## normal. Both what you pay for a box and what customers expect to pay
## follow the factor, so buying stock when it's cheap pays off.
##
## Factors wobble at every update (every few in-game hours) and slowly drift
## back toward normal. Each morning there's a chance of a news event that
## hits one product hard.

const UPDATE_EVERY_HOURS := 4
const MIN_FACTOR := 0.65
const MAX_FACTOR := 1.5
const WOBBLE := 0.1  # each update moves prices up to +/-10%
const DRIFT_BACK := 0.2  # how fast prices return to normal (0-1)
const EVENT_CHANCE := 0.4  # chance of a news event each morning
const SHORTAGE := 1.35
const SURPLUS := 0.7
const CRAZE_DEMAND := 3.0  # how much more often customers want a craze product

var factor := {}  # product id -> current price factor
var previous := {}  # product id -> factor before the last update
var demand := {}  # product id -> how likely customers are to want it (1 = normal)
var news := ""  # today's headline


func setup(ids: Array) -> void:
	for id in ids:
		factor[id] = 1.0
		previous[id] = 1.0
		demand[id] = 1.0


## How much a product moved in the last update (0.1 = up 10%).
func change(id: String) -> float:
	return factor[id] / previous[id] - 1.0


## Moves every price a little. On a new day it may also create a news event
## about one of `event_ids`. Returns the headline, or "" if nothing happened.
func update(new_day: bool, event_ids: Array, names: Dictionary) -> String:
	for id in factor:
		previous[id] = factor[id]
		var f: float = factor[id]
		f += (1.0 - f) * DRIFT_BACK
		f *= 1.0 + randf_range(-WOBBLE, WOBBLE)
		factor[id] = clampf(f, MIN_FACTOR, MAX_FACTOR)
	if not new_day:
		return ""
	news = ""
	for id in demand:
		demand[id] = 1.0
	if event_ids.is_empty() or randf() > EVENT_CHANCE:
		return ""
	var id: String = event_ids.pick_random()
	var product: String = names[id]
	match randi() % 3:
		0:
			factor[id] = clampf(factor[id] * SHORTAGE, MIN_FACTOR, MAX_FACTOR)
			news = "%s shortage! Prices are way up." % product
		1:
			factor[id] = clampf(factor[id] * SURPLUS, MIN_FACTOR, MAX_FACTOR)
			news = "%s surplus! Prices dropped." % product
		_:
			demand[id] = CRAZE_DEMAND
			news = "Everyone wants %s today!" % product.to_lower()
	return news
