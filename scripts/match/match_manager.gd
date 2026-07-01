class_name MatchManager
extends Node2D

## Orquestador de un partido: marcador, reloj, saques y cambio de táctica.
##
## Composición (nodos hijos en match.tscn):
##   - MatchRules: reglas (gol, saques, SIN fuera de juego — por diseño).
##   - FoulSystem: faltas y tarjetas por timing/ángulo de las entradas.
##   - Field: dibujo del terreno de juego.
##   - Ball: el balón.
##   - MatchCamera: cámara lateral estilo retransmisión de TV.
##   - HUD (CanvasLayer): marcador, reloj, estamina y táctica.

signal score_changed(home: int, away: int)
signal clock_updated(seconds_elapsed: float, half: int)
signal half_ended(half: int)
signal match_ended(home: int, away: int)

@onready var rules: MatchRules = $MatchRules
@onready var foul_system: FoulSystem = $FoulSystem
@onready var ball: Ball = $Ball
@onready var hud: Node = $HUD

## Táctica de cada equipo. La del jugador se cambia con las teclas 1/2/3;
## la de la IA la ajusta su entrenador virtual según el marcador.
var player_tactics := TacticsManager.new()
var ai_tactics := TacticsManager.new()

var home_score := 0
var away_score := 0
var current_half := 1
var elapsed := 0.0
var playing := false

func _ready() -> void:
	add_child(player_tactics)
	add_child(ai_tactics)

	rules.goal_scored.connect(_on_goal_scored)
	rules.ball_out.connect(_on_ball_out)
	foul_system.foul_committed.connect(_on_foul_committed)

	if GameState.player_team == null:
		GameState.pick_default_match()
	_spawn_teams()
	_kickoff()

func _physics_process(delta: float) -> void:
	if not playing:
		return

	elapsed += delta
	clock_updated.emit(elapsed, current_half)
	if elapsed >= rules.half_duration_seconds():
		_end_half()
		return

	# Si el balón salió, MatchRules emite aquí la señal de gol o de saque.
	rules.check_ball_position(ball.global_position, ball.last_touch_side)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tactic_offensive"):
		player_tactics.set_tactic(TacticsManager.Tactic.OFFENSIVE)
	elif event.is_action_pressed("tactic_balanced"):
		player_tactics.set_tactic(TacticsManager.Tactic.BALANCED)
	elif event.is_action_pressed("tactic_defensive"):
		player_tactics.set_tactic(TacticsManager.Tactic.DEFENSIVE)
	elif event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused

func _spawn_teams() -> void:
	# TODO(M2): instanciar player.tscn x11 por equipo con SquadFactory,
	# posicionarlos según formación + táctica y conectar sus señales de
	# pase/tiro/entrada con el balón y el FoulSystem.
	pass

func _kickoff() -> void:
	ball.stop_at(Vector2.ZERO)
	playing = true

func _on_goal_scored(scoring_side: MatchRules.Side) -> void:
	if scoring_side == MatchRules.Side.HOME:
		home_score += 1
	else:
		away_score += 1
	score_changed.emit(home_score, away_score)
	_kickoff()

func _on_ball_out(_restart: MatchRules.Restart, _side: MatchRules.Side, out_position: Vector2) -> void:
	# TODO(M2): colocar el balón para el saque (banda/córner/puerta) y dar
	# el control al equipo correspondiente. De momento, balón al punto de salida.
	var clamped_x := clampf(out_position.x, -rules.field_half_length + 8.0, rules.field_half_length - 8.0)
	var clamped_y := clampf(out_position.y, -rules.field_half_width + 8.0, rules.field_half_width - 8.0)
	ball.stop_at(Vector2(clamped_x, clamped_y))

func _on_foul_committed(_offender: Node, _victim: Node, _result: FoulSystem.TackleResult) -> void:
	# TODO(M2): detener el juego y sacar la falta desde el punto de la infracción.
	pass

func _end_half() -> void:
	playing = false
	half_ended.emit(current_half)
	if current_half == 1:
		current_half = 2
		elapsed = 0.0
		_kickoff()
	else:
		match_ended.emit(home_score, away_score)
