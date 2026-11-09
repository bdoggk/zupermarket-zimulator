class_name BossBones
extends Gangster
## Mr. Bones himself, for the showdown at his crypt (0.20, Turf, GangWar
## .showdown). A gangster on Bone Mart's side with a lot more in him: he
## hits harder, taunts you, calls two more of his gang out of the crypt
## when he's down to half, and only you can hurt him (your gang deals with
## his guards). He won't leave his graveyard: get far enough away (LEASH)
## and he goes back to his crypt, so you can get your breath back.

const HP := 40
const DAMAGE := 2
const EVERY := 2.0  # (a big slow swing: hit him, back off to get your breath, hit him again)
const SPEED := 2.3
const TAUNT_EVERY := 7.0
const LEASH := 9  # cells from his crypt's door he'll chase you

var summoned := false
var _taunt := 3.0


## Turns this (just set up as one of Bone Mart's gang) into Mr. Bones.
func make_boss() -> void:
	max_hp = HP
	hp = HP
	damage = DAMAGE
	every = EVERY
	speed = SPEED


## He only has eyes for you (his guards take care of your gang), as long
## as you're in his graveyard.
func _can_fight(n: Node2D) -> bool:
	if not (n is Player and super._can_fight(n)):
		return false
	if Iso.chebyshev((n as Player).current_cell(), home) > LEASH:
		if foe == n:
			Game.show_popup(position + Vector2(0, -60), "Run, coward! RUN!", Color(0.95, 0.92, 0.8))
		return false
	return true


func get_pick_rect() -> Rect2:
	return Rect2(-13, -52, 26, 56)


func hurt(amount: int, from: Node2D) -> void:
	if from is Gangster:  # (only you can take him down)
		if not is_out():
			Game.show_popup(position + Vector2(0, -56), "Ha!", Color(0.95, 0.92, 0.8))
		return
	super.hurt(amount, from)
	if not summoned and hp * 2 <= max_hp and not is_out():
		summoned = true
		turf.boss_summons(self)


func _process(delta: float) -> void:
	super._process(delta)
	if is_out() or foe == null:
		return
	_taunt -= delta
	if _taunt <= 0.0:
		_taunt = TAUNT_EVERY
		var taunts: Array = Brand.SHOWDOWN.taunts
		Game.show_popup(position + Vector2(0, -60), taunts.pick_random(), Color(0.95, 0.92, 0.8))


func _draw() -> void:
	if down or _fading:
		return
	var w := 30.0  # a bigger health bar, always showing
	draw_rect(Rect2(-w / 2.0 - 1, -58, w + 2, 5), Color(0.05, 0.05, 0.07, 0.9))
	draw_rect(Rect2(-w / 2.0, -57, w * hp / max_hp, 3), Color(0.95, 0.25, 0.2))
