# Hantu Anjay

**Indonesian ghost-hunting Roblox game by JihadPixel.**

Roam a haunted open world of floating voxel islands, capture legendary Indonesian & ASEAN spirits in magical bottles, and fill your ghost compendium before your rivals do.

- **Platform:** Roblox
- **Players:** 1–50 per server
- **Target:** Ages 10+

---

## Gameplay

Players explore 6 floating biome islands — Kuburan, Kampung Tua, Hutan Bambu, Pantai Sepi, Kuburan Cina, and Sawah Haunted — each haunted by spirits with affinities for that zone. Ghosts are triggered by proximity, cold zones, standing still, or scanning, then weakened through a mini-game before being sealed in a magical bottle.

**30 capturable spirits** across four rarity tiers:

| Rarity | Count | Examples |
|--------|-------|---------|
| Common | 10 | Pocong, Kuntilanak, Wewe Gombel |
| Rare | 10 | Rangda, Orang Bunian, Penanggalan |
| Epic | 7 | Nyi Blorong, Batara Kala, Leyak |
| Mythic | 3 | Nyi Roro Kidul, Dewi Durga, Batara Guru Shadow |

**6 capture mini-games:** Mantra Tap, Bottle Aim, Rhythm Chant, Signal Triangulate, Shadow Chase, Team Surround (Mythic). All support mobile, PC, and controller input.

**Progression:** Hunter rank (level 1–100+), compendium completion milestones, daily/weekly quests, Spirit Shard economy, companion ghost (rarest caught follows you at 40% scale).

**Monetization:** Spirit Shard packs, VIP Hunter gamepass (+10% XP), Extra Bottle Bag (+10 capacity), Auto-Shard Collector. No pay-to-win.

---

## Development Setup

**Prerequisites:** [Rojo](https://rojo.space), [Wally](https://wally.run), [Selene](https://github.com/Kampfkarren/selene) (optional linter).

```bash
# Install packages (Wally → Packages/ and ServerPackages/)
wally install

# Start live sync with Roblox Studio
rojo serve

# Build a standalone .rbxl file
rojo build -o game.rbxl

# Lint
selene src/
```

Tests use [TestEZ](https://roblox.github.io/testez/) and run inside Roblox Studio — there is no CLI test command.

---

## Project Structure

```
src/
  server/
    init.server.luau       ← bootstrap (pcall-wrapped init order)
    systems/               ← PlayerDataManager, WorldBuilder, GhostSpawnManager,
                              GhostAI, CaptureSession, EconomyManager, QuestManager,
                              TutorialManager
    data/                  ← QuestDefs.luau
  client/
    init.client.luau       ← bootstrap
    systems/               ← UIManager, HUD, CompendiumUI, ShopUI, AudioController,
                              ZoneDetector, MiniGameController, TutorialController,
                              CompanionController, LocalizationBridge
    minigames/             ← MantraTap, BottleAim, RhythmChant, SignalTriangulate,
                              ShadowChase, TeamSurround
  shared/
    Remotes.luau           ← all RemoteEvents + RemoteFunctions declared here
    GhostDefs.luau         ← 30 ghost definitions (id, rarity, miniGame, stats…)
    BottleDefs.luau        ← bottle catch rates
    Constants.luau         ← all tuning values
    Types.luau             ← PlayerProfile, GhostInstance, CompendiumEntry…
    ZoneDefs.luau          ← 6 biome configs + haunt point coords

Packages/                  ← Wally client/shared deps (Signal, Promise, ProfileService…)
ServerPackages/            ← Wally server deps (ProfileService)
```

**Rojo mapping:** `src/server` → `ServerScriptService.Server` · `src/client` → `StarterPlayerScripts.Client` · `src/shared` → `ReplicatedStorage.Shared`

---

## Extending the Game

### Adding a new ghost

**1. `src/shared/GhostDefs.luau`** — add an entry to the `GhostDefs` table:
```lua
YourGhostId = {
    id             = "YourGhostId",
    nameKey        = "GHOST_YOURGHOST_NAME",
    loreKey        = "GHOST_YOURGHOST_LORE",
    rarity         = "Common",        -- "Common" | "Rare" | "Epic" | "Mythic"
    behavior       = "Wanderer",      -- "Wanderer" | "Hunter" | "Trickster"
    miniGame       = "MantraTap",     -- any MiniGameType from Types.luau
    maxResistance  = 3,               -- mini-game hits required to weaken
    speed          = 6,               -- studs/s movement speed
    detectionRange = 15,              -- studs; proximity trigger distance
    soundId        = 0,               -- Roblox audio asset ID (0 = placeholder)
    modelName      = "YourGhostId",   -- exact Model name in ReplicatedStorage.Assets.Ghosts
    affinityZones  = { "Kuburan" },   -- zones where spawn weight is doubled
},
```

**2. `src/shared/ZoneDefs.luau`** — add the ghost ID to `affinityGhosts` of any relevant zone (optional but recommended).

**3. Studio** — add a ghost Model named `YourGhostId` to `ReplicatedStorage.Assets.Ghosts`. See STUDIO_SETUP.md §7 for required Part properties and Humanoid setup.

**4. Localization** — add two keys to the `LocalizationTable`:
- `GHOST_YOURGHOST_NAME` → display name
- `GHOST_YOURGHOST_LORE` → lore text shown in the compendium

That's it. GhostSpawnManager auto-buckets ghosts by `rarity` at startup, so the new ghost immediately enters the spawn pool with the correct rarity weight.

> **Mythic note:** Mythic ghosts use the `TeamSurround` mini-game and are controlled by `startMythicEventLoop` in GhostSpawnManager. Make sure `miniGame = "TeamSurround"` and `behavior = "Trickster"` for Mythic entries, consistent with the existing three.

---

### Adding a new biome

**1. `src/shared/ZoneDefs.luau`** — add an entry to the `ZoneDefs` table:
```lua
YourZoneId = {
    id              = "YourZoneId",
    modelName       = "YourZoneId",        -- exact Model name in Workspace.World
    worldOffset     = Vector3.new(X, Y, Z), -- suggested center for Studio placement
    hauntPointCount = 4,                   -- number of HauntPoint Parts you'll place
    ambientSoundId  = 0,                   -- Roblox audio asset ID (0 = placeholder)
    affinityGhosts  = { "Pocong" },        -- ghost IDs with boosted spawn weight here
    detectionVolume = {
        min = Vector3.new(X1, Y1, Z1),     -- AABB matching actual island position
        max = Vector3.new(X2, Y2, Z2),
    },
},
```

**2. `src/shared/Types.luau`** — add the new zone ID to the `ZoneId` union type:
```lua
export type ZoneId =
    "Kuburan" | "KampungTua" | "HutanBambu"
    | "PantaiSepi" | "KuburanCina" | "SawahHaunted"
    | "YourZoneId"   -- ← add here
```

**3. Studio** — build the island model in Studio, name it `YourZoneId`, place it in `Workspace.World`, and add the required number of `HauntPoint` Parts. See STUDIO_SETUP.md §6 for full setup steps.

**4. Localization** — add one key:
- `ZONE_YOURZONERID_NAME` → display name shown in the HUD zone label

That's it. ZoneDetector, AudioController, GhostSpawnManager, WorldBuilder, and ShardManager all iterate `ZoneDefs` dynamically — they pick up the new zone automatically on next server start.

> **Detection volume:** The AABB must match the actual in-world position of the island. Test with `ZoneDetector` after placing — the HUD zone label should update when you walk onto the island.

---

## Design Documents

- **[GDD.md](GDD.md)** — full game design: world layout, spirit roster, mini-game specs, progression, economy
- **[PRD.md](PRD.md)** — scripting requirements: system APIs, remote schema, data schema, anti-exploit rules, performance constraints
- **[TASKS.md](TASKS.md)** — implementation task tracker

For contributor architecture guidance (require patterns, boot order, system contracts), see **[CLAUDE.md](CLAUDE.md)**.
