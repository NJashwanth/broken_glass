## 1.0.0

Initial release.

* `BrokenGlass` — snapshots any child and breaks it into shards. Drive it
  declaratively with `broken`, from a touch with `breakOnTap`, or imperatively
  with a `BrokenGlassController`.
* `ShatterPattern` — radial cracks crossed by concentric fracture rings, with
  `fine`, `chunky` and `spiderWeb` presets.
* `GlassStyle` — cracks, lit bevels, per-facet sheen, tint and shadows, with
  `window`, `screen` and `frost` presets.
* `BrokenGlassController` — `shatter()`, `restore()` and `toggle()`; `restore()`
  plays the break backwards.
* `scatter: false` for crack-in-place damage, and `spread` / `gravity` /
  `rotation` / `fade` to tune the motion.
