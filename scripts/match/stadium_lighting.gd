class_name StadiumLighting
extends CanvasModulate

## Ambiente visual del partido según la hora configurada en Ajustes
## (decisión registrada: Día / Atardecer / Noche / Aleatoria).
##
## Día y atardecer solo modulan el color de la escena; de noche se añade
## una modulación azulada + focos del estadio con PointLight2D (luces 2D
## nativas de Godot), cuya textura radial se genera en código.

const DAY_COLOR := Color(0.98, 0.97, 1.0)
const SUNSET_COLOR := Color(1.0, 0.84, 0.72)
const NIGHT_COLOR := Color(0.52, 0.56, 0.78)

## `time_of_day` es un valor de Settings.TimeOfDay (ya resuelto: sin RANDOM).
func setup(time_of_day: int, rules: MatchRules) -> void:
	if time_of_day == Settings.TimeOfDay.SUNSET:
		color = SUNSET_COLOR
	elif time_of_day == Settings.TimeOfDay.NIGHT:
		color = NIGHT_COLOR
		_add_floodlights(rules)
	else:
		color = DAY_COLOR

func _add_floodlights(rules: MatchRules) -> void:
	var texture := GradientTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 0.94, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 0.94, 0.0))
	texture.gradient = gradient

	# Seis torres de luz: esquinas y centros de banda, como un estadio real.
	for x in [-rules.field_half_length * 0.7, 0.0, rules.field_half_length * 0.7]:
		for y in [-rules.field_half_width - 60.0, rules.field_half_width + 60.0]:
			var light := PointLight2D.new()
			light.texture = texture
			light.texture_scale = 3.2
			light.energy = 0.9
			light.position = Vector2(x, y)
			add_child(light)
