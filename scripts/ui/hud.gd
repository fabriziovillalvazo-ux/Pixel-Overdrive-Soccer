class_name HUD
extends CanvasLayer

## HUD de partido: marcador, reloj, barra de estamina del jugador
## controlado, táctica activa, mensajes de eventos (gol, falta, tarjetas)
## y pantalla de final. Se conecta a las señales del MatchManager
## (nodo padre en match.tscn).

@onready var score_label: Label = %ScoreLabel
@onready var clock_label: Label = %ClockLabel
@onready var tactic_label: Label = %TacticLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var message_label: Label = %MessageLabel
@onready var full_time_label: Label = %FullTimeLabel
@onready var name_label: Label = %NameLabel
@onready var home_chip: ColorRect = %HomeChip
@onready var away_chip: ColorRect = %AwayChip

var _match_manager: MatchManager

func _ready() -> void:
	_match_manager = get_parent() as MatchManager
	if _match_manager == null:
		return
	_match_manager.score_changed.connect(_on_score_changed)
	_match_manager.clock_updated.connect(_on_clock_updated)
	_match_manager.player_tactics.tactic_changed.connect(_on_tactic_changed)
	_on_score_changed(0, 0)
	_on_tactic_changed(_match_manager.player_tactics.current_tactic)
	# Chips con los colores de cada equipo junto al marcador (referencia).
	if GameState.player_team != null:
		home_chip.color = GameState.player_team.primary_color
	if GameState.ai_team != null:
		away_chip.color = GameState.ai_team.primary_color

## Llamar cuando cambie el jugador controlado: sigue su estamina y muestra
## su placa de nombre (estilo referencia: "Rex Voltaje · DEL").
func track_player(player: PlayerCharacter) -> void:
	var stamina := player.stamina_component
	stamina_bar.max_value = stamina.max_stamina
	stamina_bar.value = stamina.current
	if not stamina.stamina_changed.is_connected(_on_stamina_changed):
		stamina.stamina_changed.connect(_on_stamina_changed)
	var stats := player.stats_component.stats
	if stats != null:
		name_label.text = "%s · %s" % [stats.player_name, stats.position_short_name()]

## Mensaje breve centrado en pantalla (gol, falta, tarjeta, descanso...).
func show_message(text: String, duration: float = 2.0) -> void:
	message_label.text = text
	message_label.visible = true
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		# Solo se oculta si nadie mostró otro mensaje mientras tanto.
		if message_label.text == text:
			message_label.visible = false)

func show_full_time(home: int, away: int) -> void:
	var home_name := GameState.player_team.team_name if GameState.player_team else "Local"
	var away_name := GameState.ai_team.team_name if GameState.ai_team else "Visitante"
	full_time_label.text = "FINAL\n%s %d - %d %s\n\nENTER: volver al menú" \
			% [home_name, home, away, away_name]
	full_time_label.visible = true

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
