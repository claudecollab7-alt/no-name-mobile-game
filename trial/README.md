# Trial project (throwaway)

The one-week Godot go/no-go proof from [BUILD_PLAN.md](../BUILD_PLAN.md) section 5. **None of this code is kept**: the real game is built fresh in `game/` from phase 1, with tests.

What it contains:

- The verified 23-point board drawn in code in the "Hill and meadow" look: tigers' cave on the summit, worn paths, meadow below.
- Playable pass-and-play Aadupuli: goats place, then move; tigers move and jump. No undo, no repeat rule.
- Fredoka (headings, buttons) and Figtree (text) fonts.
- Plato-like play screen: a panel per side with its goal, a "How to play" card, and a one-line hint.
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

## Playing it on a phone

**Web, any phone on the same Wi-Fi:** start the `trial-web-phone` preview (in `.claude/launch.json`; `tools/serve.py` serves `trial/build/web` on port 8061 to the local network with caching off), then open `http://<this computer's Wi-Fi address>:8061` on the phone. Find the address with `ipconfig` (the "IPv4 Address" under Wi-Fi). Windows Firewall already allows Python on this computer.

**Android app, no cable:** send `trial/build/android/trial.apk` to the phone (USB file transfer, Google Drive or a message to yourself), open it, and allow "Install unknown apps" for the app you opened it from when Android asks. Turn that permission off again afterwards.

**Android app, with a cable:** turn on USB debugging (Settings › About phone › tap "Build number" seven times › Developer options › USB debugging), plug in, accept the prompt, then run the `adb install` command above.

## Credits

- Fonts: Fredoka (The Fredoka Project Authors) and Figtree (The Figtree Project Authors). Both SIL Open Font License 1.1; licence files are next to the fonts.
- Sounds: synthesised by `tools/make_sounds.py`.
