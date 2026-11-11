extends Node2D

@onready var status: Label = $Status


func _ready() -> void:
	$EncounterTrigger.triggered.connect(_on_triggered)
	$PatternTrigger.triggered.connect(_on_pattern_triggered)
	EncounterManager.encounter_set(-2, preload("res://battle/enemy/test/showcase_enemy.tscn"), null, null, "* A pattern dummy appeared.")
	WorldMenu.register_phone("Guide", "* The yellow star lets you save.\n* The green star opens a shop.")
	EncounterManager.battle_finished.connect(_on_battle_finished)


func _on_triggered(_actor: OverworldChar) -> void:
	EncounterManager.encounter(-1)


func _on_pattern_triggered(_actor: OverworldChar) -> void:
	EncounterManager.encounter(-2)


func _on_battle_finished(result: String) -> void:
	status.text = "Battle: %s. Walk to the light and press Z to try again." % result


func _draw() -> void:
	draw_rect(Rect2(16, 32, 608, 416), Color(0.08, 0.10, 0.14))
	draw_rect(Rect2(16, 32, 608, 416), Color(0.55, 0.58, 0.62), false, 3.0)
