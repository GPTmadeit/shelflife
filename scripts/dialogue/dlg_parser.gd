extends RefCounted
## Parses .dlg dialogue scripts.
##
##   === node_id                 starts a node
##   WHO [emotion]: text         a line (WHO is a cast id; emotion optional)
##   ? choice text -> target     consecutive ?-lines form a menu
##   -> target                   jump (-> END finishes the conversation)
##   ~ command arg "quoted arg"  a command (see dlg_runner.gd)
##   {cond} ...                  any entry can be guarded: {flag} {!flag}
##                               {seen:node} {!seen:node}, joined with &
##   # comment


static func parse(text: String) -> Dictionary:
	var nodes := {}
	var cur: Array = []
	var lineno := 0
	for raw in text.split("\n"):
		lineno += 1
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("==="):
			var id := line.substr(3).strip_edges()
			cur = []
			nodes[id] = cur
			continue
		var cond := ""
		if line.begins_with("{"):
			var close := line.find("}")
			cond = line.substr(1, close - 1).strip_edges()
			line = line.substr(close + 1).strip_edges()
		var e := {"cond": cond, "line": lineno}
		if line.begins_with("?"):
			var body := line.substr(1).strip_edges()
			var arrow := body.rfind("->")
			e.t = "choice"
			e.text = body.substr(0, arrow).strip_edges()
			e.target = body.substr(arrow + 2).strip_edges()
		elif line.begins_with("->"):
			e.t = "goto"
			e.target = line.substr(2).strip_edges()
		elif line.begins_with("~"):
			var parts := split_args(line.substr(1).strip_edges())
			e.t = "cmd"
			e.name = parts[0]
			e.args = parts.slice(1)
		else:
			var colon := line.find(":")
			if colon < 0:
				push_warning("dlg line %d: no speaker: %s" % [lineno, line])
				continue
			var head := line.substr(0, colon).strip_edges()
			var emo := ""
			var b := head.find("[")
			if b >= 0:
				emo = head.substr(b + 1, head.find("]") - b - 1).strip_edges()
				head = head.substr(0, b).strip_edges()
			e.t = "line"
			e.who = head.to_lower()
			e.emo = emo
			e.text = line.substr(colon + 1).strip_edges()
		cur.append(e)
	return nodes


static func split_args(s: String) -> Array:
	var out := []
	var cur := ""
	var quoted := false
	for ch in s:
		if ch == "\"":
			quoted = not quoted
			continue
		if ch == " " and not quoted:
			if cur != "":
				out.append(cur)
				cur = ""
			continue
		cur += ch
	if cur != "":
		out.append(cur)
	return out


## Checks every jump target exists. Returns a list of problems.
static func validate(nodes: Dictionary) -> Array:
	var problems := []
	for id in nodes.keys():
		for e in nodes[id]:
			if e.t in ["goto", "choice"] and e.target != "END" and not nodes.has(e.target):
				problems.append("line %d: %s -> missing node '%s'" % [e.line, id, e.target])
			var c: String = e.cond
			for part in c.split("&", false):
				part = part.strip_edges().trim_prefix("!")
				if part.begins_with("seen:") and not nodes.has(part.substr(5)):
					problems.append("line %d: condition on missing node '%s'" % [e.line, part.substr(5)])
	return problems
