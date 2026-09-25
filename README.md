# Bullet Heaven

2D top-down **shoot 'em up / bullet heaven / reverse bullet hell** (survivor-like),
built with **Godot 4.7.2** and GDScript.

You never press an attack button. You steer; the weapons fire themselves.

## Status: foundation only

This repository currently holds the **systems layer**, not a finished game. It
runs, but nothing shoots yet, and there is no interface of any kind.

**Working today:** movement, camera and screen shake, the enemy spawner and its
difficulty phases, contact damage, XP gems and the pickup magnet, the XP curve
and level-up signal, and the `EventBus` contract every system talks through.

**Not in the repo, by design:**

| Missing | Spec |
| --- | --- |
| The three weapons (Magic Missile, Orbital Shield, Shock Nova) | `docs/DESIGN.md` §5 |
| The thirteen upgrades in `UpgradeDB.UPGRADES` | `docs/DESIGN.md` §7 |
| Warden boss and its 5-minute cadence | `docs/DESIGN.md` §6 |
| HUD, level-up picker, game over / victory screen, damage numbers | `docs/DESIGN.md` §8 |

**[`docs/DESIGN.md`](docs/DESIGN.md) is the specification.** It documents each
missing piece with the exact stats, formulas and scaling the verified prototype
used, plus the two engine traps that cost real debugging time.

## Controls

| Input | Action |
| --- | --- |
| `WASD` / arrow keys | Move |
| `R` | Restart, once the run has ended |

## Core loop

1. **Auto-firing weapons** hit whatever is nearest — you only position yourself.
2. **Swarm waves** spawn in a ring just off-screen, in phases that get denser and
   nastier with the run clock.
3. **XP gems** drop on death and fly to you once they enter your pickup radius.
4. **Level up** pauses the game and offers **3 random upgrades** — a new weapon,
   a weapon level, or a passive stat.
5. **Survive.** 15:00 is a win, 0 HP is a loss.

## Project layout

```
scenes/
  main/        Main.tscn        run root: starts the run, spawns gems
  player/      Player.tscn      movement, health, weapon slots, pickup radius
  enemies/     Enemy.tscn       one scene, all archetypes (stats injected)
  pickups/     XPGem.tscn
scripts/
  autoload/    EventBus (signals), GameState (run state), UpgradeDB (catalogue)
  data/        PlayerStats — every number an upgrade can touch
  weapons/     WeaponBase — the cooldown skeleton every weapon extends
  systems/     EnemySpawner — the difficulty director
docs/
  DESIGN.md    the specification
```

### Design notes

- **EventBus** is signals only, so no system holds a reference to another.
- **PlayerStats** holds multipliers; weapons read them instead of hardcoding
  numbers, so a passive upgrade affects every weapon for free.
- **UpgradeDB.UPGRADES** is the single place to add progression content.
- `EnemySpawner.TYPES` / `PHASES` are the whole difficulty curve.

## Adding a weapon

1. `scripts/weapons/MyWeapon.gd` → `extends WeaponBase`, override `_configure()`
   (stats from `level`) and `_fire()`.
2. `scenes/weapons/MyWeapon.tscn` → a `Node2D` with that script.
3. Add an entry to `UpgradeDB.UPGRADES` with `"kind": "weapon"` and the scene path.

## Running

Open the folder with Godot 4.7.2, or:

```
godot --path .
```

Headless smoke test:

```
godot --headless --path . --quit-after 900
```
