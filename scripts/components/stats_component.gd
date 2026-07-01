class_name StatsComponent
extends Node

## Expone los stats EFECTIVOS de un jugador en partido.
##
## Valor efectivo = stat base (PlayerStats)
##                x multiplicador de Trait (TraitData, si aplica a ese stat)
##                x factor de rendimiento por estamina (StaminaComponent).
##
## El multiplicador del Trait se lee del recurso: aquí no hay ningún
## número mágico. Los valores efectivos pueden superar 99 (p. ej. un
## tiro 88 con Súper Tiro rinde 110): es intencional, los Traits deben
## sentirse arcade.

## Carta base del jugador (recurso .tres o generado por SquadFactory).
@export var stats: PlayerStats

## Componente de estamina hermano; si es null, no se aplica fatiga.
@export var stamina_component: StaminaComponent

## Devuelve el valor efectivo de un stat ("speed", "shot_power", "jump",
## "passing", "tackling", "technique").
func get_stat(stat_name: StringName) -> float:
	if stats == null:
		push_warning("StatsComponent sin PlayerStats asignado en %s" % get_path())
		return 0.0

	var value := float(stats.get(stat_name))

	# Trait: el multiplicador vive en el recurso TraitData (dato, no código).
	if stats.has_trait() and stats.special_trait.affected_stat == stat_name:
		value *= stats.special_trait.multiplier

	# Fatiga: degrada el rendimiento físico y técnico.
	if stamina_component != null:
		value *= stamina_component.get_performance_factor(stat_name)

	return value

## Valor base sin modificadores (para fichas / UI de alineación).
func get_base_stat(stat_name: StringName) -> float:
	if stats == null:
		return 0.0
	return float(stats.get(stat_name))
