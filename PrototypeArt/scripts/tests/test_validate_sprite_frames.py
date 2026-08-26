import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image


SCRIPT = Path(__file__).parents[1] / "validate_sprite_frames.py"
SPEC = importlib.util.spec_from_file_location("validator", SCRIPT)
validator = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(validator)


class ValidatorTests(unittest.TestCase):
    def test_valid_pair_and_anchor_drift(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            palette = Image.new("RGB", (1, 1), (220, 80, 10))
            palette.save(root / "palette.png")
            manifest = {
                "asset": "ember", "cue": "idle",
                "frameSize": {"width": 8, "height": 8}, "safetyInsetPixels": 1,
                "frames": [
                    {"file": "ember-idle-01.png", "durationMilliseconds": 180},
                    {"file": "ember-idle-02.png", "durationMilliseconds": 180},
                ],
            }
            (root / "manifest.json").write_text(json.dumps(manifest))
            for name in ("ember-idle-01.png", "ember-idle-02.png"):
                image = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
                for y in range(3, 7):
                    for x in range(2, 6):
                        image.putpixel((x, y), (220, 80, 10, 255))
                image.save(root / name)
            self.assertEqual(validator.validate(root / "manifest.json", root, root / "palette.png"), [])
            shifted = Image.open(root / "ember-idle-02.png")
            shifted.transform((8, 8), Image.Transform.AFFINE, (1, 0, 0, 0, 1, 1)).save(root / "ember-idle-02.png")
            self.assertTrue(any("anchor drift" in error for error in validator.validate(root / "manifest.json", root, root / "palette.png")))


if __name__ == "__main__":
    unittest.main()
