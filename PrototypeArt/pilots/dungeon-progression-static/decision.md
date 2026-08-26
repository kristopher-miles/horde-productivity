# Decision

Selected: ImageGen attempt 02 plus one native stage-1 pixel cleanup.

Attempt 01 established the coherent camera, shared cave geometry, open staging floor, and clear stages 1–4. It was not selected because stage 5 read as a richly furnished room rather than a vast fortress. The one permitted targeted correction changed only cell 5, adding a deep repeated-arch vault, massive pillars, overflowing gold, chests, and clearly colored gemstones. Cells 1–4 and the unmistakable solid-magenta unused sixth cell remained coherent.

Both generated attempts inherited a worked hearth, fitted masonry, and heraldic crest in stage 1 from the composition seed. A native-scale review rejected those settlement signs. With the ImageGen correction allowance exhausted, `cleanup-stage1.py` performed the smallest reviewed deterministic pixel cleanup: an irregular binary mask copied existing natural cave-wall pixels from `(178, 7)–(290, 105)` over the worked structure at `(65, 7)`, then copied a triangular webbed-rock patch from `(275, 0)–(320, 72)` to `(105, 4)`. It did not redraw, rescale, soften, or alter the floor, camera, palette, later stages, or staging geometry.

## Gate result

- Stage 1 reads as an unlit, cold, webbed, damp, sad natural cave with irregular raw rock and no visible settlement.
- Stage 2 adds only a crude fire ring, rough mat, faint warmth, and sparse storage.
- Stage 3 reads as a settled and fortified practical hall.
- Stage 4 reads as a rich, warm, imposing stronghold.
- Stage 5 reads as a vast underground fortress whose receding vault is surrounded by overflowing gold, treasure chests, ingots, and multicolored gemstones.
- The unlabeled native contact sheet reads unambiguously poorest-to-richest.
- The five frames retain a fixed front-facing camera and a usable open lower-center staging area.
- The dedicated VC-02 review rejected the dragon-like emblems inside the stage 2–4 fireplace shields. `cleanup-vc02.py` replaces only those three shield interiors with plain project-palette metal at native resolution; the shield outlines, room progression, camera, and composition are unchanged.
- All five standalone environment frames contain no living creature, face, statue, or character silhouette after cleanup. Stage 5's colored clusters read as faceted gemstones and its upper shelf ornament reads as a vessel, not as a living figure.

Result: deterministic and visual VC-01 and VC-02 gates pass. The complete family is marked replaceable prototype art, remains outside the app bundle, and is not integrated into runtime or VC-04 consumers by this item.
