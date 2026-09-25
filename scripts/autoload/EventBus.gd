extends Node
## Global signal hub. Nothing but signals lives here, so systems can talk
## without holding references to each other.

# --- Player ---
signal player_health_changed(current: float, maximum: float)
signal player_xp_changed(current: int, needed: int, level: int)
signal player_leveled_up(new_level: int)
signal player_died

# --- Combat ---
signal enemy_died(world_position: Vector2, xp_value: int)
signal damage_dealt(world_position: Vector2, amount: float, is_crit: bool)
signal kills_changed(kills: int)

# --- Run flow ---
signal run_time_changed(seconds: float)
signal run_started
signal run_ended(victory: bool)
signal wave_announced(text: String)

# --- Progression ---
signal upgrade_choices_ready(choices: Array)
signal upgrade_applied(upgrade_id: String, new_level: int)
