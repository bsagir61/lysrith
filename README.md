# LYSRITH: Silent Cartography

A fictional, abstract, serious map-based espionage and crisis-management
strategy game for Android, built with Godot 4.x and GDScript.

You direct the **Lysrith Directorate**, a fictional intelligence bureau.
Expose the hidden rival network (push **Rival Network Exposure** to 100)
before Global Exposure hits 100, Agency Trust hits 0, five regions collapse,
or the bureau goes insolvent.

Everything in the game is fictional and abstract: no real countries, flags,
borders, agencies, or real-world espionage methods. Operations are pure game
mechanics.

## Controls

- One-finger touch only. Portrait orientation.
- Tap a region node -> region dossier -> **Plan Operation** -> pick agent ->
  pick operation -> confirm -> read the debrief.
- Bottom bar: **Roster** (review agents), **Pass Turn** (rest), **Menu**.

## How to run

1. Install Godot 4.3+ (standard build, no mono needed).
2. Import the project folder (`project.godot`) in the Project Manager.
3. Run. Desktop mouse clicks emulate touch automatically.

## Android export notes

- Install Android Build Template / export templates for your Godot version.
- Project is portrait (1080x1920 design, `canvas_items` stretch, `expand`
  aspect) and scales to common phone resolutions.
- Renderer is `mobile`. No network permissions are needed (fully offline).
- Add your keystore in Export settings for Play upload; package name,
  icons (`art/icon.svg` as a base) and version codes are set there.
- Haptics use `Input.vibrate_handheld` (VIBRATE permission is added
  automatically by the exporter when used).

## Folder structure

```
data/                 regions.json, agents.json, operations.json, events.json
scenes/boot|menus|game/   minimal .tscn shells (UI is built in code via UITheme)
scripts/core/         GameState, TurnResolver, Balance, SaveManager, RandomService
scripts/data/         JSON loaders (RegionData, AgentData, OperationData, EventData)
scripts/managers/     SettingsManager, AudioManager, TutorialManager
scripts/map/          MapController, RegionNode, SignalLine (visuals only)
scripts/ui/           UITheme, UITransitions and all screen/panel scripts
art/                  icon.svg (all other visuals are procedural)
```

## Major systems

- **GameState** (autoload): single source of truth - resources, meters,
  16 regions, 6 agents, event history, difficulty, seed.
- **TurnResolver** (autoload): operation odds/outcomes, rival spread,
  upkeep, collapses, end conditions. All tuning lives in **Balance.gd**.
- **EventData**: 36 event cards with trigger conditions and 2-3 choices.
- **SaveManager**: auto-saves each turn to `user://lysrith_save.json`;
  Continue restores exact state. Settings persist via ConfigFile.
- **TutorialManager**: skippable 10-step first-run tutorial.
- **AudioManager**: all tones synthesized at runtime (no external assets).
- Map, portraits, panels: procedural vector-style drawing, one shared
  visual system (UITheme).

## Difficulty

Rookie Desk (forgiving), Standard Watch (default), Black Room (hard:
fewer resources, faster rival spread, harsher failures).

## Known limitations

- Audio is minimal synthesized tones plus a soft ambient loop.
- Single save slot.
- No localization (English only).

## Suggested next updates

- Region-specific hidden-tag gameplay bonuses.
- Agent injury/retirement arcs and roster management.
- Daily seeded challenge runs.
- Achievements and end-of-run scoring.
- Localization and cloud save.
