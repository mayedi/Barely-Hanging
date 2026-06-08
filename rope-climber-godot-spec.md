# Rope Climber — Godot 4.6 Implementation Specification

> **Purpose of this document.** This is a complete build spec for an AI coding agent (Claude Code) to implement a physics-based rope-climbing game in **Godot 4.6** (GDScript). It contains the design, every mechanic with its algorithm and exact tuning values, the required project architecture, a milestone-based build order, and a future roadmap. Build the **MVP scope** only (clearly marked). Architect everything so the **Future Roadmap** features can be added later without refactors.

> **How to use this doc:** Read it fully before writing code. Build in the milestone order in §12. Do not invent extra features beyond the MVP. When a tuning number is given, use it exactly as the default — they are validated starting values from a working prototype.

---

## Table of Contents
1. Game Concept
2. Design Pillars (non-negotiable)
3. The Core Loop
4. Coordinate System & Physics Model
5. Architecture (read this carefully)
6. Mechanics — Detailed Specs
7. The Character (Fluffy One-Eye)
8. Camera
9. Feel / Juice
10. UI / HUD & Coaching
11. Tuning Reference (all default values)
12. Build Milestones (the order to implement)
13. Coding Standards
14. Stakes & Consequence (a required design decision)
15. Future Roadmap (DO NOT build yet — architect for it)

---

## 1. Game Concept

A **physics-based rope-climbing game**, rendered in **3D but played on a 2D side-view plane** (the *Getting Over It* / *Umihara Kawase* presentation trick). The player controls a small, charming **fluffy one-eyed creature** that ascends a vertical course by:

- **throwing a rope** that arcs under gravity and hooks onto **any surface it touches** — the rope sticks wherever it lands on a platform (top, side, or underside), not just on designated ledge anchors,
- **swinging** like a pendulum and **pumping** to build amplitude,
- **wrapping the rope around platform corners** to whip around them,
- managing a **grip/endurance** meter that drains while airborne,
- **landing on platforms to rest** (recover grip) or **chaining** hook-to-hook without stopping (the mastery path).

> **Hooking philosophy (important).** This is *free-form grappling*, like the early prototypes and like Umihara Kawase / the Worms ninja rope. The rope attaches to the **first point of any platform surface its flight path contacts** — there is no concept of "valid" vs "invalid" anchors, and the player is never required to target a specific ledge. Any bit of any platform is grabbable. Pair this with corner-wrapping (§6.3): you grab a surface and the rope bends around whatever geometry is in the way. This freedom is the source of the game's expressive movement.

It is a **skill game** with a high ceiling, in the lineage of Getting Over It, Jump King, and Umihara Kawase. The presentation is cute; the challenge is real.

---

## 2. Design Pillars (non-negotiable)

These decisions are settled. Do not deviate.

1. **3D render, 2D simulation.** All gameplay physics happen in a 2D plane (`z = 0`). 3D is purely presentation (meshes, lighting, depth, parallax). Never let rendering concerns leak into the simulation.
2. **The swing is the core verb.** Everything serves making the pendulum swing feel deep and satisfying. No mechanic may trivialize swinging (e.g. no "auto-climb winch").
3. **Skill over accessibility.** Hard execution is the point. Make the game *legible* (the player always understands what to do and where to go) but never *easy*. Legibility comes from feedback and level design, not from removing physics.
4. **Custom deterministic physics.** Use hand-rolled Verlet integration for the player and rope (see §4). Do **not** use a `RigidBody3D`/`RigidBody2D` for the player. We need exact control over the rope constraint and corner-wrapping; Godot's solver does not give us that cleanly.
5. **Decoupled feel.** Audio, particles, screen-shake, and other juice must be driven by **signals/events**, never called directly from physics/logic code. Logic emits "what happened"; feedback systems decide "how it looks/sounds."

---

## 3. The Core Loop

```
On a platform (grounded)
  → AIM: move cursor (farther = stronger throw), see live arc + landing reticle
  → THROW: release to fire rope; it arcs and hooks onto any platform surface it hits
  → SWING: pump A/D to build amplitude; rope may wrap corners and whip you around
  → ASCEND: either
       (a) swing up and RELEASE to land on a higher platform (rest, grip refills), or
       (b) throw a NEW rope mid-swing onto any higher surface (chain, no rest — mastery path)
  → repeat upward to the GOAL
Fail state: grip runs out while airborne → you drop the rope and fall.
```

---

## 4. Coordinate System & Physics Model

### 4.1 Plane
- Gameplay lives on the **XY plane at `z = 0`**. `+X` right, `+Y` up, gravity pulls `-Y`.
- 3D nodes render at `(x, y, 0)`. Background décor sits at `z < 0` for parallax.

### 4.2 Fixed timestep
- Run simulation in `_physics_process(delta)`.
- Set **`Engine.physics_ticks_per_second = 120`** in an autoload `_ready()` (or Project Settings). The rope constraint and wrapping are stability-sensitive; 120 Hz is the validated rate. Render interpolation can stay on default.

### 4.3 Verlet integration (player & hook)
Each simulated point stores `pos: Vector2` and `prev_pos: Vector2`. Per step:
```gdscript
var vel := (pos - prev_pos) * config.damping
prev_pos = pos
pos = pos + vel + Vector2(0, -config.gravity) * dt * dt
```
- To inject velocity, modify `prev_pos` (e.g. to add velocity `v` in a direction `d`: `prev_pos -= d * v`).
- This integration is the heart of the game; everything below (pendulum, pump, whip) emerges from it plus constraints.

### 4.4 Collision against the level
- Platforms are axis-aligned boxes defined as **data** (see §5.5). Resolve the player against them with **simple AABB math** (treat the player as a box of half-size = `player_radius`). Push out along the axis of least penetration; if pushed upward, the player is **grounded**.
- Do **not** use Godot collision bodies for this in the MVP. AABB math against level data is deterministic, trivial, and matches the proven prototype. (You may revisit later; see Roadmap.)

```gdscript
# returns true if grounded this step
func resolve_aabb(p: PhysicsPoint, radius: float, platforms: Array) -> bool:
    var grounded := false
    for plat in platforms:
        var d := p.pos - plat.center
        var ox := (plat.half.x + radius) - abs(d.x)
        var oy := (plat.half.y + radius) - abs(d.y)
        if ox > 0.0 and oy > 0.0:
            if ox < oy:
                p.pos.x += ox if d.x > 0 else -ox
                p.prev_pos.x = p.pos.x  # kill x velocity
            else:
                p.pos.y += oy if d.y > 0 else -oy
                if d.y > 0: grounded = true
                p.prev_pos.y = p.pos.y  # kill y velocity
    return grounded
```

---

## 5. Architecture (read this carefully)

The single most important requirement from the client: **clean, scalable, easy to update and debug.** Follow this structure precisely.

### 5.1 Folder layout
```
res://
  project.godot
  /scenes
    main.tscn                      # root: spawns level, player, camera, hud
    /player/player.tscn
    /creature/creature.tscn
    /level/platform_view.tscn      # visual mesh for one platform
    /ui/hud.tscn
  /scripts
    /core
      game_director.gd             # autoload: owns run lifecycle/state
      event_bus.gd                 # autoload: global signals (decoupling)
      game_config.gd               # class_name GameConfig (Resource)
    /player
      player.gd                    # owns the player PhysicsPoint + state machine
      player_state_machine.gd
      /states                      # one script per state
        state.gd                   # base
        grounded_state.gd
        aiming_state.gd
        airborne_state.gd          # swinging OR free-falling (rope attached or not)
      rope.gd                      # class_name Rope: hinge stack, constraint, wrapping
      throw_controller.gd          # aim, power, prediction, fire
    /sim
      physics_point.gd             # class_name PhysicsPoint (pos/prev_pos verlet)
      aabb_util.gd                 # collision + segment/box helpers (static funcs)
    /camera
      game_camera.gd
    /level
      level_data.gd                # class_name LevelData (Resource): platforms, start, goal
      level.gd                     # builds visuals from LevelData, exposes platform rects
    /feedback
      audio_manager.gd             # autoload: plays SFX in response to EventBus
      effects_manager.gd           # autoload: particles, hitstop, trail, shake hooks
    /ui
      hud.gd
  /resources
    default_config.tres            # a GameConfig instance (all tuning lives here)
    /levels/level_01.tres          # a LevelData instance
  /assets
    /audio  /models  /materials
```

### 5.2 Autoloads (singletons)
Register these in Project Settings → Autoload:
- **`EventBus`** — a `Node` that only declares `signal`s. Everything communicates through it. No game logic here.
- **`GameDirector`** — owns the high-level run state (`PLAYING`, `WON`), handles reset, sets `physics_ticks_per_second`, holds the active `GameConfig` and `LevelData` references.
- **`AudioManager`** — connects to `EventBus` signals in `_ready()`, plays sounds. Knows nothing about game logic.
- **`EffectsManager`** — connects to `EventBus`, triggers particles / hitstop / shake / trail.

### 5.3 The EventBus (decoupling contract)
Declare these signals. Logic emits them; feedback/UI listen. This is what keeps the project maintainable.
```gdscript
extends Node
# --- gameplay events ---
signal rope_fired(from: Vector2, dir: Vector2, power: float)
signal rope_attached(at: Vector2, platform_index: int)
signal rope_dropped()
signal rope_wrapped(corner: Vector2)      # rope caught a corner
signal rope_unwrapped(corner: Vector2)
signal player_pumped()
signal player_landed(at: Vector2, impact: float)
signal player_fell()                      # grip ran out / dropped while airborne
signal grip_changed(value: float)         # 0..1
signal grip_critical()
signal reached_goal()
signal run_reset()
```

### 5.4 GameConfig — ALL tuning lives in one Resource
This is the key to "easy to tweak/iterate." Create a `Resource` with every gameplay number as an `@export`. Save an instance as `res://resources/default_config.tres`. Designers tweak values in the Inspector with zero code changes. **No magic numbers anywhere else in the codebase** — read everything from the active `GameConfig`.

```gdscript
class_name GameConfig
extends Resource

@export_group("Physics")
@export var gravity: float = 36.0
@export var damping: float = 0.9945
@export var player_radius: float = 0.6

@export_group("Throw")
@export var throw_min_speed: float = 16.0
@export var throw_max_speed: float = 50.0
@export var power_scale: float = 18.0        # cursor distance (world units) for full power

@export_group("Rope")
@export var reel_speed: float = 9.0
@export var rope_min_length: float = 1.4
@export var constraint_iterations: int = 6
@export var max_hinges: int = 6              # rope-wrap depth cap

@export_group("Pump")
@export var pump_accel: float = 24.0
@export var pump_align_boost: float = 1.95   # pushing WITH the swing builds amplitude
@export var pump_counter: float = 0.55       # pushing against only brakes a little

@export_group("Grip / Endurance")
@export var grip_drain: float = 0.12         # per second airborne while attached
@export var grip_restore: float = 0.8        # per second grounded
@export var grip_warn: float = 0.55
@export var grip_critical: float = 0.25

@export_group("Camera")
@export var view_height: float = 37.0
@export var fov_degrees: float = 30.0
@export var cam_speed_zoom: float = 9.0      # extra distance at high speed
```

### 5.5 LevelData — levels are data, not hardcode
```gdscript
class_name LevelData
extends Resource

# Each platform: position (Vector2 center), size (Vector2 = width,height),
# and flags. Use a small inner struct via Dictionary or a typed sub-Resource.
@export var platforms: Array[Dictionary] = []  # {center:Vector2, size:Vector2, is_ground:bool, is_goal:bool}
@export var start_pos: Vector2 = Vector2(0, 1)
```
`level.gd` reads a `LevelData`, builds the visual platform meshes, and exposes a plain array of platform rects (center/half-extents/flags) that the simulation queries. The simulation never touches Nodes for collision — only this data array.

**MVP level (`level_01.tres`) — the validated zig-zag layout** (center x,y / width,height):
```
ground : ( 0, -1) 46 x 2   [is_ground]
        : ( 5,  5)  9 x 1.4
        : (-5, 10)  9 x 1.4
        : ( 6, 15)  8 x 1.4
        : (-6, 20)  8 x 1.4
        : ( 6, 25)  8 x 1.4
        : (-6, 30)  8 x 1.4
        : ( 5, 35)  8 x 1.4
goal   : ( 0, 41) 11 x 1.8 [is_goal]
start_pos = (0, 1)
```
Ledges alternate sides and rise ~5 units; each next surface is within a pumped swing's reach of the previous. **This spacing is the #1 thing to tune after the build works** — if a surface is unreachable, widen platforms or reduce the rise.

> Because hooking is free-form (any surface point, §6.2), a "platform" is just a box surface — it need not be a thin ledge. Later levels can include **tall walls, wide faces, overhangs, and pillars**, all hookable anywhere along their surface, which feeds corner-wrapping and varied routes. The MVP layout uses thin ledges for clarity, but the data model and hooking rule already support any box geometry — do not bake in any "ledges only" assumption.

### 5.6 Player state machine
The player is a small state machine. Keep states tiny and single-purpose. Shared data (the `PhysicsPoint`, the active `Rope`, grip value) lives on `player.gd`; states drive transitions and per-state input.

States:
- **GroundedState** — standing on a platform. Grip restores. Can aim/throw. Transition to Aiming on mouse-down, to Airborne if it leaves the ground.
- **AimingState** — mouse held: compute aim/power, drive the throw preview (arc + reticle showing the exact contact point on whatever surface the rope will hit). On release: fire rope, go to Airborne. (Aiming can occur grounded or airborne — model it as a sub-behavior usable from both, or allow Aiming to remember whether attached. Simplest: aiming is a flag handled inside Grounded/Airborne rather than a separate state. Choose whichever stays cleanest; do not over-engineer.)
- **AirborneState** — not grounded. Covers both "swinging" (rope attached) and "free fall" (no rope). Applies pump, reel, rope constraint + wrapping, grip drain. Transition to Grounded on landing; emit `player_fell` if grip hits 0.

Keep it readable: an `enum` + `match` in `player.gd` is acceptable if a full node-based FSM feels heavy. Prioritize clarity over pattern purity.

---

## 6. Mechanics — Detailed Specs

### 6.1 Aiming & Throw
- **Aim direction & power from the cursor.** Project the mouse to the `z=0` plane:
  ```gdscript
  var from := camera.project_ray_origin(mouse_screen_pos)
  var dir := camera.project_ray_normal(mouse_screen_pos)
  var hit = Plane(Vector3(0,0,1), 0).intersects_ray(from, dir)  # Vector3 or null
  var cursor := Vector2(hit.x, hit.y)
  ```
- `to_cursor := cursor - player.pos`; `power := clamp(to_cursor.length() / power_scale, 0, 1)`; `speed := lerp(throw_min_speed, throw_max_speed, power)`; launch velocity `= to_cursor.normalized() * speed`.
- **Live preview while aiming:** simulate the hook's exact path (same integration as the real hook) for ~260 steps; draw dots along it; place a **reticle** at the first point the path contacts **any platform surface** (top, side, or underside — all are valid).
  - The reticle simply marks **where the rope will stick.** Optionally tint it teal when that point is above the player and amber when at/below — but treat this purely as a *height hint*, **not** a validity gate. Both are legal hooks; the player may grab below themselves deliberately (e.g. to wrap a corner or set up a swing). Do not block or discourage any hook.
- **Fire:** spawn the hook as a `PhysicsPoint` with the launch velocity. Emit `rope_fired`.

### 6.2 Hook (projectile) & attach
- The hook is a Verlet point under gravity (no damping). Each step, test its position against every platform rect (slightly expanded). **On contact with any platform, the rope attaches at the closest point on that platform's surface to the hook** — top, side, or underside, anywhere along the box. There is no surface preference and no "top-only" rule. Clamp the hook to that surface point and **attach**:
  - Create the `Rope` with `hinges = [anchor]`, `length = distance(player, anchor)`.
  - Emit `rope_attached(at, platform_index)`.
  - The anchor is purely a pivot to swing from; the corner-wrapping system (§6.3) handles the rope bending around the rest of that platform's geometry as you swing, so grabbing a side or underside is fully supported and often desirable.
- If the hook falls far below the player without hitting anything, cancel it.

### 6.3 Rope: constraint, reel, and CORNER WRAPPING
This is the most important and trickiest system. Implement it as its own class (`Rope`).

**State:**
```gdscript
class_name Rope
var hinges: Array = []   # Array of {pos:Vector2, wind:int}; hinges[0] = anchor (wind unused)
var length: float = 0.0  # total rope budget
```
- **Active pivot** = `hinges.back()`. The player swings around it.
- **Consumed length** = sum of segment lengths between fixed hinges.
- **Active length** = `max(rope_min_length, length - consumed)`.

**Distance constraint (the pendulum):** after integrating the player, pull it back to within `active_length` of the active pivot. Run `constraint_iterations` times. Moving the player purely radially preserves tangential velocity — this is what produces the pendulum and the whip.
```gdscript
var pv := hinges.back().pos
var d := player.pos - pv
var dist := d.length()
if dist > active_length:
    player.pos -= d * ((dist - active_length) / dist)
```

**Reel:** `W` decreases `length` (down to `rope_min_length`), `S` increases it. Shortening near the bottom of a swing adds energy (intentional emergent skill).

**WRAP — catch a corner.** After the constraint, if the straight segment from the active pivot to the player passes through any platform's interior, the rope must bend around that platform's corner:
1. Detect: segment-vs-box-interior test (use a slightly *shrunk* box so edge-touching doesn't count). Liang–Barsky clip:
   ```gdscript
   static func seg_hits_box(a:Vector2,b:Vector2,minp:Vector2,maxp:Vector2)->bool:
       var t0:=0.0; var t1:=1.0; var dd:=b-a
       var P:=[-dd.x, dd.x, -dd.y, dd.y]
       var Q:=[a.x-minp.x, maxp.x-a.x, a.y-minp.y, maxp.y-a.y]
       for i in 4:
           if P[i]==0.0:
               if Q[i]<0.0: return false
           else:
               var r:=Q[i]/P[i]
               if P[i]<0.0:
                   if r>t1: return false
                   if r>t0: t0=r
               else:
                   if r<t0: return false
                   if r<t1: t1=r
       return t1>t0
   ```
2. Choose the wrap corner: of the platform's 4 corners, pick the one where **both** sub-segments (pivot→corner and corner→player) avoid the box interior, minimizing total path length. Skip corners coincident with the pivot or the player.
3. Insert it as a new hinge, storing the **winding sign**:
   ```gdscript
   var w := sign((corner.x - A.x)*(player.y - corner.y) - (corner.y - A.y)*(player.x - corner.x))
   if w == 0: w = 1
   hinges.push_back({pos=corner, wind=w})
   emit EventBus.rope_wrapped(corner)
   ```
   The sudden drop in active length whips the player around the corner — the desired feel.
4. Cap at `max_hinges`. Wrap at most one corner per step.

**UNWRAP — peel off a corner.** Before wrapping each step, check the last hinge: compute the current winding sign using the previous hinge and the player; if it flipped from the stored `wind`, the rope has swung back past the corner — pop the hinge (its length returns to the active segment automatically via the consumed-length recompute).
```gdscript
while hinges.size() > 1:
    var H = hinges.back(); var Hp = hinges[hinges.size()-2]
    var s := sign((H.pos.x-Hp.pos.x)*(player.y-H.pos.y) - (H.pos.y-Hp.pos.y)*(player.x-H.pos.x))
    if s != 0 and s != H.wind: hinges.pop_back()
    else: break
```

**Order per physics step (attached):** integrate player → apply pump → apply reel → solve constraint (N iters) → unwrap → wrap → solve constraint again (2 iters to settle).

> ⚠️ **Wrapping is the highest-risk code.** Expect to debug it visually. Common failures: false wraps on far ledges (tighten the shrink margin and require true interior intersection), sticky hinges that never unwrap (check the winding-sign logic), or an unstable whip (it's a hard radial snap — this is intended, but if it explodes, soften by applying the post-wrap constraint over a couple iterations). Add a debug toggle that draws the hinge polyline and prints `hinges.size()`.

### 6.4 Pump (amplitude-building swing)
Pumping must make **each consecutive well-timed swing go further**, like pumping a playground swing. Apply a **tangential** impulse (perpendicular to the rope), with a boost when pushing *with* the current motion:
```gdscript
var pv := rope.hinges.back().pos
var radial := (player.pos - pv).normalized()
var tangent := Vector2(-radial.y, radial.x)
var d := 1.0 if Input.is_action_pressed("pump_right") else -1.0   # A = -1, D = +1
tangent *= d
var vel := player.pos - player.prev_pos
var along := vel.dot(tangent)
var boost := config.pump_align_boost if along > 0.0 else config.pump_counter
player.prev_pos -= tangent * config.pump_accel * dt * dt * boost
emit EventBus.player_pumped()
```
- Pressing the key that matches your swing direction adds energy (amplitude grows over several swings); mistiming bleeds it. That timing is the skill.
- With `damping` near `0.9945`, energy accumulates across swings rather than dissipating.

### 6.5 Grip / Endurance
- While **attached and airborne:** `grip -= grip_drain * dt`. At `grip < grip_critical` (first crossing), emit `grip_critical` (one-shot warning). At `grip <= 0`: drop the rope, emit `player_fell`.
- While **grounded:** `grip += grip_restore * dt` (clamped to 1). Reset the critical warning latch once grip recovers above `grip_warn`.
- Emit `grip_changed(value)` whenever it changes so the HUD/feel react.

### 6.6 Release & landing
- **Release** (`SPACE`): drop the rope. The player keeps its current swing velocity (natural momentum — do **not** add an artificial boost). Releasing near the top of a swing is how you reach a ledge to land on.
- **Landing:** when the player becomes grounded after being airborne, if the downward impact speed exceeds a small threshold, emit `player_landed(at, impact)` (drives dust + thud + shake). Landing on any ledge top is a valid rest stop (grip refills). This is the accessible path; chaining without landing is the mastery path.

### 6.7 Win
- Reach the goal platform: `state == PLAYING and distance(player, goal_center) < goal_half_width + 1.2 and player.y > goal_y - 2` → emit `reached_goal`, set state `WON`, show summit UI. Forgiving on purpose (touching the goal counts).

### 6.8 Reset
- `R` resets the run: player to `start_pos`, drop rope, grip = 1, state `PLAYING`. Emit `run_reset`.

---

## 7. The Character (Fluffy One-Eye)

An **original** creature — **do not** replicate any existing/branded character. Design:
- **Round fuzzy body:** a sphere (warm orange, `~#f0822e`), roughness high.
- **Fur:** cover the body in small cone "tufts" pointing outward on an even (fibonacci-sphere) distribution. Use a **`MultiMeshInstance3D`** (Godot's equivalent of instancing) for one draw call. Leave a fur-free patch where the eye goes. ~300 tufts.
- **One big eye:** a stationary cream eyeball; a separate "gaze" node (iris + pupil + glint) that rotates slightly toward the movement direction so it feels alive. Teal iris (`~#1f9b8e`), black pupil.
- **Two little feet:** small flattened spheres at the base.
- **Reactions (driven by velocity, see §9):** squash on vertical speed, lean into horizontal motion, eye widens at high speed.

Build it as a `creature.tscn` scene composed of these `MeshInstance3D`/`MultiMeshInstance3D` nodes, with a script exposing `set_gaze_dir(v)`, `set_squash(amount)`, etc. The player script drives those from sim state. Keep the creature presentation-only — it reads sim state, never affects it.

---

## 8. Camera

- **`Camera3D`** in perspective, **low FOV (~30°)**, positioned back along `+Z` looking at the `z=0` plane. Compute distance so the visible vertical extent ≈ `view_height`:
  `cam_dist = (view_height / 2) / tan(deg_to_rad(fov/2))`.
- **Follow** the player on Y (clamp so the start floor stays visible early). Keep X near 0 (the course is narrow) — static horizontal framing reads as classic side-view.
- **Speed zoom-out:** as player speed rises, ease the camera back by up to `cam_speed_zoom` units (lerp smoothly). Gives a sense of velocity.
- **Shake:** a decaying shake value, applied as small random offset; triggered by hard landings and grip-fail.

---

## 9. Feel / Juice

All feel is **decoupled** — `AudioManager` and `EffectsManager` subscribe to `EventBus` in `_ready()` and react. Logic never calls them directly.

### 9.1 Audio (`AudioManager`)
Map signals → sounds. For MVP, either short imported SFX or `AudioStreamGenerator` for procedural tones (the prototype used procedural; samples will sound better later). Expose a simple `play(name)` API internally.
| Signal | Sound |
|---|---|
| `rope_attached` | short "twang" (pitch drop ~640→200 Hz) |
| `rope_wrapped` | quick high "tick" |
| `player_landed` | low thud + filtered noise (scaled by impact) |
| fast swing (see trail/whoosh trigger) | wind "whoosh" (speed-gated, with cooldown) |
| `grip_critical` | soft warning beep |
| `reached_goal` | rising arpeggio |

### 9.2 Effects (`EffectsManager`)
- **Hitstop:** on `rope_attached`, freeze the simulation for ~0.045 s (a manual `hitstop_timer` that makes `_physics_process` skip integration while rendering continues — do **not** use `Engine.time_scale`, it disturbs UI/audio). A tiny freeze on the catch makes hooking feel punchy.
- **Particles:** burst on `rope_attached` (teal, at anchor) and `player_landed` (dusty, at feet). Use `GPUParticles3D` one-shot emitters or a small pooled set of `CPUParticles3D`.
- **Motion trail:** at high speed, drop fading ghost copies of the creature.
- **Screen shake:** on `player_landed` (scaled by impact) and `player_fell`.

### 9.3 Creature reactions (in creature.tscn script, fed by player)
- Squash/stretch with vertical speed; lean (z-rotation) into horizontal velocity; eye widens with speed; gaze tracks movement direction.

---

## 10. UI / HUD & Coaching

`hud.tscn` listens to `EventBus`; never reads sim internals directly beyond what signals carry (pass needed values in the signal).
- **Grip meter** (bottom-left): fills 0..1, colors solid → straining (amber) → critical (red), with a text state label.
- **Power meter** (bottom-right): visible only while aiming.
- **Height readout** (top): meters climbed.
- **Orientation pulse (optional):** to keep the climb legible, the nearest platform above the player may gently pulse as a *direction hint* — but it is **only orientation, not a required target.** The player can hook any surface anywhere; never imply the pulsed platform is the only valid grab.
- **Staged coaching prompts** (fade out once learned, tracked by flags):
  1. grounded, never thrown → "aim at a platform above & release — the rope grabs wherever it lands"
  2. attached, never pumped → "press A / D to pump — build your swing higher"
  3. attached, pumped, never landed high → "swing up, then release to land on a platform"
- **Win panel:** "SUMMIT — press R to climb again".
- **Controls reference** (corner): aim=mouse, throw=hold/release L-click, pump=A/D, release=Space, reel=W/S, reset=R.

---

## 11. Tuning Reference (all default values)

These are validated defaults from the working prototype. Put them in `default_config.tres`.

```
gravity              = 36.0
damping              = 0.9945
player_radius        = 0.6
throw_min_speed      = 16.0
throw_max_speed      = 50.0
power_scale          = 18.0
reel_speed           = 9.0
rope_min_length      = 1.4
constraint_iterations= 6
max_hinges           = 6
pump_accel           = 24.0
pump_align_boost     = 1.95
pump_counter         = 0.55
grip_drain           = 0.12
grip_restore         = 0.8
grip_warn            = 0.55
grip_critical        = 0.25
view_height          = 37.0
fov_degrees          = 30.0
cam_speed_zoom       = 9.0
physics_ticks/sec    = 120
hitstop_on_attach    = 0.045 s
```
Input map actions to define: `aim`/throw via mouse button + motion, `pump_left` (A), `pump_right` (D), `reel_in` (W), `reel_out` (S), `release` (Space), `reset` (R).

---

## 12. Build Milestones (the order to implement)

Build and verify each milestone before moving on. Each should be independently testable.

1. **Scaffold.** Project, autoloads (`EventBus`, `GameDirector`, `AudioManager`, `EffectsManager`), `GameConfig` + `default_config.tres`, `LevelData` + `level_01.tres`, `physics_ticks_per_second = 120`. Empty scenes wired together.
2. **Render the world.** `level.gd` builds 3D platform meshes from `LevelData`; side-locked `Camera3D`; lighting (hemisphere + directional, **no shadows**); gradient sky; background parallax boxes; fog.
3. **Player body + collision.** `PhysicsPoint`, Verlet integration, AABB collision vs level data, gravity, grounded detection. A placeholder sphere falls and rests on ledges. Camera follows.
4. **Throw + hook + basic pendulum.** Cursor aim, power, arc preview + a reticle that marks the exact contact point on any surface; fire hook; attach to **any platform surface it hits** (top/side/underside); single-pivot distance constraint. You can hook any surface and swing. No wrapping yet.
5. **Pump + reel + grip.** Tangential amplitude-building pump; reel; grip drain/restore/fail; HUD meters; staged coaching. The full accessible loop works: hook → pump → release → land → repeat to goal.
6. **Rope wrapping.** Implement the hinge stack (§6.3) with a debug draw of hinges. This is the milestone to budget debugging time for.
7. **The creature.** Replace the placeholder with the fluffy one-eye (MultiMesh fur, tracking eye, feet) and its reactions.
8. **Feel pass.** Audio, hitstop, particles, trail, camera speed-zoom, shake — all via EventBus.
9. **Polish & win flow.** Win panel, reset, orientation pulse, final tuning sweep.

---

## 13. Coding Standards

- **Typed GDScript everywhere** (`var x: float`, typed params/returns, `class_name`). Enables editor checks and refactor safety.
- **`snake_case`** for vars/functions/files, `PascalCase` for `class_name`s, `UPPER_SNAKE` for constants/enums.
- **No magic numbers.** Every gameplay constant comes from `GameConfig`. Layout/level numbers come from `LevelData`.
- **Single responsibility per script.** Sim ≠ rendering ≠ audio ≠ UI. If a script is doing two of these, split it.
- **Communicate via `EventBus` signals**, not hard node references, wherever feedback/UI is involved. Direct references only within a tightly-coupled subsystem (e.g. player ↔ its rope).
- **Static utility functions** for pure math (`AabbUtil.seg_hits_box`, corner finding) — easy to unit-test, no state.
- **Comment the *why*, not the *what*** — especially in the rope-wrapping and Verlet code, where the math is non-obvious.
- **Add a debug overlay** (toggle with a key): draw rope hinges, active length, player velocity, grip, current state. You will need it.
- Keep functions short; prefer small pure helpers over long methods.

---

## 14. Stakes & Consequence (a required design decision)

The prototype is mechanically complete but currently **has no consequence** — falling costs nothing, so success feels empty. A movement game only grips players when doing it well *matters*, which requires that doing it badly *hurts*. **Implement a real fall cost** for the MVP, in the spirit of *Getting Over It* (the "dread" path):

- Define **checkpoints** (e.g. resting on certain ledges saves progress). A fall that misses a checkpoint drops you back meaningfully — potentially a long way. The dread of losing progress is the emotional engine.
- This pairs deliberately with the cute creature: adorable character, punishing climb — that contrast is the game's hook.

Architect this cleanly: a small `ProgressTracker` (on `GameDirector`) listening to `player_landed`/`player_fell`, with checkpoint data on the `LevelData`. Keep the *amount* of punishment a tunable value in `GameConfig` so it can be dialed in.

(Alternative direction — a "pursuit" system like rising water or a chase — is in the Roadmap. Pick **dread** for MVP unless the client decides otherwise.)

---

## 15. Future Roadmap (DO NOT build yet — architect for it)

Do not implement these now. But the architecture above (data-driven levels, event bus, config resource, anchor/platform as data, decoupled feedback) must make them addable without rewrites.

- **Anchor types** as a `LevelData` property: sticky, slippery (rope slides), bouncy (slingshot), **crumbling** (breaks shortly after you hook it — the "keep moving" pressure). Implement as a per-platform enum the rope/feedback react to.
- **Hazards:** wind gusts that push the swing, moving anchors, swinging obstacles, spikes.
- **Reel-pump depth:** formalize shortening-at-the-bottom as an energy gain for a higher skill ceiling.
- **Flow/chain meter:** chaining hooks without touching ground builds a multiplier and slows grip drain.
- **Time trials & ghost races:** record input/positions; race a ghost of a best run. Async — no real-time netcode needed. This is the intended first "social" feature and the genre's natural replay engine.
- **Multiple themed vertical zones**, each a `LevelData` resource.
- **Collectibles** off the optimal line to bait risky swings.
- **Swap collision to Godot physics** only if a concrete need arises; the custom AABB approach is preferred for determinism.

---

### Final note to the implementing agent
The hardest, highest-value system is **rope corner-wrapping (§6.3)** — give it a visual debug view and budget time there. The most important *design* requirement is **consequence (§14)** — without it the game is a toy. The most important *engineering* requirement is keeping **simulation, rendering, audio, and UI separated via the EventBus and a single GameConfig** — that is what makes this project scalable and easy to fix later. Build the MVP milestones in order; do not pull Roadmap features forward.
