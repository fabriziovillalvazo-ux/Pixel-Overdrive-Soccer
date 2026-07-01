extends Control

## Pantalla de título (placeholder del menú principal).
## ENTER o clic para saltar al partido con los equipos por defecto.
## TODO(M4): menú completo con selección de equipo de la Liga Overdrive.

const MATCH_SCENE := "res://scenes/match/match.tscn"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or _is_click(event):
		GameState.pick_default_match()
		get_tree().change_scene_to_file(MATCH_SCENE)

func _is_click(event: InputEvent) -> bool:
	var mouse_event := event as InputEventMouseButton
	return mouse_event != null and mouse_event.pressed
