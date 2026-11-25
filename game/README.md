# Tiger & Goat (game project)

The real game, Godot 4.7.2. Started 2026-11-26 (BUILD_PLAN.md phase 1, decision D49). The throwaway proof is in `../trial/`.

## Layout

| Path | What |
|---|---|
| `shell/` | The app around the games: `app.gd` (tabs, screen stack, back button), `ui.gd` (style kit), `store.gd` (save file), `sfx.gd`, `modal.gd`, `screen.gd` |
| `shell/screens/` | Home (Play tab), Daily, Friends, Profile, game page, play, result, settings |
| `games/aadupuli/rules/` | The rules. Pure data, no screen code; the only place that knows what is legal |
| `games/aadupuli/ai/` | Computer opponent (interim; phase 2 replaces it) |
| `games/aadupuli/board/` | Board drawing ("Hill and meadow"), pieces, non-interactive preview |
| `tests/` | gdUnit4 tests: every rule, plus an app walk-through |
| `assets/` | Fonts (OFL), icons (Tabler, MIT; kept as raw SVG), sounds (made for this game) |
| `addons/gdUnit4/` | Test framework 6.2.2 (MIT); not included in exports |

## Commands (from the repository root)

Run all tests:

```bash
bash tools/run_tests.sh
```

Open in the editor:

```bash
godot --path game --editor
```

Export web and Android (from `game/`):

```bash
godot --headless --path . --export-release Web build/web/index.html
```

```bash
godot --headless --path . --export-debug Android build/android/tiger-goat.apk
```

Play on a phone on the same Wi-Fi: start the `app-web-phone` preview (`.claude/launch.json`) and open `http://<this computer's Wi-Fi address>:8061`.

## Notes

- **Icons** are read as raw SVG at runtime and tinted in code. Each has a `.svg.import` file set to `keep`, so exports include the file as-is. A new icon needs the same three-line import file.
- **Text** is plain English in code; Godot passes Control text through translation automatically, so other languages can be added later with a translation file.
- **Save file:** `user://save.json` (profile, settings, stats), written atomically.
- The Android package name is a placeholder (`org.placeholder.boardgames`) until the platform brand is chosen (week 11).
