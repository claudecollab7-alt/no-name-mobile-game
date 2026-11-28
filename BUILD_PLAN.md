# Build Plan — Trial Week and Release 1

- **Written:** 2026-11-16
- **Covers:** the one-week Godot trial and release 1 (Tiger & Goat: the Aadupuli rules for a global audience).
- **Companion:** [DISCUSSION.md](DISCUSSION.md) holds every decision and its reason. Its "Current plan at a glance" table is the source of truth. If this plan and that table disagree, stop and ask.
- **Who does what:** Opus writes the code. You review, test on a real phone, and make the decisions listed in [section 12](#12-decisions-you-owe-and-when).
- **Pace:** 10–20 hours a week. If late, cut from the bottom of the stretch list and keep the date.

Anything marked *(verify)* is from memory and must be checked against the installed Godot version or the current store rules before relying on it.

---

## 1. How to use this plan

### For each working session

1. Read the "Current plan at a glance" in DISCUSSION.md and the [progress tracker](#13-progress-tracker) here.
2. Pick the next unticked task. Do one task per session.
3. Build it to its "Done when" line. Run the automated tests.
4. Tell the user exactly what to check on the phone or in the Godot editor.
5. Tick the task in the tracker and add a line to the [session log](#14-session-log).

### Ground rules for the code

- **Rules and computer opponent are plain GDScript classes** (extending `RefCounted`), with no nodes, no scenes and no screen code. They must run from the command line.
- **Check [docs/engine-reference](docs/engine-reference/README.md) before writing Godot code.** AI knowledge of Godot stops around 4.3–4.4; those notes list what changed up to 4.7 and which APIs are deprecated.
- **Typed GDScript everywhere** (`var x: int`, typed arrays, return types).
- **The shell knows nothing about Aadupuli.** It talks to a game only through the module contract in [section 3](#3-architecture).
- **Every rule has a test.** A rule change without a test change is not done.
- **All visible text goes through translation keys.** No player-facing text hard-coded in scripts or scenes, so more languages can be added later.
- **No new decisions in code.** If a task needs a product decision that DISCUSSION.md does not answer, stop and ask.
- **Opus cannot see the Godot editor or a phone.** Anything visual or tactile ends with a short checklist for the user.
- **Commits:** the user decides when to commit. Suggest a commit at the end of each finished task.

---

## 2. Week 0 — your preparation

Nothing here needs Opus. Tick these before the trial week.

| # | Task | Notes |
|---|---|---|
| P1 | Install Godot 4, latest stable, standard (not .NET) build | Done 2026-11-16: **4.7.2 pinned**. Full setup in [docs/SETUP.md](docs/SETUP.md). |
| P2 | Do the official "Your first 2D game" tutorial | 2–3 hours. The goal is being able to read GDScript and find your way round the editor. |
| P3 | Install Android build tools | Android Studio (for the SDK) and JDK 17 *(verify the JDK version Godot asks for)*. Follow Godot's "Exporting for Android" page. |
| P4 | Install Git and create a free private GitHub repository | The project folder is not a Git repository yet. |
| P5 | Get a cheap Android test phone | Borrow or buy the lowest-end phone you can (2–3 GB memory). Turn on USB debugging. This phone is the judge for every speed target. |
| P6 | Play 20–30 games of Aadupuli on paper | Use the rules in DISCUSSION.md section 17. Note where it drags and where it's exciting. |
| P7 | **Verify the board** — done 2026-11-16 | Board confirmed against your picture and tiger start points confirmed; see [section 4](#4-the-board-verified-2026-11-16). |
| P8 | Play the competitor's Aadupuli app for an hour | Note what confuses, what is missing, what they do well. |
| P9 | Open a Google Play developer account | One-time $25. Identity checks can take days, so start early. |
| P10 | Start asking 12 people to be testers | They need Android phones and Google accounts, and must stay opted in for 14 days in a row in weeks 13–14. Ask 15–18 so drop-outs don't reset the clock. |

---

## 3. Architecture

### Folder layout

| Path | Contents |
|---|---|
| `game/` | The Godot project |
| `game/shell/` | Start-up, home shelf, mode picker, settings, profile, stats, saving, sound, language, sharing |
| `game/games/aadupuli/` | The Aadupuli module: `rules/`, `ai/`, `board/`, `tutorial/`, `puzzles/`, `text/` |
| `game/shared/` | Pieces reused by every game: tutorial engine, puzzle frame, search runner, UI parts, theme |
| `game/tests/` | Automated tests, run from the command line |
| `tools/` | Command-line scripts: self-play balance runner, puzzle generator, test runner |
| `site/` | The plain website; the web build is copied under `site/play/` |
| `DISCUSSION.md`, `BUILD_PLAN.md` | The two planning documents |

### Layers

```text
Shell (screens, navigation, profile, saving, language, sound, sharing)
   │  talks only through the game module contract
   ▼
Game module (Aadupuli)
   ├── Board view      draws a state, turns taps into moves
   ├── Tutorial data   scripted steps
   ├── Puzzle data     bundled daily puzzles
   ├── Opponent        picks a move for a state, a level and a time budget
   └── Rules           the only place that knows what is legal
```

Dependencies point downward only. Rules depend on nothing.

### The game module contract

Every game supplies these pieces. Names are a starting point; keep them identical across games.

| Piece | Kind | Responsibility |
|---|---|---|
| `GameDefinition` | Resource | Id, title key, family-name key, supported modes, variants, options with defaults, links to the scenes and data below |
| `Rules` | `RefCounted` | `initial_state(options)`, `legal_moves(state)`, `apply_move(state, move)`, `result(state)`, `to_dict(state)`, `from_dict(data)` |
| `Opponent` | `RefCounted` | `choose_move(state, level, time_budget_ms)`; must be interruptible and never touch the screen |
| `BoardView` | Scene | `show_state(state)`, `set_legal_hints(moves)`, signal `move_chosen(move)`; plays its own animations and sounds |
| `TutorialScript` | Data file | Ordered steps: board position, highlighted targets, text key, the move that completes the step |
| `PuzzleSet` | Data file | Bundled puzzles: position, side to move, goal, solution line, difficulty |
| Text | Translation file | Every string for this game, in English (more languages later) |

`apply_move` returns a new state and never changes the one it was given. That makes undo, replay, search and tests simple.

### Aadupuli state

Kept small and integer-based so the opponent can search quickly.

| Field | Type | Meaning |
|---|---|---|
| `tigers` | three ints (0–22) | Point index of each tiger |
| `goats` | int used as 23 bits | Which points hold a goat |
| `goats_in_hand` | int | Goats not yet placed (starts at 15) |
| `captured` | int | Goats taken by tigers |
| `to_move` | int | Goats or tigers |
| `position_counts` | Dictionary | How many times each full position has occurred, for the no-repeat rule |

Always true: goats on board + `goats_in_hand` + `captured` = 15. Tests check this after every move.

Two lookup tables are built once from the board data: `NEIGHBOURS[point]` (points one step away) and `JUMPS[point]` (pairs of "over" and "landing" points in a straight line).

### Options (set per game, not hard-coded)

| Option | Release 1 value | Why it is an option |
|---|---|---|
| `capture_target` | 5 | Decision D10: settled by self-play in phase 2; later a house rule |
| `start_mode` | `fixed` | Decision D11: other start modes arrive later |
| `repeat_limit` | 3 | Decision D12: a move creating a position for the third time is illegal |
| `board_id` | `classic_23` | Decision D34: more boards may be added later |
| `tiger_count`, `goat_count` | 3 and 15 | Decision D34: other counts may be offered later |

### Saving

One versioned JSON file in Godot's `user://` folder, written to a temporary file and then renamed so a crash cannot corrupt it. Holds settings, stats, puzzle streak, ladder progress, unlocked themes and any game in progress. A `version` number and a small upgrade function are there from the first save.

---

## 4. The board (verified 2026-11-16)

**Verified against the board picture you supplied**, saved as [docs/board-reference.png](docs/board-reference.png). The picture shows exactly this layout: one top point, three rows of six joined by the rectangle's left and right sides, four lines fanning down from the top, and a bottom row of four. 23 points, 38 connections, 3 tigers, 15 goats.

You decided to start with this board and add more boards or piece-count options later if needed. So the board is a data file, and the number of tigers and goats are options, never fixed numbers in the code.

```text
Row 0 (top point):                 0

Row 1:              1     2     3     4     5     6
Row 2:              7     8     9    10    11    12
Row 3:             13    14    15    16    17    18

Row 4 (bottom):          19    20    21    22
```

| Lines | Points in order |
|---|---|
| Four lines fanning down from the top | 0–2–8–14–19, 0–3–9–15–20, 0–4–10–16–21, 0–5–11–17–22 |
| Three long rows | 1–2–3–4–5–6, 7–8–9–10–11–12, 13–14–15–16–17–18 |
| Bottom row | 19–20–21–22 |
| Left and right sides | 1–7–13 and 6–12–18 |

- 23 points and 38 connections.
- The side lines (1–7–13 and 6–12–18) are confirmed by the picture.
- A tiger jumps only along one of these lines: over the next point, landing on the one after.
- Fixed start: tigers on 0, 3 and 4 (the top point plus the two centre points of the first row). **Confirmed by you on 2026-11-16.**

---

## 5. Phase 0 — trial week (week 1)

A throwaway proof. Its code is not kept. Its only job is a go or no-go on Godot.

| # | Task | Done when |
|---|---|---|
| T0.1 | New Godot project: Compatibility renderer, portrait, 1080×1920 base size with stretch enabled | Project opens and runs on the PC |
| T0.2 | Draw the draft board in code; place 3 tigers and a few goats; tap a piece, tap a point, it slides there | Pieces move smoothly on the PC |
| T0.3 | Bundled fonts, one sound on move, one vibration on capture. Draw the board in the starting palette (now "Hill and meadow", DISCUSSION.md section 24). *(Changed 2026-11-25: Tamil text dropped for the global focus; fonts are now Fredoka and Figtree.)* | Text, sound and vibration all present; board readable on the cheap phone indoors and in sunlight |
| T0.4 | Export to Android and install on the cheap phone | The app runs on the phone |
| T0.5 | Export to web; serve it locally; open it in the phone's browser | The game loads and plays in the browser |
| T0.6 | Timing test: a rough move generator and a simple look-ahead, run on the phone | Numbers recorded for depth reached in 1 second |
| T0.7 | Look up, without building, a Godot plugin for Google Play Games saved games | One-paragraph finding: workable, risky or not available |

### Go or no-go measurements (on the cheap phone)

| Measure | Pass | Worry | Fail |
|---|---|---|---|
| Android download size | under 30 MB | 30–45 MB | over 45 MB |
| Time from tap to first screen | under 3 s | 3–5 s | over 5 s |
| Smoothness while a piece slides | steady, no visible stutter | occasional stutter | constant stutter |
| Text | crisp and readable at small sizes | slightly soft | blurry or clipped |
| Web: transfer size / load on mobile data | under 15 MB / under 10 s | up to 25 MB / 20 s | worse |
| Opponent look-ahead in 1 second | 6 or more moves deep | 4–5 | 3 or fewer |

Thresholds are my proposals.

### Trial results so far (2026-11-19)

The trial project is in [trial/](trial/README.md). It plays a real pass-and-play game: goats place then move, tigers move and jump, captures and wins are counted.

| Measure | Result | Verdict |
|---|---|---|
| Board data | 23 points, 38 connections, all two-way | Pass |
| Rule sanity | 300 random games all finished; goat total never broke | Pass |
| Android download size | 27.7 MB debug APK, arm64 only (an empty project is 27 MB) | **Pass, but close to 30 MB.** Real content will push it over; plan an engine trim before release |
| Web transfer size | 10.4 MB compressed (game data itself is 0.6 MB) | Pass |
| Tamil text (since dropped) | Joined correctly in the web build before Tamil was removed from the app on 2026-11-25 | No longer tested |
| Look-ahead, this laptop, native | 5–8 moves deep in 1 s, about 46,000 positions a second | Reference only |
| Look-ahead, this laptop, browser | 6 moves deep in 1 s, about 56,000 positions a second | Reference only |
| Look-ahead on the cheap phone | Not measured yet | Expect roughly 4–5 moves; likely a **worry**, fixable in phase 2 with a position table and better ordering |
| Start-up, smoothness, sunlight, sound, vibration | Not measured yet | Needs the phone |
| Google Play Games saved games (T0.7) | A Godot 4 plugin exists ("Google Play Games Services for Godot", MIT, Asset Library). Needs Gradle builds (verified working), the Drive app-folder permission and Play Console set-up. Google is removing the old games v1 SDK in 2026, so the plugin's sign-in path must be checked first | **Workable but risky.** Keep as stretch item 3; drop to 1.1 at the first sign of trouble |

Seen while playing, to carry into phase 1:

- **Taps were swallowed by layout containers** until they were told to let input through. The real shell must set this deliberately.
- **The top of the board is crowded:** points 2, 3, 4 and 5 are close together, and the two starting tigers almost touch. Piece sizes and tap areas must be tuned on the real phone; a slightly larger board or a small zoom on the top area may be needed.
- **Empty space above and below the board** on tall screens. The real layout should give the board more of the height.

Still to do in the trial: T0.4 and the phone half of T0.5 (needs the test phone), the start-up/smoothness/sunlight checks, choosing the font, and listening to the sounds.

- **All pass, or only worries:** go. Note the worries as risks.
- **Web fails, Android passes:** go; release 1 ships Android plus the website without web play, and web play follows later.
- **Android size, start-up, smoothness or text fails:** stop. Revisit the stack with the user before spending more.

---

## 6. Phase 1 — rules, board, pass-and-play (weeks 2–3)

| # | Task | Done when |
|---|---|---|
| 1.1 | Project set-up: real project in `game/`, folder layout, project settings as in T0.1, gdUnit4 6.2.x as the test framework (the engine reference records 6.2.2 running headless on Godot 4.7.2, with its exact command and exit codes; install it from the editor's Asset Store, which replaced the Asset Library in 4.7), and a `tools/run_tests` script | One command runs an example test and reports pass or fail |
| 1.2 | Board data from the verified board: points with screen positions, connections, and the generated `NEIGHBOURS` and `JUMPS` tables. Also a printable numbered board image for the user | Tests confirm 23 points, the agreed connection count, and that every connection is two-way. User signs off the printout. |
| 1.3 | Rules: state, `initial_state`, `legal_moves`, `apply_move`, `result` | All rule tests in 1.4 pass |
| 1.4 | Rule tests (list below) plus a "golden games" file: complete games as move lists with the expected result | Tests pass from the command line; at least 10 golden games |
| 1.5 | Shell skeleton: start-up, home shelf with the Aadupuli card and a "coming next" card, mode picker, empty settings screen, back navigation, module loading through `GameDefinition` | From launch, two taps reach an empty game screen; the shell contains no Aadupuli-specific code |
| 1.6 | Board view: board and pieces drawn in code, tap to select and move, tap an empty point to place a goat, legal-move hints, slide and capture animations, sound and vibration hooks | A full game can be played by hand; illegal taps do nothing and give gentle feedback |
| 1.7 | Pass-and-play: choose sides or coin toss, turn banner, counters for goats in hand and goats captured, greyed-out repeat moves with a one-line reason, game-over screen, rematch | **Checkpoint A** |

### Rule tests required in 1.4

- Goats move first; goats place one per turn; goats cannot move until all 15 are placed.
- Tigers move one step along a line to an empty point, from their first turn.
- A tiger jumps one goat into the empty point directly beyond; the goat is removed and `captured` rises by one.
- No jumping a tiger, no jumping two goats, no jumping off a line, one jump per turn.
- Capturing is optional.
- Tigers win exactly when `captured` reaches `capture_target`.
- Goats win when no tiger has a legal move, including during placement.
- If goats have no legal move, tigers win.
- A move that would create the same full position for the third time is not in `legal_moves`.
- The 15-goat total always holds.
- Random play test: 2,000 random games all end, never crash and never break the 15-goat total.
- Saving and loading a state gives back an identical state.

### Checkpoint A

Two people can play a full, correct game on one phone, and the test suite is green. Check the date against the timeline.

---

## 7. Phase 2 — computer opponents (weeks 4–6)

| # | Task | Done when |
|---|---|---|
| 2.1 | Search: look-ahead with pruning, deepening one level at a time until the time budget runs out, captures tried first, a table of positions already examined. Runs off the main thread on Android; on web it works in small slices per frame *(Godot's web build runs single-threaded by default; verify)* | Returns a legal move within budget on the cheap phone; the screen never freezes |
| 2.2 | Position scoring, with all weights in one tunable resource: goats captured, goats that can be captured next turn, tiger freedom of movement, tigers already trapped, goats in hand, goats standing safely together | Beats a random player 99 times in 100 as either side |
| 2.3 | Three levels as data (table below), each with a name, portrait and a few lines in both languages | Each level feels clearly different to the user |
| 2.4 | `tools/self_play`: plays many computer-versus-computer games from the command line at capture targets 4, 5, 6 and 7 and writes a table of win rates and game lengths | Table produced from at least 500 games per target; user picks the target (D10) |
| 2.5 | Versus-computer mode: choose side or coin toss, thinking indicator, undo (takes back your move and the reply), resign | **Checkpoint B** |

### Level design

| Level | Look-ahead | Deliberate mistakes | Thinking time shown |
|---|---|---|---|
| Easy | 1–2 moves | Picks a weaker move about 1 time in 3; never misses an immediate win | about 0.6 s |
| Medium | 3–4 moves | Picks the second-best move about 1 time in 10 | about 0.8 s |
| Hard | As deep as 1–1.5 s allows | None | 1–1.5 s |

Numbers are starting points to tune by playing. The hard level is strong but not proven perfect (see DISCUSSION.md section 17).

### Also measure in 2.4

Average game length in moves and in minutes. The research warning was that Aadupuli can feel slow. If hard-versus-hard games regularly pass about 80 moves, raise it with the user before phase 3.

### Checkpoint B

All three levels are playable as either side on the cheap phone, and the capture target is chosen from data.

---

## 8. Phase 3 — tutorial, first run, text (weeks 7–8)

| # | Task | Done when |
|---|---|---|
| 3.1 | Tutorial engine in `shared/`, driven entirely by a data file: set a position, highlight targets, show one line, wait for the right move, advance | A two-step dummy tutorial runs from data alone |
| 3.2 | Aadupuli tutorial, five steps: place a goat; move a tiger; jump a goat; move a goat once all are placed; trap the last tiger. Skippable, replayable from the menu | A newcomer finishes it in under 90 seconds |
| 3.3 | One-screen rules summary and a short story page (history, regional names) | Both fit without scrolling on a small phone, in both languages |
| 3.4 | Text system: one translation file (English only at launch, ready for more), bundled fonts, layouts that survive longer words in other languages | Every screen correct; no clipped text, tested with a deliberately long dummy language |
| 3.5 | First-run flow: "How to play" card → offer tutorial → first game against Easy, playing tigers | A fresh install reaches a first move in under two minutes |
| 3.6 | Usability test, run by the user: five people who have never seen the game, watched silently | **Checkpoint C** |

### Checkpoint C

Five first-timers each finish a game with no help. Every point where one hesitated is written down and either fixed or consciously left.

---

## 9. Phase 4 — daily puzzle (weeks 9–10)

| # | Task | Done when |
|---|---|---|
| 4.1 | Puzzle format: position, side to move, goal ("tigers: capture a goat in N moves" or "goats: trap a tiger in N moves"), solution line, difficulty 1–5 | Format documented in the data file header and loadable |
| 4.2 | `tools/make_puzzles`: collect positions from self-play games, prove a forced win within N by full search, keep those with a single correct first move, grade difficulty by depth and number of tempting wrong moves | At least 120 proven puzzles spread across difficulties |
| 4.3 | Puzzle screen: the player moves, the computer answers with the best defence, tries are counted, solved or failed result | A puzzle can be solved and failed correctly |
| 4.4 | Daily choice and streak: puzzle picked by calendar date from the bundled list (easier early in the week), works offline, streak counted on the phone's local date | Changing the phone's date moves to the right puzzle; streak rises and resets correctly |
| 4.5 | Sharing: a short text result with a link to the website, through the Android share sheet and the browser's share feature | **Checkpoint D** |

Example share text:

```text
Tiger & Goat · Daily #42
Solved in 2 tries · 5-day streak
https://<site>/daily
```

### Checkpoint D

120 proven puzzles are bundled, the streak works, and a shared result opens the website. If the generator cannot find 120 good puzzles, ship with fewer and loop them; do not hand-write unproven ones.

---

## 10. Phase 5 — polish, website, stretch (weeks 11–12)

| # | Task | Done when |
|---|---|---|
| 5.1 | Visual identity pass: one palette, one type family, one piece style, all held in a single theme resource so later themes are a data swap. Direction is decided: brass-and-wood board on a light app (DISCUSSION.md section 22). The trial week and phase 1 already use the starting palette, so this pass is tuning, not invention. | Every screen uses the theme; nothing looks like a default control |
| 5.2 | Sounds: place, move, capture, trap, win, lose, button, puzzle solved. Free-licence or self-recorded, with sources listed in `CREDITS.md` | All eight present, balanced in volume, and can be switched off |
| 5.3 | Stats screen and the full save system from section 3 | Stats survive closing the app; an older save file still loads |
| 5.4 | Settings and comfort: sound, vibration, language, reduced motion; tigers and goats distinct by shape, not only colour; every tap target comfortably finger-sized | User passes a one-handed test on the cheap phone |
| 5.5 | Website in `site/`: home, rules, daily page, privacy policy, Play page with the web build if the trial allowed it; preview tags so shared links show a picture | Site live on free static hosting; pages load fast on mobile data |
| 5.6 | Stretch items, strictly in this order, stopping when week 12 ends | Feature freeze at the end of week 12 |

### Stretch order (from DISCUSSION.md section 18)

1. Opponent ladder: each opponent "cleared" by beating them as tigers and as goats.
2. One unlockable board theme: Heirloom, the brass-and-wood look (proposal: earned by a 7-day puzzle streak).
3. Google sign-in backup through Play Games saved games, Android only.
4. Replay with one hint after a loss.

Whatever is unfinished at the freeze moves to a 1.1 update. No exceptions.

### Rule for AI-assisted art

Board and pieces are drawn in code. AI-generated images are used only for backgrounds, story illustrations and store pictures, and every one is redrawn or corrected to the palette and style from 5.1 before it ships. Confirm the generating tool's licence allows commercial use.

---

## 11. Phases 6 and 7 — closed test and release (weeks 13–16)

| # | Task | Done when |
|---|---|---|
| 6.1 | Release build: permanent app identifier from the brand name, release signing key created, version numbers, app bundle export, current target Android level *(verify Play's requirement)* | A signed bundle uploads to Play Console without errors |
| 6.2 | **Back up the signing key and its passwords in two separate places** | User confirms both copies exist |
| 6.3 | Store listing in English: title "Tiger & Goat", short and full description, screenshots, feature picture | Listing complete in Play Console |
| 6.4 | Store forms: data safety (nothing collected), content rating questionnaire, audience set to 13 and over, privacy policy link | All forms accepted |
| 6.5 | Closed test: 12 or more testers opted in for 14 days in a row; a simple feedback form; fixes in order of crashes, rule errors, confusion | 14 days reached with 12 or more still opted in |
| 6.6 | Apply for public release, describing the test and what changed because of it | Google grants production access |
| 7.1 | Buffer week: only fixes | No known crash or rule error |
| 7.2 | Release to a fraction of users first, then everyone | **Release 1 is public** |
| 7.3 | After release: reply to every review; write the 1.1 list | First week of reviews answered |

### Release 1 is done when

| Measure | Bar |
|---|---|
| Automated rule tests | All pass |
| Crashes in the closed test | None unresolved |
| Fresh install to first move | Under two minutes |
| Start-up on the cheap phone | Under 3 seconds (or the figure agreed after the trial) |
| Text | Every screen correct in English; no hard-coded text |
| Offline | Everything except sharing works in aeroplane mode |
| Data | Nothing leaves the phone except what the player shares |

---

## 12. Decisions you owe, and when

| Decision | Needed by | Blocks |
|---|---|---|
| Board connections (P7) | Done 2026-11-16 | — |
| Tiger start points (top point plus 3 and 4) | Done 2026-11-16 | — |
| Go or no-go on Godot | End of week 1 | Everything |
| Capture target (4, 5, 6 or 7) from the self-play table | End of week 6 | Tutorial wording, puzzles |
| Names and personalities of the three opponents | Week 5 | Task 2.3 |
| Palette and piece style direction | Done 2026-11-25 ("Hill and meadow", DISCUSSION.md section 24; replaced brass and wood from 2026-11-16) | — |
| Font choice from the trial comparison | End of week 1 | Every screen |
| **Platform brand name** (Tiger & Goat is the game's name, D44) | **Week 11** | The permanent app identifier, the website address |
| Which stretch items made it | End of week 12 | Store description |

---

## 13. Risks

| Risk | Likelihood | Effect | Response |
|---|---|---|---|
| The board connections are wrong | Low (verified against your picture 2026-11-16) | Every rule, puzzle and opponent is wrong | Board kept as data, not code; a test checks the 23 points and 38 connections |
| Godot fails the trial on cheap phones or the web | Low to medium | Stack change | The trial exists for this; only a week is lost |
| The opponent is too slow in GDScript | Medium | Weak hard level | Time budget, integer state, position table; accept a shallower hard level before considering native code |
| Too few good puzzles can be generated | Medium | Daily puzzle repeats early | Ship fewer and loop; widen goals (two-move and three-move); never ship unproven puzzles |
| The game feels slow, as the research warned | Medium | Poor retention | Measured in 2.4; levers are capture target, animation speed and the puzzle mode |
| Text renders badly on some phones | Low | Looks broken | Bundled fonts, not the phone's; checked in the trial |
| Fewer than 12 testers stay opted in for 14 days | Medium | Release slips by weeks | Recruit 15–18 from week 0; remind them weekly |
| Scope creep | High | Missed date | Fixed stretch order; feature freeze at week 12 |
| Burnout | Medium | Project stalls | One full day off a week; every fourth week light |
| Signing key lost | Low | Cannot update the app | Task 6.2, two backups |
| Brand name not chosen by week 11 | Medium | Closed test delayed | It is in the decisions table with a date |

---

## 14. Progress tracker

### Week 0 (you)

- [x] P1 Godot installed, version noted (4.7.2, 2026-11-16; see docs/SETUP.md)
- [ ] P2 First-game tutorial done
- [x] P3 Android build tools installed (2026-11-16; test APK and web build exported successfully)
- [x] P4 Git and GitHub repository (2026-11-16; public by your choice, connected and pushed)
- [ ] P5 Cheap test phone ready
- [ ] P6 20–30 paper games played
- [x] P7 Board and tiger start points verified and signed off (2026-11-16)
- [ ] P8 Competitor app played
- [ ] P9 Play developer account open
- [ ] P10 Testers being recruited

### Phase 0 — trial

- [x] T0.1 Project (2026-11-19, `trial/`)
- [x] T0.2 Board and moving pieces (2026-11-19; playable pass-and-play)
- [ ] T0.3 Fonts, sound, vibration (built 2026-11-19; fonts changed to Fredoka and Figtree 2026-11-25; sound and vibration need you and the phone)
- [ ] T0.4 Android on the cheap phone (APK built: `trial/build/android/trial.apk`)
- [ ] T0.5 Web in the phone's browser (web build works on the laptop)
- [ ] T0.6 Look-ahead timing (laptop done; phone still to measure with "Think 1 s")
- [x] T0.7 Saved-games plugin finding (workable but risky; see trial results)
- [ ] **Go or no-go recorded**

### Phase 1 — rules, board, pass-and-play

- [x] 1.1 Project set-up and test runner (2026-11-26: `game/`, gdUnit4 6.2.2, `tools/run_tests.sh`)
- [x] 1.2 Board data (2026-11-26; verified against your picture earlier, printout skipped)
- [x] 1.3 Rules (2026-11-26, including the no-repeat rule and save/load)
- [ ] 1.4 Rule tests and golden games (22 rule tests pass; the 10 golden games file is still to do)
- [x] 1.5 Shell (2026-11-26: four tabs, home, game page, play, result, daily, friends, profile, settings; see DISCUSSION.md section 25)
- [x] 1.6 Board view (Hill and meadow, from the trial)
- [x] 1.7 Pass-and-play — **Checkpoint A** reached in the browser and in tests (2026-11-26); still to confirm on a phone

### Phase 2 — computer opponents

- [x] 2.1 Search (2026-11-26: position table, move ordering, worker thread on phones, short cap in browsers)
- [x] 2.2 Position scoring (captures, tiger freedom, threatened goats, trapped tigers, goat links, moves without a capture)
- [x] 2.3 Three levels (easy 2 deep with slips, medium 4 deep, hard as deep as 1.2 s allows)
- [x] 2.4 Self-play table; capture target chosen (5 kept; 40-move rule added; DISCUSSION.md section 28)
- [ ] 2.5 Versus-computer mode — **Checkpoint B** (screen, levels, thinking indicator and undo built with an interim opponent 2026-11-26; real opponent work 2.1–2.4 still to do)

### Phase 3 — tutorial, first run, text

- [x] 3.1 Tutorial engine (2026-11-27: lessons are data; the board can limit moves and spotlight points)
- [x] 3.2 Aadupuli tutorial (5 lessons: place, step, capture, goats move, trap; ends in a first game vs Easy as tigers)
- [ ] 3.3 Rules summary and story
- [ ] 3.4 Text system
- [ ] 3.5 First-run flow
- [ ] 3.6 Five first-timers — **Checkpoint C**

### Phase 4 — daily puzzle

- [x] 4.1 Puzzle format (2026-11-27: goals capture / safe / trap, with n moves, difficulty and answer)
- [x] 4.2 Puzzle generator, 194 puzzles (every one proven: forced solution, exactly one correct first move)
- [x] 4.3 Puzzle screen (toughest computer defence, tries, wrong-move explanations, Show answer)
- [x] 4.4 Daily choice and streak (same puzzle for everyone by date, easier early in the week, works offline)
- [x] 4.5 Sharing — **Checkpoint D** (Copy result to paste in WhatsApp; a link waits for the website)

### Phase 5 — polish, website, stretch

- [ ] 5.1 Visual identity
- [x] 5.2 Sounds (2026-11-27: eight sounds, all generated by `tools/make_sounds.py`: place, move, capture, win, lose, select, solved, nope)
- [ ] 5.3 Stats and saving
- [ ] 5.4 Settings and comfort
- [ ] 5.5 Website
- [ ] Stretch 1 Opponent ladder
- [ ] Stretch 2 One board theme
- [ ] Stretch 3 Sign-in backup
- [ ] Stretch 4 Replay with hint
- [ ] **Feature freeze**

### Game 2 — Mancala (Kalah) and Pallanguzhi

- [x] G2.1 Rules (2026-11-27: one sowing core, `games/sowing/sowing_rules.gd`; 14 rule tests; self-play check in DISCUSSION.md section 29)
- [x] G2.2 Board and seed animation (2026-11-27: `games/sowing/board/sowing_board_view.gd`; 11 board tests; pictures in `docs/game2/`)
- [x] G2.3 Computer opponent (2026-11-27: `games/sowing/ai/sowing_opponent.gd`, easy/medium/hard; ladder in DISCUSSION.md section 29)
- [x] G2.3b Pallanguzhi rule fix (2026-11-27: pasu goes to the pit's owner, D63 revised; no forced win, ladder clean)
- [x] G2.4 In the app (2026-11-27: home cards, game page with rules card, play vs computer or pass and play, result popup, per-game records; online shows Soon)
- [x] G2.5a Tutorial (2026-11-27: four lessons per game, offered once on first play, leads into a first game vs Easy)
- [x] G2.5b Puzzles (2026-11-27: 110 proven puzzles per game, Puzzles card on each game page, progress saved)
- [x] G2.6 Online (2026-11-27: rooms and quick match carry the game; first/second sides swap on rematch; chat picker shared by all games; checked live)

### Game 3 — Bagh-Chal

- [x] G3.0 Rules researched and decided (2026-11-27: DISCUSSION.md section 30, D65–D67)
- [x] G3.1 Engine takes the board as data; Bagh-Chal rules and tests (2026-11-27: 11 rule tests, every Tiger & Goat test still passes; self-play in DISCUSSION.md section 30)
- [x] G3.2 Board drawing (2026-11-27: Himalayan touch; pictures in `docs/game3/`, made by `tools/shot_tiger.tscn`)
- [x] G3.3 Computer opponent and balance check (2026-11-27: Bagh-Chal scoring and levels; ladder by `tools/tiger_ladder.gd`; results in DISCUSSION.md section 30)
- [x] G3.4 In the app (2026-11-27: home card, game page, play, result, own record; online, lessons and puzzles hidden until built)
- [x] G3.5 Online (2026-11-27: lobby game "baghchal", online card on the page, rooms and quick match with sides, rematch, own record)
- [x] G3.6 Lessons (2026-11-27: five on the real board, incl. guarding a goat; from the page, rules card and a one-time offer on first play)
- [x] G3.7 Puzzles (2026-11-27: 130 proven puzzles of four kinds, Puzzles card on the page, solved ones remembered)

### Game 4 — Four in a Row

- [x] G4.0 Rules and look decided (2026-11-27: DISCUSSION.md section 31, D68–D71)
- [x] G4.1 Grid engine and Four in a Row rules (2026-11-27: `games/grid/grid.gd`, `games/fourinrow/four_rules.gd` with bitboards; 14 tests: wins in every direction, draw, full columns, no wrap between columns, save and load, random games)
- [x] G4.2 Board drawing (2026-11-27: wooden stand in the meadow, orange and cream discs, drop with a bounce, winning four highlighted; pictures in `docs/game4/`, made by `tools/shot_four.tscn`; 8 board tests)
- [x] G4.3 Computer opponent (2026-11-27: bitboard search, wins/blocks/never under a threat; Easy, Medium, Hard; ladder by `tools/four_ladder.gd`, results in DISCUSSION.md section 31)
- [x] G4.4 In the app (2026-11-27: home card, game page with First / Second / Coin toss, play vs computer or pass and play, result, record by seat on the profile; online, lessons and puzzles hidden until built)
- [x] G4.5 Online (2026-11-27: lobby game "fourinrow" with first/second seats, seat choice in quick match and rooms, rematch swaps who moves first, checked live)
- [x] G4.6 Lessons (2026-11-28: four on the real frame: drop, four wins, block, diagonals; from the page, rules card and a one-time offer on first play)
- [x] G4.7 Puzzles (2026-11-28: 130 proven puzzles of four kinds, checked again by a plain solver; Puzzles card on the page, solved ones remembered)

### Game 5 — Reversi

- [x] G5.0 Rules and look decided (2026-11-28: DISCUSSION.md section 32, D72–D75)
- [x] G5.1 Reversi rules (2026-11-28: `games/reversi/reversi_rules.gd` on masked 64-bit bitboards; 10 tests incl. a cross-check against plain rules in 1,500+ positions)
- [x] G5.2 Board drawing (2026-11-28: `games/reversi/board/reversi_board_view.gd` and a preview; discs turn over one after another along each line; pictures in `docs/game5/`; 10 board tests)
- [x] G5.3 Computer opponent (2026-11-28: `games/reversi/ai/reversi_opponent.gd`, search on hand-unrolled bitboards; ladder: Medium beat Easy 40/40, Hard beat Medium 30/40; 7 tests)
- [x] G5.4 In the app (2026-11-28: home card, game page with First / Second / Coin toss, play screen with live disc counts and automatic passes, result, record by seat on the Profile; 8 tests; checked in the browser)
- [x] G5.5 Online (2026-11-28: lobby game "reversi", seat choice, the server passes at once for a player with no move, rematch swaps who starts; 4 lobby tests and 2 screen tests with the real server)
- [x] G5.6 Lessons (2026-11-28: five lessons on the real tray, offered once on first play, from the page and the rules card; 6 tests)
- [x] G5.7 Puzzles (2026-11-28: 130 proven puzzles, make them pass and endings of 4 to 12 empty squares played to the end; Puzzles card on the page; 6 tests incl. a plain-rules cross-check)

### Phases 6 and 7 — closed test and release

- [ ] 6.1 Release build
- [ ] 6.2 Signing key backed up twice
- [ ] 6.3 Store listing
- [ ] 6.4 Store forms
- [ ] 6.5 14-day closed test
- [ ] 6.6 Production access
- [ ] 7.1 Buffer week
- [ ] 7.2 **Release 1 public**
- [ ] 7.3 Reviews answered, 1.1 list written

---

## 15. Session log

Add one line per working session: date, task, result, anything the next session must know.

| Date | Task | Result | Notes |
|---|---|---|---|
| 2026-11-16 | Plan written | — | Godot version not yet pinned; board not yet verified |
| 2026-11-16 | Board verified | Matches the draft exactly | Picture saved at docs/board-reference.png |
| 2026-11-16 | Tiger start confirmed | Points 0, 3 and 4 | Nothing about the board is open now |
| 2026-11-28 | Game 5 puzzles | Exact end-of-game proofs on bitboards; generator (400 games, 134 s); 130 puzzles: make them pass 25, endings 4–6 30, 7–8 30, 9–10 25, 11–12 20; puzzle screen plays endings to the last disc; 6 tests, 268 pass; checked in the browser | Reversi complete; game 6 next |
| 2026-11-28 | Game 5 lessons | Five Reversi lessons (flip, line, eight directions, corner, pass) with a lesson screen, Learn card, first-play offer and rules-card button; 6 tests, 262 pass; checked in the browser | G5.7 puzzles next |
| 2026-11-28 | Game 5 online | Reversi in the lobby (moves checked, automatic passes, ends on the disc count); online card, seat chips, waiting screen, online play and result with rematch; 4 lobby tests, 2 screen tests on the real server, 256 pass | G5.6 lessons next |
| 2026-11-28 | Game 5 in the app | Reversi home card, game page, play screen (disc counts, passes explained, undo, computer on a thread), result screen, Profile record; 8 app tests, 250 pass; checked in the browser | G5.5 online next |
| 2026-11-28 | Game 5 computer | Negamax on bitboards, 60k–100k positions a second; Easy naive (disc count), Medium 4 ahead + perfect last 8, Hard 5 ahead + perfect last 10; ladder 40 games: Easy vs greedy 16–21–3, Medium beat Easy 40/40, Hard beat Medium 30/40; 7 tests, 242 pass | G5.4 in the app next |
| 2026-11-28 | Game 5 board | Wooden tray in the meadow, grass squares, discs that settle and turn over along each line, glowing dots for legal moves, last move ringed; preview; 4 pictures; 10 board tests, 235 pass | G5.3 computer next |
| 2026-11-28 | Game 5 rules | Reversi rules on bitboards (masked shifts for the sign bit and edges), passing, game end; 10 rule tests, 225 pass; 2,000 random games: first 45%, second 51%, draws 4%, about 11,000 positions a second | G5.2 board drawing next (pictures first) |
| 2026-11-28 | Game 5 planned | Reversi chosen; rules, first-move choice, look and hints decided (D72–D75); G5.1–G5.7 planned | G5.1 rules next |
| 2026-11-28 | Game 4 puzzles | Puzzle proofs on bitboards; generator (600 games, 75 s); 130 puzzles: make four now 25, saves 45, win in 2 35, win in 3 25; puzzle screen and page card; 6 tests incl. a plain-solver cross-check, 215 pass; checked in the browser | Four in a Row complete; game 5 next |
| 2026-11-28 | Game 4 lessons | Four Four in a Row lessons and their screen; Learn to play card, rules-card button and first-play offer; first game vs Easy moving first; 6 tests, 209 pass; played through in the browser at phone size | G4.7 puzzles next |
| 2026-11-27 | Game 4 online | Lobby plays "fourinrow" (seats first/second, results four or full); online card on the page; seat chips on the online screen; waiting screen routes to the Four in a Row play screen; 5 lobby tests and 1 screen test against the real server, 203 pass; checked live against a scripted player | G4.6 lessons next |
| 2026-11-27 | Game 4 in the app | Four in a Row home card, game page (first/second/coin toss), play and result screens, record by seat on the profile; rules card without tutorial until G4.6; 7 app tests, 197 pass; played against the computer in the browser at phone size | G4.5 online next |
| 2026-11-27 | Game 4 computer | Four in a Row search on bitboards with threat spaces, levels Easy/Medium/Hard; ladder: Medium beat Easy 38/40, Hard beat Medium 17/20; 9 opponent tests, 190 pass | G4.4 in the app next |
| 2026-11-27 | Game 4 board | Four in a Row board view and preview: wooden stand on feet in the meadow, orange and cream discs, falling disc with a bounce, landing hints, winning line; 8 board tests, 181 pass; pictures for approval | G4.3 computer opponent next |
| 2026-11-27 | Game 4 rules | Grid geometry (69 lines of four on 7 × 6); Four in a Row rules on bitboards; 14 rule tests, 173 pass; 5,000 random games: first player 56%, about 75,000 positions a second | G4.2 board drawing next (pictures first) |
| 2026-11-27 | Game 4 planned | Four in a Row chosen; rules, first-move choice, look and Hard level decided (D68–D71); G4.1–G4.7 planned | G4.1 grid engine and rules next |
| 2026-11-27 | Game 3 puzzles | Puzzle generator takes --board; 130 proven Bagh-Chal puzzles (safe 40, capture in 2 40, trap in 1 25, trap in 2 25); Puzzles card on the page, puzzle screen per board, solved remembered; 4 tests, 159 pass; checked in the browser at phone size | Bagh-Chal complete; game 4 next |
| 2026-11-27 | Game 3 lessons | Five Bagh-Chal lessons on the shared tutorial screen; Learn to play card, rules-card button and first-play offer; fixed pieces landing off their point when the board resizes mid-move; 6 tests, 155 pass; played through in the browser at phone size | Puzzles next (G3.7) |
| 2026-11-27 | Game 3 online | Lobby plays "baghchal" on the tiger rules; online card on the Bagh-Chal page; online and waiting screens route tiger games by board; online results on Bagh-Chal's record; 4 lobby tests and 1 screen test against the real server, 149 pass; checked in the browser against a second player | Lessons, puzzles next (G3.6–G3.7) |
| 2026-11-27 | Game 3 in the app | Bagh-Chal home card; Tiger & Goat page, play and result screens take the board; Bagh-Chal rules card and record (by side) on the profile; 4 app tests, 144 pass; checked in the browser at phone size | Online, lessons, puzzles next (G3.5–G3.7) |
| 2026-11-27 | Game 3 computer | Bagh-Chal opponent: captures checked past the horizon, look-ahead always ends with tigers to move, goats look one move further, edge and double-threat scoring; Tiger & Goat unchanged; level ladder tool; 6 opponent tests, 140 pass | Hard vs hard leans tigers (70%); app, online, lessons, puzzles next (G3.4) |
| 2026-11-27 | Game 3 board | Tiger board view draws any board; Bagh-Chal scene with snowy peaks, prayer flags and a square plateau; Tiger & Goat unchanged; 4 board tests, 134 pass | Not playable in the app yet (G3.4); goat play next (G3.3) |
| 2026-11-27 | Game 3 rules | Tiger engine takes the board as data (Tiger & Goat, Bagh-Chal); Bagh-Chal 5x5 board, 4 corner tigers, 20 goats, traditional no-repeat; 11 new tests, 130 pass; self-play: every game ends, tigers lead (100% at 3-move look-ahead, 65–75% deeper) | The computer's goat play needs Bagh-Chal scoring (G3.3); board drawing next (G3.2) |
| 2026-11-27 | Game 2 puzzles | 220 proven puzzles (most seeds this turn, win in 1, win in 2) generated in seconds by `tools/make_sowing_puzzles.gd`; puzzle screen with tries, Show answer and reasons; progress per game; checked in the browser; 119 tests pass | **Game 2 is complete.** Daily tab stays Tiger & Goat for now; a rotating daily is a later decision |
| 2026-11-27 | Game 2 lessons | Four hands-on lessons each for Mancala and Pallanguzhi (sow, go again or relay, capture or pasu, the end); Learn to play card, Try the tutorial on the rules card, one-time offer on first play; checked in the browser; 115 tests pass | Puzzles for the seed games (G2.5b) still to do; lesson timing to check with real first-timers |
| 2026-11-27 | Game 2 online | Server rooms and quick match know their game (old apps get Tiger & Goat); seed games online with timer, chat, resign, reconnect, rematch that swaps who starts; chat picker moved to shared code; checked live against a scripted player; 111 tests pass | Still to do for game 2: tutorial and puzzles (G2.5). Restart the game server after pulling (the running one must have the new lobby) |
| 2026-11-27 | Game 2 in the app | Both games playable: home cards, game page, play screen with panels and hints, result popup (shared base with Tiger & Goat), records and profile card; first player alternates per game; tried in the browser; 104 tests pass | Online (G2.6) and tutorial/puzzles (G2.5) still to do; timing in the browser pane was throttled, so feel needs checking on the phone |
| 2026-11-27 | Pallanguzhi pasu fix | Pasu now goes to the pit's owner (D63 revised); hard searches 9 deep, ladder clean, hard vs hard close (11 of 24 drawn); 98 tests pass | Next: put both games in the app (G2.4) |
| 2026-11-27 | Game 2 computer | Search opponent with three levels; Kalah ladder clean (each level beats the one below); found Pallanguzhi as ruled is a 7-move forced win for the first player; compared 7 variants; pasu-to-owner option added to the rules; 98 tests pass | Pallanguzhi pasu rule needs a decision before the app step |
| 2026-11-27 | Game 2 board | Wooden tray on the meadow, pebble seeds with count chips, Kalah stores or Pallanguzhi piles, one-tap moves, seeds animated one drop at a time with a new pebble sound, tap to skip; 92 tests pass | Not playable in the app yet (G2.4); pictures in docs/game2/, made by `tools/shot_sowing.tscn` |
| 2026-11-27 | Game 2 rules | Kalah and Pallanguzhi share one sowing core that records every step for animation; 14 new tests, 81 pass; 1,000-game self-play: all games end, first player has a clear edge (greedy: Kalah 58–32, Pallanguzhi 84–12) | First player must alternate in both games; next is the board and seed animation |
| 2026-11-27 | Polish pass 1 | Eight sounds; last-move trail on the board; meadow fills the full width; pick-up bounce; "nowhere to go" hint for stuck pieces; meadow-green start screen; 67 tests pass | Still to polish: visual identity review (5.1), stats/saving review (5.3), comfort checks on a real phone (5.4), website (5.5) |
| 2026-11-27 | Daily puzzle | 194 proven puzzles from 300 self-play games; Daily tab with today's puzzle, streak, best, practice; home card shows today's number; 64 tests pass | Puzzle #1 date is 2026-11-01 for now; reset to the launch date before release. Sharing copies text only until the website exists |
| 2026-11-27 | Tutorial | Five hands-on lessons; welcome card on first launch; Learn to play card on the game page, How to play card and Settings; fixed goats not placeable with Move hints off; 58 tests pass | First-timer timing (under 90 s) still to check with real people (Checkpoint C) |
| 2026-11-26 | Phase 2: computer opponent | New opponent with position table and background thinking; self-play tool (`game/tools/self_play.gd`); 5 captures kept; goats win after 40 tiger moves without a capture; summit spacing; 53 tests pass | Checkpoint B still needs the phone (levels feel, speed) |
| 2026-11-26 | End-of-game popup | Result now pops up over the board (confetti on a win) instead of a separate page; shown the moment the game ends and fades in after the last move; pieces no longer draw over it; 2 new tests (44 pass) | The browser pane was too laggy to replay the manual win reliably; the automated in-browser win showed the popup |
| 2026-11-26 | Online play (pulled forward, D54) | Server (`game/server/`, `tools/run_server.sh`), rooms with codes, quick match, server-checked moves, 45 s turns, chat faces and phrases, reconnect, rematch; 16 new tests including real-WebSocket end-to-end and app-screen tests; 42 tests pass; played live in the browser against a second connection | Server runs on this computer only; internet hosting, report/block and server restarts still to do |
| 2026-11-26 | Phase 1 started in `game/` | Rules with 22 tests, app shell with all screens, interim computer opponent, app walk-through test; all 26 tests pass; web and Android builds work | Remaining in phase 1: golden games file; phone checks. Phone server is now `app-web-phone` on port 8061 |
| 2026-11-25 | Trial redesign | Tiger & Goat, English only, Plato-like screen, "Hill and meadow" look | Decisions D40–D45 in DISCUSSION.md sections 23–24 |
| 2026-11-19 | Trial T0.1–T0.3, T0.6, T0.7 | Playable board in brass and wood; exports work; look-ahead 6 moves in 1 s on the laptop's browser | Phone checks outstanding. Run the web build with the `trial-web` preview (`.claude/launch.json`) |
| 2026-11-16 | Design direction | Brass-and-wood board, light app, shapes plus colour, kolam decoration | Starting palette in DISCUSSION.md section 22 |
| 2026-11-16 | Tools set up | Godot 4.7.2, JDK 17, Android SDK (API 35 and 36, NDK r28b), Android Studio, GitHub CLI; local Git repository | Empty test app: Android 27 MB, web 9.8 MB compressed. Android size will be near the trial's limit. Details in docs/SETUP.md |
