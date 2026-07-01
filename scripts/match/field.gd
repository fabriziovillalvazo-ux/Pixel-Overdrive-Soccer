class_name Field
extends Node2D

## Terreno de juego dibujado proceduralmente (placeholder hasta tener el
## tileset de césped de Aseprite). Centrado en el origen; las dimensiones
## deben coincidir con las de MatchRules.

@export var half_length: float = 560.0
@export var half_width: float = 170.0
@export var goal_half_height: float = 28.0

const GRASS_DARK := Color("1b7a3d")
const GRASS_LIGHT := Color("259149")
const LINE_COLOR := Color(0.95, 0.98, 0.95, 0.85)

func _draw() -> void:
	# Franjas de césped alternas (efecto cortacésped clásico).
	var stripe_width := half_length * 2.0 / 14.0
	for i in range(14):
		var color := GRASS_LIGHT if i % 2 == 0 else GRASS_DARK
		draw_rect(Rect2(-half_length + i * stripe_width, -half_width, stripe_width, half_width * 2.0), color)

	# Líneas: perímetro, medio campo, círculo central y áreas.
	draw_rect(Rect2(-half_length, -half_width, half_length * 2.0, half_width * 2.0), LINE_COLOR, false, 2.0)
	draw_line(Vector2(0, -half_width), Vector2(0, half_width), LINE_COLOR, 2.0)
	draw_arc(Vector2.ZERO, 55.0, 0.0, TAU, 48, LINE_COLOR, 2.0)

	var area_depth := 90.0
	var area_half_height := 80.0
	draw_rect(Rect2(-half_length, -area_half_height, area_depth, area_half_height * 2.0), LINE_COLOR, false, 2.0)
	draw_rect(Rect2(half_length - area_depth, -area_half_height, area_depth, area_half_height * 2.0), LINE_COLOR, false, 2.0)

	# Porterías.
	draw_rect(Rect2(-half_length - 10.0, -goal_half_height, 10.0, goal_half_height * 2.0), Color.WHITE, false, 2.0)
	draw_rect(Rect2(half_length, -goal_half_height, 10.0, goal_half_height * 2.0), Color.WHITE, false, 2.0)
