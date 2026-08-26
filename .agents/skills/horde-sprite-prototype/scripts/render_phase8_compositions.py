#!/usr/bin/env python3
"""Render native Phase 8 scene-composition QA from approved frames."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[4]
PILOTS = ROOT / "PrototypeArt" / "pilots"
OUTPUT = ROOT / "PrototypeArt" / "phase8-qa"


def load(relative: str) -> Image.Image:
    return Image.open(ROOT / relative).convert("RGBA")


def place(scene: Image.Image, sprite: Image.Image, x: int, y: int) -> None:
    scene.alpha_composite(sprite, (round(x - sprite.width / 2), scene.height - y - sprite.height))


def render(name: str, overlay: str | None, ember: str, residents: dict[str, str]) -> Image.Image:
    scene = load("PrototypeArt/pilots/great-room-background-static/normalized/great-room-background-static-01.png")
    if overlay:
        scene.alpha_composite(load(overlay))
    place(scene, load("PrototypeArt/pilots/hearth-fire-idle/normalized/hearth-fire-idle-01.png"), 112, 73)
    lantern = load("PrototypeArt/pilots/lantern-flame-idle/normalized/lantern-flame-idle-01.png")
    place(scene, lantern, 35, 100)
    place(scene, lantern, 234, 100)
    for resident, x in (("pip", 52), ("moss", 104), ("rill", 269)):
        place(scene, load(residents[resident]), x, 40)
    place(scene, load(ember), 184, 40)
    scene.alpha_composite(load("PrototypeArt/pilots/great-room-foreground-static/normalized/great-room-foreground-static-01.png"))
    scene.save(OUTPUT / f"{name}.png")
    return scene


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    normal_residents = {name: f"PrototypeArt/pilots/{name}-idle/normalized/{name}-idle-01.png" for name in ("pip", "moss", "rill")}
    concern_residents = {name: f"PrototypeArt/pilots/{name}-concern/normalized/{name}-concern-03.png" for name in ("pip", "moss", "rill")}
    celebrate_residents = {name: f"PrototypeArt/pilots/{name}-celebrate/normalized/{name}-celebrate-03.png" for name in ("pip", "moss", "rill")}
    scenes = [
        render("normal", None, "PrototypeArt/pilots/ember-idle/normalized/ember-idle-01.png", normal_residents),
        render("hazard", "PrototypeArt/pilots/room-hazard-appears/normalized/room-hazard-appears-04.png", "PrototypeArt/pilots/ember-concern/normalized/ember-concern-03.png", concern_residents),
        render("recovery", "PrototypeArt/pilots/room-recovery-glow/normalized/room-recovery-glow-02.png", "PrototypeArt/pilots/ember-recover/normalized/ember-recover-04.png", celebrate_residents),
        render("resource-change", "PrototypeArt/pilots/room-resource-change/normalized/room-resource-change-04.png", "PrototypeArt/pilots/ember-recover/normalized/ember-recover-04.png", normal_residents),
    ]
    sheet = Image.new("RGBA", (320 * len(scenes), 180), (0, 0, 0, 0))
    for index, scene in enumerate(scenes):
        sheet.alpha_composite(scene, (index * 320, 0))
    sheet.save(OUTPUT / "phase8-state-contact-sheet.png")
    assert all(scene.size == (320, 180) for scene in scenes)


if __name__ == "__main__":
    main()
