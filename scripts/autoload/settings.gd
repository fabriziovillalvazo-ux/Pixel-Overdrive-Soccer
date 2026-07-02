extends Node

## Autoload Settings: preferencias del jugador, persistidas en disco
## (user://settings.cfg). Decisión registrada: la hora del partido
## (día/atardecer/noche/aleatoria) se configura en Ajustes.

enum TimeOfDay { DAY, SUNSET, NIGHT, RANDOM }

const SAVE_PATH := "user://settings.cfg"

var time_of_day: TimeOfDay = TimeOfDay.DAY

func _ready() -> void:
	load_settings()

## Alterna al siguiente valor (para el botón del menú) y guarda.
func cycle_time_of_day() -> void:
	time_of_day = ((time_of_day + 1) % TimeOfDay.size()) as TimeOfDay
	save_settings()

## Hora efectiva para el próximo partido (resuelve la opción Aleatoria).
func resolve_match_time() -> TimeOfDay:
	if time_of_day == TimeOfDay.RANDOM:
		return [TimeOfDay.DAY, TimeOfDay.SUNSET, TimeOfDay.NIGHT].pick_random() as TimeOfDay
	return time_of_day

func time_of_day_display_name() -> String:
	match time_of_day:
		TimeOfDay.DAY:
			return "DÍA"
		TimeOfDay.SUNSET:
			return "ATARDECER"
		TimeOfDay.NIGHT:
			return "NOCHE"
		_:
			return "ALEATORIA"

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("match", "time_of_day", time_of_day)
	config.save(SAVE_PATH)

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	var stored: int = config.get_value("match", "time_of_day", TimeOfDay.DAY)
	time_of_day = clampi(stored, 0, TimeOfDay.size() - 1) as TimeOfDay
