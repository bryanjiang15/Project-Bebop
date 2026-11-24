extends SceneTree

## Ticket 24 pace. Typical site, the turn-25 rebuild, and the same seeds
## under the shipped economy and the previous costs.
##   godot --headless --path . --script res://tests/pace_report.gd
##   godot --headless --path . --script res://tests/pace_report.gd -- --site


const PaceSite = preload("res://tests/pace_site.gd")
const SEEDS: Array[int] = [12345, 12011, 12023, 12059, 12073, 16016]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var site_only := OS.get_cmdline_user_args().has("--site")
	var shipped: GameConfig = GameConfig.load_file()
	shipped.log_enabled = false
	print("\n=== typical site, shipped ===")
	for order in ["expand", "granary"]:
		_print_site(PaceSite.play_site(shipped, order))
	print("\n=== typical site, previous costs ===")
	var previous: GameConfig = GameConfig.load_file()
	PaceSite.apply_old(previous)
	previous.log_enabled = false
	for order in ["expand", "granary"]:
		_print_site(PaceSite.play_site(previous, order))
	print("\n=== rebuild at turn 25, shipped expand ===")
	var again: GameConfig = GameConfig.load_file()
	again.log_enabled = false
	_print_rebuild(PaceSite.rebuild(again))
	if site_only:
		quit(0)
		return
	print("\n=== seeds, shipped ===")
	for seed_value in SEEDS:
		var cfg: GameConfig = GameConfig.load_file()
		cfg.log_enabled = false
		_print_seed(PaceSite.play_seed(cfg, seed_value))
	print("\n=== seeds, previous costs ===")
	for seed_value in SEEDS:
		var cfg: GameConfig = GameConfig.load_file()
		PaceSite.apply_old(cfg)
		cfg.log_enabled = false
		_print_seed(PaceSite.play_seed(cfg, seed_value))
	print("\nPACE REPORT OK")
	quit(0)


func _print_site(stats: Dictionary) -> void:
	print("order %s first_city %s first_forest %s (%s) first_building %s first_settler %s second_city %s" % [
		stats["order"], stats["first_city"], stats["first_forest"], stats["first_spell"],
		stats["first_building"], stats["first_settler"], stats["second_city"],
	])
	print("  casts T15 %s T25 %s T26-35 %s T50 %s warriors %s units %s ended %s on %s" % [
		stats["casts_t15"], stats["casts_t25"], stats["casts_26_35"], stats["casts_t50"],
		stats["warriors"], stats["units"], stats["ended"], stats["end_turn"],
	])
	for mark in [15, 25, 50]:
		print("  ", _snap_line(mark, stats.get("t%d" % mark, {})))


func _print_seed(stats: Dictionary) -> void:
	print("seed %s first_city %s first_forest %s first_building %s first_settler %s second_city %s ended %s on %s" % [
		stats["seed"], stats["first_city"], stats["first_forest"], stats["first_building"],
		stats["first_settler"], stats["second_city"], stats["ended"], stats["end_turn"],
	])
	print("  casts T15 %s T25 %s T26-35 %s T50 %s warriors %s units %s" % [
		stats["casts_t15"], stats["casts_t25"], stats["casts_26_35"], stats["casts_t50"],
		stats["warriors"], stats["units"],
	])
	for mark in [15, 25, 50]:
		print("  ", _snap_line(mark, stats.get("t%d" % mark, {})))


func _print_rebuild(row: Dictionary) -> void:
	print("loss T%s settler T%s found T%s elapsed %s within_7 %s cities %s prod %s" % [
		row["loss_turn"], row["settler_turn"], row["found_turn"], row["elapsed"],
		row["within_7"], row["cities_after_loss"], row["trainer_prod"],
	])
	print("  ", row["note"])


func _snap_line(mark: int, snap: Dictionary) -> String:
	if snap.is_empty():
		return "T%d —" % mark
	return "T%d cities %s pop %s income %s bank %s" % [mark, snap["cities"], snap["pop"], snap["income"], snap["bank"]]
