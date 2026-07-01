class_name MatchCamera
extends Camera2D

## Cámara lateral clásica 2D, emulando una retransmisión de TV:
## sigue al balón con suavizado horizontal y un leve adelanto en la
## dirección del juego, con límites en los bordes del campo.

@export var target_path: NodePath
@export var follow_smoothing: float = 4.0
## Píxeles de adelanto en la dirección en que viaja el balón.
@export var lead_distance: float = 40.0

var _target: Node2D

func _ready() -> void:
	_target = get_node_or_null(target_path)
	make_current()

func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var lead := Vector2.ZERO
	var ball_target := _target as Ball
	if ball_target != null and ball_target.velocity.length() > 20.0:
		lead = ball_target.velocity.normalized() * lead_distance
	var desired := _target.global_position + lead
	# La cámara de TV apenas se mueve en vertical: prioriza el eje X.
	desired.y *= 0.35
	global_position = global_position.lerp(desired, clampf(follow_smoothing * delta, 0.0, 1.0))
