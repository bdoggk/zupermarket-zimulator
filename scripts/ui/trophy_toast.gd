class_name TrophyToast
extends PanelContainer
## "TROPHY!" across the top of the screen when you earn one (0.18), with a
## fanfare: its name, what it was for and what it paid. More than one at a
## time wait their turn.

const SECONDS := 5.0
const FANFARE := preload("res://assets/sounds/trophy.wav")
const CHIME := preload("res://assets/sounds/goal_done.wav")
const CUP := preload("res://assets/sprites/trophy.png")

var title: Label
var line: Label
var held := false  # (set by the HUD) a menu or the day's summary is up: wait, then show
var _queue: Array[Dictionary] = []
var _left := 0.0
var _sound: AudioStreamPlayer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.12, 0.04, 0.95)
	style.border_color = Color(0.95, 0.78, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var cup := UI.icon(CUP, Vector2(48, 48))
	cup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cup)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	title = UI.label("", Color(1.0, 0.86, 0.4))
	title.add_theme_font_size_override("font_size", 24)
	col.add_child(title)
	line = UI.label("", Color.WHITE)
	col.add_child(line)
	_sound = AudioStreamPlayer.new()
	add_child(_sound)
	Game.trophy_earned.connect(func(t: Dictionary): _queue.append(t))
	Game.goal_done.connect(func(_g): _play(CHIME))


func _play(stream: AudioStream) -> void:
	_sound.stream = stream
	_sound.play()


func _process(delta: float) -> void:
	if held:
		visible = false
		return
	if _left > 0.0:
		visible = true
		_left -= delta
		modulate.a = clampf(_left * 2.0, 0.0, 1.0)
		if _left <= 0.0:
			visible = false
		return
	if _queue.is_empty():
		return
	var t: Dictionary = _queue.pop_front()
	title.text = "TROPHY: %s" % t.name
	var unlocks := ""
	for id: String in Game.FURNITURE:
		if Game.FURNITURE[id].get("trophy", "") == t.id:
			unlocks = "   New decoration: %s" % Game.FURNITURE[id].name
	line.text = "%s.   +$%s%s" % [t.text, Game.cash(float(t.cash)), unlocks]
	visible = true
	modulate.a = 1.0
	_left = SECONDS
	reset_size()
	_play(FANFARE)
	Settings.vibrate(0.6, 0.3)
