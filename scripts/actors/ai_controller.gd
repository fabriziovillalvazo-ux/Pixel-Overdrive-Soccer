class_name AIController
extends Node

## IA de la escuadra enemiga (y de los compañeros no controlados).
##
## Máquina de estados sencilla por jugador; los parámetros de comportamiento
## colectivo (altura de líneas, presión, apoyo) llegan del TacticsManager
## del equipo, de modo que cambiar de táctica se nota de inmediato.
##
## ESQUELETO: el árbol de decisión está definido; la implementación fina
## (elección de pase, coberturas, marcajes) es trabajo del hito M3 del GDD.

enum State { POSITION, CHASE_BALL, ATTACK, DEFEND, SUPPORT }

@export var reaction_time: float = 0.25

var tactics: TacticsManager
var controlled_player: PlayerCharacter
var ball: Ball
var home_position: Vector2

var _state: State = State.POSITION
var _think_timer := 0.0

func _physics_process(delta: float) -> void:
	if controlled_player == null or ball == null:
		return
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = reaction_time
		_state = _decide_state()
	_act(delta)

func _decide_state() -> State:
	if controlled_player.has_ball:
		return State.ATTACK
	var distance_to_ball := controlled_player.global_position.distance_to(ball.global_position)
	var pressure_radius := 90.0 * (tactics.get_modifier("pressure") if tactics else 1.0)
	if distance_to_ball < pressure_radius and ball.last_touch_side != controlled_player.side:
		return State.CHASE_BALL
	return State.POSITION

func _act(_delta: float) -> void:
	match _state:
		State.CHASE_BALL:
			_move_towards(ball.global_position)
		State.POSITION:
			var target := home_position
			if tactics:
				# La táctica desplaza la posición base hacia el ataque o la defensa.
				var forward := 1.0 if controlled_player.side == MatchRules.Side.HOME else -1.0
				target.x += tactics.get_modifier("line_height") * 120.0 * forward
			_move_towards(target)
		State.ATTACK:
			# TODO(M3): decidir entre conducir, pasar al mejor desmarcado o tirar.
			pass
		State.DEFEND, State.SUPPORT:
			# TODO(M3): marcajes y líneas de pase de apoyo.
			pass

func _move_towards(target: Vector2) -> void:
	var to_target := target - controlled_player.global_position
	if to_target.length() < 6.0:
		controlled_player.velocity = Vector2.ZERO
		return
	var speed := controlled_player.stats_component.get_stat(&"speed") \
			* PlayerCharacter.SPEED_TO_PIXELS
	controlled_player.velocity = to_target.normalized() * speed
	controlled_player.stamina_component.tick(get_physics_process_delta_time(), false, true)
