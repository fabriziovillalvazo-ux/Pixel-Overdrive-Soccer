class_name PlayerStats
extends Resource

## Stats base de un jugador (escala 1-99). 100% ficticios.
##
## Estos valores son la "carta" del jugador: nunca se modifican en partido.
## Los valores efectivos (con Trait y fatiga aplicados) los calcula
## StatsComponent en tiempo real.

enum FieldPosition { POR, DEF, MED, DEL }

@export var player_name: String = "Jugador"
@export var field_position: FieldPosition = FieldPosition.MED

@export_group("Físico")
## Velocidad de carrera.
@export_range(1, 99) var speed: int = 50
## Potencia y altura de salto (cabezazos, despejes, paradas).
@export_range(1, 99) var jump: int = 50
## Reserva máxima de estamina.
@export_range(1, 99) var max_stamina: int = 70

@export_group("Técnico")
## Potencia de tiro.
@export_range(1, 99) var shot_power: int = 50
## Precisión de pase.
@export_range(1, 99) var passing: int = 50
## Calidad de entrada / robo de balón.
@export_range(1, 99) var tackling: int = 50
## Control de balón y regate.
@export_range(1, 99) var technique: int = 50

@export_group("Rasgo único")
## Trait especial (null para jugadores sin rasgo).
## El multiplicador vive dentro del recurso TraitData, no en el código.
@export var special_trait: TraitData

func has_trait() -> bool:
	return special_trait != null

func position_short_name() -> String:
	return FieldPosition.keys()[field_position]
