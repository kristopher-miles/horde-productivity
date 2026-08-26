# Decision

Selected: byte-preserving reuse of approved `kobold-master-idle` seed attempt 02 and strip attempt 02.

No ImageGen call, redraw, recoloring, scaling, or motion change was made for Adult. The four approved master frames were renamed deterministically, and frame 01 was retained separately as the reusable Adult model. All frames keep the native `48x64` canvas, common y `62` baseline, and occupied heights `60, 60, 59, 59` pixels.

Result: the canonical broadest/tallest model reads as Adult after Baby and Kid at native 1x. The replaceable prototype is installed only in `KoboldAdultIdle.atlas`; resident placement remains deferred.

