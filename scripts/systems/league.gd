class_name League
extends RefCounted

## Temporada del Modo Historia (Liga Overdrive).
##
## 14 jornadas (ida y vuelta contra los otros 7 equipos). El calendario se
## genera con el método del círculo sobre la lista alfabética de equipos:
## es determinista, así que no hace falta persistirlo — solo se guardan
## el equipo elegido, la jornada actual y la tabla (3 slots independientes,
## decisión registrada).

const ROUNDS := 14
const SLOT_COUNT := 3
const SAVE_TEMPLATE := "league_slot_%d.save"

var slot := 1
var player_team_name := ""
## 1..ROUNDS; ROUNDS + 1 significa temporada terminada.
var current_round := 1
## team_name -> {"pts", "w", "d", "l", "gf", "ga"}
var table := {}

static func create(slot_number: int, team_name: String) -> League:
	var league := League.new()
	league.slot = slot_number
	league.player_team_name = team_name
	for team in GameState.league_teams:
		league.table[team.team_name] = {"pts": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0}
	league.save()
	return league

func is_finished() -> bool:
	return current_round > ROUNDS

## Emparejamientos [local, visitante] (nombres) de una jornada.
## Jornadas 8-14: mismo cruce con la localía invertida.
static func fixtures_for_round(teams: Array[TeamData], round_number: int) -> Array:
	var count := teams.size()
	if count < 2:
		return []
	var base_round := (round_number - 1) % (count - 1)
	var second_leg := round_number > count - 1

	# Método del círculo: el equipo 0 queda fijo y el resto rota.
	var others: Array[int] = []
	for i in range(1, count):
		others.append(i)
	for r in base_round:
		others.push_front(others.pop_back())

	var index_pairs := [[0, others[0]]]
	var half := int(count / 2.0)
	for i in range(1, half):
		index_pairs.append([others[i], others[count - 1 - i]])

	var pairs := []
	for pair in index_pairs:
		var home_name: String = teams[pair[0]].team_name
		var away_name: String = teams[pair[1]].team_name
		if second_leg:
			pairs.append([away_name, home_name])
		else:
			pairs.append([home_name, away_name])
	return pairs

## Rival del jugador en la jornada actual.
func current_rival() -> String:
	for pair in League.fixtures_for_round(GameState.league_teams, current_round):
		if pair[0] == player_team_name:
			return pair[1]
		if pair[1] == player_team_name:
			return pair[0]
	return ""

## Cierra la jornada tras el partido del jugador: registra su resultado
## (en el motor el jugador siempre es HOME; aquí se reorienta según el
## calendario), simula los demás cruces, avanza la jornada y guarda.
func finish_player_round(player_goals: int, rival_goals: int) -> void:
	if is_finished():
		return
	for pair in League.fixtures_for_round(GameState.league_teams, current_round):
		var home_name: String = pair[0]
		var away_name: String = pair[1]
		if home_name == player_team_name:
			record_result(home_name, away_name, player_goals, rival_goals)
		elif away_name == player_team_name:
			record_result(home_name, away_name, rival_goals, player_goals)
		else:
			var home_team := GameState.team_by_name(home_name)
			var away_team := GameState.team_by_name(away_name)
			record_result(home_name, away_name,
					_simulated_goals(home_team, away_team),
					_simulated_goals(away_team, home_team))
	current_round += 1
	save()

func record_result(home_name: String, away_name: String, home_goals: int, away_goals: int) -> void:
	var home: Dictionary = table[home_name]
	var away: Dictionary = table[away_name]
	home["gf"] += home_goals
	home["ga"] += away_goals
	away["gf"] += away_goals
	away["ga"] += home_goals
	if home_goals > away_goals:
		home["w"] += 1
		home["pts"] += 3
		away["l"] += 1
	elif home_goals < away_goals:
		away["w"] += 1
		away["pts"] += 3
		home["l"] += 1
	else:
		home["d"] += 1
		away["d"] += 1
		home["pts"] += 1
		away["pts"] += 1

## Clasificación ordenada: puntos, diferencia de goles, goles a favor.
func standings_sorted() -> Array:
	var rows := []
	for team_name in table:
		var s: Dictionary = table[team_name]
		rows.append({"name": team_name, "pts": s["pts"], "w": s["w"], "d": s["d"],
				"l": s["l"], "gf": s["gf"], "ga": s["ga"]})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["pts"] != b["pts"]:
			return a["pts"] > b["pts"]
		var diff_a: int = a["gf"] - a["ga"]
		var diff_b: int = b["gf"] - b["ga"]
		if diff_a != diff_b:
			return diff_a > diff_b
		if a["gf"] != b["gf"]:
			return a["gf"] > b["gf"]
		return String(a["name"]) < String(b["name"]))
	return rows

## Goles simulados de un cruce entre equipos IA, sesgados por su media.
static func _simulated_goals(attacker: TeamData, defender: TeamData) -> int:
	if attacker == null or defender == null:
		return 0
	var expected := 1.2 + float(attacker.base_overall - defender.base_overall) * 0.05
	return clampi(int(round(expected + randfn(0.0, 1.0))), 0, 6)

# --- Persistencia (3 slots) -------------------------------------------------

func save() -> void:
	var config := ConfigFile.new()
	config.set_value("league", "player_team", player_team_name)
	config.set_value("league", "current_round", current_round)
	config.set_value("league", "table", table)
	config.save(_slot_path(slot))

static func load_slot(slot_number: int) -> League:
	var config := ConfigFile.new()
	if config.load(_slot_path(slot_number)) != OK:
		return null
	var league := League.new()
	league.slot = slot_number
	league.player_team_name = config.get_value("league", "player_team", "")
	league.current_round = config.get_value("league", "current_round", 1)
	league.table = config.get_value("league", "table", {})
	if league.player_team_name == "" or league.table.is_empty():
		return null
	return league

static func slot_summary(slot_number: int) -> String:
	var league := load_slot(slot_number)
	if league == null:
		return "VACÍO"
	if league.is_finished():
		return "%s · TEMPORADA FINALIZADA" % league.player_team_name
	return "%s · JORNADA %d/%d" % [league.player_team_name, league.current_round, ROUNDS]

static func delete_slot(slot_number: int) -> void:
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove(SAVE_TEMPLATE % slot_number)

static func _slot_path(slot_number: int) -> String:
	return "user://" + (SAVE_TEMPLATE % slot_number)
