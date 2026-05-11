# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Indonesian-themed ghost-hunting Roblox game. 30 capturable ghost types, 6 mini-games, compendium, economy (shards/Robux), daily/weekly quests, tutorial, companion system.

Design specs live in **GDD.md** (gameplay) and **PRD.md** (technical). Task tracking in **TASKS.md**.

## Toolchain

| Tool | Purpose | Command |
|------|---------|---------|
| **Rojo** | Sync `src/` → Roblox Studio | `rojo serve` (live sync) · `rojo build -o game.rbxl` |
| **Wally** | Package manager | `wally install` (populates `Packages/` and `ServerPackages/`) |
| **Selene** | Luau linter | `selene src/` |

Tests (TestEZ) run inside Roblox Studio — there is no CLI test command.

## Rojo File→Instance Mapping

```
src/server/          → ServerScriptService.Server
src/client/          → StarterPlayerScripts.Client        (LocalScript = init.client.luau)
src/shared/          → ReplicatedStorage.Shared
src/assets/          → ReplicatedStorage.Assets
Packages/            → ReplicatedStorage.Packages
ServerPackages/      → ServerScriptService.ServerPackages
```

Require paths reflect this mapping exactly:
- **From server systems**: `require(ReplicatedStorage.Shared.X)`, `require(ServerScriptService.Server.systems.X)`
- **From client systems**: `require(ReplicatedStorage.Shared.X)`, `require(script.Parent.X)` (sibling within `systems/`)
- **From init.client.luau**: `script` IS the `Client` LocalScript folder, so use `script.systems.X`

## Language Rules

All `.luau` files use `--!strict`. Every local that is assigned but only used for side-effects must be suppressed with `_ = local` to silence the linter. Leading `;` before `(...)` statements prevents ambiguous parsing — use a local assignment instead inside anonymous functions passed to `pcall`/`safeInit`.

## Architecture

### Three Layers

```
Server systems (init.server.luau bootstraps in order):
  PlayerDataManager → WorldBuilder → GhostSpawnManager → GhostAI
  → EconomyManager → QuestManager → CaptureSession → TutorialManager
  → RequestViewCompendium handler

Client systems (init.client.luau bootstraps in order):
  LocalizationBridge → UIManager → [CharacterAdded:Wait()]
  → ZoneDetector → AudioController → HUD → CompendiumUI → ShopUI
  → MiniGameController → TutorialController → CompanionController
```

Every system exposes `System.Init()`. Bootstrap scripts call them in dependency order wrapped in `safeInit(name, fn)` which pcall-wraps and logs without crashing.

### Remotes

All RemoteEvents and RemoteFunctions are declared in `src/shared/Remotes.luau`. Server creates them on first require; client waits for them. Never scatter `WaitForChild` calls — always go through `Remotes["Name"]`.

### Player Data

`PlayerDataManager` wraps ProfileService. Pattern everywhere:
```lua
-- Register a join callback (called once profile is ready):
PlayerDataManager.OnLoaded(function(player, data) ... end)

-- Read/write data in a server system:
local data = PlayerDataManager.GetData(player)  -- returns PlayerProfile?
data.shards += 10
PlayerDataManager.Save(player)  -- call after high-value mutations
```

`PlayerProfile` type is in `src/shared/Types.luau`. All profile mutation is server-side only (§22 Rule 1).

### Ghost Lifecycle

```
GhostSpawnManager.spawnGhostAt()
  → GhostAI.Start()          -- AI loop: Patrolling → Triggered → Escaped
  → GhostSpawned FireAllClients
  → player RequestCapture
  → CaptureSession (mini-game, resistance tracking)
  → TutorialManager.OnCaptureStarted / OnCaptureResult (if tutorial instance)
  → resolveCapture → GhostSpawnManager.SetState("Captured" | "Escaped")
  → GhostSpawnManager.OnCaptureOrEscape() → despawn + respawn timer
```

Tutorial ghosts use `GhostSpawnManager.SpawnTutorial()` — no GhostAI, static `resistance=1`, fired only to one player via `FireClient`.

### Mini-Game Contract

Each module in `src/client/minigames/` must implement:
```lua
function Module.start(config: { [string]: any }, onInput: ({ [string]: any }) -> any)
function Module.stop()
```

`MiniGameController` dispatches by `miniGameType` from the `MiniGameStart` RemoteEvent and calls `makeOnInput(instanceId)` to wire server-validated input via `RequestMiniGameInput`.

### UI Pattern

Every UI module registers with UIManager:
```lua
UIManager.register("Name", Module)  -- Module must have open(), close(), screenGui
UIManager.open("Name")  -- closes any other open UI first (single-modal constraint)
UIManager.close("Name")
```

### Quest Signals

Other systems fire into QuestManager — never import QuestManager from other systems:
```lua
QuestManager.Signals.GhostCaptured:Fire(player, { rarity = "Rare", zoneId = "Kuburan" })
QuestManager.Signals.ZoneVisited:Fire(player, { zoneId = "HutanBambu" })
QuestManager.Signals.GroupCapture:Fire(player)
```

### Shared Definitions

| File | Contents |
|------|---------|
| `GhostDefs.luau` | 30 ghosts keyed by string ID (`"Pocong"`, `"Kuntilanak"`, …) |
| `BottleDefs.luau` | Bottle catch rates — `catchRate` never sent to client |
| `Constants.luau` | All tuning values including `RATE_LIMIT_*` constants |
| `Types.luau` | `PlayerProfile`, `GhostInstance`, `CompendiumEntry`, etc. |
| `ZoneDefs.luau` | 6 zone definitions with haunt point counts |

## Anti-Exploit (PRD §22)

Rate-limit tables (`os.clock()` keyed by userId) live in the handler's module and are cleaned on `PlayerRemoving`. Current limits: `RequestScan` 8s, `RequestCapture` 3s, `RequestMiniGameInput` 0.1s, `RequestBuyBottle` 2s.

Resistance values and catch rates never appear in any RemoteEvent or RemoteFunction response payload. All economy amounts (shards, XP, bottle counts) flow server→client only via `ShardsUpdated`, `XPUpdated`, `BottlesUpdated` events. Audit markers at each enforcement point are commented `-- §22 Rule N`.
