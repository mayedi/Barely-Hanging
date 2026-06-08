class_name LevelData
extends Resource
## A level as data, not hardcode (spec §5.5). Each platform is a Dictionary so levels
## stay editable in the Inspector / .tres without code. GameDirector converts these
## into typed PlatformRects for the sim; level.gd builds the visuals from the same data.
##
## Platform dictionary keys:
##   center:Vector2, size:Vector2 (width,height),
##   is_ground:bool, is_goal:bool, is_checkpoint:bool   (flags optional, default false)
##
## The data model intentionally supports ANY box geometry (walls, faces, overhangs,
## pillars), not just thin ledges — hooking is free-form, so do not bake in a
## "ledges only" assumption (spec §5.5 note).

@export var platforms: Array[Dictionary] = []
@export var start_pos: Vector2 = Vector2(0, 1)

## Read a flag from a platform dict with a default (keeps callers tidy).
static func flag(plat: Dictionary, key: String) -> bool:
	return plat.get(key, false)
