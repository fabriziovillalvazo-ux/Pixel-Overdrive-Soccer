class_name FoulSystem
extends Node

## Sistema de faltas y tarjetas.
##
## Cada entrada (tackle) se evalúa según:
##   - TIMING: cuánto llegó tarde el defensor respecto a la ventana en la
##     que el balón era jugable (0 = perfecto; >0 = segundos tarde).
##   - ÁNGULO: dirección de la entrada respecto al rival. Entrar de frente
##     es más limpio; por la espalda (>120 grados) agrava la falta.
##   - INTENSIDAD: las segadas (slide) y entrar al sprint agravan el resultado.
##
## El resultado se decide con una puntuación de severidad acumulada,
## con umbrales configurables desde el inspector.

signal foul_committed(offender: Node, victim: Node, result: TackleResult)
signal card_shown(player: Node, card: Card)

enum TackleResult { CLEAN, FOUL, YELLOW_CARD, RED_CARD }
enum Card { NONE, YELLOW, RED }

@export_group("Timing")
## Margen (seg) en el que la entrada se considera perfectamente limpia.
@export var clean_window: float = 0.15
## Severidad añadida por cada segundo de retraso.
@export var late_severity_per_second: float = 4.0

@export_group("Ángulo")
## A partir de este ángulo (grados) la entrada cuenta como "por la espalda".
@export var back_tackle_angle: float = 120.0
@export var back_tackle_severity: float = 1.5

@export_group("Intensidad")
@export var slide_severity: float = 0.75
@export var sprint_severity: float = 0.5

@export_group("Umbrales de sanción")
@export var foul_threshold: float = 1.0
@export var yellow_threshold: float = 2.0
@export var red_threshold: float = 3.5

## Tarjetas acumuladas por jugador (instance_id -> amarillas).
var _yellow_cards: Dictionary = {}

## Evalúa una entrada y emite las señales correspondientes.
## - timing_error: segundos de retraso respecto al último toque de balón.
## - approach_angle_deg: ángulo entrada-rival (0 = de frente, 180 = por detrás).
## - is_slide: true si fue una segada (clic derecho en defensa).
## - is_sprinting: true si el defensor entró al sprint.
## - tackling_stat: stat efectivo de entrada del defensor (1-99+), reduce severidad.
func evaluate_tackle(
	offender: Node,
	victim: Node,
	timing_error: float,
	approach_angle_deg: float,
	is_slide: bool,
	is_sprinting: bool,
	tackling_stat: float
) -> TackleResult:
	var severity := 0.0

	var lateness := maxf(0.0, timing_error - clean_window)
	severity += lateness * late_severity_per_second

	if absf(approach_angle_deg) >= back_tackle_angle:
		severity += back_tackle_severity

	if is_slide:
		severity += slide_severity
	if is_sprinting:
		severity += sprint_severity

	# Un buen stat de entrada "perdona" parte de la severidad (hasta ~33%).
	severity *= 1.0 - clampf(tackling_stat / 99.0, 0.0, 1.0) * 0.33

	var result := _severity_to_result(severity)
	_apply_result(offender, victim, result)
	return result

func _severity_to_result(severity: float) -> TackleResult:
	if severity >= red_threshold:
		return TackleResult.RED_CARD
	if severity >= yellow_threshold:
		return TackleResult.YELLOW_CARD
	if severity >= foul_threshold:
		return TackleResult.FOUL
	return TackleResult.CLEAN

func _apply_result(offender: Node, victim: Node, result: TackleResult) -> void:
	if result == TackleResult.CLEAN:
		return

	foul_committed.emit(offender, victim, result)

	match result:
		TackleResult.YELLOW_CARD:
			_give_yellow(offender)
		TackleResult.RED_CARD:
			card_shown.emit(offender, Card.RED)

func _give_yellow(offender: Node) -> void:
	var id := offender.get_instance_id()
	var yellows: int = _yellow_cards.get(id, 0) + 1
	_yellow_cards[id] = yellows
	if yellows >= 2:
		# Doble amarilla = roja.
		card_shown.emit(offender, Card.RED)
	else:
		card_shown.emit(offender, Card.YELLOW)

func reset() -> void:
	_yellow_cards.clear()
