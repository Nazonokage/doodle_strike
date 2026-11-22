# Doodle Strike – Skills Directory

Which skills to load for this project, where they live in your `Skills` folder, and what to install.
Paths come from your `tree` output. **Assumed root:** `D:\projects\Skills\frontend\` (the folder you ran `tree` in). Adjust `ROOT` if your layout differs.

```
ROOT = D:\projects\Skills\frontend
```

Rule of thumb: every loaded skill costs context. Load Tier 1 always, Tier 2 when the task matches, and leave the rest out.

---

## Tier 1 – Always load

| Skill | Path | Why |
|---|---|---|
| **doodle-strike** (our custom skill) | `ROOT\doodle-strike\` (new, copy the folder here) | Encodes the locked decisions, rules, and playbooks |
| flutter-best-practices | `ROOT\flutter-ai-rules\skills\flutter-best-practices\` | General Flutter conventions |
| effective-dart | `ROOT\flutter-ai-rules\skills\effective-dart\` | Dart style, matters for the pure-Dart sim |
| dart-3-updates | `ROOT\flutter-ai-rules\skills\dart-3-updates\` | Modern Dart features (records, patterns, sealed classes for messages) |
| testing | `ROOT\flutter-ai-rules\skills\testing\` | Test structure for sim, protocol, widgets |

## Tier 2 – Load when the task matches

| Task | Skill | Path |
|---|---|---|
| UI state in menus/lobby | riverpod | `ROOT\flutter-ai-rules\skills\riverpod\` |
| Mocking in tests | mocktail | `ROOT\flutter-ai-rules\skills\mocktail\` |
| Runtime/analyzer errors | flutter-errors | `ROOT\flutter-ai-rules\skills\flutter-errors\` |
| App structure questions | flutter-app-architecture | `ROOT\flutter-ai-rules\skills\flutter-app-architecture\` |
| Code review passes | code-review | `ROOT\flutter-ai-rules\skills\code-review\` |
| Menu/HUD accessibility | accessibility, inclusive-design | `ROOT\flutter-ai-rules\skills\accessibility\`, `...\inclusive-design\` |
| Menu/lobby look and feel | no-ai-design-slop | `ROOT\MengTo\agent-skills\ui\no-ai-design-slop\` |
| Menu/UI motion principles (easing, durations) | animate, review-animations | `ROOT\emilkowalski\skills\animate\`, `...\review-animations\` |

Notes:
- The Emil Kowalski animation skills are web/CSS oriented. Use them for the principles (ease-out for entrances, keep UI motion short, respect reduced motion), not for the code they output.
- `architecture-feature-first` in flutter-ai-rules conflicts with our `sim`/`protocol`/`app` split. Skip it, or treat it as UI-layer guidance only.

## Tier 3 – Design reference only (Three.js oriented)

These are checklists of ideas, already distilled into `doodle-strike\references\gameplay-feel.md`. Load the originals only if you want more depth.

| Skill | Path |
|---|---|
| design-action-combat | `ROOT\MengTo\agent-skills\game-development\design-action-combat\` |
| build-game-camera-controls | `ROOT\MengTo\agent-skills\game-development\build-game-camera-controls\` |
| build-game-audio-feedback | `ROOT\MengTo\agent-skills\game-development\build-game-audio-feedback\` |
| create-game-vfx | `ROOT\MengTo\agent-skills\game-development\create-game-vfx\` |
| author-game-levels | `ROOT\MengTo\agent-skills\game-development\author-game-levels\` (**its one-flat-plane rule does NOT apply to a jetpack game**) |
| design-game-encounters | `ROOT\MengTo\agent-skills\game-development\design-game-encounters\` |
| tune-enemy-ai | `ROOT\MengTo\agent-skills\game-development\tune-enemy-ai\` (useful for bots) |
| test-playable-web-games | `ROOT\MengTo\agent-skills\game-development\test-playable-web-games\` |
| build-game-map-editor | `ROOT\MengTo\agent-skills\game-development\build-game-map-editor\` (only if you build an in-game editor later) |

## Phase 4 only (do not load yet)

| Skill | Path |
|---|---|
| firebase-auth, firebase-cloud-firestore, firebase-cloud-functions, firebase-analytics, firebase-messaging, firebase-crashlytics, firebase-app-check, firebase-remote-config | `ROOT\flutter-ai-rules\skills\<name>\` |
| revenuecat-testing | `ROOT\flutter-ai-rules\skills\revenuecat-testing\` (only if monetization is decided) |

## Skip for this project

| Skill / folder | Reason |
|---|---|
| `three-agent-skills\` (r3f-best-practices, three-best-practices) | Wrong engine |
| `antrophic\skills\brand-guidelines` | Applies Anthropic's own brand colors and fonts, not yours |
| `antrophic\skills\canvas-design`, `algorithmic-art`, `slack-gif-creator`, `theme-factory`, `web-artifacts-builder`, `webapp-testing`, `frontend-design` | Web/art tooling, not relevant to a Flutter game |
| `antrophic\skills\docx`, `pdf`, `pptx`, `xlsx`, `doc-coauthoring`, `internal-comms` | Document tooling |
| `emilkowalski\skills\pick-ui-library`, `write-swift`, `animate-expo`, `ask-sonner` | Web/Swift/Expo specific |
| `flutter-flame-harness\` | Heavy "idea to store" pipeline; read `skills\flame-harness-plan` and `flame-harness-evaluator` for ideas only. It also assumes its own project structure, which conflicts with ours |
| `awesome-cursorrules\` | Overlaps flutter-ai-rules. If wanted, find the Flutter rule with: `dir ROOT\awesome-cursorrules\rules /s /b \| findstr /i flutter` |
| Firebase skills before Phase 4 | Not needed for local PvP |
| `MengTo\agent-skills\web-design\*` | Landing-page and WebGL visual styles |

## Keep (already useful for building skills)

| Skill | Path |
|---|---|
| skill-creator | `ROOT\antrophic\skills\skill-creator\` |

---

## Install commands (from Grok, with corrections)

Run these in a terminal. **I have not verified that these repos, flags, or commands work; test each one and read the output.**

```bash
# Flame skills: run inside your Flutter project after adding flame as a dependency
dart run skills get -p flame
```

```bash
# Official Flutter and Dart skills
npx skills add flutter/skills --skill '*' --agent universal
npx skills add dart-lang/skills --skill '*' --agent universal
```

Corrections to what you pasted:
- Use double dashes: `--skill` and `--agent`. A single `-` followed by a space (`- skill`) is almost certainly a formatting mistake, probably from copy/paste turning `--` into a dash.
- Grok's version also mentioned `--yes` to skip prompts. Add it only after you have seen what the command does interactively once.
- `dart run skills get -p flame` depends on a `skills` package and on Flame publishing skills; check the command's `--help` output first.

After installing, update the table above: note the real install paths, and remove anything that duplicates what `flutter-ai-rules` already gives you (the official Flutter skills may overlap with `flutter-best-practices`). If two skills give conflicting advice, keep one.

---

## Suggested load set per task

| Task | Load |
|---|---|
| Anything in `packages/sim` | doodle-strike, effective-dart, dart-3-updates, testing |
| Netcode | doodle-strike, effective-dart, testing |
| Flame rendering, camera, effects | doodle-strike, flutter-best-practices, official Flame skills |
| Menus, lobby, HUD | doodle-strike, flutter-best-practices, riverpod, no-ai-design-slop |
| Reviewing a change | doodle-strike, code-review |
