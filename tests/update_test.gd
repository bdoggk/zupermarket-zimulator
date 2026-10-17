extends Node
# The updater (scripts/updater.gd), against a stand-in for GitHub
# (tests/update_server.py on a local port): a newer version downloads,
# gets checked and replaces the game file; a damaged, short or missing
# download leaves the game alone; the same version, no internet and Android
# do what they should; and the main menu, Options and the HUD show it.
#   godot --headless --path . res://tests/update_test.tscn

const PORT := 47391
const NEW_NAME := "ZupermarketZimulator-windows.exe"

var fails := 0
var dir := ""  # a scratch folder for the "game" and the "server"
var exe := ""
var server_pid := -1
var new_bytes := PackedByteArray()
var new_hash := ""


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	_versions()
	_setup()
	await _until_real(func(): return _server_up(), 10.0)
	await _good_update()
	await _bad_downloads()
	await _no_update()
	await _android_and_elsewhere()
	await _screens()
	OS.kill(server_pid)
	_restore_env()
	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


func _versions() -> void:
	check(Updater.is_newer("0.9.3", "0.9.2"), "0.9.3 is newer than 0.9.2")
	check(Updater.is_newer("v0.10", "0.9.9"), "0.10 is newer than 0.9.9 (numbers, not letters)")
	check(Updater.is_newer("1.0", "0.99.99"), "1.0 is newer than 0.99.99")
	check(not Updater.is_newer("0.9.2", "0.9.2"), "the same version isn't newer")
	check(not Updater.is_newer("0.9.2", "0.9.2.0"), "0.9.2 and 0.9.2.0 are the same")
	check(not Updater.is_newer("0.9.1", "0.9.2"), "an older version isn't newer")
	check(Updater.is_newer("0.9.3-beta", "0.9.2"), "a tag with a word after it still compares")
	check(Updater.first_line("\n**Zupermarket Zimulator 0.9.3: it updates itself.**\n\n## Downloads") \
		== "Zupermarket Zimulator 0.9.3: it updates itself.", "the headline is the notes' first line, without the stars")
	check(Updater.find_asset([{"name": "a.apk"}, {"name": NEW_NAME, "size": 3}], NEW_NAME).get("size") == 3, "finds the Windows file in a release")
	check(Updater.find_asset(null, NEW_NAME).is_empty(), "a release without files is fine")
	check(Updater.state == Updater.State.OFF, "it's off when running in the editor (no checks from tests or the editor)")


func _setup() -> void:
	dir = ProjectSettings.globalize_path("user://update_test")
	for sub in ["game", "www"]:
		DirAccess.make_dir_recursive_absolute(dir.path_join(sub))
		var d := DirAccess.open(dir.path_join(sub))
		for f in d.get_files():
			d.remove(f)
	exe = dir.path_join("game/ZupermarketZimulator.exe")
	_reset_game()
	# The "new version": a few MB of noise.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	new_bytes.resize(3 * 1024 * 1024 + 123)
	for i in new_bytes.size():
		new_bytes[i] = rng.randi() & 0xff
	_write(dir.path_join("www/new.exe"), new_bytes)
	new_hash = Updater.sha256_of(dir.path_join("www/new.exe"))
	server_pid = OS.create_process("python3", [ProjectSettings.globalize_path("res://tests/update_server.py"), str(PORT), dir.path_join("www")])
	check(server_pid > 0, "the stand-in release server started")
	OS.set_environment("ZZ_UPDATE_EXE", exe)
	OS.set_environment("ZZ_UPDATE_PLATFORM", "windows")
	Settings.auto_update = true


func _restore_env() -> void:
	for k in ["ZZ_UPDATE_EXE", "ZZ_UPDATE_PLATFORM", "ZZ_UPDATE_API"]:
		OS.unset_environment(k)


func _reset_game() -> void:
	_write(exe, "the old game".to_utf8_buffer())
	for f in DirAccess.get_files_at(exe.get_base_dir()):
		if f != exe.get_file():
			DirAccess.remove_absolute(exe.get_base_dir().path_join(f))


## A release on the stand-in server: what GitHub's "latest release" answers.
func _release(file: String, tag: String, asset := {}) -> void:
	var a := {"name": NEW_NAME, "size": new_bytes.size(), "digest": "sha256:" + new_hash,
		"browser_download_url": "http://127.0.0.1:%d/redirect/new.exe" % PORT}
	a.merge(asset, true)
	var apk := {"name": "ZupermarketZimulator-android.apk", "size": 10,
		"browser_download_url": "http://127.0.0.1:%d/files/game.apk" % PORT}
	var data := {"tag_name": tag, "body": "**Zupermarket Zimulator %s: robots in the store.**\n\nMore." % tag.trim_prefix("v"),
		"assets": [apk, a]}
	_write(dir.path_join("www/" + file), JSON.stringify(data).to_utf8_buffer())
	OS.set_environment("ZZ_UPDATE_API", "http://127.0.0.1:%d/files/%s" % [PORT, file])


## Checks for an update as if the game had just started.
func _check() -> void:
	Updater.state = Updater.State.IDLE
	Updater.latest = ""
	Updater.check()
	await _until_real(func(): return not Updater.busy(), 30.0)


func _good_update() -> void:
	_reset_game()
	_release("ok.json", "v99.0.0")
	var seen: Array[int] = []
	var track := func():
		if seen.is_empty() or seen[-1] != Updater.state:
			seen.append(Updater.state)
	Updater.changed.connect(track)
	await _check()
	Updater.changed.disconnect(track)
	check(Updater.state == Updater.State.READY, "a newer version downloads and installs (state %s, %s)" % [Updater.State.keys()[Updater.state], Updater.error])
	check(seen.has(Updater.State.CHECKING) and seen.has(Updater.State.DOWNLOADING) and seen.has(Updater.State.VERIFYING),
		"it goes checking, downloading, checking the file, installed")
	check(Updater.latest == "99.0.0", "it knows the new version's number")
	check(FileAccess.get_file_as_bytes(exe) == new_bytes, "the game file is now the new version (followed GitHub's redirect)")
	check(FileAccess.get_file_as_string(exe + ".old") == "the old game", "the old game file is kept as .old until the next start")
	check(not FileAccess.file_exists(exe + ".download"), "no half-download left behind")
	check(Updater.status_text().contains("99.0.0") and Updater.status_text().contains("next time"), "it says the new version starts next time")
	check(Updater.action_text() == "Restart now", "and offers Restart now")
	check(Updater.headline == "Zupermarket Zimulator 99.0.0: robots in the store.", "with the release's headline")
	Updater.check()
	check(Updater.state == Updater.State.READY, "it doesn't check again once an update is waiting")
	Updater.clean_up()
	check(not FileAccess.file_exists(exe + ".old"), "the next start deletes the old file")
	check(FileAccess.get_file_as_bytes(exe) == new_bytes, "and leaves the new one alone")

	# A second update while an .old one couldn't be deleted yet.
	_write(exe + ".old", "still running".to_utf8_buffer())
	_write(exe, "the old game".to_utf8_buffer())
	await _check()
	check(Updater.state == Updater.State.READY and FileAccess.get_file_as_bytes(exe) == new_bytes, "updating again with an .old file already there works too")


func _bad_downloads() -> void:
	_reset_game()
	_release("bad.json", "v99.0.0", {"digest": "sha256:" + "0".repeat(64)})
	await _check()
	check(Updater.state == Updater.State.FAILED and Updater.error.contains("damaged"), "a download that doesn't match GitHub's checksum is refused")
	check(FileAccess.get_file_as_string(exe) == "the old game", "and the game file isn't touched")
	check(not FileAccess.file_exists(exe + ".download") and not FileAccess.file_exists(exe + ".old"), "and nothing is left behind")
	check(Updater.action_text() == "Try again", "the menu offers Try again")

	_release("short.json", "v99.0.0", {"size": new_bytes.size() + 1})
	await _check()
	check(Updater.state == Updater.State.FAILED and Updater.error.contains("cut short"), "a download that's the wrong size is refused")
	check(FileAccess.get_file_as_string(exe) == "the old game", "and the game file isn't touched")

	_release("gone.json", "v99.0.0", {"browser_download_url": "http://127.0.0.1:%d/files/missing.exe" % PORT})
	await _check()
	check(Updater.state == Updater.State.FAILED and Updater.error.contains("404"), "a download that isn't there fails (%s)" % Updater.error)
	check(FileAccess.get_file_as_string(exe) == "the old game" and not FileAccess.file_exists(exe + ".download"), "and leaves the game alone")

	_reset_game()
	_release("bad.json", "v99.0.0", {"digest": "sha256:" + "0".repeat(64)})
	await _check()
	Updater.do_action()  # Try again
	check(Updater.state == Updater.State.DOWNLOADING, "Try again downloads again")
	await _until_real(func(): return not Updater.busy(), 30.0)
	check(Updater.state == Updater.State.FAILED, "(from the same release, which is still damaged)")


func _no_update() -> void:
	_reset_game()
	_release("same.json", "v" + Updater.version())
	await _check()
	check(Updater.state == Updater.State.UP_TO_DATE, "the same version: up to date")
	check(Updater.status_text() == "" and Updater.version_text().contains("up to date"), "the menu just says up to date in the corner")
	check(FileAccess.get_file_as_string(exe) == "the old game", "nothing downloaded")

	_release("older.json", "v0.1")
	await _check()
	check(Updater.state == Updater.State.UP_TO_DATE, "an older release isn't offered")

	OS.set_environment("ZZ_UPDATE_API", "http://127.0.0.1:1/nothing")
	await _check()
	check(Updater.state == Updater.State.CHECK_FAILED, "no internet: the check fails")
	check(Updater.status_text() == "", "quietly (nothing on the menu)")

	Updater._last_check = -1.0e9
	Settings.auto_update = false
	Updater.check_again_if_failed()
	check(Updater.state == Updater.State.CHECK_FAILED, "with Automatic updates off, the menu doesn't check")
	Settings.auto_update = true
	_release("same.json", "v" + Updater.version())
	Updater.check_again_if_failed()
	await _until_real(func(): return not Updater.busy(), 30.0)
	check(Updater.state == Updater.State.UP_TO_DATE, "turned on, the menu checks again after a failed check")
	Updater.check_again_if_failed()
	check(not Updater.busy(), "but not again right after a good one")

	OS.set_environment("ZZ_UPDATE_API", "http://127.0.0.1:%d/files/nope.json" % PORT)
	await _check()
	check(Updater.state == Updater.State.CHECK_FAILED, "a missing release page also fails quietly")


func _android_and_elsewhere() -> void:
	_reset_game()
	OS.set_environment("ZZ_UPDATE_PLATFORM", "android")
	_release("ok.json", "v99.0.0")
	await _check()
	check(Updater.state == Updater.State.AVAILABLE, "Android: a newer version is offered, not installed")
	check(Updater.download_url.ends_with("/files/game.apk"), "with the APK's download link")
	check(Updater.action_text() == "Download" and Updater.status_text().contains("saves stay"), "Download, and your saves stay")
	check(FileAccess.get_file_as_string(exe) == "the old game", "nothing replaced on Android")
	OS.set_environment("ZZ_UPDATE_PLATFORM", "windows")

	OS.set_environment("ZZ_UPDATE_EXE", dir.path_join("nowhere/ZupermarketZimulator.exe"))
	await _check()
	check(Updater.state == Updater.State.AVAILABLE and Updater.action_text() == "Download",
		"Windows, but the game's folder can't be written to: it offers the download instead")
	OS.set_environment("ZZ_UPDATE_EXE", exe)

	OS.set_environment("ZZ_UPDATE_EXE", "C:\\Program Files\\WindowsApps\\Zupermarket_0.9.3.0_x64__abc\\ZupermarketZimulator.exe")
	check(Updater.from_store() and not Updater.works_here(), "the Microsoft Store version never updates itself (the Store does)")
	OS.set_environment("ZZ_UPDATE_EXE", "C:/Users/me/Downloads/ZupermarketZimulator.exe")
	check(not Updater.from_store(), "a downloaded .exe isn't the Store version")
	OS.set_environment("ZZ_UPDATE_EXE", exe)

	_release("noexe.json", "v99.0.0", {"name": "something-else.zip"})
	await _check()
	check(Updater.state == Updater.State.AVAILABLE and Updater.download_url == Updater.RELEASES_PAGE,
		"a release without a Windows file links to the release page")


func _screens() -> void:
	# The main menu's update card.
	_reset_game()
	_release("ok.json", "v99.0.0")
	Updater.state = Updater.State.IDLE
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await _frames(3)
	check(not menu.update_panel.visible, "no update card before there's news")
	var shown: Array[String] = []  # what the card said at each step (the menu hears about it first)
	var bars: Array[bool] = []
	var watch := func():
		shown.append(menu.update_label.text if menu.update_panel.visible else "")
		bars.append(menu.update_bar.visible)
	Updater.changed.connect(watch)
	Updater.check()
	await _until_real(func(): return not Updater.busy(), 30.0)
	Updater.changed.disconnect(watch)
	await _frames(2)
	var at := shown.find_custom(func(t): return t.begins_with("Downloading version 99.0.0"))
	check(at >= 0, "the menu shows the download (%s)" % ", ".join(shown))
	check(at >= 0 and bars[at], "with a progress bar")
	check(menu.update_panel.visible and menu.update_button.visible and menu.update_button.text == "Restart now", "then Restart now")
	check(menu.update_headline.text.contains("robots"), "and what's new")
	check(not menu.update_bar.visible, "and the bar goes away")
	var r: Rect2 = menu.update_panel.get_global_rect()
	var m: Rect2 = menu.main_panel.get_global_rect()
	check(not r.intersects(m), "the card sits beside the menu, not on it")
	check(r.end.x <= menu.root.size.x + 1.0 and r.position.y >= 0.0, "and on the screen")
	menu.show_screen(menu.Screen.OPTIONS)
	await _frames(2)
	check(not menu.update_panel.visible, "it's hidden behind Options")
	var opts: Node = menu.options
	check(opts.update_check != null and opts.update_check.button_pressed, "Options has Automatic updates, on")
	check(opts.update_note.text.contains("by themselves"), "and says what it does")
	opts.update_check.button_pressed = false
	check(not Settings.auto_update, "switching it off turns updates off")
	check(opts.update_note.text.begins_with("Off"), "and says so")
	opts.update_check.button_pressed = true
	await _frames(1)
	check(Settings.auto_update, "and back on")
	menu.show_screen(menu.Screen.MAIN)
	await _frames(2)
	check(menu.update_panel.visible, "the card's back on the main screen")
	menu.queue_free()
	await _frames(2)

	# In a game: a message when it's ready.
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var hud: Node = main.get_node("HUD")
	Updater.state = Updater.State.READY
	Updater.changed.emit()
	await _frames(1)
	var said: bool = hud.message_box.get_children().any(func(l): return l is Label and l.text.contains("downloaded"))
	check(said, "while playing, a message says the update is downloaded")
	main.queue_free()
	await _frames(2)
	Updater.state = Updater.State.OFF


func _server_up() -> bool:
	var tcp := StreamPeerTCP.new()
	if tcp.connect_to_host("127.0.0.1", PORT) != OK:
		return false
	tcp.poll()
	OS.delay_msec(50)
	tcp.poll()
	var up := tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED
	tcp.disconnect_from_host()
	return up


func _write(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func _until_real(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
