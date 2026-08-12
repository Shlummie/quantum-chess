extends Control

## Main game controller - connects UI elements and manages game flow

@onready var board: Board = $Board
@onready var game_manager: GameManager = $GameManager
@onready var turn_label: Label = $UI/TurnLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var probability_popup: Control = $ProbabilityPopup
@onready var popup_title: Label = $ProbabilityPopup/PopupContainer/Panel/VBox/Title
@onready var popup_info: Label = $ProbabilityPopup/PopupContainer/Panel/VBox/Info
@onready var roll_button: Button = $ProbabilityPopup/PopupContainer/Panel/VBox/RollButton
@onready var move_history_panel: PanelContainer = $UI/MoveHistoryPanel
@onready var move_history_container: VBoxContainer = $UI/MoveHistoryPanel/MarginContainer/VBox/ScrollContainer/MoveList
@onready var promotion_popup: Control = $PromotionPopup
@onready var settings_popup: Control = $SettingsPopup
@onready var settings_button: Button = $UI/SettingsButton

var white_timer_label: Label
var black_timer_label: Label


var pending_capture_attacker: Piece = null
var pending_capture_defender: Piece = null
var pending_promotion_piece: Piece = null

const BOARD_PIXEL_SIZE = 640  # 8 squares * 80 pixels
const MOVE_HISTORY_WIDTH = 200


func _ready() -> void:
	# Connect signals
	game_manager.turn_changed.connect(_on_turn_changed)
	game_manager.capture_attempted.connect(_on_capture_attempted)
	game_manager.piece_split.connect(_on_piece_split)
	game_manager.probability_redistributed.connect(_on_probability_redistributed)
	game_manager.check_status_changed.connect(_on_check_status_changed)
	game_manager.game_over.connect(_on_game_over)
	game_manager.move_recorded.connect(_on_move_recorded)
	game_manager.check_collapse_occurred.connect(_on_check_collapse)
	game_manager.time_updated.connect(_on_time_updated)
	board.split_requested.connect(_on_split_requested)

	board.promotion_requested.connect(_on_promotion_requested)
	roll_button.pressed.connect(_on_roll_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	
	# Connect promotion buttons
	setup_promotion_buttons()
	setup_settings_buttons()
	setup_timers()
	
	# Initialize game

	board.initialize(game_manager)
	update_turn_display()
	setup_move_history_panel()
	
	# Center the board
	center_board()
	get_tree().root.size_changed.connect(center_board)


func center_board() -> void:
	var viewport_size = get_viewport_rect().size
	
	# Calculate available height and scale board if necessary
	# Reserve space for UI: Top(100) + Bottom(50) = 150px overhead
	var max_board_height = viewport_size.y - 150
	var scale_factor = min(1.0, max_board_height / float(BOARD_PIXEL_SIZE))
	
	board.scale = Vector2(scale_factor, scale_factor)
	var current_board_size = BOARD_PIXEL_SIZE * scale_factor
	
	var board_x = (viewport_size.x - current_board_size - MOVE_HISTORY_WIDTH) / 2
	# Ensure board doesn't overlap left edge
	board_x = max(20, board_x)
	
	var board_y = (viewport_size.y - current_board_size) / 2
	# Ensure enough top margin for label
	board_y = max(board_y, 80)
	
	board.position = Vector2(board_x, board_y)
	
	# Position UI elements
	# Label 50px above board (User requested spacing)
	turn_label.position = Vector2(board_x + current_board_size / 2 - 80, board_y - 50)
	
	# Hint label below board
	hint_label.position = Vector2(board_x + current_board_size / 2 - 220, board_y + current_board_size + 10)
	
	# Position timers relative to scaled board
	if white_timer_label:
		white_timer_label.position = Vector2(board_x + current_board_size + 20, board_y + current_board_size - 40)
	if black_timer_label:
		black_timer_label.position = Vector2(board_x + current_board_size + 20, board_y)
	
	# Position move history panel
	var history_y_start = board_y + 45
	var history_height = current_board_size - 90
	
	if move_history_panel:
		move_history_panel.position = Vector2(board_x + current_board_size + 20, history_y_start)
		move_history_panel.size = Vector2(MOVE_HISTORY_WIDTH, history_height)



func update_turn_display() -> void:
	var player_name = "White" if game_manager.current_player == GameManager.Player.WHITE else "Black"
	turn_label.text = player_name + "'s Turn"
	
	# Color the label
	if game_manager.current_player == GameManager.Player.WHITE:
		turn_label.add_theme_color_override("font_color", Color("#f0f0f0"))
	else:
		turn_label.add_theme_color_override("font_color", Color("#a0a0a0"))


func _on_turn_changed(_current_player: int) -> void:
	update_turn_display()


func _on_check_status_changed(player: int, is_in_check: bool) -> void:
	if is_in_check:
		var player_name = "White" if player == GameManager.Player.WHITE else "Black"
		hint_label.text = player_name + " is in CHECK!"
		hint_label.add_theme_color_override("font_color", Color("#ff6b6b"))
	else:
		hint_label.text = "Right-click a piece to split it into quantum superposition"
		hint_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1))


func _on_check_collapse(piece: Piece, survived: bool) -> void:
	# Record the collapse event in move history
	var piece_name = piece.get_type_name()
	var notation = ""
	
	if survived:
		notation = "⚛ " + piece_name + " observed → CHECK!"
		print("Quantum collapse: " + piece_name + " observed giving check - piece becomes real!")
	else:
		notation = "⚛ " + piece_name + " collapsed → no check"
		print("Quantum collapse: " + piece_name + " failed observation - piece vanishes!")
	
	# Add collapse event to history
	var is_white = piece.piece_color == Piece.PieceColor.WHITE
	# Note: This appears as the opponent's action since they were giving check
	game_manager.move_history.append(notation)
	game_manager.move_recorded.emit(notation, not is_white)


func _on_game_over(winner: int, reason: String) -> void:
	turn_label.text = reason
	if winner == -1:  # Draw
		turn_label.add_theme_color_override("font_color", Color("#ffd700"))
	else:
		var winner_color = Color("#90EE90") if winner == GameManager.Player.WHITE else Color("#90EE90")
		turn_label.add_theme_color_override("font_color", winner_color)
	hint_label.text = "Game Over - Close and reopen to play again"
	hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))


func _on_capture_attempted(attacker: Piece, defender: Piece, success: bool) -> void:
	# Show capture result feedback
	var result_text = "Capture successful!" if success else "Capture failed!"
	print(result_text)  # TODO: Show in UI


func _on_piece_split(original: Piece, new_pieces: Array) -> void:
	# Add the new quantum copy to the board
	if new_pieces.size() >= 2:
		var copy = new_pieces[1]
		if not copy.is_inside_tree():
			board.pieces_container.add_child(copy)
		board.place_piece(copy, original.board_position)
		copy.update_visuals()
		original.update_visuals()
		
		# Offset is handled by board.place_piece -> update_square_visuals
	
	game_manager.end_turn()




func _on_probability_redistributed(pieces: Array) -> void:
	# Update visuals for all pieces in the group
	for piece in pieces:
		if is_instance_valid(piece):
			piece.update_visuals()


func _on_split_requested(piece: Piece) -> void:
	if piece.piece_type == Piece.PieceType.KING:
		print("Cannot split the King!")
		return
	
	game_manager.split_piece(piece)
	game_manager.record_split(piece)


func show_probability_popup(attacker: Piece, defender: Piece) -> void:
	pending_capture_attacker = attacker
	pending_capture_defender = defender
	
	popup_title.text = "Capture Attempt"
	
	var attacker_info = "%s %s → %d%% success" % [
		attacker.fraction_to_string(attacker.quantum_fraction),
		attacker.get_type_name(),
		int(attacker.quantum_fraction * 100)
	]
	var defender_info = "%s %s → %d%% survival" % [
		defender.fraction_to_string(defender.quantum_fraction),
		defender.get_type_name(),
		int((1.0 - defender.quantum_fraction) * 100)
	]
	
	popup_info.text = "Attacker: " + attacker_info + "\nDefender: " + defender_info
	probability_popup.visible = true


func _on_roll_button_pressed() -> void:
	probability_popup.visible = false
	
	if pending_capture_attacker and pending_capture_defender:
		var result = game_manager.attempt_capture(pending_capture_attacker, pending_capture_defender)
		# Handle result...
	
	pending_capture_attacker = null
	pending_capture_defender = null


func _input(event: InputEvent) -> void:
	# Allow closing popups with Escape
	if event.is_action_pressed("ui_cancel"):
		if probability_popup.visible:
			probability_popup.visible = false
			pending_capture_attacker = null
			pending_capture_defender = null
		elif settings_popup.visible:
			settings_popup.visible = false
		# Note: promotion popup cannot be closed with Escape - must choose a piece


#region Pawn Promotion

func setup_promotion_buttons() -> void:
	var buttons_container = promotion_popup.get_node_or_null("PopupContainer/Panel/VBox/ButtonsContainer")
	if not buttons_container:
		return
	
	var queen_btn = buttons_container.get_node_or_null("QueenButton")
	var rook_btn = buttons_container.get_node_or_null("RookButton")
	var bishop_btn = buttons_container.get_node_or_null("BishopButton")
	var knight_btn = buttons_container.get_node_or_null("KnightButton")
	
	if queen_btn:
		queen_btn.pressed.connect(_on_promote_queen)
	if rook_btn:
		rook_btn.pressed.connect(_on_promote_rook)
	if bishop_btn:
		bishop_btn.pressed.connect(_on_promote_bishop)
	if knight_btn:
		knight_btn.pressed.connect(_on_promote_knight)


func _on_promotion_requested(piece: Piece, _pos: Vector2i) -> void:
	pending_promotion_piece = piece
	
	# Update button labels based on piece color
	var is_white = piece.piece_color == Piece.PieceColor.WHITE
	var buttons_container = promotion_popup.get_node_or_null("PopupContainer/Panel/VBox/ButtonsContainer")
	if buttons_container:
		var symbols = {
			"QueenButton": "♕" if is_white else "♛",
			"RookButton": "♖" if is_white else "♜",
			"BishopButton": "♗" if is_white else "♝",
			"KnightButton": "♘" if is_white else "♞"
		}
		for btn_name in symbols:
			var btn = buttons_container.get_node_or_null(btn_name)
			if btn:
				btn.text = symbols[btn_name]
	
	promotion_popup.visible = true


func _on_promote_queen() -> void:
	complete_promotion(Piece.PieceType.QUEEN)


func _on_promote_rook() -> void:
	complete_promotion(Piece.PieceType.ROOK)


func _on_promote_bishop() -> void:
	complete_promotion(Piece.PieceType.BISHOP)


func _on_promote_knight() -> void:
	complete_promotion(Piece.PieceType.KNIGHT)


func complete_promotion(piece_type: Piece.PieceType) -> void:
	promotion_popup.visible = false
	if pending_promotion_piece:
		board.complete_promotion(pending_promotion_piece, piece_type)
	pending_promotion_piece = null

#endregion


#region Settings Menu

func setup_settings_buttons() -> void:
	var buttons_container = settings_popup.get_node_or_null("PopupContainer/Panel/VBox/ButtonsContainer")
	if not buttons_container:
		return
	
	var restart_btn = buttons_container.get_node_or_null("RestartButton")
	var main_menu_btn = buttons_container.get_node_or_null("MainMenuButton")
	var close_btn = buttons_container.get_node_or_null("CloseButton")
	
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_game)
	if main_menu_btn:
		main_menu_btn.pressed.connect(_on_main_menu)
	if close_btn:
		close_btn.pressed.connect(_on_close_settings)


func _on_settings_button_pressed() -> void:
	settings_popup.visible = true


func _on_restart_game() -> void:
	settings_popup.visible = false
	
	# Clear move history display
	setup_move_history_panel()
	
	# Re-enable board input (in case game was over)
	board.set_process_input(true)
	
	# Reinitialize the game
	board.initialize(game_manager)
	update_turn_display()
	
	# Reset hint label
	hint_label.text = "Right-click a piece to split it into quantum superposition"
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1))


func _on_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_close_settings() -> void:
	settings_popup.visible = false

#endregion


#region Move History

func setup_move_history_panel() -> void:
	# Clear any existing moves
	if move_history_container:
		for child in move_history_container.get_children():
			child.queue_free()


func _on_move_recorded(move_text: String, is_white: bool) -> void:
	if not move_history_container:
		return
	
	if is_white:
		# Create a new row for white's move
		var row = HBoxContainer.new()
		row.name = "MoveRow_" + str(game_manager.move_number)
		
		# Move number label
		var num_label = Label.new()
		num_label.text = str(game_manager.move_number) + "."
		num_label.custom_minimum_size = Vector2(30, 0)
		num_label.add_theme_font_size_override("font_size", 14)
		num_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		row.add_child(num_label)
		
		# White move label
		var white_label = Label.new()
		white_label.name = "WhiteMove"
		white_label.text = move_text
		white_label.custom_minimum_size = Vector2(70, 0)
		white_label.add_theme_font_size_override("font_size", 14)
		white_label.add_theme_color_override("font_color", Color(1, 1, 1))
		row.add_child(white_label)
		
		# Placeholder for black move
		var black_label = Label.new()
		black_label.name = "BlackMove"
		black_label.text = ""
		black_label.custom_minimum_size = Vector2(70, 0)
		black_label.add_theme_font_size_override("font_size", 14)
		black_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		row.add_child(black_label)
		
		move_history_container.add_child(row)
	else:
		# Find the current row and add black's move
		var row_name = "MoveRow_" + str(game_manager.move_number)
		var row = move_history_container.get_node_or_null(row_name)
		if row:
			var black_label = row.get_node_or_null("BlackMove")
			if black_label:
				black_label.text = move_text
	
	# Auto-scroll to bottom
	await get_tree().process_frame
	var scroll = move_history_panel.get_node_or_null("MarginContainer/VBox/ScrollContainer")
	if scroll:
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

#endregion


#region Timer UI

func setup_timers() -> void:
	# Create White Timer
	white_timer_label = Label.new()
	white_timer_label.text = "10:00"
	white_timer_label.add_theme_font_size_override("font_size", 24)
	white_timer_label.add_theme_color_override("font_color", Color.WHITE)
	$UI.add_child(white_timer_label)
	
	# Create Black Timer
	black_timer_label = Label.new()
	black_timer_label.text = "10:00"
	black_timer_label.add_theme_font_size_override("font_size", 24)
	black_timer_label.add_theme_color_override("font_color", Color.WHITE)
	$UI.add_child(black_timer_label)


func _on_time_updated(white_time: float, black_time: float) -> void:
	if white_timer_label:
		white_timer_label.text = format_time(white_time)
		# Highlight active timer
		if game_manager.current_player == GameManager.Player.WHITE:
			white_timer_label.modulate = Color(1, 1, 1, 1)
			black_timer_label.modulate = Color(0.7, 0.7, 0.7, 0.5)
		else:
			white_timer_label.modulate = Color(0.7, 0.7, 0.7, 0.5)
			black_timer_label.modulate = Color(1, 1, 1, 1)

	if black_timer_label:
		black_timer_label.text = format_time(black_time)


func format_time(time_in_seconds: float) -> String:
	if GlobalSettings.time_limit < 0:
		return "∞"
	
	var minutes = int(time_in_seconds / 60)
	var seconds = int(time_in_seconds) % 60
	return "%02d:%02d" % [minutes, seconds]

#endregion
