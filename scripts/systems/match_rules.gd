class_name MatchRules
extends Node

## Reglas de partido de Pixel Overdrive Soccer.
##
## ============================================================
##  DECISIÓN DE DISEÑO: NO EXISTE EL FUERA DE JUEGO (OFFSIDE).
##  No es un olvido ni un TODO: el juego busca ritmo arcade con
##  desmarques profundos constantes. OFFSIDE_ENABLED se mantiene
##  como constante documental y no debe activarse.
## ============================================================

signal goal_scored(scoring_side: Side)
signal ball_out(restart: Restart, side: Side, out_position: Vector2)

enum Side { HOME, AWAY }
enum Restart { THROW_IN, CORNER, GOAL_KICK, KICKOFF }

const OFFSIDE_ENABLED := false

@export_group("Duración")
## Minutos reales por parte (2 partes por partido).
@export var half_duration_minutes: float = 5.0

@export_group("Campo (px, centrado en el origen)")
@export var field_half_length: float = 560.0
@export var field_half_width: float = 170.0
@export var goal_half_height: float = 28.0

## Siempre false: el fuera de juego está deshabilitado por diseño.
## La función existe solo para dejar constancia explícita de la decisión.
func is_offside(_attacker_position: Vector2, _defenders: Array) -> bool:
	return OFFSIDE_ENABLED

## Comprueba la posición del balón y emite gol / saque cuando corresponde.
## Devuelve true si el balón sigue en juego.
func check_ball_position(ball_position: Vector2, last_touch_side: Side) -> bool:
	# Banda superior o inferior -> saque de banda.
	if absf(ball_position.y) > field_half_width:
		ball_out.emit(Restart.THROW_IN, _opponent(last_touch_side), ball_position)
		return false

	# Línea de fondo.
	if absf(ball_position.x) > field_half_length:
		if absf(ball_position.y) <= goal_half_height:
			# GOL: en la portería izquierda (x negativa) marca el visitante.
			var scorer := Side.AWAY if ball_position.x < 0.0 else Side.HOME
			goal_scored.emit(scorer)
			return false
		# Fuera por la línea de fondo: córner o saque de puerta según
		# quién tocó por última vez.
		var defending_side := Side.HOME if ball_position.x < 0.0 else Side.AWAY
		if last_touch_side == defending_side:
			ball_out.emit(Restart.CORNER, _opponent(defending_side), ball_position)
		else:
			ball_out.emit(Restart.GOAL_KICK, defending_side, ball_position)
		return false

	return true

func half_duration_seconds() -> float:
	return half_duration_minutes * 60.0

func _opponent(side: Side) -> Side:
	return Side.AWAY if side == Side.HOME else Side.HOME
