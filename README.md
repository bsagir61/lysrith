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
scripts/core/         Campaign state, resolver, balance and pure region strategy helpers
scripts/data/         JSON loaders (RegionData, AgentData, OperationData, EventData)
scripts/managers/     Settings, EN/TR localization, audio and tutorial flow
scripts/map/          MapController, RegionNode, SignalLine (visuals only)
scripts/ui/           UITheme, UITransitions and all screen/panel scripts
scripts/tests/        Headless strategic validation suite
art/                  icon.svg (all other visuals are procedural)
```

## Major systems

- **GameState** (autoload): single source of truth - resources, meters,
  16 regions, 6 agents, event history, difficulty, seed.
- **TurnResolver** (autoload): authoritative operation previews and outcomes,
  calculation breakdowns, rival spread, upkeep, collapses and turn outlook.
  Preview and resolution use the same cost, chance and Heat calculations.
- **RegionTagRules**: pure revealed-identity modifiers and Trade Hub income.
- **RegionAssessment**: runtime-only, intel-gated region priority labels and
  deterministic situation summaries.
- **StrategicAdvisor**: runtime-only advisory actions derived from information
  the player is allowed to know.
- **EventData**: 36 event cards with trigger conditions and 2-3 choices.
- **SaveManager**: auto-saves each turn to `user://lysrith_save.json`;
  Continue restores exact state. Settings persist via ConfigFile.
- **TutorialManager**: skippable first-run tutorial with contextual identity
  discovery guidance.
- **LocalizationManager**: centralized English and Turkish UI strings through
  `L10n.t(...)`; language selection persists in Settings.
- **AudioManager**: all tones synthesized at runtime (no external assets).
- Map, portraits, panels: procedural vector-style drawing, one shared
  visual system (UITheme).

## Strategic region loop

Regions begin with incomplete intelligence. **Map Signals** raises coverage,
while **Deep Analysis** reveals one of ten stable regional identities. A
revealed identity visibly modifies only its supported operations; unrevealed
identities have no effect and expose no preview clue. The dossier presents an
intel-gated assessment, situation summary, intelligence gaps and up to three
advisory options.

The campaign HUD prioritizes Rival Network Exposure and Global Exposure,
groups action resources into compact chips, and keeps turn/world context
quieter. Turn Outlook reports expected passive economy, Heat decay and
pressure without predicting random events. Operation planning shows final
odds, real costs, Heat, warnings and expandable calculation details. Debriefs
separate immediate effects, modifiers, economy, world response and changed
metrics.

Identity state remains stored through the existing `hidden_tag` and
`tag_revealed` fields. Assessments, recommendations, previews and Outlook are
derived at runtime, so existing save files require no migration.

## Difficulty

Rookie Desk (forgiving), Standard Watch (default), Black Room (hard:
fewer resources, faster rival spread, harsher failures).

## Known limitations

- Audio is minimal synthesized tones plus a soft ambient loop.
- Single save slot.
- Static interface and instructional text are localized in English and
  Turkish. Region/agent proper names and deep event JSON narrative remain in
  their original English content.

## Validation

Open the project in Godot and run the main scene for normal UI testing. The
headless strategic suite does not touch `SaveManager` or the player's save:

```powershell
Godot --headless --path . res://scripts/tests/StrategicValidation.tscn
```

The suite checks EN/TR key parity, all ten revealed identities, unrevealed-tag
isolation, trait interactions, preview/payment consistency, one-time discovery
reward, Trade Hub income rules, in-memory save compatibility and the core
region-to-debrief UI flow in both languages.

## Suggested next update

- Localize the event JSON narrative and choice text as one focused content
  pass, without changing event mechanics or balance.
