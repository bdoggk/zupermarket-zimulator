class_name StoreRating
extends RefCounted
## The store's star rating (0.18). Every shopper leaves with a score from 1
## to 5 stars (Customer.rate_visit: did they find everything, how long did
## they wait, were the prices fair, was the floor clean?), and the rating
## is the average of the last WINDOW of them, shown to the nearest half
## star. More stars bring more shoppers (traffic_factor). Now and then a
## shopper writes a review saying what made their visit (Brand.REVIEWS),
## and the Goals app on the computer lists them, so you can see what to fix.

signal changed

const WINDOW := 40  # the rating is the average of this many of the latest shoppers
const START := 3.0  # a new store (and an old save) starts here...
const SETTLE := 10  # ...and its first shoppers' scores are averaged with this many 3s, so one happy shopper isn't 5 stars
const BEST_AFTER := 20  # the best rating (for trophies) counts once this many shoppers have rated the store
const REVIEWS_KEPT := 30
const REVIEW_CHANCE := 0.35  # how often a shopper writes a review (always for 1 or 5 stars)
const TRAFFIC_PER_STAR := 0.1  # each star above 3 brings this many more shoppers (below 3, fewer)
const HAPPY := 4.0  # a score this high is a happy shopper...
const UNHAPPY := 2.0  # ...and this low, an unhappy one

var scores: Array[float] = []  # the latest shoppers' scores, oldest first
var reviews: Array[Dictionary] = []  # newest first: {day, stars, user, kind, text}
var best := START  # the best the rating has been (shown(), for trophies)


## The rating: the average of the latest shoppers (START before anyone's
## rated it, and close to it while only a few have).
func stars() -> float:
	var total := 0.0
	for sc in scores:
		total += sc
	var n := scores.size()
	if n < SETTLE:
		total += START * (SETTLE - n)
		n = SETTLE
	return total / n


## The rating to the nearest half star (what the stars on screen show).
func shown() -> float:
	return roundf(stars() * 2.0) / 2.0


## How many more (or fewer) shoppers the rating brings: 0.8 at 1 star,
## 1.0 at 3, 1.2 at 5.
func traffic_factor() -> float:
	return 1.0 + TRAFFIC_PER_STAR * (stars() - 3.0)


## A shopper's visit, scored `score` (1 to 5); `reason` is what made it
## (a Brand.REVIEWS key); `product` what they couldn't get or found pricey.
func record(score: float, reason: String, kind: Dictionary = {}, product := "") -> void:
	score = clampf(score, 1.0, 5.0)
	scores.append(score)
	while scores.size() > WINDOW:
		scores.pop_front()
	if scores.size() >= BEST_AFTER:
		best = maxf(best, shown())
	var st: Dictionary = Game.stats
	st.ratings = int(st.get("ratings", 0)) + 1
	st.stars_sum = float(st.get("stars_sum", 0.0)) + score
	if score >= HAPPY:
		st.happy = int(st.get("happy", 0)) + 1
	elif score <= UNHAPPY:
		st.unhappy = int(st.get("unhappy", 0)) + 1
	var why: Dictionary = st.get("why", {})
	why[reason] = int(why.get(reason, 0)) + 1
	st.why = why
	var extreme := score <= 1.5 or score >= 4.75
	if extreme or randf() < REVIEW_CHANCE:
		_review(score, reason, kind, product)
	changed.emit()


func _review(score: float, reason: String, kind: Dictionary, product: String) -> void:
	var lines: Array = Brand.REVIEWS.get(reason, Brand.REVIEWS.ok)
	var text: String = lines.pick_random()
	var name := Game.product_name(product).to_lower() if product != "" and Game.PRODUCTS.has(product) else "brains"
	text = text.replace("{product}", name).replace("{rival}", Brand.RIVAL.name)
	var kind_id: String = Brand.SHOPPERS.find_key(kind) if Brand.SHOPPERS.values().has(kind) else "zombie"
	var handles: Array = ZomTokFeed.HANDLES.get(kind_id, ZomTokFeed.HANDLES.zombie)
	reviews.push_front({"day": Game.day, "stars": roundi(score), "user": "@" + str(handles.pick_random()),
		"kind": kind_id, "text": text})
	while reviews.size() > REVIEWS_KEPT:
		reviews.pop_back()


## Today's average (from Game.stats), or -1 if nobody's rated today yet.
static func today() -> float:
	var n := int(Game.stats.get("ratings", 0))
	return float(Game.stats.get("stars_sum", 0.0)) / n if n > 0 else -1.0


## What shoppers said today, the most common first: [[reason, count]...].
static func today_reasons() -> Array:
	var why: Dictionary = Game.stats.get("why", {})
	var out: Array = []
	for r: String in why:
		out.append([r, int(why[r])])
	out.sort_custom(func(a, b): return a[1] > b[1])
	return out


## "★★★½" in words for the HUD's tooltip and messages: "3.5 stars".
static func words(v: float) -> String:
	return ("%.1f" % v).replace(".0", "") + (" star" if is_equal_approx(v, 1.0) else " stars")


func to_dict() -> Dictionary:
	return {"scores": scores, "reviews": reviews, "best": best}


func from_dict(d: Dictionary) -> void:
	scores.clear()
	for sc in d.get("scores", []):
		scores.append(clampf(float(sc), 1.0, 5.0))
	while scores.size() > WINDOW:
		scores.pop_front()
	reviews.clear()
	for r in d.get("reviews", []):
		if r is Dictionary and r.has("text"):
			reviews.append({"day": int(r.get("day", 1)), "stars": clampi(int(r.get("stars", 3)), 1, 5),
				"user": str(r.get("user", "@someone")), "kind": str(r.get("kind", "zombie")), "text": str(r.text)})
	while reviews.size() > REVIEWS_KEPT:
		reviews.pop_back()
	best = maxf(float(d.get("best", START)), shown() if scores.size() >= BEST_AFTER else START)
