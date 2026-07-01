class_name AIController
extends Node

## IA de la escuadra enemiga (y de los compañeros no controlados).
##
## Máquina de estados sencilla por jugador; los parámetros de comportamiento
## colectivo (altura de líneas, presión, apoyo) llegan del TacticsManager
## del equipo, de modo que cambiar de táctica se nota de inmediato.
## Se instala como nodo hijo de cada PlayerCharacter y se desactiva sola
## mientras el usuario controla a ese jugador.

enum State { POSITION, CHASE_BALL, ATTACK }

@export var reaction_time: float = 0.25

var tactics: TacticsManager
var controlled_player: PlayerCharacter
var ball: Ball
var rules: MatchRules
var teammates: Array[PlayerCharacter] = []
var opponents: Array[PlayerCharacter] = []
var is_goalkeeper := false

var _state: State = State.POSITION
var _think_timer := 0.0
var _action_cooldown := 0.0

func _physics_process(delta: float) -> void:
	if controlled_player == null or ball == null:
		return
	if controlled_player.is_user_controlled:
		return

	_action_cooldown = maxf(0.0, _action_cooldown - delta)
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = reaction_time
		_state = _decide_state()
	_act()

func _decide_state() -> State:
	if controlled_player.has_ball:
		return State.ATTACK
	if is_goalkeeper:
		return State.POSITION
	if ball.carrier != null and ball.carrier.side == controlled_player.side:
		return State.POSITION
	# Presiona solo el jugador del equipo más cercano al balón, para que
	# el bloque no se amontone; el radio de presión depende de la táctica.
	var pressure_radius := 90.0 * (tactics.get_modifier("pressure") if tactics else 1.0)
	var distance_to_ball := controlled_player.global_position.distance_to(ball.global_position)
	if distance_to_ball < pressure_radius and _is_closest_teammate_to_ball(distance_to_ball):
		return State.CHASE_BALL
	return State.POSITION

func _act() -> void:
	match _state:
		State.CHASE_BALL:
			_move_towards(ball.global_position)
			_try_defensive_tackle()
		State.POSITION:
			_move_towards(_position_target())
		State.ATTACK:
			_attack()

func _position_target() -> Vector2:
	if is_goalkeeper:
		# El portero cubre la portería siguiendo la altura del balón.
		var target := controlled_player.formation_spot
		target.y = clampf(ball.global_position.y,
				-rules.goal_half_height * 1.4, rules.goal_half_height * 1.4)
		return target

	var target := controlled_player.formation_spot
	var forward := 1.0 if controlled_player.side == MatchRules.Side.HOME else -1.0
	if tactics:
		# La táctica desplaza la posición base hacia el ataque o la defensa.
		target.x += tactics.get_modifier("line_height") * 120.0 * forward
	# Deriva hacia el balón para que el bloque acompañe el juego.
	target.x += (ball.global_position.x - target.x) * 0.25
	target.y += (ball.global_position.y - target.y) * 0.2
	return target

func _attack() -> void:
	var goal_x := rules.field_half_length \
			if controlled_player.side == MatchRules.Side.HOME \
			else -rules.field_half_length
	var goal_center := Vector2(goal_x, 0.0)
	var pos := controlled_player.global_position

	# El portero no conduce: despeja largo en cuanto puede.
	if is_goalkeeper:
		if _action_cooldown <= 0.0:
			var open_mate := _best_pass_option(goal_x)
			if open_mate != null:
				_action_cooldown = 1.0
				var to_mate := open_mate.global_position - pos
				controlled_player.pass_requested.emit(
						controlled_player, to_mate.normalized(), true, 1.0)
		return

	if _action_cooldown <= 0.0:
		# A tiro: dispara con potencia alta.
		if pos.distance_to(goal_center) < 190.0:
			_action_cooldown = 0.8
			controlled_player.shot_requested.emit(
					controlled_player, (goal_center - pos).normalized(), randf_range(0.7, 1.0))
			return
		# Presionado: busca el pase que más acerque al gol.
		if _nearest_opponent_distance() < 34.0:
			var mate := _best_pass_option(goal_x)
			if mate != null:
				_action_cooldown = 0.8
				var to_mate := mate.global_position - pos
				var power := clampf(to_mate.length() / 260.0, 0.4, 1.0)
				controlled_player.pass_requested.emit(
						controlled_player, to_mate.normalized(), to_mate.length() > 200.0, power)
				return

	# Conduce hacia la portería manteniendo su carril de la formación.
	_move_towards(Vector2(goal_x, controlled_player.formation_spot.y * 0.4))

func _try_defensive_tackle() -> void:
	var carrier := ball.carrier
	if carrier == null or not is_instance_valid(carrier):
		return
	if carrier.side == controlled_player.side:
		return
	if controlled_player.global_position.distance_to(carrier.global_position) < 16.0:
		controlled_player.try_tackle(false)

func _is_closest_teammate_to_ball(my_distance: float) -> bool:
	for mate in teammates:
		if mate == controlled_player or not is_instance_valid(mate):
			continue
		if mate.global_position.distance_to(ball.global_position) < my_distance - 4.0:
			return false
	return true

func _nearest_opponent_distance() -> float:
	var nearest := INF
	for opponent in opponents:
		if not is_instance_valid(opponent):
			continue
		nearest = minf(nearest, controlled_player.global_position.distance_to(opponent.global_position))
	return nearest

func _best_pass_option(goal_x: float) -> PlayerCharacter:
	var best: PlayerCharacter = null
	var best_score := -INF
	for mate in teammates:
		if mate == controlled_player or not is_instance_valid(mate):
			continue
		var distance := controlled_player.global_position.distance_to(mate.global_position)
		if distance < 40.0 or distance > 300.0:
			continue
		# Mejor cuanto más cerca del gol rival y más cerca del pasador.
		var score := -absf(goal_x - mate.global_position.x) - distance * 0.3
		if score > best_score:
			best_score = score
			best = mate
	return best

func _move_towards(target: Vector2) -> void:
	var to_target := target - controlled_player.global_position
	if to_target.length() < 6.0:
		controlled_player.velocity = Vector2.ZERO
		return
	controlled_player.sprinting = false
	var speed := controlled_player.stats_component.get_stat(&"speed") \
			* PlayerCharacter.SPEED_TO_PIXELS
	controlled_player.velocity = to_target.normalized() * speed
