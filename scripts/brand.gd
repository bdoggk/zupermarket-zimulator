class_name Brand
## Everything that makes this game *this* game: its name, the starting
## store layout, what it sells, furniture and paint names, staff, colors and
## the things characters say.
##
## Supermarket Sim and Zupermarket Zimulator share every other script. Only
## this file (plus the art in assets/sprites, drawn by tools/make_sprites.py)
## is different between the two projects, so a new feature can be copied
## from one game to the other by copying the scripts folder and keeping
## this file.

const ID := "zombie"
const TITLE := "Zupermarket Zimulator"
const TAGLINE := "Fresh organs daily."

## Shoppers leave messes (blood) that have to be mopped up. Needs a mop
## bucket (M) in LAYOUT.
const SPILLS := true

## Map legend (see store.gd for the details)
##   #  wall              .  floor            S  shelf
##   F  fridge            L  plant            R  register
##   1-4  checkout line (1 = front of the line)
##   C  computer          D  delivery zone    E  door
##   P  player start      O  OPEN / CLOSED sign
##   M  mop bucket (only used when SPILLS is on)
const LAYOUT := [
	"################",
	"#DDD.......M.C.#",
	"#DDD...........#",
	"#..............#",
	"#...SSS........#",
	"#..............#",
	"#..............#",
	"#...SSS........#",
	"#..............#",
	"#......R1234...#",
	"#L....P...O...L#",
	"#########E######",
]

## The town around the store. Walk out the front door to explore it. The
## store sits in the top corner, where LAYOUT goes (@). Legend:
##   ,  dirt              ;  dead grass        :  dirt path
##   _  sidewalk          =  road              -  road with a center line
##   1-3  lots next door you can buy to make the store bigger (in order)
##   T  dead tree         C c  wrecked car (two tiles, C is the back end)
##   l  street lamp       x  rubble            w  ruined wall
##   B  burning barrel    h  fire hydrant      g  gravestone
##   v  dead bush
## The rival store (see RIVAL):
##   #  its walls         b  its floor         e  its door
##   s  shelf             r  counter           m  where its owner stands
##   p  price board       k  skull pile        S  its sign out front
## The two little shops across the road (see SHOPS), each with its own
## letters for its walls, floor, door, shelves, counter and keeper:
##   D f d j  the vampire's curio shop: walls, floor, door, shelf
##   V u      its counter, and where the vampire stands behind it
##   H o n z  the witch's brewery: walls, floor, door, shelf
##   W y      its counter, and where the witch stands behind it
##   Q  a coffin          K  the cauldron
const TOWN := [
	"@@@@@@@@@@@@@@@@111122223333,,##############;;;;",
	"@@@@@@@@@@@@@@@@111122223333,,#kbbbbbbbbbbk#;;;;",
	"@@@@@@@@@@@@@@@@111122223333,,#bbbbbbbbbbbb#;T;;",
	"@@@@@@@@@@@@@@@@111122223333x,#bbsssbbsssbb#;;;;",
	"@@@@@@@@@@@@@@@@111122223333,,#bbbbbbbbbbbb#;;;;",
	"@@@@@@@@@@@@@@@@111122223333,,#bbbbbbbbbbbb#x;;;",
	"@@@@@@@@@@@@@@@@111122223333,,#bbsssbbsssbb#;;;;",
	"@@@@@@@@@@@@@@@@111122223333,B#bbbbbbbbbbbb#;;;;",
	"@@@@@@@@@@@@@@@@111122223333,,#bbbbbbbbbbbb#;;v;",
	"@@@@@@@@@@@@@@@@111122223333,,#bbbmrbbbbbbk#;;;;",
	"@@@@@@@@@@@@@@@@111122223333,,#bbbbbbbpbbbb#;;;;",
	"@@@@@@@@@@@@@@@@111122223333,,######e#######;;;;",
	"________________________________________S_______",
	"___l_________l_________l_______l_____________l__",
	"================================================",
	"======Cc=================================Cc=====",
	"--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=",
	"=========================Cc=====================",
	"================================================",
	"________l_________l_________l_________l_________",
	"______________h__________________h______________",
	",,,,,,,,,,,,:,,,,,,,x,;;;;T,,,,,,,,,,,,,:,,,,B,,",
	",,T,,DDDDDDD:HHHHHHH,,;;;;;,www,,wwww,,,:,,;;;;;",
	",,,,,DjQjfjD:HzKyzzH,,g;g;;,w,,,,,,xw,,,:,,;;;;;",
	";v;,;DuVfffd:HooWozH,,;;;;;,w,B,,,,,,,,,:,,;T;;;",
	";;;;;DfffjjD:HzooooH,g;g;g;,w,,,,x,,w,v,:,,;;;;;",
	";B;,;DDDDDDD:HHHnHHH,,;;;;;,w,,,,,,,w,,,:,,;;;;;",
	";;;w;;,,,,,,:,,,,,,,,,g,g,,,wwwwww,ww,,,:,,;;;;;",
	";;;www,,x,,,:,,,,,v,,,,,,,,,,,,,,,,,,,,,:,v;;;;;",
	";;v;;;,,,,,,:,,,v,,,,,,,,,T,,,;;;;;;;;;,:,,;;;;;",
	";;;;;;,,T,,,:,,,,,,,,T,,,,,,,,;;;;;v;;;,:,,;;;T;",
	";;;;;;,,,,,,:,,,,,,,,,,,,,,,,,;;;;;;;;;,:,,;;;;;",
]

## Where shoppers walk into town from (and leave by): the ends of the road
## and the paths at the bottom of the map.
const TOWN_SPAWNS := [Vector2i(0, 15), Vector2i(0, 17), Vector2i(47, 15), Vector2i(47, 17), Vector2i(12, 31), Vector2i(40, 31)]

## The lots next door (1, 2, 3 in TOWN), bought in Build mode. Each one
## makes the store 4 tiles wider.
const EXPANSIONS := [
	{"cost": 600.0, "level": 2},
	{"cost": 1200.0, "level": 3},
	{"cost": 2000.0, "level": 4},
]

## The competition down the street. Shoppers pick between the two stores:
## `share` of them go there when your prices match the market. Undercut
## its prices (walk over and check them) to win them back, or buy it out.
const RIVAL := {
	"name": "Bone Mart",
	"owner": "Mr. Bones",
	"slogan": "Bare bones prices!",
	"share": 0.25,
	"buyout": 3000.0,
	"buyout_level": 5,
	"price_low": 0.82,  # its prices are this much of the market price...
	"price_high": 1.08,  # ...up to this, changing every day
	"deal": 0.6,  # its deal of the day
	"hello": "Welcome to Bone Mart! Bare bones prices!",
	"deal_news": "Bone Mart has a deal on %s today.",
	"bought": "You bought out Bone Mart! Every zombie in town shops with you now.",
	# Its spies: from this day on, a skeleton in a trench coat sneaks into
	# your store now and then while you're open and looks at your shelves.
	# If it gets away, Bone Mart prices what it saw `spy_undercut` of yours
	# for the rest of the day (never under `spy_floor` of the market price).
	# Walk up to it and use it to throw it out.
	"spy_from_day": 2,
	"spies_per_day": [1, 2],  # visits a day: before store level 3, and from level 3
	"spy_undercut": 0.92,
	"spy_floor": 0.5,
	"spy_caught_xp": 10.0,
	"spy_in": "A spy from Bone Mart just snuck in! Catch it before it gets away with your prices.",
	"spy_notes": ["*scribble scribble*", "Hmm... noted.", "Interesting prices...", "*writes it down*"],
	"spy_caught": "You threw Bone Mart's spy out! It didn't get away with a thing.",
	"spy_caught_by": "%s threw Bone Mart's spy out! It didn't get away with a thing.",
	"spy_cheaper": "Bone Mart's spy got away! Bone Mart cut its prices to beat yours: %s.",
	"spy_nothing": "Bone Mart's spy got away, but Bone Mart already beats your prices on what it saw.",
	"textures": {
		"owner": preload("res://assets/sprites/skeleton_owner.png"),
		"stocker": preload("res://assets/sprites/skeleton_stocker.png"),
		"sign": preload("res://assets/sprites/rival_sign.png"),
		"sign_sold": preload("res://assets/sprites/rival_sign_sold.png"),
		"spy": preload("res://assets/sprites/skeleton_spy.png"),
	},
}

## The two little shops across the road. Walk in and use the counter to buy
## what they sell (BREWS): each one does something for a little while.
##   map / keeper_map  the counter and where the keeper stands, in TOWN
##   wall / floor / door / shelf  the shop's other letters in TOWN
##   look  its sprites: wall_<look>_tall/_low, ground_<look>_a/_b/_mat,
##         shop_shelf_<look>, shop_counter_<look>, shop_sign_<look>
##   tall_left  its left wall is tall like the back one (the brewery's is
##         low, so it doesn't hide the path next to it)
## The counter faces away from its keeper.
const SHOPS := {
	"curios": {
		"name": "Fangsworth's Curios", "keeper": "Count Fangsworth", "map": "V", "keeper_map": "u",
		"wall": "D", "floor": "f", "door": "d", "shelf": "j", "look": "curios", "tall_left": true,
		"hello": "Garlic? Crucifixes? Don't ask why a vampire sells them.",
		"blurb": "Charms against all sorts of trouble. The Count doesn't touch the stock.",
		"shelf_text": "Skulls, candles, crucifixes, garlic and stakes. The Count sells them at the counter.",
		"keeper_look": preload("res://assets/sprites/keeper_vampire.png"),
		"light": Color(1.0, 0.72, 0.4),
	},
	"brewery": {
		"name": "The Bubbling Cauldron", "keeper": "Old Hagatha", "map": "W", "keeper_map": "y",
		"wall": "H", "floor": "o", "door": "n", "shelf": "z", "look": "brewery", "tall_left": false,
		"hello": "Potions and wine, dearie! Fresh from the cauldron.",
		"blurb": "Brewed this morning. Drink it right here; it works straight away.",
		"shelf_text": "Bottles of every color. Something in one of them is blinking. Buy at the counter.",
		"keeper_look": preload("res://assets/sprites/keeper_witch.png"),
		"light": Color(0.6, 1.0, 0.55),
	},
}

## What the shops sell. It works straight away, for `seconds` (real
## seconds); buying another adds more time (see Game.buy_brew). An entry
## with no `shop` isn't for sale: it's something else that wears off
## (`open_only`: it only counts down while the store is open).
const BREWS := {
	"swift": {
		"name": "Swift Potion", "shop": "brewery", "cost": 20.0, "seconds": 60.0,
		"desc": "Run 50% faster for a minute.",
		"icon": preload("res://assets/sprites/brew_swift.png"),
	},
	"quickhand": {
		"name": "Quickhand Potion", "shop": "brewery", "cost": 35.0, "seconds": 60.0,
		"desc": "Scan, stock and mop twice as fast for a minute.",
		"icon": preload("res://assets/sprites/brew_quickhand.png"),
	},
	"charm": {
		"name": "Charm Potion", "shop": "brewery", "cost": 50.0, "seconds": 90.0,
		"desc": "Half again as many shoppers come in, for 90 seconds.",
		"icon": preload("res://assets/sprites/brew_charm.png"),
	},
	"wine": {
		"name": "Grave Wine", "shop": "brewery", "cost": 15.0, "seconds": 120.0,
		"desc": "Everyone mellows out: shoppers wait in line twice as long, for 2 minutes.",
		"icon": preload("res://assets/sprites/brew_wine.png"),
	},
	"garlic": {
		"name": "Garlic", "shop": "curios", "cost": 10.0, "seconds": 90.0,
		"desc": "Hang it by the door: nobody drips blood for 90 seconds.",
		"icon": preload("res://assets/sprites/brew_garlic.png"),
	},
	"crucifix": {
		"name": "Crucifix", "shop": "curios", "cost": 30.0, "seconds": 120.0,
		"desc": "Blood on the floor doesn't scare shoppers off or cost you XP, for 2 minutes.",
		"icon": preload("res://assets/sprites/brew_crucifix.png"),
	},
	"stake": {
		"name": "Wooden Stake", "shop": "curios", "cost": 40.0, "seconds": 120.0,
		"desc": "Hammer it into Bone Mart's door: nobody shops there for 2 minutes.",
		"icon": preload("res://assets/sprites/brew_stake.png"),
	},
	"rumor": {
		"name": "Rumor about Bone Mart", "shop": "", "cost": 0.0, "seconds": 60.0, "open_only": true,
		"done": "The rumor about Bone Mart died down.",
		"desc": "Your spy is spreading a rumor about Bone Mart: fewer shoppers go there for a while.",
		"icon": preload("res://assets/sprites/brew_rumor.png"),
	},
}

## Kinds of shoppers.
##   weight     how common they are       level  store level they start showing up
##   speed      walking speed (1 = normal)       patience  how long they'll wait in line
##   items      how many different products they want ([min, max])
##   qty        how many of each ([min, max])
##   tolerance  how far over the market price they'll still pay (1 = not at all)
##   leaky      chance they drip blood   rival  extra chance they shop at the rival
##   night      (optional) this many times as common after 5 PM, and rarer by day
##   likes      (optional) their favorite products: while those are on your
##              shelves, they come much more often, want them most, and are
##              less tempted by the rival (Game.shopper_weight, Game.favorites_on_shelves)
##   plural     (optional) for "New shoppers: witches"
const SHOPPERS := {
	"zombie": {
		"name": "Zombie", "weight": 10.0, "level": 1, "speed": 1.0, "patience": 1.0,
		"items": [1, 4], "qty": [1, 2], "tolerance": 1.0, "leaky": 0.35, "rival": 0.0,
		"looks": [
			preload("res://assets/sprites/customer_0.png"), preload("res://assets/sprites/customer_1.png"),
			preload("res://assets/sprites/customer_2.png"), preload("res://assets/sprites/customer_3.png"),
			preload("res://assets/sprites/customer_4.png"), preload("res://assets/sprites/customer_5.png"),
		],
	},
	"crawler": {
		"name": "Crawler", "weight": 2.0, "level": 1, "speed": 0.5, "patience": 1.6,
		"items": [1, 2], "qty": [1, 1], "tolerance": 1.0, "leaky": 0.6, "rival": 0.0,
		"looks": [preload("res://assets/sprites/shopper_crawler.png")],
	},
	"runner": {
		"name": "Runner", "weight": 2.5, "level": 2, "speed": 1.8, "patience": 0.55,
		"items": [1, 3], "qty": [1, 2], "tolerance": 1.05, "leaky": 0.2, "rival": 0.0,
		"looks": [preload("res://assets/sprites/shopper_runner.png")],
	},
	"skeleton": {
		"name": "Skeleton", "weight": 3.0, "level": 1, "speed": 1.15, "patience": 1.0,
		"items": [1, 3], "qty": [1, 2], "tolerance": 0.9, "leaky": 0.0, "rival": 0.15, "likes": ["bonemeal", "calcium"],
		"looks": [
			preload("res://assets/sprites/shopper_skeleton_0.png"), preload("res://assets/sprites/shopper_skeleton_1.png"),
			preload("res://assets/sprites/shopper_skeleton_2.png"), preload("res://assets/sprites/shopper_skeleton_3.png"),
		],
	},
	"brute": {
		"name": "Brute", "weight": 1.5, "level": 3, "speed": 0.8, "patience": 1.2,
		"items": [4, 6], "qty": [1, 3], "tolerance": 1.0, "leaky": 0.5, "rival": 0.0,
		"looks": [preload("res://assets/sprites/shopper_brute.png")],
		# A recorded growl: when a brute shambles in, now and then while
		# shopping, and when one storms out.
		"sound": preload("res://assets/sounds/brute_growl.ogg"),
	},
	"rich": {
		"name": "Rich Zombie", "weight": 1.2, "level": 3, "speed": 0.9, "patience": 0.8,
		"items": [2, 4], "qty": [1, 2], "tolerance": 1.5, "leaky": 0.0, "rival": -0.1, "likes": ["brains", "goldbrains"],
		"looks": [preload("res://assets/sprites/shopper_rich.png")],
	},
	"witch": {
		"name": "Witch", "plural": "witches", "weight": 2.0, "level": 2, "speed": 1.1, "patience": 0.9,
		"items": [1, 3], "qty": [1, 3], "tolerance": 0.95, "leaky": 0.0, "rival": 0.05, "likes": ["newt", "mandrake"],
		"looks": [preload("res://assets/sprites/shopper_witch_0.png"), preload("res://assets/sprites/shopper_witch_1.png")],
	},
	"vampire": {
		"name": "Vampire", "weight": 1.5, "level": 3, "speed": 1.25, "patience": 1.5,
		"items": [2, 4], "qty": [1, 2], "tolerance": 1.3, "leaky": 0.0, "rival": -0.05, "night": 3.0, "likes": ["batwings", "bloodbag"],
		"looks": [preload("res://assets/sprites/shopper_vampire_0.png"), preload("res://assets/sprites/shopper_vampire_1.png")],
	},
	# Store levels 7 and up:
	"mummy": {
		"name": "Mummy", "plural": "mummies", "weight": 1.5, "level": 7, "speed": 0.7, "patience": 1.5,
		"items": [2, 4], "qty": [1, 2], "tolerance": 1.15, "leaky": 0.0, "rival": 0.0, "likes": ["scarabs", "canopic"],
		"looks": [preload("res://assets/sprites/shopper_mummy_0.png"), preload("res://assets/sprites/shopper_mummy_1.png")],
	},
	"ghost": {
		"name": "Ghost", "weight": 1.8, "level": 9, "speed": 1.4, "patience": 0.7,
		"items": [1, 3], "qty": [1, 2], "tolerance": 1.05, "leaky": 0.0, "rival": 0.05, "night": 2.5, "likes": ["ecto", "cobweb"],
		"looks": [preload("res://assets/sprites/shopper_ghost_0.png"), preload("res://assets/sprites/shopper_ghost_1.png")],
	},
	"werewolf": {
		"name": "Werewolf", "plural": "werewolves", "weight": 1.4, "level": 11, "speed": 1.3, "patience": 0.9,
		"items": [3, 6], "qty": [1, 3], "tolerance": 1.1, "leaky": 0.45, "rival": 0.0, "night": 3.0, "likes": ["moonsteak", "howljerky"],
		"looks": [preload("res://assets/sprites/shopper_werewolf_0.png"), preload("res://assets/sprites/shopper_werewolf_1.png")],
	},
}

## Boxes waiting in the delivery zone when a new game starts.
const STARTING_BOXES := ["guts", "blood", "fingers", "guts"]

## Everything the store can sell.
##   box_size    items per delivery box
##   unit_cost   what you pay per item when the market is normal
##   base_price  what customers expect to pay when the market is normal
##   level       store level needed before you can buy the license
##   license     one-time cost to start selling it (0 = you start with it)
##   cold        goes in a meat cooler instead of a shelf
## To add a product: add an entry here plus an 8x10 icon in assets/sprites.
const PRODUCTS := {
	"guts": {
		"name": "Canned Guts", "box_size": 8, "unit_cost": 1.0, "base_price": 2.0,
		"level": 1, "license": 0.0, "cold": false,
		"icon": preload("res://assets/sprites/item_guts.png"),
	},
	"blood": {
		"name": "Blood Bottle", "box_size": 6, "unit_cost": 1.5, "base_price": 3.0,
		"level": 1, "license": 0.0, "cold": false,
		"icon": preload("res://assets/sprites/item_blood.png"),
	},
	"fingers": {
		"name": "Finger Chips", "box_size": 10, "unit_cost": 1.0, "base_price": 2.5,
		"level": 1, "license": 0.0, "cold": false,
		"icon": preload("res://assets/sprites/item_fingers.png"),
	},
	"eyeballs": {
		"name": "Eyeball Jar", "box_size": 8, "unit_cost": 1.25, "base_price": 2.75,
		"level": 1, "license": 40.0, "cold": false,
		"icon": preload("res://assets/sprites/item_eyeballs.png"),
	},
	"bonemeal": {
		"name": "Bone Meal", "box_size": 10, "unit_cost": 0.8, "base_price": 1.75,
		"level": 1, "license": 30.0, "cold": false,
		"icon": preload("res://assets/sprites/item_bonemeal.png"),
	},
	"lungs": {
		"name": "Lungs", "box_size": 6, "unit_cost": 2.0, "base_price": 4.25,
		"level": 2, "license": 75.0, "cold": false,
		"icon": preload("res://assets/sprites/item_lungs.png"),
	},
	"hearts": {
		"name": "Fresh Hearts", "box_size": 6, "unit_cost": 1.5, "base_price": 3.25,
		"level": 2, "license": 90.0, "cold": true,
		"icon": preload("res://assets/sprites/item_hearts.png"),
	},
	"newt": {
		"name": "Eye of Newt", "box_size": 8, "unit_cost": 1.25, "base_price": 3.0,
		"level": 2, "license": 60.0, "cold": false,
		"icon": preload("res://assets/sprites/item_newt.png"),
	},
	"calcium": {
		"name": "Calcium Milk", "box_size": 6, "unit_cost": 1.5, "base_price": 3.5,
		"level": 2, "license": 70.0, "cold": true,
		"icon": preload("res://assets/sprites/item_calcium.png"),
	},
	"kidneys": {
		"name": "Kidneys", "box_size": 12, "unit_cost": 0.5, "base_price": 1.25,
		"level": 3, "license": 100.0, "cold": false,
		"icon": preload("res://assets/sprites/item_kidneys.png"),
	},
	"toes": {
		"name": "Toe Jerky", "box_size": 6, "unit_cost": 2.5, "base_price": 5.5,
		"level": 3, "license": 120.0, "cold": false,
		"icon": preload("res://assets/sprites/item_toes.png"),
	},
	"batwings": {
		"name": "Bat Wing Crisps", "box_size": 8, "unit_cost": 1.75, "base_price": 4.0,
		"level": 3, "license": 100.0, "cold": false,
		"icon": preload("res://assets/sprites/item_batwings.png"),
	},
	"mandrake": {
		"name": "Mandrake Root", "box_size": 6, "unit_cost": 2.5, "base_price": 5.5,
		"level": 3, "license": 110.0, "cold": false,
		"icon": preload("res://assets/sprites/item_mandrake.png"),
	},
	"liver": {
		"name": "Liver", "box_size": 6, "unit_cost": 3.0, "base_price": 6.5,
		"level": 4, "license": 160.0, "cold": true,
		"icon": preload("res://assets/sprites/item_liver.png"),
	},
	"marrow": {
		"name": "Bone Marrow", "box_size": 6, "unit_cost": 2.5, "base_price": 5.75,
		"level": 4, "license": 175.0, "cold": false,
		"icon": preload("res://assets/sprites/item_marrow.png"),
	},
	"bloodbag": {
		"name": "Type O Blood Bag", "box_size": 6, "unit_cost": 3.5, "base_price": 8.0,
		"level": 4, "license": 150.0, "cold": true,
		"icon": preload("res://assets/sprites/item_bloodbag.png"),
	},
	"brains": {
		"name": "Fresh Brains", "box_size": 6, "unit_cost": 4.0, "base_price": 9.0,
		"level": 5, "license": 220.0, "cold": true,
		"icon": preload("res://assets/sprites/item_brains.png"),
	},
	"spine": {
		"name": "Spine Snacks", "box_size": 8, "unit_cost": 3.0, "base_price": 7.5,
		"level": 5, "license": 250.0, "cold": false,
		"icon": preload("res://assets/sprites/item_spine.png"),
	},
	# Store levels 7 and up:
	"scarabs": {
		"name": "Scarab Crunch", "box_size": 10, "unit_cost": 1.5, "base_price": 3.5,
		"level": 7, "license": 280.0, "cold": false,
		"icon": preload("res://assets/sprites/item_scarabs.png"),
	},
	"canopic": {
		"name": "Canopic Pâté", "box_size": 6, "unit_cost": 4.0, "base_price": 9.5,
		"level": 7, "license": 320.0, "cold": true,
		"icon": preload("res://assets/sprites/item_canopic.png"),
	},
	"spleen": {
		"name": "Spleen Smoothie", "box_size": 6, "unit_cost": 3.5, "base_price": 8.0,
		"level": 8, "license": 300.0, "cold": true,
		"icon": preload("res://assets/sprites/item_spleen.png"),
	},
	"nails": {
		"name": "Nail Clippings", "box_size": 12, "unit_cost": 0.6, "base_price": 1.5,
		"level": 8, "license": 200.0, "cold": false,
		"icon": preload("res://assets/sprites/item_nails.png"),
	},
	"ecto": {
		"name": "Ectoplasm Soda", "box_size": 8, "unit_cost": 2.5, "base_price": 6.0,
		"level": 9, "license": 350.0, "cold": true,
		"icon": preload("res://assets/sprites/item_ecto.png"),
	},
	"cobweb": {
		"name": "Cobweb Candy", "box_size": 10, "unit_cost": 2.0, "base_price": 5.0,
		"level": 9, "license": 330.0, "cold": false,
		"icon": preload("res://assets/sprites/item_cobweb.png"),
	},
	"tongue": {
		"name": "Tongue Tacos", "box_size": 6, "unit_cost": 4.5, "base_price": 10.5,
		"level": 10, "license": 420.0, "cold": false,
		"icon": preload("res://assets/sprites/item_tongue.png"),
	},
	"moonsteak": {
		"name": "Moon Steak", "box_size": 6, "unit_cost": 5.0, "base_price": 12.0,
		"level": 11, "license": 480.0, "cold": true,
		"icon": preload("res://assets/sprites/item_moonsteak.png"),
	},
	"howljerky": {
		"name": "Howl Jerky", "box_size": 8, "unit_cost": 4.0, "base_price": 9.5,
		"level": 11, "license": 450.0, "cold": false,
		"icon": preload("res://assets/sprites/item_howljerky.png"),
	},
	"goldbrains": {
		"name": "Golden Brains", "box_size": 4, "unit_cost": 12.0, "base_price": 28.0,
		"level": 12, "license": 900.0, "cold": true,
		"icon": preload("res://assets/sprites/item_goldbrains.png"),
	},
}

## One-time purchases at the computer.
##   level     store level needed (optional)
##   requires  another upgrade you need first (optional)
##   delivery  seconds a delivery takes once you own it (optional)
##   zone      how big the delivery zone gets, in tiles (optional)
const UPGRADES := {
	"scanner": {
		"name": "Handheld Scanner",
		"cost": 120.0,
		"desc": "Scan any shelf to order a box of what's on it, right there.",
		"icon": preload("res://assets/sprites/scanner.png"),
	},
	"delivery_bike": {
		"name": "Delivery Bike",
		"cost": 150.0, "level": 2, "delivery": 5.0,
		"desc": "A zombie on a rusty bike brings your boxes. Deliveries take 5 seconds.",
		"icon": preload("res://assets/sprites/upgrade_bike.png"),
	},
	"delivery_van": {
		"name": "Delivery Van",
		"cost": 400.0, "level": 3, "requires": "delivery_bike", "delivery": 3.0,
		"desc": "A beat-up van with no brakes. Deliveries take 3 seconds.",
		"icon": preload("res://assets/sprites/upgrade_van.png"),
	},
	"delivery_hearse": {
		"name": "Hearse Express",
		"cost": 900.0, "level": 5, "requires": "delivery_van", "delivery": 1.0,
		"desc": "A souped-up hearse. Boxes show up about a second after you order.",
		"icon": preload("res://assets/sprites/upgrade_hearse.png"),
	},
	"zone_1": {
		"name": "Bigger Delivery Zone",
		"cost": 200.0, "level": 2, "zone": Vector2i(3, 3),
		"desc": "Paint more stripes: room for 9 boxes instead of 6.",
		"icon": preload("res://assets/sprites/upgrade_zone_1.png"),
	},
	"zone_2": {
		"name": "Loading Bay",
		"cost": 450.0, "level": 3, "requires": "zone_1", "zone": Vector2i(4, 3),
		"desc": "Room for 12 boxes in the delivery zone.",
		"icon": preload("res://assets/sprites/upgrade_zone_2.png"),
	},
	"zone_3": {
		"name": "Body Dump",
		"cost": 800.0, "level": 4, "requires": "zone_2", "zone": Vector2i(4, 4),
		"desc": "A huge delivery zone: room for 16 boxes.",
		"icon": preload("res://assets/sprites/upgrade_zone_3.png"),
	},
	# Store levels 7 and up:
	"conveyor": {
		"name": "Conveyor Belts",
		"cost": 1200.0, "level": 7,
		"desc": "Every register and self-checkout rings shoppers up 25% faster (yours and your cashiers').",
		"icon": preload("res://assets/sprites/upgrade_conveyor.png"),
	},
	"zone_4": {
		"name": "Mass Grave",
		"cost": 1400.0, "level": 8, "requires": "zone_3", "zone": Vector2i(5, 4),
		"desc": "The biggest delivery zone: room for 20 boxes.",
		"icon": preload("res://assets/sprites/upgrade_zone_4.png"),
	},
	"billboard": {
		"name": "Billboard",
		"cost": 1500.0, "level": 9,
		"desc": "A billboard by the road: 15% more shoppers.",
		"icon": preload("res://assets/sprites/upgrade_billboard.png"),
	},
	"training": {
		"name": "Staff Training",
		"cost": 1800.0, "level": 10,
		"desc": "Staff earn XP twice as fast and can reach level 7 (two more levels, each one faster).",
		"icon": preload("res://assets/sprites/upgrade_training.png"),
	},
	"drains": {
		"name": "Floor Drains",
		"cost": 2200.0, "level": 12,
		"desc": "Blood that's been on the floor for 2 hours drains away by itself.",
		"icon": preload("res://assets/sprites/upgrade_drains.png"),
	},
	"golden_sign": {
		"name": "Golden Sign",
		"cost": 2500.0, "level": 13,
		"desc": "A store this fancy: shoppers pay up to 10% more before it feels pricey.",
		"icon": preload("res://assets/sprites/upgrade_golden_sign.png"),
	},
	"neon": {
		"name": "Neon Billboard",
		"cost": 3000.0, "level": 14, "requires": "billboard",
		"desc": "Light up the billboard: another 15% more shoppers.",
		"icon": preload("res://assets/sprites/upgrade_neon.png"),
	},
}

## Furniture you can buy in build mode. kind is shelf, fridge, storage,
## decor, register or selfcheckout ("light": a decoration that lights up,
## see Lantern). The ids stay the same in both games;
## only names and art change.
const FURNITURE := {
	"shelf": {"name": "Rusty Shelf", "cost": 60.0, "kind": "shelf", "texture": preload("res://assets/sprites/shelf.png")},
	"fridge": {"name": "Meat Cooler", "cost": 150.0, "kind": "fridge", "texture": preload("res://assets/sprites/fridge.png")},
	"storage": {"name": "Storage Rack", "cost": 120.0, "kind": "storage", "texture": preload("res://assets/sprites/storage.png")},
	"plant": {"name": "Gravestone", "cost": 25.0, "kind": "decor", "texture": preload("res://assets/sprites/plant.png")},
	"lantern": {"name": "Lantern", "cost": 40.0, "kind": "decor", "light": true, "texture": preload("res://assets/sprites/lantern.png")},
	"register": {"name": "Register", "cost": 250.0, "kind": "register", "texture": preload("res://assets/sprites/register.png")},
	"selfcheckout": {"name": "Self-Checkout", "cost": 400.0, "kind": "selfcheckout", "texture": preload("res://assets/sprites/selfcheckout.png")},
	# Decorations that bring in one kind of shopper ("pulls", see
	# Game.shopper_weight), from the store level in "level". "light": a
	# Color it glows (at "glow", from its foot); "steady": no flicker.
	"cauldron": {"name": "Cauldron", "cost": 60.0, "kind": "decor", "level": 2, "pulls": "witch",
		"light": Color(0.45, 1.0, 0.45), "glow": Vector2(0, -18), "texture": preload("res://assets/sprites/prop_cauldron.png")},
	"coffin": {"name": "Coffin", "cost": 90.0, "kind": "decor", "level": 6, "pulls": "vampire",
		"texture": preload("res://assets/sprites/prop_coffin.png")},
	"bones": {"name": "Bone Pile", "cost": 80.0, "kind": "decor", "level": 8, "pulls": "skeleton",
		"texture": preload("res://assets/sprites/rival_skulls.png")},
	"spiritlamp": {"name": "Spirit Lamp", "cost": 110.0, "kind": "decor", "level": 9, "pulls": "ghost",
		"light": Color(0.55, 0.8, 1.0), "glow": Vector2(0, -26), "texture": preload("res://assets/sprites/decor_spirit_lamp.png")},
	"sarcophagus": {"name": "Sarcophagus", "cost": 140.0, "kind": "decor", "level": 10, "pulls": "mummy",
		"texture": preload("res://assets/sprites/decor_sarcophagus.png")},
	"moonlamp": {"name": "Moon Lamp", "cost": 160.0, "kind": "decor", "level": 11, "pulls": "werewolf",
		"light": Color(1.0, 0.95, 0.75), "glow": Vector2(0, -44), "steady": true, "texture": preload("res://assets/sprites/decor_moon_lamp.png")},
}

## Paint jobs in build mode. Each id matches sprites in assets/sprites:
## floor_<id>_a/_b/_stain.png and wall_<id>_tall/_low/_swatch.png.
const FLOOR_STYLES := [
	{"id": "grimy", "name": "Grimy Tile"},
	{"id": "morgue", "name": "Morgue Tile"},
	{"id": "rotten", "name": "Rotten Wood"},
	{"id": "slime", "name": "Slime Lino"},
	{"id": "ash", "name": "Ash"},
]
const WALL_COLORS := [
	{"id": "moss", "name": "Moss"},
	{"id": "bone", "name": "Bone"},
	{"id": "brick", "name": "Old Brick"},
	{"id": "bruise", "name": "Bruise"},
	{"id": "concrete", "name": "Concrete"},
]

## Staff you can hire at the computer.
##   hire   one-time cost to hire someone
##   wage   paid at the end of every day
##   max    how many you can have
const STAFF := {
	"stocker": {
		"name": "Stocker", "hire": 50.0, "wage": 25.0, "max": 3,
		"desc": "Shambles to the stockroom, grabs boxes and stocks the shelves.",
		"texture": preload("res://assets/sprites/staff_stocker.png"),
	},
	"cashier": {
		"name": "Cashier", "hire": 50.0, "wage": 30.0, "max": 4,
		"desc": "Runs a register and rings up the zombies. One per register.",
		"texture": preload("res://assets/sprites/staff_cashier.png"),
	},
	"janitor": {
		"name": "Janitor", "hire": 50.0, "wage": 20.0, "max": 2,
		"desc": "Brings their own mop and cleans up the blood so you don't have to.",
		"texture": preload("res://assets/sprites/staff_janitor.png"),
	},
	"manager": {
		"name": "General Manager", "hire": 100.0, "wage": 45.0, "max": 1,
		"desc": "Orders more boxes before doing anything else, as soon as a shelf has room (or when you say, below). Keeps the other staff working (15% faster) and gets anyone who's stuck moving again.",
		"texture": preload("res://assets/sprites/staff_manager.png"),
	},
	"spy": {
		"name": "Spy", "hire": 80.0, "wage": 35.0, "max": 1,
		"desc": "Sneaks over to Bone Mart and comes back with its prices, its deal of the day and when its next spy is coming, and spreads rumors that keep shoppers away from it. Throws out Bone Mart's spies too.",
		"texture": preload("res://assets/sprites/staff_spy.png"),
	},
}
const STAFF_NAMES := [
	"Zed", "Ghoulia", "Rotney", "Brainard", "Moaning Mary", "Stiff Steve",
	"Bones", "Grisly Gus", "Mortimer", "Lurch", "Dee Composed", "Carl Cadaver",
	"Pale Paula", "Limpy Lou", "Morgana", "Half Hank",
]

## The loan shark, in the computer's Loans app. You can borrow more as
## your store levels up; the more you borrow, the higher the interest (see
## Game.loan_rate). It's paid back every morning for 7 days. Still owe him
## on the night of the last day, and he comes for your head: the game
## starts over from day 1 (scripts/ui/loan_cutscene.gd).
const LOAN := {
	"lender": "Count Vlad",
	"business": "Count Vlad's Blood Money",
	"pitch": "Short of cash? I lend to anyone. And I always collect.",
	"sprite": preload("res://assets/sprites/count_vlad.png"),
	"taken": "Count Vlad lends you $%s. You owe him $%s: $%s every morning for %d days. Miss the night of day %d and he comes for your head.",
	"paid_morning": "Count Vlad took his loan payment: $%s. You still owe $%s.",
	"short_morning": "You couldn't make Count Vlad's payment! He took $%s of $%s. Pay the rest in the Loans app before the night of day %d, or he comes for your head.",
	"last_day": "Tonight Count Vlad comes to collect the $%s you still owe. Have it by closing time, or he takes your head!",
	"paid_off": "You've paid Count Vlad back in full. He'll lend to you again whenever you like.",
	"paid_at_night": "Count Vlad came by at closing and collected the last $%s. You're square.",
	"start_over": "Count Vlad took your head as payment. Starting over from day 1...",
	# The cutscene on the last night (%s: the day, what you borrowed, what
	# you owed with interest, what's still owed):
	"arrive": "Good evening. It is the night of day %d. We had an agreement.",
	"owed": "You borrowed $%s from me. With interest, $%s.",
	"short": "And yet you still owe me $%s.",
	"excuse": "Uhh... braaains?",
	"threat": "I always collect. One way... or another.",
	"gloat": "This head will do nicely. Pleasure doing business.",
	"game_over": "Count Vlad took your head as payment.",
	"gone": "Your store, your money, your staff: all gone.",
}

## What people are called and what they say.
const SAY := {
	"shopper": "zombie",
	"shoppers": "zombies",
	"no_product": "No %s?! Grrr",
	"not_sold": "You don't sell %s?!",
	# Townsfolk (skeletons, witches, vampires) about their favorite products:
	"town_wants": ["Sell %s and I'll shop at your place!", "Got any %s? Bone Mart doesn't!", "I'd come in for %s, you know."],
	"town_later": ["Sell %s when your store's bigger!", "One day you'll sell %s, right?"],
	"town_gone": ["Your %s is all gone!", "Out of %s again?!"],
	"town_loves": ["Love your %s!", "Best %s in town."],
	"too_pricey": "Grrr... pricey!",
	"sold_out": "Braaains... sold out?!",
	"walkout": "Uuurrgh!",
	"opened": "Doors open! The horde shambles in.",
	"closing": "Closing time! Ring up the last of the horde.",
	"morning": "Day %d. Get ready, then flip the OPEN sign by the door.",
	"spill": "Blood on the floor! A little is fine, but lots of it scares shoppers off, and every puddle costs you XP. Grab the mop from the bucket.",
	"jam": "Unexpected limb in the bagging area! Go fix the self-checkout.",
	"brew_bought": "%s: %s",
	"brew_done": "Your %s wore off.",
}

## Lighting. day/night: how dark it is away from the ceiling lights.
## plain_night: the night tint on Low graphics. menu: the main menu's tint.
const LIGHT := {
	"day": Color(0.66, 0.72, 0.64),
	"night": Color(0.36, 0.42, 0.4),
	"lamp": Color(0.86, 1.0, 0.78),
	"plain_night": Color(0.62, 0.7, 0.64),
	"menu": Color(0.5, 0.58, 0.5),
}
