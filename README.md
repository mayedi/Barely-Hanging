# Barely Hanging

A physics-based rope-climbing game in **Godot 4.6** (GDScript). You play a small fluffy
one-eyed creature ascending a vertical course by throwing a rope that hooks onto **any
surface it touches**, swinging like a pendulum, pumping to build amplitude, wrapping the
rope around corners, and managing a grip/endurance meter. Cute character, punishing climb.

Built to the spec in [`rope-climber-godot-spec.md`](rope-climber-godot-spec.md) — the MVP
scope, in the milestone order given there.

## Controls

| Action | Input |
|---|---|
| Aim | Mouse (farther from the creature = stronger throw) |
| Throw | Hold/release **Left Click** |
| Pump | **A** / **D** (push with the swing to build amplitude) |
| Reel in / out | **W** / **S** (shorten near the bottom of a swing for extra energy) |
| Release rope | **Space** |
| Reset run | **R** |
| Debug overlay | **F3** (rope hinges, active-length circle, velocity, state) |

Land on a ledge to rest and refill grip. Resting on a **checkpoint ledge** (teal marker)
saves progress — if your grip runs out while hanging, you fall back to the last checkpoint
and lose everything above it. Reach the glowing **goal** at the top to win.

## Running

Open the project in Godot 4.6 and press Play, or from the command line:

```
godot --path . 
```

The first time you run from the CLI after adding scripts, refresh the global class cache:

```
godot --headless --import --path .
```

## Tests

All the high-risk simulation math (Verlet integration, AABB resolution, the rope distance
constraint, hook contact, corner wrap/unwrap, pump amplitude, checkpoints/reset) is covered
by a headless test suite. Exit code is the number of failures:

```
godot --headless --path . res://tests/sim_test.tscn
```

## Architecture

Simulation, rendering, audio and UI are kept strictly separate; everything communicates
through the **EventBus** and reads tuning from one **GameConfig** resource. That separation
is what keeps the project scalable and easy to debug.

```
scripts/
  core/      event_bus, game_director (run lifecycle), game_config, progress_tracker
  sim/       physics_point (Verlet), aabb_util (collision + segment math)
  player/    player (state + loop), rope (constraint + wrapping), throw_controller,
			 rope_view, aim_preview
  level/     level_data (Resource), level (builds visuals), platform_rect, platform_view
  camera/    game_camera (side-locked, follow, speed-zoom, shake)
  creature/  creature ("Fluffy One-Eye": MultiMesh fur, tracking eye, feet, reactions)
  feedback/  audio_manager, effects_manager (hitstop, particles, trail) — EventBus listeners
  ui/        hud (grip/power/height meters, coaching, summit panel)
  debug/     debug_view (F3 overlay)
resources/   default_config.tres (ALL tuning), levels/level_01.tres (the level as data)
```

Everything that can be a scene or resource is **authored** (editable in the editor), not
built in code. Scripts only hold behaviour and data-driven configuration.

```
scenes/
  main.tscn                 WorldEnvironment + lights + all top-level nodes
  creature/creature.tscn    body, fur MultiMesh, eye hierarchy, feet (meshes/materials)
  player/                   player.tscn, rope_view.tscn, aim_preview.tscn
  level/                    platform_view.tscn, parallax_box.tscn (templates, data-driven)
  ui/hud.tscn               full Control tree
  fx/                       attach_burst.tscn, land_dust.tscn, trail_ghost.tscn
  audio/audio_manager.tscn  AudioStreamPlayers wired to the .wav SFX (an autoload scene)
  debug/debug_view.tscn
resources/
  default_config.tres       ALL tuning
  levels/level_01.tres       the level as data
  env/world_environment.tres sky + fog + ambient
  materials/*.tres           platform materials
assets/audio/*.wav          procedurally-baked SFX (see tools/gen_assets.gd)
```

A few things are necessarily script-driven because they are dynamic data, not static
content: the fibonacci fur distribution, the rope/aim/debug geometry (rebuilt each frame
from live positions), platform sizes (from level data), and particle placement. The
nodes, meshes and materials they use are all authored.

- **Autoloads:** `EventBus`, `GameDirector`, `AudioManager` (scene), `EffectsManager`.
- **Tuning:** every gameplay number lives in `resources/default_config.tres` — tweak it in
  the Inspector with zero code changes.
- **Levels:** are data (`LevelData`), not hardcode. `level_01.tres` is the validated
  zig-zag layout; checkpoints and the goal are flags on platforms.
- **Physics:** fixed 120 Hz, hand-rolled Verlet for the creature and hook (no `RigidBody`),
  AABB math against the platform data (no Godot collision bodies).

## Dev flags

Guarded command-line flags, no effect on normal play:

- `--demo` — drop into a mid-air swing (visual check of the rope + pendulum)
- `--demo-wrap` — force the rope to bend around a corner, with the debug overlay on
- `--shot=res://out.png` — render a frame to a PNG and quit
- `res://tests/creature_preview.tscn` — render the creature close-up

## Notes

- The Future Roadmap features (anchor types, hazards, ghost races, etc.) are **not** built,
  but the data-driven levels + EventBus + config make them addable without rewrites.
