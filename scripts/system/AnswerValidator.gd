extends Node
func check_answer(player_answer: String, question: Dictionary) -> bool:
	var submitted := player_answer.strip_edges()
	if submitted.is_empty():
		return false
	var accepted: Array = question.get("accepted_answers", [question.get("answer", null)])
	for candidate in accepted:
		if typeof(candidate) == TYPE_INT or typeof(candidate) == TYPE_FLOAT:
			if submitted.is_valid_int() and int(submitted) == int(candidate):
				return true
		elif submitted.to_lower() == str(candidate).strip_edges().to_lower():
			return true
	return false
