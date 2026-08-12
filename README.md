# Quantum Chess

A Godot prototype of a custom chess variant in which non-king pieces can split into weighted copies, probabilistic captures observe entangled groups, and related copies can recombine.

## Core mechanics

- Standard chess movement as the base ruleset.
- Split a non-king piece across two legal destinations instead of making a normal move.
- Show fractional piece weights such as 1/2 or 1/4.
- Resolve capture probability from the target's weight.
- Collapse/redistribute related copies after observation.
- Recombine compatible copies on the same square.
- Handle fractional pawn promotion and probabilistic king attacks.

See `RULES.md` for the variant contract and `TODO.md` for known edge cases. This is a game mechanic inspired by quantum concepts, not an accurate physics model.

## Project layout

- `project.godot` — Godot project settings.
- `scenes/` — board and interface scenes.
- `scripts/board.gd` — board state, movement, turn, observation, and rule coordination.
- `scripts/piece.gd` — piece identity, movement, weight, and rendering state.
- `scripts/global_settings.gd` — shared configuration.
- `assets/pixel_16x16/` — generated original pixel pieces and board tiles.
- `generate_pixel_assets.py` — deterministic asset generator except for the decorative square noise.

## Run

Requirements: Godot 4.x. Import the directory in the Godot project manager, allow Godot to rebuild its `.godot` cache, and run the main scene.

To regenerate the pixel assets, install Pillow and run:

```bash
python generate_pixel_assets.py
```

## Development status

This is a prototype, not a complete competitive rules implementation. Probability, legal-move validation, check/checkmate, entanglement, promotion, castling, en passant, undo/replay, and UI explanation all need adversarial testing. Random outcomes should be made seedable before deterministic replays or automated tournaments are claimed.

No opaque rules document or imported spritesheet is included; the rules are Markdown and the committed game assets are generated/original.

## License

Original source is MIT licensed. Original pixel assets are CC0; see `ASSET_LICENSES.md`. Godot and Pillow retain their upstream licenses.
