# Contributing to BuildAnimator

Thanks for your interest in improving BuildAnimator! 

## Getting Started

1. **Fork & clone** the repo
2. Install [Rojo](https://rojo.space) for Studio sync
3. Run `rojo serve` and sync into a test place

## Development Workflow

```bash
rojo serve  # live sync to Studio
```

### Running Tests

Tests live in `spec/` and use the [TestEZ](https://github.com/Roblox/testez) format. Run them through Studio's TestEZ runner or CI.

### Code Style

- **Luau type annotations** on all public functions
- **Doc comments** (`--[[ ... ]]`) on exported APIs
- **Upper-case constants** for config keys (e.g. `PART_TWEEN_TIME`)
- **camelCase** for function names
- All particle/sound cleanup must go through `Debris` — no manual `Destroy()` timers
- New patterns go in `Patterns.lua` — test them in the demo

### Adding a New Animation Style

1. Add the style name to the `ANIMATION_STYLE` config comment
2. Implement the movement logic in `animatePart()` and `_animatePartWithCompletion()`
3. Create a pattern preset in `Patterns.lua`
4. Add a test cycle in `Demo.lua`
5. Document it in the README

### Cleanup Safety

BuildAnimator must never leak parts or sounds. Follow these rules:
- Every `Instance.new("Part")` for effects gets `Debris:AddItem(carrier, lifetime)`
- Every `Sound` gets `Debris:AddItem(sound, 3)`
- Tween completion handlers are guarded by a `completed` flag to prevent double-fire
- A safety timer fires after `PART_TWEEN_TIME + 0.5` to force-finalize any stuck tween

## Submitting Changes

1. Feature branch: `git checkout -b feat/your-feature`
2. Test in Studio with the demo script
3. Clear commit messages (present tense, imperative mood)
4. Open a PR

## Reporting Bugs

Include:
- Roblox Studio version
- Number of parts in the batch
- Animation style used
- Whether `BuildAnimator.clearQueue()` was called before the issue

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
