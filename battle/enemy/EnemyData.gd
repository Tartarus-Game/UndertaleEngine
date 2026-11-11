class_name EnemyData extends Resource

@export var enemy_name := "Dummy"
@export_multiline var description := "A training dummy."
@export var max_hp: float = 30.0
@export var attack: float = 3.0
@export var defense: float = 0.0
@export var can_flee := true
@export_range(0.0, 1.0, 0.01) var flee_chance := 1.0
@export_range(0.0, 1.0, 0.01) var flee_chance_per_turn := 0.0
@export var exp_reward := 0
@export var gold_reward := 0
@export var menu_messages: Array[String] = []
