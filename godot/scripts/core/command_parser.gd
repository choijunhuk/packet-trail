extends RefCounted

static func parse(line: String) -> Dictionary:
	if line.length() > 4096:
		return {"ok": false, "code": "INPUT_TOO_LONG", "text": "명령은 4096자 이내로 입력하세요."}
	var tokens: Array[String] = []
	var token := ""
	var quote := ""
	var escaped := false
	var started := false
	for character in line:
		if character.unicode_at(0) == 0:
			return {"ok": false, "code": "UNSUPPORTED_SYNTAX", "text": "제어 문자를 사용할 수 없습니다."}
		if escaped:
			token += character
			escaped = false
			started = true
			continue
		if character == "\\" and quote != "'":
			escaped = true
			started = true
			continue
		if not quote.is_empty():
			if character == quote:
				quote = ""
			else:
				token += character
			continue
		if character in ["\"", "'"]:
			quote = character
			started = true
		elif character in [" ", "\t"]:
			if started:
				tokens.append(token)
				token = ""
				started = false
		elif character in [";", "|", "&", ">", "<", "`", "$", "\n", "\r"]:
			return {"ok": false, "code": "UNSUPPORTED_SYNTAX", "text": "셸 연결·치환·리다이렉션은 지원하지 않습니다. 명령 하나씩 입력하세요."}
		else:
			token += character
			started = true
	if escaped or not quote.is_empty():
		return {"ok": false, "code": "INVALID_ARGUMENTS", "text": "따옴표 또는 이스케이프가 끝나지 않았습니다."}
	if started:
		tokens.append(token)
	if tokens.is_empty():
		return {"ok": true, "command": "", "args": []}
	var command: String = tokens.pop_front()
	return {"ok": true, "command": command, "args": tokens}
