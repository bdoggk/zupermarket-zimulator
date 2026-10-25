class_name PcSnake
extends HBoxContainer
## Zombie Snake, on the store computer: steer a snake round the screen
## eating what your store sells. Every bite makes it longer and a little
## faster; running into a wall or yourself ends the game. The best score is
## saved with the store (Game.snake_best).
##
## Arrow keys or WASD, the d-pad or left stick, a swipe on the board, or the
## arrow buttons to steer; Enter, Space, A or a tap to start. It pauses when
## you close the app (or the computer) and carries on when you come back.

enum State { READY, PLAYING, PAUSED, OVER }

const COLS := 24
const ROWS := 15
const STEP_START := 0.15  # seconds per move at the start...
const STEP_MIN := 0.065  # ...the fastest it gets...
const STEP_FASTER := 0.005  # ...and how much quicker each bite makes it
const SWIPE := 24.0  # pixels of drag that turn the snake
const START := [Vector2i(6, 7), Vector2i(5, 7), Vector2i(4, 7)]
const HEAD := Color(0.5, 0.88, 0.42)
const TAIL := Color(0.2, 0.5, 0.2)
const BOARD_BG := Color(0.04, 0.08, 0.05)
const BOARD_EDGE := Color(0.3, 0.6, 0.3)
const SOUNDS := {
	"eat": preload("res://assets/sounds/snake_eat.wav"),
	"over": preload("res://assets/sounds/snake_over.wav"),
}
const ARROW := preload("res://assets/sprites/pc_arrow.png")

var state := State.READY
var snake: Array[Vector2i] = []  # head first
var dir := Vector2i.RIGHT
var food := Vector2i(-1, -1)
var food_icon: Texture2D
var score := 0
var new_best := false  # this game beat the old best
var step_time := STEP_START
var board: Control  # the game (the column on the right has the scores and the arrow buttons)
var score_label: Label
var best_label: Label
var help_label: Label
var arrow_buttons := {}  # Vector2i -> Button
var rng := RandomNumberGenerator.new()
var _turns: Array[Vector2i] = []  # turns pressed but not taken yet (two at most, so quick presses all count)
var _t := 0.0
var _swipe_from := Vector2.INF
var _stick := Vector2i.ZERO  # where the left stick points (one turn per push)
var _shown := false


func _init() -> void:
	add_theme_constant_override("separation", 16)
	custom_minimum_size = Vector2(420, 260)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	board = Control.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_board_input)
	add_child(board)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	side.custom_minimum_size.x = 170
	add_child(side)
	var title := UI.label("ZOMBIE SNAKE", UI.GOOD)
	title.add_theme_font_size_override("font_size", 24)
	side.add_child(title)
	score_label = UI.label("", Color.WHITE)
	score_label.add_theme_font_size_override("font_size", 22)
	side.add_child(score_label)
	best_label = UI.label("", UI.WARN)
	side.add_child(best_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	# The arrow buttons, in a cross (for a mouse or a touch screen).
	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 4)
	pad.add_theme_constant_override("v_separation", 4)
	pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	side.add_child(pad)
	for row in [[Vector2i.ZERO, Vector2i.UP, Vector2i.ZERO], [Vector2i.LEFT, Vector2i.ZERO, Vector2i.RIGHT], [Vector2i.ZERO, Vector2i.DOWN, Vector2i.ZERO]]:
		for d: Vector2i in row:
			if d == Vector2i.ZERO:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(52, 52)
				pad.add_child(gap)
				continue
			var b := UI.button("", func(): press(d), Vector2(52, 52))
			b.icon = _arrow(d)
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 28)
			b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS  # (turns the moment you touch it)
			pad.add_child(b)
			arrow_buttons[d] = b
	help_label = UI.label("", UI.DIM)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.add_theme_font_size_override("font_size", 15)
	side.add_child(help_label)
	rng.randomize()
	_reset()


## The arrow sprite turned to point `d`.
static func _arrow(d: Vector2i) -> Texture2D:
	var img := ARROW.get_image()
	img.decompress()
	match d:
		Vector2i.RIGHT:
			img.rotate_90(CLOCKWISE)
		Vector2i.DOWN:
			img.rotate_180()
		Vector2i.LEFT:
			img.rotate_90(COUNTERCLOCKWISE)
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- the game

func best() -> int:
	return Game.snake_best


## A new snake, waiting for you to start.
func _reset() -> void:
	snake.assign(START)
	dir = Vector2i.RIGHT
	_turns.clear()
	score = 0
	new_best = false
	step_time = STEP_START
	_t = 0.0
	_place_food()


func start() -> void:
	if state == State.PAUSED:
		state = State.PLAYING
		return
	_reset()
	state = State.PLAYING


## A direction (an arrow, the d-pad, a swipe): turns the snake, or starts
## the game heading that way.
func press(d: Vector2i) -> void:
	if state == State.PAUSED:
		start()
	elif state != State.PLAYING:
		start()
		if d != -dir:
			dir = d
		return
	turn(d)


## Turns the snake on its next move. Doubling back on yourself doesn't
## count, and quick presses queue up (two at most).
func turn(d: Vector2i) -> void:
	var last: Vector2i = _turns.back() if not _turns.is_empty() else dir
	if d == last or d == -last or _turns.size() >= 2:
		return
	_turns.append(d)


## One move: the head goes one square on (eating whatever's there).
func step() -> void:
	if not _turns.is_empty():
		dir = _turns.pop_front()
	var head := snake[0] + dir
	var eating := head == food
	var body := snake.slice(0, snake.size() - (0 if eating else 1))  # (the tail moves out of the way)
	if head.x < 0 or head.y < 0 or head.x >= COLS or head.y >= ROWS or head in body:
		_game_over()
		return
	snake.insert(0, head)
	if eating:
		score += 1
		step_time = maxf(STEP_MIN, step_time - STEP_FASTER)
		_play("eat")
		Settings.vibrate(0.15, 0.05)
		_place_food()
	else:
		snake.pop_back()


func _game_over() -> void:
	state = State.OVER
	if score > best():
		Game.snake_best = score
		new_best = true
	_play("over")
	Settings.vibrate(0.5, 0.25)


## Something your store sells, on a free square.
func _place_food() -> void:
	var free: Array[Vector2i] = []
	for y in ROWS:
		for x in COLS:
			var c := Vector2i(x, y)
			if not c in snake:
				free.append(c)
	if free.is_empty():
		food = Vector2i(-1, -1)
		return
	food = free[rng.randi() % free.size()]
	var ids: Array = Game.unlocked_ids()
	if ids.is_empty():
		ids = Game.PRODUCTS.keys()
	food_icon = Game.PRODUCTS[ids[rng.randi() % ids.size()]].icon


func _play(sound: String) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = SOUNDS[sound]
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _process(delta: float) -> void:
	var shown := is_visible_in_tree() and not get_tree().paused
	if not shown:
		if state == State.PLAYING:
			state = State.PAUSED  # (you closed it, or the game's paused)
		_shown = false
		return
	_shown = true
	if Engine.time_scale > 0.0:
		delta /= Engine.time_scale  # (real time, whatever speed the store runs at)
	if state == State.PLAYING:
		_t += delta
		while _t >= step_time and state == State.PLAYING:
			_t -= step_time
			step()
	score_label.text = "Score %d" % score
	best_label.text = "Best %d" % maxi(best(), score)
	if UI.has_pad():
		help_label.text = "D-pad or stick: steer\nA: start"
	elif Game.touch_ui:
		help_label.text = "Swipe on the board or tap the arrows to steer"
	else:
		help_label.text = "Arrows or WASD: steer\nEnter or Space: start"
	board.queue_redraw()


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var d := Vector2i.ZERO
	var go := false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W:
				d = Vector2i.UP
			KEY_DOWN, KEY_S:
				d = Vector2i.DOWN
			KEY_LEFT, KEY_A:
				d = Vector2i.LEFT
			KEY_RIGHT, KEY_D:
				d = Vector2i.RIGHT
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				go = true
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_UP:
				d = Vector2i.UP
			JOY_BUTTON_DPAD_DOWN:
				d = Vector2i.DOWN
			JOY_BUTTON_DPAD_LEFT:
				d = Vector2i.LEFT
			JOY_BUTTON_DPAD_RIGHT:
				d = Vector2i.RIGHT
			JOY_BUTTON_A:
				go = true
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var v := Vector2(Input.get_joy_axis(event.device, JOY_AXIS_LEFT_X), Input.get_joy_axis(event.device, JOY_AXIS_LEFT_Y))
		var now := Vector2i.ZERO
		if v.length() > 0.6:
			now = Vector2i(signi(roundi(v.x)), 0) if absf(v.x) > absf(v.y) else Vector2i(0, signi(roundi(v.y)))
		if now != _stick and now != Vector2i.ZERO:
			d = now
		_stick = now
		if d == Vector2i.ZERO:
			return
	if d != Vector2i.ZERO:
		press(d)
	elif go:
		if state != State.PLAYING:
			start()
	else:
		return
	get_viewport().set_input_as_handled()


## Touch or the mouse on the board: a tap starts, a swipe steers. (A
## touch comes in as the mouse too, so only the mouse is read: one tap is
## one tap.)
func _board_input(event: InputEvent) -> void:
	var pos := Vector2.INF
	var down := false
	var moved := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		down = event.pressed
		if not down:
			_swipe_from = Vector2.INF
			return
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		pos = event.position
		moved = true
	else:
		return
	board.accept_event()
	if down:
		_swipe_from = pos
		if state != State.PLAYING:
			start()
		return
	if moved and _swipe_from != Vector2.INF:
		var v := pos - _swipe_from
		if v.length() >= SWIPE:
			turn(Vector2i(signi(roundi(v.x)), 0) if absf(v.x) > absf(v.y) else Vector2i(0, signi(roundi(v.y))))
			_swipe_from = pos


# ---------------------------------------------------------------- drawing

## The board's square size and top-left corner (whole pixels, centered).
func cell_rect() -> Array:
	var cell := maxf(4.0, floorf(minf(board.size.x / COLS, board.size.y / ROWS)))
	var size := Vector2(COLS, ROWS) * cell
	return [cell, ((board.size - size) / 2.0).floor()]


func _draw_board() -> void:
	var cr := cell_rect()
	var cell: float = cr[0]
	var at: Vector2 = cr[1]
	var area := Rect2(at, Vector2(COLS, ROWS) * cell)
	board.draw_rect(area.grow(3), BOARD_EDGE)
	board.draw_rect(area, BOARD_BG)
	for y in ROWS:  # faint dots, like an old screen
		for x in COLS:
			board.draw_rect(Rect2(at + (Vector2(x, y) + Vector2(0.5, 0.5)) * cell - Vector2.ONE, Vector2(2, 2)), Color(0.15, 0.3, 0.16, 0.6))
	if food.x >= 0 and food_icon:
		var bob := roundf(sin(Time.get_ticks_msec() / 160.0)) if state == State.PLAYING else 0.0
		var k := floorf(cell * 0.9 / maxf(food_icon.get_width(), food_icon.get_height()))
		k = maxf(1.0, k)
		var fs := food_icon.get_size() * k
		var fp := at + Vector2(food) * cell + (Vector2(cell, cell) - fs) / 2.0 + Vector2(0, bob)
		board.draw_texture_rect(food_icon, Rect2(fp.floor(), fs), false)
	var n := snake.size()
	for i in range(n - 1, -1, -1):
		var c := snake[i]
		var col := HEAD.lerp(TAIL, float(i) / maxf(1.0, n - 1))
		var r := Rect2(at + Vector2(c) * cell, Vector2(cell, cell)).grow(-1)
		board.draw_rect(r, col.darkened(0.45))
		board.draw_rect(r.grow(-1), col)
	if n > 0:  # red eyes, looking the way it's going
		var h := at + Vector2(snake[0]) * cell
		var e := maxf(2.0, floorf(cell / 5.0))
		var side := Vector2(-dir.y, dir.x)
		var mid := h + Vector2(cell, cell) / 2.0 + Vector2(dir) * cell * 0.18
		for s in [-1.0, 1.0]:
			board.draw_rect(Rect2((mid + side * s * cell * 0.22 - Vector2(e, e) / 2.0).floor(), Vector2(e, e)), Color(0.9, 0.12, 0.12))
	if state != State.PLAYING:
		board.draw_rect(area, Color(0, 0, 0, 0.55))
		var lines: Array[String] = []
		match state:
			State.READY:
				lines = ["ZOMBIE SNAKE", "Eat what your store sells.", _start_hint()]
			State.PAUSED:
				lines = ["PAUSED", _start_hint("carry on")]
			State.OVER:
				lines = ["GAME OVER", ("New best: %d!" if new_best else "Score: %d") % score, _start_hint("play again")]
		var font := get_theme_default_font()
		var y := area.get_center().y - lines.size() * 18.0
		for i in lines.size():
			var fsz := 34 if i == 0 else 20
			var col := UI.GOOD if i == 0 else (UI.WARN if new_best and state == State.OVER and i == 1 else Color.WHITE)
			board.draw_string_outline(font, Vector2(area.position.x, y), lines[i], HORIZONTAL_ALIGNMENT_CENTER, area.size.x, fsz, 6, Color(0, 0, 0, 0.9))
			board.draw_string(font, Vector2(area.position.x, y), lines[i], HORIZONTAL_ALIGNMENT_CENTER, area.size.x, fsz, col)
			y += fsz + 14.0


func _start_hint(what := "start") -> String:
	if UI.has_pad():
		return "Press A to %s" % what
	if Game.touch_ui:
		return "Tap to %s" % what
	return "Press Enter to %s" % what
