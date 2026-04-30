# CLAUDE.md — Project Guide for Claude

> Read this first whenever opening this project cold. It contains everything needed to understand, extend, and not break the existing code.

---

## Project Overview

| Field | Value |
|---|---|
| **Name** | 2D Metroidvania (working title) |
| **Engine** | Godot 4.3 (GL Compatibility renderer) |
| **Language** | GDScript |
| **Target Platform** | PC (keyboard + gamepad) |
| **Viewport** | 480×270 internal, stretched to 1920×1080 (pixel-perfect) |
| **Entry Scene** | `res://scenes/rooms/test_room.tscn` |
| **Autoloads** | `GameManager` → `res://autoloads/game_manager.gd` |

This is a 2D side-scrolling Metroidvania built in Godot 4. The foundation is complete: the player controller, state machine, combat components (hitbox/hurtbox/health), camera system, and room-transition system are all functional. Enemies, UI, audio, and actual level content are the next phases.

---

## Full Architecture Map

### Folder Structure

```
2d-metroidvania-vibcode/
├── assets/
│   ├── audio/              (empty — reserved for SFX/music)
│   ├── fonts/              (empty — reserved for custom fonts)
│   └── sprites/
│       ├── player/
│       │   └── Lobster Bisk.png        (player sprite)
│       └── tilesets/
│           ├── placeholder_tile.png
│           └── placeholder_tileset.png
├── autoloads/
│   └── game_manager.gd     (scene transitions + fade overlay — global singleton)
├── resources/
│   └── tileset.tres        (TileSet resource — one atlas source, 2 solid tiles)
├── scenes/
│   ├── components/         (canonical combat components — USE THESE)
│   │   ├── health_component.gd
│   │   ├── hitbox.gd
│   │   ├── hitbox.tscn
│   │   ├── hurtbox.gd
│   │   └── hurtbox.tscn
│   ├── componets/          (MISSPELLED DUPLICATE — DO NOT USE, will be deleted)
│   │   ├── hitbox.gd       (older, no class_name — used by player.tscn currently)
│   │   └── hurtbox.gd
│   ├── enemies/            (empty — next major system to build)
│   ├── objects/
│   │   ├── door.gd
│   │   └── door.tscn       (room-transition trigger with spawn point)
│   ├── player/
│   │   ├── player.gd       (CharacterBody2D controller)
│   │   ├── player.tscn     (full player prefab)
│   │   ├── player_camera.gd
│   │   └── states/
│   │       ├── state.gd        (abstract base)
│   │       ├── state_machine.gd
│   │       ├── idle.gd
│   │       ├── run.gd
│   │       ├── jump.gd
│   │       ├── fall.gd
│   │       └── attack.gd
│   ├── rooms/
│   │   ├── base_room.gd        (base class — sets camera bounds)
│   │   ├── camera_controller.gd (UNUSED legacy script)
│   │   ├── main.tscn           (editor testing scene — not the entry point)
│   │   ├── test_room.tscn      (room 1 — starting room, ~976px wide)
│   │   ├── test_room_2.tscn    (room 2 — standard 480px)
│   │   └── test_room_3.tscn    (room 3 — ~1119px wide)
│   └── ui/                 (empty — reserved for HUD, menus)
├── shaders/                (empty — reserved)
├── data/                   (empty — reserved for JSON/data files)
├── project.godot
└── icon.svg
```

### How Scenes Connect

```
project.godot
└── Entry: test_room.tscn
    └── [base_room.gd] finds Player node, sets camera bounds
        ├── Player (player.tscn instanced inside room)
        │   ├── StateMachine → manages Idle/Run/Jump/Fall/Attack states
        │   ├── PlayerCamera → look-ahead + room clamping + screen shake
        │   ├── Hitbox (Area2D) → deals damage to EnemyHurtbox
        │   ├── Hurtbox (Area2D) → receives damage from EnemyHitbox
        │   └── HealthComponent → tracks HP, emits signals to Player
        └── Door (door.tscn)
            └── body_entered → GameManager.transition_to_room()
                └── GameManager → fade out → change_scene_to_file() → fade in
                    └── new room's BaseRoom → sets camera bounds again
```

### Physics Layer Map

| Layer # | Name | Used By |
|---|---|---|
| 1 | World | TileMapLayer collision |
| 2 | Player | Player CollisionShape2D |
| 3 | Enemy | Enemy bodies (future) |
| 4 | PlayerHitbox | Player's attack Area2D |
| 5 | EnemyHitbox | Enemy attack Area2D (future) |
| 6 | PlayerHurtbox | Player's damage-receive Area2D |
| 7 | EnemyHurtbox | Enemy damage-receive Area2D (future) |
| 8 | Interactable | Doors, switches, pickups |

---

## State Machine Design

The state machine lives at `scenes/player/states/`. It uses a **return-value pattern**: each state's `physics_update(delta)` returns either `""` (stay) or a state name string like `"Jump"` to trigger a transition.

```
StateMachine._physics_process(delta):
    next = current_state.physics_update(delta)
    if next != "":
        transition_to(next)  # calls exit() then enter()
```

### State Transition Table

| From \ To | Idle | Run | Jump | Fall | Attack | Dash |
|---|---|---|---|---|---|---|
| **Idle** | — | has input | jump pressed | not on floor | attack pressed | dash pressed + has_dash + cooldown=0 |
| **Run** | no input + vel<1 | — | jump pressed | not on floor | attack pressed | dash pressed + has_dash + cooldown=0 |
| **Jump** | — | — | — | vel.y >= 0 | attack pressed | dash pressed + has_dash + cooldown=0 |
| **Fall** | lands, no input | lands + input | coyote window | — | attack pressed | dash pressed + has_dash + cooldown=0 |
| **Attack** | attack ends, no input | attack ends + input | — | attack ends, in air | — | — (not allowed) |
| **Dash** | timer done + grounded + no input; OR hit + grounded | timer done + grounded + input | — | timer done + airborne; OR hit + airborne | — | — |

### Adding a New State

1. Create `scenes/player/states/my_state.gd` extending `State`
2. Implement `enter()`, `exit()`, `physics_update(delta) -> String`
3. Add it as a child Node of the `StateMachine` node in `player.tscn`
4. Reference it by its node name in transition return strings
5. Add transition cases in the states that should lead into it

---

## Every Implemented Mechanic

### Player Movement (`player.gd` + state scripts)

| Feature | Where | Details |
|---|---|---|
| Horizontal movement | `player.gd:handle_horizontal_movement()` | Acceleration/friction model. Ground: accel=1200, friction=1200. Air: accel=1200, friction=800. Max speed: 200 |
| Gravity | `player.gd:apply_gravity()` | 980/s², capped at max_fall_speed=400 |
| Jumping | `jump.gd:enter()` + `player.gd:perform_jump()` | jump_force=350 (velocity.y = -350) |
| Jump cut | `jump.gd:physics_update()` | Release jump while ascending → multiply vel.y by 0.5 |
| Coyote jump | `player.gd:update_coyote_time()` | 0.05s window after leaving platform edge |
| Jump buffer | `fall.gd:physics_update()` | 0.1s buffer — pressing jump before landing queues a jump |
| Facing direction | `player.gd:update_sprite()` | `player.scale.x = facing_direction` flips sprite |
| Dash | `player.gd`, `dash.gd` | 400px/s horizontal burst, 0.15s, gated by `has_dash` + `dash_cooldown_max=0.3s`. Pierce mode at dash_level=2 when `pierce_cooldown<=0` (0.9s recharge) — disables hurtbox + cyan tint. Regular dash: hurtbox live, exits immediately on hit. |

### Camera (`player_camera.gd`)

| Feature | Details |
|---|---|
| Look-ahead | Lerps offset 30px toward facing direction at speed 5.0/s |
| Room clamping | Camera position clamped to room bounds set by `BaseRoom._setup_room()` |
| Screen shake | `shake(intensity)` adds random jitter; decays by shake_decay=5.0/s |

Camera bounds are set via `set_room_bounds(left, right, top, bottom)`. If the room is smaller than the viewport, the camera centers instead of clamping.

### Combat System

| Feature | Files | Details |
|---|---|---|
| Attack | `attack.gd`, `hitbox.gd` | Attack state lasts 0.25s; hitbox activates on enter, deactivates on exit |
| Hitbox positioning | `attack.gd:enter()` | `hitbox.position.x = 16 * facing_direction` |
| Damage dealing | `hitbox.gd:_on_area_entered()` | Checks `is_active`, calls `target.take_hit(damage, knockback)` |
| Knockback | `hitbox.gd` | Normalized direction × knockback_force=200 |
| Damage receiving | `hurtbox.gd` → `health_component.gd` | `hurt` signal → `take_damage()` |
| I-frames | `hurtbox.gd` | 0.5s invincibility after any hit |
| Death | `player.gd:_on_died()` | `get_tree().reload_current_scene()` |
| Damage flash | `player.gd:_flash_damage()` | White tween on sprite modulate |

### Room Transitions (`door.gd`, `game_manager.gd`)

| Step | Who | What |
|---|---|---|
| Trigger | `door.gd:_on_body_entered()` | Player enters door Area2D |
| Lock | `game_manager.gd` | `is_transitioning = true` — prevents double triggers |
| Fade out | `game_manager.gd:fade_to_black()` | ColorRect alpha 0→1 over 0.3s |
| Scene change | `game_manager.gd` | `get_tree().change_scene_to_file(target_scene)` |
| Wait | `game_manager.gd` | 2 physics frames for scene to init |
| Spawn | `game_manager.gd:place_player_at_door()` | Find player group + find door by `door_id`, teleport player to `spawn_point` |
| Fade in | `game_manager.gd:fade_to_clear()` | ColorRect alpha 1→0 over 0.3s |

The `SpawnPoint` Marker2D child of each Door defines where the player appears. Make sure every door has a correctly positioned `SpawnPoint`.

---

## Design Patterns Used

### Hitbox / Hurtbox Pattern
Damage is decoupled. A Hitbox deals damage; a Hurtbox receives it. They communicate via the `hurt(damage, knockback)` signal. The HealthComponent listens to Hurtbox, not Hitbox. This means any entity (enemy, hazard, projectile) can deal damage just by having a Hitbox with the right physics mask.

### HealthComponent Pattern
Health lives in a standalone Node child (`health_component.gd`). It emits `health_changed` and `died` signals. The owning entity (Player, future Enemy) subscribes to these signals to react (damage flash, death animation, etc.). This keeps health logic separate from movement logic.

### State Machine Pattern
Each state is a Node child of the StateMachine. StateMachine sets `state.player = get_parent()` during `_ready()`. States call `player.*` functions (not direct velocity manipulation) to use the shared physics helpers. States are decoupled from each other — they communicate only through string return values.

### BaseRoom Pattern
Every room scene's root node uses `base_room.gd`. On `_ready()`, it deferred-calls `_setup_room()` which finds the Player (by group `"player"`) and calls `camera.set_room_bounds()`. This means camera clamping is always set correctly as long as you: (a) use `base_room.gd` on the room root, (b) add `RoomBoundsMin` and `RoomBoundsMax` Marker2D nodes.

### GameManager Singleton Pattern
`GameManager` is an autoload — always in the scene tree. It owns the fade overlay `ColorRect` (added to the CanvasLayer at runtime). It holds `target_door_id` across scene changes since autoloads persist.

---

## Known Quirks, Edge Cases & Workarounds

1. **Misspelled `componets/` folder** — The player scene (`player.tscn`) currently uses hitbox/hurtbox scripts from `scenes/componets/` (no `class_name`). The `scenes/components/` folder has the proper versions with `class_name Hitbox` and `class_name Hurtbox`. They need to be consolidated — update the script paths in `player.tscn` to use the `components/` versions before adding enemies.

2. **`test_room_3` missing `room_id`** — The `room_id` export in `base_room.gd` is meant for save-system use. `test_room_3.tscn` never sets it, so it defaults to `""`. Not a runtime bug right now, but will matter when a save/load system is added.

3. **`camera_controller.gd` in rooms** — There's an unused `camera_controller.gd` in `scenes/rooms/`. It also appears attached to a `Camera2D2` node in `main.tscn`. It is not used by any room or player. Safe to delete.

4. **`main.tscn` is not the entry point** — `project.godot` points to `test_room.tscn` as the main scene. `main.tscn` exists as an editor testing scene and has its own Player instance, which means it has duplicated player state. Don't use it as a real scene.

5. **Player is instanced inside room scenes** — Each room (test_room, test_room_2, test_room_3) has a Player instance baked in. When `GameManager` transitions between rooms, it positions this room-local Player at the target door. This means the Player does not persist between scenes — HP resets on every room transition. This will need to change when persistent health/inventory is needed.

6. **`test_room_2` RoomBoundsMin has negative Y** — `RoomBoundsMin` is at `(0, -1856)` in test_room_2. This looks like a mistake (maybe from a vertical room experiment). The camera will try to clamp to an enormous range upward. Not visible at current layout but worth fixing.

7. **Door monitoring delay** — Doors call `_enable_monitoring()` 0.5s after `_ready()`. This prevents the door from firing immediately when the player is spawned on top of it after a transition. Do not remove this delay.

8. **Attack hitbox not flipped during runtime** — The hitbox position is set in `attack.gd:enter()` using `player.facing_direction`. If the player turns mid-attack, the hitbox does not move. This is intentional — attack locks you in for 0.25s.

9. **No jump from Attack state** — You cannot queue a jump during an attack. Jump buffering only works in Fall state.

10. **Dash disabled by default** — `has_dash` starts `false` and `dash_level` starts `0`. Nothing happens when you press K until you set `has_dash = true` in the Inspector. This is intentional — the dash is a Metroidvania unlock. Set `dash_level = 1` for basic dash; `dash_level = 2` for pierce mode (the `has_dash` flag must also be true).

11. **Pierce dash + damage flash interaction** — Pierce dash sets `sprite.modulate` to cyan. The damage flash (`_flash_damage`) also writes to `sprite.modulate` via a tween. Since pierce dash disables the hurtbox, damage can't trigger the flash during a pierce — no conflict. If this changes in future, the flash tween needs to be aware of the pierce tint.

12. **`player._physics_process` runs before state machine** — Both the player node and the StateMachine child have `_physics_process`. Godot 4 runs parent before child, so cooldowns are ticked one frame before the state reads them. This is correct and intentional.

---

## Current Status

### Working
- Player movement: walk, run, jump (with cut + coyote + buffer), fall
- State machine with 6 states (Idle, Run, Jump, Fall, Attack, Dash)
- Basic melee attack with hitbox activation (no enemy targets yet)
- Health system: HealthComponent, Hurtbox, i-frames, damage flash, death + reload
- Camera: look-ahead, room boundary clamping, screen shake
- Room system: 3 test rooms connected bidirectionally via doors
- Scene transitions: fade-to-black, player spawning at correct door
- Input: keyboard + gamepad bindings for move, jump, attack, dash, interact, pause, map

### Incomplete / Placeholder
- No enemies — `scenes/enemies/` is empty; the hitbox/hurtbox/health pipeline is ready but untested against an actual enemy
- No UI — no HUD (health bar, etc.), no pause menu, no map screen
- No audio — audio folder is empty; no AudioStreamPlayers anywhere
- Dash is implemented but gated behind `has_dash = true` (Inspector toggle) — set `dash_level = 1` for basic, `dash_level = 2` for pierce
- No save/load system — `room_id` fields exist but nothing writes or reads save data
- Player sprite is a placeholder ("Lobster Bisk.png") with no animations
- Tileset uses placeholder art with only 2 distinct tiles
- `test_room_2` camera bounds have a likely-incorrect -1856 Y value

### What's Next (Priority Order)
1. Fix the `componets/` → `components/` script path issue in `player.tscn`
2. Build a basic enemy (Node2D + CharacterBody2D + EnemyHitbox + EnemyHurtbox + HealthComponent + simple patrol AI)
3. Add HUD (health bar connected to Player's HealthComponent signals)
4. ~~Implement Dash state~~ **done in v0.2.0**
5. Add audio (SFX for jump, land, attack, hit, death)
6. Fix `test_room_2` camera bounds Y value
7. Implement save/load using `room_id`

---

## How to Continue — Adding New Mechanics Safely

### Adding a New Player State (e.g., Dash)

1. Create `scenes/player/states/dash.gd` extending `State`
2. Implement at minimum: `enter()`, `exit()`, `physics_update(delta) -> String`
3. In Godot editor, open `player.tscn`, select the `StateMachine` node, add a child `Node` named exactly `"Dash"`, attach `dash.gd`
4. In whatever states should transition to Dash (e.g., Idle, Run, Fall), add:
   ```gdscript
   if Input.is_action_just_pressed("dash"):
       return "Dash"
   ```
5. Do not call `move_and_slide()` more than once per physics frame — every state that calls it is fine, but don't call it twice in a single state.

### Adding an Enemy

1. Create `scenes/enemies/my_enemy.tscn` with root `CharacterBody2D`
2. Add children:
   - `CollisionShape2D` (collision_layer=3 Enemy, collision_mask=1 World)
   - `Sprite2D`
   - `Hitbox` (from `scenes/components/hitbox.tscn`) — set layer=5 (EnemyHitbox), mask=32 (PlayerHurtbox)
   - `Hurtbox` (from `scenes/components/hurtbox.tscn`) — set layer=64 (EnemyHurtbox), mask=8 (PlayerHitbox)
   - `HealthComponent` (from `scenes/components/health_component.gd`)
3. Write `my_enemy.gd`, connect `HealthComponent.died` signal to a death handler
4. The existing Player Hitbox (layer=8/PlayerHitbox, mask=64/EnemyHurtbox) will automatically hit the enemy's Hurtbox — no changes needed to player code.

### Adding a New Room

1. Create `scenes/rooms/my_room.tscn`
2. Root node: `Node2D`, attach `base_room.gd`
3. Set `room_id` export to a unique string (e.g., `"cave_01"`)
4. Add:
   - `TileMapLayer` — assign `tileset.tres`, paint terrain
   - `RoomBoundsMin` (Marker2D) — place at top-left of playable area
   - `RoomBoundsMax` (Marker2D) — place at bottom-right of playable area
   - `Player` — instance `player.tscn`, add to group `"player"`
   - `Door` (instance `door.tscn`) for each exit — set `door_id`, `target_scene`, `target_door_id`
5. In the connecting room, add a Door pointing to this room, with `target_door_id` matching this room's door's `door_id`

### Adding UI (HUD)

1. Create a `CanvasLayer` node in the room (or as an autoload)
2. Connect to `Player.health.health_changed(current, max_health)` — the signal already fires correctly
3. Do not put the HUD inside the player scene — it should be at the room or autoload level so it persists across state transitions

### Modifying Physics Feel

All tuning values are `@export` on `player.gd`. Change them in the Inspector on the Player node in any scene without touching code:
- `run_speed`, `ground_acceleration`, `ground_friction`
- `air_acceleration`, `air_friction`
- `jump_force`, `gravity`, `max_fall_speed`, `jump_cut_multiplier`

### Do Not Break These Invariants

- Every state must call `player.move_and_slide()` exactly once in `physics_update()` (or not at all if the state freezes the player)
- `StateMachine` expects all State children to be direct children of the `StateMachine` node — don't nest states
- `GameManager.transition_to_room()` expects the target room to have a Door node whose `door_id` matches `target_door_id` — always set both ends of a door pair
- `BaseRoom._setup_room()` finds the player by group `"player"` — always add the Player node to that group
- The fade overlay in `GameManager` is added to a `CanvasLayer` at runtime — don't add another CanvasLayer-based overlay at z_layer=100 or transitions will break
