extends Node
class_name GameManager

## Manages game state, turns, and quantum mechanics

signal turn_changed(current_player: int)
signal game_over(winner: int, reason: String)
signal check_status_changed(player_in_check: int, is_in_check: bool)
signal capture_attempted(attacker: Piece, defender: Piece, success: bool)
signal piece_split(piece: Piece, new_pieces: Array)
signal probability_redistributed(pieces: Array)
signal check_collapse_occurred(piece: Piece, survived: bool)
signal time_updated(white_time: float, black_time: float)


enum Player { WHITE = 0, BLACK = 1 }
enum GameState { PLAYING, CHECK, CHECKMATE, STALEMATE, DRAW }

var current_player: Player = Player.WHITE
var game_state: GameState = GameState.PLAYING
var move_history: Array = []  # Array of move notation strings
var board: Board
var move_number: int = 1

# Time Controls
var white_time: float = 600.0  # 10 minutes in seconds
var black_time: float = 600.0
var is_timer_active: bool = false
const INITIAL_TIME: float = 600.0

signal move_recorded(move_text: String, is_white: bool)


# Track all pieces and their entanglement groups
var all_pieces: Array[Piece] = []
var entanglement_groups: Dictionary = {}  # group_id -> Array[Piece]
var next_entanglement_id: int = 0

# En passant tracking - the square where en passant capture is possible
var en_passant_target: Vector2i = Vector2i(-1, -1)

# Castling rights
var white_can_castle_kingside: bool = true
var white_can_castle_queenside: bool = true
var black_can_castle_kingside: bool = true
var black_can_castle_queenside: bool = true


func _ready() -> void:
	randomize()



func _process(delta: float) -> void:
	if game_state == GameState.PLAYING and is_timer_active:
		if current_player == Player.WHITE:
			white_time -= delta
			if white_time <= 0:
				white_time = 0
				game_over.emit(Player.BLACK, "Time Out! Black wins!")
				game_state = GameState.CHECKMATE # Can treat as checkmate for end state
		else:
			black_time -= delta
			if black_time <= 0:
				black_time = 0
				game_over.emit(Player.WHITE, "Time Out! White wins!")
				game_state = GameState.CHECKMATE
		
		time_updated.emit(white_time, black_time)


func initialize(game_board: Board) -> void:

	board = game_board
	current_player = Player.WHITE
	game_state = GameState.PLAYING
	move_history.clear()
	move_number = 1
	all_pieces.clear()
	entanglement_groups.clear()
	next_entanglement_id = 0
	en_passant_target = Vector2i(-1, -1)
	white_can_castle_kingside = true
	white_can_castle_queenside = true
	black_can_castle_kingside = true
	black_can_castle_queenside = true
	
	# Reset timers
	# Reset timers
	var time_limit = GlobalSettings.time_limit
	
	# If unlimited time (-1), we might need to handle it differently, 
	# but for now we'll just set a very high number or check is_timer_active logic
	if time_limit < 0:
		is_timer_active = false
		white_time = 0.0
		black_time = 0.0
	else:
		white_time = time_limit
		black_time = time_limit
		is_timer_active = true
		
	time_updated.emit(white_time, black_time)



func register_piece(piece: Piece) -> void:
	all_pieces.append(piece)
	# Each original piece gets its own entanglement group
	var group_id = next_entanglement_id
	next_entanglement_id += 1
	piece.entanglement_group_id = group_id
	entanglement_groups[group_id] = [piece]


func get_player_color(player: Player) -> Piece.PieceColor:
	return Piece.PieceColor.WHITE if player == Player.WHITE else Piece.PieceColor.BLACK


func get_opponent(player: Player) -> Player:
	return Player.BLACK if player == Player.WHITE else Player.WHITE


#region Check Detection

## Find the king for a given player
func find_king(player: Player) -> Piece:
	var color = get_player_color(player)
	for piece in all_pieces:
		if piece.piece_type == Piece.PieceType.KING and piece.piece_color == color:
			return piece
	return null


## Check if a square is attacked by any piece of the given color
func is_square_attacked(pos: Vector2i, by_color: Piece.PieceColor) -> bool:
	for piece in all_pieces:
		if piece.piece_color != by_color:
			continue
		if can_piece_attack_square(piece, pos):
			return true
	return false


## Check if a specific piece can attack a square (ignoring check constraints)
func can_piece_attack_square(piece: Piece, target: Vector2i) -> bool:
	var pos = piece.board_position
	
	match piece.piece_type:
		Piece.PieceType.PAWN:
			# Pawns attack diagonally
			var direction = -1 if piece.piece_color == Piece.PieceColor.WHITE else 1
			var attack_positions = [
				Vector2i(pos.x - 1, pos.y + direction),
				Vector2i(pos.x + 1, pos.y + direction)
			]
			return target in attack_positions
		
		Piece.PieceType.KNIGHT:
			var offsets = [
				Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
				Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2)
			]
			return (target - pos) in offsets
		
		Piece.PieceType.BISHOP:
			return is_diagonal_clear(pos, target)
		
		Piece.PieceType.ROOK:
			return is_straight_clear(pos, target)
		
		Piece.PieceType.QUEEN:
			return is_diagonal_clear(pos, target) or is_straight_clear(pos, target)
		
		Piece.PieceType.KING:
			var diff = target - pos
			return abs(diff.x) <= 1 and abs(diff.y) <= 1 and diff != Vector2i(0, 0)
	
	return false


## Check if diagonal path is clear between two squares
func is_diagonal_clear(from: Vector2i, to: Vector2i) -> bool:
	var diff = to - from
	if abs(diff.x) != abs(diff.y) or diff.x == 0:
		return false
	
	var step = Vector2i(sign(diff.x), sign(diff.y))
	var current = from + step
	
	while current != to:
		if board.get_first_piece_at(current) != null:
			return false
		current += step
	
	return true


## Check if straight path is clear between two squares
func is_straight_clear(from: Vector2i, to: Vector2i) -> bool:
	var diff = to - from
	if diff.x != 0 and diff.y != 0:
		return false
	if diff.x == 0 and diff.y == 0:
		return false
	
	var step = Vector2i(sign(diff.x), sign(diff.y))
	var current = from + step
	
	while current != to:
		if board.get_first_piece_at(current) != null:
			return false
		current += step
	
	return true


## Check if the given player's king is in check (without triggering collapse)
func is_in_check(player: Player) -> bool:
	var king = find_king(player)
	if not king:
		return false
	
	var opponent_color = get_player_color(get_opponent(player))
	return is_square_attacked(king.board_position, opponent_color)


## Get all pieces currently attacking the king
func get_checking_pieces(player: Player) -> Array[Piece]:
	var king = find_king(player)
	if not king:
		return []
	
	var checking: Array[Piece] = []
	var opponent_color = get_player_color(get_opponent(player))
	
	for piece in all_pieces:
		if piece.piece_color != opponent_color:
			continue
		if can_piece_attack_square(piece, king.board_position):
			checking.append(piece)
	
	return checking


## Check for check WITH quantum collapse - fractional pieces must "prove" they exist
## Returns true if the player is STILL in check after collapses
func resolve_quantum_check(player: Player) -> bool:
	var checking_pieces = get_checking_pieces(player)
	
	if checking_pieces.is_empty():
		return false
	
	var still_in_check = false
	
	# Each checking piece that's fractional must roll to prove it exists
	for piece in checking_pieces:
		if piece.quantum_fraction >= 1.0:
			# Full piece - check is guaranteed
			still_in_check = true
		else:
			# Fractional piece - observation triggers collapse
			var roll = randf()
			if roll <= piece.quantum_fraction:
				# Piece exists! It collapses to a full piece (it's now "observed")
				promote_to_full(piece)
				check_collapse_occurred.emit(piece, true)
				still_in_check = true
			else:
				# Piece doesn't exist - collapse it
				check_collapse_occurred.emit(piece, false)
				collapse_piece(piece)
				# Check might still exist from other pieces
	
	return still_in_check

#endregion


#region Legal Move Validation

## Get all legal moves for a piece (excluding moves that leave king in check)
func get_legal_moves(piece: Piece) -> Array[Vector2i]:
	var pseudo_moves = board.calculate_valid_moves(piece)
	var legal_moves: Array[Vector2i] = []
	
	for move in pseudo_moves:
		if is_move_legal(piece, move):
			legal_moves.append(move)
	
	# Add castling moves for king
	if piece.piece_type == Piece.PieceType.KING and not piece.has_moved:
		var castling_moves = get_castling_moves(piece)
		for move in castling_moves:
			legal_moves.append(move)
	
	# Add en passant moves for pawns
	if piece.piece_type == Piece.PieceType.PAWN:
		var ep_move = get_en_passant_move(piece)
		if ep_move != Vector2i(-1, -1):
			legal_moves.append(ep_move)
	
	return legal_moves


## Check if a move is legal (doesn't leave own king in check)
func is_move_legal(piece: Piece, to: Vector2i) -> bool:
	var from = piece.board_position
	var captured_piece = board.get_first_piece_at(to)
	var player = Player.WHITE if piece.piece_color == Piece.PieceColor.WHITE else Player.BLACK
	
	# Simulate the move
	board.simulate_move(piece, from, to)
	if captured_piece:
		captured_piece.board_position = Vector2i(-100, -100)  # Temporarily remove
	
	# Check if king is in check after move
	var king_in_check = is_in_check(player)
	
	# Undo simulation
	board.simulate_move(piece, to, from)
	if captured_piece:
		captured_piece.board_position = to
	
	return not king_in_check


## Check if any legal moves exist for a player
func has_legal_moves(player: Player) -> bool:
	var color = get_player_color(player)
	for piece in all_pieces:
		if piece.piece_color == color:
			var moves = get_legal_moves(piece)
			if moves.size() > 0:
				return true
	return false

#endregion


#region Castling

## Get available castling moves for a king
func get_castling_moves(king: Piece) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	
	if king.has_moved:
		return moves
	
	var player = Player.WHITE if king.piece_color == Piece.PieceColor.WHITE else Player.BLACK
	var opponent_color = get_player_color(get_opponent(player))
	var row = 7 if player == Player.WHITE else 0
	
	# Can't castle out of check
	if is_in_check(player):
		return moves
	
	# Kingside castling
	var can_kingside = white_can_castle_kingside if player == Player.WHITE else black_can_castle_kingside
	if can_kingside:
		var rook = board.get_first_piece_at(Vector2i(7, row))
		if rook and rook.piece_type == Piece.PieceType.ROOK and not rook.has_moved:
			# Check if squares between king and rook are empty
			if board.get_first_piece_at(Vector2i(5, row)) == null and \
			   board.get_first_piece_at(Vector2i(6, row)) == null:
				# Check if king doesn't pass through or end in check
				if not is_square_attacked(Vector2i(5, row), opponent_color) and \
				   not is_square_attacked(Vector2i(6, row), opponent_color):
					moves.append(Vector2i(6, row))
	
	# Queenside castling
	var can_queenside = white_can_castle_queenside if player == Player.WHITE else black_can_castle_queenside
	if can_queenside:
		var rook = board.get_first_piece_at(Vector2i(0, row))
		if rook and rook.piece_type == Piece.PieceType.ROOK and not rook.has_moved:
			# Check if squares between king and rook are empty
			if board.get_first_piece_at(Vector2i(1, row)) == null and \
			   board.get_first_piece_at(Vector2i(2, row)) == null and \
			   board.get_first_piece_at(Vector2i(3, row)) == null:
				# Check if king doesn't pass through or end in check
				if not is_square_attacked(Vector2i(2, row), opponent_color) and \
				   not is_square_attacked(Vector2i(3, row), opponent_color):
					moves.append(Vector2i(2, row))
	
	return moves


## Execute castling move (move the rook)
func execute_castling(king: Piece, to: Vector2i) -> void:
	var row = king.board_position.y
	
	if to.x == 6:  # Kingside
		var rook = board.get_first_piece_at(Vector2i(7, row))
		if rook:
			board.move_piece(rook, Vector2i(7, row), Vector2i(5, row))
	elif to.x == 2:  # Queenside
		var rook = board.get_first_piece_at(Vector2i(0, row))
		if rook:
			board.move_piece(rook, Vector2i(0, row), Vector2i(3, row))


## Update castling rights after a move
func update_castling_rights(piece: Piece, from: Vector2i) -> void:
	# King moved - lose both castling rights
	if piece.piece_type == Piece.PieceType.KING:
		if piece.piece_color == Piece.PieceColor.WHITE:
			white_can_castle_kingside = false
			white_can_castle_queenside = false
		else:
			black_can_castle_kingside = false
			black_can_castle_queenside = false
	
	# Rook moved - lose that side's castling rights
	if piece.piece_type == Piece.PieceType.ROOK:
		if piece.piece_color == Piece.PieceColor.WHITE:
			if from == Vector2i(0, 7):
				white_can_castle_queenside = false
			elif from == Vector2i(7, 7):
				white_can_castle_kingside = false
		else:
			if from == Vector2i(0, 0):
				black_can_castle_queenside = false
			elif from == Vector2i(7, 0):
				black_can_castle_kingside = false

#endregion


#region En Passant

## Get en passant capture move for a pawn if available
func get_en_passant_move(pawn: Piece) -> Vector2i:
	if en_passant_target == Vector2i(-1, -1):
		return Vector2i(-1, -1)
	
	var pos = pawn.board_position
	var direction = -1 if pawn.piece_color == Piece.PieceColor.WHITE else 1
	
	# Check if pawn is adjacent to en passant target
	var ep_capture_square = Vector2i(en_passant_target.x, pos.y + direction)
	
	if abs(en_passant_target.x - pos.x) == 1 and ep_capture_square.y == en_passant_target.y:
		# Verify move is legal (doesn't leave king in check)
		if is_move_legal(pawn, en_passant_target):
			return en_passant_target
	
	return Vector2i(-1, -1)


## Set en passant target after a double pawn move
func set_en_passant_target(pawn: Piece, from: Vector2i, to: Vector2i) -> void:
	# Check if pawn moved two squares
	if abs(to.y - from.y) == 2:
		# Set the en passant target to the square the pawn passed through
		en_passant_target = Vector2i(to.x, (from.y + to.y) / 2)
	else:
		en_passant_target = Vector2i(-1, -1)


## Execute en passant capture
func execute_en_passant(pawn: Piece, to: Vector2i) -> void:
	# The captured pawn is on the same rank as the attacking pawn, same file as target
	var captured_pawn_pos = Vector2i(to.x, pawn.board_position.y)
	var captured_pawn = board.get_first_piece_at(captured_pawn_pos)
	
	if captured_pawn:
		board.remove_specific_piece(captured_pawn)
		all_pieces.erase(captured_pawn)
		captured_pawn.queue_free()

#endregion


#region Game State

## Called after each move to check game state
func check_game_state() -> void:
	# First, check if there's a potential check situation
	# If fractional pieces are giving check, they must collapse to prove they exist
	var in_check = resolve_quantum_check(current_player)
	var has_moves = has_legal_moves(current_player)
	
	if in_check:
		check_status_changed.emit(current_player, true)
		if not has_moves:
			# Checkmate!
			game_state = GameState.CHECKMATE
			var winner = get_opponent(current_player)
			var winner_name = "White" if winner == Player.WHITE else "Black"
			game_over.emit(winner, "Checkmate! " + winner_name + " wins!")
		else:
			game_state = GameState.CHECK
	else:
		check_status_changed.emit(current_player, false)
		if not has_moves:
			# Stalemate!
			game_state = GameState.STALEMATE
			game_over.emit(-1, "Stalemate! It's a draw.")
		else:
			game_state = GameState.PLAYING
	
	if game_state != GameState.PLAYING:
		is_timer_active = false



func end_turn() -> void:
	# Increment move number after Black's turn
	if current_player == Player.BLACK:
		move_number += 1
	current_player = Player.BLACK if current_player == Player.WHITE else Player.WHITE
	turn_changed.emit(current_player)
	check_game_state()


#region Move Notation

const FILE_NAMES = ["a", "b", "c", "d", "e", "f", "g", "h"]
const RANK_NAMES = ["8", "7", "6", "5", "4", "3", "2", "1"]

## Convert board position to algebraic notation (e.g., e4)
func pos_to_algebraic(pos: Vector2i) -> String:
	return FILE_NAMES[pos.x] + RANK_NAMES[pos.y]


## Get piece letter for notation (K, Q, R, B, N, or empty for pawn)
func get_piece_letter(piece: Piece) -> String:
	match piece.piece_type:
		Piece.PieceType.KING: return "K"
		Piece.PieceType.QUEEN: return "Q"
		Piece.PieceType.ROOK: return "R"
		Piece.PieceType.BISHOP: return "B"
		Piece.PieceType.KNIGHT: return "N"
		Piece.PieceType.PAWN: return ""
	return ""


## Record a standard move
func record_move(piece: Piece, from: Vector2i, to: Vector2i, is_capture: bool = false, capture_result: Dictionary = {}) -> void:
	var notation = ""
	var is_white = piece.piece_color == Piece.PieceColor.WHITE
	
	# Build basic notation
	var piece_letter = get_piece_letter(piece)
	var from_square = pos_to_algebraic(from)
	var to_square = pos_to_algebraic(to)
	
	if piece.piece_type == Piece.PieceType.PAWN:
		if is_capture:
			notation = FILE_NAMES[from.x] + "x" + to_square
		else:
			notation = to_square
	else:
		notation = piece_letter
		if is_capture:
			notation += "x"
		notation += to_square
	
	# Add quantum annotations
	if piece.quantum_fraction < 1.0:
		notation += " [" + piece.fraction_to_string(piece.quantum_fraction) + "]"
	
	# Add capture result annotation
	if is_capture and capture_result.size() > 0:
		if capture_result.get("success", false):
			notation += " ✓"
		else:
			notation += " ✗"
	
	# Add check/checkmate symbols
	if game_state == GameState.CHECKMATE:
		notation += "#"
	elif game_state == GameState.CHECK or is_in_check(get_opponent(current_player)):
		notation += "+"
	
	move_history.append(notation)
	move_recorded.emit(notation, is_white)


## Record castling move
func record_castling(is_kingside: bool) -> void:
	var notation = "O-O" if is_kingside else "O-O-O"
	var is_white = current_player == Player.WHITE
	move_history.append(notation)
	move_recorded.emit(notation, is_white)


## Record quantum split
func record_split(piece: Piece) -> void:
	var notation = "⚛" + get_piece_letter(piece)
	if piece.piece_type == Piece.PieceType.PAWN:
		notation = "⚛P"
	notation += pos_to_algebraic(piece.board_position)
	notation += " → ½"
	
	var is_white = piece.piece_color == Piece.PieceColor.WHITE
	move_history.append(notation)
	move_recorded.emit(notation, is_white)


## Record pawn promotion
func record_promotion(piece: Piece, to: Vector2i, new_type: Piece.PieceType) -> void:
	var notation = pos_to_algebraic(to) + "="
	match new_type:
		Piece.PieceType.QUEEN: notation += "Q"
		Piece.PieceType.ROOK: notation += "R"
		Piece.PieceType.BISHOP: notation += "B"
		Piece.PieceType.KNIGHT: notation += "N"
	
	var is_white = piece.piece_color == Piece.PieceColor.WHITE
	move_history.append(notation)
	move_recorded.emit(notation, is_white)

#endregion

#endregion


#region Quantum Mechanics

## Split a piece into two quantum copies
func split_piece(piece: Piece) -> Array[Piece]:
	if piece.piece_type == Piece.PieceType.KING:
		push_error("Cannot split the King!")
		return []
	
	# Calculate new fraction (half of current)
	var new_fraction = piece.quantum_fraction / 2.0
	
	# Update original piece
	piece.quantum_fraction = new_fraction
	
	# Create quantum copy
	var copy = piece.create_quantum_copy()
	copy.quantum_fraction = new_fraction
	
	# Add to entanglement group
	var group = entanglement_groups[piece.entanglement_group_id]
	group.append(copy)
	copy.entanglement_group_id = piece.entanglement_group_id
	
	# Register the new piece
	all_pieces.append(copy)
	
	piece_split.emit(piece, [piece, copy])
	
	return [piece, copy]


## Attempt a capture between two pieces
func attempt_capture(attacker: Piece, defender: Piece) -> Dictionary:
	var result = {
		"success": false,
		"attacker_survives": true,
		"defender_survives": true,
		"attacker_roll": 0.0,
		"defender_roll": 0.0,
		"attacker_threshold": attacker.quantum_fraction,
		"defender_threshold": defender.quantum_fraction
	}
	
	# Roll for attacker success
	result.attacker_roll = randf()
	var attacker_succeeds = result.attacker_roll <= attacker.quantum_fraction
	
	if attacker.quantum_fraction >= 1.0 and defender.quantum_fraction >= 1.0:
		# Both full pieces - normal capture
		result.success = true
		result.defender_survives = false
	elif attacker.quantum_fraction >= 1.0:
		# Full piece attacking fractional - roll for defender
		result.defender_roll = randf()
		result.defender_survives = result.defender_roll > defender.quantum_fraction
		result.success = not result.defender_survives
	elif defender.quantum_fraction >= 1.0:
		# Fractional attacking full piece
		result.success = attacker_succeeds
		result.defender_survives = not attacker_succeeds
		if not attacker_succeeds:
			result.attacker_survives = false  # Attacker collapses on failure
	else:
		# Both fractional - both roll
		result.defender_roll = randf()
		var defender_dodges = result.defender_roll > defender.quantum_fraction
		
		if attacker_succeeds and not defender_dodges:
			result.success = true
			result.defender_survives = false
		elif not attacker_succeeds:
			result.attacker_survives = false
		# If defender dodges, both can survive
	
	# Handle collapses and probability redistribution
	if not result.attacker_survives:
		collapse_piece(attacker)
	if not result.defender_survives:
		collapse_piece(defender)
	
	# If attacker succeeds, it becomes a full piece
	if result.success and result.attacker_survives:
		promote_to_full(attacker)
	
	capture_attempted.emit(attacker, defender, result.success)
	return result


## Collapse a piece and redistribute probability to entangled copies
func collapse_piece(piece: Piece) -> void:
	var group_id = piece.entanglement_group_id
	var group = entanglement_groups.get(group_id, [])
	
	# Remove from group
	group.erase(piece)
	all_pieces.erase(piece)
	
	# Redistribute probability to remaining pieces
	if group.size() > 0:
		var prob_to_distribute = piece.quantum_fraction
		var share = prob_to_distribute / group.size()
		for p in group:
			p.quantum_fraction = min(1.0, p.quantum_fraction + share)
		probability_redistributed.emit(group)
	
	# Remove the piece from the board
	if piece.board_position != Vector2i(-1, -1):
		board.remove_specific_piece(piece)
	piece.queue_free()


## Promote a fractional piece to full (after successful capture)
func promote_to_full(piece: Piece) -> void:
	var group_id = piece.entanglement_group_id
	var group = entanglement_groups.get(group_id, [])
	
	# Remove all other pieces in the entanglement group
	for p in group:
		if p != piece:
			all_pieces.erase(p)
			if p.board_position != Vector2i(-1, -1):
				board.remove_specific_piece(p)
			p.queue_free()
	
	# Set piece to full
	piece.quantum_fraction = 1.0
	piece.is_collapsed = true
	entanglement_groups[group_id] = [piece]


## Try to recombine pieces on the same square
func try_recombine(position: Vector2i) -> Piece:
	var pieces_at_pos = board.get_pieces_at(position)
	
	if pieces_at_pos.size() < 2:
		return null
	
	# Duplicate the array for processing to avoid modification issues during iteration
	var pieces_to_process = pieces_at_pos.duplicate()
	
	# Check if all pieces are from the same entanglement group
	var group_id = pieces_to_process[0].entanglement_group_id
	for p in pieces_to_process:
		if p.entanglement_group_id != group_id:
			print("Recombine failed: different groups ", p.entanglement_group_id, " vs ", group_id)
			return null  # Can't combine pieces from different origins
	
	print("Recombining ", pieces_to_process.size(), " pieces at ", position)
	
	# Combine all pieces at this position
	var combined_fraction = 0.0
	var main_piece = pieces_to_process[0]
	
	for p in pieces_to_process:
		combined_fraction += p.quantum_fraction
		if p != main_piece:
			all_pieces.erase(p)
			entanglement_groups[group_id].erase(p)
			board.remove_specific_piece(p)
			p.queue_free()
	
	main_piece.quantum_fraction = min(1.0, combined_fraction)
	return main_piece


## Check fractional checkmate
func attempt_fractional_checkmate(attacking_piece: Piece) -> bool:
	if attacking_piece.quantum_fraction >= 1.0:
		return true  # Full piece = guaranteed checkmate
	
	var roll = randf()
	if roll <= attacking_piece.quantum_fraction:
		return true  # Checkmate succeeds
	else:
		# Checkmate fails, redistribute probability
		collapse_piece(attacking_piece)
		return false


## Handle pawn promotion with observer effect
func attempt_pawn_promotion(pawn: Piece, promotion_type: Piece.PieceType) -> bool:
	if pawn.quantum_fraction >= 1.0:
		# Full pawn promotes normally
		pawn.piece_type = promotion_type
		pawn.update_visuals()
		return true
	
	# Fractional pawn triggers observer effect
	var roll = randf()
	if roll <= pawn.quantum_fraction:
		# Pawn exists - promote to full piece
		promote_to_full(pawn)
		pawn.piece_type = promotion_type
		pawn.update_visuals()
		return true
	else:
		# Pawn doesn't exist - remove from game
		collapse_piece(pawn)
		return false

#endregion
