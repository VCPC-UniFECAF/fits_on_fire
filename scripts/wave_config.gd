class_name WaveConfig
extends Resource

enum AdvanceMode {
	INHERIT,
	DELAY,
	CLEAR_ALL,
	BOTH,
}

@export_group("Identificação")
@export var display_name: String = ""

@export_group("Spawns")
@export var entries: Array[WaveSpawnEntry] = []
@export var delay_between_spawns: float = 0.4

@export_group("Timing da onda")
@export var delay_before_wave: float = 0.0
@export var advance_mode: AdvanceMode = AdvanceMode.INHERIT
## Pausa após a onda quando advance_mode usa DELAY ou BOTH (-1 usa o valor do spawner).
@export var delay_after_wave: float = -1.0


func get_total_spawn_count() -> int:
	var total := 0
	for entry in entries:
		if entry != null:
			total += entry.count
	return total
