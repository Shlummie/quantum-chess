# Quantum Chess rules implemented by this prototype

This is a deterministic software interpretation of a custom chess variant, not a simulation of quantum mechanics and not a standard rules authority.

## Ordinary play

The board starts from the normal chess position. Unsplintered pieces move according to ordinary chess rules except where the quantum rules below modify capture, check, promotion, or castling.

## Splitting

- Instead of making a normal move, a player may split a non-king piece into two legal destination squares.
- Each new copy carries half of the source piece's probability weight. A half copy can be split again into quarter copies, and so on where the interface and move rules permit.
- The king cannot be split.
- Copies descended from one piece remain entangled for collapse and recombination.

## Moving and recombining

- A fractional copy moves like its underlying chess piece.
- Compatible entangled copies that occupy the same square can recombine without consuming an additional turn.
- Castling requires an unsplit, unmoved king and an unsplit, unmoved rook with the ordinary path and check restrictions. A fractional rook cannot castle.
- Ordinary en passant rules apply when their preconditions are satisfied by the concrete board state.

## Captures and observation

- Capturing a fractional target succeeds with probability equal to that target's weight.
- Resolving a probabilistic interaction observes the affected entangled group. Failed and successful outcomes collapse or redistribute the surviving weight across its related copies according to the game engine.
- When a fractional attacker meets a fractional defender, the engine resolves survival for both sides rather than assuming an ordinary guaranteed capture.

Because random observation affects the state, identical positions can produce different outcomes. The UI should display piece weights and the result of each observation.

## Check, mate, and promotion

- A fractional attack on a king creates probabilistic check. Mate resolution therefore depends on the available legal escapes and the observation result.
- A fractional pawn reaching the final rank promotes through the same probabilistic state machinery; promotion does not silently convert unrelated entangled copies.
- The game ends when the implemented king/checkmate resolver determines that no legal survival path remains.

## Prototype caveat

The source code is the final authority for the current build. Edge cases may still be incomplete; see `TODO.md`. When behavior and this document disagree, file an issue with the exact position and move sequence.
