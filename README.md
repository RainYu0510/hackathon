# NoxCat: Riftbound Co-op (Godot 4)

Open `project.godot` in Godot 4 and run the project.

- Player 1: A/D, W jump, F attack, G interact/dimension.
- Player 2: Arrow keys, Up jump, K attack, L interact/dimension.
- Player 2 also has direct arrow-key fallback handling for imported-project compatibility.
- F1 toggles debug HUD, F2/F3 force dimensions, R resets the room.
- `Level01.tscn` is the playable tutorial. `Level04.tscn` is the charge puzzle.
- Levels 02, 03 and 05 intentionally contain only `LEVEL DESIGN TBD`.

## v3 fixes

- The supplied NOXCAT, CyberDog, slime, dimension background, portal, and platform PNGs are installed under `assets/`.
- Level 01 now displays the supplied green normal-space art and crimson alternate-space art instead of plain placeholder rectangles.
- CyberDog movement has direct arrow-key fallback input.
- Only NoxCat can collect the goggles; acquiring or activating them plays the goggle animation and a green screen pulse.
- Backgrounds are dimmed while playable platforms receive bright color-coded top edges (mint in normal space, orange in alternate space).
- Both characters use higher jumps plus coyote time and jump buffering for more forgiving platforming.
