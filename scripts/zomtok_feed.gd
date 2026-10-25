class_name ZomTokFeed
## What's on ZomTok (the store computer's video app, scripts/ui/zomtok_app.gd):
## an endless feed of the town's characters dancing. Video `i` on day `d` is
## always the same (it's made from a random number seeded with both), and a
## new day brings a new feed. Each video is a Dictionary:
##   handle      who posted it ("@rotting_rita")
##   looks       the dancers' textures (the first one is the poster)
##   dance       how they dance (DANCES)
##   backdrop    where it was filmed (BACKDROPS)
##   beat        which track plays (ZomTokApp.BEATS)
##   caption     what they wrote, hashtags and all
##   sound       the sound's name, under the caption
##   likes, shares, comment_count
##   comments    [{user, text, likes}], the top ones
## Who turns up depends on the store: shoppers you've seen (by store level),
## your own staff (by name), Mr. Bones, Count Vlad and, once the gang war's
## on, Big Rotto's crew. A product everyone wants today gets a mention.

const DANCES := ["bounce", "sway", "spin", "flip", "moonwalk", "headbang", "jump", "wave", "shuffle"]
const BACKDROPS := ["store", "bonemart", "street", "graveyard", "disco"]
const SOUND_NAMES := ["Graveyard Shuffle", "Brain Drop", "Bone Rattle"]

const HANDLES := {
	"zombie": ["rotting_rita", "chewy_chad", "lurch.exe", "dead_and_vibing", "zed_head", "grave_danger"],
	"crawler": ["floor_is_lava_jk", "lowkey_crawler", "knees_optional"],
	"runner": ["speedrun_zed", "zoomin_zombie", "cardio_corpse"],
	"skeleton": ["bonejangles", "rattle_me_bones", "calcium_queen", "spooky_scary", "no_body_knows"],
	"brute": ["big_brute_energy", "smash_daddy", "hulking_out"],
	"rich": ["zillionaire", "old_money_older_body", "trust_fund_tomb"],
	"witch": ["hex_and_the_city", "cauldron_cutie", "broom_broom", "witchy_wednesday"],
	"vampire": ["fangs4days", "count_cardio", "night_shift_nina", "garlic_free"],
	"mummy": ["wrap_god", "tutankhamoon", "unwrapped_daily"],
	"ghost": ["boo_tiful", "sheet_happens", "see_through_me", "casper_who"],
	"werewolf": ["full_moon_fever", "howl_u_doin", "furry_furious"],
}
const CAPTIONS := [
	"tried the new dance and lost an arm {tags}",
	"they said zombies can't dance {tags}",
	"POV: the {product} restock just hit {tags}",
	"when the blood bottle kicks in {tags}",
	"rate my moves 1-10 (be nice, I bite) {tags}",
	"my undead legs did NOT agree to this {tags}",
	"learned this in one night (I have a lot of nights) {tags}",
	"dance break at the {where} {tags}",
	"this sound is stuck in my skull {tags}",
	"no brains, just vibes {tags}",
	"doing it till I fall apart (again) {tags}",
	"duet this if you've still got both legs {tags}",
]
const TAGS := ["#fyp", "#zomtok", "#undeadtok", "#brains", "#graveyardshift", "#dancechallenge", "#zombiedance", "#zupermarket", "#nightshift", "#rotandroll"]
const COMMENTS := [
	"BRAAAINS", "this slaps harder than a werewolf", "my bones are RATTLING", "the moves are giving... decomposed",
	"first", "not me watching this 40 times", "who let them cook", "I'd buy {product} from them",
	"the way their arm almost fell off", "rent free in my skull", "teach me pls", "ok this is my new alarm sound",
	"the drop at 0:03 though", "absolutely rotten (compliment)", "my mummy would love this", "my coffin is shaking",
	"saw them at the Zupermarket yesterday, they're even better in person", "this is why I'm undead", "10/10 no notes",
	"doing this at my next funeral", "sir this is a graveyard", "LMAOOO the spin", "ate and left no brains",
	"why is this so clean", "I tried this and now I'm in pieces", "the ghost in the back is me", "obsessed",
	"we need a tutorial", "the moonwalk had me screaming", "{rival} could never",
]
## Comments that only make sense on some videos.
const KIND_COMMENTS := {
	"skeleton": ["all skin, no bones? couldn't be you", "humerus", "the bones were boning", "a skele-TON of talent"],
	"vampire": ["the fangs are giving", "who's out here in daylight", "drink some water (blood)"],
	"witch": ["she put a spell on me fr", "the broom work is insane", "cauldron cam when?"],
	"ghost": ["I can see right through these moves (in a good way)", "BOO-tiful", "the sheet slay"],
	"mummy": ["unwrap the talent", "3000 years old and still dancing", "the bandages held on, respect"],
	"werewolf": ["AWOOOO", "the shedding though", "full moon energy"],
	"brute": ["the floor felt that", "gentle giant era", "SMASH"],
	"staff": ["shouldn't you be stocking shelves", "the boss is gonna see this", "on the clock?? icon", "this is why the shelves are empty"],
	"bones": ["the {rival} commercial nobody asked for", "ratio", "{rival} prices are higher than this jump", "boo get off the app", "shop at the Zupermarket instead"],
	"vlad": ["he's going to charge interest on this", "pay him back before he dances at you", "the cape twirl!!", "don't like this or he'll want a cut"],
	"gang": ["Big Rotto's crew stays winning", "bone crushers and dance floor crushers", "where were these moves at the last raid"],
}


## Video `i` of day `day`'s feed.
static func video(day: int, i: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([day, i, "zomtok"])
	var v := {"day": day, "index": i}
	var hot := _hot_product()
	var who := _creator(rng, i)
	v.merge(who)
	v.dance = DANCES[rng.randi() % DANCES.size()]
	if not v.has("backdrop"):
		v.backdrop = BACKDROPS[rng.randi() % BACKDROPS.size()]
	v.beat = rng.randi() % SOUND_NAMES.size()
	var tags: Array = TAGS.duplicate()
	_shuffle(tags, rng)
	var tag_text := " ".join(tags.slice(0, 2 + rng.randi() % 2))
	if not v.has("caption"):
		var c: String = CAPTIONS[rng.randi() % CAPTIONS.size()]
		if hot == "" and "{product}" in c:
			c = CAPTIONS[1]
		v.caption = c
	v.caption = _fill(v.caption, hot, v.backdrop).replace("{tags}", tag_text).strip_edges()
	v.sound = "%s - %s" % [SOUND_NAMES[v.beat], "original sound" if rng.randf() < 0.4 else "ZomTok Hits"]
	var reach := 10.0 ** rng.randf_range(2.2, 5.6)  # from a couple of hundred likes to a few hundred thousand
	v.likes = int(reach)
	v.shares = int(reach * rng.randf_range(0.01, 0.06))
	var pool: Array = COMMENTS.duplicate()
	for extra: String in v.get("extra_comments", []):
		pool.append(extra)
	pool.append_array(KIND_COMMENTS.get(v.get("group", ""), []))
	pool.append_array(KIND_COMMENTS.get(v.get("group", ""), []))  # (twice: more likely)
	_shuffle(pool, rng)
	var n := 8 + rng.randi() % 7
	var comments: Array = []
	var top := maxi(3, int(reach * rng.randf_range(0.02, 0.08)))
	for k in mini(n, pool.size()):
		comments.append({"user": "@" + _any_handle(rng), "text": _fill(pool[k], hot, v.backdrop),
			"likes": maxi(0, int(top / pow(1.0 + k, 1.3) * rng.randf_range(0.6, 1.4)))})
	comments.sort_custom(func(a, b): return a.likes > b.likes)
	v.comments = comments
	v.comment_count = comments.size() + int(reach * rng.randf_range(0.005, 0.03))
	v.erase("extra_comments")
	return v


## Who posted video `i`, and who's dancing in it.
static func _creator(rng: RandomNumberGenerator, i: int) -> Dictionary:
	var pick := rng.randf()
	# Now and then: one of your staff, Mr. Bones, Count Vlad or the gang.
	if pick < 0.12 and not Game.staff.is_empty():
		var s: Dictionary = Game.staff[rng.randi() % Game.staff.size()]
		var role: String = s.role
		if Brand.STAFF.has(role):
			var looks: Array = [Brand.STAFF[role].texture]
			if rng.randf() < 0.5:
				looks.append(_shopper_look(rng, "zombie"))
			return {"handle": "@" + _slug(str(s.name)) + "_on_shift", "looks": looks, "group": "staff", "backdrop": "store",
				"caption": ["on my break (I don't get a break) {tags}", "the boss doesn't know I'm filming this {tags}", "stocking shelves but make it choreography {tags}"][rng.randi() % 3]}
	if pick < 0.2:
		var looks: Array = [Brand.RIVAL.textures.owner]
		for k in 2:
			looks.append(_shopper_look(rng, "skeleton"))
		return {"handle": "@bonemart_official", "looks": looks, "group": "bones", "backdrop": "bonemart",
			"caption": "%s: lower prices, higher kicks. Come dance at %s! {tags}" % [Brand.RIVAL.owner, Brand.RIVAL.name]}
	if pick < 0.27:
		return {"handle": "@count_vlad", "looks": [Brand.LOAN.sprite], "group": "vlad", "backdrop": ["graveyard", "disco"][rng.randi() % 2],
			"caption": "Interest rates? I prefer interest BITES. {tags}"}
	if pick < 0.34 and Game.war.on:
		var looks: Array = [Brand.WAR.textures.zombie_boss]
		for k in 2:
			looks.append(Brand.WAR.textures.zombie_gang[rng.randi() % Brand.WAR.textures.zombie_gang.size()])
		return {"handle": "@big_rotto_crew", "looks": looks, "group": "gang", "backdrop": "street",
			"caption": "%s's crew after a raid {tags}" % Brand.WAR.zombie_boss}
	var kinds := shopper_kinds()
	var kind: String = kinds[(rng.randi() + i) % kinds.size()]
	var looks: Array = [_shopper_look(rng, kind)]
	var friends := rng.randi() % 3  # dancing alone, or with one or two friends
	for k in friends:
		var other: String = kind if rng.randf() < 0.6 else kinds[rng.randi() % kinds.size()]
		looks.append(_shopper_look(rng, other))
	var handles: Array = HANDLES.get(kind, HANDLES.zombie)
	return {"handle": "@" + handles[rng.randi() % handles.size()], "looks": looks, "group": kind}


## The kinds of shopper you'd know by now (they come to the store from
## their level on).
static func shopper_kinds() -> Array:
	var out: Array = []
	for kind: String in Brand.SHOPPERS:
		if int(Brand.SHOPPERS[kind].get("level", 1)) <= maxi(1, Game.level):
			out.append(kind)
	return out


static func _shopper_look(rng: RandomNumberGenerator, kind: String) -> Texture2D:
	var looks: Array = Brand.SHOPPERS[kind].looks
	return looks[rng.randi() % looks.size()]


static func _any_handle(rng: RandomNumberGenerator) -> String:
	var kinds: Array = HANDLES.keys()
	var list: Array = HANDLES[kinds[rng.randi() % kinds.size()]]
	var h: String = list[rng.randi() % list.size()]
	return h if rng.randf() < 0.7 else "%s%d" % [h, rng.randi_range(2, 99)]


## The product everyone wants today (the market's news), or "".
static func _hot_product() -> String:
	var best := ""
	var most := 1.25
	for id: String in Game.market.demand:
		if Game.PRODUCTS.has(id) and float(Game.market.demand[id]) > most:
			most = float(Game.market.demand[id])
			best = id
	return Game.product_name(best).to_lower() if best != "" else ""


static func _fill(text: String, hot: String, backdrop: String) -> String:
	var where := {"store": "Zupermarket", "bonemart": Brand.RIVAL.name, "street": "bus stop", "graveyard": "graveyard", "disco": "crypt party"}
	return text.replace("{product}", hot if hot != "" else "blood bottle").replace("{rival}", Brand.RIVAL.name).replace("{where}", where.get(backdrop, "store"))


static func _slug(name: String) -> String:
	return name.to_lower().replace(" ", "_").replace(".", "")


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for k in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (k + 1)
		var tmp = a[k]
		a[k] = a[j]
		a[j] = tmp


## 950, 1.2K, 34.5K, 1.2M.
static func count_text(n: int) -> String:
	if n < 1000:
		return str(n)
	if n < 1000000:
		return ("%.1fK" % (n / 1000.0)).replace(".0K", "K")
	return ("%.1fM" % (n / 1000000.0)).replace(".0M", "M")
