class_name StaminaComponent
extends Node

## Gestiona la estamina de un jugador durante el partido.
##
## La estamina se consume al esprintar (y con acciones intensas como
## entradas o saltos) y se recupera lentamente al trotar o estar parado.
## Cuando baja de ciertos umbrales, degrada el rendimiento del jugador:
## primero el físico (velocidad, salto) y, si sigue cayendo, también
## el técnico (tiro, pase, entrada, control).

signal stamina_changed(current: float, maximum: float)
signal exhausted
signal recovered

## Stats considerados "físicos" y "técnicos" a efectos de degradación.
const PHYSICAL_STATS: Array[StringName] = [&"speed", &"jump"]
const TECHNICAL_STATS: Array[StringName] = [&"shot_power", &"passing", &"tackling", &"technique"]

@export_group("Consumo y recuperación (unidades/seg)")
@export var sprint_drain: float = 12.0
@export var jog_recovery: float = 4.0
@export var idle_recovery: float = 9.0
## Coste fijo de acciones puntuales.
@export var tackle_cost: float = 6.0
@export var jump_cost: float = 4.0

@export_group("Degradación de rendimiento")
## Por debajo de este porcentaje empieza a degradarse el físico.
@export_range(0.0, 1.0) var physical_threshold: float = 0.6
## Por debajo de este porcentaje empieza a degradarse también lo técnico.
@export_range(0.0, 1.0) var technical_threshold: float = 0.35
## Rendimiento físico mínimo con estamina a cero.
@export_range(0.1, 1.0) var physical_floor: float = 0.55
## Rendimiento técnico mínimo con estamina a cero.
@export_range(0.1, 1.0) var technical_floor: float = 0.7

var max_stamina: float = 100.0
var current: float = 100.0

var _was_exhausted := false

func setup(stats: PlayerStats) -> void:
	# La reserva real escala con el stat max_stamina (1-99 -> 60-158).
	max_stamina = 60.0 + float(stats.max_stamina)
	current = max_stamina

## Llamar cada frame desde el actor con su estado de movimiento.
func tick(delta: float, sprinting: bool, moving: bool) -> void:
	if sprinting and moving:
		_change(-sprint_drain * delta)
	elif moving:
		_change(jog_recovery * delta)
	else:
		_change(idle_recovery * delta)

func spend(amount: float) -> void:
	_change(-amount)

func ratio() -> float:
	return current / max_stamina

## Factor multiplicador (0-1] que StatsComponent aplica a cada stat.
func get_performance_factor(stat_name: StringName) -> float:
	var r := ratio()
	if stat_name in PHYSICAL_STATS:
		return _degradation(r, physical_threshold, physical_floor)
	if stat_name in TECHNICAL_STATS:
		return _degradation(r, technical_threshold, technical_floor)
	return 1.0

func _degradation(r: float, threshold: float, floor_value: float) -> float:
	if r >= threshold:
		return 1.0
	# Interpolación lineal entre rendimiento pleno (en el umbral)
	# y el suelo de rendimiento (con estamina a cero).
	return lerpf(floor_value, 1.0, r / threshold)

func _change(amount: float) -> void:
	var previous := current
	current = clampf(current + amount, 0.0, max_stamina)
	if is_equal_approx(previous, current):
		return
	stamina_changed.emit(current, max_stamina)
	if current <= 0.0 and not _was_exhausted:
		_was_exhausted = true
		exhausted.emit()
	elif _was_exhausted and ratio() > 0.25:
		_was_exhausted = false
		recovered.emit()
