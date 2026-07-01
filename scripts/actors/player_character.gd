class_name PlayerCharacter
extends CharacterBody2D

## Jugador de campo (controlado por el usuario o por la IA).
##
## Controles (solo teclado + ratón, ver GDD sección 5):
##   - WASD: movimiento.  Shift: sprint (consume estamina).
##   - El RATÓN apunta: la dirección de pase/centro/tiro es hacia el cursor.
##   - Clic izquierdo: pase raso (con balón) / entrada normal (sin balón).
##   - Clic derecho: tiro a puerta (con balón) / segada (sin balón).
##   - E: pase elevado / centro al área.
##
## La escena player.tscn monta los componentes como nodos hijos
## (arquitectura por componentes): StatsComponent y StaminaComponent.

signal pass_requested(player: PlayerCharacter, direction: Vector2, lofted: bool)
signal shot_requested(player: PlayerCharacter, direction: Vector2)
signal tackle_requested(player: PlayerCharacter, is_slide: bool)

## Escala px/seg por punto de stat de velocidad.
const SPEED_TO_PIXELS := 1.35
const SPRINT_MULTIPLIER := 1.4

@onready var stats_component: StatsComponent = $StatsComponent
@onready var stamina_component: StaminaComponent = $StaminaComponent

## true mientras este jugador es el que controla el usuario.
var is_user_controlled := false
## true si este jugador tiene el balón en los pies.
var has_ball := false
## Lado del campo al que pertenece (MatchRules.Side).
var side: MatchRules.Side = MatchRules.Side.HOME
## Color de camiseta (placeholder visual hasta tener sprites de Aseprite).
var shirt_color: Color = Color.WHITE

func setup(player_stats: PlayerStats, team_side: MatchRules.Side, color: Color) -> void:
	stats_component.stats = player_stats
	stats_component.stamina_component = stamina_component
	stamina_component.setup(player_stats)
	side = team_side
	shirt_color = color
	queue_redraw()

func _physics_process(delta: float) -> void:
	if is_user_controlled:
		_process_user_input(delta)
	# La IA mueve al jugador a través de AIController (nodo hermano en la
	# escena de partido) fijando `velocity` antes de este punto.
	move_and_slide()

func _process_user_input(delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var sprinting := Input.is_action_pressed("sprint") and stamina_component.current > 0.0

	var speed := stats_component.get_stat(&"speed") * SPEED_TO_PIXELS
	if sprinting:
		speed *= SPRINT_MULTIPLIER

	velocity = input_direction * speed
	stamina_component.tick(delta, sprinting, input_direction != Vector2.ZERO)

func _unhandled_input(event: InputEvent) -> void:
	if not is_user_controlled:
		return

	if event.is_action_pressed("action_primary"):
		if has_ball:
			pass_requested.emit(self, aim_direction(), false)
		else:
			stamina_component.spend(stamina_component.tackle_cost)
			tackle_requested.emit(self, false)
	elif event.is_action_pressed("action_secondary"):
		if has_ball:
			shot_requested.emit(self, aim_direction())
		else:
			stamina_component.spend(stamina_component.tackle_cost)
			tackle_requested.emit(self, true)
	elif event.is_action_pressed("action_lob") and has_ball:
		pass_requested.emit(self, aim_direction(), true)

## Dirección normalizada hacia el cursor: el ratón siempre apunta.
func aim_direction() -> Vector2:
	var to_mouse := get_global_mouse_position() - global_position
	return to_mouse.normalized() if to_mouse.length() > 0.01 else Vector2.RIGHT

func _draw() -> void:
	# Placeholder hasta integrar los sprites de Aseprite:
	# rectángulo con el color del equipo + marcador de selección.
	draw_rect(Rect2(-5, -8, 10, 16), shirt_color)
	if is_user_controlled:
		draw_arc(Vector2(0, 10), 7.0, 0.0, TAU, 16, Color.WHITE, 1.0)
