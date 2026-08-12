from PIL import Image, ImageDraw
import os
import random

def create_piece_image(piece_type, color_name, color_hex):
    img = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Common colors
    outline = (0, 0, 0, 255)
    fill = color_hex
    
    if piece_type == 'pawn':
        # Pawn shape
        draw.rectangle([6, 3, 9, 5], fill=fill, outline=outline) # Head
        draw.rectangle([5, 6, 10, 11], fill=fill, outline=outline) # Body
        draw.rectangle([4, 12, 11, 14], fill=fill, outline=outline) # Base
    
    elif piece_type == 'rook':
        # Rook shape
        draw.rectangle([4, 3, 5, 5], fill=fill, outline=outline) # Left turret
        draw.rectangle([7, 3, 8, 5], fill=fill, outline=outline) # Center turret
        draw.rectangle([10, 3, 11, 5], fill=fill, outline=outline) # Right turret
        draw.rectangle([4, 6, 11, 11], fill=fill, outline=outline) # Body
        draw.rectangle([3, 12, 12, 14], fill=fill, outline=outline) # Base

    elif piece_type == 'knight':
        # Knight shape (horse head)
        draw.rectangle([5, 4, 10, 6], fill=fill, outline=outline) # Head top
        draw.rectangle([4, 5, 6, 8], fill=fill, outline=outline) # Snout
        draw.rectangle([7, 7, 10, 11], fill=fill, outline=outline) # Neck
        draw.rectangle([4, 12, 11, 14], fill=fill, outline=outline) # Base

    elif piece_type == 'bishop':
        # Bishop shape
        draw.rectangle([7, 2, 8, 3], fill=fill, outline=outline) # Top knob
        draw.rectangle([6, 4, 9, 7], fill=fill, outline=outline) # Hat
        draw.rectangle([6, 8, 9, 11], fill=fill, outline=outline) # Body
        draw.rectangle([5, 12, 10, 14], fill=fill, outline=outline) # Base
        
    elif piece_type == 'queen':
        # Queen shape
        draw.rectangle([4, 3, 4, 4], fill=fill, outline=outline) # Crown point L
        draw.rectangle([11, 3, 11, 4], fill=fill, outline=outline) # Crown point R
        draw.rectangle([6, 2, 9, 5], fill=fill, outline=outline) # Crown center
        draw.rectangle([5, 6, 10, 11], fill=fill, outline=outline) # Body
        draw.rectangle([4, 12, 11, 14], fill=fill, outline=outline) # Base

    elif piece_type == 'king':
        # King shape
        draw.rectangle([7, 1, 8, 3], fill=fill, outline=outline) # Cross V
        draw.rectangle([6, 2, 9, 2], fill=fill, outline=outline) # Cross H
        draw.rectangle([5, 4, 10, 6], fill=fill, outline=outline) # Crown
        draw.rectangle([5, 7, 10, 11], fill=fill, outline=outline) # Body
        draw.rectangle([4, 12, 11, 14], fill=fill, outline=outline) # Base

    filename = f"assets/pixel_16x16/{color_name[0]}{piece_type}.png"
    img.save(filename)
    print(f"Generated {filename}")

def create_square_image(name, base_color):
    img = Image.new('RGB', (16, 16), base_color)
    pixels = img.load()
    
    # Add some noise for wood/stone texture
    r, g, b = base_color
    for x in range(16):
        for y in range(16):
            noise = random.randint(-10, 10)
            nr = max(0, min(255, r + noise))
            ng = max(0, min(255, g + noise))
            nb = max(0, min(255, b + noise))
            pixels[x, y] = (nr, ng, nb)
            
    # Add a slight border/bevel
    border_color = (max(0, r-20), max(0, g-20), max(0, b-20))
    for i in range(16):
        pixels[i, 0] = border_color
        pixels[0, i] = border_color

    filename = f"assets/pixel_16x16/square_{name}.png"
    img.save(filename)
    print(f"Generated {filename}")

# White: #f0f0f0, Black: #202020
white_color = (240, 240, 240, 255)
black_color = (32, 32, 32, 255)

pieces = ['pawn', 'rook', 'knight', 'bishop', 'queen', 'king']

for p in pieces:
    create_piece_image(p, 'white', white_color)
    create_piece_image(p, 'black', black_color)

# Create board squares
# Light: #f0d9b5 -> (240, 217, 181)
create_square_image('light', (240, 217, 181))
# Dark: #b58863 -> (181, 136, 99)
create_square_image('dark', (181, 136, 99))
