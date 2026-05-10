# TASKS — Hantu Anjay (Scripting)

**Derived from:** PRD v0.1.0 / GDD v0.1.0  
**Track progress:** check `[ ]` → `[x]` when task is complete.

Legend: **Deps** = task IDs that must be complete before starting this one.

---

## Phase 0 — Foundation (Shared Layer)

> Build the shared data layer that every other system depends on. No game logic here — only types, constants, and data definitions.

---

### T-01 · Bootstrap Project Structure

- **Description:** Create all folder structure and empty bootstrap entry-point scripts. Set up `src/server/init.server.luau` and `src/client/init.client.luau` as empty files. Create all subfolders: `src/server/systems/`, `src/server/data/`, `src/client/systems/`, `src/client/minigames/`, `src/shared/`, `src/assets/Localization/`. Create empty placeholder `.luau` files for every module listed in PRD §1 so Rojo syncs the tree without errors.
- **Files:** All files under `src/` as specified in PRD §1.
- **Output:** Rojo syncs without errors; Roblox Studio sees all expected module locations; no `require` call fails due to missing path.
- **DoD:**
  - [x] `default.project.json` paths resolve in Studio
  - [x] All placeholder modules return an empty table `{}`
  - [x] `init.server.luau` and `init.client.luau` run without error on empty requires
  - [x] No Rojo sync errors in terminal

**Deps:** none

---

### T-02 · Shared Types

- **Description:** Implement `src/shared/Types.luau` with all exported Luau types exactly as defined in PRD §2.1. Include: `Rarity`, `GhostBehavior`, `MiniGameType`, `BottleId`, `ZoneId`, `GhostId`, `GhostInstance`, `GhostState`, `CaptureResult`, `PlayerProfile`, `CompendiumEntry`, `QuestProgress`. These are type-only — no runtime values.
- **Files:** `src/shared/Types.luau`
- **Output:** A module that exports all types. Any other module can `require` it and get full type inference in a Luau LSP.
- **DoD:**
  - [x] All types from PRD §2.1 are present and correctly shaped
  - [x] `PlayerProfile` includes the `milestones` field (`{ [string]: boolean }`) per PRD §4.3
  - [x] `GhostInstance.state` uses the `GhostState` union type
  - [x] No syntax errors; module loads cleanly

**Deps:** T-01

---

### T-03 · Shared Constants & XP Table

- **Description:** Implement `src/shared/Constants.luau` with all values from PRD §2.2 and `src/shared/XPTable.luau` with level→XP thresholds per PRD §2.3. XPTable must be generated programmatically using `math.floor(100 * (1.3 ^ (level - 2)))` for levels 2–100, not hardcoded per entry.
- **Files:** `src/shared/Constants.luau`, `src/shared/XPTable.luau`
- **Output:** Two modules. `Constants` returns the config table. `XPTable` returns a table indexed `[level] = cumulativeXP` for levels 2–100.
- **DoD:**
  - [x] All constant keys from PRD §2.2 are present with correct values
  - [x] `XPTable[2] == 100`, `XPTable[3] == 230`, `XPTable[4] == 400` (matches PRD examples)
  - [x] `XPTable` covers levels 2–100 programmatically
  - [x] No magic numbers left in Constants that belong in XPTable or vice versa

**Deps:** T-01

---

### T-04 · Ghost Data Definitions

- **Description:** Implement `src/shared/GhostDefs.luau` with all 30 ghost entries exactly as listed in PRD §20 table. Each entry must match the `GhostDef` type: `id`, `nameKey`, `loreKey`, `rarity`, `behavior`, `miniGame`, `maxResistance`, `speed`, `detectionRange`, `soundId` (placeholder `0` until audio assets ready), `modelName`, `affinityZones`.
- **Files:** `src/shared/GhostDefs.luau`
- **Output:** A module returning a dictionary keyed by `GhostId` (e.g. `GhostDefs["Pocong"]`). Must be readable by both server and client.
- **DoD:**
  - [x] All 30 ghost entries present with correct rarity, behavior, miniGame, maxResistance, and speed per PRD §20 table
  - [x] Each entry has a `nameKey` matching the pattern `GHOST_{ID}_NAME` and `loreKey` matching `GHOST_{ID}_LORE`
  - [x] `affinityZones` is a non-empty array for every ghost
  - [x] Module loads from both server and client contexts without error

**Deps:** T-02

---

### T-05 · Zone Definitions

- **Description:** Implement `src/shared/ZoneDefs.luau` with all 6 biome zone configs per PRD §5.2. Each entry must include: `id`, `modelName`, `worldOffset`, `hauntPointCount`, `ambientSoundId` (placeholder `0`), `affinityGhosts`, `detectionVolume` (`{min: Vector3, max: Vector3}`). Choose `worldOffset` values and `detectionVolume` bounds that match the intended island layout described in GDD §3.2 (total ~600×600 studs, varying heights).
- **Files:** `src/shared/ZoneDefs.luau`
- **Output:** A module returning a dictionary keyed by `ZoneId`. Used by `WorldBuilder`, `GhostSpawnManager`, `ZoneDetector`.
- **DoD:**
  - [x] All 6 zones present: `Kuburan`, `KampungTua`, `HutanBambu`, `PantaiSepi`, `KuburanCina`, `SawahHaunted`
  - [x] `detectionVolume` bounds for each zone do not overlap each other
  - [x] `hauntPointCount` matches GDD §3.2 values (3–5 per zone)
  - [x] `affinityGhosts` arrays match GDD §3.2 Ghost Affinity column
  - [x] Module loads cleanly from both server and client

**Deps:** T-02, T-04

---

### T-06 · Bottle Definitions

- **Description:** Implement `src/shared/BottleDefs.luau` with all 5 bottle entries per PRD §8.3. Each entry: `catchRate` (0.0–1.0), `maxDurability` (number or `nil` for unlimited), `unlimited` (boolean).
- **Files:** `src/shared/BottleDefs.luau`
- **Output:** A module returning a dictionary keyed by `BottleId`.
- **DoD:**
  - [x] All 5 bottles present: `BotolBiasa`, `BotolKacaBiru`, `BotolEmas`, `BotolKristal`, `BotolRetak`
  - [x] Catch rates match PRD §8.3 exactly (0.40 / 0.60 / 0.80 / 0.95 / 0.20)
  - [x] `BotolKristal.unlimited == true` and `maxDurability == nil`
  - [x] Module is identical between server and client reads

**Deps:** T-02

---

### T-07 · Quest Definitions

- **Description:** Implement `src/server/data/QuestDefs.luau` with all 6 quest entries (3 daily, 3 weekly) per PRD §9.1. Each entry must include: `id`, `type`, `descKey`, `target`, `rewardShards`, `rewardXP`, `trackEvent`, `trackFilter` (optional). The `trackFilter` table structure must be consistent enough for `QuestManager` to evaluate generically.
- **Files:** `src/server/data/QuestDefs.luau`
- **Output:** A module returning an array of `QuestDef` tables. Server-only.
- **DoD:**
  - [x] All 6 quests present with correct IDs, types, targets, and rewards per PRD §9.1
  - [x] `trackFilter` present and correctly shaped for the 4 quests that need it
  - [x] `descKey` values match the localization manifest in PRD §21
  - [x] Module loads without error on server

**Deps:** T-02, T-05

---

### T-08 · Shared Utilities

- **Description:** Implement `src/shared/Util.luau` with reusable helper functions needed across systems: `weightedRandom(weights: {[string]: number}): string` (picks key by weight), `isInsideBounds(pos: Vector3, bounds: {min: Vector3, max: Vector3}): boolean` (AABB check used by ZoneDetector), `countTable(t: {}): number` (counts non-nil entries in a dictionary), `formatDate(timestamp: number): string` (formats `os.time()` as `"DD/MM/YYYY"`).
- **Files:** `src/shared/Util.luau`
- **Output:** A module exporting the 4 utility functions above.
- **DoD:**
  - [x] `weightedRandom` returns keys proportionally — verified by calling it 1000× and checking distribution
  - [x] `isInsideBounds` returns `true` when position is strictly inside bounds, `false` on boundary and outside
  - [x] `countTable` correctly counts a mix of filled and nil-holed tables
  - [x] `formatDate` returns correctly formatted string from a known timestamp

**Deps:** T-01

---

### T-09 · Remote API Scaffold

- **Description:** Create all `RemoteEvent` and `RemoteFunction` instances in `ReplicatedStorage/Remotes/` as listed in PRD §3. These must be created by the server `init.server.luau` before any other system starts. Create a shared accessor module `src/shared/Remotes.luau` that returns a dictionary of all remote references by name so every system accesses them consistently without string-based `WaitForChild` calls scattered everywhere.
- **Files:** `src/shared/Remotes.luau`, `src/server/init.server.luau` (creation logic)
- **Output:** All 16 RemoteEvents and 8 RemoteFunctions exist in `ReplicatedStorage/Remotes/` at runtime. Any module can `require(Remotes).GhostSpawned` and get the correct instance.
- **DoD:**
  - [x] All 16 RemoteEvents from PRD §3.1 are created and accessible
  - [x] All 8 RemoteFunctions from PRD §3.2 are created and accessible (+ `RequestBuyBottle` from PRD §14.2)
  - [x] `Remotes.luau` uses `WaitForChild` with a timeout on client side (in case of race); errors clearly if timeout exceeded
  - [x] No two systems create the same remote independently

**Deps:** T-01

---

### T-10 · Localization CSV

- **Description:** Create `src/assets/Localization/GameStrings.csv` with all string keys from PRD §21. CSV must have exactly 3 columns: `Key`, `id`, `en`. Cover all categories: UI keys, ghost name keys (all 30), ghost lore keys (all 30 — write placeholder lore text for each), zone name keys (6), quest keys (6), rank title keys (5), error/system keys, and tutorial step keys. Import this CSV into Roblox Studio as a `LocalizationTable` in `ReplicatedStorage/Assets/Localization/`.
- **Files:** `src/assets/Localization/GameStrings.csv`
- **Output:** A valid CSV file. When imported into Studio, `LocalizationService:GetTranslatorForPlayerAsync()` can resolve every key listed in PRD §21 for both `id` and `en` locales.
- **DoD:**
  - [x] CSV is valid (no missing commas, no unclosed quotes)
  - [x] All 30 `GHOST_{ID}_NAME` keys present
  - [x] All 30 `GHOST_{ID}_LORE` keys present with non-empty placeholder text in both languages
  - [x] All 6 zone keys, 6 quest keys, 5 rank keys, all UI/error/tutorial keys present
  - [x] Importing CSV into Studio produces no validation errors
  - [x] `translator:FormatByKey("UI_BUTTON_SCAN")` returns `"Deteksi"` for Indonesian player

**Deps:** T-01

---

## Phase 1 — Data Persistence

---

### T-11 · PlayerDataManager

- **Description:** Implement `src/server/systems/PlayerDataManager.luau` as a thin wrapper around `ProfileService`. Set up the profile template per PRD §4.1 (including `milestones`, `cosmetics`, `xpBoostExpiry` fields). Handle `Players.PlayerAdded` (load profile, fire `OnLoaded` callbacks) and `Players.PlayerRemoving` (release profile). Expose the API from PRD §4.2: `GetProfile`, `GetData`, `Save`, `OnLoaded`. Wrap all DataStore operations in `pcall` and log errors without crashing the server.
- **Files:** `src/server/systems/PlayerDataManager.luau`
- **Output:** A server module that loads player data on join, persists it on leave, and exposes a clean API for all other server systems to read/write player data.
- **DoD:**
  - [x] New player gets the default profile template exactly (level=1, xp=0, shards=50, BotolBiasa×3)
  - [x] Returning player gets their previously saved data (verified by leaving and rejoining)
  - [x] `OnLoaded` callback fires after profile is ready — no system accesses data before this
  - [x] Session lock prevents simultaneous writes (ProfileService built-in — verify it kicks in when two servers serve same player)
  - [x] Server does not crash on DataStore failure; logs warning instead
  - [x] `GetData` returns `nil` gracefully if called before profile loaded

**Deps:** T-02, T-03, T-09

---

## Phase 2 — World

---

### T-12 · WorldBuilder

- **Description:** Implement `src/server/systems/WorldBuilder.luau`. On server start (before `Players.PlayerAdded`), iterate `ZoneDefs`, clone each biome model from `ReplicatedStorage/Assets/Biomes/`, position using `PivotTo` and `worldOffset`, collect all `HauntPoint`-tagged Parts into a registry dictionary keyed by zone ID, and parent models to `Workspace/World/`. Clone the Hub model to `HUB_SPAWN`. Tag all Hub parts with CollisionGroup `"Safe"`. Fire a `Signal` (`WorldBuilder.Ready`) when complete so other systems can gate on world readiness. Build must finish in under 5 seconds (PRD §23).
- **Files:** `src/server/systems/WorldBuilder.luau`
- **Output:** At runtime, all 6 biome islands and the Hub island are visible in Workspace, positioned correctly, with `HauntPoint` Parts registered and accessible to `GhostSpawnManager`.
- **DoD:**
  - [x] All 6 biome models placed at correct `worldOffset` per `ZoneDefs`
  - [x] Hub island placed at `Constants.HUB_SPAWN`
  - [x] `HauntPoint` Part count per zone matches `ZoneDef.hauntPointCount`
  - [x] `WorldBuilder.Ready` signal fires before any player can join
  - [x] Build completes in < 5s measured with `os.clock()`
  - [x] No biome model overlaps another (visually verify in Studio)

**Deps:** T-03, T-05, T-08

---

## Phase 3 — Ghost Systems

---

### T-13 · GhostSpawnManager

- **Description:** Implement `src/server/systems/GhostSpawnManager.luau`. After `WorldBuilder.Ready`, begin populating haunt points with ghost instances. Use `Util.weightedRandom` with `Constants.RARITY_SPAWN_WEIGHT` to select rarity, then select a ghost from `GhostDefs` for that rarity, giving affinity ghosts 2× weight. Instantiate `GhostInstance` data table, clone ghost model from `ReplicatedStorage/Assets/Ghosts/{ghostId}`, parent to `Workspace/Ghosts/{instanceId}`, fire `GhostSpawned` RemoteEvent to all clients. Cap active ghosts at 20 server-wide (PRD §23). Implement `OnCaptureOrEscape(instanceId)`: remove from pool, wait `CAPTURE_COOLDOWN`, respawn at a different haunt point. Implement the Mythic server-wide event for `BataraGuruShadow` (PRD §6.4): spawns at Hub center when ≥4 players online, one at a time, despawns after 10 min if not captured.
- **Files:** `src/server/systems/GhostSpawnManager.luau`
- **Output:** Ghosts continuously populate the world. After capture or escape, a new ghost appears at a different haunt point after the cooldown. Never exceeds 20 active ghosts.
- **DoD:**
  - [x] Ghosts spawn across all 6 zones within 30s of server start
  - [x] Rarity distribution over 100 spawns is approximately 60/28/10/2 (Common/Rare/Epic/Mythic) — log and verify
  - [x] Affinity ghosts appear in their preferred zones more frequently than non-affinity ones
  - [x] After a ghost is captured/escaped, it does not respawn at the exact same haunt point
  - [x] Active ghost count never exceeds 20
  - [x] `GhostSpawned` RemoteEvent fires to all clients with correct payload on each spawn
  - [x] `GhostDespawned` fires on capture/escape
  - [x] BataraGuruShadow spawns only when 4+ players present, only one at a time
  - [x] BataraGuruShadow despawns after 10 min if uncaptured

**Deps:** T-03, T-04, T-05, T-08, T-09, T-11, T-12

---

### T-14 · GhostAI — Wanderer Behavior

- **Description:** Implement the Wanderer archetype in `src/server/systems/GhostAI.luau` using `sleitnick/component`. A Wanderer component attaches to a ghost model in state `"Patrolling"`. It uses `PathfindingService` to walk between 2–3 waypoints randomly chosen near its haunt point, looping continuously. Speed pulled from `GhostDef.speed`. When state transitions to `"Triggered"` (see T-17), the Wanderer stops movement, faces the triggering player for 3 seconds, then transitions to `"Escaped"` if no capture is initiated.
- **Files:** `src/server/systems/GhostAI.luau`
- **Output:** Ghost models with Wanderer behavior visibly patrol between waypoints in Studio. On trigger, they stop and face the player.
- **DoD:**
  - [x] Wanderer moves between waypoints without getting stuck (use path recompute on stuck detection)
  - [x] Wanderer speed matches `GhostDef.speed` for each ghost
  - [x] Wanderer does not walk off the island edge (PathfindingService respects geometry)
  - [x] Transition to `"Escaped"` fires correctly after 3s of `"Triggered"` with no capture
  - [x] `GhostStateChanged` RemoteEvent fires on every state transition

**Deps:** T-04, T-09, T-13

---

### T-15 · GhostAI — Hunter Behavior

- **Description:** Add the Hunter archetype to `GhostAI.luau`. When `"Triggered"`, the Hunter uses `PathfindingService` to chase the triggering player, refreshing the path every 1 second. Speed from `GhostDef.speed`. If no capture is initiated within `Constants.GHOST_ESCAPE_TIME` (15s) from trigger, the Hunter transitions to `"Escaped"`. During chase, the ghost must not chase multiple players simultaneously — it locks onto the first player that triggered it.
- **Files:** `src/server/systems/GhostAI.luau`
- **Output:** Hunter ghosts visibly chase players after being triggered.
- **DoD:**
  - [x] Hunter begins chasing within 0.5s of trigger
  - [x] Path refreshes every 1s; ghost does not walk into walls for more than 2s
  - [x] Hunter locks onto original triggering player, ignores others during chase
  - [x] After 15s without capture start, Hunter state → `"Escaped"`
  - [x] `GhostStateChanged` fires on trigger and escape

**Deps:** T-14

---

### T-16 · GhostAI — Trickster Behavior

- **Description:** Add the Trickster archetype to `GhostAI.luau`. When `"Triggered"`, the Trickster teleports to a random point within 30 studs of its current position every 4 seconds. Spawn 1–2 decoy models (clones of the ghost model, no hitbox, `CanCollide = false`, no `HauntPoint` tag). The real ghost emits a faint `ParticleEmitter`; decoys do not. If a player initiates `RequestCapture` on a decoy's `instanceId` (tracked separately), the server immediately returns `{ ok = false, error = "DECOY" }` — no mini-game opens.
- **Files:** `src/server/systems/GhostAI.luau`
- **Output:** Trickster ghosts teleport and have visible decoys. Players who try to capture a decoy get an immediate fail response.
- **DoD:**
  - [x] Trickster teleports every 4s while in `"Triggered"` state
  - [x] 1–2 decoy models spawn on trigger, are visually identical to real ghost
  - [x] Real ghost has a ParticleEmitter; decoys do not — distinguishable if you know what to look for
  - [x] `RequestCapture` on decoy instanceId returns `{ ok = false, error = "DECOY" }`
  - [x] Decoy models are destroyed when ghost transitions to `"Escaped"` or `"Captured"`

**Deps:** T-14

---

### T-17 · GhostAI — Detection Triggers

- **Description:** Implement all 4 detection trigger conditions in `GhostAI.luau` (PRD §7.3). Proximity: check player root within `GhostDef.detectionRange` studs using a 0.5s server tick (not Heartbeat). Cold Zone: tag specific Parts near haunt points as `ColdZone`; use `.Touched` to detect player contact; 30s cooldown per zone per player. Shard Pickup: connect to a `ShardCollected` signal fired by the shard interaction system. Idle Too Long: track player velocity; if player stands still ≥ 8s within 40 studs of haunt point, trigger the nearest patrolling ghost. All trigger checks are server-only; fire `GhostStateChanged` to clients when state changes to `"Triggered"`.
- **Files:** `src/server/systems/GhostAI.luau`
- **Output:** All 4 triggers reliably transition ghosts from `"Patrolling"` to `"Triggered"`.
- **DoD:**
  - [x] Proximity trigger fires when player walks within `detectionRange` studs
  - [x] Cold Zone trigger fires on `.Touched` and respects 30s cooldown per zone per player
  - [x] Shard pickup trigger fires when a player picks up a SpiritShard Part
  - [x] Idle trigger fires after 8s of standing still within 40 studs of a haunt point
  - [x] None of the triggers fire from the Hub Safe zone
  - [x] Trigger only fires if ghost is currently in `"Patrolling"` state (no double-trigger)

**Deps:** T-03, T-14, T-15, T-16

---

## Phase 4 — Capture System

---

### T-18 · CaptureSession — Core Flow

- **Description:** Implement `src/server/systems/CaptureSession.luau` handling the full capture flow from PRD §8.1. Handle `RequestCapture` RemoteFunction: validate that `instanceId` exists, state is `"Triggered"`, player owns the chosen bottle, and player is within 25 studs. Transition ghost to `"InCapture"`, lock it to this player (other players' `RequestCapture` on same instance returns `{ ok = false, error = "BUSY" }`). Fire `MiniGameStart` to the capturing player. Start a 30s server-side timeout; if exceeded, auto-fail. On resistance reaching 0, run the catch rate check (`math.random() <= bottleDef.catchRate`). On Success: update compendium via `PlayerDataManager`, award XP (with VIP and XP Boost multipliers), decrement bottle (skip if BotolKristal unlimited), fire `CompendiumUpdated`, `XPUpdated`, `BottlesUpdated`, check milestones, call `GhostSpawnManager.OnCaptureOrEscape`. On Fail: decrement bottle, transition ghost to `"Escaped"`, call `GhostSpawnManager.OnCaptureOrEscape`. Fire `MiniGameEnd` in both cases.
- **Files:** `src/server/systems/CaptureSession.luau`
- **Output:** Full end-to-end capture flow works. Capture and fail both correctly clean up ghost and trigger respawn.
- **DoD:**
  - [x] `RequestCapture` rejects if player is >25 studs from ghost
  - [x] `RequestCapture` rejects if ghost is not in `"Triggered"` state
  - [x] `RequestCapture` rejects if player has 0 of the chosen bottle
  - [x] Only one player can be in capture session per ghost instance at a time
  - [x] 30s timeout auto-fails and cleans up correctly
  - [x] Catch rate check uses server-side `math.random()` — never client-provided value
  - [x] VIP Hunter gamepass XP multiplier (1.1×) applied correctly
  - [x] XP Boost multiplier (1.5×) applied when `xpBoostExpiry > os.time()`
  - [x] First capture of a ghost type gives `FIRST_CAPTURE_BONUS_MULTIPLIER = 3` bonus
  - [x] BotolKristal does not decrement on use (unlimited = true)
  - [x] `GhostSpawnManager.OnCaptureOrEscape` called in both success and fail paths
  - [x] Milestone check runs after every successful compendium update

**Deps:** T-03, T-06, T-11, T-13, T-17

---

### T-19 · CaptureSession — Server-Side Mini-Game Validators

- **Description:** Add server-side validation logic to `CaptureSession.luau` for each of the 6 mini-game types, handling `RequestMiniGameInput` per PRD §8.1 and §8.2. Each validator is a stateful session object that tracks progress for the current mini-game. The validator must return `{ ok, resistanceDelta }` without exposing current resistance to the client.
  - **MantraTap:** Maintain the expected symbol sequence server-side. Validate each submitted `{ step, symbol }` against expected order. Return `resistanceDelta = 2` on correct tap, `0` on wrong.
  - **BottleAim:** Accept `{ heldSeconds }` increments. Return `resistanceDelta = 3 * deltaSeconds` clamped.
  - **RhythmChant:** Accept `{ lane, hitDelta }`. Return `resistanceDelta = 2` if `math.abs(hitDelta) <= 0.15`, else `0`.
  - **SignalTriangulate:** Accept final `{ submittedAngle }`. Reduce resistance proportional to accuracy (full reduction if within ±15°, partial for ±45°, zero beyond).
  - **ShadowChase:** Accept `{ contact }` every 0.5s. `"shadow"` → `resistanceDelta = 1`; `"body"` → reset mini-game (resistance resets to starting value for this ghost).
  - **TeamSurround:** Accept no client input — server monitors position Parts via `.Touched`. When all required positions held for ≥3s, resistance drops to 0.
- **Files:** `src/server/systems/CaptureSession.luau`
- **Output:** Server correctly validates all 6 mini-game input types and returns accurate resistance deltas.
- **DoD:**
  - [x] MantraTap: wrong symbol returns `resistanceDelta = 0`; correct returns `2`
  - [x] MantraTap: sequence cannot be skipped by submitting step index out of order
  - [x] BottleAim: resistance reduces at 3 per second of hold; stops when ghost is at 0
  - [x] RhythmChant: hit window is exactly ±0.15s; outside returns 0
  - [x] SignalTriangulate: full reduction within ±15°; zero beyond ±45°
  - [x] ShadowChase: body contact resets current mini-game resistance correctly
  - [x] TeamSurround: requires all positions filled simultaneously for ≥3s; partial fill does not complete
  - [x] None of these validators trust client-reported `resistanceDelta` — all computed server-side

**Deps:** T-18

---

### T-20 · XP & Leveling System

- **Description:** Implement XP awarding and level-up logic as part of `CaptureSession.luau` (or a helper called by it). After XP is added to `data.xp`, check against `XPTable` for level-up. Support multi-level-up (e.g. XP from a Mythic capture might skip multiple levels). On level-up: update `data.level`, fire `LevelUp` RemoteEvent with `{newLevel, rank}`, check if rank title changed (per GDD §7.1 rank thresholds). Rank is determined by level range: 1–5 = Pemula, 6–15 = Jagoan, 16–30 = Paranormal, 31–50 = Dukun, 51+ = Legenda.
- **Files:** `src/server/systems/CaptureSession.luau` or `src/server/systems/ProgressionManager.luau`
- **Output:** XP awards correctly accumulate and trigger level-ups, including rank transitions.
- **DoD:**
  - [x] XP from `Constants.XP_PER_RARITY` applied correctly per rarity
  - [x] `FIRST_CAPTURE_BONUS_MULTIPLIER` applied only on first capture of that ghost type
  - [x] Level-up triggers at correct XP thresholds from `XPTable`
  - [x] Multi-level-up works in a single XP grant
  - [x] `LevelUp` RemoteEvent fires with correct `rank` string key (e.g. `"RANK_PEMULA_TITLE"`)
  - [x] `XPUpdated` RemoteEvent fires after every XP change (even without level-up)

**Deps:** T-03, T-11, T-18

---

### T-21 · Compendium Milestone Checks

- **Description:** Implement milestone checking in `PlayerDataManager.luau` or as a helper called by `CaptureSession`. After any successful capture updates the compendium, count total captured ghosts and check the 3 milestones from PRD §4.3: 10 ghosts → set `milestones.aura_mistis = true`, 20 → `milestones.title_kolektor = true`, 30 → `milestones.botol_kristal = true` and add `BotolKristal` to profile bottles. Each milestone fires once (guarded by the milestone flag). Fire a dedicated notification to the client (reuse `QuestCompleted` RemoteEvent or a new `MilestoneUnlocked` event).
- **Files:** `src/server/systems/PlayerDataManager.luau` or `src/server/systems/CaptureSession.luau`
- **Output:** At 10, 20, and 30 captured ghosts, the player receives their milestone reward exactly once.
- **DoD:**
  - [x] Milestone fires only once per player (flag prevents re-trigger on same or future sessions)
  - [x] At 10 captured: `milestones.aura_mistis` set to `true`
  - [x] At 20 captured: `milestones.title_kolektor` set to `true`
  - [x] At 30 captured: `milestones.botol_kristal` set to `true` AND `data.bottles.BotolKristal` is set
  - [x] Client receives notification event with milestone info
  - [x] Milestone persists across sessions (saved in ProfileService)

**Deps:** T-11, T-18

---

## Phase 5 — Economy & Quests

---

### T-22 · EconomyManager — Shard Operations

- **Description:** Implement `src/server/systems/EconomyManager.luau` for Spirit Shard operations per PRD §10.1. `AddShards(player, amount)` increments `data.shards` and fires `ShardsUpdated`. `SpendShards(player, amount)` checks balance first; returns `false` without modifying data if insufficient. `GetShards(player)` returns current balance read-only. All operations go through `PlayerDataManager.GetData`. Never trust any amount passed from the client.
- **Files:** `src/server/systems/EconomyManager.luau`
- **Output:** Shard balance is safely managed server-side. Client always gets an accurate display via `ShardsUpdated`.
- **DoD:**
  - [ ] `AddShards` correctly updates balance and fires `ShardsUpdated` RemoteEvent
  - [ ] `SpendShards` returns `false` and does NOT modify balance when insufficient
  - [ ] `SpendShards` returns `true` and deducts correctly when sufficient
  - [ ] `GetShards` reads without modifying
  - [ ] No path where a negative shard balance is possible

**Deps:** T-09, T-11

---

### T-23 · EconomyManager — Robux & Gamepasses

- **Description:** Add MarketplaceService integration to `EconomyManager.luau` per PRD §10.2 and §10.3. Set up `ProcessReceipt` for the 3 Developer Products (100/500/1500 shard packs). `ProcessReceipt` must be idempotent — check `PurchaseHistory` DataStore or ProfileService receipt log before granting. On player join, use `MarketplaceService:UserOwnsGamePassAsync` (wrapped in `pcall`) to check all 3 gamepasses and cache results in `data.gamepasses`. Apply gamepass effects: VIP (XP ×1.1 in CaptureSession), Extra Bottle Bag (max capacity +10 — enforce in bottle purchase logic), Auto-Shard (tick every 30s, +1 shard via `AddShards`). Implement `ApplyXPBoost(player, duration)` per PRD §10.5.
- **Files:** `src/server/systems/EconomyManager.luau`
- **Output:** Shard pack purchases grant shards reliably (no double-grant). Gamepasses are detected on join. Gamepass effects are applied throughout the relevant systems.
- **DoD:**
  - [ ] `ProcessReceipt` grants shards only once per receipt ID (idempotent)
  - [ ] `ProcessReceipt` returns `NotProcessedYet` if player is not in server (they'll get it on next join)
  - [ ] All 3 gamepasses checked on player join; results cached in `data.gamepasses`
  - [ ] Auto-Shard tick fires every 30s and adds 1 shard per tick
  - [ ] `ApplyXPBoost` sets `data.xpBoostExpiry = os.time() + duration`
  - [ ] XP Boost active when `os.time() < xpBoostExpiry` — verified in T-18 CaptureSession

**Deps:** T-22

---

### T-24 · EconomyManager — Bottle Shop (RequestBuyBottle)

- **Description:** Add a `RequestBuyBottle` RemoteFunction handler (server-side) per PRD §14.2. Client sends `{ bottleId, quantity }`. Server validates: bottle is purchasable with shards (not Robux), player has enough shards, quantity is valid (1 or 5). Deduct shards via `SpendShards`, add bottles to `data.bottles`, fire `BottlesUpdated` and `ShardsUpdated`. Enforce Extra Bottle Bag gamepass capacity limit: default max 5 total bottles of any non-default type; +10 if gamepass owned.
- **Files:** `src/server/systems/EconomyManager.luau`, register in `src/server/init.server.luau`
- **Output:** Players can buy bottles in-game using shards; balance and inventory update immediately.
- **DoD:**
  - [ ] `RequestBuyBottle` rejects invalid `bottleId` (e.g. BotolKristal is not purchasable with shards)
  - [ ] Deduction and bottle grant are atomic — no partial state if error occurs
  - [ ] Capacity limit enforced; returns `{ ok = false, error = "FULL" }` if over limit
  - [ ] Both `BottlesUpdated` and `ShardsUpdated` fire after successful purchase

**Deps:** T-22, T-23

---

### T-25 · QuestManager

- **Description:** Implement `src/server/systems/QuestManager.luau` per PRD §9. On player load, run reset logic: compute WIB midnight using PRD §9.2 formula; if `data.lastDailyReset < currentWIBMidnight`, reset all daily quest progress and award 5 daily login shards via `AddShards`; update `lastDailyReset`. If `data.lastWeeklyReset < currentWIBMonday`, reset weekly progress. Connect to internal Signals (`GhostCaptured`, `ShardCollected`, `ZoneVisited`, `GroupCapture`) and increment matching quest progress using `trackFilter` evaluation. When progress meets `target`, grant `rewardShards` and `rewardXP`, fire `QuestCompleted` RemoteEvent, and fire `QuestProgress` updates after each increment.
- **Files:** `src/server/systems/QuestManager.luau`
- **Output:** Quests track correctly, reset on schedule, and reward players on completion.
- **DoD:**
  - [ ] Daily quests reset correctly after WIB midnight (test by manually setting `lastDailyReset` to yesterday)
  - [ ] Weekly quests reset on Monday WIB
  - [ ] Daily login shards (+5) awarded on first login of each day
  - [ ] `GhostCaptured` signal increments rarity-filtered quests only for matching rarity
  - [ ] Zone filter works: `weekly_kuburancina` only increments for captures in `KuburanCina`
  - [ ] `GroupCapture` quest increments when ≥3 other players are within 40 studs of capture
  - [ ] Quest does not increment past `target` (clamp at target)
  - [ ] Rewards are granted exactly once per quest per cycle

**Deps:** T-07, T-09, T-11, T-22

---

## Phase 6 — Client Foundation

---

### T-26 · LocalizationBridge

- **Description:** Implement `src/client/systems/LocalizationBridge.luau` per PRD §18. Call `LocalizationService:GetTranslatorForPlayerAsync(LocalPlayer)` once on init (yield until ready). Expose `LocalizationBridge.get(key, params?)` that calls `translator:FormatByKey` wrapped in `pcall`, falling back to the raw key string if resolution fails. Cache the translator instance — do not call `GetTranslatorForPlayerAsync` per call.
- **Files:** `src/client/systems/LocalizationBridge.luau`
- **Output:** Any UI script can call `LocalizationBridge.get("UI_BUTTON_SCAN")` and receive the correctly localized string.
- **DoD:**
  - [ ] Returns correct Indonesian string for `id` locale
  - [ ] Returns correct English string for `en` locale
  - [ ] Falls back to raw key string (not empty string or error) if key is missing from CSV
  - [ ] Parametric keys (e.g. `{count}`, `{level}`, `{date}`) resolve correctly when `params` table is passed
  - [ ] Init does not block the rest of the client for more than 3s

**Deps:** T-09, T-10

---

### T-27 · UIManager

- **Description:** Implement `src/client/systems/UIManager.luau` per PRD §11. Detect platform once (`Mobile` / `PC` / `Console`) using `UserInputService`. Implement `register(name, module)`, `open(name)`, `close(name)`, `isOpen(name)`. Enforce single-modal constraint: opening a modal screen automatically closes any other currently open modal (HUD is never closed by this — it is always visible). Apply `ScreenInsets.DeviceSafeInsets` to all ScreenGui instances. Emit a `UIManager.PlatformDetected` signal so other systems can read the platform type after init.
- **Files:** `src/client/systems/UIManager.luau`
- **Output:** Centralized UI routing. Any system calls `UIManager.open("Compendium")` and the compendium screen opens while any other modal closes.
- **DoD:**
  - [ ] Platform detection works correctly on mobile emulator (TouchEnabled), PC, and gamepad-only
  - [ ] Opening Compendium while Shop is open closes Shop first
  - [ ] HUD remains visible regardless of which modal is open
  - [ ] `UIManager.isOpen` returns accurate boolean
  - [ ] All ScreenGuis have `DeviceSafeInsets` applied

**Deps:** T-26

---

### T-28 · ZoneDetector

- **Description:** Implement `src/client/systems/ZoneDetector.luau` per PRD §16. Use `RunService.Heartbeat` throttled to 0.25s intervals. On each tick, check player `HumanoidRootPart.Position` against each zone's `detectionVolume` bounds using `Util.isInsideBounds`. When zone changes, fire a local `Signal` and also `FireServer` on a `ZoneChangedRemote` RemoteEvent (server uses this for quest tracking in T-25). Handle `nil` zone (Hub or between zones) gracefully.
- **Files:** `src/client/systems/ZoneDetector.luau`
- **Output:** Zone changes are detected within 0.25s of the player entering a new zone. HUD zone label updates. Server quest tracking receives zone visit events.
- **DoD:**
  - [ ] Zone detection fires within 0.25s of entering a zone boundary
  - [ ] No false-positive fires when player stays in same zone
  - [ ] Correctly returns to `nil` zone when player is in Hub or between islands
  - [ ] `ZoneChangedRemote:FireServer` called on each zone change (not on null transitions)
  - [ ] Does not fire on every Heartbeat — throttled to 0.25s intervals

**Deps:** T-05, T-08, T-09, T-27

---

## Phase 7 — Client HUD & UI

---

### T-29 · HUD — Layout & Core Elements

- **Description:** Build the HUD ScreenGui per PRD §12.1 and §12.2. Create all elements: Lantern bar (static 100% placeholder), Zone label, Player count, Bottle display, XP bar, SCAN button, Compendium button, Shop button. Wire RemoteEvent listeners: `ZoneChanged` → update zone label text via `LocalizationBridge.get("ZONE_{id}_NAME")`; `BottlesUpdated` → refresh bottle icon + count; `XPUpdated` → animate XP bar fill. Mobile layout: SCAN/Compendium/Shop buttons are 72×72px at bottom center; bottle collapses to icon + count. PC layout: keyboard hints shown on buttons. Apply safe area padding (12px UIPadding on all sides).
- **Files:** `src/client/systems/HUD.luau`
- **Output:** Fully functional HUD visible in-game showing all elements. Updates reactively to server events.
- **DoD:**
  - [ ] All 8 HUD elements are present and positioned per PRD §12.1 diagram
  - [ ] Zone label updates correctly when entering each biome zone
  - [ ] Bottle display shows count per bottle type
  - [ ] XP bar fills smoothly via TweenService on `XPUpdated`
  - [ ] Player count reflects actual server population in real time
  - [ ] On mobile: touch buttons are ≥44×44px (prefer 72×72px per PRD), no keyboard hints
  - [ ] On PC: keyboard hints visible on SCAN (E key or configurable)
  - [ ] No HUD element is clipped by device notch/home bar

**Deps:** T-26, T-27, T-28

---

### T-30 · HUD — Mini-Map

- **Description:** Implement the mini-map per PRD §12.3 inside `HUD.luau`. Use a `Frame` with a static background image (pre-drawn top-down island map SVG exported as a Decal). Overlay player dots (white = self, yellow = others) updated every 0.5s. Overlay `?` icons for ghost traces received via `ScanPulseResult`. Map dots must be positioned relative to map by converting world position to map UV coordinates using the known world bounds (600×600 studs from `ZoneDefs` offsets).
- **Files:** `src/client/systems/HUD.luau`
- **Output:** Mini-map shows all players and ghost traces in approximately correct positions.
- **DoD:**
  - [ ] Player dots update at 0.5s intervals (not Heartbeat)
  - [ ] Self dot is white; other player dots are yellow
  - [ ] `?` icons appear at correct relative positions after SCAN
  - [ ] `?` icons fade out after 5s
  - [ ] Map does not update more frequently than 0.5s (performance constraint)
  - [ ] Mini-map is readable on mobile at minimum screen size

**Deps:** T-29

---

### T-31 · HUD — SCAN Button & Cold Zone Highlights

- **Description:** Wire the SCAN button per PRD §12.4. On button activation: check local `scanCooldown` flag; invoke `RequestScan` RemoteFunction; on `ok` response, spawn highlight effects (semi-transparent blue circles/glow) at each `coldZone` position for 5 seconds using `BillboardGui` or `SelectionBox`; start `SCAN_COOLDOWN` (8s) countdown displayed on the button (number counting down or greyed state). Button must be visually disabled during cooldown.
- **Files:** `src/client/systems/HUD.luau`
- **Output:** SCAN button works end-to-end. Cold zones appear as visible highlights in world space after scanning.
- **DoD:**
  - [ ] Button disabled immediately after tap; re-enables after exactly 8s
  - [ ] Cold zone highlights appear at correct world positions
  - [ ] Highlights disappear after 5s automatically
  - [ ] If server returns `ok = false` (cooldown enforced server-side too), button resets without showing highlights
  - [ ] Cooldown countdown shown on button UI (number or animation)

**Deps:** T-29, T-09

---

### T-32 · CompendiumUI

- **Description:** Implement `src/client/systems/CompendiumUI.luau` per PRD §13. On open, call `RequestViewCompendium:InvokeServer(nil)` to get own compendium data. Render a 5-column `ScrollingFrame` grid with 30 slots. Captured slots show ghost icon + rarity border color; uncaptured slots show black silhouette. On slot tap/click, slide in a detail card from the right with: rotating `ViewportFrame` ghost model, ghost name (LocalizationBridge), lore (LocalizationBridge), rarity badge, capture count, first captured date. Implement filter bar (3 dropdowns: Rarity, Status, Zone) — client-side filtering only. Implement other-player view: `RequestViewCompendium:InvokeServer(userId)` opens same layout with "Compendium of [Name]" banner and no interaction.
- **Files:** `src/client/systems/CompendiumUI.luau`
- **Output:** Fully functional compendium screen with grid, detail card, filters, and other-player view.
- **DoD:**
  - [ ] All 30 slots rendered correctly on open
  - [ ] Rarity border colors match PRD §13.1 (white/blue/purple/gold)
  - [ ] Uncaptured slots show black silhouette (ghost shape, not empty box)
  - [ ] Detail card slide-in animation works
  - [ ] `ViewportFrame` shows rotating ghost model for captured ghosts
  - [ ] Localized name and lore text display correctly
  - [ ] Capture count and first-captured date display correctly
  - [ ] All 3 filters work independently and in combination
  - [ ] `CompendiumUpdated` RemoteEvent updates the relevant slot in real-time without full reload
  - [ ] Other-player view is read-only (no capture stats shown if other player has privacy — show counts only)

**Deps:** T-26, T-27, T-09

---

### T-33 · ShopUI

- **Description:** Implement `src/client/systems/ShopUI.luau` per PRD §14. 4 tabs: Bottles (shard-priced), Cosmetics (Robux), Battle Pass (season overview), Boosts (XP Boost). Bottles tab: show `BotolKacaBiru` and `BotolEmas` with shard prices; buy button calls `RequestBuyBottle` RemoteFunction; show `BotolRetak` as "1 Free / Daily Login" (no buy button — awarded automatically). Cosmetics tab: show each item with Robux price; buy button calls `MarketplaceService:PromptProductPurchase` or `PromptGamePassPurchase` as appropriate. Battle Pass tab: show 30-tier progress bar (tier data from a server fetch or hardcoded for v1). Boosts tab: XP Boost purchase. All labels via LocalizationBridge.
- **Files:** `src/client/systems/ShopUI.luau`
- **Output:** Working shop with all 4 tabs. Purchases trigger correct flows.
- **DoD:**
  - [ ] Bottle purchase deducts correct shard amount and updates inventory
  - [ ] Bottle purchase shows error message if insufficient shards
  - [ ] Cosmetic purchase opens Roblox native purchase prompt
  - [ ] All prices and labels use LocalizationBridge (no hardcoded strings)
  - [ ] Shop closes correctly when UIManager opens another screen
  - [ ] Insufficient shard error message displayed (not silent fail)

**Deps:** T-26, T-27, T-09, T-24

---

## Phase 8 — Mini-Games (Client)

---

### T-34 · MiniGameController (Dispatcher)

- **Description:** Implement `src/client/systems/MiniGameController.luau` per PRD §15.1. Listen to `MiniGameStart` RemoteEvent. On receipt, call `UIManager.open("MiniGame")`, look up the mini-game module by `miniGameType`, call `module.start(config, onInput)`. Pass `onInput` as a callback that calls `RequestMiniGameInput:InvokeServer(instanceId, inputData)`. Listen to `MiniGameEnd` RemoteEvent: call `module.stop()`, close the MiniGame screen, play the result sound via `AudioController`, show a result overlay ("Hantu tertangkap!" or "Hantu kabur!"). Each mini-game module must implement `start(config, onInput)` and `stop()` interface.
- **Files:** `src/client/systems/MiniGameController.luau`
- **Output:** Clean dispatcher that routes mini-game events to the correct module. Result always shown to player.
- **DoD:**
  - [ ] Correct mini-game module opens for each of the 6 types
  - [ ] `onInput` callback correctly invokes `RequestMiniGameInput` to server
  - [ ] `stop()` is always called on `MiniGameEnd` regardless of result
  - [ ] Result overlay shows correct localized string for success/fail
  - [ ] Audio plays: `capture_success` on Success, `capture_fail` on Fail

**Deps:** T-26, T-27, T-09

---

### T-35 · Mini-Game — MantraTap UI

- **Description:** Implement `src/client/minigames/MantraTap.luau`. Config: `{ symbols: {string}, timeLimit: number }`. UI: row of symbol buttons (one per symbol in sequence); the next expected symbol glows/highlights; others are dimmed. Timer bar counts down from `timeLimit`. On tap: call `onInput({ step = currentIndex, symbol = tappedSymbol })`. On correct response (`resistanceDelta > 0`), advance highlight to next symbol. On wrong tap: flash button red. On timer expiry: call `onInput({ timeout = true })`. Works for mobile tap, PC click, and controller (A button on highlighted symbol — use `UserInputService.GamepadButtonDown`).
- **Files:** `src/client/minigames/MantraTap.luau`
- **Output:** Playable MantraTap mini-game UI.
- **DoD:**
  - [ ] Symbol buttons are large enough for mobile tap (≥44×44px)
  - [ ] Correct symbol glows clearly; wrong ones are clearly dimmed
  - [ ] Timer bar depletes smoothly over `timeLimit` seconds
  - [ ] Wrong tap flashes red; no progress
  - [ ] Controller: A button confirms highlighted symbol; D-pad navigates (or auto-select next)
  - [ ] Game stops cleanly on `stop()` (no orphan connections)

**Deps:** T-34

---

### T-36 · Mini-Game — BottleAim UI

- **Description:** Implement `src/client/minigames/BottleAim.luau`. Config: `{ holdDuration: 2, ghostWorldPos: Vector3 }`. Convert `ghostWorldPos` to screen position via `Camera:WorldToScreenPoint`. Render a circular reticle at that screen position. While player holds input on the reticle, a progress fill circle fills over `holdDuration` seconds. Input: mouse click-hold (PC), touch-hold (mobile), hold right trigger (controller). Every 0.5s of hold, call `onInput({ heldSeconds = accumulator })`. If input released early, reset accumulator to 0. Ghost moves during aim (world position updates via `GhostStateChanged`); reticle must follow.
- **Files:** `src/client/minigames/BottleAim.luau`
- **Output:** Playable BottleAim mini-game UI.
- **DoD:**
  - [ ] Reticle tracks ghost screen position even as ghost moves
  - [ ] Progress circle fills correctly over hold duration
  - [ ] Releasing input resets progress to 0 (no partial accumulation saved)
  - [ ] Works for touch, mouse, and gamepad
  - [ ] `onInput` called every 0.5s during hold, not every frame

**Deps:** T-34

---

### T-37 · Mini-Game — RhythmChant UI

- **Description:** Implement `src/client/minigames/RhythmChant.luau`. Config: `{ notes: {lane, timing}[], bpm: number }`. UI: 3 vertical lanes side by side, notes (square blocks) scroll downward, tap zone highlighted at bottom of each lane. Hit window: ±0.15s. Input: 3 tap buttons (mobile, placed bottom-left/center/right), Q/W/E keys (PC), face buttons (controller). On tap: call `onInput({ lane, hitDelta = os.clock() - noteTiming })`. Play a percussion sound (`AudioController.playUI("minigame_hit")`) on each tap regardless of hit/miss. Miss (no note in window): no sound, no callback.
- **Files:** `src/client/minigames/RhythmChant.luau`
- **Output:** Playable DDR-style mini-game UI.
- **DoD:**
  - [ ] Notes scroll at correct speed derived from `bpm`
  - [ ] Hit zone is visually clear (highlighted area at bottom)
  - [ ] Tap registers within ±0.15s window; outside = no callback
  - [ ] Sound plays on hit
  - [ ] Works cross-platform: touch buttons (mobile), Q/W/E (PC), gamepad face buttons
  - [ ] Notes are single-tap only (no holds required)

**Deps:** T-34

---

### T-38 · Mini-Game — SignalTriangulate UI

- **Description:** Implement `src/client/minigames/SignalTriangulate.luau`. Config: `{ targetAngle: number }` (client does not know target). UI: a compass ring that rotates based on player input. Audio cue gets louder as submitted angle approaches target (optional — can be visual glow instead for v1). Input: left/right swipe (mobile), A/D keys (PC), left stick (controller). Submit button (tap center, Enter, or gamepad A). On submit: call `onInput({ submittedAngle = currentAngle })`. Show partial glow feedback based on returned `resistanceDelta`.
- **Files:** `src/client/minigames/SignalTriangulate.luau`
- **Output:** Playable compass mini-game UI.
- **DoD:**
  - [ ] Compass ring rotates smoothly with input
  - [ ] Submit button sends current angle
  - [ ] Visual feedback (glow intensity or color) reflects `resistanceDelta` response
  - [ ] Works cross-platform
  - [ ] Angle wraps correctly 0°–360° (no negative angles)

**Deps:** T-34

---

### T-39 · Mini-Game — ShadowChase UI

- **Description:** Implement `src/client/minigames/ShadowChase.luau`. Config: `{ duration: 30 }`. UI: a 2D top-down arena view (200×200px canvas on screen). Player avatar = white circle; ghost body = red circle; ghost shadow = grey circle. Shadow position updated via `GhostStateChanged` events with `shadowPos` field. Player moves avatar with WASD/joystick/drag. Every 0.5s, check client-side overlap: avatar touching shadow → `onInput({ contact = "shadow" })`; avatar touching body → `onInput({ contact = "body" })`. Duration countdown shown. On timeout: `stop()` is called by MiniGameController via `MiniGameEnd`.
- **Files:** `src/client/minigames/ShadowChase.luau`
- **Output:** Playable ShadowChase mini-game UI.
- **DoD:**
  - [ ] Shadow position updates correctly from `GhostStateChanged` events
  - [ ] Player avatar movement works on touch, keyboard, and gamepad
  - [ ] Shadow contact fires `onInput` every 0.5s (not every frame)
  - [ ] Body contact fires correctly and mini-game reset is reflected visually
  - [ ] Duration countdown is visible
  - [ ] Arena is clearly readable on mobile screen

**Deps:** T-34

---

### T-40 · Mini-Game — TeamSurround UI

- **Description:** Implement `src/client/minigames/TeamSurround.luau`. Config: `{ positions: {Vector3}, requiredPlayers: number }`. This mini-game has no overlay UI — players walk to world-space positions. Show HUD indicators: for each position, render a `BillboardGui` arrow/marker above the target Part in world. Show fill state (e.g. green = filled, grey = empty) updated via `MiniGameStart` update packets from server. Show a "waiting for players" status label in HUD. `stop()` removes all `BillboardGui` markers.
- **Files:** `src/client/minigames/TeamSurround.luau`
- **Output:** Players see world-space markers and fill state. No screen overlay blocking movement.
- **DoD:**
  - [ ] `BillboardGui` markers appear at correct world positions
  - [ ] Markers update green/grey based on fill state from server packets
  - [ ] Markers are removed cleanly on `stop()`
  - [ ] "Waiting for players" or "All positions filled!" status shown in HUD
  - [ ] No full-screen overlay — player can freely move in world during this mini-game

**Deps:** T-34

---

## Phase 9 — Audio

---

### T-41 · AudioController — Ambient & Tension

- **Description:** Implement `src/client/systems/AudioController.luau` per PRD §17. Ambient layer: maintain one looped `Sound` per zone; on `ZoneChanged` signal, crossfade from current to new ambient sound over 1 second using `TweenService`. Tension layer: one looped drone `Sound`; update its `Volume` every 0.5s based on distance to the nearest ghost model in `Workspace/Ghosts/` using the formula from PRD §17.2. Hub zone: ambient sound = silence (Volume = 0).
- **Files:** `src/client/systems/AudioController.luau`
- **Output:** Atmospheric audio that matches the zone and ghost proximity.
- **DoD:**
  - [ ] Ambient sound changes within 1s of entering a new zone with audible crossfade
  - [ ] Tension drone audibly increases as player walks toward a ghost
  - [ ] Tension drone at full volume (0.6) when within 10 studs of ghost
  - [ ] Tension drone silent when no ghost is within 50 studs
  - [ ] Tension updates every 0.5s (not every Heartbeat)
  - [ ] Hub island has no ambient sound

**Deps:** T-27, T-28

---

### T-42 · AudioController — Ghost & UI SFX

- **Description:** Add ghost signature sound and UI SFX to `AudioController.luau`. Ghost SFX: listen to `GhostStateChanged` RemoteEvent; when `state == "Triggered"`, play the ghost's signature sound (`GhostDef.soundId`) at the ghost's world position by parenting a `Sound` to the ghost model. UI SFX: implement `AudioController.playUI(key)` with a lookup table of UI sound asset IDs for all 5 events from PRD §17.4 (`capture_success`, `capture_fail`, `level_up`, `minigame_hit`, `quest_complete`).
- **Files:** `src/client/systems/AudioController.luau`
- **Output:** Ghost sounds play at ghost location when triggered. UI sounds play on relevant events.
- **DoD:**
  - [ ] Signature sound plays at ghost model position (spatial audio) on `"Triggered"` state
  - [ ] Signature sound stops when ghost despawns
  - [ ] All 5 UI SFX play at correct moments
  - [ ] `playUI` does not error if called with unknown key (silent fail + warn)
  - [ ] Multiple ghosts triggering simultaneously each play their own sound independently

**Deps:** T-41

---

## Phase 10 — Tutorial

---

### T-43 · Tutorial — Server Side

- **Description:** Add tutorial gate logic to the server. On player join (after `PlayerDataManager.OnLoaded`), check `data.tutorialDone`. If `false`, fire `TutorialStep` RemoteEvent with `step = 0`. Listen for `RequestSkipTutorial` RemoteFunction — set `data.tutorialDone = true` and save. Implement the scripted tutorial Pocong: when server receives a signal that the player has reached tutorial step 3, spawn a special ghost instance at a fixed world position (Hub island, visible point) with `resistance = 1`, `catchRate = 1.0` override (always succeeds), behavior `"Wanderer"` frozen in place. Mark this instance as tutorial-only so `GhostSpawnManager` does not count it toward the 20-ghost cap.
- **Files:** `src/server/init.server.luau` or `src/server/systems/TutorialManager.luau`
- **Output:** New players always go through the tutorial. Tutorial Pocong is always capturable on first throw.
- **DoD:**
  - [ ] Players with `tutorialDone = false` receive `TutorialStep` event on join
  - [ ] Players with `tutorialDone = true` skip tutorial entirely
  - [ ] Tutorial Pocong spawns at fixed position and cannot move
  - [ ] Tutorial Pocong always succeeds on first bottle throw regardless of bottle type
  - [ ] Tutorial Pocong counts as first Compendium entry for real (not a throwaway)
  - [ ] `data.tutorialDone = true` saved after tutorial completes or is skipped

**Deps:** T-11, T-13, T-18, T-09

---

### T-44 · Tutorial — Client Side

- **Description:** Implement `src/client/systems/TutorialController.luau` per PRD §19. Listen to `TutorialStep` RemoteEvent. On step 0: show NPC chat bubble with `TUT_STEP0` text + walking arrow indicator toward cold zone. On step 1: highlight SCAN button with pulsing outline + show `TUT_STEP1` bubble. On step 2: player taps SCAN → advance to step 2, show `TUT_STEP2` bubble. On step 3 (server fires after scripted Pocong spawns): show `TUT_STEP3` bubble; highlight the ghost model. On step 4: MantraTap runs at 50% speed (pass `timeLimit * 2` in config). On step 5: auto-open Compendium after capture success; show `TUT_STEP4` bubble. On step 6: highlight mini-map; show `TUT_STEP5` bubble; call `RequestSkipTutorial`. Show "Skip" button (calls `RequestSkipTutorial`) visible from step 0 onward.
- **Files:** `src/client/systems/TutorialController.luau`
- **Output:** New players experience a guided 3-minute tutorial that ends naturally in the open world.
- **DoD:**
  - [ ] Tutorial steps fire in correct sequence — server event advances steps
  - [ ] NPC chat bubbles are positioned above the NPC model, not floating in screen space
  - [ ] SCAN button pulse animation shows on step 1
  - [ ] MantraTap tutorial runs at half speed (longer timer)
  - [ ] Compendium auto-opens after capture success with animation
  - [ ] Skip button visible from step 0; calling it ends tutorial immediately
  - [ ] Tutorial does not restart on rejoin once `tutorialDone = true`

**Deps:** T-26, T-27, T-29, T-31, T-32, T-34, T-35, T-43

---

## Phase 11 — Social Features

---

### T-45 · Companion Ghost

- **Description:** Implement the companion ghost system per GDD §12.3. Server-side: after any successful capture, determine the player's rarest captured ghost by iterating `data.compendium` keys and finding the highest rarity. Update `data.companion = ghostId`. Fire `CompanionSet` RemoteEvent with `{ ghostId }`. Client-side: on `CompanionSet`, despawn the previous companion model (if any), clone the new ghost model from `ReplicatedStorage/Assets/Ghosts/{ghostId}`, scale it to 40% size, attach it to follow the player using a `BodyPosition` or lerp in a `RunService.Heartbeat` loop offset 3 studs behind and 1 stud to the right of `HumanoidRootPart`. Companion does not interact with game systems (no hitbox, no collisions).
- **Files:** Server: `src/server/systems/CaptureSession.luau`. Client: `src/client/systems/CompanionController.luau`
- **Output:** Player's rarest captured ghost visibly follows them as a companion.
- **DoD:**
  - [ ] Companion updates to the new ghost if a rarer one is captured
  - [ ] Companion is 40% scale and visually distinct from world ghosts
  - [ ] Companion has no collision (`CanCollide = false`, `CanTouch = false`)
  - [ ] Companion follows smoothly without rubber-banding
  - [ ] `CompanionSet` with `ghostId = nil` despawns companion (handles edge case)
  - [ ] Companion is client-local — other players do not see it (or it is replicated but not interactable — decide and document)

**Deps:** T-09, T-18, T-27

---

### T-46 · View Other Player Compendium

- **Description:** Wire the "tap player to view their compendium" feature per GDD §12.3 / PRD §13.5. Client: when player taps on another player's character model (via `ClickDetector` or `ProximityPrompt` on the character), call `RequestViewCompendium:InvokeServer(targetUserId)`. Server: `RequestViewCompendium` handler checks if `targetUserId` is `nil` (own) or a valid player currently in the server; returns their compendium data. Client: open `CompendiumUI` in read-only mode with banner "Compendium of [Username]" — capture stats shown but no filter or interaction possible.
- **Files:** `src/client/systems/CompendiumUI.luau`, `src/server/init.server.luau`
- **Output:** Tapping another player opens their compendium in read-only view.
- **DoD:**
  - [ ] `ProximityPrompt` or `ClickDetector` appears on player character models
  - [ ] Prompt does not appear on own character
  - [ ] Other player's compendium opens correctly in read-only mode
  - [ ] Server rejects `RequestViewCompendium` if `targetUserId` is not currently in server
  - [ ] Banner shows correct username
  - [ ] No edit/purchase actions visible in other-player view

**Deps:** T-32, T-09

---

## Phase 12 — Integration & Bootstrap

---

### T-47 · Server Bootstrap

- **Description:** Implement `src/server/init.server.luau` as the ordered startup sequence. Systems must initialize in dependency order: (1) Create Remotes (T-09), (2) `PlayerDataManager` init (T-11), (3) `WorldBuilder` — await `WorldBuilder.Ready` before continuing (T-12), (4) `GhostSpawnManager.init()` (T-13), (5) `CaptureSession.init()` (T-18), (6) `QuestManager.init()` (T-25), (7) `EconomyManager.init()` (T-22/T-23), (8) `MarketplaceService.ProcessReceipt` assignment (T-23). Each system `init()` call wrapped in `pcall`; log any init failure and continue (don't crash server on non-critical system failure).
- **Files:** `src/server/init.server.luau`
- **Output:** All server systems start in the correct order. Server is fully operational before any player joins.
- **DoD:**
  - [ ] World is built before `Players.PlayerAdded` fires for the first player
  - [ ] All systems initialize without error in a clean server start
  - [ ] If one non-critical system fails to init (e.g. audio config), server continues running
  - [ ] `ProcessReceipt` is assigned exactly once
  - [ ] No system starts before its dependency system has completed init

**Deps:** T-09, T-11, T-12, T-13, T-18, T-19, T-20, T-21, T-22, T-23, T-24, T-25

---

### T-48 · Client Bootstrap

- **Description:** Implement `src/client/init.client.luau` as the ordered client startup sequence: (1) `LocalizationBridge.init()` — await translator ready, (2) `UIManager.init()` — detect platform, (3) `ZoneDetector.init()`, (4) `AudioController.init()`, (5) `HUD.init()` — register with UIManager, (6) `CompendiumUI.init()`, (7) `ShopUI.init()`, (8) `MiniGameController.init()`, (9) `TutorialController.init()`, (10) `CompanionController.init()`. Wait for character to load before starting ZoneDetector and HUD (character-dependent systems). Each step wrapped in `pcall`; log failure without crashing client.
- **Files:** `src/client/init.client.luau`
- **Output:** All client systems start correctly. HUD visible within 2s of character spawn.
- **DoD:**
  - [ ] `LocalizationBridge` ready before any UI text is set
  - [ ] `UIManager` platform detected before any UI layout is applied
  - [ ] ZoneDetector only starts after `LocalPlayer.Character` is available
  - [ ] HUD visible within 2s of character spawn
  - [ ] Tutorial fires only after HUD is ready (so tutorial highlights have targets)
  - [ ] No `require` error in output console

**Deps:** T-26, T-27, T-28, T-29, T-30, T-31, T-32, T-33, T-34, T-41, T-42, T-44, T-45

---

## Phase 13 — Anti-Exploit & Hardening

---

### T-49 · RemoteFunction Rate Limiting

- **Description:** Add server-side rate limiting to all RemoteFunctions per PRD §22. `RequestScan`: enforce min 8s between calls per player using a `{ [userId]: lastCallTime }` table. `RequestCapture`: enforce min 3s between calls per player. `RequestMiniGameInput`: enforce min 0.1s between calls per player per instance (prevent input spam). `RequestBuyBottle`: enforce min 2s between calls per player. Any call within the cooldown window returns `{ ok = false, error = "RATE_LIMITED" }` without processing.
- **Files:** `src/server/systems/CaptureSession.luau`, `src/server/systems/EconomyManager.luau`, `src/server/init.server.luau`
- **Output:** Rate limiting prevents exploit-style rapid RemoteFunction invocations.
- **DoD:**
  - [ ] `RequestScan` second call within 8s returns `RATE_LIMITED`
  - [ ] `RequestCapture` second call within 3s returns `RATE_LIMITED`
  - [ ] `RequestMiniGameInput` call within 0.1s of previous returns `RATE_LIMITED`
  - [ ] Rate limit tables are cleaned up when player leaves (no memory leak)
  - [ ] Legitimate gameplay is not affected — limits are tight enough to block exploits but not normal play

**Deps:** T-18, T-22, T-47

---

### T-50 · Anti-Exploit Audit

- **Description:** Review all server RemoteFunction handlers against the anti-exploit rules in PRD §22. Verify: (1) No profile mutation happens client-side — trace every write path. (2) `RequestCapture` validates proximity, ghost state, bottle ownership. (3) `RequestMiniGameInput` validates step sequence — cannot submit step 5 without completing steps 1–4. (4) Resistance value is never included in any RemoteEvent payload to the client. (5) Shard balance is never included in any client→server message as a trusted value. (6) `ProcessReceipt` idempotency check is in place. (7) Ghost positions are server-authoritative. Fix any found gaps.
- **Files:** All server system files
- **Output:** A review pass confirming all 10 anti-exploit rules from PRD §22 are implemented. Any gaps are fixed.
- **DoD:**
  - [ ] All 10 rules from PRD §22 verified with corresponding code locations documented (inline comment or separate note)
  - [ ] No `RemoteEvent` carries resistance value or catch rate in payload
  - [ ] No `RemoteFunction` trusts a numeric value from client for economy operations
  - [ ] Step-skipping in MantraTap is impossible (tested by sending step=5 directly)
  - [ ] Duplicate `ProcessReceipt` with same receipt ID grants product only once

**Deps:** T-47, T-49

---

*Last updated: 2026-05-10 · JihadPixel*
