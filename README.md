# UndertaleEngine

An UNDERTALE fangame engine in Godot 4.6. The project currently contains a playable battle prototype and a small test encounter; it is not a complete UNDERTALE implementation.

## Run the demo

Open `project.godot` in Godot 4.6 and run the project. The test scene starts a battle automatically.

- Arrow keys: choose an option or move the red soul.
- Z / Enter: confirm. During a battle message, confirm once to reveal it and again to continue.
- X: go back, skip text, or move at half speed during the enemy turn.
- Fight uses a moving marker: confirm as close to the center as possible. The test enemy becomes spareable after its second ACT option. Flee ends the encounter.

The demo has a basic fight meter, ACT and item callbacks, spare/flee, HP, invulnerability, a timed enemy wave, and win/loss results. It deliberately uses placeholder enemies, items, bullets, and damage values.

## Building an encounter

`EncounterManager.encounter_set(id, enemy0, enemy1, enemy2)` registers up to three enemy scenes, and `EncounterManager.encounter(id)` starts the battle. The result is emitted through `EncounterManager.battle_finished(result)` as `"won"`, `"lost"`, or `"fled"`; the prototype then reloads the scene it entered from. Reloading a scene does not preserve its node state, so a game that needs persistent overworld state should save and restore it around the transition.

Extend `BattleEnemy` and override `init()` and `perform_action(slot)` for enemy-specific actions. Set `spareable` when an enemy can be spared, and set `_hp` / `_hp_max` to its starting health. Items are registered in `ItemManager`; override `Item.use()` to return the battle message, and set `consumable = true` for items that should be removed after use. `Global.player_heal(amount)` updates HP and the battle UI.

To make a bullet pattern, create a scene whose root extends `BattleWave`, then assign it to `wave_scene` on `battle/Battle.tscn`. Override `advance_wave(previous, now)` to schedule events between elapsed times in **seconds**. Use `battle.spawn_bullet(bullet, position)` to add a `BattleBullet` (or a derived scene). `BattleBullet.velocity` is in pixels per second; `lifetime`, wave duration, and invulnerability are in seconds. The included `ExampleWave` shows periodic scheduling with a `while` loop so delayed updates do not silently lose spawns. Bullets and the wave are cleaned up when the turn ends.

## Timing

Soul and bullet motion use the physics timestep; fight-meter progress, typing, waves, and animations use elapsed time in seconds. `CharacterBody2D.move_and_slide()` applies Godot's physics timestep internally, so do not multiply its velocity by delta first. The typer retains unused time between updates and can reveal multiple characters in a long frame.

Physics remains sampled at Godot's configured physics tick rate. Changing the display FPS does not change the intended speeds or durations, but collisions and input are still resolved on physics or render frames, so their precision is bounded by the corresponding timestep.

## Tests

After importing the project once, run:

```sh
godot --headless --editor --path . --quit
godot --headless --path . res://tests/test_runner.tscn
```

The tests cover the battle flow, actual bullet collision, arena bounds, invulnerability, and timing/movement at 30, 60, and 144 updates per second.

## References

The battle flow and extension points were informed by [UndergameEngine](https://github.com/SheepYhangCN/UndergameEngine), [TML233's UndertaleEngine](https://github.com/TML233/UndertaleEngine), [Zhazha's Undertale Engine](https://github.com/onezhazha233/Undertale-Engine-modded-by-Zhazha), and [swapfell-remake-project](https://github.com/onezhazha233/swapfell-remake-project). These are GameMaker projects; this implementation is written for Godot.
