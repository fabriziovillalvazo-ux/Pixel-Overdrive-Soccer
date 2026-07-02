class_name MatchManager
extends Node2D

## Orquestador de un partido: equipos, posesión, marcador, reloj, saques,
## faltas y cambio de táctica.
##
## Composición (nodos hijos en match.tscn):
##   - MatchRules: reglas (gol, saques, SIN fuera de juego — por diseño).
##   - FoulSystem: faltas y tarjetas por timing/ángulo de las entradas.
##   - Field: dibujo del terreno de juego.
##   - Ball: el balón (con sistema de posesión).
##   - MatchCamera: cámara lateral estilo retransmisión de TV.
##   - HUD (CanvasLayer): marcador, reloj, estamina, táctica y mensajes.
##
## El equipo del usuario es HOME (ataca a la derecha); la IA es AWAY.

signal score_changed(home: int, away: int)
signal clock_updated(seconds_elapsed: float, half: int)
signal half_ended(half: int)
signal match_ended(home: int, away: int)

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const MAIN_MENU_SCENE := "res://scenes/main/main.tscn"
const LEAGUE_SCENE := "res://scenes/league/league_menu.tscn"

## Radio en el que un jugador captura un balón suelto.
const CONTROL_RADIUS := 11.0
const TACKLE_RANGE_STAND := 16.0
const TACKLE_RANGE_SLIDE := 24.0
## Alcance de pierna al evaluar el timing de una entrada.
const BALL_REACH := 12.0

@onready var rules: MatchRules = $MatchRules
@onready var foul_system: FoulSystem = $FoulSystem
@onready var ball: Ball = $Ball
@onready var hud: HUD = $HUD
@onready var lighting: StadiumLighting = $CanvasModulate

## Táctica de cada equipo. La del jugador se cambia con las teclas 1/2/3;
## la de la IA la ajusta su entrenador virtual según el marcador.
var player_tactics := TacticsManager.new()
var ai_tactics := TacticsManager.new()

var home_players: Array[PlayerCharacter] = []
var away_players: Array[PlayerCharacter] = []
var user_controlled: PlayerCharacter = null
var home_goalkeeper: PlayerCharacter = null
var crowd: CrowdAudio = null

var home_score := 0
var away_score := 0
var current_half := 1
var elapsed := 0.0
var playing := false
var match_over := false

var _ai_coach_timer := 0.0

func _ready() -> void:
	# El orquestador sigue procesando con el árbol pausado para poder
	# despausar (Esc) y salir al menú tras el final del partido; jugadores,
	# balón y cámara quedan en PAUSABLE y sí se congelan.
	process_mode = Node.PROCESS_MODE_ALWAYS

	add_child(player_tactics)
	add_child(ai_tactics)

	rules.goal_scored.connect(_on_goal_scored)
	rules.ball_out.connect(_on_ball_out)
	foul_system.foul_committed.connect(_on_foul_committed)
	foul_system.card_shown.connect(_on_card_shown)

	if GameState.player_team == null:
		GameState.pick_default_match()

	# Ambiente: hora del partido (Ajustes) y afición sintetizada.
	lighting.setup(Settings.resolve_match_time(), rules)
	crowd = CrowdAudio.new()
	add_child(crowd)

	_spawn_teams()
	_kickoff(MatchRules.Side.HOME)
	crowd.cheer(0.7)

func _physics_process(delta: float) -> void:
	if not playing or get_tree().paused:
		return

	elapsed += delta
	clock_updated.emit(elapsed, current_half)

	_ai_coach_timer += delta
	if _ai_coach_timer >= 5.0:
		_ai_coach_timer = 0.0
		_update_ai_coach()

	if elapsed >= rules.half_duration_seconds():
		_end_half()
		return

	_scan_loose_ball()
	# Si el balón salió, MatchRules emite aquí la señal de gol o de saque.
	rules.check_ball_position(ball.global_position, ball.last_touch_side)

func _unhandled_input(event: InputEvent) -> void:
	if match_over:
		if event.is_action_pressed("ui_accept"):
			# La pausa es global al árbol: hay que soltarla antes de salir.
			get_tree().paused = false
			if GameState.mode == GameState.Mode.STORY and GameState.league != null:
				# Modo Historia: registra el resultado, simula el resto de
				# la jornada, guarda el slot y vuelve a la clasificación.
				GameState.league.finish_player_round(home_score, away_score)
				get_tree().change_scene_to_file(LEAGUE_SCENE)
			else:
				get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return

	if event.is_action_pressed("switch_player"):
		_switch_to_nearest()
	elif event.is_action_pressed("gk_charge"):
		_set_gk_charge(true)
	elif event.is_action_released("gk_charge"):
		_set_gk_charge(false)
	elif event.is_action_pressed("tactic_offensive"):
		player_tactics.set_tactic(TacticsManager.Tactic.OFFENSIVE)
	elif event.is_action_pressed("tactic_balanced"):
		player_tactics.set_tactic(TacticsManager.Tactic.BALANCED)
	elif event.is_action_pressed("tactic_defensive"):
		player_tactics.set_tactic(TacticsManager.Tactic.DEFENSIVE)
	elif event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused

# --- Equipos ---------------------------------------------------------------

func _spawn_teams() -> void:
	home_players = _spawn_team(GameState.player_team, MatchRules.Side.HOME, player_tactics)
	away_players = _spawn_team(GameState.ai_team, MatchRules.Side.AWAY, ai_tactics)
	home_goalkeeper = home_players[0]
	# Con ambos equipos creados, cada IA conoce a compañeros y rivales.
	for p in home_players:
		var ai: AIController = p.get_node("AI")
		ai.teammates = home_players
		ai.opponents = away_players
	for p in away_players:
		var ai: AIController = p.get_node("AI")
		ai.teammates = away_players
		ai.opponents = home_players

func _spawn_team(team: TeamData, side: MatchRules.Side, tactics: TacticsManager) -> Array[PlayerCharacter]:
	var players: Array[PlayerCharacter] = []
	var squad := SquadFactory.build_squad(team)
	var slots := Formations.field_slots(team.formation)
	var mirror := 1.0 if side == MatchRules.Side.HOME else -1.0

	for i in squad.size():
		var p := PLAYER_SCENE.instantiate() as PlayerCharacter
		p.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(p)
		# El portero (índice 0) viste el color secundario para distinguirse.
		var color := team.secondary_color if i == 0 else team.primary_color
		p.setup(squad[i], side, color)

		var slot := slots[i] if i < slots.size() else Vector2.ZERO
		p.formation_spot = Vector2(
				slot.x * rules.field_half_length * mirror,
				slot.y * rules.field_half_width)
		p.global_position = p.formation_spot

		p.pass_requested.connect(_on_pass_requested)
		p.shot_requested.connect(_on_shot_requested)
		p.tackle_requested.connect(_on_tackle_requested)

		var ai := AIController.new()
		ai.name = "AI"
		ai.controlled_player = p
		ai.ball = ball
		ai.rules = rules
		ai.tactics = tactics
		ai.is_goalkeeper = i == 0
		p.add_child(ai)

		players.append(p)
	return players

func _all_players() -> Array[PlayerCharacter]:
	var all: Array[PlayerCharacter] = []
	all.append_array(home_players)
	all.append_array(away_players)
	return all

# --- Posesión y control ----------------------------------------------------

func _scan_loose_ball() -> void:
	if ball.carrier != null:
		return
	for p in _all_players():
		if not is_instance_valid(p):
			continue
		if p.global_position.distance_to(ball.global_position) < CONTROL_RADIUS \
				and ball.can_be_taken_by(p):
			_give_ball(p)
			return

func _give_ball(p: PlayerCharacter) -> void:
	ball.attach_to(p)
	# El control del usuario sigue al balón dentro de su equipo.
	if p.side == MatchRules.Side.HOME:
		_set_controlled(p)

func _set_controlled(p: PlayerCharacter) -> void:
	if p == null or user_controlled == p:
		return
	if user_controlled != null and is_instance_valid(user_controlled):
		user_controlled.is_user_controlled = false
		user_controlled.queue_redraw()
	user_controlled = p
	p.is_user_controlled = true
	p.queue_redraw()
	hud.track_player(p)

## Achique: mientras se mantiene Espacio, el portero (siempre IA) sale
## hacia el balón para tapar; al soltar vuelve a cubrir la portería.
func _set_gk_charge(active: bool) -> void:
	if home_goalkeeper == null or not is_instance_valid(home_goalkeeper):
		return
	var ai := home_goalkeeper.get_node_or_null("AI") as AIController
	if ai != null:
		ai.charging_out = active

func _switch_to_nearest() -> void:
	var best: PlayerCharacter = null
	var best_distance := INF
	for p in home_players:
		if not is_instance_valid(p) or p == user_controlled:
			continue
		var d := p.global_position.distance_to(ball.global_position)
		if d < best_distance:
			best_distance = d
			best = p
	if best != null:
		_set_controlled(best)

# --- Acciones con balón ----------------------------------------------------

func _on_pass_requested(player: PlayerCharacter, direction: Vector2, lofted: bool, power: float) -> void:
	if ball.carrier != player:
		return
	var stat := player.stats_component.get_stat(&"passing")
	var loft := (150.0 + 170.0 * power) if lofted else 0.0
	ball.kick(direction, stat * (0.55 + 0.5 * power), player.side, loft, player)

func _on_shot_requested(player: PlayerCharacter, direction: Vector2, power: float) -> void:
	if ball.carrier != player:
		return
	# Stat efectivo: aquí es donde Súper Tiro (x1.25 en datos) se nota.
	var stat := player.stats_component.get_stat(&"shot_power")
	ball.kick(direction, stat * (0.6 + 0.5 * power), player.side, 60.0 * power, player)

func _on_tackle_requested(tackler: PlayerCharacter, is_slide: bool) -> void:
	var carrier := ball.carrier
	if carrier == null or not is_instance_valid(carrier):
		return
	if carrier.side == tackler.side:
		return
	var reach := TACKLE_RANGE_SLIDE if is_slide else TACKLE_RANGE_STAND
	if tackler.global_position.distance_to(carrier.global_position) > reach:
		return

	# Timing: cuánto le falta al balón para estar al alcance de la pierna.
	var ball_distance := tackler.global_position.distance_to(ball.global_position)
	var timing_error := maxf(0.0, (ball_distance - BALL_REACH) / 60.0)
	# Ángulo: 0 grados = de frente al portador, 180 = por la espalda.
	var to_tackler := (tackler.global_position - carrier.global_position).normalized()
	var angle_deg := rad_to_deg(acos(clampf(carrier.facing.dot(to_tackler), -1.0, 1.0)))

	var result := foul_system.evaluate_tackle(
			tackler, carrier, timing_error, angle_deg,
			is_slide, tackler.sprinting,
			tackler.stats_component.get_stat(&"tackling"))

	if result == FoulSystem.TackleResult.CLEAN:
		_give_ball(tackler)

# --- Reglas: goles, saques, faltas -----------------------------------------

func _kickoff(kicking_side: MatchRules.Side) -> void:
	ball.stop_at(Vector2.ZERO)
	for p in _all_players():
		if not is_instance_valid(p):
			continue
		p.global_position = p.formation_spot
		p.velocity = Vector2.ZERO

	var taker := _most_advanced(kicking_side)
	if taker != null:
		# El que saca se coloca un paso hacia su propio campo.
		taker.global_position = Vector2(-rules.attack_direction(kicking_side) * 14.0, 0.0)
		_give_ball(taker)
	elif user_controlled == null:
		_switch_to_nearest()
	playing = true

func _most_advanced(side: MatchRules.Side) -> PlayerCharacter:
	var candidates := home_players if side == MatchRules.Side.HOME else away_players
	var forward := rules.attack_direction(side)
	var best: PlayerCharacter = null
	var best_x := -INF
	for p in candidates:
		if not is_instance_valid(p):
			continue
		if p.formation_spot.x * forward > best_x:
			best_x = p.formation_spot.x * forward
			best = p
	return best

func _on_goal_scored(scoring_side: MatchRules.Side) -> void:
	if scoring_side == MatchRules.Side.HOME:
		home_score += 1
	else:
		away_score += 1
	score_changed.emit(home_score, away_score)
	hud.show_message("¡GOOOL!")
	crowd.cheer(1.0)
	var conceding := MatchRules.Side.AWAY \
			if scoring_side == MatchRules.Side.HOME else MatchRules.Side.HOME
	_kickoff(conceding)

func _on_ball_out(restart: MatchRules.Restart, awarded_side: MatchRules.Side, out_position: Vector2) -> void:
	var spot := _restart_spot(restart, out_position)
	ball.stop_at(spot)
	var taker := _nearest_of_side(awarded_side, spot)
	if taker != null:
		taker.global_position = spot
		_give_ball(taker)

func _restart_spot(restart: MatchRules.Restart, out_position: Vector2) -> Vector2:
	# Margen de 20 px hacia dentro: el balón queda pegado al portador y no
	# debe volver a cruzar la línea en el mismo instante del saque.
	var x_sign := -1.0 if out_position.x < 0.0 else 1.0
	var y_sign := -1.0 if out_position.y < 0.0 else 1.0
	match restart:
		MatchRules.Restart.THROW_IN:
			return Vector2(
					clampf(out_position.x, -rules.field_half_length + 20.0, rules.field_half_length - 20.0),
					y_sign * (rules.field_half_width - 20.0))
		MatchRules.Restart.CORNER:
			return Vector2(
					x_sign * (rules.field_half_length - 20.0),
					y_sign * (rules.field_half_width - 20.0))
		MatchRules.Restart.GOAL_KICK:
			return Vector2(x_sign * (rules.field_half_length - 70.0), 0.0)
		_:
			return Vector2.ZERO

func _nearest_of_side(side: MatchRules.Side, spot: Vector2) -> PlayerCharacter:
	var candidates := home_players if side == MatchRules.Side.HOME else away_players
	var best: PlayerCharacter = null
	var best_distance := INF
	for p in candidates:
		if not is_instance_valid(p):
			continue
		var d := p.global_position.distance_to(spot)
		if d < best_distance:
			best_distance = d
			best = p
	return best

func _on_foul_committed(_offender: Node, victim: Node, _result: FoulSystem.TackleResult) -> void:
	hud.show_message("¡FALTA!")
	crowd.cheer(0.4)
	# Libre arcade: sin barreras ni pausa, la víctima recupera la posesión
	# en el punto de la infracción para no frenar el ritmo.
	var victim_player := victim as PlayerCharacter
	if victim_player != null and is_instance_valid(victim_player):
		_give_ball(victim_player)

func _on_card_shown(player: Node, card: FoulSystem.Card) -> void:
	if card == FoulSystem.Card.YELLOW:
		hud.show_message("TARJETA AMARILLA")
	else:
		hud.show_message("¡TARJETA ROJA!")
		_send_off(player as PlayerCharacter)

func _send_off(p: PlayerCharacter) -> void:
	if p == null or not is_instance_valid(p):
		return
	if ball.carrier == p:
		ball.release()
	home_players.erase(p)
	away_players.erase(p)
	if user_controlled == p:
		user_controlled = null
		_switch_to_nearest()
	p.queue_free()

## Swap clásico (decisión registrada): en la segunda parte los equipos
## intercambian campo; las posiciones de formación se espejan y las reglas
## invierten las direcciones de ataque.
func _swap_sides() -> void:
	rules.swap_sides()
	for p in _all_players():
		if is_instance_valid(p):
			p.formation_spot.x = -p.formation_spot.x

# --- Entrenador virtual y final de partido ---------------------------------

func _update_ai_coach() -> void:
	var goal_difference := away_score - home_score
	if goal_difference < 0:
		# Perdiendo: la IA se lanza al ataque en la segunda parte.
		ai_tactics.set_tactic(TacticsManager.Tactic.OFFENSIVE \
				if current_half == 2 else TacticsManager.Tactic.BALANCED)
	elif goal_difference >= 2:
		ai_tactics.set_tactic(TacticsManager.Tactic.DEFENSIVE)
	else:
		ai_tactics.set_tactic(TacticsManager.Tactic.BALANCED)

func _end_half() -> void:
	playing = false
	ball.release()
	half_ended.emit(current_half)
	if current_half == 1:
		current_half = 2
		elapsed = 0.0
		hud.show_message("DESCANSO", 2.5)
		_swap_sides()
		_kickoff(MatchRules.Side.AWAY)
		crowd.cheer(0.7)
	else:
		match_over = true
		match_ended.emit(home_score, away_score)
		hud.show_full_time(home_score, away_score)
		# Congela jugadores y balón; MatchManager (ALWAYS) sigue escuchando
		# el ENTER para volver al menú.
		get_tree().paused = true
