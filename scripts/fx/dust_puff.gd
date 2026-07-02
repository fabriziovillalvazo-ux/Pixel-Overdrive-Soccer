class_name DustPuff
extends Node2D

## Nube de polvo breve (entradas y sprints), dibujada proceduralmente:
## placeholder fiel al estilo de referencia hasta tener partículas de
## Aseprite. Se autodestruye al terminar.

const LIFETIME := 0.35

var _age := 0.0

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := _age / LIFETIME
	var color := Color(0.87, 0.83, 0.72, 0.55 * (1.0 - t))
	for i in 3:
		var offset := Vector2.from_angle(TAU * i / 3.0 + 0.6) * (3.0 + 9.0 * t)
		draw_circle(offset, 2.5 + 2.0 * t, color)
