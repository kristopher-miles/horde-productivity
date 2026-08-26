import tempfile
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parents[1]))
from render_complete_visual_qa import PILOT, build


class CompleteVisualQATests(unittest.TestCase):
    def test_committed_visual_matrix_is_deterministic_and_complete(self):
        with tempfile.TemporaryDirectory() as directory:
            result = build(Path(directory))
            committed = PILOT / "qa"
            self.assertEqual(result["roomDragonCombinations"], 25)
            self.assertEqual(result["dragonRecolorCombinations"], 30)
            self.assertEqual(result["livingCreaturesPerSourceBackground"], 0)
            self.assertEqual(result["charactersPerRoomDragonCell"], 1)
            self.assertEqual(result["koboldAges"], 3)
            self.assertEqual(result["koboldPalettesPerAge"], 3)
            for filename in ["room-dragon-5x5-contact-sheet.png", "dragon-recolor-5x6-contact-sheet.png", "validation.json"]:
                self.assertEqual((Path(directory) / filename).read_bytes(), (committed / filename).read_bytes())


if __name__ == "__main__":
    unittest.main()
