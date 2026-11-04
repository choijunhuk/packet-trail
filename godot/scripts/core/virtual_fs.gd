extends RefCounted

static func normalize(path: String, cwd: String = "/", home: String = "/home/player") -> Dictionary:
	if path.length() > 1024 or path.contains(":") or path.contains("\\") or path.contains("\n") or path.contains("\r"):
		return {"ok": false, "code": "INVALID_PATH", "text": "게임 내부 경로만 사용할 수 있습니다."}
	for index in range(path.length()):
		if path.unicode_at(index) < 32 or path.unicode_at(index) == 127:
			return {"ok": false, "code": "INVALID_PATH", "text": "제어 문자가 포함된 경로입니다."}
	var value := path if not path.is_empty() else "."
	if value == "~":
		value = home
	elif value.begins_with("~/"):
		value = home + value.substr(1)
	var parts: Array[String] = []
	if not value.begins_with("/"):
		for part in cwd.split("/", false):
			parts.append(part)
	for part in value.split("/", false):
		if part == ".":
			continue
		if part == "..":
			if not parts.is_empty():
				parts.pop_back()
		else:
			parts.append(part)
	return {"ok": true, "path": "/" + "/".join(parts)}

static func permitted(entry: Dictionary, account: String, groups: Array, bit: int) -> bool:
	var mode := String(entry.get("mode", "000"))
	if mode.length() != 3:
		return false
	var index := 2
	if String(entry.get("owner", "")) == account:
		index = 0
	elif groups.has(String(entry.get("group", ""))):
		index = 1
	return (int(mode[index]) & bit) != 0

static func access(files: Dictionary, path: String, account: String, groups: Array, operation: String) -> Dictionary:
	var components := path.split("/", false)
	var parent := "/"
	for index in range(components.size()):
		if not files.has(parent) or files[parent].get("kind", "") != "dir":
			return _failure("NOT_DIRECTORY", parent + ": Not a directory")
		if not permitted(files[parent], account, groups, 1):
			return _failure("PERMISSION_DENIED", parent + ": Permission denied")
		parent = parent.path_join(components[index])
	if not files.has(path):
		return _failure("NOT_FOUND", path + ": No such file or directory")
	var entry: Dictionary = files[path]
	if operation == "list" and (not permitted(entry, account, groups, 4) or not permitted(entry, account, groups, 1)):
		return _failure("PERMISSION_DENIED", path + ": Permission denied")
	if operation == "read" and not permitted(entry, account, groups, 4):
		return _failure("PERMISSION_DENIED", path + ": Permission denied")
	if operation == "enter" and not permitted(entry, account, groups, 1):
		return _failure("PERMISSION_DENIED", path + ": Permission denied")
	if operation == "write_dir" and (not permitted(entry, account, groups, 2) or not permitted(entry, account, groups, 1)):
		return _failure("PERMISSION_DENIED", path + ": Permission denied")
	return {"ok": true, "entry": entry.duplicate(true)}

static func children(files: Dictionary, directory: String) -> Array:
	var result: Array = []
	for key in files.keys():
		var path := String(key)
		if path != directory and path.get_base_dir() == directory:
			result.append({"path": path, "name": path.get_file(), "kind": files[path].get("kind", "file")})
	result.sort_custom(func(a, b): return String(a.name) < String(b.name))
	return result

static func _failure(code: String, text: String) -> Dictionary:
	return {"ok": false, "code": code, "text": text}
