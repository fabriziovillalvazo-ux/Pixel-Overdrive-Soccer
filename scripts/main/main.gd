extends Control

## Menú principal.
## Modos (decisión registrada): AMISTOSO (partidos casuales, sin
## persistencia) y LIGA con 3 slots de guardado + Copa KO (hito M4).
## Ajustes: hora del partido (Día/Atardecer/Noche/Aleatoria), persistente.

const MATCH_SCENE := "res://scenes/match/match.tscn"

@onready var friendly_button: Button = %FriendlyButton
@onready var league_button: Button = %LeagueButton
@onready var time_button: Button = %TimeButton

func _ready() -> void:
	friendly_button.pressed.connect(_start_friendly)
	time_button.pressed.connect(_on_time_pressed)
	# TODO(M4): pantalla de liga con 3 slots de guardado y Copa KO.
	league_button.disabled = true
	_refresh_time_button()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_start_friendly()

func _start_friendly() -> void:
	# TODO(M4): selección de equipo propio y rival para el amistoso.
	GameState.pick_default_match()
	get_tree().change_scene_to_file(MATCH_SCENE)

func _on_time_pressed() -> void:
	Settings.cycle_time_of_day()
	_refresh_time_button()

func _refresh_time_button() -> void:
	time_button.text = "HORA DEL PARTIDO: %s" % Settings.time_of_day_display_name()
