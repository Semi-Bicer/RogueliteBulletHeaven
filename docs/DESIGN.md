# Bullet Heaven — System Design

Reference specification for the 2D top-down **reverse bullet hell / survivor-like**
prototype. Engine: **Godot 4.7.2**, GDScript, `gl_compatibility` renderer.

This document describes the **full system as it was built and verified**. Parts of
it were then intentionally stripped back out of the repository so the team can
implement them. Sections marked **[TO BUILD]** are not in the codebase right now —
they are the spec for that work. Sections marked **[IN REPO]** exist today and are
the foundation the rest plugs into.


---

## 1. Core loop

1. The player only steers. **Every weapon fires itself** on a cooldown.
2. Enemies spawn in a ring just off-screen and walk straight at the player.
3. Enemies drop **XP gems**, which fly to the player once inside the pickup radius.
4. Enough XP leads to a **level up**: the tree pauses and 3 random upgrades are offered.
5. 15:00 survived = victory. 0 HP = defeat.

---

## 2. Architecture rules

- **`EventBus` holds signals and nothing else.** No system keeps a reference to
  another system; they talk through the bus. Adding a listener never requires
  touching the emitter.
- **`PlayerStats` is the single source of every number an upgrade can change.**
  Weapons read multipliers from it instead of hardcoding values, so one passive
  upgrade improves every weapon for free, present and future.
- **Content lives in data, not in code paths.** Enemy archetypes are dictionary
  entries; upgrades are dictionary entries; difficulty is a table of phases.
  Adding content should never mean adding an `if`.
- **Scenes stay dumb, scripts own behaviour.** One `Enemy.tscn` serves every
  archetype — stats are injected by the spawner after `add_child`.

### Autoloads

| Autoload | Responsibility |
| --- | --- |
| `EventBus` | Signal hub. Declarations only, zero logic. |
| `GameState` | One run of state: clock, kills, level, XP curve, difficulty ramp. |
| `UpgradeDB` | Upgrade catalogue plus the roll that builds a legal set of choices. |

### Signal contract (`EventBus`)

```gdscript
# Player
signal player_health_changed(current: float, maximum: float)
signal player_xp_changed(current: int, needed: int, level: int)
signal player_leveled_up(new_level: int)
signal player_died

# Combat
signal enemy_died(world_position: Vector2, xp_value: int)
signal damage_dealt(world_position: Vector2, amount: float, is_crit: bool)
signal kills_changed(kills: int)

# Run flow
signal run_time_changed(seconds: float)
signal run_started
signal run_ended(victory: bool)
signal wave_announced(text: String)

# Progression
signal upgrade_choices_ready(choices: Array)
signal upgrade_applied(upgrade_id: String, new_level: int)
```

Anything that only displays information (a HUD, a damage number, a boss banner)
must be a pure consumer of these signals and must never be read back by gameplay.

---

## 3. Collision layers

| Bit | Layer | Used by |
| --- | --- | --- |
| 1 | `player` | `Player` body |
| 2 | `enemy` | `Enemy` bodies (mask 2 as well, so they jostle each other) |
| 3 | `player_attack` | projectiles, orbs, novas |
| 4 | `pickup` | XP gems |

- The player body has **mask 0** — it walks through enemies. Contact damage is
  handled by a separate `HurtBox` `Area2D` (mask 2), polled on a 0.45 s tick.
- Attacks are `Area2D` with mask 2 and detect enemies via `body_entered`.
- `PickupArea` is an `Area2D` with mask 8 whose `CircleShape2D` is
  `resource_local_to_scene = true`, so its radius can be grown per player.

---

## 4. Player **[IN REPO]**

`scenes/player/Player.tscn` — `CharacterBody2D`, `motion_mode = 1` (floating).

```
Player
├── Body            Polygon2D, diamond
├── CollisionShape2D
├── HurtBox         Area2D, mask 2 — contact damage
├── PickupArea      Area2D, mask 8 — gem magnet, radius from stats
├── Weapons         Node2D — every weapon instance is a child here
└── Camera2D        position smoothing on, offset driven by screen shake
```

Responsibilities: movement plus arena clamp, health / armor / regen, screen shake,
hit flash, weapon slots, and `apply_upgrade()` — the single entry point where an
upgrade id turns into a weapon or a stat change.

### `PlayerStats`

Plain `RefCounted`. Base values: 100 HP, 190 move speed, 72 pickup range.

| Field | Meaning |
| --- | --- |
| `max_health_bonus` | flat HP added |
| `damage_mult` | all weapon damage |
| `fire_rate_mult` | all weapon cooldowns (and orbit spin) |
| `move_speed_mult` | movement |
| `area_mult` | attack size / orbit radius |
| `pickup_range_mult` | gem magnet radius |
| `xp_gain_mult` | XP per gem |
| `health_regen` | HP per second |
| `armor` | flat reduction per hit, floored at 1 damage |
| `extra_projectiles` | extra shots on projectile weapons |

`apply(stat, amount)` is purely additive — every upgrade in the catalogue is
expressed as a delta, which is what keeps the catalogue data-only.

---

## 5. Weapons

### `WeaponBase` **[IN REPO]**

`Node2D`. Owns the cooldown, never reads input:

```gdscript
_cooldown_left -= delta * player.stats.fire_rate_mult
if _cooldown_left <= 0.0:
    _cooldown_left += maxf(0.05, base_cooldown)
    _fire()
```

Subclass contract:

- `_configure()` — recompute stats from `level`. Called on spawn **and** on every
  level up. Never put per-frame work here.
- `_fire()` — do the thing.
- Helpers provided: `damage_of(base)`, `area_of(base)`, `nearest_enemies(count)`.

A weapon is added by `Player._apply_weapon_upgrade()`: instantiate the scene, set
`weapon_id`, `add_child` under `Weapons`, then `setup(player)`. If the weapon is
already owned, `level_up()` is called instead.

Spawned objects (projectiles, novas) are parented to the node in the
`projectile_parent` group — the spawner — so they live in world space rather than
inheriting the player transform.

### The three reference weapons **[TO BUILD]**

**Magic Missile** — projectile weapon, the starting weapon.

| Stat | Value |
| --- | --- |
| damage | `10 + (level-1) * 4` |
| bolts | `1 + (level-1) / 2`, plus `stats.extra_projectiles` |
| pierce | `(level-1) / 3` |
| cooldown | `max(0.28, 0.85 - (level-1) * 0.05)` |
| speed | 430 |

Targets the N nearest enemies; surplus bolts reuse the last target with a random
plus/minus 0.35 rad spread. With no enemies alive it fires along `player.facing`.

*Projectile:* `Area2D`, light homing (`slerp` toward the nearest enemy within
260 px at strength 3.0/s), 2.4 s lifetime, tracks already-hit bodies so pierce
cannot double-dip the same enemy.

**Orbital Shield** — no cooldown, permanent orbiting damage.

| Stat | Value |
| --- | --- |
| orb count | `2 + (level-1) / 2` |
| damage | `8 + (level-1) * 3` |
| orbit radius | `86 + (level-1) * 5`, scaled by `area_mult` |
| spin | `2.2 + (level-1) * 0.12` rad/s, scaled by `fire_rate_mult` |

Sets `base_cooldown = 999` and overrides `_process` to spin instead of firing.
`_configure()` rebuilds the orbs. Each orb keeps a per-enemy re-hit cooldown of
0.5 s in a dictionary keyed by instance id, so a parked enemy is damaged at a
fixed rate rather than every frame.

**Shock Nova** — periodic AoE centred on the player.

| Stat | Value |
| --- | --- |
| damage | `14 + (level-1) * 5` |
| radius | `120 + (level-1) * 14`, scaled by `area_mult` |
| cooldown | `max(1.1, 2.6 - (level-1) * 0.16)` |

Spawns a one-shot `Area2D` whose `CircleShape2D` radius is tweened 8 to radius over
0.32 s (cubic ease-out), damaging each body exactly once, then fades and frees.
Adds a small screen shake on cast.

---

## 6. Enemies **[IN REPO, minus the boss]**

One scene, one script, stats injected via `configure(data, mult)`.

Behaviour: walk straight at the player, `move_and_slide` with mask 2 so the swarm
jostles itself into natural clumps. Knockback on hit (12 for bosses, 60 otherwise)
decays toward zero. On death: leave the `enemies` group immediately, stop physics,
`GameState.add_kill()`, emit `enemy_died`, then a 0.14 s pop tween into `queue_free`.

| Type | HP | Speed | Damage | XP | Radius |
| --- | --- | --- | --- | --- | --- |
| `slime` | 11 | 52 | 7 | 1 | 13 |
| `bat` | 7 | 96 | 5 | 1 | 10 |
| `brute` | 46 | 40 | 14 | 4 | 20 |
| `husk` | 120 | 34 | 20 | 9 | 27 |
| `warden` **[TO BUILD]** | 900 | 46 | 30 | 60 | 42 |

Scaling at spawn time, from `GameState.difficulty() = 1 + run_time/60 * 0.28`:

- health `* mult`
- speed `* min(1 + (mult-1) * 0.15, 1.6)` — capped, or late enemies outrun the player
- contact damage `* (1 + (mult-1) * 0.5)`

### Spawner director **[IN REPO, minus the boss]**

Spawns in a ring 620–780 px from the player, clustered into a plus/minus 0.6 rad arc
per batch so a wave reads as a swarm arriving from one side rather than an even
ring. Culls non-boss enemies past 1600 px every 2 s. Hard cap 320 alive.

| From | Interval | Batch | Pool |
| --- | --- | --- | --- |
| 0:00 | 1.30 s | 2 | slime |
| 1:00 | 1.15 s | 3 | slime, bat |
| 2:30 | 1.00 s | 4 | slime, bat x2 |
| 4:30 | 0.90 s | 5 | slime, bat, brute |
| 7:00 | 0.80 s | 6 | bat, brute, husk |
| 10:00 | 0.70 s | 7 | bat, brute, husk x2 |
| 13:00 | 0.55 s | 9 | brute, husk x2 |

**Warden boss [TO BUILD]** — every 300 s (`BOSS_INTERVAL`), emit
`wave_announced("WARDEN INCOMING")`, spawn one `warden` at a random angle, and
exempt it from distance culling.

---

## 7. Progression

### XP curve **[IN REPO]**

`GameState.xp_for_level(lv) = int(5 + lv * 3 + pow(lv, 1.55))`

`add_xp()` loops rather than branches, because one large gem can grant several
levels at once; each one emits `player_leveled_up` separately.

### XP gems **[IN REPO]**

`Area2D`, layer 8, `monitoring = false` — the **player** `PickupArea` finds the
gem and calls `attract_to(player)` on it. Then the gem homes in, accelerating at
1400 px/s squared up to 720 px/s.

> **Known trap, already fixed here:** the gem must collect when
> `distance <= step` as well as `distance <= COLLECT_DISTANCE`, where
> `step = speed * delta`. Without that check, one long frame carries the gem past
> the player and it oscillates forever without ever being picked up.

Gem tiers are cosmetic: 5 XP or more is purple and 1.25x, 25 XP or more is orange
and 1.6x.

### Upgrade catalogue **[TO BUILD]**

`UpgradeDB.UPGRADES` — a flat array of dictionaries. Two kinds:

- `"kind": "weapon"` — needs a `scene` path. Grants the weapon at level 0, or
  calls `level_up()` on it.
- `"kind": "passive"` — needs `stat` and `amount`, applied additively to
  `PlayerStats`.

Plus a `consumable` fallback (`Ration`, heal 30) so the screen is never short of
choices when everything is maxed.

| id | Name | Effect | Max |
| --- | --- | --- | --- |
| `magic_missile` | Magic Missile | weapon | 8 |
| `orbital_shield` | Orbital Shield | weapon | 8 |
| `shock_nova` | Shock Nova | weapon | 8 |
| `might` | Might | `damage_mult` +0.12 | 6 |
| `haste` | Haste | `fire_rate_mult` +0.10 | 6 |
| `swiftness` | Swiftness | `move_speed_mult` +0.08 | 5 |
| `vitality` | Vitality | `max_health_bonus` +20, heals the same | 6 |
| `regeneration` | Regeneration | `health_regen` +0.6 | 5 |
| `armor` | Armor | `armor` +1 | 5 |
| `area` | Resonance | `area_mult` +0.12 | 5 |
| `multishot` | Split Shot | `extra_projectiles` +1 | 3 |
| `magnet` | Magnet | `pickup_range_mult` +0.30 | 4 |
| `greed` | Greed | `xp_gain_mult` +0.15 | 4 |

`roll(owned, count)` rules:

- drop anything already at `max_level`;
- drop **unowned** weapons once `MAX_WEAPONS` (3) are held — owned weapons stay
  eligible so they can still be levelled;
- shuffle, take `count`, pad with the fallback.

Each returned choice carries `current_level`, `next_level` and `is_new` so the
picker can label a card `NEW` or `LV n` without looking anything up.

Two stats need follow-up work after being applied, handled in
`Player._post_passive()`: `max_health_bonus` also heals for the amount gained,
and `pickup_range_mult` must resize the `PickupArea` shape.

---

## 8. Run flow and presentation **[TO BUILD]**

`Main.gd` is the only node that knows about all of it. Responsibilities:

- spawn a gem on `enemy_died`, spawn a damage number on `damage_dealt`;
- on `player_leveled_up`, increment a **pending** counter and open the picker;
- opening the picker sets `get_tree().paused = true`; the picker node itself runs
  with `process_mode = 3` (ALWAYS) so it still responds;
- on a pick: apply, decrement, unpause, and `call_deferred` the next screen if
  more levels are still queued — one gem can grant several;
- on `run_ended`, unpause, clear the queue, show the summary;
- `R` reloads the scene once the run is over.

> **Known trap, already fixed here:** `enemy_died` and `damage_dealt` are emitted
> from inside physics callbacks, where adding a node with a collision shape to the
> tree throws *"Can't change this state while flushing queries"*. Both spawns must
> go through `add_child.call_deferred()`, and anything that needs `create_tween()`
> must have its `setup()` deferred too, since a tween requires the node to already
> be in the tree.

### HUD **[TO BUILD]**

Pure `EventBus` consumer: XP bar across the top, `LV n` top-left, run clock
centre, kill count top-right, health bar bottom-left, and a centred wave banner
that fades in, holds 1.4 s and fades out on `wave_announced`.

### Level-up picker **[TO BUILD]**

Dimmed full-screen `Control`, `process_mode = ALWAYS`, cards built at runtime from
the rolled choices (228x200 buttons, tinted with the upgrade colour, labelled
`NEW` or `LV n`). First card grabs focus after one frame so the screen is
keyboard-playable.

### Game over / victory **[TO BUILD]**

One screen for both outcomes, differing in title and colour, showing time, level
and kills, with a restart button.

---

## 9. Balance notes

- Contact damage is a 0.45 s tick of the **highest** damage among the bodies
  currently overlapping — not a sum. Standing in a crowd is survivable for a few
  seconds, which is what makes kiting the skill of the game.
- Armor is flat but damage is floored at 1, so armor can never make the player
  immune to the weakest enemy.
- A stationary player dies at roughly 0:32 with only the starting weapon. That is
  the intended pressure: movement is mandatory.

---

## 10. Testing

Headless runs catch parse errors, physics-flush errors and leaks without opening
the editor:

```
godot --headless --path . --import          # import + compile check
godot --headless --path . --quit-after 900  # ~15 s smoke run
godot --headless --path . --check-only --script res://scripts/<file>.gd
```

`--check-only` reports autoload identifiers (`EventBus`, `GameState`, ...) as
*"Identifier not found"* because autoloads are not registered in that mode. That
is expected noise; only **Parse Error** lines matter.

For a longer soak, temporarily drive the player from `_physics_process` with
`Vector2.from_angle(GameState.run_time * k)` and raise `Engine.time_scale`. A full
15-minute run then takes about a minute of wall clock. Remove the harness before
handing the code over.
