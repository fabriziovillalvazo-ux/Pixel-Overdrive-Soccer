class_name Formations
extends RefCounted

## Traduce una formación en texto ("4-4-2", "3-5-2"...) a:
##   - layout(): posiciones (POR/DEF/MED/DEL) para generar la plantilla.
##   - field_slots(): coordenadas normalizadas en el campo propio.
##
## Coordenadas normalizadas: x en [-1, 0] (portería propia → centro),
## y en [-1, 1] (banda superior → inferior). El MatchManager las escala a
## píxeles y las refleja para el equipo visitante.

const FALLBACK: Array[int] = [4, 4, 2]

static func parse(formation: String) -> Array[int]:
	var counts: Array[int] = []
	for part in formation.split("-"):
		if part.strip_edges().is_valid_int():
			counts.append(int(part.strip_edges()))
	var total := 0
	for c in counts:
		total += c
	if counts.is_empty() or total != 10:
		counts = FALLBACK.duplicate()
	return counts

static func layout(formation: String) -> Array[PlayerStats.FieldPosition]:
	var counts := parse(formation)
	var result: Array[PlayerStats.FieldPosition] = [PlayerStats.FieldPosition.POR]
	for line in counts.size():
		var line_position := PlayerStats.FieldPosition.MED
		if line == 0:
			line_position = PlayerStats.FieldPosition.DEF
		elif line == counts.size() - 1:
			line_position = PlayerStats.FieldPosition.DEL
		for i in counts[line]:
			result.append(line_position)
	return result

static func field_slots(formation: String) -> Array[Vector2]:
	var counts := parse(formation)
	var slots: Array[Vector2] = [Vector2(-0.92, 0.0)]
	for line in counts.size():
		var x := -0.62
		if counts.size() > 1:
			x = lerpf(-0.62, -0.08, float(line) / float(counts.size() - 1))
		var players_in_line := counts[line]
		for i in players_in_line:
			var y := ((float(i) + 0.5) / float(players_in_line) - 0.5) * 1.7
			slots.append(Vector2(x, y))
	return slots
