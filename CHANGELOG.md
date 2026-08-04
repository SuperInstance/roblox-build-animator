# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-08-04

### Added
- Initial release of BuildAnimator as a standalone, framework-agnostic module.
- **Core API:**
  - `BuildAnimator:play(parts, pattern?, center?, onComplete?)` — primary entry point
  - `BuildAnimator:playInTime(parts, bpm, center?, onComplete?)` — musical timing variant
  - `BuildAnimator.animatePart(part, transparency?, style?)` — single part animation
  - `BuildAnimator.burst(position, color, duration?)` — standalone particle burst
  - `BuildAnimator.playPlacementSound(material, position)` — material-aware sound
- **Animation styles:** `scale`, `drop`, `rise`, `cascade`, `weather`
- **Pattern presets:** `rise`, `fade`, `scaleIn`, `drop`, `cascade`, `materialShift`, `weather`
- **Pattern API:** `Patterns.get()`, `Patterns.list()`, `Patterns.extend()`
- **Events:** `OnComplete`, `OnPartRevealed` (BindableEvent-backed)
- **Configuration:** `configure()`, `resetConfig()`, `getConfig()`
- **Queue management:** `clearQueue()`, `getStats()`
- **Spatial ordering:** `height_then_distance` (default), `distance`, `none`
- **Concurrency control:** configurable max concurrent animations with queue fallback
- **Musical timing:** BPM-derived 32nd-note grid via `getStagger(bpm)`
- **Material sound mapping:** stone, wood, metal, glass, neon families with pitch variation
- **Rojo project file** (`default.project.json`)
- **Demo script** cycling through all patterns
- **Test suite** for pattern validation, spatial sorting, API surface
- MIT license

### Extracted From
- Derived from the Slackwater/Lucineer codebase (1297-line `BuildAnimator.lua`), stripped of all game-specific dependencies (BeatClock, CommandExecutor, Config.World, Worker API) and made fully framework-agnostic.
