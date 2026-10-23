extends Node
## Save slots. Registered as the "Saves" autoload.
##
## There are 3 slots. Each one is a JSON file in user://saves/:
##   Windows:  %APPDATA%\Godot\app_userdata\Supermarket Sim\saves
##   Android:  the app's private storage
##
## The game saves automatically when you start a new game, every morning,
## when you save or quit from the pause menu, and when the window is closed
## or the app goes to the background on a phone. Customers who are in the
## store at the time aren't saved (they just leave).

signal saved(slot: int)

const SLOTS := 3
const DIR := "user://saves"
const VERSION := 1
const GAME_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"

## Store layout from the save being loaded. Store._ready() uses it once.
var pending_store := {}
## The save was made between days: start the next day when it loads.
var pending_next_day := false
## A message for the HUD to show once the store is up (after starting over).
var pending_notice := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(DIR)
	get_tree().set_auto_accept_quit(false)  # so closing the window saves first
	Game.day_started.connect(func(_day: int): save_game.call_deferred())


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:  # window closed (PC)
			save_game()
			get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED:  # app sent to the background (phone)
			save_game()


# ---------------------------------------------------------------- slots

func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [DIR, slot + 1]


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot) + ".tmp")


## The save file's contents. {} if the slot is empty, {"damaged": true} if
## the file can't be read.
func read_slot(slot: int) -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		path += ".tmp"  # the game was closed in the middle of saving
		if not FileAccess.file_exists(path):
			return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"damaged": true}
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("game")) != TYPE_DICTIONARY:
		return {"damaged": true}
	return data


## A summary for the slot list: day, money, level, saved_at, play_time.
## {} if the slot is empty.
func slot_info(slot: int) -> Dictionary:
	var d := read_slot(slot)
	if d.is_empty() or d.has("damaged"):
		return d
	var g: Dictionary = d.game
	return {
		"day": int(g.get("day", 1)),
		"money": float(g.get("money", 0.0)),
		"level": Game.level_for(float(g.get("xp", 0.0))),
		"saved_at": float(d.get("saved_at", 0.0)),
		"play_time": float(g.get("play_time", 0.0)),
	}


## The slot that was played most recently, or -1 if there are no saves.
func latest_slot() -> int:
	var best := -1
	var best_time := -1.0
	for i in SLOTS:
		var info := slot_info(i)
		if info.is_empty() or info.has("damaged"):
			continue
		if info.saved_at > best_time:
			best_time = info.saved_at
			best = i
	return best


func delete_slot(slot: int) -> void:
	for path in [slot_path(slot), slot_path(slot) + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


# ---------------------------------------------------------------- playing

## Starts a new game in `slot` (anything already there is replaced).
func new_game(slot: int) -> void:
	delete_slot(slot)
	Game.reset()
	Game.slot = slot
	pending_store = {}
	pending_next_day = false
	_go(GAME_SCENE)


## The lender took your head: this slot starts over from day 1 (the old
## save is gone). The first-day tips you've already seen stay seen.
func start_over() -> void:
	var tips := Game.tutorial.duplicate()
	var tips_hidden := Game.tutorial_hidden
	if Game.slot >= 0:
		new_game(Game.slot)
	else:  # (not saving: tests)
		Game.reset()
		pending_store = {}
		pending_next_day = false
		_go(GAME_SCENE)
	Game.tutorial = tips
	Game.tutorial_hidden = tips_hidden
	pending_notice = Brand.LOAN.start_over


func load_game(slot: int) -> bool:
	var d := read_slot(slot)
	if d.is_empty() or d.has("damaged"):
		return false
	Game.reset()
	Game.from_dict(d.game)
	Game.slot = slot
	pending_store = d.get("store", {})
	pending_next_day = bool(d.game.get("between_days", false))
	_go(GAME_SCENE)
	return true


## Loads the most recently played save.
func continue_game() -> bool:
	var s := latest_slot()
	return s >= 0 and load_game(s)


## Saves the game being played into its slot. Returns false if there's
## nothing to save (e.g. on the main menu).
func save_game() -> bool:
	if Game.slot < 0 or not Game.in_game():
		return false
	var data := {
		"version": VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game": Game.to_dict(),
		"store": Game.store.to_dict(),
	}
	# Write to a temporary file first so a crash can't wreck the old save.
	var path := slot_path(Game.slot)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Couldn't save: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tmp, path)
	saved.emit(Game.slot)
	return true


func quit_to_menu() -> void:
	save_game()
	_go(MENU_SCENE)  # the menu resets the game state when it opens


func quit_game() -> void:
	save_game()
	get_tree().quit()


func _go(scene: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(scene)


# ---------------------------------------------------------------- display

## "Oct 14, 10:32 AM" in the player's time zone.
static func format_date(unix: float) -> String:
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var t := Time.get_datetime_dict_from_unix_time(int(unix) + bias * 60)
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var h: int = t.hour % 12
	return "%s %d, %d:%02d %s" % [months[t.month - 1], t.day, 12 if h == 0 else h, t.minute, "AM" if t.hour < 12 else "PM"]


## "1h 23m" or "12m".
static func format_play_time(seconds: float) -> String:
	var m := int(seconds / 60.0)
	return "%dh %02dm" % [int(m / 60.0), m % 60] if m >= 60 else "%dm" % m
