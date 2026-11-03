# Dev Log — 2D Metroidvania

## Current Version: 0.11.0
## Last Updated: 2026-11-03

---

## Patch Notes

### [0.11.0] — 2026-11-03 — Shooter enemy + reusable Projectile

Third enemy type: a ground enemy that fights at range. Green placeholder square, 2 HP, placed in `test_room` at (920, 240).

- **Files** — `scenes/enemies/shooter/shooter.gd` + `shooter.tscn`, states in `scenes/enemies/states/shooter/` (`idle`, `alert`, `reposition`, `shoot`, `hurt`). Death reuses `ground_walker/death.gd`.
- **Keeps its distance** — Reposition holds 90–170 px horizontally from the player, always facing them: backs away (1.2× speed) if closer, walks in if further or if it has no line of sight. `Shooter.can_move(dir)` casts its own wall and floor rays in the direction of travel (it walks backwards, so the facing-based WallCheck/FloorCheck pattern doesn't fit) — it never steps off a ledge or into a wall; cornered, it stands and keeps shooting.
- **Shoot** — needs a clear ray from its muzzle to the player. Windup 0.45 s (orange glow + swell; aim taken at the end), one orb, 0.35 s recoil/recovery. 1.3 s between shots. Holds fire (cooldown not spent) if line of sight is lost mid-windup.
- **Projectile** (`scenes/enemies/projectile/`, reusable by any enemy: instance, add to the room, set position, `launch(dir, speed)`) — slow orb (130 px/s), drawn with `_draw()`. Pops on World geometry, on hitting the player, or after 4 s. A pierce dash passes through it (the player's hurtbox is off).
  - **Hit it back:** its Hurtbox is on EnemyHurtbox (64), so the player's attack hits it. It reverses in the swing direction at 1.6× speed, turns white, and its Hitbox switches to the player's side (layer 8 → mask 64), damaging enemies, including the shooter.
  - Knockback from the orb is flat sideways, like the walker and flyer.
- **Tested headless** (throwaway script, not in the repo): player standing at 110 px → 3 shots / 3 hits in 6 s; player walking at a shooter standing on the block → it backed to the block's edge (x 139) and did not fall; real attack input swatted an orb back → shooter 2 → 1 HP; wall between them → 0 shots.

#### Values that may need playtesting
| Value | File | Now |
|---|---|---|
| Preferred distance | `states/shooter/reposition.gd` | 90–170 px |
| Windup | `states/shooter/shoot.gd` | 0.45 s |
| Shot cooldown | `shooter.tscn` / `shooter.gd` `shot_cooldown` | 1.3 s |
| Orb speed | `shooter.gd` `projectile_speed` | 130 px/s |
| Reflected speed | `projectile.gd` `reflect_speed_mult` | 1.6× |
| Detection radius | `shooter.tscn` DetectionZone | 200 px |

### [0.10.1] — 2026-11-03 — Player knockback actually carries

- **Bug: hits barely moved the player.** `handle_horizontal_movement` applied ground friction (3000 px/s²) on the very next frame, erasing a 200 px/s knockback in ~4 frames. Measured: a Ground Walker hit pushed the player **11 px**. Now, for the existing `knockback_duration` (0.15 s), horizontal movement/friction is skipped so the hit's velocity carries. Jump, dash and attack are separate states and still work during it. Walker hit now pushes **46 px** (+17 px hop).
- **Flyer knockback was pointing into the floor.** Both its dive hitbox and its body contact pushed along the line from above, so the player moved ~6 px. Now both push straight sideways (away from the flyer / the way the dive travels); `player.gd` adds its usual ground hop. Flyer hit now pushes **39–46 px** (+17 px hop).
- `BaseEnemy.contact_knockback_direction(diff)` — new overridable hook for body-contact knockback direction (default: straight away from the enemy's centre, unchanged for the walker). Flyer overrides it.
- Flyer dive hitbox `knockback_force` 180 → 200 (same as the walker).
- Flyer home position is read on its first physics frame (a Flyer spawned from code used to fly to (0, 0)); brighter purple tint.

### [0.10.0] — 2026-11-03 — Flyer enemy

Second enemy type: an airborne diver. Purple placeholder square, 2 HP, placed in `test_room` at (860, 120) over the open floor.

- **Files** — `scenes/enemies/flyer/flyer.gd` + `flyer.tscn`, states in `scenes/enemies/states/flyer/` (`hover`, `alert`, `chase`, `dive`, `return`, `hurt`). Death reuses `ground_walker/death.gd` (nothing walker-specific in it).
- **No gravity** — `MOTION_MODE_FLOATING`; moves on both axes. Hurt knockback also works on both axes, so a pogo knocks it down.
- **Behaviour** — Hover drifts around its home point → Alert (0.35 s "!") → Chase to a perch above and beside the player → Dive → Recovery → Chase again (≥0.7 s between dives). Leaves the player and flies home if they leave its 150 px detection radius or it gets more than 260 px (`leash_distance`) from home.
- **Dive** — Windup 0.40 s (pulls back, red tint; aim locks at the END of the windup, so moving during the telegraph is the dodge). Dive at 270 px/s for up to 0.45 s (yellow, stretched along the dive, hitbox on its body). Recovery 0.60 s is the punish window; hitting a wall/floor "bonks" it (grey, 1.0 s recovery).
- **Platform avoidance** — every check uses its own 16×16 collision box against the World layer:
  - steering (`steer_toward`) looks 28 px ahead with `test_move` and turns up to ~120° to the clear side, preferring the side it last turned to so it doesn't flip-flop;
  - a perch only counts if the box fits there and has a clear straight line to the player (tries same side, other side, straight above, then the same at half height);
  - it only dives with a clear line to the player right now. With no way in (player under a platform) it hovers overhead and waits.
- **Tested headless** (throwaway script, not in the repo): open air 4 dives in 10 s; platform between flyer and player → went round the edge and dived in from the side; player fully covered → 0 dives; never overlapped geometry in any case.

#### Values that may need playtesting
| Value | File | Now |
|---|---|---|
| Dive windup | `states/flyer/dive.gd` | 0.40 s |
| Dive speed | `states/flyer/dive.gd` | 270 px/s |
| Perch offset | `states/flyer/chase.gd` | 56 px side, 52 px up |
| Gap between dives | `states/flyer/chase.gd` `MIN_CHASE_TIME` | 0.7 s |
| Detection radius | `flyer.tscn` DetectionZone | 150 px |

### [0.9.0] — 2026-04-20 — HK-style enemy combat overhaul

Ground Walker enemy behaviour and feel rebuilt from scratch around the Hollow Knight Wandering Husk template. Every phase now has a clear visual read and a fair player interaction window.

**New state — Alert (`alert.gd`)**
- Added as the bridge between Patrol/Idle and Chase.
- When the player enters the DetectionZone, the enemy pauses for 0.30 s, snaps to face them, and plays a forward-lean squash before committing to Chase.
- This creates the "!" beat that makes HK enemies feel aware rather than scripted. A player who watches the enemy sees the reaction; a player running into the room blind gets a brief grace window.
- Both `patrol.gd` and `idle.gd` now route `player_in_detection_zone → "Alert"` instead of directly to `"Chase"`.

**Attack redesigned — 3-phase sequence (`attack.gd`)**

| Phase | Duration | Speed | Hitbox | Visual |
|---|---|---|---|---|
| Windup | 0.22 s | 0 | OFF | Red tint + wide squash (1.4×, 0.7×) |
| Lunge | 0.14 s | 480 px/s | ON | Narrow stretch (0.7×, 1.4×) |
| Recovery | 0.35 s | 0 | OFF | Spring back to rest — **punish window** |
| **Total** | **0.71 s** | | | |

- Windup is the telegraph — clear visual signal, long enough to dash away or jump.
- Lunge is fast (480 px/s over 0.14 s ≈ 67 px travel) — enough to punish a player who doesn't react.
- Recovery is the punish window — enemy is fully stationary and unthreatenable. Hit it here.
- Chains directly back into Attack if the player is still within melee range after recovery.
- All three phase transitions use `_play_scale_tween()` with configurable easing, keeping the tween code in one place.

**Hurt stagger improved (`hurt.gd`)**
- `stun_duration` raised from 0.15 s to 0.30 s — a real, readable flinch.
- Added impact squash on `enter()`: X squish (0.6×, 1.35×) → spring back. Makes hits feel weighty.
- Fallback on stun exit changed from `"Idle"` to `"Patrol"` — after a stagger the enemy resumes active behaviour rather than standing around.

**Idle wait shortened (`idle.gd`)**
- Rest duration changed from 1.0–2.0 s to 0.4–0.9 s. Enemies feel alive and patrolling rather than loitering.
- Routes detection to `"Alert"` (same as Patrol).

**`base_enemy.gd` — `squash_stretch()` helper added**
- `squash_stretch(target, duration, ease, trans) -> Tween` — convenience wrapper states can call instead of building their own Tweens. Returns the Tween so callers can kill it on exit.

**State graph after this patch:**
```
Idle ──(timer)──────────────────────────→ Patrol
Idle ──(player detected)────────────────→ Alert
Patrol ──(wall / ledge)─────────────────→ Patrol (flip + cooldown)
Patrol ──(player detected)──────────────→ Alert
Alert ──(0.30 s)────────────────────────→ Chase
Chase ──(dist ≤ 60 px)──────────────────→ Attack
Chase ──(player > 64 px above)──────────→ Patrol
Chase ──(wall stuck ≥ 0.4 s)────────────→ Patrol
Chase ──(left detection zone)───────────→ Patrol
Attack (Windup → Lunge → Recovery)
  └──(dist ≤ 60 after recovery)──────→ Attack (chain)
  └──(dist ≤ 120)────────────────────→ Chase
  └──(dist > 120)────────────────────→ Patrol
Hurt ──(stun ends, player detected)─────→ Chase
Hurt ──(stun ends, no player)───────────→ Patrol
[Hurt / Death entered via force_transition at any time]
```

---

### [0.8.4] — 2026-04-20 — Enemy AI overhaul (patrol + chase + attack lunge)

**Changed:**

- **Patrol no longer stutters on walls** (`patrol.gd`) — removed the Idle transition on wall/ledge detection. The enemy now flips direction and stays in Patrol with a 0.2 s `TURN_COOLDOWN` that suppresses the wall/ledge check for one tick after the turn. This prevents the old oscillation where the enemy would flip, check again on the very next frame, and flip back.

- **Chase no longer stops short of the player** (`chase.gd`) — removed the `FloorCheck` gate that was zeroing `velocity.x` whenever there was no floor detected ahead. The enemy now walks off ledges in pursuit. Replaced with two bail-out conditions that send the enemy back to Patrol:
  - **Player too high** — if the player is more than 64 px above the enemy (i.e. on a platform the enemy can't reach by walking), the enemy gives up and returns to Patrol.
  - **Wall-stuck** — if `WallCheck` is colliding for 0.4 s continuously while facing the player (blocked path, not just a momentary clip), the enemy gives up and returns to Patrol.
  - Lost detection zone (`player_in_detection_zone = false`) still returns to Patrol.

- **Attack active phase now lunges** (`attack.gd`) — during the active (hitbox-live) window the enemy moves forward at `run_speed` in the facing direction. Previously the enemy stood still during the active phase, meaning the hitbox (placed 16 px ahead) often didn't reach the player at the 60 px trigger distance. The lunge closes that gap without making the attack feel instant.

**Behaviour summary:**
```
Patrol ──(player detected)──────────────→ Chase
Chase  ──(dist ≤ 60 px)─────────────────→ Attack
Chase  ──(player > 64 px above)──────────→ Patrol
Chase  ──(wall blocked ≥ 0.4 s)──────────→ Patrol
Chase  ──(left detection zone)───────────→ Patrol
Attack ──(after active phase, dist ≤ 60)─→ Attack (chain)
Attack ──(after active phase, dist ≤ 120)→ Chase
Attack ──(after active phase, dist > 120)→ Idle
```

---

### [0.8.3] — 2026-04-20 — Enemy attack windup + detection zone exit

**Changed:**
- **Enemy attack is now a proper state machine state** — the old proximity-based inline attack in `ground_walker.gd` (`_try_attack` / `_perform_attack`) has been replaced by a full `Attack` state wired into the state machine. `ground_walker.gd` is now minimal; all attack logic lives in `attack.gd`.

- **Attack windup telegraph** (`attack.gd`) — the Attack state runs in two phases:
  - *Windup (0.3 s)* — enemy stops completely (`velocity.x = 0`), sprite tints red (`Color(1.0, 0.4, 0.4)`). Hitbox is **off**. Player has 0.3 s to react — dash away, jump, back off.
  - *Active (0.5 s)* — red tint clears, hitbox activates on the facing side with an explicit direction so knockback is always away from the enemy. Gravity applies; enemy doesn't float.
  - *Total sequence: 0.8 s.* On exit (including force-exits from getting hurt mid-windup), hitbox is deactivated and modulate is reset to white.

- **Chase → Attack transition** (`chase.gd`) — Chase now checks 2D distance every frame. When the player is within 60 px the state returns `"Attack"`, handing off to the windup sequence. Previously Chase never entered Attack at all.

- **Detection zone exit → Idle** (`chase.gd`, `attack.gd`) — both states return `"Idle"` when the player is outside the 120 px detection radius. `base_enemy.gd`'s `_on_detection_exited` already sets `player_in_detection_zone = false` correctly; no changes needed there.

**Timing reference:**
| Phase | Duration | Hitbox | Visual |
|---|---|---|---|
| Windup | 0.3 s | OFF | Red tint |
| Active | 0.5 s | ON | Normal |
| Total | 0.8 s | — | — |

---

### [0.8.2] — 2026-04-20 — Attack direction overhaul + pogo dash fix

**Changed:**
- **Attack direction logic rewritten** (`attack.gd:enter()`) — horizontal input is no longer checked. Attacks always travel in the current facing direction unless vertical input overrides. Rules by ground state:
  - *Grounded*: up input → UP attack. Any other input or no input → facing direction. Down attack is blocked on the ground entirely.
  - *Airborne*: down input → DOWN (pogo). Up input → UP. No vertical input → facing direction.
  - This removes the accidental left/right override when the player holds a direction during an attack, and makes the pogo intent unambiguous — pressing down in the air always means "bounce".
- **Free dash after pogo — root cause fixed** (`attack.gd:_on_hit_landed()`) — the previous fix reset `dash_cooldown = 0.0` but the pogo launches the player airborne, where the dash gate is `player.dash_cooldown <= 0.0 AND not player.used_aerial_dash`. If the player had already used their aerial dash before the pogo, `used_aerial_dash` remained `true` and silently blocked the free dash despite the cooldown being zero. Fix: reset both `player.dash_cooldown = 0.0` and `player.used_aerial_dash = false` on a successful pogo. `dash.gd`'s `enter()` correctly sets `dash_cooldown = dash_cooldown_max` when the player *uses* the granted dash — that's the start of the next cooldown, not a conflict.

### [0.8.1] — 2026-04-20 — Pogo improvements (superseded by 0.8.2)

---

### [0.8.0] — 2026-04-20 — Hollow Knight combat tuning pass

Full audit of every combat-related value against Hollow Knight's design. The goal was to make each mechanic feel intentional rather than just functional — the nail swing has weight and recovery, the dash covers a readable distance, hits register with a sharp crack, and taking damage is unambiguous.

#### Full value table — before → after

| Parameter | File | Before | After | Notes |
|---|---|---|---|---|
| `attack_duration` | `attack.gd` | 0.15 s | **0.35 s** | Matches HK nail total swing time |
| Hitbox active window | `attack.gd` | 0 s → full duration | **0.05 s → 0.20 s** | 0.15 s damage window + 0.15 s recovery |
| `hitbox_offset` | `attack.gd` | 24 px | **20 px** | Tighter to the player, less sweep |
| `pogo_force` | `player.gd` | 400 / 500 px/s | **300 px/s** | Reliable bounce without being trivial |
| `hitstop_duration` | `player.gd` | 0.06 s | **0.12 s** | ~7 frames at 60 fps — sharp crack |
| `hitstop_duration` | `base_enemy.gd` | 0.06 s | **0.12 s** | Both sides matched |
| Camera shake — deal hit | `componets/hitbox.gd` | 3.0 | **2.5** | Softer than taking damage |
| Camera shake — take hit | `player.gd` | 5.0 | **4.0** | Taking a hit still reads worse |
| `invincibility_duration` | `componets/hurtbox.gd` | 0.5 s | **1.0 s** | HK gives ~1 s to escape |
| I-frame visual | `player.gd` | none | **visible toggle every 0.08 s** | Loops while invincible, stops on `invincibility_ended` |
| Player knockback force | `player.tscn` (Hitbox) | 350 | **120** | Enemy recoil is moderate, not launch |
| Enemy knockback force | `ground_walker.tscn` (Hitbox) | 500 | **200** | Player pushed back, not across the room |
| `knockback_decay` | `base_enemy.gd` | 6.0 | **8.0** | Quick jolt ~0.12 s, not a slide |
| `knockback_duration` | `player.gd` | 0.25 s | **0.15 s** | Restore input control fast |
| Enemy attack cooldown | `ground_walker.gd` | 0.25 s | **0.5 s** | Readable gap between swings |
| Enemy attack duration | `states/ground_walker/attack.gd` | 0.4 s | **0.5 s** | Consistent with above |
| Chase speed multiplier | `states/ground_walker/chase.gd` | 1.5× | **1.3×** | More persistent, not sprint |
| `run_speed` | `player.tscn` | 175–200 | **170** | In HK range (160–180) |
| `jump_force` | `player.tscn` | 500 | **380** | ~3× player height with current gravity |
| `max_fall_speed` | `player.gd` | 700–800 | **400** | Cap fall speed for aerial control |
| Coyote time | `player.tscn` CoyoteTimer | 0.10 s | **0.08 s** | Tighter but still generous |
| Jump buffer | `player.tscn` JumpBufferTimer | 0.15 s | **0.10 s** | Matches HK responsiveness |
| `dash_speed` | `dash.gd` | 500 | **350** | Fast but not teleport-fast |
| `dash_duration` | `dash.gd` | 0.18 s | **0.15 s** | ~52 px range at 350 px/s |

#### New systems

**Timed hitbox window (`attack.gd`)**
The hitbox is no longer active for the full attack duration. It activates at `_HITBOX_ACTIVATE_TIME = 0.05 s` and deactivates at `_HITBOX_DEACTIVATE_TIME = 0.20 s`. The remaining `0.15 s` is committed recovery — you're locked into the animation but not dealing damage. This is the structural reason you can't pure-mash in Hollow Knight; skill expression lives in timing your swings between recoveries.

**I-frame visibility flash (`player.gd` + `componets/hurtbox.gd`)**
`hurtbox.gd` now emits `invincibility_ended` when the i-frame window closes. `player.gd` listens to this signal and stops the flash. `_start_iframe_flash()` creates an infinite looping Tween that toggles `sprite.visible` every 0.08 s. `_on_invincibility_ended()` kills the tween and resets `sprite.visible = true`. The flash runs on the `visible` property — no conflict with `modulate`-based damage flash or hitstop flash.

#### Values that may need further playtesting

- **`pogo_force = 300`** — set below `jump_force` (380) so pogo chains require a bit of skill. If chains feel unreliable after testing, raise to 340–360.
- **`max_fall_speed = 400`** — the fall gravity multiplier (user-set 2.2) may cause the player to reach 400 very quickly, effectively removing late-fall acceleration. If aerials feel too floaty after terminal, consider 500–600 or reducing the multiplier.
- **`knockback_duration = 0.15`** — input is restored quickly after a hit. If players can immediately cancel the knockback animation with movement, raise to 0.2.
- **`dash_speed = 350`** with **`dash_duration = 0.15`** covers ~52 px. This is shorter than HK's Mothwing Cloak in absolute terms. If the dash feels insufficient for platform gaps, raise speed to 400 (covers ~60 px).
- **Camera shake asymmetry** (2.5 deal / 4.0 take) — verify this reads correctly with the HUD present. Taking damage already triggers the HUD heart-punch animation; if both feel redundant, reduce the take-damage shake to 3.0.

---

### [0.7.0] — 2026-04-20

**Changed:**
- **Dash-ready indicator reworked** — replaced CPUParticles2D with 10 individually tweened `ColorRect` pips. Each pip spawns on a circle of radius 30px, then tweens to `Vector2.ZERO` over `0.25s` with `EASE_IN / TRANS_QUAD` acceleration (reads as "energy absorbing inward" rather than exploding). Alpha simultaneously tweens to `0`. Each pip self-destructs via `tween.finished.connect(pip.queue_free)`. The CPUParticles2D node and its `_ready()` setup code were removed entirely.

**Added:**
- **Single-hit-per-activation** (`scenes/componets/hitbox.gd`) — `var _hit_targets: Array = []` tracks every hurtbox that has been hit during the current activation window. `activate()` clears the array; `_on_area_entered()` early-returns if the incoming area is already in the list. Prevents multi-hit inside a single swing when a hitbox overlaps multiple or large hurtboxes.
- **Hitstop system** — when any hitbox lands a hit, both the attacker and the target freeze for `hitstop_duration` seconds (default `0.2s`). Implemented as a per-node countdown (`hitstop_time: float`) rather than `Engine.time_scale` — only game entities pause, not the renderer or UI.
  - **Player** (`player.gd`) — `hitstop_duration: float = 0.2` export, `hitstop_time: float = 0.0` runtime var. Guard at the very top of `_physics_process`: tick and `return` early while `> 0`.
  - **Player state machine** (`state_machine.gd`) — guard after instance-validity check: `if player.hitstop_time > 0.0: return`. Prevents state transitions mid-freeze.
  - **BaseEnemy** (`base_enemy.gd`) — same `hitstop_duration` export and `hitstop_time` var. Guard at the top of `_physics_process` ticks and returns early. Knockback decay also pauses, which is correct — the knockback slide resumes exactly where it left off.
  - **Enemy state machine** (`enemy_state_machine.gd`) — same guard pattern after instance-validity check.
  - **Hitbox trigger** — both hitbox scripts (`componets/hitbox.gd` and `components/hitbox.gd`) set `hitstop_time = hitstop_duration` on attacker and target (via `"hitstop_time" in node` property-existence check) immediately after a successful `take_hit()` call.
- **Attacker hit-flash** (`scenes/componets/hitbox.gd`) — on a successful hit the attacker's `Sprite2D` (if present) is set to `Color(1.5, 1.5, 1.5)` and tweened back to `Color.WHITE` over `hitstop_duration`. Softer than the damage flash — communicates "landed a blow" without looking like the attacker was hurt.
- **Camera shake on player hit** (`scenes/componets/hitbox.gd`) — if the attacker has a `PlayerCamera` child, `shake(3.0)` fires on every successful player hit.

**Pip tween reference:**
| Property | Value | Notes |
|---|---|---|
| Count | `10` | Evenly spaced on a circle |
| Spawn radius | `30px` | Circle radius in local space |
| Pip size | `3×3px` | `ColorRect.size` |
| Pip color | `Color(0.3, 0.8, 1.0)` | Cyan — matches pierce tint |
| Travel duration | `0.25s` | Same for position and alpha tweens |
| Position easing | `EASE_IN / TRANS_QUAD` | Slow start → fast finish = inward pull |
| Alpha target | `0.0` | Fades out as it converges |

**Hitstop coverage summary:**
| Node | Timer source | Guard location |
|---|---|---|
| `player.gd` | `player.hitstop_time` | Top of `_physics_process` |
| `state_machine.gd` | reads `player.hitstop_time` | After instance-validity check |
| `base_enemy.gd` | `enemy.hitstop_time` | Top of `_physics_process` |
| `enemy_state_machine.gd` | reads `enemy.hitstop_time` | After instance-validity check |

**Known Issues / Accepted Trade-offs:**
- Cooldown timers (`dash_cooldown`, `attack_cooldown`, etc.) pause during hitstop — they are decremented in the same `_physics_process` blocks that return early. This means hitstop slightly extends cooldowns by `hitstop_duration`. At `0.2s` this is imperceptible in normal play.
- The attacker hit-flash writes `Sprite2D.modulate`. On the player this can conflict with `_flash_damage` (which also writes modulate) if both fire in the same frame — since the player hitbox lands a hit the same frame the enemy hitbox responds. In practice the enemy's hitstop guard means their hitbox won't fire during the player's freeze. Acceptable for now.

---

### [0.6.0] — 2026-04-20

**Added:**
- **Dash-ready indicator** — a one-shot visual fires the exact frame `dash_cooldown` crosses from `> 0` to `0`, gated on `has_dash`. No Timer node; uses delta-based crossing detection with `_prev_dash_cooldown` mirroring the existing pierce-ready pattern.
  - **Sprite flash** — `sprite.modulate` is snapped to `Color(2.0, 2.0, 2.0, 1.0)` (overbright white) then tweened back to `Color.WHITE` over `0.2s` via `create_tween()`.
  - **Inward particle burst** — `_dash_ready_particles` (CPUParticles2D, built at runtime in `_ready()`) fires 8 particles simultaneously (`explosiveness = 1.0`). High damping (`80–100`) makes them decelerate into the player origin rather than flying outward — reads as "energy absorbed" / charge restored, not explosion.
  - **Camera jolt** — `camera.shake(1.0)`, softer than pierce-ready's `2.0` since dash recharges more frequently.
- `var _prev_dash_cooldown: float = 0.0` — previous-frame snapshot used by the crossing check. Initialized to `0.0` so the condition `_prev_dash_cooldown > 0.0` never fires at game start.

**Particle tuning reference:**
| Property | Value | Notes |
|---|---|---|
| `amount` | `8` | Sparse — feedback, not spectacle |
| `lifetime` | `0.3s` | Short burst |
| `initial_velocity_min/max` | `40 / 60` | Small outward spawn radius |
| `damping_min/max` | `80 / 100` | Strong drag → inward deceleration feel |
| `scale_amount_min/max` | `1.5 / 2.0` | Larger-than-pixel pips |
| `color` | `Color(0.85, 0.85, 0.95, 0.9)` | Cool white — distinct from pierce cyan |

**Flash tween reference:**
| Step | Value |
|---|---|
| Instant set | `Color(2.0, 2.0, 2.0, 1.0)` — overbright white |
| Tween target | `Color.WHITE` |
| Duration | `0.2s` |

**Known Issues:**
- `scale_amount_curve` (smooth per-particle size fade to 0) was skipped — setting up a `Curve` resource in code is verbose and the damping alone produces the inward-absorption feel. Can be added later with a `CurveTexture` if needed.
- The flash tween writes `sprite.modulate`. If the player takes damage during the 0.2s fade (`_flash_damage` also writes `modulate`), the damage flash will override the dash-ready flash. Acceptable — damage feedback takes priority.

---

### [0.5.0] — 2026-04-19

**Added:**
- **Player HUD** — `scenes/ui/player_hud.gd` + `scenes/ui/player_hud.tscn`. Displays the player's current health as a row of discrete colored heart pips (filled = alive, empty = lost). Built entirely at runtime from `ColorRect` nodes; no texture assets required.
  - `initialize(max_health)` — clears and rebuilds the pip row; called once at startup and again if `max_health` ever increases mid-game.
  - `update_health(current_hp, max_hp)` — recolors all pips and fires a scale-punch animation on the pip that just changed.
  - `_punch_heart(index)` — snaps the target `ColorRect` to `scale = Vector2(1.3, 1.3)` then tweens back to `(1.0, 1.0)` over `0.15s` using `EASE_OUT / TRANS_BACK`.
  - Damage and heal directions are distinguished: damage punches the first newly-empty pip (`index = current_hp`); healing punches the last newly-filled pip (`index = current_hp - 1`).
- **HUD scene structure**: `CanvasLayer` (layer=10) → `MarginContainer` (margin_left=12, margin_top=12) → `HBoxContainer` (separation=4px between pips).
- **HUD integration in `player.gd`**: HUD scene is instanced and added as a child of the Player node in `_ready()`. Connected to `HealthComponent.health_changed` signal alongside the existing combat callbacks — no changes to the signal itself.

**Tuning values:**
| Variable | File | Default | Notes |
|---|---|---|---|
| `heart_size` | `player_hud.gd` | `Vector2(20, 20)` | Pixel size of each heart pip |
| `filled_color` | `player_hud.gd` | `Color(0.9, 0.1, 0.2)` | Red — alive HP |
| `empty_color` | `player_hud.gd` | `Color(0.3, 0.3, 0.3)` | Dark grey — lost HP |
| Punch scale | `_punch_heart()` | `1.3` | Peak scale of the animation pop |
| Punch duration | `_punch_heart()` | `0.15s` | Time to settle back to normal size |
| HUD layer | `player_hud.tscn` | `10` | Renders above world, below fade overlay (100) |
| Margin | `player_hud.tscn` | `12 px` | Left + top offset from screen edge |
| Pip gap | `player_hud.tscn` | `4 px` | HBoxContainer separation |

**Known Issues:**
- HUD is added as a child of the Player node and uses a `CanvasLayer`, so it renders in screen space correctly. However, because the Player is re-instanced each room transition (health resets), the HUD is also re-created each transition. This is acceptable until persistent health across rooms is needed.
- No animation for `initialize()` — pips just appear. A fade-in or stagger could be added later.

---

### [0.4.0] — 2026-04-19

**Added:**
- **4-directional attack** — Attack direction sampled once in `attack.gd:enter()` using `Input.get_vector("move_left","move_right","move_up","move_down")`, snapped to nearest cardinal (up/down/left/right). Falls back to current `facing_direction` if no directional input is held. Stored in `player.attack_direction: Vector2`.
- **Directional hitbox positioning** — Hitbox offset applied in the sampled direction at distance `hitbox_offset = 24.0` px from the player origin. All four directions use the same collision shape; only `position` changes. Resets to `Vector2(hitbox_offset, 0)` on exit.
- **Pogo bounce** — Downward attack (`Vector2.DOWN`) that connects with any hurtbox fires `player.velocity.y = -player.pogo_force` once per swing (`_pogo_triggered` flag prevents multi-bounce from a single attack). Attack duration plays out normally; player travels upward and exits to "Fall" naturally, enabling pogo chains.
- **`hit_landed` signal on hitbox** — `scenes/componets/hitbox.gd` now emits `signal hit_landed` (no args) immediately after `area.take_hit()` succeeds. Consumed by the Attack state to detect pogo conditions; available for future use (SFX, hitpause, combo counters).
- `player.attack_direction: Vector2 = Vector2.RIGHT` — readable by any system that needs to know the last/current attack direction.
- `@export player.pogo_force: float = 300.0` — upward velocity on a successful downward strike.

**Tuning values to balance:**
| Variable | File | Default | Notes |
|---|---|---|---|
| `attack_duration` | `attack.gd` | `0.25s` | How long the hitbox is active |
| `hitbox_offset` | `attack.gd` | `24.0 px` | Distance from player center to hitbox |
| `pogo_force` | `player.gd` | `300.0` | Upward velocity on pogo hit |

**Known Issues:**
- Horizontal attacks update `player.facing_direction` on enter; diagonal inputs with equal x/y magnitude prefer the vertical axis (y-axis wins the `abs(y) > abs(x)` check). Pure diagonals are uncommon in practice but worth noting.
- No visual feedback for attack direction yet — sprite doesn't rotate or change for up/down attacks. Requires animation work.
- `hit_landed` is only on `scenes/componets/hitbox.gd` (the misspelled path player.tscn uses). The canonical `scenes/components/hitbox.gd` used by enemies does NOT have the signal. These need to be consolidated — until then, only the player's hitbox fires `hit_landed`.

---

---

## Patch Notes

### [0.3.0] — 2026-04-19

**Added:**
- Enemy state base classes — `scenes/enemies/states/enemy_state.gd` (`class_name EnemyState`) and `scenes/enemies/states/enemy_state_machine.gd` (`class_name EnemyStateMachine`). Mirror the player's state machine design with a return-value transition pattern. `EnemyStateMachine` adds `force_transition(state_name)` for external interrupt (hurt/death signals).
- `scenes/enemies/base_enemy.gd` (`class_name BaseEnemy`) — shared foundation for all enemies:
  - `@export run_speed`, `max_fall_speed`, `knockback_decay`
  - `apply_gravity(delta)` — uses `ProjectSettings` gravity, caps at `max_fall_speed`
  - `set_facing(direction)` — flips `Sprite2D`, realigns `WallCheck` and `FloorCheck` raycasts
  - `apply_knockback(source_pos, force)` — computes horizontal knockback from damage source
  - `flash()` — over-bright modulate + 0.15s tween back to normal (matches player hit flash)
  - `die()` — emits `enemy_died`, plays 0.3s shrink+fade tween, then `queue_free()`
  - Signals: `enemy_died`, `enemy_damaged(current_hp, max_hp)`
  - Hurtbox/HealthComponent/Zone signal wiring in `_ready()`; `_physics_process` decays knockback
  - `player_in_detection_zone` / `player_in_attack_zone` bool flags updated by zone signals
- `GroundWalker` enemy — `scenes/enemies/ground_walker/ground_walker.gd` + `ground_walker.tscn`:
  - 6-state machine: Idle → Patrol → Chase → Attack / Hurt / Death
  - **Idle**: waits 1–2s (randomised), transitions to Patrol or Chase
  - **Patrol**: walks at `run_speed` in facing direction; reverses + briefly idles at walls (`WallCheck`) or ledges (`FloorCheck`)
  - **Chase**: moves toward player at `run_speed × 1.5`; respects `FloorCheck` (stops at ledges); transitions to Attack when close
  - **Attack**: stops, activates `Hitbox` for 0.4s, chains back to Attack/Chase/Idle based on zone flags
  - **Hurt**: stun 0.3s, knockback drives movement, returns to Chase or Idle
  - **Death**: disables hurtbox + hitbox, calls `die()`, no exit transition
  - Scene structure: `CharacterBody2D` (layer=Enemy/4, mask=World/1) with `Sprite2D`, `CollisionShape2D` (16×16), `StateMachine`, instanced `Hurtbox` (layer=EnemyHurtbox/64), instanced `Hitbox` (layer=EnemyHitbox/16, mask=PlayerHurtbox/32, damage=1, knockback=200), instanced `HealthComponent` (max_health=3), `DetectionZone` (r=120, mask=Player/2), `AttackZone` (r=25, mask=Player/2), `WallCheck` RayCast2D, `FloorCheck` RayCast2D
- `scenes/components/health_component.tscn` — created (was missing; required for scene instancing)
- One `GroundWalker` instance placed in `test_room.tscn` at `(550, 200)`

**Changed:**
- `test_room.tscn` `load_steps` 5 → 6

**Known Issues:**
- Enemy position `(550, 200)` may need adjustment depending on the tilemap layout — if the enemy spawns in the air it will fall to the floor correctly, but verify it lands on a walkable platform
- `EnemyState._ready()` resolves `enemy` via `get_parent().get_parent()` — states must always be direct children of `StateMachine`, which must be a direct child of the enemy node
- No animations — enemy uses a static placeholder tile sprite; `AnimatedSprite2D` + animation states are the next step
- `health_component.gd` auto-connects to `hurtbox.hurt` in its own `_ready()`. `base_enemy._on_hurt` is a second listener on the same signal. Damage is applied once (by HealthComponent); `_on_hurt` only handles knockback, flash, and state transition. This is safe but requires awareness when changing either script.
- All v0.2.x known issues remain

---

## Architecture Changes

### [0.3.0] — 2026-04-19

- **Enemy state machine mirrors player state machine** — same return-value pattern, same `transition_to` / `enter` / `exit` lifecycle. Only addition is `force_transition` for external interrupt. Future enemy types can reuse `EnemyStateMachine` and `EnemyState` unchanged.
- **BaseEnemy as shared foundation** — all per-enemy tuning is `@export` on `BaseEnemy`. Subclasses (`GroundWalker`, future enemies) extend it and add only their specific behaviour. No scene inheritance — concrete scenes instance components directly.
- **Zone-flag pattern** — `player_in_detection_zone` and `player_in_attack_zone` are plain booleans on `BaseEnemy`, updated by Area2D signals. States read these flags instead of doing physics queries. Simple, cheap, and correct for an enemy that only cares about the player.
- **Dual signal listener pattern** — `HealthComponent` and `BaseEnemy` both connect to `hurtbox.hurt`. `HealthComponent` handles damage; `BaseEnemy` handles knockback, flash, and state transitions. Guard in `_on_hurt` (`current_health > 0`) prevents "Hurt" from overriding "Death" when a lethal hit lands.

---

---

## Patch Notes

### [0.2.2] — 2026-04-16

**Changed:**
- `dash_cooldown_max` tuned from 3.0s → 1.0s

---

### [0.2.1] — 2026-04-16

**Added:**
- 8-directional dash — direction sampled via `Input.get_vector("move_left","move_right","move_up","move_down")` at dash start; snapped to nearest of 8 directions and normalized (diagonals travel at same speed as cardinals). Falls back to horizontal facing if no input held.
- `move_up` input action: W key + left-stick up (joypad axis 1, -1.0)
- `move_down` input action: S key + left-stick down (joypad axis 1, +1.0)
- Aerial dash lock — `var used_aerial_dash: bool` on `player.gd`; set when dashing from the air, cleared on landing (`is_on_floor()` check in `_physics_process`). Prevents a second air dash before touching ground.

**Changed:**
- `dash_cooldown_max` tuned from 0.3s → 3.0s (superseded by v0.2.2)
- Dash velocity set to full `Vector2` each frame (`player.velocity = dash_dir * dash_speed`) instead of only overriding `velocity.x`
- All four state dash triggers now also gate on `not player.used_aerial_dash`

---

### [0.2.0] — 2026-04-16

**Added:**
- Dash state (`scenes/player/states/dash.gd`) — 6th player state, triggers from Idle / Run / Jump / Fall (not Attack)
  - `@export dash_speed: float = 400.0` — horizontal burst speed in facing direction
  - `@export dash_duration: float = 0.15` — how long the dash lasts
  - Zeroes `velocity.y` every frame during dash — no gravity applies mid-dash
  - Transitions to `"Fall"` if airborne when done, `"Run"` or `"Idle"` based on input if grounded
- Progression gating on `player.gd`:
  - `@export has_dash: bool = false` — master unlock; nothing happens if false
  - `@export dash_level: int = 0` — 0=locked, 1=basic dash, 2=adds pierce upgrade
- Cooldown system on `player.gd` (ticked every physics frame via `_physics_process`):
  - `@export dash_cooldown_max: float = 1.0` — seconds between any dash (tuned across v0.2.1–v0.2.2)
  - `@export pierce_cooldown_max: float = 0.9` — seconds between pierce dashes
  - `var dash_cooldown: float` and `var pierce_cooldown: float` — live counters, read by states
- Pierce dash mode (active when `dash_level == 2` AND `pierce_cooldown <= 0`):
  - On enter: `hurtbox.monitorable = false` — enemy attacks pass through entirely
  - On enter: cyan sprite tint (`Color(0.3, 0.8, 1.0)`) to visually distinguish from regular dash
  - On exit: hurtbox restored, modulate reset to `Color.WHITE`
  - Resets `pierce_cooldown` to `pierce_cooldown_max` when consumed
- Regular dash enemy-collision behavior:
  - Hurtbox stays active — dashing into an attack deals damage normally
  - `hurtbox.hurt` signal connected in `enter()`, disconnected in `exit()`
  - On hit: `_was_hit` flag set; dash state exits at end of that physics frame (after `move_and_slide()`)
- Pierce-ready visual feedback on `player.gd`:
  - `CPUParticles2D` created at runtime in `_ready()` — 12-particle cyan burst, `one_shot`, `explosiveness=1.0`, omnidirectional spread
  - `_on_pierce_ready()` fires when `pierce_cooldown` crosses from >0 to <=0 — calls `_pierce_ready_particles.restart()` + subtle `camera.shake(2.0)`
- Dash trigger added to `idle.gd`, `run.gd`, `jump.gd`, `fall.gd`:
  ```gdscript
  if Input.is_action_just_pressed("dash") and player.has_dash and player.dash_cooldown <= 0.0 and not player.used_aerial_dash:
      return "Dash"
  ```

**Changed:**
- `player.gd` now has its own `_physics_process` — runs cooldown ticking independently of the state machine (parent runs before child, so cooldowns are always current when states read them)

**Known Issues:**
- Dash state node must be added manually in the Godot editor: open `player.tscn`, select the `StateMachine` node, add child `Node`, name it exactly `"Dash"`, attach `res://scenes/player/states/dash.gd` — the state machine discovers it by node name
- `has_dash` defaults to `false` — must be set to `true` in Inspector for the dash to function (by design — it is a Metroidvania upgrade)
- All issues carried over from v0.1.0 remain (misspelled `componets/` folder, test_room_2 camera bounds Y, test_room_3 missing room_id)

---

## Architecture Changes

### [0.2.0] — 2026-04-16

- **Dash progression pattern** — `has_dash` / `dash_level` on `player.gd` establish the template for all future ability unlocks. New abilities should follow: `has_X: bool = false` to gate, `X_level: int` for upgrades, cooldowns as `@export` vars ticked in `_physics_process`.
- **Signal-based dash interrupt** — Regular dash connects to `hurtbox.hurt` for the duration of the state and disconnects on exit. This keeps the state self-contained without requiring the hurtbox or health system to know anything about the current state. Future states that need to react to damage mid-state should use this same pattern.
- **Runtime particle node** — Pierce-ready particles are built programmatically in `_ready()` rather than as a scene node, keeping the player scene lean for a one-off effect. Once there are more particle effects, they should be moved to named scene nodes for easier inspector tuning.

---

---

## Patch Notes

### [0.1.0] — 2026-04-16

**Added:**
- Player controller (`player.gd`, `player.tscn`) — CharacterBody2D with tunable physics exports (run_speed, jump_force, gravity, acceleration, friction, max_fall_speed)
- State machine system (`state_machine.gd`, `state.gd`) — return-value-driven transitions, manages Idle / Run / Jump / Fall / Attack states
- Idle state — handles idle-to-run, idle-to-jump, idle-to-fall, idle-to-attack transitions
- Run state — handles run-to-idle, run-to-jump, run-to-fall, run-to-attack transitions
- Jump state — jump-cut on early release (multiplier 0.5x), transitions to Fall at apex
- Fall state — coyote jump (0.05s window), jump buffer (0.1s), transitions to Idle/Run on land
- Attack state — activates hitbox for 0.25s, repositions hitbox based on facing direction, reduced horizontal speed during attack
- Camera system (`player_camera.gd`) — look-ahead (30px, lerp speed 5.0), room boundary clamping, screen shake with decay
- Health component (`health_component.gd`) — `max_health` export, `take_damage()`, `heal()`, `reset()`, signals: `health_changed(current, max_health)` and `died`
- Hitbox component (`hitbox.gd`, `hitbox.tscn`) — `damage` and `knockback_force` exports, `activate()` / `deactivate()`, detects Hurtbox overlap via Area2D
- Hurtbox component (`hurtbox.gd`, `hurtbox.tscn`) — invincibility frames (0.5s), emits `hurt(damage, knockback)` signal
- Player damage feedback — white modulate flash on hit, camera screen shake on damage
- Player death — `get_tree().reload_current_scene()` on `died` signal
- Door / room transition object (`door.gd`, `door.tscn`) — `door_id`, `target_scene`, `target_door_id` exports, 0.5s monitoring delay on spawn to prevent instant re-trigger
- GameManager autoload (`game_manager.gd`) — fade-to-black scene transitions (0.3s in/out), player placement at target door's SpawnPoint, `is_transitioning` guard
- BaseRoom class (`base_room.gd`) — deferred camera bound setup, finds player by `"player"` group, exposes `room_id` export for future save system
- 3 test rooms: `test_room.tscn` (~976px wide), `test_room_2.tscn` (480px), `test_room_3.tscn` (~1119px wide) — all bidirectionally connected via doors
- Physics layer map: World (1), Player (2), Enemy (3), PlayerHitbox (4), EnemyHitbox (5), PlayerHurtbox (6), EnemyHurtbox (7), Interactable (8)
- Input actions: `move_left`, `move_right`, `jump`, `attack`, `dash`, `interact`, `pause`, `map` — keyboard + gamepad bindings for all
- Placeholder art: "Lobster Bisk.png" player sprite, placeholder tileset with 2 solid tiles
- TileSet resource (`tileset.tres`) — atlas source, collision on World layer

**Known Issues:**
- `scenes/componets/` (misspelled) is a duplicate of `scenes/components/` — player.tscn currently references the misspelled path; needs consolidation
- `test_room_2` has `RoomBoundsMin` at Y=-1856, likely a mistake from a vertical layout experiment — camera bounds are unusually large vertically in that room
- `test_room_3` has `room_id` left as `""` (export not set in scene) — will matter when save/load is implemented
- `camera_controller.gd` in `scenes/rooms/` is unused — legacy script from before PlayerCamera was built
- `dash` input action is mapped (K / joypad 10) but no Dash state exists — pressing it does nothing
- Player HP resets on every room transition (Player is instanced per-room, not persistent)
- No enemies — combat pipeline is ready (hitbox/hurtbox/health) but untested against a live target
- No UI — no health bar, no pause menu, no map
- No audio — audio folder empty, no AudioStreamPlayers in any scene

---

## Architecture Changes

### [0.1.0] — 2026-04-16

**Initial architecture established:**

- **State Machine** — Node-based, child states of a `StateMachine` node inside the player. States return transition strings from `physics_update()`. Clean separation: each state handles its own gravity + movement + collision, only delegates to `player.*` helper functions.
- **Hitbox/Hurtbox Decoupling** — Hitboxes deal damage; Hurtboxes receive it. HealthComponent listens to Hurtbox's `hurt` signal, not to Hitbox directly. Means any damage source (attack, hazard, projectile) just needs a Hitbox with the right layer mask.
- **Room-local Player** — Each room scene instances its own Player. GameManager repositions it at the target door on transition. Simple but means no cross-room state persistence yet.
- **GameManager Fade Overlay** — ColorRect is created programmatically in `_ready()` and added to a CanvasLayer at layer 100. Not a scene node, so it persists across scene changes as part of the autoload.
- **BaseRoom Setup Pattern** — Rooms don't know about the player at design time. `_setup_room()` runs deferred, finds the player by group, and pushes camera bounds to the PlayerCamera. Rooms are self-contained.

---

## Next Steps

- [ ] Consolidate `scenes/componets/` into `scenes/components/` and update `player.tscn` script references
- [ ] Fix `test_room_2` `RoomBoundsMin` Y value (change from -1856 to correct top boundary)
- [ ] Set `room_id` on `test_room_3`
- [ ] Delete unused `camera_controller.gd` and `main.tscn`'s stale Camera2D2 node
- [x] Build first enemy: CharacterBody2D with patrol AI, EnemyHitbox + EnemyHurtbox + HealthComponent — Ground Walker, v0.3.0 (reworked through v0.9.0)
- [x] Add HUD CanvasLayer with health bar, connected to Player's `health_changed` signal — done in v0.5.0
- [x] Implement Dash state — done in v0.2.0
- [ ] Add jump / land / attack SFX (AudioStreamPlayer nodes, wired to state enter/exit)
- [ ] Add hit / death SFX
- [ ] Make Player persistent across rooms (move Player out of room scenes, into GameManager or a dedicated persistent scene)
- [ ] Implement save/load using `room_id` fields
- [ ] Add proper player animations (replace static sprite with AnimatedSprite2D or AnimationPlayer)
- [ ] Design and build actual level rooms (replace test rooms)
- [ ] Implement pause menu (Escape is already mapped)
- [ ] Implement map screen (M key is already mapped)
- [ ] Add more attack types / combos
- [ ] Add enemy variety (ranged, flying, etc.) — Flyer done in v0.10.0, Shooter in v0.11.0; next: leaper, shield bearer
- [ ] Add collectibles / power-ups (use Interactable layer 8)
