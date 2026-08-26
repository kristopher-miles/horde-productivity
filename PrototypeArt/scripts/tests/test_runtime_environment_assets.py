import hashlib
import json
import unittest
from pathlib import Path

from PIL import Image


REPOSITORY = Path(__file__).parents[3]
PILOT = REPOSITORY / "PrototypeArt/pilots/dungeon-progression-static"
CATALOG = REPOSITORY / "TheHorde/Resources/Assets.xcassets"
EXPECTED_HASHES = [
    "528c9cba31339b414ab14a6b05bc7944b491875d5df9abcb473202d20e62ab29",
    "82232a85ff552e0c291d03f065e539eae99497eea591d6ad030e106630e4d5fc",
    "a2732bd6e8bb609a09022bbe0f0f7229ff1bba581e16badfa63e6d3a80e7ce91",
    "c6aa3cdbd10746f871ba6fd5ea8d5be0b4bf0955e0a8e1f1b5e6fb7c770918a0",
    "4420b950c259e92a173e474ba5a8e8520b37a8dc2aae9a1ad0e567fb1e131b64",
]


class RuntimeEnvironmentAssetTests(unittest.TestCase):
    def test_runtime_family_is_the_exact_opaque_native_source(self):
        for stage, expected_hash in enumerate(EXPECTED_HASHES, start=1):
            filename = f"dungeon-progression-static-{stage:02d}.png"
            source = PILOT / "normalized" / filename
            imageset = CATALOG / f"DungeonStage{stage}.imageset"
            runtime = imageset / filename
            contents = json.loads((imageset / "Contents.json").read_text())

            self.assertEqual(runtime.read_bytes(), source.read_bytes())
            self.assertEqual(hashlib.sha256(runtime.read_bytes()).hexdigest(), expected_hash)
            self.assertEqual(contents["images"], [{"filename": filename, "idiom": "universal", "scale": "1x"}])
            self.assertEqual(contents["properties"]["compression-type"], "lossless")
            with Image.open(runtime) as image:
                self.assertEqual(image.mode, "RGBA")
                self.assertEqual(image.size, (320, 180))
                self.assertEqual(image.getchannel("A").getextrema(), (255, 255))

    def test_only_the_five_contract_dungeon_backgrounds_are_bundled(self):
        self.assertEqual(
            {path.name for path in CATALOG.glob("Dungeon*.imageset")},
            {f"DungeonStage{stage}.imageset" for stage in range(1, 6)},
        )

    def test_runtime_sources_retain_the_empty_environment_audit(self):
        audit = (PILOT / "qa/vc02-creature-audit.md").read_text()
        for stage, expected_hash in enumerate(EXPECTED_HASHES, start=1):
            self.assertIn(f"dungeon-progression-static-{stage:02d}.png", audit)
            self.assertIn(expected_hash, audit)
        self.assertIn("no creature", audit.casefold())


if __name__ == "__main__":
    unittest.main()
