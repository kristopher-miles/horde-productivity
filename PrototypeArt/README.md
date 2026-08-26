# Prototype Art Workspace

This directory contains replaceable development art and the evidence needed to reproduce it. Generated images are inputs, not production promises.

## Directory contract

- `references/`: composition and palette references derived from the current app art.
- `pilots/<asset>-<cue>/`: brief, raw generation, normalized frames, editable source, and QA media for one animation.
- `toolchain.md`: pinned local tools and upstream provenance.
- `workflow-status.md`: Phase 7 gates and decisions.
- `workflow-decision.md`: frozen prototype workflow and escalation rules.
- `phase7-exit-audit.md`: final gate evidence and known prototype debt.
- `phase8-asset-audit.md`: full asset-suite inventory, validation results, and integration boundary.
- `guides/`: development-only native room and character generation guides.
- `phase8-qa/`: native composite state previews assembled from approved layers.
- `evidence-log.md`: attempts and hands-on time used for staffing estimates.
- `scripts/`: deterministic normalization, validation, and Pixelorama packaging.

Final runtime PNGs belong in the Xcode asset catalog. Raw generations and QA media stay here and never ship in the app bundle.
