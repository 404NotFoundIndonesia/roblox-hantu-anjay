# Product Requirements Document — Hantu Anjay (Scripting)

**Version:** 0.1.0  
**Studio:** JihadPixel  
**Derived from:** GDD v0.1.0  
**Audience:** Scripters / Developers  

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Shared Types & Constants](#2-shared-types--constants)
3. [Remote API](#3-remote-api)
4. [ProfileService — Data Schema](#4-profileservice--data-schema)
5. [Server — WorldBuilder](#5-server--worldbuilder)
6. [Server — GhostSpawnManager](#6-server--ghostspawnmanager)
7. [Server — GhostAI](#7-server--ghostai)
8. [Server — CaptureSession](#8-server--capturesession)
9. [Server — QuestManager](#9-server--questmanager)
10. [Server — EconomyManager](#10-server--economymanager)
11. [Client — UIManager](#11-client--uimanager)
12. [Client — HUD](#12-client--hud)
13. [Client — CompendiumUI](#13-client--compendiumui)
14. [Client — ShopUI](#14-client--shopui)
15. [Client — MiniGameController](#15-client--minigamecontroller)
16. [Client — ZoneDetector](#16-client--zonedetector)
17. [Client — AudioController](#17-client--audiocontroller)
18. [Client — LocalizationBridge](#18-client--localizationbridge)
19. [Client — TutorialController](#19-client--tutorialcontroller)
20. [Ghost Data Definitions](#20-ghost-data-definitions)
21. [Localization Key Manifest](#21-localization-key-manifest)
22. [Anti-Exploit Rules](#22-anti-exploit-rules)
23. [Performance Constraints](#23-performance-constraints)

---

## 1. Project Structure

```
src/
  server/
    init.server.luau            ← bootstrap: load all server systems
    systems/
      WorldBuilder.luau
      GhostSpawnManager.luau
      GhostAI.luau
      CaptureSession.luau
      QuestManager.luau
      EconomyManager.luau
      PlayerDataManager.luau    ← thin wrapper around ProfileService
    data/
      GhostDefs.luau            ← all 30 ghost definitions
      ZoneDefs.luau             ← 6 biome configs + haunt point coords
      QuestDefs.luau            ← daily/weekly quest templates
      BottleDefs.luau           ← bottle types + stats

  client/
    init.client.luau            ← bootstrap: load all client systems
    systems/
      UIManager.luau
      HUD.luau
      CompendiumUI.luau
      ShopUI.luau
      MiniGameController.luau
      ZoneDetector.luau
      AudioController.luau
      LocalizationBridge.luau
      TutorialController.luau
    minigames/
      MantraTap.luau
      BottleAim.luau
      RhythmChant.luau
      SignalTriangulate.luau
      ShadowChase.luau
      TeamSurround.luau

  shared/
    Constants.luau
    Types.luau
    GhostDefs.luau              ← re-exported for client read (no write)
    ZoneDefs.luau
    BottleDefs.luau
    XPTable.luau                ← level → XP thresholds
    Util.luau                   ← shared helpers

  assets/
    Localization/
      GameStrings.csv
    Audio/
      (SoundIds referenced by AudioController)
```

---

## 2. Shared Types & Constants

### 2.1 `src/shared/Types.luau`

```luau
export type Rarity = "Common" | "Rare" | "Epic" | "Mythic"

export type GhostBehavior = "Wanderer" | "Hunter" | "Trickster"

export type MiniGameType =
  | "MantraTap"
  | "BottleAim"
  | "RhythmChant"
  | "SignalTriangulate"
  | "ShadowChase"
  | "TeamSurround"

export type BottleId =
  | "BotolBiasa"
  | "BotolKacaBiru"
  | "BotolEmas"
  | "BotolKristal"
  | "BotolRetak"

export type ZoneId =
  | "Kuburan"
  | "KampungTua"
  | "HutanBambu"
  | "PantaiSepi"
  | "KuburanCina"
  | "SawahHaunted"

export type GhostId = string  -- e.g. "Pocong", "Kuntilanak"

export type GhostInstance = {
  ghostId: GhostId,
  instanceId: string,          -- unique per spawned instance
  zoneId: ZoneId,
  hauntPointIndex: number,
  state: GhostState,
  resistance: number,          -- current, starts at max per GhostDef
}

export type GhostState =
  | "Patrolling"
  | "Triggered"
  | "InCapture"
  | "Escaped"
  | "Captured"

export type CaptureResult = "Success" | "Fail" | "Escaped"

export type PlayerProfile = {
  level: number,
  xp: number,
  compendium: { [GhostId]: CompendiumEntry },
  shards: number,
  bottles: { [BottleId]: number },  -- counts per bottle type
  quests: QuestProgress,
  lastDailyReset: number,           -- os.time()
  lastWeeklyReset: number,
  gamepasses: { [string]: boolean },
  companion: GhostId?,              -- rarest captured ghost to follow player
  tutorialDone: boolean,
}

export type CompendiumEntry = {
  captureCount: number,
  firstCapturedAt: number,   -- os.time()
}

export type QuestProgress = {
  daily: { [string]: number },   -- questId → current count
  weekly: { [string]: number },
}
```

### 2.2 `src/shared/Constants.luau`

```luau
return {
  MAX_PLAYERS = 50,
  WORLD_ORIGIN = Vector3.new(0, 0, 0),
  HUB_SPAWN = Vector3.new(0, 50, 0),
  CHUNK_SIZE = 16,
  SCAN_RADIUS = 60,            -- studs, detection pulse
  SCAN_COOLDOWN = 8,           -- seconds between SCAN uses
  GHOST_ESCAPE_TIME = 15,      -- seconds Hunter gives up chase
  CAPTURE_COOLDOWN = 5,        -- seconds before ghost respawns after escape/capture
  DAILY_RESET_HOUR = 0,        -- WIB (UTC+7), handled as UTC offset in QuestManager
  WEEKLY_RESET_DAY = 1,        -- Monday

  XP_PER_RARITY = {
    Common = 10,
    Rare   = 30,
    Epic   = 75,
    Mythic = 200,
  },
  FIRST_CAPTURE_BONUS_MULTIPLIER = 3,

  BOTTLE_DEFAULT = "BotolBiasa",
  BOTTLE_DEFAULT_COUNT = 3,

  RARITY_SPAWN_WEIGHT = {
    Common = 60,
    Rare   = 28,
    Epic   = 10,
    Mythic = 2,
  },

  MYTHIC_MIN_PLAYERS = 2,      -- min players to capture mythic without Botol Kristal
}
```

### 2.3 `src/shared/XPTable.luau`

```luau
-- XP required to reach each level (cumulative from level 1)
-- Level 1→2: 100 XP, grows by ~30% per level
return {
  [2]  = 100,
  [3]  = 230,
  [4]  = 400,
  [5]  = 620,
  -- ... generate programmatically: math.floor(100 * (1.3 ^ (level - 2)))
  -- Max level cap: 100
}
```

---

## 3. Remote API

All RemoteEvents fire server→client for display only.  
All state-changing actions use **RemoteFunction** (server-authoritative return value).  
Client never modifies its own data directly.

### 3.1 RemoteEvents (server → client, one-way)

| Name | Payload | Purpose |
|------|---------|---------|
| `GhostSpawned` | `{instanceId, ghostId, position, zoneId}` | Show ghost model client-side |
| `GhostDespawned` | `{instanceId}` | Remove ghost model |
| `GhostStateChanged` | `{instanceId, state: GhostState}` | Update ghost visual/audio |
| `ScanPulseResult` | `{coldZones: {Vector3}}` | Show cold zone highlights |
| `MiniGameStart` | `{instanceId, miniGameType, config}` | Open mini-game UI |
| `MiniGameEnd` | `{result: CaptureResult, xpGained, shardGained}` | Show result, close UI |
| `CompendiumUpdated` | `{ghostId, entry: CompendiumEntry}` | Refresh compendium slot |
| `XPUpdated` | `{xp, level}` | Update HUD XP bar |
| `ShardsUpdated` | `{shards}` | Update HUD shard count |
| `BottlesUpdated` | `{bottles}` | Update HUD bottle display |
| `QuestProgress` | `{questId, current, target}` | Update quest tracker |
| `QuestCompleted` | `{questId, rewards}` | Show completion popup |
| `LevelUp` | `{newLevel, rank}` | Show level-up screen |
| `ZoneChanged` | `{zoneId}` | Update HUD zone label |
| `TutorialStep` | `{step: number}` | Advance tutorial UI |
| `CompanionSet` | `{ghostId?}` | Spawn/despawn companion model |

### 3.2 RemoteFunctions (client → server, awaits result)

| Name | Args | Returns | Notes |
|------|------|---------|-------|
| `RequestScan` | `{}` | `{ok, coldZones?}` | Rate-limited by SCAN_COOLDOWN |
| `RequestCapture` | `{instanceId, bottleId}` | `{ok, error?}` | Validates proximity, bottle ownership |
| `RequestMiniGameInput` | `{instanceId, inputData}` | `{ok, resistanceDelta}` | Server validates mini-game step |
| `RequestPurchaseShard` | `{productId}` | `{ok}` | Invokes MarketplaceService server-side |
| `RequestEquipBottle` | `{bottleId}` | `{ok}` | Sets active bottle in profile |
| `RequestViewCompendium` | `{targetUserId?}` | `{compendium}` | nil = own; other = read-only |
| `RequestSkipTutorial` | `{}` | `{ok}` | Sets tutorialDone = true |

---

## 4. ProfileService — Data Schema

### 4.1 Profile Template

```luau
-- src/server/systems/PlayerDataManager.luau

local ProfileTemplate: PlayerProfile = {
  level = 1,
  xp = 0,
  compendium = {},              -- filled on first capture: { [ghostId] = {captureCount, firstCapturedAt} }
  shards = 50,                  -- starting shards
  bottles = {
    BotolBiasa = 3,             -- start with 3 default bottles
  },
  quests = {
    daily  = {},
    weekly = {},
  },
  lastDailyReset  = 0,
  lastWeeklyReset = 0,
  gamepasses = {},
  companion = nil,
  tutorialDone = false,
}
```

### 4.2 PlayerDataManager API

```luau
PlayerDataManager.GetProfile(player)   → Profile | nil
PlayerDataManager.GetData(player)      → PlayerProfile   -- profile.Data shorthand
PlayerDataManager.Save(player)         → void            -- force-save (post-purchase, post-capture)
PlayerDataManager.OnLoaded(player, cb) → void            -- fires when profile ready
```

- Load profile in `Players.PlayerAdded`; release in `Players.PlayerRemoving`
- Never expose the raw Profile object outside this module
- Wrap all writes in `pcall`; log errors without crashing

### 4.3 Milestone Checks

After any compendium update, check:

```luau
local count = countCaptured(data.compendium)
if count >= 10 and not data.milestones.aura_mistis then
    data.milestones.aura_mistis = true
    -- grant aura via EconomyManager or cosmetic flag
end
if count >= 20 and not data.milestones.title_kolektor then
    data.milestones.title_kolektor = true
end
if count >= 30 and not data.milestones.botol_kristal then
    data.milestones.botol_kristal = true
    data.bottles.BotolKristal = 1   -- or unlimited flag
end
```

Add `milestones: { [string]: boolean }` to profile template.

---

## 5. Server — WorldBuilder

**File:** `src/server/systems/WorldBuilder.luau`  
**Runs:** once on server start, before `Players.PlayerAdded` fires  

### 5.1 Responsibility

- Clone pre-built biome island Models from `ReplicatedStorage/Assets/Biomes/`
- Position each island in world space according to `ZoneDefs`
- Parent all to `Workspace`
- Mark haunt points (invisible Part with tag `HauntPoint` + attribute `ZoneId`)
- Place hub island at `Constants.HUB_SPAWN` base

### 5.2 `src/shared/ZoneDefs.luau`

```luau
export type ZoneDef = {
  id: ZoneId,
  modelName: string,            -- asset name in ReplicatedStorage/Assets/Biomes/
  worldOffset: Vector3,         -- relative to WORLD_ORIGIN
  hauntPointCount: number,      -- 3–5
  ambientSoundId: number,       -- Roblox asset ID
  affinityGhosts: {GhostId},   -- ghosts that prefer this zone (spawn weight ×2)
  detectionVolume: {            -- Region3-like bounds for ZoneDetector
    min: Vector3,
    max: Vector3,
  },
}

return {
  Kuburan     = { id = "Kuburan",     worldOffset = Vector3.new(-300, 20, 0),   hauntPointCount = 4, ... },
  KampungTua  = { id = "KampungTua",  worldOffset = Vector3.new(-100, 40, 200), hauntPointCount = 5, ... },
  HutanBambu  = { id = "HutanBambu",  worldOffset = Vector3.new(150, 60, 100),  hauntPointCount = 3, ... },
  PantaiSepi  = { id = "PantaiSepi",  worldOffset = Vector3.new(200, 10, -200), hauntPointCount = 3, ... },
  KuburanCina = { id = "KuburanCina", worldOffset = Vector3.new(-200, 30, -150),hauntPointCount = 4, ... },
  SawahHaunted= { id = "SawahHaunted",worldOffset = Vector3.new(50, 50, -300),  hauntPointCount = 4, ... },
}
```

### 5.3 Build Sequence

```
1. Iterate ZoneDefs
2. Clone biome Model from ReplicatedStorage/Assets/Biomes/{modelName}
3. PivotTo island using worldOffset
4. Collect all Parts tagged "HauntPoint" inside model → store in GhostSpawnManager registry
5. Parent model to Workspace/World
6. Clone Hub model → place at HUB_SPAWN → tag all parts CollisionGroup "Safe"
7. Fire Signal: WorldBuilder.Ready
```

---

## 6. Server — GhostSpawnManager

**File:** `src/server/systems/GhostSpawnManager.luau`  

### 6.1 Responsibility

- Maintain a pool of active GhostInstances (max 2–3 per haunt point at once)
- Spawn new ghosts over time using rarity-weighted random selection
- Trigger respawn after capture or escape
- Expose ghost positions to server (never expose to client raw — use RemoteEvent)

### 6.2 Spawn Logic

```
1. Pick random haunt point that has < maxGhostsPerPoint (default: 1)
2. Determine zone from haunt point tag
3. Roll rarity using RARITY_SPAWN_WEIGHT (weighted random)
4. From eligible ghosts for that zone+rarity, pick random ghostId
   - Affinity ghosts for that zone get 2× weight
5. Instantiate GhostInstance { ghostId, instanceId = HttpService:GenerateGUID(), zoneId, hauntPointIndex, state = "Patrolling", resistance = GhostDefs[ghostId].maxResistance }
6. Clone ghost Model from ReplicatedStorage/Assets/Ghosts/{ghostId}
7. Parent to Workspace/Ghosts/{instanceId}
8. Fire GhostSpawned RemoteEvent to all clients
9. Hand instance to GhostAI
```

### 6.3 Respawn

```luau
function GhostSpawnManager.OnCaptureOrEscape(instanceId: string)
  -- remove from active pool
  -- wait(Constants.CAPTURE_COOLDOWN)
  -- pick a *different* haunt point (not the same one)
  -- spawn new ghost
end
```

### 6.4 Server-Wide Mythic Event (Batara Guru Shadow)

- Spawns when total active players ≥ 4
- Only one active at a time
- Appears at Hub island center
- Despawns after 10 min if not captured
- Fires global announcement RemoteEvent to all clients

---

## 7. Server — GhostAI

**File:** `src/server/systems/GhostAI.luau`  
Uses `sleitnick/component` — one Component per GhostInstance model.

### 7.1 State Machine

```
Patrolling
  ├─ [player enters proximity (≤20 studs) OR detection trigger] → Triggered
  └─ [wander between haunt sub-points via PathfindingService or lerp]

Triggered
  ├─ [player initiates capture] → InCapture
  ├─ [Hunter: chases player for GHOST_ESCAPE_TIME, no capture] → Escaped
  └─ [Wanderer/Trickster: stands in place for 3s, then vanishes] → Escaped

InCapture
  ├─ [mini-game success + bottle throw] → Captured
  └─ [mini-game fail / bottle miss] → Escaped

Captured  → notify GhostSpawnManager → despawn model
Escaped   → notify GhostSpawnManager → despawn model → schedule respawn
```

### 7.2 Behavior Archetypes

**Wanderer**
- `PathfindingService` path between 2–3 waypoints near haunt point
- Speed: 4–8 studs/s
- Detection range: 15 studs
- On trigger: stops, faces player, waits 3s, Escaped if not captured

**Hunter**
- On trigger: `PathfindingService` chase toward player's position (refreshes every 1s)
- Speed: 10–14 studs/s (varies by ghost)
- Gives up after `GHOST_ESCAPE_TIME` seconds with no successful capture start
- On give-up: state → Escaped

**Trickster**
- On trigger: teleports to random point within 30 studs every 4s
- Spawns 1–2 decoy models (no hitbox, visual only)
- Real ghost emits faint particle; decoys don't
- On capture attempt on decoy: fail immediately, no mini-game

### 7.3 Detection Triggers

Server checks these each frame (or via `.Touched` + zone overlap):

| Trigger | Condition | Cooldown |
|---------|-----------|----------|
| Proximity | Player root within 15 studs of ghost | — |
| Cold Zone | Player steps on Part tagged `ColdZone` near haunt point | 30s per zone |
| Shard Pickup | Player picks up SpiritShard Part | — |
| Idle Too Long | Player stands still ≥ 8s within 40 studs of haunt point | — |

Only the **server** validates detection; client gets `GhostStateChanged` event.

---

## 8. Server — CaptureSession

**File:** `src/server/systems/CaptureSession.luau`  

### 8.1 Flow

```
Client calls RequestCapture(instanceId, bottleId)
  └─ Server validates:
       ✓ instanceId exists and state == "Triggered"
       ✓ player owns ≥1 of bottleId
       ✓ player is within 25 studs of ghost
     → Set ghost state = "InCapture"
     → Lock ghost to this player (other players see "Being Captured" state)
     → Fire MiniGameStart to player's client: { instanceId, miniGameType, config }
     → Start timeout (30s max per mini-game) — auto-Fail if exceeded

Client sends RequestMiniGameInput(instanceId, inputData) per interaction step
  └─ Server validates input against current mini-game state
     → Returns { ok, resistanceDelta }
     → Updates ghost.resistance on server

When ghost.resistance == 0:
  └─ Server runs catch rate check:
       catchRate = BottleDefs[bottleId].catchRate
       roll = math.random()
       if roll <= catchRate → CaptureResult = "Success"
       else → CaptureResult = "Fail"

  Fire MiniGameEnd to client: { result, xpGained, shardGained }

  On Success:
    → Update compendium (PlayerDataManager)
    → Award XP (+ FIRST_CAPTURE_BONUS_MULTIPLIER if first time)
    → Decrement bottle count (unless BotolKristal)
    → Fire CompendiumUpdated, XPUpdated, BottlesUpdated
    → Check milestone
    → GhostSpawnManager.OnCaptureOrEscape(instanceId)

  On Fail:
    → Decrement bottle count
    → Ghost state → Escaped
    → GhostSpawnManager.OnCaptureOrEscape(instanceId)
```

### 8.2 Resistance Reduction per Mini-Game

| Mini-Game | Resistance reduced per success step |
|-----------|-------------------------------------|
| MantraTap | 2 per correct symbol tap |
| BottleAim | 3 per second held on target |
| RhythmChant | 2 per correct beat hit |
| SignalTriangulate | All at once on correct alignment |
| ShadowChase | 1 per 0.5s shadow contact |
| TeamSurround | All at once when all positions filled |

### 8.3 Bottle Definitions (`src/shared/BottleDefs.luau`)

```luau
return {
  BotolBiasa    = { catchRate = 0.40, maxDurability = 3,   unlimited = false },
  BotolKacaBiru = { catchRate = 0.60, maxDurability = 5,   unlimited = false },
  BotolEmas     = { catchRate = 0.80, maxDurability = 8,   unlimited = false },
  BotolKristal  = { catchRate = 0.95, maxDurability = nil, unlimited = true  },
  BotolRetak    = { catchRate = 0.20, maxDurability = 1,   unlimited = false },
}
```

### 8.4 Multi-Player Capture (Mythic)

- TeamSurround mini-game fires `MiniGameStart` to **all players** within 40 studs
- Server tracks which players are standing on circle positions (tagged Parts)
- All required positions must be occupied simultaneously for ≥ 3s
- If only 1 player present and bottle is NOT BotolKristal → RequestCapture returns `{ ok = false, error = "NEED_TEAM" }`
- BotolKristal solo: skip TeamSurround, run ShadowChase instead at resistance 10

---

## 9. Server — QuestManager

**File:** `src/server/systems/QuestManager.luau`  

### 9.1 Quest Definitions (`src/server/data/QuestDefs.luau`)

```luau
export type QuestDef = {
  id: string,
  type: "daily" | "weekly",
  descKey: string,          -- localization key
  target: number,
  rewardShards: number,
  rewardXP: number,
  trackEvent: string,       -- internal event name QuestManager listens to
  trackFilter: any?,        -- optional filter (e.g. rarity == "Common")
}

return {
  -- Daily
  { id="daily_capture3common",  type="daily",  descKey="QUEST_DAILY_CAPTURE3COMMON",  target=3,  rewardShards=30,  rewardXP=50,  trackEvent="GhostCaptured", trackFilter={rarity="Common"} },
  { id="daily_find10shards",    type="daily",  descKey="QUEST_DAILY_FIND10SHARDS",    target=10, rewardShards=20,  rewardXP=30,  trackEvent="ShardCollected" },
  { id="daily_visit3zones",     type="daily",  descKey="QUEST_DAILY_VISIT3ZONES",     target=3,  rewardShards=15,  rewardXP=20,  trackEvent="ZoneVisited" },

  -- Weekly
  { id="weekly_capture1rare",   type="weekly", descKey="QUEST_WEEKLY_CAPTURE1RARE",   target=1,  rewardShards=100, rewardXP=200, trackEvent="GhostCaptured", trackFilter={rarity="Rare"} },
  { id="weekly_groupcapture",   type="weekly", descKey="QUEST_WEEKLY_GROUPCAPTURE",   target=1,  rewardShards=80,  rewardXP=150, trackEvent="GroupCapture" },
  { id="weekly_kuburancina",    type="weekly", descKey="QUEST_WEEKLY_KUBURANCINA",    target=1,  rewardShards=60,  rewardXP=100, trackEvent="GhostCaptured", trackFilter={zone="KuburanCina"} },
}
```

### 9.2 Reset Logic

```luau
-- On player load, check if reset needed:
local UTC_OFFSET = 7 * 3600   -- WIB = UTC+7
local function getWIBMidnight()
  local now = os.time()
  local wib = now + UTC_OFFSET
  local dayStart = wib - (wib % 86400)
  return dayStart - UTC_OFFSET
end

-- If lastDailyReset < current WIB midnight → reset daily quests, award daily login shards (+5)
-- If lastWeeklyReset < current WIB Monday midnight → reset weekly quests
```

### 9.3 Progress Tracking

QuestManager listens to internal Signals:

```luau
Signals.GhostCaptured:Connect(function(player, ghostId, zoneId)
  -- iterate daily+weekly quests, increment matching ones
end)

Signals.ShardCollected:Connect(function(player)
  -- increment daily_find10shards
end)

Signals.ZoneVisited:Connect(function(player, zoneId)
  -- increment daily_visit3zones if new zone this session
end)

Signals.GroupCapture:Connect(function(player)
  -- increment weekly_groupcapture
end)
```

On increment: if `current >= target` → complete quest → grant rewards → fire `QuestCompleted` RemoteEvent.

---

## 10. Server — EconomyManager

**File:** `src/server/systems/EconomyManager.luau`  

### 10.1 Spirit Shard Operations

```luau
EconomyManager.AddShards(player, amount)      -- safe add, fires ShardsUpdated
EconomyManager.SpendShards(player, amount)    -- returns false if insufficient
EconomyManager.GetShards(player)              -- read-only
```

All operations write through `PlayerDataManager`. Never trust client-sent amounts.

### 10.2 Robux — MarketplaceService

```luau
-- Developer Products (Shard Packs)
local PRODUCTS = {
  [PRODUCT_ID_100]  = function(player) EconomyManager.AddShards(player, 100) end,
  [PRODUCT_ID_500]  = function(player) EconomyManager.AddShards(player, 500) end,
  [PRODUCT_ID_1500] = function(player) EconomyManager.AddShards(player, 1500) end,
}

MarketplaceService.ProcessReceipt = function(receiptInfo)
  local handler = PRODUCTS[receiptInfo.ProductId]
  if handler then
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if player then
      local ok, err = pcall(handler, player)
      if ok then return Enum.ProductPurchaseDecision.PurchaseGranted end
    end
  end
  return Enum.ProductPurchaseDecision.NotProcessedYet
end
```

### 10.3 Gamepasses

```luau
local GAMEPASSES = {
  VIP_HUNTER       = GAMEPASS_ID_VIP,
  EXTRA_BOTTLE_BAG = GAMEPASS_ID_BOTTLE,
  AUTO_SHARD       = GAMEPASS_ID_AUTOSHARD,
}

-- Check on player join, cache result in profile.gamepasses
-- VIP_HUNTER: XP multiplier 1.1× applied in CaptureSession
-- EXTRA_BOTTLE_BAG: max bottle capacity +10 (default 5 → 15)
-- AUTO_SHARD: server tick every 30s, +1 shard per tick while player in world
```

### 10.4 Cosmetics

Cosmetic purchases (Hunter Outfit Pack, World Atmosphere Pack, etc.) set a flag in profile:

```luau
data.cosmetics = {
  outfitPack1 = false,
  atmospherePack1 = false,
  ghostTrailEffect = false,
  -- ...
}
```

Cosmetic application is client-side visual only; server just stores the ownership flag.

### 10.5 XP Boost

- Profile field: `xpBoostExpiry: number` (os.time() when boost expires)
- `EconomyManager.ApplyXPBoost(player, durationSeconds)` sets expiry
- In CaptureSession, check `os.time() < data.xpBoostExpiry` → multiply XP by 1.5×

---

## 11. Client — UIManager

**File:** `src/client/systems/UIManager.luau`  

### 11.1 Responsibility

- Central router for opening/closing UI screens
- Detects platform (mobile / PC / console) once on init
- Applies layout adjustments to all screens based on platform
- Ensures only one modal screen open at a time (Compendium, Shop, etc.)

### 11.2 Platform Detection

```luau
local UserInputService = game:GetService("UserInputService")
local platform = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
                 then "Mobile"
                 elseif UserInputService.GamepadEnabled then "Console"
                 else "PC"
```

### 11.3 Screen Registry

```luau
UIManager.register("HUD",        HUD)
UIManager.register("Compendium", CompendiumUI)
UIManager.register("Shop",       ShopUI)
UIManager.register("MiniGame",   MiniGameController)
UIManager.register("Tutorial",   TutorialController)

UIManager.open("Compendium")     -- closes any other modal, opens Compendium
UIManager.close("Compendium")
UIManager.isOpen("HUD")          -- → boolean
```

### 11.4 Safe Area

All ScreenGui frames use `ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets`.  
Anchor HUD corners with `UIPadding` of 12px from each edge.

---

## 12. Client — HUD

**File:** `src/client/systems/HUD.luau`  

### 12.1 Elements

| Element | Position | Updates via |
|---------|----------|-------------|
| Lantern bar | Top-left | (future system; placeholder for v1 — static 100%) |
| Zone label | Top-center | `ZoneChanged` RemoteEvent |
| Player count | Top-right | `Players.PlayerAdded/Removing` |
| Bottle display | Bottom-left | `BottlesUpdated` RemoteEvent |
| Mini-map | Bottom-right | see §12.3 |
| SCAN button | Bottom-center | fires `RequestScan` |
| Compendium button | Bottom-center-left | opens CompendiumUI |
| Shop button | Bottom-center-right | opens ShopUI |
| XP bar | Bottom | `XPUpdated` RemoteEvent |

### 12.2 Mobile Layout

- SCAN, Compendium, Shop buttons: 72×72 px, bottom bar, spaced evenly
- Bottle display collapses to icon + count only
- Zone label: smaller font, top-center
- No keyboard hints shown

### 12.3 Mini-Map

- Use `ViewportFrame` or a top-down 2D canvas drawn via `DrawingAPI` on a `SurfaceGui`
- Show all 6 islands as colored polygons (static, pre-drawn)
- Dots for each player updated every 0.5s via `Players:GetPlayers()` → HumanoidRootPart position
- Question mark icons for detected ghost traces (positions received via `ScanPulseResult`)
- Player's own dot: white; others: yellow

### 12.4 SCAN Mechanic

```luau
ScanButton.Activated:Connect(function()
  if scanCooldown then return end
  scanCooldown = true
  local result = RequestScan:InvokeServer()
  if result.ok then
    -- show cold zone highlights for 5s
    for _, pos in result.coldZones do
      spawnColdZoneHighlight(pos)
    end
  end
  task.delay(Constants.SCAN_COOLDOWN, function() scanCooldown = false end)
end)
```

---

## 13. Client — CompendiumUI

**File:** `src/client/systems/CompendiumUI.luau`  

### 13.1 Layout

- `ScrollingFrame` grid, 5 columns, auto-fills rows
- 30 slots rendered on open; locked slots show ghost silhouette (black) + rarity border color
- Rarity border colors: Common=white, Rare=blue, Epic=purple, Mythic=gold

### 13.2 Slot Data

Populated from `RequestViewCompendium:InvokeServer(nil)` on open.  
Response: `{ compendium: { [GhostId]: CompendiumEntry } }` — merge with GhostDefs for display.

### 13.3 Detail Card

Tap/click slot → slide-in panel from right:
- `ViewportFrame` with rotating ghost block model (clone from `ReplicatedStorage/Assets/Ghosts/`)
- Ghost name (via LocalizationBridge)
- Lore text (via LocalizationBridge)
- Rarity badge
- "Caught: N times" + "First caught: {date}" (or "???" if uncaptured)

### 13.4 Filter Bar

Three filter dropdowns at top:
- Rarity: All / Common / Rare / Epic / Mythic
- Status: All / Captured / Uncaptured
- Zone: All / {ZoneId list}

Filter is client-side only — no server call.

### 13.5 Other Player View

`RequestViewCompendium:InvokeServer(targetUserId)` → same layout, read-only, banner shows "Compendium of [Username]".

---

## 14. Client — ShopUI

**File:** `src/client/systems/ShopUI.luau`  

### 14.1 Tabs

- **Bottles** — buy with Spirit Shards
- **Cosmetics** — Robux purchase (calls `MarketplaceService:PromptProductPurchase` / `PromptGamePassPurchase`)
- **Battle Pass** — season pass overview, tier progress
- **Boosts** — XP Boost purchase

### 14.2 Bottle Shop (Shard-Priced)

| Bottle | Shard Price |
|--------|-------------|
| Botol Kaca Biru | 80 shards / 5-pack |
| Botol Emas | 200 shards / 5-pack |
| Botol Retak | Free (1 per daily login) |

Purchase calls `EconomyManager.SpendShards` server-side via a new RemoteFunction:

```
RequestBuyBottle(bottleId, quantity) → { ok, error? }
```

### 14.3 Robux Purchases

All Robux purchases use `MarketplaceService` client-side prompts.  
Server processes via `ProcessReceipt` (§10.2) or `PromptGamePassPurchaseFinished`.

---

## 15. Client — MiniGameController

**File:** `src/client/systems/MiniGameController.luau`  

### 15.1 Dispatch

Listens to `MiniGameStart` RemoteEvent → looks up `miniGameType` → requires corresponding module from `src/client/minigames/`:

```luau
local miniGameModules = {
  MantraTap         = require(script.Parent.minigames.MantraTap),
  BottleAim         = require(script.Parent.minigames.BottleAim),
  RhythmChant       = require(script.Parent.minigames.RhythmChant),
  SignalTriangulate  = require(script.Parent.minigames.SignalTriangulate),
  ShadowChase       = require(script.Parent.minigames.ShadowChase),
  TeamSurround      = require(script.Parent.minigames.TeamSurround),
}
```

Each module exports: `{ start(config, onInput), stop() }`.

### 15.2 MantraTap

- Config: `{ symbols: {string}, timeLimit: number }`
- UI: row of symbol buttons; correct next symbol glows
- Each tap → `RequestMiniGameInput({ step = currentIndex, symbol = tapped })`
- Server validates order; returns `resistanceDelta`
- Wrong tap → flash red, no penalty (just no progress)
- Timer: `timeLimit` seconds → if expired, MiniGameController fires auto-fail to server

### 15.3 BottleAim

- Config: `{ holdDuration: 2, ghostWorldPos: Vector3 }`
- UI: reticle overlay on ghost's screen position (use `Camera:WorldToScreenPoint`)
- Progress: fill circle around reticle while held
- Input: `UserInputService.InputBegan/Changed` for mouse; `.TouchStarted` for mobile; gamepad right stick
- Each 0.5s of hold → `RequestMiniGameInput({ heldSeconds = accumulator })`

### 15.4 RhythmChant

- Config: `{ notes: {lane: 1|2|3, timing: number}[], bpm: number }`
- UI: 3 vertical lanes, notes scroll down, tap zone at bottom
- Input: 3 tap buttons (mobile) / keyboard keys Q,W,E or gamepad
- Hit window: ±0.15s from note timing
- Each hit → `RequestMiniGameInput({ lane, hitDelta })`

### 15.5 SignalTriangulate

- Config: `{ targetAngle: number }` (server picks, client doesn't know answer)
- UI: compass ring; rotate using left/right swipe or A/D or left stick
- Server judges alignment when player submits (tap center button)
- `RequestMiniGameInput({ submittedAngle })` → server returns delta resistance

### 15.6 ShadowChase

- Config: `{ duration: 30 }` 
- UI: 2D top-down view of arena; shadow and ghost body rendered as colored circles
- Shadow position: server streams via repeated `GhostStateChanged` with `shadowPos` field
- Player controls: WASD / joystick / drag (mobile)
- Collision: client-side raycast/overlap check → `RequestMiniGameInput({ contact: "shadow"|"body" })` every 0.5s

### 15.7 TeamSurround

- Config: `{ positions: {Vector3}, requiredPlayers: number }`
- UI: overhead mini-map shows circle positions + which are filled
- Players walk to marked positions in world (no mini-game overlay, just HUD indicators)
- Server detects positions via Part `.Touched`; fires `MiniGameStart` update packets with current fill state
- When all filled: server completes automatically (no client submit needed)

---

## 16. Client — ZoneDetector

**File:** `src/client/systems/ZoneDetector.luau`  

### 16.1 Logic

```luau
local currentZone: ZoneId? = nil

RunService.Heartbeat:Connect(function()
  local rootPos = LocalPlayer.Character.HumanoidRootPart.Position
  for zoneId, def in ZoneDefs do
    if isInsideBounds(rootPos, def.detectionVolume) then
      if zoneId ~= currentZone then
        currentZone = zoneId
        ZoneChanged:Fire(zoneId)                     -- local Signal
        -- also notify server for quest tracking:
        ZoneChangedRemote:FireServer(zoneId)
      end
      return
    end
  end
  -- Hub / between zones
  if currentZone ~= nil then
    currentZone = nil
    ZoneChanged:Fire(nil)
  end
end)
```

`isInsideBounds`: simple AABB check using `def.detectionVolume.min` / `.max`.

---

## 17. Client — AudioController

**File:** `src/client/systems/AudioController.luau`  

### 17.1 Layers

| Layer | Type | Notes |
|-------|------|-------|
| Ambient | Looped Sound per zone | Swapped on `ZoneChanged`, crossfade 1s |
| Tension | Looped drone | Volume 0→1 as nearest ghost distance shrinks |
| Ghost SFX | One-shot | Plays on `GhostStateChanged` (Triggered) |
| UI SFX | One-shot | Plays on capture result, level-up, quest complete |

### 17.2 Tension System

```luau
RunService.Heartbeat:Connect(function()
  -- find nearest ghost model in Workspace/Ghosts/
  local nearest = math.huge
  for _, ghostFolder in Workspace.Ghosts:GetChildren() do
    local dist = (rootPos - ghostFolder.PrimaryPart.Position).Magnitude
    if dist < nearest then nearest = dist end
  end
  local t = 1 - math.clamp((nearest - 10) / 40, 0, 1)  -- full tension at 10 studs
  tensionSound.Volume = t * 0.6
end)
```

### 17.3 Ghost Signature Sounds

Defined in `GhostDefs[ghostId].soundId` (Roblox asset ID).  
Plays at ghost world position using `Sound` parented to ghost model root.  
Fires on state `"Triggered"`.

### 17.4 UI Sounds

```luau
AudioController.playUI("capture_success")   -- Gamelan note
AudioController.playUI("capture_fail")      -- Glass shatter
AudioController.playUI("level_up")          -- Gamelan fanfare
AudioController.playUI("minigame_hit")      -- Percussion tap
AudioController.playUI("quest_complete")    -- Short chime
```

All UI sounds stored as asset IDs in a lookup table inside AudioController.

---

## 18. Client — LocalizationBridge

**File:** `src/client/systems/LocalizationBridge.luau`  

### 18.1 Setup

```luau
local LocalizationService = game:GetService("LocalizationService")
local translator = LocalizationService:GetTranslatorForPlayerAsync(LocalPlayer)

function LocalizationBridge.get(key: string, params?: {[string]: any}): string
  local ok, result = pcall(function()
    return translator:FormatByKey(key, params)
  end)
  return if ok then result else key  -- fallback: show raw key
end
```

### 18.2 Usage Pattern

Every UI text label calls `LocalizationBridge.get(key)` on init and on language change.  
Never hardcode display strings in UI scripts.

### 18.3 Key Format

`CATEGORY_SUBCATEGORY_IDENTIFIER` — all caps, underscore-separated.  
Full manifest: see §21.

---

## 19. Client — TutorialController

**File:** `src/client/systems/TutorialController.luau`  

### 19.1 Steps

| Step | Trigger | Action |
|------|---------|--------|
| 0 | Player spawns, `tutorialDone == false` | Show NPC chat bubble: greeting + walk indicator |
| 1 | Player walks toward cold zone marker | NPC explains SCAN; highlight SCAN button |
| 2 | Player taps SCAN | Cold zone highlighted; NPC explains ghost traces |
| 3 | Scripted Pocong spawns (server-triggered via `TutorialStep` event) | NPC says "catch it!" |
| 4 | Player attempts capture | MantraTap opens at 50% speed, forgiving (any order accepted) |
| 5 | Capture success | Compendium opens with animation; NPC explains it |
| 6 | NPC points at mini-map | Explains other islands; tutorial ends |

### 19.2 Implementation Notes

- Tutorial is gated server-side: `tutorialDone` flag in profile
- Step 3 Pocong is a **scripted ghost** — server spawns it at fixed position, resistance = 1, always "Success" on first bottle throw regardless of catch rate
- After step 6: server sets `tutorialDone = true` via `RequestSkipTutorial` or auto-complete
- NPC is a non-player Model in Hub island, animated via Animator

---

## 20. Ghost Data Definitions

**File:** `src/shared/GhostDefs.luau` (shared, read by both sides)

```luau
export type GhostDef = {
  id: GhostId,
  nameKey: string,          -- localization key
  loreKey: string,
  rarity: Rarity,
  behavior: GhostBehavior,
  miniGame: MiniGameType,
  maxResistance: number,
  speed: number,            -- studs/s (used by GhostAI)
  detectionRange: number,   -- studs
  soundId: number,          -- signature audio
  modelName: string,        -- asset in ReplicatedStorage/Assets/Ghosts/
  affinityZones: {ZoneId},
}
```

### Full Roster

| # | Id | Rarity | Behavior | MiniGame | MaxRes | Speed |
|---|-----|--------|----------|----------|--------|-------|
| 1 | Pocong | Common | Wanderer | MantraTap | 3 | 5 |
| 2 | Kuntilanak | Common | Wanderer | MantraTap | 3 | 6 |
| 3 | WeweGombel | Common | Wanderer | RhythmChant | 2 | 4 |
| 4 | Banaspati | Common | Wanderer | BottleAim | 2 | 7 |
| 5 | SundelBolong | Common | Wanderer | MantraTap | 3 | 5 |
| 6 | Toyol | Common | Hunter | BottleAim | 2 | 9 |
| 7 | Tuyul | Common | Hunter | BottleAim | 2 | 9 |
| 8 | LeakWeak | Common | Wanderer | SignalTriangulate | 3 | 8 |
| 9 | GenderuwoJr | Common | Hunter | RhythmChant | 3 | 6 |
| 10 | Jenglot | Common | Wanderer | BottleAim | 2 | 3 |
| 11 | Rangda | Rare | Trickster | ShadowChase | 5 | 10 |
| 12 | OrangBunian | Rare | Trickster | SignalTriangulate | 5 | 7 |
| 13 | HantuRaya | Rare | Trickster | MantraTap | 6 | 8 |
| 14 | BabiNgepet | Rare | Wanderer | RhythmChant | 5 | 8 |
| 15 | Palasik | Rare | Hunter | SignalTriangulate | 5 | 11 |
| 16 | Penanggalan | Rare | Wanderer | SignalTriangulate | 6 | 6 |
| 17 | AswangMild | Rare | Hunter | ShadowChase | 5 | 10 |
| 18 | ManananggalHalf | Rare | Hunter | BottleAim | 6 | 9 |
| 19 | KraSue | Rare | Wanderer | BottleAim | 5 | 8 |
| 20 | PhiPop | Rare | Trickster | RhythmChant | 6 | 9 |
| 21 | NyiBlorong | Epic | Hunter | ShadowChase | 8 | 12 |
| 22 | BataraKala | Epic | Hunter | ShadowChase | 8 | 7 |
| 23 | RangdaTrue | Epic | Trickster | ShadowChase | 9 | 11 |
| 24 | Mahisasura | Epic | Hunter | RhythmChant | 8 | 13 |
| 25 | Leyak | Epic | Trickster | ShadowChase | 9 | 10 |
| 26 | SantetSpecter | Epic | Trickster | SignalTriangulate | 8 | 8 |
| 27 | HantuKopek | Epic | Trickster | MantraTap | 7 | 9 |
| 28 | NyiRoroKidul | Mythic | Trickster | TeamSurround | 10 | 14 |
| 29 | DewiDurga | Mythic | Hunter | TeamSurround | 10 | 12 |
| 30 | BataraGuruShadow | Mythic | Trickster | TeamSurround | 10 | 15 |

---

## 21. Localization Key Manifest

All keys defined in `src/assets/Localization/GameStrings.csv`.  
CSV columns: `Key, id, en`

### UI Keys
```
UI_BUTTON_SCAN              Deteksi                 Scan
UI_BUTTON_COMPENDIUM        Ensiklopedia            Compendium
UI_BUTTON_SHOP              Toko                    Shop
UI_LABEL_ZONE               Zona:                   Zone:
UI_LABEL_PLAYERS            Pemain                  Players
UI_LABEL_SHARDS             Pecahan Roh             Spirit Shards
UI_LABEL_BOTTLES            Botol                   Bottles
UI_LABEL_LEVEL              Level                   Level
UI_FILTER_ALL               Semua                   All
UI_FILTER_CAPTURED          Tertangkap              Captured
UI_FILTER_UNCAPTURED        Belum Ditangkap         Uncaptured
UI_COMPENDIUM_CAUGHT        Ditangkap: {count}x     Caught: {count}x
UI_COMPENDIUM_FIRST         Pertama kali: {date}    First caught: {date}
UI_COMPENDIUM_UNKNOWN       ???                     ???
UI_TUTORIAL_SKIP            Lewati                  Skip
```

### Ghost Name Keys
```
GHOST_POCONG_NAME           Pocong                  Pocong
GHOST_KUNTILANAK_NAME       Kuntilanak              Kuntilanak
GHOST_WEWEGOMBEL_NAME       Wewe Gombel             Wewe Gombel
... (one per ghost)
```

### Ghost Lore Keys
```
GHOST_POCONG_LORE           Roh orang yang meninggal ...   The spirit of the deceased ...
... (one per ghost)
```

### Zone Name Keys
```
ZONE_KUBURAN_NAME           Kuburan                 Graveyard
ZONE_KAMPUNGTUA_NAME        Kampung Tua             Old Village
ZONE_HUTANBAMBU_NAME        Hutan Bambu             Bamboo Forest
ZONE_PANTAISEPI_NAME        Pantai Sepi             Lonely Shore
ZONE_KUBURANCINA_NAME       Kuburan Cina            Chinese Cemetery
ZONE_SAWAHHAUNTED_NAME      Sawah Angker            Haunted Rice Field
```

### Quest Keys
```
QUEST_DAILY_CAPTURE3COMMON  Tangkap 3 hantu biasa          Capture 3 common ghosts
QUEST_DAILY_FIND10SHARDS    Temukan 10 Pecahan Roh         Find 10 Spirit Shards
QUEST_DAILY_VISIT3ZONES     Kunjungi 3 zona berbeda        Visit 3 different zones
QUEST_WEEKLY_CAPTURE1RARE   Tangkap 1 hantu langka         Capture 1 rare ghost
QUEST_WEEKLY_GROUPCAPTURE   Tangkap hantu bersama teman    Capture a ghost near friends
QUEST_WEEKLY_KUBURANCINA    Tangkap hantu di Kuburan Cina  Capture ghost in Chinese Cemetery
```

### Rank Title Keys
```
RANK_PEMULA_TITLE           Pemburu Pemula          Rookie Hunter
RANK_JAGOAN_TITLE           Pemburu Jagoan          Skilled Hunter
RANK_PARANORMAL_TITLE       Paranormal Sejati       True Paranormal
RANK_DUKUN_TITLE            Dukun Handal            Expert Shaman
RANK_LEGENDA_TITLE          Legenda Paranormal      Paranormal Legend
```

### Error / System Keys
```
ERR_NEED_TEAM               Butuh minimal 2 pemain untuk menangkap hantu ini!   Need at least 2 players to capture this spirit!
ERR_NO_BOTTLES              Botol habis!            No bottles left!
ERR_TOO_FAR                 Terlalu jauh!           Too far away!
ERR_SCAN_COOLDOWN           Deteksi sedang diisi ulang...   Scan is recharging...
NOTIFY_CAPTURE_SUCCESS      Hantu tertangkap!       Spirit captured!
NOTIFY_CAPTURE_FAIL         Hantu kabur!            Spirit escaped!
NOTIFY_LEVELUP              Naik level! Level {level}   Level up! Level {level}
NOTIFY_QUEST_DONE           Misi selesai!           Quest complete!
NOTIFY_MYTHIC_SPAWN         Hantu Legendaris telah muncul!   A Legendary Spirit has appeared!
```

### Tutorial Keys
```
TUT_STEP0   Hei Pemburu! Selamat datang. Ikuti aku!    Hey Hunter! Welcome. Follow me!
TUT_STEP1   Tekan Deteksi untuk merasakan kehadiran hantu.   Press Scan to sense nearby spirits.
TUT_STEP2   Lihat! Ada jejak hantu di sana.            Look! A spirit trace over there.
TUT_STEP3   Pocong terlihat! Lempar botolmu!           A Pocong appeared! Throw your bottle!
TUT_STEP4   Bagus! Cek Ensiklopediamu.                 Nice! Check your Compendium.
TUT_STEP5   Masih banyak pulau lain untuk dijelajahi. Ada hantu langka di luar sana!   More islands await. Rare spirits are out there!
```

---

## 22. Anti-Exploit Rules

| Rule | Implementation |
|------|---------------|
| No client-side data writes | All profile mutations go through server systems only |
| Capture validated server-side | `RequestCapture` checks proximity, ghost state, bottle ownership before starting |
| Mini-game input validated step-by-step | Each `RequestMiniGameInput` call validated against current server-side game state; client cannot skip steps |
| Resistance never sent to client | Client only receives `resistanceDelta` result, not current resistance value |
| Shard balance never trusted from client | All shard changes via `EconomyManager`; client receives `ShardsUpdated` event as display only |
| Bottle catch rate computed server-side | Client never sees catch rate; no way to force success |
| Ghost positions server-authoritative | Ghost model position replicated via `RemoteEvent`, never driven by client |
| RemoteFunction rate limiting | `RequestScan`: min 8s gap enforced server-side. `RequestCapture`: min 3s gap per player |
| ProcessReceipt idempotent | Check for duplicate receipt before granting product |
| ProfileService session lock | Prevents two servers writing same player data simultaneously |

---

## 23. Performance Constraints

| Constraint | Limit | Notes |
|------------|-------|-------|
| Max active ghost models | 20 per server | GhostSpawnManager cap |
| Ghost AI tick rate | 0.5s | Use `task.delay` loop, not `RunService.Heartbeat` |
| Mini-map update rate | 0.5s | Heartbeat is overkill |
| ZoneDetector check rate | 0.25s | Via `RunService.Heartbeat` throttled with timer |
| Tension audio update | 0.5s | Heartbeat throttled |
| ProfileService auto-save | ~60s internal | Plus manual save post-capture/purchase |
| WorldBuilder build time | <5s target | Pre-baked models, no procedural geometry at runtime |
| Max Parts per biome model | ~800 Parts | Profile first, then optimize with `UnionOperation` |
| ScanPulseResult coldZones | max 10 positions | Server caps response array |
| RemoteEvent payload size | <1KB per event | Avoid sending model data; use asset IDs + IDs only |

---

*Document maintained by JihadPixel. Sync with GDD on each design change.*
