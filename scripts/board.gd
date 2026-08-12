extends Node2D
class_name Board

## Chess board management - handles squares, piece positions, and visual display

signal square_clicked(position: Vector2i)
signal piece_selected(piece: Piece)
signal move_requested(piece: Piece, from: Vector2i, to: Vector2i)
signal split_requested(piece: Piece)
signal promotion_requested(piece: Piece, position: Vector2i)

const BOARD_SIZE = 8
const SQUARE_SIZE = 80  # pixels

# Colors for classic theme
var light_square_color := Color("#f0d9b5")
var dark_square_color := Color("#b58863")
var highlight_color := Color("#829769", 0.8)
var selected_color := Color("#646f40", 0.9)
var last_move_color := Color("#cdd26a", 0.5)
var check_color := Color("#ff6b6b", 0.6)
var castling_color := Color("#5d9cec", 0.6)

# Board state: position -> Array of Pieces (multiple for quantum superposition)
var board_state: Dictionary = {}
var selected_piece: Piece = null
var valid_moves: Array[Vector2i] = []
var last_move_from: Vector2i = Vector2i(-1, -1)
var last_move_to: Vector2i = Vector2i(-1, -1)
var king_in_check_pos: Vector2i = Vector2i(-1, -1)

# Node references
@onready var squares_container: Node2D = $Squares
@onready var pieces_container: Node2D = $Pieces
@onready var highlights_container: Node2D = $Highlights

var game_manager: GameManager


func _ready() -> void:
	create_board_squares()


func initialize(manager: GameManager) -> void:
	game_manager = manager
	manager.initialize(self)
	manager.check_status_changed.connect(_on_check_status_changed)
	manager.game_over.connect(_on_game_over)
	setup_initial_pieces()


func _on_check_status_changed(player: int, is_in_check: bool) -> void:
	if is_in_check:
		var king = game_manager.find_king(player)
		if king:
			king_in_check_pos = king.board_position
	else:
		king_in_check_pos = Vector2i(-1, -1)
	update_highlights()


func _on_game_over(_winner: int, reason: String) -> void:
	print(reason)
	# Game is over - disable further input
	set_process_input(false)


func create_board_squares() -> void:
	var light_texture = load("res://assets/pixel_16x16/square_light.png")
	var dark_texture = load("res://assets/pixel_16x16/square_dark.png")
	
	for row in range(BOARD_SIZE):
		for col in range(BOARD_SIZE):
			var square = TextureRect.new()
			square.position = Vector2(col * SQUARE_SIZE, row * SQUARE_SIZE)
			square.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
			
			var is_light = (row + col) % 2 == 0
			square.texture = light_texture if is_light else dark_texture
			# Ensure texture scales sharply (nearest neighbor is global default now, but stretches to size)
			
			squares_container.add_child(square)
	
	# Add coordinate labels
	add_coordinate_labels()


func add_coordinate_labels() -> void:
	var files = ["a", "b", "c", "d", "e", "f", "g", "h"]
	var ranks = ["8", "7", "6", "5", "4", "3", "2", "1"]
	
	for i in range(BOARD_SIZE):
		# File labels (bottom)
		var file_label = Label.new()
		file_label.text = files[i]
		file_label.position = Vector2(i * SQUARE_SIZE + SQUARE_SIZE - 12, BOARD_SIZE * SQUARE_SIZE - 16)
		var is_light = (7 + i) % 2 == 0
		file_label.add_theme_color_override("font_color", dark_square_color if is_light else light_square_color)
		file_label.add_theme_font_size_override("font_size", 12)
		squares_container.add_child(file_label)
		
		# Rank labels (left)
		var rank_label = Label.new()
		rank_label.text = ranks[i]
		rank_label.position = Vector2(4, i * SQUARE_SIZE + 2)
		is_light = (i) % 2 == 0
		rank_label.add_theme_color_override("font_color", dark_square_color if is_light else light_square_color)
		rank_label.add_theme_font_size_override("font_size", 12)
		squares_container.add_child(rank_label)


func setup_initial_pieces() -> void:
	# Clear existing pieces
	for child in pieces_container.get_children():
		child.queue_free()
	board_state.clear()
	
	# Setup piece positions [type, color, file, rank]
	var setup = [
		# Black pieces (top, row 0-1)
		[Piece.PieceType.ROOK, Piece.PieceColor.BLACK, 0, 0],
		[Piece.PieceType.KNIGHT, Piece.PieceColor.BLACK, 1, 0],
		[Piece.PieceType.BISHOP, Piece.PieceColor.BLACK, 2, 0],
		[Piece.PieceType.QUEEN, Piece.PieceColor.BLACK, 3, 0],
		[Piece.PieceType.KING, Piece.PieceColor.BLACK, 4, 0],
		[Piece.PieceType.BISHOP, Piece.PieceColor.BLACK, 5, 0],
		[Piece.PieceType.KNIGHT, Piece.PieceColor.BLACK, 6, 0],
		[Piece.PieceType.ROOK, Piece.PieceColor.BLACK, 7, 0],
		# White pieces (bottom, row 6-7)
		[Piece.PieceType.ROOK, Piece.PieceColor.WHITE, 0, 7],
		[Piece.PieceType.KNIGHT, Piece.PieceColor.WHITE, 1, 7],
		[Piece.PieceType.BISHOP, Piece.PieceColor.WHITE, 2, 7],
		[Piece.PieceType.QUEEN, Piece.PieceColor.WHITE, 3, 7],
		[Piece.PieceType.KING, Piece.PieceColor.WHITE, 4, 7],
		[Piece.PieceType.BISHOP, Piece.PieceColor.WHITE, 5, 7],
		[Piece.PieceType.KNIGHT, Piece.PieceColor.WHITE, 6, 7],
		[Piece.PieceType.ROOK, Piece.PieceColor.WHITE, 7, 7],
	]
	
	# Add pawns
	for col in range(BOARD_SIZE):
		setup.append([Piece.PieceType.PAWN, Piece.PieceColor.BLACK, col, 1])
		setup.append([Piece.PieceType.PAWN, Piece.PieceColor.WHITE, col, 6])
	
	# Create pieces
	for piece_data in setup:
		var piece = create_piece(piece_data[0], piece_data[1])
		var pos = Vector2i(piece_data[2], piece_data[3])
		place_piece(piece, pos)
		game_manager.register_piece(piece)


func create_piece(type: Piece.PieceType, color: Piece.PieceColor) -> Piece:
	var piece = preload("res://scenes/piece.tscn").instantiate()
	piece.piece_type = type
	piece.piece_color = color
	piece.quantum_fraction = 1.0
	pieces_container.add_child(piece)
	return piece



func update_square_visuals(pos: Vector2i) -> void:
	var pieces = get_pieces_at(pos)
	if pieces.is_empty():
		return
		
	var center = board_to_screen(pos)
	print("Update visuals at ", pos, ": found ", pieces.size(), " pieces")
	
	if pieces.size() == 1:
		var tween = create_tween()
		tween.tween_property(pieces[0], "position", center, 0.2).set_ease(Tween.EASE_OUT)
	else:
		# Multiple pieces - circle arrangement
		var radius = SQUARE_SIZE * 0.25 # Increased radius
		for i in range(pieces.size()):
			var angle = (TAU * i) / pieces.size() - (PI / 2)
			var offset = Vector2(cos(angle), sin(angle)) * radius
			var target = center + offset
			
			var tween = create_tween()
			tween.tween_property(pieces[i], "position", target, 0.2).set_ease(Tween.EASE_OUT)


func place_piece(piece: Piece, pos: Vector2i) -> void:
	piece.board_position = pos
	piece.position = board_to_screen(pos)
	
	if not board_state.has(pos):
		board_state[pos] = []
	board_state[pos].append(piece)
	
	update_square_visuals(pos)


func remove_piece_at(pos: Vector2i) -> void:
	if board_state.has(pos):
		board_state[pos].clear()


func remove_specific_piece(piece: Piece) -> void:
	if board_state.has(piece.board_position):
		board_state[piece.board_position].erase(piece)
		update_square_visuals(piece.board_position)


func get_pieces_at(pos: Vector2i) -> Array:
	return board_state.get(pos, [])


func get_first_piece_at(pos: Vector2i) -> Piece:
	var pieces = get_pieces_at(pos)
	return pieces[0] if pieces.size() > 0 else null


func board_to_screen(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * SQUARE_SIZE + SQUARE_SIZE / 2, pos.y * SQUARE_SIZE + SQUARE_SIZE / 2)


func screen_to_board(screen_pos: Vector2) -> Vector2i:
	var local_pos = screen_pos - global_position
	return Vector2i(int(local_pos.x / SQUARE_SIZE), int(local_pos.y / SQUARE_SIZE))


func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < BOARD_SIZE and pos.y >= 0 and pos.y < BOARD_SIZE


## Simulate a move without visual updates (for checking legality)
func simulate_move(piece: Piece, from: Vector2i, to: Vector2i) -> void:
	# Update board state
	if board_state.has(from):
		board_state[from].erase(piece)
	
	if not board_state.has(to):
		board_state[to] = []
	board_state[to].append(piece)
	
	piece.board_position = to


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var board_pos = screen_to_board(get_global_mouse_position())
		
		if not is_valid_position(board_pos):
			return
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			handle_left_click(board_pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			handle_right_click(board_pos)


func handle_left_click(pos: Vector2i) -> void:
	var clicked_piece = get_first_piece_at(pos)
	
	if selected_piece:
		if pos in valid_moves:
			# Execute move
			execute_move(selected_piece, pos)
		elif clicked_piece and clicked_piece.piece_color == get_current_player_color():
			# Select different piece
			select_piece(clicked_piece)
		else:
			# Deselect
			deselect_piece()
	else:
		if clicked_piece and clicked_piece.piece_color == get_current_player_color():
			select_piece(clicked_piece)


func handle_right_click(pos: Vector2i) -> void:
	var clicked_piece = get_first_piece_at(pos)
	
	if clicked_piece and clicked_piece.piece_color == get_current_player_color():
		if clicked_piece.piece_type != Piece.PieceType.KING:
			split_requested.emit(clicked_piece)


func select_piece(piece: Piece) -> void:
	selected_piece = piece
	# Use legal moves from game manager (includes check validation)
	valid_moves = game_manager.get_legal_moves(piece)
	update_highlights()
	piece_selected.emit(piece)


func deselect_piece() -> void:
	selected_piece = null
	valid_moves.clear()
	update_highlights()


func execute_move(piece: Piece, to: Vector2i) -> void:
	var from = piece.board_position
	
	# Attempt to consolidate target pieces if they are split (quantum interference)
	# This ensures we capture the "whole" probability mass if they are on the same square
	if get_pieces_at(to).size() > 1:
		game_manager.try_recombine(to)
		
	var target_piece = get_first_piece_at(to)
	
	# Check for castling
	if piece.piece_type == Piece.PieceType.KING and abs(to.x - from.x) == 2:
		var is_kingside = to.x == 6
		game_manager.execute_castling(piece, to)
		move_piece(piece, from, to)
		game_manager.update_castling_rights(piece, from)
		game_manager.record_castling(is_kingside)
	# Check for en passant
	elif piece.piece_type == Piece.PieceType.PAWN and to == game_manager.en_passant_target:
		game_manager.execute_en_passant(piece, to)
		move_piece(piece, from, to)
		game_manager.record_move(piece, from, to, true, {"success": true})
	# Normal capture
	elif target_piece and target_piece.piece_color != piece.piece_color:
		var result = game_manager.attempt_capture(piece, target_piece)
		if result.success and result.attacker_survives:
			move_piece(piece, from, to)
		game_manager.record_move(piece, from, to, true, result)
	# Normal move
	else:
		move_piece(piece, from, to)
		game_manager.record_move(piece, from, to, false)
	
	# Update castling rights
	game_manager.update_castling_rights(piece, from)
	
	# Handle en passant target for double pawn moves
	if piece.piece_type == Piece.PieceType.PAWN:
		game_manager.set_en_passant_target(piece, from, to)
	else:
		game_manager.en_passant_target = Vector2i(-1, -1)
	
	last_move_from = from
	last_move_to = to
	deselect_piece()
	
	# Check for pawn promotion before ending turn
	if not check_pawn_promotion(piece):
		game_manager.end_turn()
	
	# Try recombining pieces
	game_manager.try_recombine(to)


func move_piece(piece: Piece, from: Vector2i, to: Vector2i) -> void:
	# Remove from old position
	if board_state.has(from):
		board_state[from].erase(piece)
	
	# Enemy pieces at destination are handled by capture logic in execute_move
	# We don't remove them here to allow for quantum superposition (stacking)
	
	# Add to new position
	if not board_state.has(to):
		board_state[to] = []
	board_state[to].append(piece)
	
	# Update piece
	piece.board_position = to
	piece.has_moved = true
	
	# Update visual layout for both source and destination
	update_square_visuals(from)
	update_square_visuals(to)


func check_pawn_promotion(piece: Piece) -> bool:
	if piece.piece_type != Piece.PieceType.PAWN:
		return false
	
	var promotion_rank = 0 if piece.piece_color == Piece.PieceColor.WHITE else 7
	if piece.board_position.y == promotion_rank:
		# Request promotion dialog from main
		promotion_requested.emit(piece, piece.board_position)
		return true
	return false


func complete_promotion(piece: Piece, new_type: Piece.PieceType) -> void:
	game_manager.attempt_pawn_promotion(piece, new_type)
	game_manager.record_promotion(piece, piece.board_position, new_type)
	game_manager.end_turn()


## Calculate pseudo-legal moves (not checking for leaving king in check)
func calculate_valid_moves(piece: Piece) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var pos = piece.board_position
	
	match piece.piece_type:
		Piece.PieceType.PAWN:
			moves = get_pawn_moves(piece, pos)
		Piece.PieceType.KNIGHT:
			moves = get_knight_moves(piece, pos)
		Piece.PieceType.BISHOP:
			moves = get_sliding_moves(piece, pos, [Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)])
		Piece.PieceType.ROOK:
			moves = get_sliding_moves(piece, pos, [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)])
		Piece.PieceType.QUEEN:
			moves = get_sliding_moves(piece, pos, [
				Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
				Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)
			])
		Piece.PieceType.KING:
			moves = get_king_moves(piece, pos)
	
	return moves


func get_pawn_moves(piece: Piece, pos: Vector2i) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var direction = -1 if piece.piece_color == Piece.PieceColor.WHITE else 1
	var start_rank = 6 if piece.piece_color == Piece.PieceColor.WHITE else 1
	
	# Forward move
	var forward = Vector2i(pos.x, pos.y + direction)
	if is_valid_position(forward) and get_pieces_at(forward).size() == 0:
		moves.append(forward)
		
		# Double move from start
		if pos.y == start_rank:
			var double = Vector2i(pos.x, pos.y + direction * 2)
			if is_valid_position(double) and get_pieces_at(double).size() == 0:
				moves.append(double)
	
	# Captures
	for dx in [-1, 1]:
		var capture_pos = Vector2i(pos.x + dx, pos.y + direction)
		if is_valid_position(capture_pos):
			var target = get_first_piece_at(capture_pos)
			if target and target.piece_color != piece.piece_color:
				moves.append(capture_pos)
	
	return moves


func get_knight_moves(piece: Piece, pos: Vector2i) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var offsets = [
		Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
		Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2)
	]
	
	for offset in offsets:
		var target = pos + offset
		if is_valid_position(target):
			var target_piece = get_first_piece_at(target)
			if not target_piece or target_piece.piece_color != piece.piece_color:
				moves.append(target)
	
	return moves


func get_sliding_moves(piece: Piece, pos: Vector2i, directions: Array) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	
	for dir in directions:
		var current = pos + dir
		while is_valid_position(current):
			var target_piece = get_first_piece_at(current)
			if not target_piece:
				moves.append(current)
			elif target_piece.piece_color != piece.piece_color:
				moves.append(current)
				break
			else:
				break
			current += dir
	
	return moves


func get_king_moves(piece: Piece, pos: Vector2i) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var directions = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	
	for dir in directions:
		var target = pos + dir
		if is_valid_position(target):
			var target_piece = get_first_piece_at(target)
			if not target_piece or target_piece.piece_color != piece.piece_color:
				moves.append(target)
	
	# Castling moves are added by game_manager.get_legal_moves()
	return moves


func get_current_player_color() -> Piece.PieceColor:
	return Piece.PieceColor.WHITE if game_manager.current_player == GameManager.Player.WHITE else Piece.PieceColor.BLACK


func update_highlights() -> void:
	# Clear existing highlights
	for child in highlights_container.get_children():
		child.queue_free()
	
	# Check highlight (red square on king)
	if king_in_check_pos != Vector2i(-1, -1):
		add_highlight(king_in_check_pos, check_color)
	
	# Last move highlights
	if last_move_from != Vector2i(-1, -1):
		add_highlight(last_move_from, last_move_color)
		add_highlight(last_move_to, last_move_color)
	
	# Selected piece highlight
	if selected_piece:
		add_highlight(selected_piece.board_position, selected_color)
		
		# Valid move highlights
		for move_pos in valid_moves:
			var target = get_first_piece_at(move_pos)
			
			# Check if this is a castling move
			if selected_piece.piece_type == Piece.PieceType.KING and abs(move_pos.x - selected_piece.board_position.x) == 2:
				add_castling_highlight(move_pos)
			elif target:
				add_capture_highlight(move_pos)
			elif move_pos == game_manager.en_passant_target and selected_piece.piece_type == Piece.PieceType.PAWN:
				add_capture_highlight(move_pos)  # En passant shows as capture
			else:
				add_move_dot(move_pos)


func add_highlight(pos: Vector2i, color: Color) -> void:
	var highlight = ColorRect.new()
	highlight.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
	highlight.position = Vector2(pos.x * SQUARE_SIZE, pos.y * SQUARE_SIZE)
	highlight.color = color
	highlights_container.add_child(highlight)


func add_move_dot(pos: Vector2i) -> void:
	var dot = ColorRect.new()
	var dot_size = SQUARE_SIZE * 0.3
	dot.size = Vector2(dot_size, dot_size)
	dot.position = Vector2(pos.x * SQUARE_SIZE + (SQUARE_SIZE - dot_size) / 2, 
						   pos.y * SQUARE_SIZE + (SQUARE_SIZE - dot_size) / 2)
	dot.color = highlight_color
	highlights_container.add_child(dot)


func add_capture_highlight(pos: Vector2i) -> void:
	var ring = ColorRect.new()
	ring.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
	ring.position = Vector2(pos.x * SQUARE_SIZE, pos.y * SQUARE_SIZE)
	ring.color = Color(highlight_color.r, highlight_color.g, highlight_color.b, 0.5)
	highlights_container.add_child(ring)


func add_castling_highlight(pos: Vector2i) -> void:
	var highlight = ColorRect.new()
	highlight.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
	highlight.position = Vector2(pos.x * SQUARE_SIZE, pos.y * SQUARE_SIZE)
	highlight.color = castling_color
	highlights_container.add_child(highlight)
