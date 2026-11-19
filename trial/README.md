# Trial project (throwaway)

The one-week Godot go/no-go proof from [BUILD_PLAN.md](../BUILD_PLAN.md) section 5. **None of this code is kept**: the real game is built fresh in `game/` from phase 1, with tests.

What it contains:

- The verified 23-point board drawn in code in the brass-and-wood palette.
- Playable pass-and-play Aadupuli: goats place, then move; tigers move and jump. No undo, no repeat rule.
- Three Tamil-capable fonts to compare (button "Font").
- Three generated sounds (place, move, capture) and a vibration on capture (phones only).
- On-screen measurements: platform, start-up time, frames per second, and "Think 1 s" for look-ahead depth.

## Commands (from the repository root, in a new terminal)

Open in the editor:

```bash
godot --path trial --editor
```

Run the timing test and rule checks:

```bash
godot --headless --path trial -s res://tools/timing.gd
```

Export the web and Android builds:

```bash
godot --headless --path trial --export-release Web build/web/index.html
```

```bash
godot --headless --path trial --export-debug Android build/android/trial.apk
```

Install on a phone with USB debugging on:

```bash
adb install -r trial/build/android/trial.apk
```

Regenerate the sounds:

```bash
python -I trial/tools/make_sounds.py trial/assets/sounds
```

## Credits

- Fonts: Hind Madurai (Indian Type Foundry), Catamaran (The Catamaran Authors), Mukta Malar (Ek Type). All SIL Open Font License 1.1; licence files are next to the fonts.
- Sounds: synthesised by `tools/make_sounds.py`.
