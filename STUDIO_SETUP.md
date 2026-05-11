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
| Max Players | **8** |
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

> The Hub island model is placed by WorldBuilder at runtime using `HUB_SPAWN = Vector3.new(0, 50, 0)`. The SpawnLocation just needs to be in the same general area so players appear near the Hub.

---

## 4. ReplicatedStorage — Assets Folder

All game assets live under `ReplicatedStorage.Assets`. This folder and its subfolders are **not** created by scripts — you must build the hierarchy manually in the Explorer.

### 4a. Create the folder hierarchy

In the **Explorer**, right-click **ReplicatedStorage** → **Insert Object → Folder**:

```
ReplicatedStorage
└── Assets                    ← Folder
    ├── Biomes                ← Folder
    ├── Ghosts                ← Folder
    └── Hub                   ← Model (see §5)
```

Name each exactly as shown (case-sensitive).

---

## 5. Hub Island Model

The Hub is the central safe island where players spawn. It is placed at `(0, 50, 0)` by WorldBuilder.

1. Create or import your Hub island geometry.
2. In **Explorer**, group all Hub parts into a **Model**: right-click selected parts → **Group** (`Ctrl+G`).
3. Name the Model **`Hub`** (exact, case-sensitive).
4. Set the Model's **PrimaryPart** to any flat surface part on the Hub (e.g. the floor/ground part).
5. Place the `Hub` model **inside `ReplicatedStorage.Assets`** (not in Workspace — WorldBuilder clones and places it).

**Hub model requirements:**
- All BaseParts inside Hub automatically receive `CollisionGroup = "Safe"` when WorldBuilder places it, so ghost proximity detection ignores players on the Hub. No manual tagging needed.
- Include any decorative elements, portals, or signage as children of the Hub model.
- The Hub model's bounding box should be roughly centered so that `PivotTo(CFrame.new(0, 50, 0))` places it correctly in the world.

---

## 6. Biome Island Models

WorldBuilder reads `ReplicatedStorage.Assets.Biomes` and clones one model per zone. Each model is positioned using its `worldOffset` from ZoneDefs.

### 6a. Create each biome model

For each zone, follow these steps:
1. Build the island geometry in **Workspace** (easier for visual editing).
2. When done: select all parts → **Group** (`Ctrl+G`) → rename the Model.
3. **Move the Model into `ReplicatedStorage.Assets.Biomes`** (drag in Explorer).
4. Set the Model's **PrimaryPart** to the island's base/ground part.

### 6b. Biome model names and positions

The model **Name** must match `modelName` in ZoneDefs exactly:

| Zone ID | Model Name | World Offset (X, Y, Z) | Footprint (approx) |
|---------|-----------|------------------------|---------------------|
| Kuburan | `Kuburan` | -280, 30, 0 | 90×90 studs |
| KampungTua | `KampungTua` | 0, 60, 270 | 90×90 studs |
| HutanBambu | `HutanBambu` | 220, 75, 150 | 90×90 studs |
| PantaiSepi | `PantaiSepi` | 250, 15, -220 | 90×90 studs |
| KuburanCina | `KuburanCina` | -200, 40, -240 | 90×90 studs |
| SawahHaunted | `SawahHaunted` | 60, 55, -300 | 90×90 studs |

> These offsets are used as the island's `PivotTo` target. Design each model with its center at the local origin `(0, 0, 0)` so `PivotTo` places it correctly.

### 6c. HauntPoint Parts — required

Each biome model **must** contain a specific number of BasePart children (or descendants) named exactly **`HauntPoint`**. GhostSpawnManager reads these parts to know where ghosts can appear.

| Model | Required HauntPoint count |
|-------|--------------------------|
| Kuburan | **4** |
| KampungTua | **5** |
| HutanBambu | **3** |
| PantaiSepi | **3** |
| KuburanCina | **4** |
| SawahHaunted | **4** |

**HauntPoint setup per part:**
1. Insert a **Part** inside the biome model (anywhere in the hierarchy — scripts use `GetDescendants`).
2. Name it **`HauntPoint`** (exact spelling).
3. Set **Size**: `4, 4, 4` (used as spawn location; visual size does not matter in production — you can make it a small invisible marker).
4. Set **Anchored**: `true`.
5. Set **CanCollide**: `false`.
6. Set **Transparency**: `1` (invisible in play mode; keep visible at `0` during editing if you want to see them).
7. Position it **on or slightly above the island surface** at a logical spawn location (near gravestones, trees, water's edge, etc.).
8. Repeat until you have the required count for that model.

> **Warning:** If the count does not match, WorldBuilder prints a warning in the Output window: `[WorldBuilder] Kuburan: expected 4 HauntPoints, got N`. The game still runs but spawn distribution will be uneven.

### 6d. Zone detection volumes

The scripts use AABB (box) detection, not Parts, for zone detection — you do **not** need to add any detection Part to the models. The bounds are hardcoded in `ZoneDefs.luau`:

| Zone | Min (X, Y, Z) | Max (X, Y, Z) |
|------|---------------|---------------|
| Kuburan | -325, 20, -45 | -235, 90, 45 |
| KampungTua | -50, 50, 225 | 50, 130, 315 |
| HutanBambu | 175, 65, 105 | 265, 145, 195 |
| PantaiSepi | 205, 5, -265 | 295, 60, -175 |
| KuburanCina | -245, 30, -285 | -155, 100, -195 |
| SawahHaunted | 15, 45, -345 | 105, 115, -255 |

Keep biome islands within these bounds. If you resize or reposition an island significantly, update `ZoneDefs.luau` to match.

---

## 7. Ghost Models

Ghost models are used in two places:
- **CompendiumUI**: renders each ghost in a `ViewportFrame` for the compendium card.
- **CompanionController**: clones the companion ghost and attaches it to the local player.
- **GhostSpawnManager**: clones ghost models into `Workspace.Ghosts` during gameplay.

All 30 ghost models live in `ReplicatedStorage.Assets.Ghosts`.

### 7a. Model naming

Each model **Name** must match the `modelName` field in `GhostDefs.luau`. These are identical to the ghost ID strings:

**Common (10):**
`Pocong`, `Kuntilanak`, `WeweGombel`, `Banaspati`, `SundelBolong`, `Toyol`, `Tuyul`, `LeakWeak`, `GenderuwoJr`, `Jenglot`

**Rare (10):**
`Rangda`, `OrangBunian`, `HantuRaya`, `BabiNgepet`, `Palasik`, `Penanggalan`, `AswangMild`, `ManananggalHalf`, `KraSue`, `PhiPop`

**Epic (7):**
`NyiBlorong`, `BataraKala`, `RangdaTrue`, `Mahisasura`, `Leyak`, `SantetSpecter`, `HantuKopek`

**Mythic (3):**
`NyiRoroKidul`, `DewiDurga`, `BataraGuruShadow`

### 7b. Ghost model setup per model

For each of the 30 models:
1. Build or import the ghost mesh/rig.
2. Group into a **Model** and set its **Name** exactly as listed above.
3. Set **PrimaryPart** to the root/torso BasePart (scripts use `PrimaryPart` for positioning).
4. Place the model inside `ReplicatedStorage.Assets.Ghosts`.

**Required properties on every BasePart inside the ghost model:**

| Property | Value | Reason |
|----------|-------|--------|
| Anchored | `false` | Model must be moveable by scripts |
| CanCollide | `false` | Ghosts should not block players |
| CanTouch | `false` | Prevents false touch events |
| Massless | `true` | Prevents physics weight affecting movement |

> When used as a companion, CompanionController sets these programmatically at clone time. When spawned in-world by GhostSpawnManager, the model is moved via `PivotTo`. Set these in the template anyway so the model behaves correctly before the script runs.

**Humanoid (optional but recommended):**
- Add a **Humanoid** inside the model for proper R15 rig support and `ScaleTo` compatibility.
- Set `Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None` (hides default health bar).
- Set `Humanoid.HealthDisplayDistance = 0`.

**Scale for companion:**
- CompanionController calls `model:ScaleTo(0.4)` — ensure the model has a **Humanoid** with a valid `HumanoidDescription` or at minimum a well-structured rig so `ScaleTo` works.

---

## 8. Localization Table

`LocalizationBridge` uses Roblox's built-in `LocalizationService`. The game needs a `LocalizationTable` asset with all UI and ghost name/lore strings.

### 8a. Create the LocalizationTable

1. In the **Explorer**, right-click **ReplicatedStorage** → **Insert Object** → type `LocalizationTable` → select it.
2. Name it **`LocalizationTable`** (the default name is fine).
3. In Properties, set **Source Language** to `id` (Indonesian, the base language).

> Alternatively, use **Home → Localization → Configure Localization** to open the Studio localization editor and upload a CSV.

### 8b. Required localization keys

Add at minimum these keys. The game falls back to the raw key string if a key is missing (not a crash, but text will show as `TUT_STEP0`, etc.).

**Tutorial steps:**
- `TUT_STEP0` — Welcome message (step 0)
- `TUT_STEP1` — Scan hint (step 1)
- `TUT_STEP2` — Ghost approaching (step 2)
- `TUT_STEP3` — Catch it! (step 3)
- `TUT_STEP4` — Check your compendium (step 5)
- `TUT_STEP5` — Explore the map (step 6)

**Rank titles:**
- `RANK_PEMULA_TITLE`, `RANK_JAGOAN_TITLE`, `RANK_PARANORMAL_TITLE`, `RANK_DUKUN_TITLE`, `RANK_LEGENDA_TITLE`

**Ghost names and lore (60 keys total):**
For each ghost ID, add two keys: `GHOST_{ID}_NAME` and `GHOST_{ID}_LORE`. Example for Pocong:
- `GHOST_POCONG_NAME` → `Pocong`
- `GHOST_POCONG_LORE` → *(lore text)*

Ghost IDs: `POCONG`, `KUNTILANAK`, `WEWEGOMBEL`, `BANASPATI`, `SUNDELBOLONG`, `TOYOL`, `TUYUL`, `LEAKWEAK`, `GENDERUWOJR`, `JENGLOT`, `RANGDA`, `ORANGBUNIAN`, `HANTURAYA`, `BABINGEPET`, `PALASIK`, `PENANGGALAN`, `ASWANGMILD`, `MANANANGGALHALF`, `KRASUE`, `PHIPOP`, `NYIBLORONG`, `BATARAKALA`, `RANGDATRUE`, `MAHISASURA`, `LEYAK`, `SANTETSPECTER`, `HANTUKOPEK`, `NYIROROKIDUL`, `DEWIDURGA`, `BATAGARUSHADOW`

> The key format uses the `nameKey` / `loreKey` fields from `GhostDefs.luau` (e.g. `nameKey = "GHOST_POCONG_NAME"`).

---

## 9. Optional: TutorialNPC

If present in **Workspace**, `TutorialController` attaches a `BillboardGui` chat bubble above it for tutorial dialogue. If absent, dialogue falls back to a screen-space label — the tutorial still works.

### 9a. Setup

1. Create or import an NPC model in Workspace (any humanoid model, static rig, or simple dummy).
2. Name it **`TutorialNPC`** (exact, searched recursively with `workspace:FindFirstChild("TutorialNPC", true)`).
3. Set **PrimaryPart** to the character's head or torso (the bubble appears at `StudsOffset = (0, 4, 0)` above this part).
4. Position it on the Hub island near the spawn point, facing the player.
5. Set **Anchored = true** on all parts (it is a static prop, not a moving character).

---

## 10. Collision Groups

The `"Safe"` collision group is registered automatically by WorldBuilder via `PhysicsService:RegisterCollisionGroup("Safe")` (wrapped in `pcall`) when the server starts. **No manual setup required** in Studio.

All BaseParts inside the Hub model receive `CollisionGroup = "Safe"` programmatically. This prevents ghost proximity checks from triggering on players standing in the Hub.

> If you test in Studio with **Play Solo** and see a `PhysicsService` warning about collision groups, it is safe to ignore — the `pcall` catches it.

---

## 11. Runtime-Created Workspace Folders

These folders are created by server scripts at runtime — **do not create them manually** in Studio:

| Folder | Created by | Purpose |
|--------|-----------|---------|
| `Workspace.World` | `WorldBuilder.Build()` | Parent for all placed island models |
| `Workspace.Ghosts` | `WorldBuilder.Build()` | Parent for all spawned ghost models |

If they already exist when the server starts (e.g. you left them from a previous test session), WorldBuilder creates duplicates. Delete any pre-existing `World` or `Ghosts` folders before publishing.

---

## 12. Gamepass and Product IDs

Before publishing to production, fill in the real IDs in `src/shared/Constants.luau`:

```lua
-- Gamepass IDs
GAMEPASS_ID_VIP = 0,       -- replace 0 with real gamepass ID
GAMEPASS_ID_BOTTLE = 0,    -- Extra Bottle Bag gamepass
GAMEPASS_ID_AUTOSHARD = 0, -- Auto-Shard Collector gamepass

-- Developer Product IDs
PRODUCT_ID_SHARDS_100 = 0,  -- 100 Spirit Shards pack
PRODUCT_ID_SHARDS_500 = 0,  -- 500 Spirit Shards pack
PRODUCT_ID_SHARDS_1500 = 0, -- 1500 Spirit Shards pack
```

To get gamepass IDs:
1. **Creator Hub → Monetization → Passes** → create each pass → copy the numeric ID from the URL.

To get developer product IDs:
1. **Creator Hub → Monetization → Developer Products** → create each product → copy the numeric ID.

> With IDs set to `0`, `MarketplaceService:UserOwnsGamePassAsync` always returns `false` and purchases silently fail — safe for testing but required for production.

---

## 13. Audio Assets

`AudioController` plays ambient sounds per zone using the `ambientSoundId` field in `ZoneDefs.luau`, and ghost-proximity tension audio using `soundId` in `GhostDefs.luau`. Both are currently `0` (placeholder).

To add audio:
1. Upload audio files via **Creator Hub → Audio** and copy each asset ID.
2. Set `ambientSoundId` for each zone in `src/shared/ZoneDefs.luau`.
3. Set `soundId` for each ghost in `src/shared/GhostDefs.luau`.

AudioController creates `Sound` instances programmatically — no manual Sound objects needed in Studio.

---

## 14. Verification Checklist

After completing setup, do a **Play Solo** test and check the **Output** window for these messages:

| Message | Meaning |
|---------|---------|
| `[WorldBuilder] Build complete in X.XXXs` | All islands placed correctly |
| `[WorldBuilder] Missing biome model: X` | A biome model is missing or misnamed |
| `[WorldBuilder] X: expected N HauntPoints, got M` | Wrong HauntPoint count in a biome model |
| `[WorldBuilder] Hub model not found` | Hub model missing or misnamed |
| `[PlayerDataManager] LoadProfileAsync error` | Datastore issue (expected in Studio first run) |

**Expected on first Studio run:**
- ProfileService may show a datastore budget warning — normal in Studio, not in production.
- `"Safe"` collision group registration may warn if Studio already has the group — the `pcall` handles it.

**The game is ready when:**
- No `[WorldBuilder]` error lines appear.
- All 6 biome islands appear in Workspace.World.
- Hub appears in Workspace.World.
- Workspace.Ghosts folder exists.
- Tutorial fires for new players (step 0 message appears on screen).
