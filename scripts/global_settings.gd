extends Node

## Global Game Settings
## Stores configuration that persists between scenes

# Time Controls (in seconds)
const TIME_10_MIN = 600.0
const TIME_5_MIN = 300.0
const TIME_3_MIN = 180.0
const TIME_UNLIMITED = -1.0

# Game Modes
enum GameMode {
	STANDARD = 0,
	QUANTUM_MOCKUP = 1
}

# Current Settings
var time_limit: float = TIME_10_MIN
var game_mode: int = GameMode.STANDARD
