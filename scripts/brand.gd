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
## The market stalls down the path (see SHOPS):
##   V  the vampire's curio stall       u  where the vampire stands
##   W  the witch's brewery stall       y  where the witch stands
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
	",,,,,,,,,,,,:,,,,,x,,,;;;;;,,,,,,,,,,,,,:,,,,B,,",
	",T,www,,ww,Q:,,,,,,,,,;;;;;,www,,wwww,,,:,,;;;;;",
	",,,w,,,,,,uV:,,g,g,g,g;;v;;,w,,,,,,xw,,,:,,;;;;;",
	";;;w;x,,,,,,:,,,,,,,,,;;;;;,w,B,,,,,,,,,:,,;T;;;",
	";;;;;;,T,,,,:,,g,g,T,g;;;;;,w,,,,x,,w,v,:,,;;;;;",
	";;;w;;,,x,yW:,v,,,,,,,;;;;;,w,,,,,,,w,,,:,,;;;;;",
	";;;w;;,,,,,K:,,g,g,g,g,,,,,,wwwwww,ww,,,:,,;;;;;",
	";;;wwwwww,,,:,,,,,,,,,,,,,,,,,,,,,,,,,,,:,v;;;;;",
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
	"textures": {
		"owner": preload("res://assets/sprites/skeleton_owner.png"),
		"stocker": preload("res://assets/sprites/skeleton_stocker.png"),
		"sign": preload("res://assets/sprites/rival_sign.png"),
		"sign_sold": preload("res://assets/sprites/rival_sign_sold.png"),
	},
}

## Market stalls down the path across the street. Use the counter to buy
## what they sell (BREWS): each one does something for a little while.
##   map / keeper_map  their counter and their keeper in TOWN
const SHOPS := {
	"curios": {
		"name": "Fangsworth's Curios", "keeper": "Count Fangsworth", "map": "V", "keeper_map": "u",
		"hello": "Garlic? Crucifixes? Don't ask why a vampire sells them.",
		"blurb": "Charms against all sorts of trouble. The Count doesn't touch the stock.",
		"stall": preload("res://assets/sprites/stall_curios.png"),
		"keeper_look": preload("res://assets/sprites/keeper_vampire.png"),
		"light": Color(1.0, 0.72, 0.4),
	},
	"brewery": {
		"name": "The Bubbling Cauldron", "keeper": "Old Hagatha", "map": "W", "keeper_map": "y",
		"hello": "Potions and wine, dearie! Fresh from the cauldron.",
		"blurb": "Brewed this morning. Drink it right here; it works straight away.",
		"stall": preload("res://assets/sprites/stall_brewery.png"),
		"keeper_look": preload("res://assets/sprites/keeper_witch.png"),
		"light": Color(0.6, 1.0, 0.55),
	},
}

## What the stalls sell. It works straight away, for `seconds` (real
## seconds); buying another adds more time (see Game.buy_brew).
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
}

## Kinds of shoppers.
##   weight     how common they are       level  store level they start showing up
##   speed      walking speed (1 = normal)       patience  how long they'll wait in line
##   items      how many different products they want ([min, max])
##   qty        how many of each ([min, max])
##   tolerance  how far over the market price they'll still pay (1 = not at all)
##   leaky      chance they drip blood   rival  extra chance they shop at the rival
##   night      (optional) this many times as common after 5 PM, and rarer by day
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
		"items": [1, 3], "qty": [1, 2], "tolerance": 0.9, "leaky": 0.0, "rival": 0.15,
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
		"items": [2, 4], "qty": [1, 2], "tolerance": 1.5, "leaky": 0.0, "rival": -0.1,
		"looks": [preload("res://assets/sprites/shopper_rich.png")],
	},
	"witch": {
		"name": "Witch", "plural": "witches", "weight": 2.0, "level": 2, "speed": 1.1, "patience": 0.9,
		"items": [1, 3], "qty": [1, 3], "tolerance": 0.95, "leaky": 0.0, "rival": 0.05,
		"looks": [preload("res://assets/sprites/shopper_witch_0.png"), preload("res://assets/sprites/shopper_witch_1.png")],
	},
	"vampire": {
		"name": "Vampire", "weight": 1.5, "level": 3, "speed": 1.25, "patience": 1.5,
		"items": [2, 4], "qty": [1, 2], "tolerance": 1.3, "leaky": 0.0, "rival": -0.05, "night": 3.0,
		"looks": [preload("res://assets/sprites/shopper_vampire_0.png"), preload("res://assets/sprites/shopper_vampire_1.png")],
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
		"desc": "Checks the stock and orders more boxes of anything whose shelves are down to a third full. Keeps the other staff working (15% faster) and gets anyone who's stuck moving again.",
		"texture": preload("res://assets/sprites/staff_manager.png"),
	},
}
const STAFF_NAMES := [
	"Zed", "Ghoulia", "Rotney", "Brainard", "Moaning Mary", "Stiff Steve",
	"Bones", "Grisly Gus", "Mortimer", "Lurch", "Dee Composed", "Carl Cadaver",
	"Pale Paula", "Limpy Lou", "Morgana", "Half Hank",
]

## What people are called and what they say.
const SAY := {
	"shopper": "zombie",
	"shoppers": "zombies",
	"no_product": "No %s?! Grrr",
	"not_sold": "You don't sell %s?!",
	"too_pricey": "Grrr... pricey!",
	"sold_out": "Braaains... sold out?!",
	"walkout": "Uuurrgh!",
	"opened": "Doors open! The horde shambles in.",
	"closing": "Closing time! Ring up the last of the horde.",
	"morning": "Day %d. Get ready, then flip the OPEN sign by the door.",
	"spill": "Blood on the floor! Grab the mop from the bucket. Blood scares shoppers off and costs you XP.",
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
