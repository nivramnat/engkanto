# Engkanto

Open world monster-catching game based on Filipino folklore. The player is an apprentice babaylan who binds and befriends engkanto (mythical creatures) to restore balance between the human and spirit worlds.

## Platform and Engine
- Godot 4.7 (stable), GDScript only (no C#)
- Targets: Android and PC (Windows)
- Renderer: GL Compatibility (chosen for low-end Android support)
- Style: low-poly 3D, third-person camera
- Godot CLI available on PATH as `godot_console` (use `--headless --import` to validate changes)

## Input Actions
Defined in project.godot; aim for both PC and touch bindings per the coding rules.
- move_forward / move_back / move_left / move_right — WASD + arrow keys (PC); on-screen joystick, bottom-left (touch)
- run — Shift (PC)
- jump — Spacebar (PC); on-screen button, bottom-right (touch)
- interact — E + left mouse (PC)
- camera_rotate — right-mouse drag + Q (PC); swipe on right half of screen (touch)
- pause — Esc (PC); HUD Pause button and Android back button (touch). `quit_on_go_back` is off so back never quits mid-game

## Save System
- SaveManager writes JSON to user://save_game.json (atomic .tmp swap). Autosaves on every battle end (incl. bind); manual Save in the pause menu
- Bump `SaveManager.SAVE_VERSION` and add a `_migrate()` step whenever the save format changes; never break old saves
- Each class owns its data: `to_dict()` / `from_dict()` on GameState, TimeOfDay, CreatureInstance (creatures saved by .tres path)

## Tests
Run each and check for `RESULT: PASS` (they use their own save files, never the real one):
- `godot_console --path . res://tests/battle_flow_test.tscn` — win / run / bind return to the overworld
- `godot_console --path . res://tests/save_load_test.tscn -- --phase=save`, then `-- --phase=load` — save, quit, Continue, edge cases
- `godot_console --path . res://tests/hut_test.tscn -- --phase=save`, then `-- --phase=load` — hut prompt, moving both ways (Move button + mouse drag), last-creature/full-party blocks, Heal All, autosave on close

## Core Loop
Explore region > encounter creature > weaken or appease > bind > train > unlock next area

## Key Systems (build in this order)
1. Player controller (walk, run, camera, touch + keyboard input)
2. Test zone (one field with a balete tree)
3. Visible wild creature spawning (day/night spawn tables)
4. Encounter trigger (touch creature to start battle)
5. Turn-based battle (4 moves, HP, type chart)
6. Binding/capture (anting-anting item; catch chance uses HP and ritual bonus)
7. Party (6 max) and storage (Albularyo's Hut)
8. Save/load

## Folder Structure
- res://scenes/       .tscn files (player, world, battle, ui)
- res://scripts/      .gd files, mirrors scenes/ structure
- res://data/creatures/  Creature resources (.tres)
- res://data/moves/   Move resources (.tres)
- res://assets/models/, res://assets/textures/, res://assets/audio/
- res://autoload/     Global singletons (GameState, SaveManager, TimeOfDay)

## Coding Rules
- Use static typing in all GDScript (var hp: int = 0)
- Creature and move data live in Resource files, never hardcoded in scripts
- One script per scene; keep scripts under 300 lines, split if larger
- Use signals for communication between systems, not direct node paths across scenes
- Every input action must work with both touch (Android) and keyboard/mouse (PC)
- All asset folder and file names must be lowercase (snake_case) for Android compatibility: exported builds are case-sensitive, so a path that only differs in case works on Windows but breaks on Android
- Commit to git after each working system with a clear message

## Workflow
- Build one system per session. Do not start the next until the current one runs without errors.
- After changes, run the project and check the output log for errors before finishing.
- Ask before adding any third-party plugin.

## Current Status
- [x] Step 1: Project setup (this file, folders, git, input map)
- [x] Steps 2–6: player, Terrain3D open world (4 biomes), day/night spawning, encounters, battle, binding
- [x] Step 7: party (6 max) + Albularyo's Hut (Baryo Lowlands, near the balete): move party/storage, Heal All, autosave on close
- [x] Step 8: Save/load (title screen, pause menu, autosave, versioned JSON)
