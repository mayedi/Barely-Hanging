extends Node
## Global signal hub (autoload "EventBus").
##
## This node holds ONLY signal declarations — never any game logic. Gameplay code
## emits "what happened"; feedback systems (audio, effects, UI, camera) listen and
## decide "how it looks/sounds". Keeping this contract is what keeps the project
## decoupled and easy to extend (see spec §5.3).

# --- gameplay events ---------------------------------------------------------
signal rope_fired(from: Vector2, dir: Vector2, power: float)
signal rope_attached(at: Vector2, platform_index: int)
signal rope_dropped()
signal rope_wrapped(corner: Vector2)        ## rope caught a platform corner
signal rope_unwrapped(corner: Vector2)      ## rope peeled back off a corner
signal player_pumped()
signal player_landed(at: Vector2, impact: float)
signal player_fell()                        ## grip ran out / dropped while airborne
signal grip_changed(value: float)           ## 0..1
signal grip_critical()                      ## one-shot when grip first crosses critical
signal reached_goal()
signal run_reset()

# --- additional events (UI / feedback / consequence) -------------------------
## Emitted while aiming so the HUD can show the power meter. active=false on release.
signal aim_updated(active: bool, power: float)
## Current climb height (metres above the start floor); only fires when it changes.
signal height_changed(metres: float)
## A checkpoint platform was rested on and saved as the new respawn point.
signal checkpoint_saved(at: Vector2)
## The player was returned to a checkpoint after a grip-fail fall (the dread cost).
signal player_respawned(at: Vector2)
## Speed-gated pulse used to drive the motion trail + wind whoosh (carries world pos).
signal fast_motion(at: Vector2, speed: float)
