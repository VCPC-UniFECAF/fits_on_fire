class_name WaveSpawnEntry
extends Resource

## Cena do inimigo a instanciar nesta entrada.
@export var enemy_scene: PackedScene
## Quantidade de inimigos desta entrada na onda.
@export_range(1, 99, 1) var count: int = 1
## Intervalo entre spawns desta entrada (-1 usa o padrão da onda).
@export var delay_between_spawns: float = -1.0
## Índice fixo em spawn_points (-1 alterna entre os pontos disponíveis).
@export var spawn_point_index: int = -1
