extends Control

## Pantalla del Modo Historia (Liga Overdrive).
##
## Tres vistas en la misma escena, alternadas por visibilidad:
##   1. Slots: los 3 slots de guardado (decisión registrada), con borrado.
##   2. Equipo: elección del equipo al crear una partida nueva.
##   3. Temporada: clasificación + botón para jugar la siguiente jornada.
##
## Al volver de un partido de historia, entra directo a la temporada.

const MATCH_SCENE := "res://scenes/match/match.tscn"
const MAIN_SCENE := "res://scenes/main/main.tscn"

@onready var slots_box: VBoxContainer = %SlotsBox
@onready var team_box: VBoxContainer = %TeamBox
@onready var season_box: VBoxContainer = %SeasonBox
@onready var slot_list: VBoxContainer = %SlotList
@onready var team_list: VBoxContainer = %TeamList
@onready var season_title: Label = %SeasonTitle
@onready var standings_label: Label = %StandingsLabel
@onready var play_round_button: Button = %PlayRoundButton

var _selected_slot := 1
var _league: League = null

func _ready() -> void:
	%SlotsBackButton.pressed.connect(_back_to_main)
	%TeamBackButton.pressed.connect(_show_slots)
	%SeasonBackButton.pressed.connect(_back_to_slots)
	play_round_button.pressed.connect(_on_play_round)

	if GameState.mode == GameState.Mode.STORY and GameState.league != null:
		_selected_slot = GameState.league_slot
		_league = GameState.league
		_show_season()
	else:
		_show_slots()

func _back_to_main() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)

func _back_to_slots() -> void:
	GameState.league = null
	_show_slots()

# --- Vista 1: slots ---------------------------------------------------------

func _show_slots() -> void:
	_league = null
	_show_only(slots_box)
	for child in slot_list.get_children():
		child.queue_free()
	for i in range(1, League.SLOT_COUNT + 1):
		var row := HBoxContainer.new()
		var open_button := Button.new()
		open_button.text = "SLOT %d · %s" % [i, League.slot_summary(i)]
		open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		open_button.pressed.connect(_on_slot_pressed.bind(i))
		row.add_child(open_button)
		if League.load_slot(i) != null:
			var delete_button := Button.new()
			delete_button.text = "BORRAR"
			delete_button.pressed.connect(_on_delete_pressed.bind(i))
			row.add_child(delete_button)
		slot_list.add_child(row)

func _on_slot_pressed(slot_number: int) -> void:
	_selected_slot = slot_number
	var existing := League.load_slot(slot_number)
	if existing != null:
		_league = existing
		_show_season()
	else:
		_show_team_select()

func _on_delete_pressed(slot_number: int) -> void:
	League.delete_slot(slot_number)
	_show_slots()

# --- Vista 2: elección de equipo --------------------------------------------

func _show_team_select() -> void:
	_show_only(team_box)
	for child in team_list.get_children():
		child.queue_free()
	for team in GameState.league_teams:
		var star_text := "-"
		if team.star_player != null:
			star_text = team.star_player.player_name
			if team.star_player.special_trait != null:
				star_text += " (%s)" % team.star_player.special_trait.trait_name
		var button := Button.new()
		button.text = "%s · %s" % [team.team_name, star_text]
		button.pressed.connect(_on_team_chosen.bind(team))
		team_list.add_child(button)

func _on_team_chosen(team: TeamData) -> void:
	_league = League.create(_selected_slot, team.team_name)
	_show_season()

# --- Vista 3: temporada -----------------------------------------------------

func _show_season() -> void:
	_show_only(season_box)
	season_title.text = "MODO HISTORIA · SLOT %d · %s" % [_selected_slot, _league.player_team_name]
	standings_label.text = _format_standings()
	if _league.is_finished():
		var champion: String = _league.standings_sorted()[0]["name"]
		play_round_button.text = "TEMPORADA FINALIZADA · CAMPEÓN: %s" % champion
		play_round_button.disabled = true
	else:
		play_round_button.text = "JUGAR JORNADA %d/%d · vs %s" \
				% [_league.current_round, League.ROUNDS, _league.current_rival()]
		play_round_button.disabled = false

func _format_standings() -> String:
	var lines: Array[String] = []
	var position := 1
	for row in _league.standings_sorted():
		var marker := "► " if row["name"] == _league.player_team_name else "   "
		lines.append("%s%d. %s — %d pts (%d-%d-%d) %d:%d" % [marker, position,
				row["name"], row["pts"], row["w"], row["d"], row["l"], row["gf"], row["ga"]])
		position += 1
	return "\n".join(lines)

func _on_play_round() -> void:
	var own := GameState.team_by_name(_league.player_team_name)
	var rival := GameState.team_by_name(_league.current_rival())
	if own == null or rival == null:
		return
	GameState.mode = GameState.Mode.STORY
	GameState.league = _league
	GameState.league_slot = _selected_slot
	GameState.player_team = own
	GameState.ai_team = rival
	get_tree().change_scene_to_file(MATCH_SCENE)

func _show_only(box: VBoxContainer) -> void:
	slots_box.visible = box == slots_box
	team_box.visible = box == team_box
	season_box.visible = box == season_box
