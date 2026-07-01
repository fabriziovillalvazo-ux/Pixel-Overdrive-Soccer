class_name Ball
extends CharacterBody2D

## Balón con física arcade sencilla.
##
## El campo es el plano XY (vista lateral de TV); la altura del balón en
## pases elevados, centros y tiros se simula con `height` + gravedad y se
## dibuja desplazando el sprite y encogiendo la sombra (efecto 2D clásico).

signal touched(by_side: MatchRules.Side)

const FRICTION := 220.0
const GRAVITY := 480.0
## Escala de fuerza por punto de stat (tiro/pase).
const POWER_TO_PIXELS := 5.2

var height: float = 0.0
var height_velocity: float = 0.0
var last_touch_side: MatchRules.Side = MatchRules.Side.HOME

func _physics_process(delta: float) -> void:
	# Rozadura con el césped (solo cuando rueda por el suelo).
	if height <= 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	# Vuelo: altura simulada con gravedad y bote amortiguado.
	if height > 0.0 or height_velocity != 0.0:
		height_velocity -= GRAVITY * delta
		height += height_velocity * delta
		if height <= 0.0:
			height = 0.0
			height_velocity = -height_velocity * 0.45
			if absf(height_velocity) < 30.0:
				height_velocity = 0.0

	move_and_slide()
	queue_redraw()

## Golpea el balón: `power_stat` es el stat EFECTIVO del jugador (ya con
## Trait y estamina aplicados por StatsComponent), así Súper Tiro se nota.
func kick(direction: Vector2, power_stat: float, by_side: MatchRules.Side, loft: float = 0.0) -> void:
	velocity = direction.normalized() * power_stat * POWER_TO_PIXELS
	height_velocity = loft
	last_touch_side = by_side
	touched.emit(by_side)

func stop_at(position_on_field: Vector2) -> void:
	global_position = position_on_field
	velocity = Vector2.ZERO
	height = 0.0
	height_velocity = 0.0

func _draw() -> void:
	# Sombra en el suelo + balón elevado según la altura simulada.
	var shadow_scale := clampf(1.0 - height / 120.0, 0.4, 1.0)
	draw_circle(Vector2.ZERO, 3.0 * shadow_scale, Color(0, 0, 0, 0.35))
	draw_circle(Vector2(0, -height * 0.5), 3.0, Color.WHITE)
