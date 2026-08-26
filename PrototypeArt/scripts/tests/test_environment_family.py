import importlib.util
import sys
import unittest
from pathlib import Path

from PIL import Image


SCRIPTS = Path(__file__).parents[1]
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location("environment_family", SCRIPTS / "normalize_environment_family.py")
environment_family = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(environment_family)
CANVAS_SPEC = importlib.util.spec_from_file_location("environment_canvas", SCRIPTS / "build_environment_family_canvas.py")
environment_canvas = importlib.util.module_from_spec(CANVAS_SPEC)
assert CANVAS_SPEC.loader
CANVAS_SPEC.loader.exec_module(environment_canvas)


class EnvironmentFamilyTests(unittest.TestCase):
    def test_canvas_repeats_five_cells_and_marks_sixth_magenta(self):
        seed = Image.new("RGBA", (2, 1), (10, 20, 30, 255))

        canvas = environment_canvas.build(seed)

        self.assertEqual(canvas.size, (6, 2))
        self.assertEqual([canvas.getpixel((index % 3 * 2, index // 3)) for index in range(5)], [(10, 20, 30, 255)] * 5)
        self.assertEqual(canvas.getpixel((4, 1)), (255, 0, 255, 255))

    def test_extracts_only_first_five_cells_in_row_major_order(self):
        source = Image.new("RGBA", (30, 20), (255, 0, 255, 255))
        colors = [(10, 0, 0), (20, 0, 0), (30, 0, 0), (40, 0, 0), (50, 0, 0)]
        for index, color in enumerate(colors):
            left = index % 3 * 10
            top = index // 3 * 10
            for y in range(top, top + 10):
                for x in range(left, left + 10):
                    source.putpixel((x, y), (*color, 255))
        manifest = {
            "frameSize": {"width": 16, "height": 9},
            "generationLayout": {"columns": 3, "rows": 2, "ignoredCells": [6]},
            "frames": [{"file": f"frame-{index}.png"} for index in range(5)],
        }
        palette = Image.new("RGB", (5, 1))
        palette.putdata(colors)

        frames = environment_family.normalize(source, manifest, palette)

        self.assertEqual(len(frames), 5)
        self.assertEqual([frame.getpixel((8, 4))[:3] for frame in frames], colors)
        self.assertNotIn((255, 0, 255), {pixel[:3] for frame in frames for pixel in frame.getdata()})


if __name__ == "__main__":
    unittest.main()
