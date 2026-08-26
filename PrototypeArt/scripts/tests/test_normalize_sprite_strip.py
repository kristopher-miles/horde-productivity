import importlib.util
import tempfile
import unittest
from pathlib import Path

from PIL import Image


SCRIPT = Path(__file__).parents[1] / "normalize_sprite_strip.py"
SPEC = importlib.util.spec_from_file_location("normalizer", SCRIPT)
normalizer = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(normalizer)


class NormalizerTests(unittest.TestCase):
    def test_checkerboard_removal_keeps_enclosed_warm_detail(self):
        image = Image.new("RGBA", (8, 8), "white")
        pixels = image.load()
        for y in range(2, 6):
            for x in range(2, 6):
                pixels[x, y] = (180, 60, 10, 255)
        pixels[3, 3] = (255, 230, 150, 255)
        cleaned = normalizer.remove_edge_background(image, 210, 14)
        self.assertEqual(cleaned.getpixel((0, 0))[3], 0)
        self.assertEqual(cleaned.getpixel((3, 3))[3], 255)

    def test_rectangular_bottom_center_composition(self):
        content = Image.new("RGBA", (4, 2), (220, 80, 10, 255))
        frame = normalizer.compose(content, 12, 8, 2, 0)
        self.assertEqual(frame.size, (12, 8))
        self.assertEqual(frame.getchannel("A").getbbox(), (2, 4, 10, 8))

    def test_palette_mapping_preserves_transparency(self):
        image = Image.new("RGBA", (2, 1), (0, 0, 0, 0))
        image.putpixel((1, 0), (245, 100, 20, 255))
        palette = Image.new("RGB", (2, 1))
        palette.putdata([(5, 4, 11), (242, 118, 13)])
        mapped = normalizer.apply_palette(image, palette)
        self.assertEqual(mapped.getpixel((0, 0)), (0, 0, 0, 0))
        self.assertEqual(mapped.getpixel((1, 0)), (242, 118, 13, 255))

    def test_dark_background_removal_keeps_largest_sprite(self):
        image = Image.new("RGBA", (8, 5), (1, 1, 1, 255))
        image.putpixel((1, 1), (30, 10, 5, 255))
        for y in range(1, 4):
            for x in range(4, 7):
                image.putpixel((x, y), (220, 80, 10, 255))
        cleaned = normalizer.remove_dark_background(image, 1, 8)
        self.assertEqual(cleaned.getpixel((1, 1))[3], 0)
        self.assertEqual(cleaned.getchannel("A").getbbox(), (4, 1, 7, 4))


if __name__ == "__main__":
    unittest.main()
