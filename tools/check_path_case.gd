extends SceneTree
## Path case checker. Android builds are case-sensitive, Windows is not, so a
## reference like "res://Assets/foo.png" to assets/foo.png works in the editor
## but breaks on a phone. This scans text resources for res:// paths (and the
## relative "uri" entries inside .gltf files) and compares every path segment
## against the real names on disk.
##
## Run:  godot_console --headless --path . -s res://tools/check_path_case.gd
## Prints "PATH CASE: OK" or one line per problem, and exits 1 on problems.
## Add "path-case: ignore" in a comment on a line to skip it (e.g. a test that
## points at a missing file on purpose).

const EXTENSIONS: Array[String] = ["tscn", "tres", "gltf", "gd", "godot"]
const SKIP_DIRS: Array[String] = [".godot", ".git", "android"]

var _res_path := RegEx.create_from_string("res://[^\"'\\s)\\]]+")
var _gltf_uri := RegEx.create_from_string("\"uri\"\\s*:\\s*\"([^\"]+)\"")
var _problems: int = 0
var _checked: int = 0


func _init() -> void:
	for file in _scan("res://"):
		if file != get_script().resource_path:
			_check_file(file)
	if _problems == 0:
		print("PATH CASE: OK (%d references checked)" % _checked)
	else:
		print("PATH CASE: %d problem(s) in %d references" % [_problems, _checked])
	quit(1 if _problems > 0 else 0)


## All files under `dir` with a scanned extension (directory names keep their real case).
func _scan(dir: String) -> Array[String]:
	var out: Array[String] = []
	for d in DirAccess.get_directories_at(dir):
		if d in SKIP_DIRS:
			continue
		out.append_array(_scan(dir.path_join(d)))
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in EXTENSIONS:
			out.append(dir.path_join(f))
	return out


func _check_file(file: String) -> void:
	var text: String = FileAccess.get_file_as_string(file)
	var lines: PackedStringArray = text.split("\n")
	for i in lines.size():
		if lines[i].contains("path-case: ignore"):
			continue
		for m in _res_path.search_all(lines[i]):
			var path: String = m.get_string().split("::")[0]  # drop sub-resource ids
			path = path.rstrip(".,;:")  # sentence punctuation in comments
			if path.begins_with("res://.godot/") or path.contains("%") or path.ends_with("/"):
				continue  # generated cache paths, format strings, directory prefixes
			_check_path(file, i + 1, path)
		if file.get_extension() == "gltf":
			for m in _gltf_uri.search_all(lines[i]):
				var uri: String = m.get_string(1)
				if not uri.begins_with("data:"):
					_check_path(file, i + 1, file.get_base_dir().path_join(uri.uri_decode()))


## Walk the path one segment at a time, matching against real directory listings.
func _check_path(file: String, line: int, path: String) -> void:
	_checked += 1
	var current: String = "res://"
	for part in path.trim_prefix("res://").split("/", false):
		var names: PackedStringArray = DirAccess.get_files_at(current) + DirAccess.get_directories_at(current)
		if part in names:
			current = current.path_join(part)
			continue
		var real: String = ""
		for n in names:
			if n.to_lower() == part.to_lower():
				real = n
				break
		_problems += 1
		if real != "":
			print("%s:%d: case mismatch: %s  (on disk: %s)" % [file, line, path, current.path_join(real)])
		else:
			print("%s:%d: not found: %s" % [file, line, path])
		return
