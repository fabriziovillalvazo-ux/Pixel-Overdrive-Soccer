class_name TraitData
extends Resource

## Rasgo único ("Trait") de un jugador estrella.
##
## REGLA DE DISEÑO: el multiplicador vive AQUÍ, en los datos (.tres),
## nunca hardcodeado en la lógica de juego. StatsComponent lee este
## recurso y aplica `multiplier` al stat indicado en `affected_stat`.
## Para rebalancear un Trait basta editar su .tres, sin tocar código.

## Nombre visible del rasgo (p. ej. "Súper Tiro").
@export var trait_name: String = ""

## Descripción corta para UI / fichas de jugador.
@export_multiline var description: String = ""

## Stat de PlayerStats al que afecta el rasgo.
## Debe coincidir con el nombre de la propiedad: "shot_power", "speed", "jump"...
@export var affected_stat: StringName = &""

## Multiplicador aplicado al stat base. El valor de producto (x1.25)
## está definido en los archivos resources/traits/*.tres.
@export_range(1.0, 2.0, 0.01) var multiplier: float = 1.0
