# Battle Screen Alignment Design

## Context
The battle flow currently splits input handling across `battle/Battle.gd` (polling `Input.is_action_just_pressed`) and `battle/UI/ScreenBattle.gd` (only left/right for the main button row). Meanwhile, `/gui` provides a clear input routing pattern (`Screen` + `ScreenManager`) that already owns button navigation and active screen focus. This mismatch makes it harder to reason about battle input, duplicates responsibility, and keeps input logic away from the UI layer that already mediates it.

## Goals
- Route battle menu input through `ScreenBattle.handle_input` and the `ScreenManager` input loop.
- Keep gameplay behavior identical: menu transitions, selection sounds, and cursor positions stay the same.
- Reduce input logic inside `Battle.gd` so it is primarily state and data orchestration.

## Non-goals
- Implement missing battle states (FIGHT_AIM, FIGHT_ANIM, MERCY, etc.).
- Rework enemy logic or item systems beyond what is needed for input cleanup.

## Proposed Approach (Design)
Introduce a small, testable input router that translates `InputEvent` into battle actions, and let `ScreenBattle` own calling it. `ScreenBattle` already extends `Screen`, is registered in `ScreenManager`, and is the right place to interpret UI input. The new router (e.g., `battle/BattleMenuInput.gd`) will be a pure logic class that uses the current `Battle` menu/state to decide what to call (`battle_set_menu`, `battle_set_fight_enemy_choice`, `battle_set_item_choice`, etc.). This keeps the heavy branching out of `Battle._process` and makes it easier to reason about selection rules and bounds.

**Data flow:** `ScreenManager._unhandled_input` -> `ScreenBattle.handle_input` -> `BattleMenuInput.handle_event(battle, event)` -> `Battle` methods -> `BattleEvent` signal -> UI updates. The router only calls into `Battle`; it does not touch UI nodes directly.

**Error handling:** Guard on null `battle`, early-return when the active screen is not battle, and clamp selection slots against enemy/item counts to avoid out-of-range access. If there are no enemies or items, the router does not advance into the corresponding menus.

**Testing & verification:** The router is pure and can be unit-tested with a stub `Battle` that captures calls. Add a test under `tests/` to ensure input events map to the same menu transitions as before. Manual verification uses the existing battle test scene: confirm button navigation, enemy selection, ACT selection grid, item page scrolling, and cancel behavior.

## Trade-offs
- Slightly more code (router + tests), but input behavior becomes deterministic and isolated.
- `Battle.gd` becomes smaller and easier to maintain; `ScreenBattle` becomes the sole input entry point, aligned with `/gui` patterns.
