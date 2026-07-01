class_name TacticsManager
extends Node

## Tácticas básicas seleccionables en pleno partido (teclas 1 / 2 / 3).
##
## Cada táctica ajusta modificadores que consumen la IA de equipo y el
## posicionamiento: altura de las líneas, presión sin balón, amplitud y
## agresividad al subir jugadores al ataque.

signal tactic_changed(tactic: Tactic)

enum Tactic { OFFENSIVE, BALANCED, DEFENSIVE }

## Modificadores por táctica. Valores relativos a la posición base de la
## formación: line_height desplaza las líneas hacia el campo rival (+) o
## el propio (-), pressure escala el radio de presión, width la amplitud,
## y support cuántos jugadores acompañan la jugada.
const MODIFIERS := {
	Tactic.OFFENSIVE: {
		"line_height": 0.2,
		"pressure": 1.25,
		"width": 1.1,
		"support": 1.3,
	},
	Tactic.BALANCED: {
		"line_height": 0.0,
		"pressure": 1.0,
		"width": 1.0,
		"support": 1.0,
	},
	Tactic.DEFENSIVE: {
		"line_height": -0.2,
		"pressure": 0.8,
		"width": 0.9,
		"support": 0.7,
	},
}

var current_tactic: Tactic = Tactic.BALANCED

func set_tactic(tactic: Tactic) -> void:
	if tactic == current_tactic:
		return
	current_tactic = tactic
	tactic_changed.emit(tactic)

func get_modifier(key: String) -> float:
	return MODIFIERS[current_tactic][key]

func tactic_display_name() -> String:
	match current_tactic:
		Tactic.OFFENSIVE:
			return "OFENSIVA"
		Tactic.DEFENSIVE:
			return "DEFENSIVA"
		_:
			return "BALANCEADA"
