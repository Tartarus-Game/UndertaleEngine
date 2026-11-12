# UndertaleEngine

A Godot 4.6 foundation for UNDERTALE-style fangames. It includes a small playable overworld, encounters, a battle loop, reusable attack patterns, dialogue, events, shops, and save/load. The included characters, art, balancing, translations and attacks are examples rather than a complete recreation of UNDERTALE.

See [the development backlog](docs/TODO.md) for the current implementation status, known gaps, and verification work.

## Run the demo

Open `project.godot` in Godot 4.6 and run the project.

- Arrow keys: move or select. **Z / Enter**: interact or confirm. **X**: cancel, skip text, or move slowly in a battle. **C**: open the overworld menu.
- The central light starts the original sample encounter. The top-right light starts the pattern dummy, with a blue soul, bones, a platform, a charged beam, a ring and a pulse.
- The yellow, green and blue lights are a save point, a shop and a dialogue interaction. The save point can save, load and choose among three slots. The orange light leads to a second room.
- **F3** opens the debug overlay. In battle, keys **1–6** select soul modes and **F6** ends the current wave. **F7** cycles registered rooms, **F8** starts a sample battle and **F9** opens a shop. **H** toggles invincibility; Page Up / Page Down change HP.

The overworld menu offers items, stats, phone entries and settings. Its settings include language, window size, fullscreen, and keyboard or gamepad bindings for movement, confirm, cancel and menu. Default gamepad face buttons and D-pad bindings are also configured. Long menu text can be scrolled with Page Up / Page Down.

## Encounters and battle

Register up to three enemy scenes with `EncounterManager.encounter_set(id, enemy0, enemy1, enemy2, text)` and call `EncounterManager.encounter(id)`. The old world is suspended during combat and restored afterwards. `battle_finished(result)` emits `won`, `lost` or `fled`. Encounters have a fade; pass `false` as the second argument to skip it. `set_encounter_music(id, stream)` assigns optional battle music.

Extend `BattleEnemy`. `EnemyData` supplies the name, HP, attack, defense, escape chance and EXP/GOLD rewards. Define ACT choices with `action_set(slot, name, callback)` or override `perform_action()`, and set `spareable` when appropriate. ACT choices can span multiple pages. Override `get_turn_dialog()` and `get_wave_scene(turn)` to customize a turn. When multiple active enemies provide waves, their waves run together; the turn ends after all have finished. An enemy can override `get_flee_chance(turn)` to define custom escape rules.

Player HP, attack, defense, inventory, equipment, EXP, GOLD, LV and KR are in `Global.player_data`. `Global.equip_item(id)`, `player_get_attack()`, `player_get_defense()` and `award_rewards()` connect equipment and rewards to battle. Enemy EXP is awarded on defeat; enemy GOLD is awarded on defeat or spare. Earned rewards are settled on victory or escape. The supplied level thresholds and damage values are defaults and can be changed for a game.

## Souls and attack patterns

`battle.soul.set_mode()` accepts `red`, `blue`, `green`, `yellow`, `aqua`, `orange`, or combinations such as `yellow+aqua+orange`. Blue uses gravity and jumping; its `gravity_direction` can point up, down, left or right. Green turns a shield with the directional controls. Yellow fires with confirm in the most recent direction. Aqua reverses controls, and orange continues in the last direction. Bullet rules use actual soul displacement to distinguish moving from standing still.

`BattleBullet` supports white, blue, orange and healing collision rules, invulnerability, shootable targets, and optional KR. Set `karma = true` on a bullet or enable `Global.player_data.kr_enabled`; `karma_per_second` controls sustained contact, and the soul drains accumulated KR over time. `BattlePatterns` provides bones, walls, rotating rings, moving platforms, telegraphed beams and blasters, line/cross/star bombs, pellets, knife warnings and expanding pulses. These are procedural starter visuals and are intended to be customized.

Create a scene whose root extends `BattleWave`, assign it to an enemy, and schedule events using elapsed seconds:

```gdscript
extends BattleWave

func advance_wave(previous: float, now: float) -> void:
    if previous < 0.5 and now >= 0.5:
        BattlePatterns.wall(battle, Vector2(450, 330), 4, Vector2(30, 0), 50, Vector2(-90, 0))
    if previous < 2.0 and now >= 2.0:
        BattlePatterns.blaster(battle, Vector2(180, 280), battle.soul.global_position, 0.8, 0.7)
```

Use `BattlePatterns.pellet()`, `platform()`, `ring()`, `line_bomb()`, `knife_warning()` and `pulse()` for other examples. Bullet velocities are pixels/second, angular velocities are radians/second, and all durations are seconds. `battle.spawn_bullet(bullet, position, true)` allows a bullet to be drawn outside the arena. `battle.set_arena_polygon(points)` accepts a simple, non-self-intersecting polygon of up to 32 vertices in local battle-box coordinates; pass an empty array to restore the rectangular box.

## World, dialogue and saves

`OverworldFrisk` handles four-direction movement and ray-based interaction. `WorldInteractable` can be configured as dialogue, a save point, a shop, or a door. Doors use a scene path and destination position. The demo includes both rooms and a working return door.

`DialogueService.present(text, options, portrait)` shows a dialogue and returns the selected option. The text typer accepts RichTextLabel BBCode and the inline commands `{wait:0.3}`, `{speed:0.05}`, `{pause}`, `{voice:name}` and `{angle:10}`. Register a voice on the typer with `register_voice()`. `EventService.run(steps, actor)` sequences dialogue, choices, waits, movement, flags, conditionals, doors, encounters and callables. For example:

```gdscript
EventService.run([
    {"type": "dialogue", "text": "* Hello.{wait:0.3} Welcome."},
    {"type": "choice", "text": "* Continue?", "options": ["Yes", "No"], "flag": "answer"},
    {"type": "if_flag", "key": "answer", "value": 0,
        "then": [{"type": "set_flag", "key": "agreed", "value": true}]}
], player)
```

`Global.set_flag()` / `get_flag()` manage persistent story values. `Global.storage_save(path, slot)` stores the player, flags, current room and position; `await Global.restore_world(path, slot)` loads them. The demo uses `user://saves/`. Store serializable values in flags. The loader also accepts the earlier prototype's player-only save data. On defeat the demo offers to load the current slot when one exists.

Register items with `ItemManager.register(id, item)`; `HealingItem` and `EquipmentItem` show how to implement effects. `ShopService.open_shop(stock, dialogue)` accepts item IDs; prices are defined by each item. `WorldMenu.register_phone(title, message)` adds phone entries. `SettingsService.text(key)` looks up the active language; add the game's own text keys to its language dictionaries.

## Timing and tests

Movement, acceleration, invulnerability, typing, attack scheduling, fades and damage-over-time use seconds. Godot's `CharacterBody2D.move_and_slide()` applies the physics timestep internally; do not multiply its velocity by delta beforehand. Use elapsed-time boundary checks or a loop when scheduling repeated events so a long update does not skip them.

Blue-soul jump height can be shortened by releasing the jump key; `jump_release_speed_ratio` controls the remaining upward speed. Platforms created by `BattlePatterns.platform()` can set `bounce_in_arena = true` to reflect off the current rectangular arena bounds.

Fast, linearly moving bullets sweep their `CollisionShape2D` shapes between physics updates, and fast expanding pulses check the swept ring. This reduces tunneling, but does not provide continuous collision for rotation, parent-driven motion, moving targets, or custom `CollisionPolygon2D` bullet shapes. Physics and input remain sampled at their configured rates, so different tick rates can still change collision precision.

After importing once, run:

```sh
godot --headless --editor --path . --quit
godot --headless --path . res://tests/test_runner.tscn
godot --headless --path . res://tests/extended_runner.tscn
godot --headless --path . res://tests/battle_physics_runner.tscn
```

The tests exercise the battle and world round trip, equipment and rewards, menu and dialogue input, shop transactions, room and save restoration, multiple waves, polygon bounds, and time-dependent behavior at 30, 60 and 144 updates per second. The battle physics suite additionally uses actual collision shapes to test jumping, platforms, projectile sweeps and lifetime boundaries.

## References

The design was informed by [UndergameEngine](https://github.com/SheepYhangCN/UndergameEngine), [TML233's UndertaleEngine](https://github.com/TML233/UndertaleEngine), [Zhazha's Undertale Engine](https://github.com/onezhazha233/Undertale-Engine-modded-by-Zhazha), and [swapfell-remake-project](https://github.com/onezhazha233/swapfell-remake-project). Those are GameMaker projects; this implementation is written for Godot.
