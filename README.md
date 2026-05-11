# Hantu Anjay

**Indonesian ghost-hunting Roblox game by JihadPixel.**

Roam a haunted open world of floating voxel islands, capture legendary Indonesian & ASEAN spirits in magical bottles, and fill your ghost compendium before your rivals do.

- **Platform:** Roblox
- **Players:** 1–8 per server
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

## Design Documents

- **[GDD.md](GDD.md)** — full game design: world layout, spirit roster, mini-game specs, progression, economy
- **[PRD.md](PRD.md)** — scripting requirements: system APIs, remote schema, data schema, anti-exploit rules, performance constraints
- **[TASKS.md](TASKS.md)** — implementation task tracker

For contributor architecture guidance (require patterns, boot order, system contracts), see **[CLAUDE.md](CLAUDE.md)**.
