import csv
from PIL import Image

def convert_csv_to_image(csv_file, output_image):
    # Read the CSV file
    with open(csv_file, 'r') as file:
        reader = csv.reader(file)
        rows = list(reader)

    # Calculate image dimensions
    width = 1100
    height = 800 

    # Create a new image
    image = Image.new('RGB', (width, height))
    pixels = image.load()

    h_delay = 0
    h = 0
    row_cnt = 0

    # Populate the image pixels
    x = 0
    y = 0
    for row in rows:
        
        if row[0] != 'clk':
            h = int(row[1], 2)
            if (h_delay == 0)and(h == 1):
                x = 0
                y += 1 
            if "U" in row[3]:     
                 row[3] = '0'
            if "U" in row[4]:     
                 row[4] = '0'
            if "U" in row[5]:     
                 row[5] = '0'
            r = int(row[3], 2)
            g = int(row[4], 2)
            b = int(row[5], 2)
            pixels[x, y] = (r, g, b)
            x += 1
        
            h_delay = int(row[1], 2)
                

    # Save the image
    # image.show()
    image.save(output_image)
    print(f"Image saved as {output_image}.")

# Usage example
# csv_file = 'F://FPGA_PERSONAl/OPEN_SPECTRE/MVP_1/MVP_1.sim/sim_1/behav/xsim/frame_out.txt'
csv_file = "C:/Users/robertjo/Downloads/ems_2/project_3/project_3.sim/sim_1/behav/xsim/frame_out.txt"
# csv_file = 'frame_out.txt'
output_image = 'output.png'
convert_csv_to_image(csv_file, output_image)

print()
