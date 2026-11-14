extends Node
## Keeps installed copies up to date from GitHub releases.
##
## An install is two files side by side: the engine (ShelfLife.exe or
## ShelfLife.x86_64) and the game itself (ShelfLife.pck). Every release has a
## manifest.json that lists both for each platform, with sizes and SHA-256
## sums. When only the game changed, the updater fetches the new .pck (a few
## MB); when the engine changed too, it fetches the platform zip and replaces
## both. Nothing is swapped until it checks out, replaced files are kept as
## *.old until the next launch, and the game then restarts on the new
## version. Saves and settings live in the user folder, so they carry over.
##
## On Android the game is one APK. The updater downloads the new APK (for
## this phone's processor), checks its SHA-256 sum, and hands it to Android's
## own installer, which asks before it replaces anything. The APKs are signed
## with the same key, so the update keeps the saves and settings.
##
## The repository is public: no account or token is involved. The only
## requests go to github.com (and the storage it redirects to), carrying a
## "ShelfLife/<version>" user agent and nothing else.
##
## Test hooks (after --, parsed by boot.gd):
##   --update-url <manifest url>  check there instead (plain http only on 127.0.0.1)
##   --update-now                 check, install and restart with no title screen
##   --update-full                always take the whole zip
##   --update-log <file>          append each step to a file

signal changed

const Version = preload("res://scripts/core/version.gd")
const LATEST_MANIFEST := "https://github.com/GPTmadeit/shelflife/releases/latest/download/manifest.json"
const RELEASE_FILE := "https://github.com/GPTmadeit/shelflife/releases/download/v%s/%s"
const RELEASES := "https://github.com/GPTmadeit/shelflife/releases"
const MARKER := "user://updated.json"
const STALL_SECS := 30.0

enum { OFF, IDLE, CHECKING, LATEST, AVAILABLE, DOWNLOADING, INSTALLING, RESTARTING, FAILED }
const STATE_NAMES := ["OFF", "IDLE", "CHECKING", "LATEST", "AVAILABLE", "DOWNLOADING", "INSTALLING", "RESTARTING", "FAILED"]

var state := IDLE
var message := ""            ## one line for the title screen
var latest := ""             ## the newest released version
var full := false            ## the engine changes too, so the whole zip is fetched
var download_bytes := 0
var progress := 0.0          ## 0..1 while downloading
var install_failed := false  ## the failure came from installing, not from checking
var updated_from := ""       ## set on the first launch after an update

var _exe := ""               ## captured at startup: on Linux /proc/self/exe dangles once replaced
var _pck := ""
var _plat := ""
var _android := false        ## an APK install: updates go through Android's installer
var _handed_off := false     ## Android's installer has the new APK
var _entry := {}
var _source := ""
var _http: HTTPRequest
var _checked := false
var _cancelled := false
var _stalled := false
var _olds := {}
var _seen_bytes := 0
var _seen_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.max_redirects = 0   # followed by hand in _fetch, so every hop stays on https
	add_child(_http)
	if OS.has_feature("template") and OS.has_feature("android"):
		_android = true
		_plat = "android-" + Engine.get_architecture_name()   # android-arm64, android-x86_64
		_cleanup()
		_read_marker()
		return
	if OS.has_feature("template") and (OS.has_feature("linux") or OS.has_feature("windows")):
		_exe = OS.get_executable_path()
		_pck = _find_pck()
		_plat = "windows" if OS.has_feature("windows") else "linux"
	if _pck == "":
		state = OFF   # running from source, or not the engine + ShelfLife.pck layout
		return
	_cleanup()
	_read_marker()


## Exported Linux, Windows and Android builds can update themselves.
func supported() -> bool:
	return state != OFF


## The title screen calls this: one quiet check per session, if allowed.
func auto_check() -> void:
	if _checked or state == OFF or not bool(Game.settings.get("updates", true)):
		return
	if not Game.dev.is_empty() and not Game.dev.has("update-url"):
		return   # test runs stay offline
	check()


func check() -> void:
	if state in [OFF, CHECKING, DOWNLOADING, INSTALLING, RESTARTING]:
		return
	_checked = true
	install_failed = false
	_go(CHECKING, "Checking for updates…")
	_source = str(Game.dev.get("update-url", LATEST_MANIFEST))
	var res: Dictionary = await _fetch(_source)
	if res.code == 404:
		_go(LATEST, "")   # nothing released yet
		return
	if res.code != 200:
		_go(FAILED, "Couldn't check for updates (%s)." % _why(res))
		return
	var m: Variant = JSON.parse_string((res.body as PackedByteArray).get_string_from_utf8())
	if not (m is Dictionary) or not (m.get("platforms") is Dictionary):
		_go(FAILED, "The update info on GitHub couldn't be read.")
		return
	latest = str(m.get("version", ""))
	if not newer(latest, Version.VERSION):
		_go(LATEST, "Up to date.")
		return
	var e: Variant = (m.get("platforms") as Dictionary).get(_plat)
	if not _valid(e):
		_go(FAILED, "Version %s is out, but not for this system yet." % latest)
		return
	_entry = e
	if _android:
		full = true
		download_bytes = int(_entry.apk.size)
		_go(AVAILABLE, "Version %s is out (%s download)." % [latest, _mb(download_bytes)])
		return
	var mine: String = await _in_thread(_sha256_file.bind(_exe))
	full = Game.dev.has("update-full") or mine != str(_entry.exe.sha256)
	download_bytes = int(_entry.zip.size) if full else int(_entry.pck.size)
	_go(AVAILABLE, "Version %s is out (%s download)." % [latest, _mb(download_bytes)])


func install() -> void:
	if state != AVAILABLE:
		return
	_cancelled = false
	_stalled = false
	install_failed = false
	if _android:
		await _install_apk()
		return
	if not _writable(_exe.get_base_dir()):
		_fail("The game can't write to its own folder, so it can't update itself there. Get the new version from the release page.")
		return
	var spec: Dictionary = _entry.zip if full else _entry.pck
	var part := (_exe + ".zip.part") if full else (_pck + ".part")
	_log("install " + ("zip" if full else "pck"))
	progress = 0.0
	_seen_bytes = 0
	_seen_t = _now()
	_go(DOWNLOADING, "Downloading version %s…" % latest)
	set_process(true)
	var res: Dictionary = await _fetch(_file_url(str(spec.file)), part)
	set_process(false)
	if _cancelled:
		DirAccess.remove_absolute(part)
		_go(AVAILABLE, "Update cancelled. Version %s is out (%s download)." % [latest, _mb(download_bytes)])
		return
	if res.code != 200:
		DirAccess.remove_absolute(part)
		_fail("The download stalled. Try again." if _stalled else "The download failed (%s)." % _why(res))
		return
	progress = 1.0
	_go(INSTALLING, "Checking the download…")
	var sum: String = await _in_thread(_sha256_file.bind(part))
	if sum != str(spec.sha256):
		DirAccess.remove_absolute(part)
		_fail("The download was damaged on the way. Try again.")
		return
	_go(INSTALLING, "Installing…")
	var err := OK
	if full:
		err = await _install_zip(part)
	else:
		err = _swap(part, _pck)
	if err != OK:
		DirAccess.remove_absolute(part)
		_fail("Couldn't replace the game files (%s). Get the new version from the release page." % error_string(err))
		return
	var f := FileAccess.open(MARKER, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"from": Version.VERSION, "to": latest}))
		f.close()
	_go(RESTARTING, "Updated to version %s. Restarting…" % latest)
	await get_tree().create_timer(0.7).timeout
	restart()


## Android: fetch the APK into the game's own files (once), check it, and
## open Android's installer on it. If the player backs out of the installer,
## the button stays, and opens it again without downloading again.
func _install_apk() -> void:
	var spec: Dictionary = _entry.apk
	var dir := OS.get_user_data_dir().path_join("update")
	DirAccess.make_dir_recursive_absolute(dir)
	# named for the version: Android's installer brings back a window it left
	# open for the very same file (an earlier update's "App installed") instead
	# of installing this one
	var apk := dir.path_join("ShelfLife-%s-%s.apk" % [latest, _plat])
	var have: String = await _in_thread(_sha256_file.bind(apk)) if FileAccess.file_exists(apk) else ""
	if have != str(spec.sha256):
		var part := apk + ".part"
		_log("install apk")
		progress = 0.0
		_seen_bytes = 0
		_seen_t = _now()
		_go(DOWNLOADING, "Downloading version %s…" % latest)
		set_process(true)
		var res: Dictionary = await _fetch(_file_url(str(spec.file)), part)
		set_process(false)
		if _cancelled:
			DirAccess.remove_absolute(part)
			_go(AVAILABLE, "Update cancelled. Version %s is out (%s download)." % [latest, _mb(download_bytes)])
			return
		if res.code != 200:
			DirAccess.remove_absolute(part)
			_fail("The download stalled. Try again." if _stalled else "The download failed (%s)." % _why(res))
			return
		progress = 1.0
		_go(INSTALLING, "Checking the download…")
		var sum: String = await _in_thread(_sha256_file.bind(part))
		if sum != str(spec.sha256):
			DirAccess.remove_absolute(part)
			_fail("The download was damaged on the way. Try again.")
			return
		DirAccess.remove_absolute(apk)
		if DirAccess.rename_absolute(part, apk) != OK:
			DirAccess.remove_absolute(part)
			_fail("Couldn't save the update. Try again.")
			return
	var f := FileAccess.open(MARKER, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"from": Version.VERSION, "to": latest}))
		f.close()
	_log("open installer")
	var err := OS.shell_open(apk)
	if err != OK:
		_fail("Android wouldn't open its installer (%s). Get the new version from the release page." % error_string(err))
		return
	_handed_off = true
	# The first time, Android asks to allow installs from Shelf Life, and after
	# that it may drop back here instead of carrying on: pressing Update again
	# reopens the installer on the same download.
	_go(AVAILABLE, "Android's installer takes it from here. If it asked you to allow installs from Shelf Life, allow it, then press Update again.")


func cancel() -> void:
	if state == DOWNLOADING:
		_cancelled = true
		_abort()


## Starts the (new) game again with the same arguments and closes this one.
func restart() -> void:
	var args := OS.get_cmdline_args()   # the engine's own options aren't in here
	if DisplayServer.get_name() == "headless":
		args.insert(0, "--headless")
	var user := OS.get_cmdline_user_args()
	if not user.is_empty():
		args.append("--")
		args.append_array(user)
	_log("restart")
	if OS.create_process(_exe, args) <= 0:
		_fail("Updated to version %s, but the game couldn't restart itself. Start it again." % latest)
		return
	get_tree().quit()


func open_page() -> void:
	OS.shell_open(RELEASES + ("/tag/v" + latest if latest != "" else ""))


func open_notes() -> void:
	OS.shell_open(RELEASES + "/tag/v" + Version.VERSION)


## --update-now: the whole update with no title screen, for tests. Quits with
## 0 when up to date, 1 on failure, 2 when this build can't update itself.
func unattended() -> void:
	_log("%s start" % Version.VERSION)
	if updated_from != "":
		_log("updated from " + updated_from)
	if state == OFF:
		_log("unsupported build")
		get_tree().quit(2)
		return
	await check()
	if state == AVAILABLE:
		await install()
	if state == RESTARTING or _handed_off:
		return   # (on Android, the installer replaces this copy when it's done)
	get_tree().quit(0 if state == LATEST else 1)


func _process(_dt: float) -> void:
	if state != DOWNLOADING:
		return
	var got := _http.get_downloaded_bytes()
	var total := _http.get_body_size()
	if total <= 0:
		total = download_bytes
	progress = clampf(float(got) / float(maxi(total, 1)), 0.0, 1.0)
	if got != _seen_bytes:
		_seen_bytes = got
		_seen_t = _now()
	elif _now() - _seen_t > STALL_SECS:
		_stalled = true
		_abort()
	changed.emit()


# --- installing ------------------------------------------------------------

func _install_zip(zip_path: String) -> Error:
	var exe_name := str(_entry.exe.file)
	var wanted := {exe_name: _exe + ".new", exe_name.get_basename() + ".pck": _pck + ".new"}
	var ok: bool = await _in_thread(_unzip.bind(zip_path, wanted))
	DirAccess.remove_absolute(zip_path)
	var new_exe: String = wanted[exe_name]
	var new_pck: String = wanted[exe_name.get_basename() + ".pck"]
	var s1 := ""
	var s2 := ""
	if ok:
		s1 = await _in_thread(_sha256_file.bind(new_exe))
		s2 = await _in_thread(_sha256_file.bind(new_pck))
	if s1 != str(_entry.exe.sha256) or s2 != str(_entry.pck.sha256):
		DirAccess.remove_absolute(new_exe)
		DirAccess.remove_absolute(new_pck)
		return ERR_FILE_CORRUPT
	if _plat == "linux":
		FileAccess.set_unix_permissions(new_exe, 493)   # rwxr-xr-x
	var err := _swap(new_exe, _exe)
	if err != OK:
		DirAccess.remove_absolute(new_pck)
		return err
	err = _swap(new_pck, _pck)
	if err != OK:
		_restore(_exe)
		DirAccess.remove_absolute(new_pck)
	return err


## Puts `fresh` where `target` is and keeps the old file as target.old. A
## running program can be renamed on both systems (Windows won't delete it).
func _swap(fresh: String, target: String) -> Error:
	var old := target + ".old"
	if FileAccess.file_exists(old) and DirAccess.remove_absolute(old) != OK:
		old = "%s.%d.old" % [target, Time.get_ticks_usec()]   # an older one is still in use
	if FileAccess.file_exists(target):
		var e := _rename(target, old)
		if e != OK:
			return e
	var e2 := _rename(fresh, target)
	if e2 != OK:
		_rename(old, target)
		return e2
	_olds[target] = old
	return OK


func _restore(target: String) -> void:
	var old: String = _olds.get(target, "")
	if old != "" and FileAccess.file_exists(old):
		DirAccess.remove_absolute(target)
		_rename(old, target)


## Windows can hold a file that was just written for a moment (antivirus, the
## search indexer), so a rename that fails gets a few more tries.
func _rename(from: String, to: String) -> Error:
	var e := DirAccess.rename_absolute(from, to)
	for _try in 10:
		if e == OK:
			break
		OS.delay_msec(100)
		e = DirAccess.rename_absolute(from, to)
	return e


## Leftovers from an earlier update: replaced files and unfinished downloads.
## On Windows the previous engine may still be closing; its copy goes next time.
## On Android, the APKs that were handed to the installer.
func _cleanup() -> void:
	if _android:
		var ud := DirAccess.open(OS.get_user_data_dir().path_join("update"))
		if ud != null:
			for f in ud.get_files():
				ud.remove(f)
		return
	var d := DirAccess.open(_exe.get_base_dir())
	if d == null:
		return
	for f in d.get_files():
		for stem in [_exe.get_file(), _pck.get_file()]:
			if f.begins_with(stem + ".") and (f.ends_with(".old") or f.ends_with(".part") or f.ends_with(".new")):
				d.remove(f)


func _find_pck() -> String:
	var dir := _exe.get_base_dir()
	for name in [_exe.get_file().get_basename() + ".pck", _exe.get_file() + ".pck"]:
		var p := dir.path_join(name)
		if FileAccess.file_exists(p):
			return p
	return ""


func _read_marker() -> void:
	if not FileAccess.file_exists(MARKER):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(MARKER))
	DirAccess.remove_absolute(MARKER)
	if d is Dictionary and str(d.get("to", "")) == Version.VERSION:
		updated_from = str(d.get("from", ""))
		_log("updated from %s to %s" % [updated_from, Version.VERSION])


func _writable(dir: String) -> bool:
	var probe := dir.path_join(".shelflife-write-test")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(probe)
	return true


func _valid(e: Variant) -> bool:
	if not e is Dictionary:
		return false
	for k in (["apk"] if _android else ["pck", "zip", "exe"]):
		var f: Variant = e.get(k)
		if not f is Dictionary:
			return false
		var name := str(f.get("file", ""))
		if name == "" or name.contains("/") or name.contains("\\") or name.contains(".."):
			return false
		if str(f.get("sha256", "")).length() != 64 or int(f.get("size", 0)) <= 0:
			return false
	return true


# --- worker-thread jobs --------------------------------------------------------

func _in_thread(job: Callable) -> Variant:
	var box := [null]
	var task := WorkerThreadPool.add_task(func(): box[0] = job.call(), false, "update")
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	return box[0]


func _sha256_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var left := f.get_length()
	while left > 0:
		var chunk := f.get_buffer(mini(left, 1 << 20))
		if chunk.is_empty():
			break
		ctx.update(chunk)
		left -= chunk.size()
	return ctx.finish().hex_encode()


## Extracts the files named in `wanted` (zip name -> destination path).
func _unzip(zip_path: String, wanted: Dictionary) -> bool:
	var z := ZIPReader.new()
	if z.open(zip_path) != OK:
		return false
	var found := 0
	for f in z.get_files():
		var dest: String = wanted.get(f.get_file(), "")
		if dest == "":
			continue
		var out := FileAccess.open(dest, FileAccess.WRITE)
		if out == null:
			break
		out.store_buffer(z.read_file(f))
		out.close()
		found += 1
	z.close()
	return found == wanted.size()


# --- HTTP ----------------------------------------------------------------------

## GET with redirects followed by hand. With `to_file` the body streams to disk.
func _fetch(url: String, to_file := "") -> Dictionary:
	for _hop in 6:
		if not _allowed(url):
			return {"code": -1, "body": PackedByteArray()}
		_http.download_file = to_file
		_http.timeout = 0.0 if to_file != "" else 20.0
		var err := _http.request(url, PackedStringArray(["User-Agent: ShelfLife/" + Version.VERSION]))
		if err != OK:
			return {"code": 0, "body": PackedByteArray()}
		var r: Array = await _http.request_completed
		var code: int = r[1]
		if code in [301, 302, 303, 307, 308]:
			url = _location(r[2], url)
			continue
		return {"code": code, "body": r[3]}
	return {"code": -2, "body": PackedByteArray()}


func _abort() -> void:
	_http.cancel_request()
	# cancel_request() doesn't emit, so wake up the waiting _fetch by hand
	_http.request_completed.emit(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())


func _location(headers: PackedStringArray, current: String) -> String:
	for h in headers:
		if h.to_lower().begins_with("location:"):
			var loc := h.substr(9).strip_edges()
			if loc.begins_with("/"):
				var host_end := current.find("/", current.find("://") + 3)
				return current.substr(0, host_end) + loc
			return loc
	return ""


func _allowed(url: String) -> bool:
	if url.begins_with("https://"):
		return true
	return Game.dev.has("update-url") and (url.begins_with("http://127.0.0.1:") or url.begins_with("http://localhost:"))


func _file_url(name: String) -> String:
	if Game.dev.has("update-url"):
		return _source.substr(0, _source.rfind("/") + 1) + name
	return RELEASE_FILE % [latest, name]


func _why(res: Dictionary) -> String:
	match int(res.code):
		0:
			return "no connection"
		-1:
			return "unsafe address"
		-2:
			return "too many redirects"
	return "HTTP %d" % int(res.code)


# --- bits ----------------------------------------------------------------------

func _go(s: int, msg: String) -> void:
	state = s
	message = msg
	_log("%s %s" % [STATE_NAMES[s], msg])
	changed.emit()


func _fail(msg: String) -> void:
	install_failed = true
	_go(FAILED, msg)


func _log(line: String) -> void:
	print("[update] ", line)
	var path := str(Game.dev.get("update-log", ""))
	if path == "":
		return
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.close()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


static func _mb(bytes: int) -> String:
	return "%.1f MB" % (bytes / 1048576.0)


## True when version a is newer than b ("0.2.0" > "0.1.9").
static func newer(a: String, b: String) -> bool:
	var pa := a.trim_prefix("v").split(".")
	var pb := b.trim_prefix("v").split(".")
	for i in 3:
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false
