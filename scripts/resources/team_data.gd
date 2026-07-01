class_name TeamData
extends Resource

## Datos de un equipo de la Liga Overdrive. Equipos y jugadores 100% ficticios.
##
## Cada equipo define a su jugador estrella (con Trait) de forma explícita;
## el resto de la plantilla se genera en tiempo de ejecución a partir de
## `roster_names` y `base_overall` (ver SquadFactory), manteniendo los
## archivos de datos compactos y editables.

@export var team_name: String = ""
@export var short_name: String = ""

@export_group("Identidad visual")
@export var primary_color: Color = Color.WHITE
@export var secondary_color: Color = Color.BLACK

@export_group("Deportivo")
## Formación por defecto (se combina con la táctica en partido).
@export var formation: String = "4-4-2"
## Nivel medio del equipo (1-99): centro de la campana para generar la plantilla.
@export_range(1, 99) var base_overall: int = 65
## Jugador estrella con su Trait. Definido a mano en el .tres del equipo.
@export var star_player: PlayerStats
## Nombres ficticios del resto de la plantilla (la estrella no se repite aquí).
@export var roster_names: Array[String] = []
