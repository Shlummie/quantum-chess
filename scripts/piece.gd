extends Node2D
class_name Piece

## Represents a chess piece with quantum properties

enum PieceType { PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING }
enum PieceColor { WHITE, BLACK }

@export var piece_type: PieceType = PieceType.PAWN
@export var piece_color: PieceColor = PieceColor.WHITE
@export var quantum_fraction: float = 1.0  # 1.0 = full piece, 0.5 = half, etc.

var board_position: Vector2i = Vector2i(-1, -1)
var has_moved: bool = false
var is_collapsed: bool = false  # True if piece has been observed/collapsed
var entanglement_group_id: int = -1  # ID linking entangled pieces

# Visual components
@onready var sprite: Sprite2D = $Sprite
@onready var fraction_label: Label = $FractionLabel

# Piece texture paths
const PIECE_TEXTURES = {
	PieceType.KING: ["res://assets/pixel_16x16/wking.png", "res://assets/pixel_16x16/bking.png"],
	PieceType.QUEEN: ["res://assets/pixel_16x16/wqueen.png", "res://assets/pixel_16x16/bqueen.png"],
	PieceType.ROOK: ["res://assets/pixel_16x16/wrook.png", "res://assets/pixel_16x16/brook.png"],
	PieceType.BISHOP: ["res://assets/pixel_16x16/wbishop.png", "res://assets/pixel_16x16/bbishop.png"],
	PieceType.KNIGHT: ["res://assets/pixel_16x16/wknight.png", "res://assets/pixel_16x16/bknight.png"],
	PieceType.PAWN: ["res://assets/pixel_16x16/wpawn.png", "res://assets/pixel_16x16/bpawn.png"]
}

# Target size for pieces on the board
const PIECE_DISPLAY_SIZE = 64.0  # pixels (4x scale of 16x16)


func _ready() -> void:
	update_visuals()


func _process(_delta: float) -> void:
	# Update fraction label in case it changes
	update_fraction_display()


func update_visuals() -> void:
	update_piece_symbol()
	update_fraction_display()


func update_piece_symbol() -> void:
	if not sprite:
		return
	
	# Remove old Unicode label if it exists
	var old_label = sprite.get_node_or_null("SymbolLabel")
	if old_label:
		old_label.queue_free()
	
	# Load the appropriate texture
	var color_index = 0 if piece_color == PieceColor.WHITE else 1
	var texture_path = PIECE_TEXTURES[piece_type][color_index]
	var texture = load(texture_path)
	
	if texture:
		sprite.texture = texture
		
		# Scale the texture to fit the display size
		var texture_size = texture.get_size()
		var scale_factor = PIECE_DISPLAY_SIZE / max(texture_size.x, texture_size.y)
		sprite.scale = Vector2(scale_factor, scale_factor)
		
		# Apply quantum transparency based on fraction
		update_quantum_opacity()


func update_quantum_opacity() -> void:
	if not sprite:
		return
	
	# Full pieces are fully opaque, fractional pieces are semi-transparent
	if quantum_fraction >= 1.0:
		sprite.modulate.a = 1.0
	else:
		# Minimum opacity of 0.4, scales with fraction
		sprite.modulate.a = 0.4 + (quantum_fraction * 0.5)


func update_fraction_display() -> void:
	if not fraction_label:
		return
	
	# Also update opacity when fraction changes
	update_quantum_opacity()
	
	if quantum_fraction >= 1.0:
		fraction_label.visible = false
	else:
		fraction_label.visible = true
		fraction_label.text = fraction_to_string(quantum_fraction)
		
		# Style the fraction label - cyan for white pieces, purple for black
		fraction_label.add_theme_font_size_override("font_size", 14)
		if piece_color == PieceColor.WHITE:
			fraction_label.add_theme_color_override("font_color", Color("#00d4ff"))
		else:
			fraction_label.add_theme_color_override("font_color", Color("#bf7fff"))
		fraction_label.add_theme_color_override("font_outline_color", Color("#000000"))
		fraction_label.add_theme_constant_override("outline_size", 2)


func fraction_to_string(frac: float) -> String:
	# Convert float to readable fraction
	if frac >= 1.0:
		return "1"
	elif abs(frac - 0.5) < 0.001:
		return "½"
	elif abs(frac - 0.25) < 0.001:
		return "¼"
	elif abs(frac - 0.75) < 0.001:
		return "¾"
	elif abs(frac - 0.125) < 0.001:
		return "⅛"
	elif abs(frac - 0.375) < 0.001:
		return "⅜"
	elif abs(frac - 0.625) < 0.001:
		return "⅝"
	elif abs(frac - 0.875) < 0.001:
		return "⅞"
	else:
		# For other fractions, show percentage
		return str(int(frac * 100)) + "%"


func create_quantum_copy() -> Piece:
	var copy = duplicate()
	copy.piece_type = piece_type
	copy.piece_color = piece_color
	copy.has_moved = has_moved
	copy.is_collapsed = false
	copy.board_position = board_position
	return copy


func get_type_name() -> String:
	match piece_type:
		PieceType.PAWN: return "Pawn"
		PieceType.KNIGHT: return "Knight"
		PieceType.BISHOP: return "Bishop"
		PieceType.ROOK: return "Rook"
		PieceType.QUEEN: return "Queen"
		PieceType.KING: return "King"
	return "Unknown"


func get_color_name() -> String:
	return "White" if piece_color == PieceColor.WHITE else "Black"

