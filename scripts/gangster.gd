class_name Gangster
extends Interactable
## Someone in the gang war (GangWar, Turf): one of Bone Mart's skeleton
## thugs, or one of your zombie gang. They walk the town's grid like
## everyone else and fight: walk up to an enemy and hit it until one of
## them is knocked out. Bone Mart's are in Store.movers (like its spies), so
## you can walk up to one and hit it (E), tap it, or shoot it from across
## the store with the Glock.
##
## Turf gives each one a job; a fight always comes first.

enum Job { GUARD, RESPOND, RAID_STORE, TAKE_BRANCH, DEFEND, RAID, HOME }
enum Step { GO, SMASH, ROB, HOLD }

const BONE := "bone"
const ZOMBIE := "zombie"
## How tough each side is: hit points, damage per hit, seconds between hits.
const STATS := {
	"bone": {"hp": 4, "damage": 1, "every": 1.1, "speed": 2.6},
	"zombie": {"hp": 6, "damage": 1, "every": 1.0, "speed": 2.9},
}
const SIGHT := 6  # cells: picks a fight with an enemy this close...
const RESPOND_SIGHT := 12  # ...or this close when it's running to a fight...
const DEFEND_SIGHT := 4  # ...or this close guarding Bone Mart (they hold their ground)
const PLAYER_SIGHT := 2  # Bone Mart's go for you when you're this close (or once you've hit one of them)
const SMASH_SECONDS := 2.0
const ROB_SECONDS := 2.5
const SCARE_RANGE := 4  # shoppers this close to a thug in your store run for it
const REPATH := 0.35
const DOWN_SECONDS := 6.0  # lies there this long, then fades away
const FADE_SPEED := 2.5
const UNSTICK_AFTER := 2.0

var store: Store
var turf: Node  # Turf
var side := BONE
var gang_name := ""
var member_id := 0  # your gang: its GangWar id
var hp := 4
var max_hp := 4
var damage := 1
var every := 1.0
var speed := 2.6
var job := Job.GUARD
var step := Step.GO
var target_plot := -1  # the branch this is about (TAKE_BRANCH, RAID, RESPOND), -1 for a main store
var home := Store.NO_CELL  # where it goes back to
var spot := Store.NO_CELL  # where its job has it stand
var foe: Node2D = null  # who it's fighting: a Gangster or the Player
var angry := false  # Bone Mart's: you've hit one of their gang
var down := false
var retired := false  # fired from your gang: walking off, out of the war
var holding := false  # waiting for the rest of the gang (on a raid): only fights back
var sprite: Sprite2D
var path: Array[Vector2i] = []
var goal := Store.NO_CELL
var timer := 0.0  # smashing or robbing
var smashing: Shelf = null
var did_smash := false
var _cooldown := 0.0
var _repath := 0.0
var _hit_flash := 0.0
var _lunge := 0.0
var _lunge_dir := Vector2.ZERO
var _alpha := 0.0
var _fading := false
var _down_t := 0.0
var _walk_anim := 0.0
var _stuck := 0.0
var _last_pos := Vector2.ZERO
var _scare_t := 0.0
var _t := randf() * 10.0


func setup(s: Store, t: Node, which: String, name_text: String, look: Texture2D, at: Vector2i) -> void:
	store = s
	turf = t
	side = which
	gang_name = name_text
	var st: Dictionary = STATS[side]
	max_hp = int(st.hp)
	hp = max_hp
	damage = int(st.damage)
	every = float(st.every)
	speed = float(st.speed)
	cell = at
	home = at
	position = Iso.cell_to_world(at)
	sprite = Sprite2D.new()
	sprite.texture = look
	sprite.centered = false
	sprite.offset = Vector2(-floorf(look.get_width() / 2.0), -(look.get_height() - 2))
	add_child(sprite)


func current_cell() -> Vector2i:
	return Iso.world_to_cell(position)


func is_enemy_of(other: Gangster) -> bool:
	return other.side != side


## Knocked out (or on the way out): not part of the fight anymore.
func is_out() -> bool:
	return down or _fading or retired


# ---------------------------------------------------------------- the player

func get_prompt(p: Player) -> String:
	if is_out():
		return ""
	if side == ZOMBIE:
		return "%s (your gang)" % gang_name
	match Game.war.weapon():
		"glock":
			return "Shoot %s" % gang_name
		"nunchucks":
			return "Whack %s" % gang_name
	return "Punch %s" % gang_name


func can_interact(p: Player) -> bool:
	return side == BONE and not is_out() and p.can_hit(self)


func use_priority(_p: Player) -> int:
	return 6  # before anything it's standing next to


func interact(p: Player) -> void:
	p.attack(self)


func get_pick_rect() -> Rect2:
	return Rect2(-10, -40, 20, 44)


func is_movable() -> bool:
	return false


func is_sellable() -> bool:
	return false


# ---------------------------------------------------------------- fighting

## Takes a hit from `from` (a Gangster or the Player).
func hurt(amount: int, from: Node2D) -> void:
	if is_out():
		return
	hp -= amount
	_hit_flash = 0.15
	if from is Player and side == BONE:
		turf.bone_angry()  # the whole gang comes for you now
	if from != null:
		var pushed := position + (position - from.position).normalized() * 3.0  # knocked back a little...
		if store.is_walkable(Iso.world_to_cell(pushed)):  # ...but never into a wall
			position = pushed
		if foe == null or not _can_fight(foe):
			foe = from
	Game.show_popup(position + Vector2(0, -46), "-%d" % amount, Color(1.0, 0.5, 0.4) if side == BONE else Color(1.0, 0.75, 0.4))
	if hp <= 0:
		_knocked_out(from)


func _knocked_out(by: Node2D) -> void:
	down = true
	foe = null
	path.clear()
	smashing = null
	highlighted = false
	if side == BONE:
		sprite.texture = Brand.WAR.textures.bones  # falls apart into a heap of bones
		sprite.offset = Vector2(-floorf(sprite.texture.get_width() / 2.0), -(sprite.texture.get_height() - 2))
		Game.show_popup(position + Vector2(0, -40), "CRACK!", Color(0.95, 0.92, 0.8))
	else:
		Game.show_popup(position + Vector2(0, -40), "Oof!", Color(0.7, 1.0, 0.6))
	turf.on_knocked_out(self, by)


func _can_fight(n: Node2D) -> bool:
	if not is_instance_valid(n):
		return false
	if n is Gangster:
		return not (n as Gangster).is_out() and (n as Gangster).side != side
	if n is Player:
		return side == BONE and (n as Player).can_be_hit()
	return false


## The nearest enemy worth fighting, or null.
func _pick_foe() -> Node2D:
	var sight := RESPOND_SIGHT if job in [Job.RESPOND, Job.RAID] else (DEFEND_SIGHT if job == Job.DEFEND else SIGHT)
	var here := current_cell()
	var best: Node2D = null
	var best_d := INF
	for g: Gangster in turf.gangsters:
		if g == self or not is_instance_valid(g) or not _can_fight(g):
			continue
		var d := float(Iso.chebyshev(g.current_cell(), here))
		if d <= sight and d < best_d:
			best_d = d
			best = g
	var p: Player = store.player
	if side == BONE and p and _can_fight(p):
		var d := float(Iso.chebyshev(p.current_cell(), here))
		if (d <= PLAYER_SIGHT or (angry and d <= sight + 4)) and d < best_d + 0.5:
			best = p
	return best


func _fight(delta: float) -> void:
	var f_cell: Vector2i = foe.current_cell() if foe.has_method("current_cell") else Iso.world_to_cell(foe.position)
	if Iso.chebyshev(current_cell(), f_cell) <= 1 and position.distance_to(foe.position) < 52.0:
		path.clear()
		_face(foe.position)
		if _cooldown <= 0.0:
			_cooldown = every
			_lunge = 0.15
			_lunge_dir = (foe.position - position).normalized()
			turf.play_hit(position, side)
			foe.hurt(damage, self)
		return
	_repath -= delta
	if _repath <= 0.0 or path.is_empty():
		_repath = REPATH
		var to := f_cell if store.is_walkable(f_cell) else store.stand_cell_for(f_cell, current_cell())
		if to != goal or path.is_empty():  # (they've moved: a new way there)
			_go(to)
	_walk(delta, 1.15)


# ---------------------------------------------------------------- every frame

func _process(delta: float) -> void:
	_t += delta
	cell = current_cell()
	_cooldown = maxf(0.0, _cooldown - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_lunge = maxf(0.0, _lunge - delta)
	if _fading:
		_alpha -= delta * FADE_SPEED
		if _alpha <= 0.0:
			turf.forget(self)
			queue_free()
			return
	else:
		_alpha = minf(1.0, _alpha + delta * FADE_SPEED)
	if down:
		_down_t += delta
		if side == ZOMBIE:
			sprite.rotation = lerpf(sprite.rotation, -PI / 2.0 if sprite.flip_h else PI / 2.0, minf(1.0, delta * 10.0))
		if _down_t > DOWN_SECONDS:
			_fading = true
	elif not _fading:
		_think(delta)
	_animate(delta)
	var b := 1.3 if highlighted else 1.0
	modulate = Color(b, b, b, _alpha)
	if _hit_flash > 0.0:
		modulate = Color(2.0, 0.6, 0.6, _alpha)
	queue_redraw()


func _think(delta: float) -> void:
	if foe != null and not _can_fight(foe):
		foe = null
	if foe == null and job != Job.HOME and not retired and not holding:
		foe = _pick_foe()
	if foe != null:
		smashing = null
		timer = 0.0
		_fight(delta)
		return
	match job:
		Job.GUARD, Job.DEFEND:
			_stand_at(spot, delta)
		Job.RESPOND, Job.RAID, Job.TAKE_BRANCH:
			if _stand_at(spot, delta) and job == Job.TAKE_BRANCH:
				turf.taking_over(self, delta)
		Job.HOME:
			if _stand_at(home, delta):
				if side == ZOMBIE and not retired:
					job = Job.GUARD
					spot = home
				else:
					_fading = true
		Job.RAID_STORE:
			_raid_store(delta)


## Walks to `where` (re-planning now and then) and stands there. True once there.
func _stand_at(where: Vector2i, delta: float) -> bool:
	if where == Store.NO_CELL:
		return true
	if current_cell() == where and path.is_empty():
		return true
	if goal != where or (path.is_empty() and current_cell() != where):
		if not _go(where):
			return current_cell() == where
	_walk(delta)
	return false


## Bone Mart's gang in your store: smash a shelf, then rob the register.
func _raid_store(delta: float) -> void:
	if store.floor_cells.has(current_cell()):
		_scare_t -= delta
		if _scare_t <= 0.0:
			_scare_t = 0.5
			turf.scare_near(self, SCARE_RANGE)
	match step:
		Step.GO:
			if not did_smash:
				if smashing == null or not is_instance_valid(smashing):
					smashing = turf.shelf_to_smash(self)
				if smashing == null:
					did_smash = true
					return
				var stand := store.stand_cell_for(smashing.cell, current_cell())
				if _stand_at(stand, delta):
					step = Step.SMASH
					timer = SMASH_SECONDS
					_face(smashing.position)
			else:
				var reg: Register = turf.register_to_rob()
				if reg == null:
					turf.raid_done(self)
					return
				var stand := store.stand_cell_for(reg.cell, current_cell())
				if _stand_at(stand, delta):
					step = Step.ROB
					timer = ROB_SECONDS
					_face(reg.position)
		Step.SMASH:
			timer -= delta
			if timer <= 0.0:
				if is_instance_valid(smashing):
					turf.smash(self, smashing)
				smashing = null
				did_smash = true
				step = Step.GO
		Step.ROB:
			timer -= delta
			if timer <= 0.0:
				turf.rob(self)
				step = Step.GO


## Gone in a puff (a fight that went on far too long): fades away now.
func vanish() -> void:
	foe = null
	path.clear()
	_fading = true


## Goes back where it came from (and fades away, if it's Bone Mart's).
func go_home(to := Store.NO_CELL) -> void:
	job = Job.HOME
	foe = null
	smashing = null
	step = Step.GO
	if to != Store.NO_CELL:
		home = to


# ---------------------------------------------------------------- walking

func _go(to: Vector2i) -> bool:
	goal = to
	var p := store.find_path(current_cell(), to)
	if p.is_empty():
		path.clear()
		return current_cell() == to
	if p.size() > 1 or position.distance_to(Iso.cell_to_world(p[0])) < 2.0:
		p.remove_at(0)  # (already in that cell: straight on to the next)
	path = p
	_stuck = 0.0
	return true


func _walk(delta: float, faster := 1.0) -> void:
	if path.is_empty():
		return
	var to_target := Iso.cell_to_world(path[0]) - position
	var step_v := Iso.velocity_toward(to_target, speed * faster) * delta
	if step_v.length() >= to_target.length():
		position = Iso.cell_to_world(path[0])
		path.remove_at(0)
	else:
		position += step_v
	if absf(step_v.x) > 0.01:
		sprite.flip_h = step_v.x < 0.0
	if position.distance_to(_last_pos) > 0.5:
		_last_pos = position
		_stuck = 0.0
	else:
		_stuck += delta
		if _stuck > UNSTICK_AFTER and goal != Store.NO_CELL:
			_go(goal)


func _face(at: Vector2) -> void:
	if absf(at.x - position.x) > 1.0:
		sprite.flip_h = at.x < position.x


func _animate(delta: float) -> void:
	if down:
		sprite.position = Vector2.ZERO
		return
	var off := Vector2.ZERO
	if not path.is_empty():
		_walk_anim += delta * 15.0
		off.y = -roundf(absf(sin(_walk_anim)) * 1.5)
	elif step in [Step.SMASH, Step.ROB] and job == Job.RAID_STORE:
		off.x = roundf(sin(_t * 30.0))  # rattling the shelf / the till
	if _lunge > 0.0:
		off += (_lunge_dir * 5.0 * (_lunge / 0.15)).round()
	sprite.position = off


func _draw() -> void:
	if down or _fading:
		return
	if hp < max_hp:  # a little health bar over their head
		var w := 14.0
		draw_rect(Rect2(-w / 2.0 - 1, -42, w + 2, 4), Color(0.05, 0.05, 0.07, 0.85))
		draw_rect(Rect2(-w / 2.0, -41, w * hp / max_hp, 2), Color(0.9, 0.25, 0.2) if side == BONE else Color(0.45, 0.9, 0.4))
	if job == Job.RAID_STORE and step in [Step.SMASH, Step.ROB]:
		var f := 1.0 - timer / (SMASH_SECONDS if step == Step.SMASH else ROB_SECONDS)
		draw_rect(Rect2(-11, -50, 22, 5), Color(0.08, 0.08, 0.1, 0.9))
		draw_rect(Rect2(-10, -49, 20 * f, 3), Color(0.95, 0.3, 0.25))


## First person shows it from its sprite, like everyone else.
func fp_texture() -> Texture2D:
	return sprite.texture if sprite else null
