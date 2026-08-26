import importlib.util
import json
import tempfile
import unittest
import zipfile
from pathlib import Path

from PIL import Image

SCRIPT = Path(__file__).parents[1] / "package_pixelorama_project.py"
SPEC = importlib.util.spec_from_file_location("pixelorama_packager", SCRIPT)
pixelorama_packager = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(pixelorama_packager)


class PixeloramaPackageTests(unittest.TestCase):
    def test_packages_rgba_frames_and_animation_tag(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            frame_paths = []
            for index in range(2):
                path = root / f"frame-{index}.png"
                Image.new("RGBA", (5, 3), (index * 30, 20, 10, 255)).save(path)
                frame_paths.append(path)

            output = root / "test.pxo"
            pixelorama_packager.package_project(output, frame_paths, tag="idle", frame_ms=200)

            with zipfile.ZipFile(output) as archive:
                data = json.loads(archive.read("data.json"))
                self.assertEqual(archive.read("mimetype"), b"application/x-pixelorama")
                self.assertEqual(data["size_x"], 5)
                self.assertEqual(data["size_y"], 3)
                self.assertEqual(data["fps"], 5.0)
                self.assertEqual(data["tags"][0], {"name": "idle", "color": "f2760d", "from": 1, "to": 2})
                self.assertEqual(len(archive.read("image_data/frames/1/layer_1")), 5 * 3 * 4)

    def test_embeds_png_palette(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            frame = root / "frame.png"
            palette = root / "palette.png"
            Image.new("RGBA", (2, 2), (10, 20, 30, 255)).save(frame)
            Image.new("RGB", (2, 1), (10, 20, 30)).save(palette)
            output = root / "test.pxo"
            pixelorama_packager.package_project(output, [frame], tag="idle", frame_ms=200, palette_path=palette)
            with zipfile.ZipFile(output) as archive:
                data = json.loads(archive.read("data.json"))
                self.assertEqual(data["project_current_palette_name"], "The Horde Prototype")
                self.assertEqual(len(data["palettes"]), 1)

    def test_accepts_environment_layer_name(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            frame = root / "frame.png"
            Image.new("RGBA", (2, 2), (10, 20, 30, 255)).save(frame)
            output = root / "test.pxo"

            pixelorama_packager.package_project(output, [frame], tag="progression", frame_ms=1000, layer_name="Environment")

            with zipfile.ZipFile(output) as archive:
                data = json.loads(archive.read("data.json"))
                self.assertEqual(data["layers"][0]["name"], "Environment")


if __name__ == "__main__":
    unittest.main()
