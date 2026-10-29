class_name Balance
extends RefCounted

# GDD 7.3 节
const TAGS: Array[StringName] = [&"fire", &"frost", &"lightning", &"mechanical", &"undead", &"holy", &"melee"]
# GDD 6.1、6.2 节
const WEAPON_KINDS: Array[StringName] = [&"pistol", &"shotgun", &"rifle", &"sniper", &"staff", &"melee", &"special"]
const WEAPON_ENERGY_RANGE: Dictionary = {
	&"pistol": [0, 1], &"shotgun": [3, 5], &"rifle": [1, 2], &"sniper": [6, 8],
	&"staff": [2, 4], &"melee": [0, 0], &"special": [8, 15],
}
const WEAPON_QUALITY_MULT: Array[float] = [1.0, 1.15, 1.3, 1.5, 1.75]
# GDD 8.1、10.4 节
const QUALITIES: Array[StringName] = [&"common", &"rare", &"epic", &"legendary"]
const RELIC_PRICE_RANGE: Dictionary = {
	&"common": [15, 20], &"rare": [30, 40], &"epic": [70, 90], &"legendary": [150, 180],
}
# GDD 11.4 节
const ENEMY_ARCHETYPES: Array[StringName] = [&"swarm", &"melee", &"charger", &"shooter", &"bomber", &"splitter", &"assassin", &"tank"]
# GDD 9.1 节；三类伤害分别计数，共 18 项
const STAT_BASE: Dictionary = {
	&"max_hp": 100.0, &"hp_regen": 0.0, &"lifesteal": 0.0, &"armor": 0.0,
	&"dodge": 0.0, &"damage": 0.0, &"melee_damage": 0.0, &"ranged_damage": 0.0,
	&"elemental_damage": 0.0, &"attack_speed": 0.0, &"crit_chance": 0.05,
	&"area": 0.0, &"move_speed": 0.0, &"range": 0.0, &"pickup_range": 2.0,
	&"luck": 0.0, &"income": 0.0, &"max_energy": 200.0,
}
const STAT_CAP: Dictionary = {
	&"lifesteal": 0.25, &"dodge": 0.6, &"attack_speed": 3.0, &"crit_chance": 1.0,
	&"area": 2.0, &"move_speed": 1.0, &"range": 1.0,
}
# GDD 9.1、8.1 节
const STAT_FLOOR: Dictionary = {&"armor": -20.0, &"max_hp": 10.0}
# GDD 8.2、8.3 节
const RELIC_EXTRA_MODS: Array[StringName] = [
	&"max_hp_pct", &"pickup_range_pct", &"resonance_gain", &"soul_damage", &"mark_multiplier",
	&"mark_cap", &"soul_slots", &"fire_damage", &"soul_attack_speed", &"slow_effect",
	&"chain_count", &"undead_heal_cap",
]
# GDD 11.3、11.5 节
const ENEMY_HP_GROWTH: float = 0.22
const ENEMY_DAMAGE_GROWTH: float = 0.12
const ENEMY_XP_GROWTH: float = 0.06
const ELITE_HP_MULT: float = 6.0
const ELITE_XP_MULT: float = 5.0
# GDD 7.1、10.4 节
const MERGE_DAMAGE_MULT: float = 2.2
const SOUL_PRICE_BY_TIER: Array[int] = [20, 45, 90, 160]
# GDD 10.2 节
const PRICE_GROWTH: float = 0.08
const SELL_RATIO: float = 0.5
# GDD 9.2、9.3 节
const XP_BASE: float = 10.0
const XP_PER_LEVEL: float = 8.0
const XP_PER_LEVEL_SQ: float = 0.5
const UPGRADE_QUALITY_BASE: Array[float] = [0.70, 0.22, 0.07, 0.01]
