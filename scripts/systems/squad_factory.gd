class_name SquadFactory
extends RefCounted

## Genera la plantilla completa de un equipo a partir de su TeamData.
##
## El jugador estrella (con su Trait) viene definido a mano en el .tres
## del equipo; el resto de la plantilla se crea proceduralmente con los
## nombres ficticios de `roster_names` y stats alrededor de `base_overall`,
## sesgados por posición. Así los archivos de datos se mantienen compactos.

const SQUAD_SIZE := 11
## Posiciones para un 11 inicial (la formación concreta ajusta el posicionamiento).
const DEFAULT_LAYOUT: Array[PlayerStats.FieldPosition] = [
	PlayerStats.FieldPosition.POR,
	PlayerStats.FieldPosition.DEF, PlayerStats.FieldPosition.DEF,
	PlayerStats.FieldPosition.DEF, PlayerStats.FieldPosition.DEF,
	PlayerStats.FieldPosition.MED, PlayerStats.FieldPosition.MED,
	PlayerStats.FieldPosition.MED, PlayerStats.FieldPosition.MED,
	PlayerStats.FieldPosition.DEL, PlayerStats.FieldPosition.DEL,
]

## Devuelve un Array[PlayerStats] de 11 jugadores, con la estrella incluida
## en el hueco que corresponde a su posición.
static func build_squad(team: TeamData, rng: RandomNumberGenerator = null) -> Array[PlayerStats]:
	if rng == null:
		rng = RandomNumberGenerator.new()
		# Semilla estable por equipo: la misma plantilla en cada partido.
		rng.seed = hash(team.team_name)

	var squad: Array[PlayerStats] = []
	var star_placed := false
	var name_index := 0

	for layout_position in DEFAULT_LAYOUT:
		if not star_placed and team.star_player != null \
				and team.star_player.field_position == layout_position:
			squad.append(team.star_player)
			star_placed = true
			continue

		var player := _generate_player(team, layout_position, name_index, rng)
		name_index += 1
		squad.append(player)

	# Si la posición de la estrella no apareció (datos raros), entra igualmente.
	if not star_placed and team.star_player != null:
		squad[squad.size() - 1] = team.star_player

	return squad

static func _generate_player(
	team: TeamData,
	layout_position: PlayerStats.FieldPosition,
	name_index: int,
	rng: RandomNumberGenerator
) -> PlayerStats:
	var player := PlayerStats.new()
	player.player_name = team.roster_names[name_index] \
			if name_index < team.roster_names.size() \
			else "%s %d" % [team.short_name, name_index + 2]
	player.field_position = layout_position

	var base := team.base_overall
	player.speed = _roll(rng, base, layout_position == PlayerStats.FieldPosition.DEL)
	player.jump = _roll(rng, base, layout_position == PlayerStats.FieldPosition.DEF)
	player.max_stamina = _roll(rng, base, layout_position == PlayerStats.FieldPosition.MED)
	player.shot_power = _roll(rng, base, layout_position == PlayerStats.FieldPosition.DEL)
	player.passing = _roll(rng, base, layout_position == PlayerStats.FieldPosition.MED)
	player.tackling = _roll(rng, base, layout_position == PlayerStats.FieldPosition.DEF)
	player.technique = _roll(rng, base, false)
	return player

## Stat aleatorio: base +/-8, con +6 extra si la posición favorece el stat.
static func _roll(rng: RandomNumberGenerator, base: int, favored: bool) -> int:
	var value := base + rng.randi_range(-8, 8) + (6 if favored else 0)
	return clampi(value, 1, 99)
