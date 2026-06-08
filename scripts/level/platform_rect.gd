class_name PlatformRect
extends RefCounted
## Typed, sim-facing description of one platform (an axis-aligned box on the z=0
## plane). LevelData stores raw Dictionaries; GameDirector converts them into these
## once at load, and the whole simulation (collision, hooking, wrapping, checkpoints)
## queries this — never any scene Node. Keeping platforms as plain data is what makes
## the physics deterministic and trivial to debug (spec §4.4, §5.5).

var center: Vector2
var half: Vector2          ## half extents (width/2, height/2)
var is_ground: bool = false
var is_goal: bool = false
var is_checkpoint: bool = false
var index: int = 0

func _init(p_center: Vector2, p_size: Vector2, p_index: int) -> void:
	center = p_center
	half = p_size * 0.5
	index = p_index

func min_corner() -> Vector2:
	return center - half

func max_corner() -> Vector2:
	return center + half

## World-space top surface centre — where a resting player stands.
func top_center(player_radius: float) -> Vector2:
	return Vector2(center.x, center.y + half.y + player_radius)
