class_name Combat
extends RefCounted

## Damage is `base × exponent^(attacker strength − defender strength)`,
## rounded to the nearest integer (halves away from zero, Godot `roundi`),
## then clamped to combat.min_damage..combat.max_damage.
## Strength is not rounded before the exponent. HP is not an input.


static func damage(cfg: GameConfig, attacker_strength: float, defender_strength: float) -> int:
	var raw := float(cfg.combat_base_damage) * pow(cfg.strength_exponent_base, attacker_strength - defender_strength)
	return clampi(roundi(raw), cfg.min_damage, cfg.max_damage)


## Hills and Fortify each multiply the defender's strength. They stack.
static func defender_strength(cfg: GameConfig, defense: float, on_hills: bool, fortified: bool) -> float:
	var strength := defense
	if on_hills:
		strength *= cfg.hills_defense_multiplier
	if fortified:
		strength *= 1.0 + cfg.fortify_defense_bonus
	return strength
