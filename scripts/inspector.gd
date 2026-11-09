class_name Inspector
extends Visitor
## The health inspector (0.19, Calendar event "inspector"): walks in, looks
## over a few shelves and coolers and the line at a register, scribbling
## notes, then grades the store on the way out (DayEvents.grade). Blood on
## the floor, empty shelves, a long line and boxes lying around all cost
## points. You can't throw an inspector out.

const STOPS := 4  # shelves and coolers looked at...
const LOOK_SECONDS := 2.5  # ...this long each

var stops_left: Array = []
var graded := false


func _init() -> void:
	speed = 1.8


func get_prompt(_p: Player) -> String:
	return "The health inspector (be nice)"


func can_interact(_p: Player) -> bool:
	return false


func _came_in() -> void:
	var list: Array = []
	list.assign(store.shelves)  # (untyped: a register goes on the end)
	list.shuffle()
	stops_left = list.slice(0, STOPS)
	var busiest: Register = null
	for r: Register in store.registers:
		if busiest == null or r.line.size() > busiest.line.size():
			busiest = r
	if busiest:
		stops_left.append(busiest)


func _next() -> void:
	if leaving:
		return
	while not stops_left.is_empty():
		var next: Variant = stops_left.pop_front()
		if is_instance_valid(next) and go_to_stop(next):
			return
	leave()


func _at_stop() -> float:
	var notes: Array = Brand.INSPECTOR.notes
	var said: String = notes.pick_random()
	if is_instance_valid(stop) and stop is Shelf and (stop as Shelf).stock <= 0:
		said = "Empty shelf..."
	elif store.spills.keys().any(func(c): return Iso.chebyshev(c, current_cell()) <= 2):
		said = "Is that... blood?"
	Game.show_popup(position + Vector2(0, -52), said, Color(0.9, 0.88, 0.78))
	return LOOK_SECONDS


func _leaving() -> void:
	if came_in and not graded:
		graded = true
		store.events.grade()


func _draw() -> void:
	if is_inside() and not leaving:  # a "?" over their head, so you know who it is
		draw_string(ThemeDB.fallback_font, Vector2(-4, -44 + sprite.position.y), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.85, 0.4))
