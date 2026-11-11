extends Node

signal room_changed(path: String, position: Vector2)


func get_player() -> OverworldFrisk:
	var players := get_tree().get_nodes_in_group("overworld_player")
	return players[0] as OverworldFrisk if not players.is_empty() else null


func change_room(path: String, destination: Variant = null) -> bool:
	if not ResourceLoader.exists(path):
		return false
	await SceneManager.change_scene_to_path(path)
	var player := get_player()
	if player and destination is Vector2:
		player.global_position = destination
	room_changed.emit(path, player.global_position if player else Vector2.ZERO)
	return true
