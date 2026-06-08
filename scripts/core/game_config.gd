class_name GameConfig
extends Resource
## Every gameplay tuning value lives here, as one Resource (spec §5.4).
##
## Designers tweak these in the Inspector on `res://resources/default_config.tres`
## with zero code changes. There must be NO magic gameplay numbers anywhere else in
## the codebase — read everything from the active GameConfig (GameDirector.config).
## (Pure presentation tuning may live as @export on the relevant view node instead.)

@export_group("Physics")
@export var gravity: float = 36.0
@export var damping: float = 0.9945
@export var player_radius: float = 0.6

@export_group("Throw")
@export var throw_min_speed: float = 16.0
@export var throw_max_speed: float = 50.0
@export var power_scale: float = 18.0          ## cursor distance (world units) for full power
@export var preview_steps: int = 260           ## arc-preview / hook-flight simulation steps
@export var hook_cancel_drop: float = 26.0     ## cancel the in-flight hook if it falls this far below the player
@export var hook_attach_margin: float = 0.15   ## box expansion used for hook contact tests

@export_group("Rope")
@export var reel_speed: float = 9.0
@export var rope_min_length: float = 1.4
@export var constraint_iterations: int = 6
@export var max_hinges: int = 6                ## rope-wrap depth cap
@export var wrap_shrink: float = 0.05          ## interior shrink so edge-grazing never false-wraps

@export_group("Pump")
@export var pump_accel: float = 24.0
@export var pump_align_boost: float = 1.95     ## pushing WITH the swing builds amplitude
@export var pump_counter: float = 0.55         ## pushing against only brakes a little

@export_group("Grip / Endurance")
@export var grip_drain: float = 0.12           ## per second airborne while attached
@export var grip_restore: float = 0.8          ## per second grounded
@export var grip_warn: float = 0.55
@export var grip_critical: float = 0.25
@export var respawn_grip: float = 1.0          ## grip restored when respawned at a checkpoint

@export_group("Consequence")
@export var fall_to_checkpoint: bool = true    ## grip-fail returns you to the last checkpoint (the dread cost)

@export_group("Landing / Win")
@export var land_impact_threshold: float = 3.0 ## min downward speed (u/s) to register a landing thud
@export var goal_radius_bonus: float = 1.2     ## forgiveness added to goal half-width (spec §6.7)
@export var goal_y_tolerance: float = 2.0      ## player must be within this below the goal centre

@export_group("Camera")
@export var view_height: float = 37.0
@export var fov_degrees: float = 30.0
@export var cam_speed_zoom: float = 9.0        ## extra distance at high speed
@export var cam_follow_lerp: float = 6.0       ## vertical follow smoothing (per second)
@export var cam_min_y: float = 7.0             ## clamp so the start floor stays framed early
@export var cam_shake_land: float = 0.12       ## shake per unit of landing impact
@export var cam_shake_fall: float = 1.4        ## shake impulse on a grip-fail fall

@export_group("Feel")
@export var hitstop_on_attach: float = 0.045   ## sim freeze on a fresh hook to make the catch feel punchy
@export var trail_speed: float = 14.0          ## speed (u/s) above which the motion trail / whoosh trigger
@export var trail_cooldown: float = 0.04       ## min seconds between trail ghosts
@export var whoosh_cooldown: float = 0.45      ## min seconds between wind whooshes
