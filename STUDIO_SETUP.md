# Studio Setup Guide — Hantu Anjay

Step-by-step instructions for configuring Roblox Studio so all scripts run correctly. Complete every section in order. **Do not skip steps** — missing assets or wrong names cause silent failures or `warn` spam in the Output window.

---

## 1. Prerequisites

### 1a. Install Rojo Studio Plugin
1. Open Roblox Studio.
2. Go to **Plugins → Manage Plugins → Marketplace**.
3. Search **"Rojo"** and install the official Rojo plugin (by Roblox).
4. Restart Studio after installation.

### 1b. Install Wally Packages
In your terminal (project root):
```bash
wally install
```
This populates `Packages/` and `ServerPackages/` with all library dependencies (Signal, Promise, ProfileService, etc.). Rojo syncs these folders into the game — they must exist before syncing.

### 1c. Start Rojo Sync
```bash
rojo serve
```
Then in Studio: **Plugins → Rojo → Connect** (default port 34872). Accept the prompt to sync. All `src/` files now live-sync into the game tree.

---

## 2. Game Settings

Open **Home → Game Settings** (or **File → Game Settings**):

| Setting | Value |
|---------|-------|
| Max Players | **50** |
| Allow HTTP Requests | **On** (needed for ProfileService datastore) |

In **Home → Game Settings → Avatar**:
- Leave avatar type at default (R15 recommended).

---

## 3. SpawnLocation

The Hub island center is at `(0, 50, 0)`. Place the default **SpawnLocation** there:

1. In the **Explorer**, select the default `SpawnLocation` (usually at origin).
2. In **Properties**, set **Position** to `0, 50, 0`.
3. Set **Neutral** = `true` (all teams spawn here).
4. Set **Size** to `6, 1, 6` (small pad — players land on the Hub model surface, not this part).

---

## 4. Workspace — World Folder

All islands (Hub + biomes) live inside **`Workspace.World`**. Create this folder before placing any models.

1. In **Explorer**, right-click **Workspace** → **Insert Object → Folder**.
2. Name it exactly **`World`** (case-sensitive).

WorldBuilder reads models from this folder at runtime. If it cannot find `Workspace.World`, it creates one automatically and also searches bare Workspace for models named after each zone.

> **`Workspace.Ghosts`** is created by the server at runtime — do **not** pre-create it.

---

## 5. Hub Island Model

Build the Hub island directly in Studio and place it inside `Workspace.World`.

1. Build or import your Hub island geometry in Workspace.
2. Select all Hub parts → **Group** (`Ctrl+G`) to make a Model.
3. Name the Model **`Hub`** (exact, case-sensitive).
4. Set **PrimaryPart** to any flat surface part on the Hub.
5. **Move the model into `Workspace.World`** (drag in Explorer).
6. Position it however you like — you are in charge of placement. The suggested center is around `(0, 50, 0)` to match `HUB_SPAWN` in Constants and the SpawnLocation above.

**WorldBuilder applies `CollisionGroup = "Safe"` to every BasePart inside `Hub` automatically** — ghost proximity detection ignores players standing on the Hub. No manual tagging needed.

---

## 6. Biome Island Models

Build each biome island directly in Studio, place it in `Workspace.World`, and add **HauntPoint** marker Parts.

### 6a. Build and name each model

For each of the 6 zones:
1. Build the island geometry in Studio.
2. Select all parts → **Group** (`Ctrl+G`).
3. Name the Model to match the **Model Name** in the table below (exact, case-sensitive).
4. Set **PrimaryPart** to the island's base/ground part.
5. **Place the model inside `Workspace.World`**.
6. Position the island where you want it. The suggested world positions are:

| Zone ID | Model Name | Suggested Center (X, Y, Z) | Footprint |
|---------|-----------|---------------------------|-----------|
| Kuburan | `Kuburan` | -280, 30, 0 | ~90×90 studs |
| KampungTua | `KampungTua` | 0, 60, 270 | ~90×90 studs |
| HutanBambu | `HutanBambu` | 220, 75, 150 | ~90×90 studs |
| PantaiSepi | `PantaiSepi` | 250, 15, -220 | ~90×90 studs |
| KuburanCina | `KuburanCina` | -200, 40, -240 | ~90×90 studs |
| SawahHaunted | `SawahHaunted` | 60, 55, -300 | ~90×90 studs |

> If you place islands at significantly different positions, update `detectionVolume` in `src/shared/ZoneDefs.luau` to match the new AABB bounds.

### 6b. HauntPoint Parts — required

Each biome model **must** contain a specific number of Parts named **`HauntPoint`**. GhostSpawnManager and ShardManager use these for ghost/shard spawn positions.

| Model | Required HauntPoint count |
|-------|--------------------------|
| Kuburan | **4** |
| KampungTua | **5** |
| HutanBambu | **3** |
| PantaiSepi | **3** |
| KuburanCina | **4** |
| SawahHaunted | **4** |

**HauntPoint setup per part:**
1. Insert a **Part** inside the biome model (anywhere in its hierarchy — scripts use `GetDescendants`).
2. Name it **`HauntPoint`** (exact spelling).
3. Set **Anchored** = `true`.
4. Set **CanCollide** = `false`.
5. Set **Transparency** = `1` (invisible at runtime; keep `0` during editing to see them).
6. Position it on or slightly above the island surface at a logical ghost-spawn spot.
7. Repeat until you have the required count.

> If the count is wrong, WorldBuilder prints: `[WorldBuilder] Kuburan: expected 4 HauntPoints, got N`. Game still runs but spawn distribution will be uneven.

### 6c. Zone detection volumes

Scripts use AABB detection (no Parts needed) for zone detection. The bounds are in `src/shared/ZoneDefs.luau`:

| Zone | Min (X, Y, Z) | Max (X, Y, Z) |
|------|---------------|---------------|
| Kuburan | -325, 20, -45 | -235, 90, 45 |
| KampungTua | -50, 50, 225 | 50, 130, 315 |
| HutanBambu | 175, 65, 105 | 265, 145, 195 |
| PantaiSepi | 205, 5, -265 | 295, 60, -175 |
| KuburanCina | -245, 30, -285 | -155, 100, -195 |
| SawahHaunted | 15, 45, -345 | 105, 115, -255 |

If you reposition an island, update its `detectionVolume` in `ZoneDefs.luau` to cover the new bounds.

### 6d. ColdZone Parts (optional, for SCAN trigger enhancement)

GhostAI wires `Touched` events on Parts named **`ColdZone`** found inside each island model. When a player walks through a ColdZone, the nearest Patrolling ghost is triggered. These are purely optional — ghost proximity and idle detection still work without them.

To add ColdZones:
1. Insert a Part inside a biome model.
2. Name it **`ColdZone`**.
3. Set **CanCollide** = `false`, **Transparency** = `1`.
4. Size and position it over any area where ghost activity should be heightened.

---

## 7. Ghost Models

Ghost models are used as templates: cloned into `Workspace.Ghosts` during gameplay, rendered in CompendiumUI ViewportFrames, and attached as companion ghosts.

All 30 ghost models live in `ReplicatedStorage.Assets.Ghosts`.

### 7a. Create the Assets folder hierarchy

In **Explorer**, right-click **ReplicatedStorage** → **Insert Object → Folder**:

```
ReplicatedStorage
└── Assets
    └── Ghosts    ← Folder (ghost model templates)
```

### 7b. Model naming

Each model **Name** must match the `modelName` field in `GhostDefs.luau`:

**Common (10):**
`Pocong`, `Kuntilanak`, `WeweGombel`, `Banaspati`, `SundelBolong`, `Toyol`, `Tuyul`, `LeakWeak`, `GenderuwoJr`, `Jenglot`

**Rare (10):**
`Rangda`, `OrangBunian`, `HantuRaya`, `BabiNgepet`, `Palasik`, `Penanggalan`, `AswangMild`, `ManananggalHalf`, `KraSue`, `PhiPop`

**Epic (7):**
`NyiBlorong`, `BataraKala`, `RangdaTrue`, `Mahisasura`, `Leyak`, `SantetSpecter`, `HantuKopek`

**Mythic (3):**
`NyiRoroKidul`, `DewiDurga`, `BataraGuruShadow`

### 7c. Ghost model setup per model

1. Build or import the ghost mesh/rig.
2. Group into a **Model** and name it exactly as listed above.
3. Set **PrimaryPart** to the root/torso BasePart.
4. Place the model inside `ReplicatedStorage.Assets.Ghosts`.

**Required properties on every BasePart inside each ghost model:**

| Property | Value | Reason |
|----------|-------|--------|
| Anchored | `false` | Model moved by scripts |
| CanCollide | `false` | Ghosts do not block players |
| CanTouch | `false` | Prevents false touch events |
| Massless | `true` | Prevents physics weight |

**Humanoid (optional but recommended):**
- Add a **Humanoid** for proper R15 rig support.
- Set `Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None`.
- Set `Humanoid.HealthDisplayDistance = 0`.

**Scale for companion:** CompanionController calls `model:ScaleTo(0.4)` — ensure the model has a Humanoid with a valid rig so `ScaleTo` works.

---

## 8. Localization Table

`LocalizationBridge` uses Roblox's built-in `LocalizationService`. The game needs a `LocalizationTable` asset with all UI and ghost name/lore strings.

### 8a. Create the LocalizationTable

1. In **Explorer**, right-click **ReplicatedStorage** → **Insert Object** → `LocalizationTable`.
2. Name it **`LocalizationTable`** (default name is fine).
3. In Properties, set **Source Language** to `id` (Indonesian, base language).

### 8b. Required localization keys

**Tutorial steps:**
`TUT_STEP0`, `TUT_STEP1`, `TUT_STEP2`, `TUT_STEP3`, `TUT_STEP4`, `TUT_STEP5`

**Rank titles:**
`RANK_PEMULA_TITLE`, `RANK_JAGOAN_TITLE`, `RANK_PARANORMAL_TITLE`, `RANK_DUKUN_TITLE`, `RANK_LEGENDA_TITLE`

**Ghost names and lore (60 keys):**
For each ghost ID: `GHOST_{ID}_NAME` and `GHOST_{ID}_LORE`. Example:
- `GHOST_POCONG_NAME` → `Pocong`
- `GHOST_POCONG_LORE` → *(lore text)*

Ghost IDs: `POCONG`, `KUNTILANAK`, `WEWEGOMBEL`, `BANASPATI`, `SUNDELBOLONG`, `TOYOL`, `TUYUL`, `LEAKWEAK`, `GENDERUWOJR`, `JENGLOT`, `RANGDA`, `ORANGBUNIAN`, `HANTURAYA`, `BABINGEPET`, `PALASIK`, `PENANGGALAN`, `ASWANGMILD`, `MANANANGGALHALF`, `KRASUE`, `PHIPOP`, `NYIBLORONG`, `BATARAKALA`, `RANGDATRUE`, `MAHISASURA`, `LEYAK`, `SANTETSPECTER`, `HANTUKOPEK`, `NYIROROKIDUL`, `DEWIDURGA`, `BATAGARUSHADOW`

---

## 9. Optional: TutorialNPC

If present in Workspace, `TutorialController` attaches a `BillboardGui` chat bubble above it for tutorial dialogue. If absent, dialogue falls back to a screen-space label — tutorial still works.

1. Create or import an NPC model anywhere in Workspace.
2. Name it **`TutorialNPC`** (searched recursively with `FindFirstChild("TutorialNPC", true)`).
3. Set **PrimaryPart** to the head or torso.
4. Position it on the Hub island near the spawn point.
5. Set **Anchored = true** on all parts.

---

## 10. Collision Groups

The `"Safe"` collision group is registered automatically by WorldBuilder at startup. **No manual setup required.**

Hub model parts receive `CollisionGroup = "Safe"` automatically when the server starts.

---

## 11. Runtime-Created Workspace Folders

| Folder | Behaviour |
|--------|-----------|
| `Workspace.World` | WorldBuilder creates if absent; you can pre-create it and place islands inside |
| `Workspace.Ghosts` | Always created by WorldBuilder at runtime — do **not** pre-create |

> If `Workspace.Ghosts` already exists when the server starts (leftover from a previous test session), delete it before playtesting to avoid duplicate folders.

---

## 12. Gamepass and Product IDs

Before publishing, fill in the real IDs in `src/shared/Constants.luau`:

```lua
GAMEPASS_ID_VIP = 0,        -- replace with real gamepass ID
GAMEPASS_ID_BOTTLE = 0,     -- Extra Bottle Bag gamepass
GAMEPASS_ID_AUTOSHARD = 0,  -- Auto-Shard Collector gamepass

PRODUCT_ID_SHARDS_100 = 0,  -- 100 Spirit Shards pack
PRODUCT_ID_SHARDS_500 = 0,  -- 500 Spirit Shards pack
PRODUCT_ID_SHARDS_1500 = 0, -- 1500 Spirit Shards pack
```

---

## 13. Audio Assets

`AudioController` plays ambient sounds per zone (`ambientSoundId` in `ZoneDefs.luau`) and ghost-proximity tension audio (`soundId` in `GhostDefs.luau`). Both are `0` (placeholder) by default.

To add audio:
1. Upload audio files via **Creator Hub → Audio** and copy each asset ID.
2. Set `ambientSoundId` for each zone in `src/shared/ZoneDefs.luau`.
3. Set `soundId` for each ghost in `src/shared/GhostDefs.luau`.

---

## 14. Verification Checklist

After setup, do a **Play Solo** test and check the **Output** window:

| Message | Meaning |
|---------|---------|
| `[WorldBuilder] Build complete` | All islands found and registered |
| `[WorldBuilder] Biome model not found in Workspace: X` | Model missing or misnamed in Workspace.World |
| `[WorldBuilder] X: expected N HauntPoints, got M` | Wrong HauntPoint count in a biome model |
| `[WorldBuilder] Hub model not found` | Hub model missing or misnamed |
| `[ShardManager] Shards placed across N zones` | SpiritShard items spawned correctly |
| `[PlayerDataManager] LoadProfileAsync error` | Datastore issue (expected in Studio first run) |

**The game is ready when:**
- No `[WorldBuilder]` error lines appear.
- All 6 biome models are visible in `Workspace.World`.
- `Workspace.Ghosts` folder exists (created at runtime).
- Tutorial fires for new players (step 0 message appears on screen).
