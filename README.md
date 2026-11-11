# UndertaleEngine

An UNDERTALE fangame engine in Godot 4.6. It currently contains a small overworld, a playable battle prototype, and an example encounter; it is not a complete UNDERTALE implementation.

## Run the demo

Open `project.godot` in Godot 4.6 and run the project. Walk toward the light, face it, and press Z to start the test encounter.

- Arrow keys: walk, choose an option, or move the red soul.
- Z / Enter: confirm. During a battle message, confirm once to reveal it and again to continue.
- X: go back, skip text, or move at half speed during the enemy turn.
- Up / Down scroll longer item descriptions and battle messages.
- Fight uses a moving marker: confirm as close to the center as possible. The test enemy becomes spareable after its second ACT option. Flee ends the encounter.

The demo has a fight meter, damage feedback, ACT and item callbacks, item use/info/drop, spare/flee, HP, invulnerability, a timed enemy wave, and win/loss results. It deliberately uses placeholder enemies, bullets, and damage values.

## Building an encounter

`EncounterManager.encounter_set(id, enemy0, enemy1, enemy2, encounter_text)` registers up to three enemy scenes, and `EncounterManager.encounter(id)` starts the battle. During battle the previous scene is detached and stops processing, then reattached as the same instance. Position and ordinary node state therefore survive the encounter. Detaching still calls `_exit_tree()`, and reattachment calls `_enter_tree()`; `_ready()` is not called again unless explicitly requested. After restoration, `EncounterManager.battle_finished(result)` emits `"won"`, `"lost"`, or `"fled"`.

Extend `BattleEnemy` for enemy-specific behavior. Assign an `EnemyData` resource in the inspector for the name, description, maximum HP, defense, attack, and whether escape is allowed; it is duplicated for each enemy instance. `action_set(slot, name, callback)` can register an ACT that returns a message, or override `perform_action(slot)`. Set `spareable` when an enemy can be spared, and override `get_turn_dialog()` for optional pre-wave dialogue.

Items are registered in `ItemManager`; override `Item.use()`, `info()`, and `drop()` to return messages, and set `consumable = true` for items that should be removed after use. The example includes Monster Candy, Spider Donut, and Butterscotch Pie. `Global.player_heal(amount)` updates HP and the battle UI. `OverworldChar` and `OverworldFrisk` provide movement and animation; `OverworldTrigger.triggered` can be connected to an encounter or a game's own interaction.

To make a bullet pattern, create a scene whose root extends `BattleWave`, then assign it to `wave_scene` on `battle/Battle.tscn` or to an enemy's `wave_scene`. The first active enemy providing a wave takes precedence; override `get_wave_scene(turn)` to vary it. Override `advance_wave(previous, now)` to schedule events between elapsed times in **seconds**. Use `battle.spawn_bullet(bullet, position)` to add a `BattleBullet` (or a derived scene). `BattleBullet.velocity` is in pixels per second; `lifetime`, wave duration, and invulnerability are in seconds. The included `ExampleWave` shows periodic scheduling with a `while` loop so delayed updates do not silently lose spawns. Bullets and the wave are cleaned up when the turn ends.

`Screen` provides button groups; `ScreenManagerNode` can select one active screen. The battle's main button row uses the same `Screen` selection mechanism.

## Timing

Soul and bullet motion use the physics timestep; fight-meter progress, typing, waves, and animations use elapsed time in seconds. `CharacterBody2D.move_and_slide()` applies Godot's physics timestep internally, so do not multiply its velocity by delta first. The typer retains unused time between updates and can reveal multiple characters in a long frame.

Physics remains sampled at Godot's configured physics tick rate. Changing the display FPS does not change the intended speeds or durations, but collisions and input are still resolved on physics or render frames, so their precision is bounded by the corresponding timestep.

## Tests

After importing the project once, run:

```sh
godot --headless --editor --path . --quit
godot --headless --path . res://tests/test_runner.tscn
```

The tests cover the battle flow, overworld interaction and scene restoration, item effects, actual bullet collision, arena bounds, invulnerability, and timing/movement at 30, 60, and 144 updates per second.

## References

The battle flow and extension points were informed by [UndergameEngine](https://github.com/SheepYhangCN/UndergameEngine), [TML233's UndertaleEngine](https://github.com/TML233/UndertaleEngine), [Zhazha's Undertale Engine](https://github.com/onezhazha233/Undertale-Engine-modded-by-Zhazha), and [swapfell-remake-project](https://github.com/onezhazha233/swapfell-remake-project). These are GameMaker projects; this implementation is written for Godot.
