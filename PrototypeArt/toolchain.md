# Sprite Prototype Toolchain

Validated on an Apple M3 Max Mac with macOS 26.

| Tool | Pinned version/source | Purpose | Status |
| --- | --- | --- | --- |
| Pixelorama | `v1.2.1-stable`, official macOS release | Editable `.pxo`, timeline review, palette edits, UI and CLI exports | Installed; UI and CLI round trips verified |
| Codex ImageGen | Built-in `imagegen` tool | Canonical seed and complete animation-strip generation | Idle and concern strips proven |
| OpenAI `sprite-pipeline` | `openai/plugins` commit `11c74d6ba24d3a6d48f54a194cd00ef3beea18f9` | Edit canvas, normalization baseline, contact sheet | Skill installed; upstream source pinned locally |
| Pillow | `11.3.0` in `PrototypeArt/.venv` | Runs deterministic image scripts | Installed; seven script tests pass |
| PyYAML | `6.0.3` in `PrototypeArt/.venv` | Runs the official Codex skill validator | Installed; skill structure passes |
| ffmpeg | Homebrew installation | Native-scale previews and GIF/APNG generation | Installed |
| SpriteKit/Xcode | System Xcode | Runtime atlas playback | Idle and concern atlases integrated and tested |
| Horde skill | `.agents/skills/horde-sprite-prototype` | Project contract, complete-strip workflow, deterministic scripts, and QA | Official validator and fresh-context celebrate acceptance pass |

## Installed locations

- Pixelorama app: `/Applications/Pixelorama.app`
- Installed Codex skill: `/Users/kris/.codex/skills/sprite-pipeline`
- Pinned upstream source: `/Users/kris/.codex/vendor/openai-plugins`

The generic skill installer copies only `sprite-pipeline/SKILL.md`; its `../../scripts` and `../../references` links do not resolve from the installed location. For this pilot, commands use the pinned upstream source above. The project skill will contain the proven project-sized scripts directly, eliminating that broken-link dependency.

Pixelorama's headless export requires absolute input/output paths. Version `1.2.1` logs Godot dummy-renderer warnings on headless exit, but still returns the correct size/frame count and writes valid PNG/GIF outputs.

The macOS native save panel cannot be driven reliably through the available UI automation. `scripts/package_pixelorama_project.py` therefore writes Pixelorama's documented v7 ZIP container deterministically from approved RGBA frames, including the project palette, tag, timing, and provenance. Pixelorama `v1.2.1` opens both Horde projects as `96x80`, four-frame sources and re-exports byte-identical horizontal sheets.
