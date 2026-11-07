class_name GoalsPanel
extends PanelContainer
## Today's goals in the top left (0.18): a tick box, what to do and how far
## along you are, for each of Game.goals.list, with the Perfect Day streak
## at the top. A goal that's just been done lights up green for a moment.
## Click or tap the title to fold it down to one line ("Goals 1/3").

const BOX := preload("res://assets/sprites/goal_box.png")
const TICK := preload("res://assets/sprites/goal_done.png")
const FLASH := 2.5  # seconds a goal that's just been done stays lit up

var folded := false
var title: Label
var streak_label: Label
var rows: Array = []  # [HBoxContainer, TextureRect, Label (what), Label (how far)]
var list_box: VBoxContainer
var _flash := {}  # goal index -> seconds left lit up
var _shown := ""  # what's on screen (it's only rebuilt when that changes)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var small := 16 if Game.touch_ui else 14  # (bigger on a phone, like the rest of the HUD)
	var big := 18 if Game.touch_ui else 15
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	title = UI.label("TODAY'S GOALS", UI.DIM)
	title.add_theme_font_size_override("font_size", small)
	top.add_child(title)
	streak_label = UI.label("", UI.WARN)
	streak_label.add_theme_font_size_override("font_size", small)
	streak_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(streak_label)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 2)
	col.add_child(list_box)
	for i in Goals.COUNT:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		list_box.add_child(row)
		var tick := UI.icon(BOX, Vector2(big + 1, big + 1))
		tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tick)
		var what := UI.label("", Color.WHITE)
		what.add_theme_font_size_override("font_size", big)
		row.add_child(what)
		var how := UI.label("", UI.INFO)
		how.add_theme_font_size_override("font_size", big)
		how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		how.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(how)
		rows.append([row, tick, what, how])
	gui_input.connect(_on_input)
	Game.goal_done.connect(_on_goal_done)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		folded = not folded
		_shown = ""
		accept_event()


func _on_goal_done(g: Dictionary) -> void:
	var i: int = Game.goals.list.find(g)
	if i >= 0:
		_flash[i] = FLASH


## Whether there's anything to show today.
static func has_goals() -> bool:
	return not Game.goals.list.is_empty() and Game.goals.day == Game.day


func _process(delta: float) -> void:
	if not visible:
		return
	for i in _flash.keys():
		_flash[i] -= delta
		if _flash[i] <= 0.0:
			_flash.erase(i)
	var list: Array[Dictionary] = Game.goals.list
	var done := Game.goals.done_count()
	var streak := Game.goals.streak
	var lines: Array[String] = []
	for g in list:
		lines.append("%s|%s|%s" % [Goals.text(g), Goals.progress_text(g), g.done])
	var key := "%s|%d|%d|%s|%s" % [folded, done, streak, "\n".join(lines), _flash.keys()]
	if key == _shown:
		return
	_shown = key
	title.text = ("Goals %d/%d" % [done, list.size()]) if folded else "TODAY'S GOALS"
	UI.set_color(title, UI.GOOD if done == list.size() else UI.DIM)
	streak_label.text = "Streak %d" % streak if streak > 0 and not folded else ""
	streak_label.tooltip_text = "Perfect Days in a row (every goal done). Tonight's bonus: $%d" % int(Goals.perfect_bonus(streak + 1))
	list_box.visible = not folded
	for i in rows.size():
		var r: Array = rows[i]
		var row: HBoxContainer = r[0]
		row.visible = i < list.size()
		if not row.visible:
			continue
		var g: Dictionary = list[i]
		(r[1] as TextureRect).texture = TICK if g.done else BOX
		var what: Label = r[2]
		what.text = Goals.text(g)
		UI.set_color(what, UI.GOOD if _flash.has(i) else (UI.DIM if g.done else Color.WHITE))
		var how: Label = r[3]
		how.text = "+$%d" % int(g.cash) if g.done else Goals.progress_text(g)
		UI.set_color(how, UI.GOOD if g.done else UI.INFO)
		row.tooltip_text = "Reward: $%d and %d XP" % [int(g.cash), int(g.xp)]
	reset_size()
