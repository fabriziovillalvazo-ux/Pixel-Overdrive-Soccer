extends Node

## Autoload GameState: estado global entre escenas.
##
## Carga la Liga Overdrive desde resources/teams/ y guarda la selección
## de equipos para el partido (siempre Jugador vs IA: no hay online ni
## multijugador local, por diseño).

const TEAMS_DIR := "res://resources/teams/"

## Los 8 equipos ficticios de la Liga Overdrive.
var league_teams: Array[TeamData] = []

## Selección para el próximo partido.
var player_team: TeamData
var ai_team: TeamData

func _ready() -> void:
	_load_league()

func _load_league() -> void:
	league_teams.clear()
	var dir := DirAccess.open(TEAMS_DIR)
	if dir == null:
		push_error("No se pudo abrir el directorio de equipos: %s" % TEAMS_DIR)
		return
	for file_name in dir.get_files():
		# En builds exportadas los .tres pueden aparecer como .tres.remap.
		var resource_name := file_name.trim_suffix(".remap")
		if not resource_name.ends_with(".tres"):
			continue
		var team := load(TEAMS_DIR + resource_name) as TeamData
		if team != null:
			league_teams.append(team)
	league_teams.sort_custom(func(a: TeamData, b: TeamData) -> bool:
		return a.team_name < b.team_name)

## Selección rápida por defecto (hasta que exista la pantalla de selección).
func pick_default_match() -> void:
	if league_teams.size() >= 2:
		player_team = league_teams[0]
		ai_team = league_teams[1]
