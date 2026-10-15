class_name SelfCheckout
extends Register
## A self-checkout kiosk (buy them in Build mode). Shoppers with only a few
## items can scan their own stuff here: slower than a cashier, but nobody
## has to run it. Every now and then a scan goes wrong ("Unexpected item in
## the bagging area!") and the machine stops until you come and fix it.
## Shoppers waiting on a stuck machine lose patience.

const ITEM_LIMIT := 5  # shoppers with more items go to a normal register
const SECONDS_PER_ITEM := 0.75
const JAM_CHANCE := 0.12
const FIX_SECONDS := 0.6
const SELF_TEXTURE := preload("res://assets/sprites/selfcheckout.png")
const LAMP := Vector2(9, -47)  # the light on top of the pole (local pixels)

var jammed := false
var _scanning: Customer = null
var _scan_t := 0.0
var _jam_at := -1.0  # seconds into this scan when it goes wrong (-1 = it won't)
var _t := 0.0


func _draw() -> void:
	draw_object_sprite(SELF_TEXTURE)
	var lamp := Color(0.4, 1.0, 0.45)
	if jammed:
		lamp = Color(1.0, 0.25, 0.2) if int(_t * 4.0) % 2 == 0 else Color(0.45, 0.1, 0.1)
	elif _scanning == null:
		lamp = Color(0.55, 0.7, 0.55)
	draw_rect(Rect2(LAMP - Vector2(2, 1), Vector2(4, 3)), lamp)
	if jammed:
		var y := -66.0 - absf(sin(_t * 5.0)) * 4.0
		draw_rect(Rect2(-5, y, 10, 14), Color(0.95, 0.3, 0.25))
		draw_rect(Rect2(-5, y, 10, 14), Color(0.15, 0.08, 0.08), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-3, y + 12), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	elif _scanning != null:
		var f := clampf(_scan_t / maxf(0.01, scan_time(_scanning)), 0.0, 1.0)
		draw_rect(Rect2(-11, -64, 22, 5), Color(0.08, 0.08, 0.1, 0.9))
		draw_rect(Rect2(-10, -63, 20 * f, 3), Color(0.55, 0.85, 0.45))


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	var c := front_customer()
	if c != _scanning:
		_scanning = c
		_scan_t = 0.0
		jammed = false
		_jam_at = randf_range(0.2, 0.8) * scan_time(c) if c and randf() < JAM_CHANCE else -1.0
	if _scanning and not jammed:
		_scan_t += delta
		if _jam_at >= 0.0 and _scan_t >= _jam_at:
			_jam_at = -1.0
			jammed = true
			Game.message.emit(Brand.SAY.get("jam", "Unexpected item in the bagging area!"))
			Game.show_popup(position + Vector2(0, -70), "Help!", Color(1.0, 0.5, 0.4))
		elif _scan_t >= scan_time(_scanning):
			checkout()
			_scanning = null
	queue_redraw()


func ghost_texture() -> Texture2D:
	return SELF_TEXTURE


func display_name() -> String:
	return "self-checkout"


func is_movable() -> bool:
	return true


func is_sellable() -> bool:
	return true


## Nobody runs a self-checkout, but it works on its own.
func is_staffed() -> bool:
	return false


## Shoppers only use it with a few items.
func accepts(c: Customer) -> bool:
	return c.item_count() <= ITEM_LIMIT


## The machine is scanning `c` right now (so their patience doesn't run out).
func is_serving(c: Customer) -> bool:
	return c == _scanning and not jammed


func scan_time(c: Customer) -> float:
	return c.item_count() * SECONDS_PER_ITEM if c else 0.0


func get_prompt(_p: Player) -> String:
	if jammed:
		return "Fix the self-checkout"
	if _scanning:
		var n := _scanning.item_count()
		return "Self-checkout: scanning %d item%s" % [n, "" if n == 1 else "s"]
	return "Self-checkout"


func can_interact(_p: Player) -> bool:
	return jammed


func get_action_time(_p: Player) -> float:
	return FIX_SECONDS


func get_action_label(_p: Player) -> String:
	return "Fixing the machine..."


func interact(_p: Player) -> void:
	if not jammed:
		return
	jammed = false
	Settings.vibrate(0.3, 0.05)
	Game.show_popup(position + Vector2(0, -60), "Fixed!", Color(0.6, 1.0, 0.6))
