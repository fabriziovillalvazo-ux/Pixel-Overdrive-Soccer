class_name Ball
extends CharacterBody2D

## Balón con física arcade sencilla y sistema de posesión.
##
## El campo es el plano XY (vista lateral de TV); la altura del balón en
## pases elevados, centros y tiros se simula con `height` + gravedad y se
## dibuja desplazando el sprite y encogiendo la sombra (efecto 2D clásico).
##
## Posesión: cuando `carrier` no es null, el balón va pegado a los pies del
## jugador. Robarlo exige una entrada limpia (FoulSystem vía MatchManager);
## un balón suelto lo captura cualquier jugador cercano, salvo quien lo
## acaba de golpear durante un breve cooldown.

signal touched(by_side: MatchRules.Side)

const FRICTION := 220.0
const GRAVITY := 480.0
## Escala de fuerza por punto de stat (tiro/pase).
const POWER_TO_PIXELS := 5.2
## Distancia del balón a los pies del portador.
const CARRY_OFFSET := 9.0
const REPOSSESS_COOLDOWN := 0.3
## Por encima de esta altura el balón vuela sobre los jugadores (sin colisión).
const FLY_HEIGHT := 12.0

var height: float = 0.0
var height_velocity: float = 0.0
var last_touch_side: MatchRules.Side = MatchRules.Side.HOME
var carrier: PlayerCharacter = null

var _last_kicker: PlayerCharacter = null
var _repossess_cooldown := 0.0

func _physics_process(delta: float) -> void:
	_repossess_cooldown = maxf(0.0, _repossess_cooldown - delta)

	if carrier != null:
		if not is_instance_valid(carrier):
			carrier = null
		else:
			global_position = carrier.global_position + carrier.facing * CARRY_OFFSET
			velocity = Vector2.ZERO
			height = 0.0
			height_velocity = 0.0
			queue_redraw()
			return

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

	# Un centro por alto pasa por encima de los cuerpos.
	set_collision_mask_value(1, height <= FLY_HEIGHT)

	move_and_slide()
	queue_redraw()

func attach_to(player: PlayerCharacter) -> void:
	release()
	carrier = player
	player.has_ball = true
	last_touch_side = player.side
	velocity = Vector2.ZERO
	height = 0.0
	height_velocity = 0.0
	touched.emit(player.side)

func release() -> void:
	if carrier != null and is_instance_valid(carrier):
		carrier.has_ball = false
	carrier = null

## Golpea el balón: `power_stat` es el stat EFECTIVO del jugador (ya con
## Trait y estamina aplicados por StatsComponent), así Súper Tiro se nota.
func kick(direction: Vector2, power_stat: float, by_side: MatchRules.Side,
		loft: float = 0.0, kicker: PlayerCharacter = null) -> void:
	release()
	velocity = direction.normalized() * power_stat * POWER_TO_PIXELS
	height_velocity = loft
	last_touch_side = by_side
	_last_kicker = kicker
	_repossess_cooldown = REPOSSESS_COOLDOWN if kicker != null else 0.0
	touched.emit(by_side)

func can_be_taken_by(player: PlayerCharacter) -> bool:
	if height > FLY_HEIGHT:
		return false
	if _repossess_cooldown > 0.0 and player == _last_kicker:
		return false
	return true

func stop_at(position_on_field: Vector2) -> void:
	release()
	global_position = position_on_field
	velocity = Vector2.ZERO
	height = 0.0
	height_velocity = 0.0

func _draw() -> void:
	# Sombra en el suelo + balón elevado según la altura simulada.
	var shadow_scale := clampf(1.0 - height / 120.0, 0.4, 1.0)
	draw_circle(Vector2.ZERO, 3.0 * shadow_scale, Color(0, 0, 0, 0.35))
	draw_circle(Vector2(0, -height * 0.5), 3.0, Color.WHITE)
