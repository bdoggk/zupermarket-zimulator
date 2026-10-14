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
const UPGRADES := {
	"scanner": {
		"name": "Handheld Scanner",
		"cost": 120.0,
		"desc": "Scan any shelf to order a box of what's on it, right there.",
		"icon": preload("res://assets/sprites/scanner.png"),
	},
}

## Furniture you can buy in build mode. kind is shelf, fridge, decor or
## register. The ids stay the same in both games; only names and art change.
const FURNITURE := {
	"shelf": {"name": "Rusty Shelf", "cost": 60.0, "kind": "shelf", "texture": preload("res://assets/sprites/shelf.png")},
	"fridge": {"name": "Meat Cooler", "cost": 150.0, "kind": "fridge", "texture": preload("res://assets/sprites/fridge.png")},
	"plant": {"name": "Gravestone", "cost": 25.0, "kind": "decor", "texture": preload("res://assets/sprites/plant.png")},
	"register": {"name": "Register", "cost": 250.0, "kind": "register", "texture": preload("res://assets/sprites/register.png")},
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
	"too_pricey": "Grrr... pricey!",
	"sold_out": "Braaains... sold out?!",
	"walkout": "Uuurrgh!",
	"opened": "Doors open! The horde shambles in.",
	"closing": "Closing time! Ring up the last of the horde.",
	"morning": "Day %d. Get ready, then flip the OPEN sign by the door.",
	"spill": "Blood on the floor! Grab the mop from the bucket. Even zombies hate a messy store.",
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
