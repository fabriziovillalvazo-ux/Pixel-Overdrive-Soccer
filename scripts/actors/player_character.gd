class_name PlayerCharacter
extends CharacterBody2D

## Jugador de campo (controlado por el usuario o por la IA).
##
## Controles (solo teclado + ratón, ver GDD sección 4):
##   - WASD: movimiento.  Shift: sprint (consume estamina).
##   - El RATÓN apunta: la dirección de pase/centro/tiro es hacia el cursor.
##   - Clic izquierdo: pase raso (con balón) / entrada normal (sin balón).
##   - Clic derecho: tiro a puerta (con balón) / segada (sin balón).
##   - E: pase elevado / centro al área.
##   - Potencia por mantenimiento: mantener pulsada la acción carga la
##     potencia (0.4 → 1.0 en 0.8 s); soltar la ejecuta.
##
## La escena player.tscn monta los componentes como nodos hijos
## (arquitectura por componentes): StatsComponent y StaminaComponent.

signal pass_requested(player: PlayerCharacter, direction: Vector2, lofted: bool, power: float)
signal shot_requested(player: PlayerCharacter, direction: Vector2, power: float)
signal tackle_requested(player: PlayerCharacter, is_slide: bool)

## Escala px/seg por punto de stat de velocidad.
## Decisión registrada (ritmo de juego): base contenida para un juego más
## técnico, con un sprint muy explosivo que conserva el toque frenético.
const SPEED_TO_PIXELS := 1.15
const SPRINT_MULTIPLIER := 1.55
const MAX_CHARGE_TIME := 0.8
const MIN_POWER := 0.4
const TACKLE_COOLDOWN := 0.6

@onready var stats_component: StatsComponent = $StatsComponent
@onready var stamina_component: StaminaComponent = $StaminaComponent

## true mientras este jugador es el que controla el usuario.
var is_user_controlled := false
## true si este jugador tiene el balón en los pies (lo mantiene Ball).
var has_ball := false
## Lado del campo al que pertenece (MatchRules.Side).
var side: MatchRules.Side = MatchRules.Side.HOME
## Color de camiseta (placeholder visual hasta tener sprites de Aseprite).
var shirt_color: Color = Color.WHITE
## true mientras esprinta (lo consulta el FoulSystem al evaluar entradas).
var sprinting := false
## Última dirección de movimiento; orienta la conducción del balón.
var facing := Vector2.RIGHT
## Posición base de su hueco en la formación (la fija el MatchManager).
var formation_spot := Vector2.ZERO

var _charging_action: StringName = &""
var _charge_time := 0.0
var _tackle_cooldown := 0.0
var _dust_timer := 0.0

func setup(player_stats: PlayerStats, team_side: MatchRules.Side, color: Color) -> void:
	stats_component.stats = player_stats
	stats_component.stamina_component = stamina_component
	stamina_component.setup(player_stats)
	side = team_side
	shirt_color = color
	queue_redraw()

func _physics_process(delta: float) -> void:
	_tackle_cooldown = maxf(0.0, _tackle_cooldown - delta)

	if is_user_controlled:
		_process_user_input(delta)
		queue_redraw()
	else:
		# La IA (AIController, nodo hijo) fija `velocity`; aquí solo
		# se contabiliza su estamina.
		stamina_component.tick(delta, sprinting, velocity.length() > 5.0)

	if _charging_action != &"" and (not is_user_controlled or not has_ball):
		_cancel_charge()
	if _charging_action != &"":
		_charge_time = minf(_charge_time + delta, MAX_CHARGE_TIME)

	if velocity.length() > 5.0:
		facing = velocity.normalized()

	move_and_slide()

func _process_user_input(delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	sprinting = Input.is_action_pressed("sprint") and stamina_component.current > 0.0

	var speed := stats_component.get_stat(&"speed") * SPEED_TO_PIXELS
	if sprinting:
		speed *= SPRINT_MULTIPLIER

	velocity = input_direction * speed
	stamina_component.tick(delta, sprinting, input_direction != Vector2.ZERO)

	# Estela de polvo al esprintar (estilo de la referencia visual).
	if sprinting and input_direction != Vector2.ZERO:
		_dust_timer -= delta
		if _dust_timer <= 0.0:
			_dust_timer = 0.22
			_spawn_dust()

func _unhandled_input(event: InputEvent) -> void:
	if not is_user_controlled:
		return

	if event.is_action_pressed("action_primary"):
		if has_ball:
			_start_charge(&"pass")
		else:
			try_tackle(false)
	elif event.is_action_released("action_primary"):
		_release_charge(&"pass")
	elif event.is_action_pressed("action_secondary"):
		if has_ball:
			_start_charge(&"shot")
		else:
			try_tackle(true)
	elif event.is_action_released("action_secondary"):
		_release_charge(&"shot")
	elif event.is_action_pressed("action_lob"):
		if has_ball:
			_start_charge(&"lob")
	elif event.is_action_released("action_lob"):
		_release_charge(&"lob")

## Entrada con cooldown y coste de estamina; la usan el input del usuario
## y la IA. El MatchManager resuelve el resultado con el FoulSystem.
func try_tackle(is_slide: bool) -> void:
	if _tackle_cooldown > 0.0:
		return
	_tackle_cooldown = TACKLE_COOLDOWN
	stamina_component.spend(stamina_component.tackle_cost)
	_spawn_dust()
	tackle_requested.emit(self, is_slide)

## Dirección normalizada hacia el cursor: el ratón siempre apunta.
func aim_direction() -> Vector2:
	var to_mouse := get_global_mouse_position() - global_position
	return to_mouse.normalized() if to_mouse.length() > 0.01 else facing

func is_charging() -> bool:
	return _charging_action != &""

func charge_power() -> float:
	return MIN_POWER + (1.0 - MIN_POWER) * (_charge_time / MAX_CHARGE_TIME)

func _start_charge(action: StringName) -> void:
	_charging_action = action
	_charge_time = 0.0

func _release_charge(action: StringName) -> void:
	if _charging_action != action:
		return
	var power := charge_power()
	_cancel_charge()
	if not has_ball:
		return
	match action:
		&"pass":
			pass_requested.emit(self, aim_direction(), false, power)
		&"lob":
			pass_requested.emit(self, aim_direction(), true, power)
		&"shot":
			shot_requested.emit(self, aim_direction(), power)

func _cancel_charge() -> void:
	_charging_action = &""
	_charge_time = 0.0

func _spawn_dust() -> void:
	if not is_inside_tree():
		return
	var puff := DustPuff.new()
	get_parent().add_child(puff)
	puff.global_position = global_position + Vector2(0, 8)

func _draw() -> void:
	# Placeholder fiel al estilo de referencia (proporciones compactas con
	# cabeza grande y contorno oscuro) hasta integrar sprites de Aseprite.
	var outline := Color(0.08, 0.07, 0.1)
	draw_rect(Rect2(-6, -12, 12, 22), outline)
	draw_circle(Vector2(0, -7), 4.0, Color(0.96, 0.8, 0.65))
	draw_rect(Rect2(-5, -3, 10, 8), shirt_color)
	draw_rect(Rect2(-5, 5, 10, 4), shirt_color.darkened(0.55))
	if is_user_controlled:
		# Flecha de selección sobre la cabeza, como en la referencia.
		var arrow := PackedVector2Array([
			Vector2(-4, -20), Vector2(4, -20), Vector2(0, -14)])
		draw_colored_polygon(arrow, Color(1.0, 0.9, 0.2))
		if has_ball:
			var length := 14.0 + 22.0 * (charge_power() if is_charging() else 0.0)
			draw_line(Vector2.ZERO, aim_direction() * length, Color(1, 1, 1, 0.7), 1.0)
