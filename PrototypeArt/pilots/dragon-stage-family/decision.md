# Dragon Stage Family Decision

The ordered family passes visual review: **Baby → Adolescent → Adult → Elder → Great Wyrm**. Silhouette length, height, horn and wing scale, body mass, and scene presence increase at every step. The contact sheet contains exactly five labeled stages over a character-free cavern; the all-frames sheet and timed preview prove four-frame loops at exact runtime geometry.

Native per-stage canvases (`96x80`, `108x90`, `120x100`, `132x110`, `144x120`) were selected over fractional runtime scaling. Runtime uses 1:1 sizes, nearest filtering, a shared bottom-center anchor, and integer scene placement, avoiding uneven cluster duplication and shimmer. Later stages intentionally provide idle only; event cues may reuse idle plus existing lightweight runtime effects. No environment or power-progression behavior is part of this decision.
