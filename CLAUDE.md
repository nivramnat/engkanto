# Engkanto

Open world monster-catching game based on Filipino folklore. The player is an apprentice babaylan who binds and befriends engkanto (mythical creatures) to restore balance between the human and spirit worlds.

## Platform and Engine
- Godot 4.7 (stable), GDScript only (no C#)
- Targets: Android and PC (Windows)
- Renderer: GL Compatibility (chosen for low-end Android support)
- Style: low-poly 3D, third-person camera
- Godot CLI available on PATH as `godot_console` (use `--headless --import` to validate changes)

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
- Commit to git after each working system with a clear message

## Workflow
- Build one system per session. Do not start the next until the current one runs without errors.
- After changes, run the project and check the output log for errors before finishing.
- Ask before adding any third-party plugin.

## Current Status
- [x] Step 1: Project setup (this file, folders, git, input map)
