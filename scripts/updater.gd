extends Node
## Keeps the game up to date. Registered as the "Updater" autoload.
##
## A couple of seconds after the game starts, it asks GitHub for the latest
## release. If that's a newer version:
##   Windows  it downloads the new ZupermarketZimulator-windows.exe into the
##            folder the game is in, checks it's all there (the size and
##            SHA-256 GitHub lists for it), renames the running .exe to
##            <name>.exe.old and puts the new one in its place. The game you
##            have open keeps running; the next start (or Restart now on the
##            main menu) is the new version, with the same saves. A file the
##            game downloads itself has no "came from the internet" mark, so
##            Windows doesn't show its security warning for it.
##   Android  the main menu says a new version is out, and Download opens the
##            APK in the browser (Android has to do the installing).
## Options > Automatic updates turns it off. It never runs in the Godot
## editor or in the Microsoft Store version (the Store does the updating
## there), and a failed check (no internet) stays quiet.
##
## Tests (tests/update_test.gd) point it elsewhere with environment variables:
##   ZZ_UPDATE_API       the "latest release" address to ask
##   ZZ_UPDATE_EXE       the file to replace instead of the running game
##   ZZ_UPDATE_PLATFORM  windows, android or linux (a Linux build of the game)
##   ZZ_UPDATE_CHECK=1   check even outside an exported game

signal changed

const REPO := "bdoggk/zupermarket-zimulator"
const API := "https://api.github.com/repos/" + REPO + "/releases/latest"
const RELEASES_PAGE := "https://github.com/" + REPO + "/releases/latest"
## The release file for each platform. Windows and Linux replace themselves.
const ASSETS := {
	"windows": "ZupermarketZimulator-windows.exe",
	"android": "ZupermarketZimulator-android.apk",
	"linux": "ZupermarketZimulator-linux.x86_64",
}
const SELF_REPLACING := ["windows", "linux"]
const CHECK_DELAY := 2.0  # seconds after starting
const CHECK_TIMEOUT := 20.0
const RECHECK_SECONDS := 300.0  # after a failed check, the main menu tries again this often at most
const STALL_SECONDS := 60.0  # a download that gets nothing for this long is given up
const RENAME_TRIES := 10  # antivirus can hold a new file for a moment
const PART := ".download"  # the new .exe while it downloads
const OLD := ".old"  # the replaced .exe, deleted at the next start

enum State { OFF, IDLE, CHECKING, UP_TO_DATE, CHECK_FAILED, AVAILABLE, DOWNLOADING, VERIFYING, READY, FAILED }

var state := State.IDLE
var latest := ""  # the newest version, like "0.9.4"
var headline := ""  # the first line of its release notes
var download_url := ""
var error := ""  # why the last download or install didn't work
var downloaded := 0  # bytes so far
var total := 0  # bytes in all
var _asset := {}
var _http: HTTPRequest
var _hash_task := -1
var _hash := ""
var _last_bytes := 0
var _waiting_since := 0  # Time.get_ticks_msec() of the last news from the server (real time, whatever the game speed)
var _last_check := -1.0e9


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not works_here():
		state = State.OFF
		if from_store():
			print("Updater: off (Microsoft Store version)")
		return
	clean_up()
	if Settings.auto_update:
		get_tree().create_timer(CHECK_DELAY, true, false, true).timeout.connect(func():
			if state == State.IDLE:
				check())


## Exported Windows and Android games (not the editor, a test run or the
## Microsoft Store version).
func works_here() -> bool:
	if not ASSETS.has(platform()) or from_store():
		return false
	return OS.has_feature("template") or OS.get_environment("ZZ_UPDATE_CHECK") == "1"


static func platform() -> String:
	var forced := OS.get_environment("ZZ_UPDATE_PLATFORM")
	if forced != "":
		return forced
	match OS.get_name():
		"Windows":
			return "windows"
		"Android":
			return "android"
	return ""


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


func api_url() -> String:
	var forced := OS.get_environment("ZZ_UPDATE_API")
	return forced if forced != "" else API


## The game file that gets replaced.
func exe_path() -> String:
	var forced := OS.get_environment("ZZ_UPDATE_EXE")
	return forced if forced != "" else OS.get_executable_path()


## Installed from the Microsoft Store: Windows keeps Store games in
## Program Files/WindowsApps, and the Store updates them itself.
func from_store() -> bool:
	return exe_path().replace("\\", "/").to_lower().contains("/windowsapps/")


## This platform downloads and installs updates by itself.
func replaces_itself() -> bool:
	return platform() in SELF_REPLACING


## True if `a` is a newer version than `b` ("0.10" is newer than "0.9.9").
static func is_newer(a: String, b: String) -> bool:
	var x := _numbers(a)
	var y := _numbers(b)
	for i in maxi(x.size(), y.size()):
		var p: int = x[i] if i < x.size() else 0
		var q: int = y[i] if i < y.size() else 0
		if p != q:
			return p > q
	return false


static func _numbers(v: String) -> Array[int]:
	var out: Array[int] = []
	var digits := RegEx.create_from_string("^\\d+")
	for part in v.strip_edges().trim_prefix("v").trim_prefix("V").split("."):
		var m := digits.search(part)
		out.append(int(m.get_string()) if m else 0)
	return out


## The release file called `file_name`, or {}.
static func find_asset(assets: Variant, file_name: String) -> Dictionary:
	if assets is Array:
		for a: Variant in assets:
			if a is Dictionary and str(a.get("name", "")) == file_name:
				return a
	return {}


## The first line of release notes, without the markdown.
static func first_line(notes: String) -> String:
	for line in notes.split("\n"):
		var t := line.strip_edges().replace("**", "").replace("__", "").lstrip("# ").strip_edges()
		if t != "":
			return t
	return ""


func busy() -> bool:
	return state in [State.CHECKING, State.DOWNLOADING, State.VERIFYING]


## 0-1 while downloading.
func progress() -> float:
	return clampf(float(downloaded) / float(total), 0.0, 1.0) if total > 0 else 0.0


# ---------------------------------------------------------------- checking

## Asks GitHub for the latest version (and starts the download if it's newer).
func check() -> void:
	if state == State.OFF or busy() or state == State.READY:
		return
	_last_check = Time.get_ticks_msec() / 1000.0
	error = ""
	_set_state(State.CHECKING)
	_http = _new_request()
	_waiting_since = Time.get_ticks_msec()
	_http.request_completed.connect(_on_checked, CONNECT_ONE_SHOT)
	if _http.request(api_url(), _headers(["Accept: application/vnd.github+json"])) != OK:
		_drop_request()
		_set_state(State.CHECK_FAILED)


## The main menu calls this: checks again if the last check failed a while ago.
func check_again_if_failed() -> void:
	if Settings.auto_update and state == State.CHECK_FAILED \
			and Time.get_ticks_msec() / 1000.0 - _last_check >= RECHECK_SECONDS:
		check()


func _on_checked(result: int, code: int, _headers_in: PackedStringArray, body: PackedByteArray) -> void:
	_drop_request()
	var data: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
	if not data is Dictionary or str(data.get("tag_name", "")) == "":
		print("Updater: couldn't check for updates (result %d, HTTP %d)" % [result, code])
		_set_state(State.CHECK_FAILED)
		return
	latest = str(data.tag_name).trim_prefix("v")
	headline = first_line(str(data.get("body", "")))
	if not is_newer(latest, version()):
		print("Updater: %s is the latest version" % version())
		_set_state(State.UP_TO_DATE)
		return
	_asset = find_asset(data.get("assets"), ASSETS[platform()])
	download_url = str(_asset.get("browser_download_url", RELEASES_PAGE))
	print("Updater: version %s is out" % latest)
	if replaces_itself() and not _asset.is_empty() and can_replace():
		download()
	else:
		_set_state(State.AVAILABLE)


# ---------------------------------------------------------------- downloading

## The game's folder can be written to (not, say, Program Files).
func can_replace() -> bool:
	var exe := exe_path()
	if not FileAccess.file_exists(exe):
		return false
	var probe := exe.get_base_dir().path_join(".zz_update_test")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(probe)
	return true


func download() -> void:
	if _asset.is_empty() or state in [State.DOWNLOADING, State.VERIFYING]:
		return
	error = ""
	var part := exe_path() + PART
	DirAccess.remove_absolute(part)
	downloaded = 0
	total = int(_asset.get("size", 0))
	_last_bytes = 0
	_waiting_since = Time.get_ticks_msec()
	_http = _new_request()
	_http.download_file = part
	_http.download_chunk_size = 1 << 18
	_http.request_completed.connect(_on_downloaded, CONNECT_ONE_SHOT)
	_set_state(State.DOWNLOADING)
	print("Updater: downloading %s" % download_url)
	if _http.request(download_url, _headers()) != OK:
		_drop_request()
		_fail("couldn't start the download")


func _process(_delta: float) -> void:
	var waited := (Time.get_ticks_msec() - _waiting_since) / 1000.0
	if state == State.CHECKING and _http and waited >= CHECK_TIMEOUT:
		_http.cancel_request()
		_drop_request()
		print("Updater: GitHub didn't answer")
		_set_state(State.CHECK_FAILED)
	elif state == State.DOWNLOADING and _http:
		downloaded = _http.get_downloaded_bytes()
		if total <= 0:
			total = maxi(0, _http.get_body_size())
		if downloaded != _last_bytes:
			_last_bytes = downloaded
			_waiting_since = Time.get_ticks_msec()
			changed.emit()
		elif waited >= STALL_SECONDS:
			_http.cancel_request()
			_drop_request()
			DirAccess.remove_absolute(exe_path() + PART)
			_fail("the download stopped")
	elif state == State.VERIFYING and _hash_task >= 0 and WorkerThreadPool.is_task_completed(_hash_task):
		WorkerThreadPool.wait_for_task_completion(_hash_task)
		_hash_task = -1
		_after_hash()


func _on_downloaded(result: int, code: int, _headers_in: PackedStringArray, _body: PackedByteArray) -> void:
	if state != State.DOWNLOADING:
		return
	_drop_request()
	var part := exe_path() + PART
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(part)
		_fail("the download didn't finish (%s)" % (("HTTP %d" % code) if result == HTTPRequest.RESULT_SUCCESS else "error %d" % result))
		return
	downloaded = file_size(part)
	if total > 0 and downloaded != total:
		DirAccess.remove_absolute(part)
		_fail("the download was cut short")
		return
	_set_state(State.VERIFYING)
	_hash = ""
	_hash_task = WorkerThreadPool.add_task(func(): _hash = sha256_of(part), false, "Checking the update")


func _after_hash() -> void:
	var part := exe_path() + PART
	var want := str(_asset.get("digest", "")).trim_prefix("sha256:").to_lower()
	if want != "" and _hash != want:
		DirAccess.remove_absolute(part)
		_fail("the download was damaged")
		return
	_install(part)


static func sha256_of(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	while f.get_position() < f.get_length():
		ctx.update(f.get_buffer(1 << 20))
	return ctx.finish().hex_encode()


static func file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f else -1


# ---------------------------------------------------------------- installing

## Swaps the new file in: this .exe becomes <name>.old (a running program can
## be renamed, just not overwritten) and the download takes its name.
func _install(part: String) -> void:
	var exe := exe_path()
	var old := exe + OLD
	if FileAccess.file_exists(old) and DirAccess.remove_absolute(old) != OK:
		old = exe + OLD + str(Time.get_unix_time_from_system())  # the last one is still in use
	var moved: Error = await _rename(exe, old)
	if moved != OK:
		DirAccess.remove_absolute(part)
		_fail("couldn't replace the game file")
		return
	moved = await _rename(part, exe)
	if moved != OK:
		DirAccess.rename_absolute(old, exe)  # put it back
		DirAccess.remove_absolute(part)
		_fail("couldn't replace the game file")
		return
	if platform() != "windows":
		FileAccess.set_unix_permissions(exe, FileAccess.get_unix_permissions(old))
	print("Updater: version %s is installed" % latest)
	_set_state(State.READY)


func _rename(from: String, to: String) -> Error:
	var err := FAILED
	for i in RENAME_TRIES:
		err = DirAccess.rename_absolute(from, to)
		if err == OK:
			return OK
		await get_tree().create_timer(0.5, true, false, true).timeout
	return err


## Starts the new version and closes this one (from the main menu, so
## there's nothing unsaved).
func restart() -> void:
	if state != State.READY:
		return
	OS.create_process(exe_path(), OS.get_cmdline_args())
	get_tree().quit()


## Deletes what an earlier update left behind (the old .exe, a half download).
func clean_up() -> void:
	var exe := exe_path()
	if exe == "":
		return
	var left := false
	DirAccess.remove_absolute(exe + PART)
	var dir := DirAccess.open(exe.get_base_dir())
	if dir:
		for f in dir.get_files():
			if f.begins_with(exe.get_file() + OLD):
				left = DirAccess.remove_absolute(exe.get_base_dir().path_join(f)) != OK or left
	if left:  # the old game is still closing: try again in a bit
		get_tree().create_timer(15.0, true, false, true).timeout.connect(clean_up, CONNECT_ONE_SHOT)


func open_download_page() -> void:
	OS.shell_open(download_url if download_url != "" else RELEASES_PAGE)


func _fail(why: String) -> void:
	error = why
	print("Updater: %s" % why)
	_set_state(State.FAILED)


# ---------------------------------------------------------------- what the menu shows

## A line for the main menu ("" when there's nothing to say).
func status_text() -> String:
	match state:
		State.DOWNLOADING:
			return "Downloading version %s... %d%%" % [latest, roundi(progress() * 100.0)]
		State.VERIFYING:
			return "Checking version %s..." % latest
		State.READY:
			return "Version %s is installed. It starts the next time you open the game." % latest
		State.AVAILABLE:
			if platform() == "android":
				return "Version %s is out! Download it and Android installs it over this one. Your saves stay." % latest
			return "Version %s is out!" % latest
		State.FAILED:
			return "Couldn't update to version %s: %s." % [latest, error]
	return ""


## The banner's button ("" for none).
func action_text() -> String:
	match state:
		State.READY:
			return "Restart now"
		State.AVAILABLE:
			return "Download"
		State.FAILED:
			return "Try again" if replaces_itself() and can_replace() else "Download"
	return ""


func do_action() -> void:
	match state:
		State.READY:
			restart()
		State.AVAILABLE:
			open_download_page()
		State.FAILED:
			if replaces_itself() and not _asset.is_empty() and can_replace():
				download()
			else:
				open_download_page()


## The little version line in the menu's corner.
func version_text() -> String:
	var v := "v" + version()
	match state:
		State.CHECKING:
			return v + "  (checking for updates)"
		State.UP_TO_DATE:
			return v + "  (up to date)"
	return v


# ---------------------------------------------------------------- helpers

func _set_state(s: State) -> void:
	state = s
	changed.emit()


func _new_request() -> HTTPRequest:
	var r := HTTPRequest.new()
	r.use_threads = true
	r.max_redirects = 8
	add_child(r)
	return r


func _drop_request() -> void:
	if _http:
		_http.queue_free()
		_http = null


func _headers(extra: Array = []) -> PackedStringArray:
	var h := PackedStringArray(["User-Agent: ZupermarketZimulator/" + version()])
	h.append_array(PackedStringArray(extra))
	return h
