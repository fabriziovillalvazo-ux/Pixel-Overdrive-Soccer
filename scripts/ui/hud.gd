class_name HUD
extends CanvasLayer

## HUD de partido: marcador, reloj, barra de estamina del jugador
## controlado y táctica activa. Se conecta a las señales del MatchManager
## (nodo padre en match.tscn).

@onready var score_label: Label = %ScoreLabel
@onready var clock_label: Label = %ClockLabel
@onready var tactic_label: Label = %TacticLabel
@onready var stamina_bar: ProgressBar = %StaminaBar

var _match_manager: MatchManager

func _ready() -> void:
	_match_manager = get_parent() as MatchManager
	if _match_manager == null:
		return
	_match_manager.score_changed.connect(_on_score_changed)
	_match_manager.clock_updated.connect(_on_clock_updated)
	_match_manager.player_tactics.tactic_changed.connect(_on_tactic_changed)
	_refresh_team_names()
	_on_score_changed(0, 0)
	_on_tactic_changed(_match_manager.player_tactics.current_tactic)

## Llamar cuando cambie el jugador controlado para seguir su estamina.
func track_player(player: PlayerCharacter) -> void:
	var stamina := player.stamina_component
	stamina_bar.max_value = stamina.max_stamina
	stamina_bar.value = stamina.current
	if not stamina.stamina_changed.is_connected(_on_stamina_changed):
		stamina.stamina_changed.connect(_on_stamina_changed)

func _refresh_team_names() -> void:
	# Los nombres cortos se muestran junto al marcador si hay equipos elegidos.
	pass

func _on_score_changed(home: int, away: int) -> void:
	var home_name := GameState.player_team.short_name if GameState.player_team else "LOC"
	var away_name := GameState.ai_team.short_name if GameState.ai_team else "VIS"
	score_label.text = "%s %d - %d %s" % [home_name, home, away, away_name]

func _on_clock_updated(seconds_elapsed: float, half: int) -> void:
	# El reloj de partido se presenta como 45 min por parte, escalados
	# desde la duración real configurada en MatchRules.
	var half_real := _match_manager.rules.half_duration_seconds()
	var displayed_minutes := int(seconds_elapsed / half_real * 45.0) + (45 if half == 2 else 0)
	clock_label.text = "%02d'" % displayed_minutes

func _on_tactic_changed(_tactic: TacticsManager.Tactic) -> void:
	tactic_label.text = "TÁCTICA: %s" % _match_manager.player_tactics.tactic_display_name()

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
