#!/usr/bin/env python3
import os
import math
import cairo

def generate_wallpaper():
    # 1920x1080 Resolution
    width, height = 1920, 1080
    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, width, height)
    cr = cairo.Context(surface)

    # 1. Background: Everforest Dark Base (#2b3339)
    cr.set_source_rgb(43/255, 51/255, 57/255)
    cr.paint()

    # 2. Large Subtle Polygon Left-Top (#323c41, opacity 0.4)
    cr.set_source_rgba(50/255, 60/255, 65/255, 0.4)
    cr.move_to(0, 0)
    cr.line_to(700, 0)
    cr.line_to(0, 900)
    cr.close_path()
    cr.fill()

    # 3. Large Subtle Polygon Right-Bottom (#3d484d, opacity 0.3)
    cr.set_source_rgba(61/255, 72/255, 77/255, 0.3)
    cr.move_to(width, height)
    cr.line_to(width - 700, height)
    cr.line_to(width, height - 900)
    cr.close_path()
    cr.fill()

    # 4. A subtle abstract geometric accent circle in the center-left (#7fbbb3, opacity 0.06)
    cr.set_source_rgba(127/255, 187/255, 179/255, 0.06)
    cr.set_line_width(1.5)
    cr.arc(500, 540, 280, 0, 2 * math.pi)
    cr.stroke()

    # 5. Intersecting minimal lines in Everforest Sage Green (#a7c080, opacity 0.08)
    cr.set_source_rgba(167/255, 192/255, 128/255, 0.08)
    cr.set_line_width(1.2)
    cr.move_to(200, height - 100)
    cr.line_to(width - 200, 100)
    cr.stroke()
    
    cr.move_to(width - 200, height - 100)
    cr.line_to(200, 100)
    cr.stroke()

    # Make sure output directory exists
    out_dir = os.path.expanduser("~/Pictures")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "wallpaper.png")
    
    # Save PNG
    surface.write_to_png(out_path)
    print(f"Wallpaper successfully generated and saved to: {out_path}")

if __name__ == "__main__":
    generate_wallpaper()
