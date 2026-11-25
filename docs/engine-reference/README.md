# Godot engine reference

Version-specific notes on **Godot 4.7** (we pin 4.7.2, see [../SETUP.md](../SETUP.md)).

AI models' knowledge of Godot runs out around version 4.3–4.4, and 4.5, 4.6 and 4.7 changed real APIs. **Before writing or reviewing Godot code, check these files first**, then the official docs they link to.

| File | Use it for |
|---|---|
| [godot/VERSION.md](godot/VERSION.md) | Which version the notes cover and when they were checked |
| [godot/breaking-changes.md](godot/breaking-changes.md) | What changed between 4.4 and 4.7, by risk |
| [godot/deprecated-apis.md](godot/deprecated-apis.md) | "Don't use X, use Y" tables |
| [godot/current-best-practices.md](godot/current-best-practices.md) | Newer patterns, including command-line testing with gdUnit4 |
| [godot/modules/](godot/modules/) | Short notes per area: animation, audio, input, navigation, networking, physics, rendering, UI |

## Source and licence

- Copied on 2026-11-25 from [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) by Donchitos, release 1.3.0 (commit `abc0de7`), folder `docs/engine-reference/godot`.
- MIT License; the original licence text is in [godot/LICENSE-claude-code-game-studios.txt](godot/LICENSE-claude-code-game-studios.txt).
- The files are unchanged. A few lines mention that project's own tools (`/setup-engine`, `.claude/scripts/godot-parse-check.gd`); those tools are **not** part of this project, so ignore those lines.
- These notes are a helpful summary, not the authority. Where they disagree with the official Godot documentation or with what Godot 4.7.2 actually does, trust the official source and fix the note.
