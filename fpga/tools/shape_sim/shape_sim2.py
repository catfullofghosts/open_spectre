# SIMULATING THE SHAPE GEN TO WORK OUT A BETTER WAY TO BUILD IT

import numpy as np
from PIL import Image

# Grid size
width, height = 800, 600

# Circle center and radius
cx, cy = 400, 300
radius = 200

# Create grid of coordinates
y_coords, x_coords = np.ogrid[:height, :width]

# === 1. Distance Map ===
# dist = np.sqrt((x_coords - cx)**2 + (y_coords - cy)**2)
dist = ((x_coords - cx)**2 + (y_coords - cy)**2)/ 2**2 
dist_normalized = (dist / dist.max()) * 255
dist_image = dist_normalized.astype(np.uint8)
Image.fromarray(dist_image).save("distance_map.png")

# ===  Circle ===
stripe_mod_threshold = 2
x_mod = x_coords % 4
inside_circle = dist <= radius
# stripe_condition = x_mod < stripe_mod_threshold
# combined_mask = np.logical_and(inside_circle, stripe_condition)
circle_image = np.zeros((height, width), dtype=np.uint8)
circle_image[inside_circle] = 255
Image.fromarray(circle_image).save("circle.png")

# === TRIANGLES === ramp shouldnt restat at 0
ramp_period = width / 4
ramp_periodY = width / 4
ramp_values = ((x_coords % ramp_period) / ramp_period) * 255
ramp_valuesY = ((y_coords % ramp_periodY) / ramp_periodY) * 255
ramp_valuesY[200:300] = ramp_valuesY[100:200]

combined_condition = ramp_valuesY > ramp_values 
# triangle = combined_condition
combined_result = np.zeros((height, width), dtype=np.uint8)
combined_result[combined_condition] = 255
triangle = combined_result

Image.fromarray(combined_result).save("Triangles.png")


# === Vertical segments === ramp shouldnt restat at 0
combined_condition = dist < ramp_values 
vertical_seq = combined_condition
combined_result = np.zeros((height, width), dtype=np.uint8)
combined_result[combined_condition] = 255
Image.fromarray(combined_result).save("Vertical.png")

# === Horizontal segments === ramp shouldnt restat at 0
combined_condition = dist < ramp_valuesY 
horizontal_seq = combined_condition
combined_result = np.zeros((height, width), dtype=np.uint8)
combined_result[combined_condition] = 255
Image.fromarray(combined_result).save("Horizontal.png")

# === Frizz === 
noise_image = np.random.randint(0, 256, (height, width), dtype=np.uint8)
combined_condition = dist < noise_image 
combined_result = np.zeros((height, width), dtype=np.uint8)
combined_result[combined_condition] = 255
Image.fromarray(combined_result).save("Frizz.png")

# === Palmleaves === 
combined_condition = triangle < vertical_seq 
combined_result = np.zeros((height, width), dtype=np.uint8)
combined_result[combined_condition] = 255
palm = combined_result
Image.fromarray(combined_result).save("Palm.png")

# ===== Criss cross ===========
combined_condition = np.bitwise_xor(vertical_seq,horizontal_seq)
combined_result = np.zeros((height, width), dtype=np.uint8)
combined_result[combined_condition] = 255
criss_cross = combined_result
Image.fromarray(combined_result).save("criss_cross.png")

# ======== Crisscross inverterd ========

combined_condition = np.logical_not( np.bitwise_xor(vertical_seq,horizontal_seq))
combined_result = np.zeros((height, width), dtype=np.uint8)
combined_result[combined_condition] = 255
Image.fromarray(combined_result).save("criss_cross_inverted.png")

# ======== Lantern ===================
# noise is built from horizontal and vertical bars from digital side
ramp_period = width / 50
ramp_periodY = width / 50
ramp_values = (((x_coords % ramp_period) / ramp_period)>0.5) * 50
ramp_valuesY = (((y_coords % ramp_periodY) / ramp_periodY)>0.5) * 50

Bramp_period = width / 40
Bramp_periodY = width / 40
Bramp_values = (((x_coords % Bramp_period) / Bramp_period)>0.5) * 50
Bramp_valuesY = (((y_coords % Bramp_periodY) / Bramp_periodY)>0.5) * 50

blankX = np.zeros((height, width), dtype=np.uint8)
blankY = np.zeros((height, width), dtype=np.uint8)
blankX = ramp_values + Bramp_values
blankY = ramp_valuesY + Bramp_valuesY

blankXY = np.zeros((height, width), dtype=np.uint8)
# blankXY =  np.bitwise_and(blankX,blankY)
blankXY =  blankX + blankY


combined_condition = dist < blankXY 

combined_result = np.zeros((height, width), dtype=np.uint8)
combined_result[combined_condition] = 255
Image.fromarray(combined_result).save("Lantern.png")

# # ======== gear =================== THIS USES VC 5 from the comparitor?!
# ramp_period = width / 50
# ramp_values = (((x_coords % ramp_period) / ramp_period)>0.2) * 50

# Bramp_values = 5

# blankX = np.zeros((height, width), dtype=np.uint8)
# blankX = ramp_values + Bramp_values


# combined_condition = dist < blankX 

# combined_result = np.zeros((height, width), dtype=np.uint8)
# combined_result[combined_condition] = 255
# Image.fromarray(combined_result).save("Gear.png")

# ===== cutout ===========
combined_condition = np.bitwise_xor(criss_cross,triangle)
cutout = combined_condition
Image.fromarray(combined_condition).save("cutout.png")

# ===== amazon ===========
combined_condition = np.bitwise_xor(palm,cutout)

Image.fromarray(combined_condition).save("amazon.png")