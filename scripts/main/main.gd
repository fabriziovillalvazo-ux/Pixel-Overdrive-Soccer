extends Control

## Menú principal.
## JUGAR abre las dos opciones (decisión registrada): MODO HISTORIA (la
## liga, 3 slots de guardado) y AMISTOSO (partidos casuales, sin
## persistencia). Ajustes: hora del partido, persistente.

const MATCH_SCENE := "res://scenes/match/match.tscn"
const LEAGUE_SCENE := "res://scenes/league/league_menu.tscn"

@onready var home_box: VBoxContainer = %HomeBox
@onready var play_box: VBoxContainer = %PlayBox
@onready var time_button: Button = %TimeButton

func _ready() -> void:
	%PlayButton.pressed.connect(_show_play_options)
	%StoryButton.pressed.connect(_open_story)
	%FriendlyButton.pressed.connect(_start_friendly)
	%BackButton.pressed.connect(_show_home)
	time_button.pressed.connect(_on_time_pressed)
	_refresh_time_button()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return
	if home_box.visible:
		_show_play_options()
	else:
		_start_friendly()

func _show_play_options() -> void:
	home_box.visible = false
	play_box.visible = true

func _show_home() -> void:
	play_box.visible = false
	home_box.visible = true

func _open_story() -> void:
	get_tree().change_scene_to_file(LEAGUE_SCENE)

func _start_friendly() -> void:
	# TODO(M4): selección de equipo propio y rival para el amistoso.
	GameState.mode = GameState.Mode.FRIENDLY
	GameState.league = null
	GameState.pick_default_match()
	get_tree().change_scene_to_file(MATCH_SCENE)

func _on_time_pressed() -> void:
	Settings.cycle_time_of_day()
	_refresh_time_button()

func _refresh_time_button() -> void:
	time_button.text = "HORA DEL PARTIDO: %s" % Settings.time_of_day_display_name()
