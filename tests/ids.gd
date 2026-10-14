class_name TestIds
## Picks product ids for the tests by what they are (a starter product, a
## cold one, a level 4 one...) instead of by name, so the same tests run in
## both Supermarket Sim and Zupermarket Zimulator.


## The products you start the game with, in catalog order.
static func starters() -> Array:
	return Game.PRODUCTS.keys().filter(func(id): return Game.PRODUCTS[id].license <= 0.0)


static func starter(i: int) -> String:
	return starters()[i]


## The first product that needs a license and unlocks at `level`.
## cold: true = only cold ones, false = only dry ones, null = either.
static func at_level(level: int, cold: Variant = null) -> String:
	for id in Game.PRODUCTS:
		var p: Dictionary = Game.PRODUCTS[id]
		if p.license > 0.0 and p.level == level and (cold == null or p.cold == cold):
			return id
	return ""


## The first cold product (it needs a fridge / cooler).
static func cold() -> String:
	for id in Game.PRODUCTS:
		if Game.PRODUCTS[id].cold:
			return id
	return ""
