# Game Design Document — Hantu Anjay

**Version:** 0.1.0  
**Studio:** JihadPixel  
**Platform:** Roblox  
**Genre:** Multiplayer Ghost-Hunting Adventure / Collector  
**Target Age:** 10+  
**Players:** 1–8 per server  

---

## 1. Vision & Hook

> *"Tangkap semua hantu legendaris ASEAN — jadi pemburu paranormal paling keren!"*  
> *"Catch every legendary ASEAN spirit — become the ultimate paranormal hunter!"*

**One-sentence pitch:** Explore haunted floating voxel islands, capture legendary Indonesian & ASEAN spirits in magical bottles, complete mini-games, and fill your ghost compendium before your rivals do.

**Core fantasy:** Player feels like a fearless paranormal hunter armed with ancient knowledge, outwitting legendary spirits that would terrify ordinary people.

**Why addictive:**
- Pokémon-style collection loop — "gotta catch 'em all" pull
- Short session design — one island run ~5–10 min
- Social rivalry — friends see each other's compendium progress
- Surprise & discovery — rare ghost spawn is unpredictable
- Escalating difficulty — capturing a Kuntilanak is easy; a Leak is brutal

---

## 2. Core Game Loop

```
LOBBY
  └─► Choose Island Seed (random 3 options)
        └─► Explore Island (2–5 min)
              ├─► Find Ghost Traces (footprints, cold spots, sounds)
              ├─► Trigger Ghost Encounter
              │     └─► Play Mini-Game → Capture / Fail
              ├─► Collect Bonus Items (spirit shards, bait)
              └─► Extract or Stay
                    ├─► Extract → Rewards → Lobby
                    └─► Stay → Harder ghosts spawn
```

**Session length target:** 5–15 min per run  
**Progression target:** 50–80 hours to complete base compendium  

---

## 3. World Design

### 3.1 Aesthetic — Voxel / Block Style

- All terrain, props, and characters use **block/voxel geometry** (Roblox Part + MeshPart, no smooth terrain)
- Color palette: muted earthy tones (greens, browns, grays) with **glowing neon ghost effects** for contrast
- Night/twilight persistent lighting — eerie but readable
- Fog layer between islands for atmosphere

### 3.2 Floating Island Maps

Each run generates a **small random island cluster** (~150×150 studs play area):

| Zone | Description |
|------|-------------|
| **Graveyard** | Stone graves, dead trees, mossy blocks |
| **Kampung Tua** | Old wooden village huts, hanging lanterns |
| **Hutan Bambu** | Dense bamboo grid, tall grass blocks |
| **Pantai Sepi** | Shore with tide blocks, dock ruins |
| **Kuburan Cina** | Tiered grave structures, incense block effects |
| **Sawah Haunted** | Rice paddy grid, scarecrow props |

Island generation:
- Pick 1 biome theme
- Procedurally tile modular block chunks (pre-built 16×16 chunks)
- 3–5 islands connected by rope bridges or floating stone paths
- One **Boss Island** unlocked after clearing normal islands in a run

### 3.3 Verticality

- Islands float at varying heights → vertical exploration
- Wind currents (visual only, no gameplay) connect islands aesthetically
- Jump pads disguised as ancient stone pillars

---

## 4. Spirits (Hantu) — ASEAN / Indonesia Focus

All spirits have:
- **Rarity tier** (Common → Mythic)
- **Behavior pattern** (how they move/attack during encounter)
- **Capture mini-game type**
- **Compendium entry** (lore in ID + EN)

### 4.1 Spirit Roster — Base 30

#### Common (10 spirits)
| # | Name | Origin | Behavior |
|---|------|---------|----------|
| 1 | Pocong | Java/Sumatra | Hops in straight line, predictable |
| 2 | Kuntilanak | Malay/Java | Circles player, laughs as tells |
| 3 | Wewe Gombel | Central Java | Steals and runs, slow |
| 4 | Banaspati | Java | Floating fireball, patrols |
| 5 | Sundel Bolong | Java | Walks toward player, back hole visible |
| 6 | Toyol | Malay/Java | Tiny, fast, steals items |
| 7 | Tuyul | Java | Similar to Toyol, pickpocket mechanic |
| 8 | Leak (Weak) | Bali | Flying head, basic movement |
| 9 | Genderuwo Jr. | Java | Large, slow, charges |
| 10 | Jenglot | Java | Tiny creature, hides in grass |

#### Rare (10 spirits)
| # | Name | Origin | Behavior |
|---|------|---------|----------|
| 11 | Rangda | Bali | Boss-tier movement, erratic |
| 12 | Orang Bunian | Malay | Invisible until close, audio cue |
| 13 | Hantu Raya | Malay | Mimics player avatar |
| 14 | Babi Ngepet | Java | Pig form, runs in circles |
| 15 | Palasik | Minang | Flying head, faster than Leak |
| 16 | Penanggalan | Malay | Head + organs, dangles |
| 17 | Aswang (Mild) | Philippines | Quadruped, ambush from trees |
| 18 | Manananggal (Half) | Philippines | Upper torso, flight pattern |
| 19 | Kra-Sue | Thailand | Glowing head, hovering |
| 20 | Phi Pop | Thailand | Possesses objects, erratic |

#### Epic (7 spirits)
| # | Name | Origin | Behavior |
|---|------|---------|----------|
| 21 | Nyi Blorong | Java | Serpent-woman, charges in wave |
| 22 | Batara Kala | Java | Large, earthquake stomp |
| 23 | Rangda (True) | Bali | Phase 2, split summons |
| 24 | Mahisasura | Hindu-Java | Bull form, ram pattern |
| 25 | Leyak | Bali | Full transformation, unpredictable |
| 26 | Santet Specter | Java | Invisible, inferred by particle trail |
| 27 | Hantu Kopek | Java | Surprise spawn, area denial |

#### Mythic (3 spirits)
| # | Name | Origin | Behavior |
|---|------|---------|----------|
| 28 | Nyi Roro Kidul | Java | Queen of South Sea, water phase |
| 29 | Dewi Durga (Dark) | Hindu-Java | Multi-phase, summons minions |
| 30 | Batara Guru Shadow | Java | Server-wide event spirit |

### 4.2 Spirit Behaviors

**3 behavioral archetypes:**

1. **Wanderer** — patrols fixed path, triggered by proximity
2. **Hunter** — chases player after detection, gives up after 15s
3. **Trickster** — teleports, spawns decoys, fakes positions

Detection triggers:
- Step in cold zone (blue fog patch)
- Pick up spirit shard
- Shine lantern in wrong direction
- Stand still too long near a haunt point

---

## 5. Capture System

### 5.1 Magical Bottles

| Bottle | Catch Rate | Durability | Unlock |
|--------|-----------|------------|--------|
| Botol Biasa | 40% | 3 uses | Default |
| Botol Kaca Biru | 60% | 5 uses | Shop / Level 5 |
| Botol Emas | 80% | 8 uses | Level 15 |
| Botol Kristal | 95% | Unlimited | Mythic unlock |
| Botol Retak | 20% | 1 use | Free reward |

**Capture sequence:**
1. Encounter triggers — ghost appears with health bar (Resistance)
2. Player **weakens** ghost via mini-game (reduces Resistance)
3. Throw bottle (tap/click) — catch rate check
4. Success → ghost sealed → added to compendium
5. Fail → ghost escapes, short cooldown before respawn

### 5.2 Ghost Resistance

Each ghost has a **Resistance** value (1–10):
- Common: 1–3 → mini-game is short
- Rare: 4–6 → mini-game has phases
- Epic: 7–9 → mini-game has fail conditions
- Mythic: 10 → multi-phase + time limit + team required

---

## 6. Mini-Games (Capture Mechanics)

All mini-games are designed for **cross-platform input** (tap + controller + keyboard).

### 6.1 Mantra Tap
**Used by:** Pocong, Kuntilanak, Sundel Bolong  
Tap/click glowing symbols in the correct order before timer expires.  
- Mobile: tap symbols on screen  
- PC: click with mouse  
- Controller: press A/B/X/Y mapping shown on screen  

### 6.2 Bottle Aim
**Used by:** Banaspati, Toyol, Tuyul  
Moving target (ghost) — hold aim reticle on ghost for 2 seconds.  
- Mobile: hold thumb on ghost  
- PC: hover mouse  
- Controller: right stick aim  

### 6.3 Rhythm Chant
**Used by:** Wewe Gombel, Genderuwo, Orang Bunian  
Beat drops — tap/press in rhythm (DDR-lite). 4–8 notes.  
3 lanes, single-tap only. No holds.

### 6.4 Signal Triangulate
**Used by:** Leak, Palasik, Penanggalan  
3 directional arrows appear — rotate to correct direction using audio/visual cue.  
- Compass-style UI, turn until needle aligns  

### 6.5 Shadow Chase
**Used by:** Epic tier  
Chase ghost's shadow on ground while avoiding its real body.  
Touch shadow = progress. Touch body = damage + mini-game reset.

### 6.6 Team Surround (Mythic only)
**Used by:** Nyi Roro Kidul, Dewi Durga, Batara Guru Shadow  
2+ players must stand at designated circle points simultaneously.  
Solo players cannot capture mythic without a Botol Kristal + max resistance drain.

---

## 7. Progression System

### 7.1 Player Level (Hunter Rank)

| Rank | Level Range | Title (ID) | Title (EN) |
|------|-------------|------------|------------|
| Pemula | 1–5 | Pemburu Pemula | Rookie Hunter |
| Jagoan | 6–15 | Pemburu Jagoan | Skilled Hunter |
| Paranormal | 16–30 | Paranormal Sejati | True Paranormal |
| Dukun | 31–50 | Dukun Handal | Expert Shaman |
| Legenda | 51+ | Legenda Paranormal | Paranormal Legend |

XP sources:
- Capture ghost → XP by rarity
- Complete run → bonus XP
- First capture of spirit type → big XP bonus
- Daily quest completion

### 7.2 Compendium

- 30 base slots (expandable with future updates)
- Each captured ghost fills a slot with:
  - Ghost 3D preview (rotating block model)
  - Lore text (ID + EN)
  - Capture stats (how many times caught, first caught date)
  - Rarity badge
- Completion milestones:
  - 10/30 → Unlock island skin "Sawah Mistis"
  - 20/30 → Unlock title "Kolektor Hantu"
  - 30/30 → Unlock Botol Kristal + exclusive cosmetic

### 7.3 Daily & Weekly Quests

**Daily (resets 00:00 WIB / server time):**
- Capture 3 Common ghosts
- Complete 2 runs
- Find 10 spirit shards

**Weekly:**
- Capture 1 Rare ghost
- Complete a run with 3+ friends
- Capture ghost in Kuburan Cina biome

Rewards: Spirit Shards, XP, occasionally Robux-adjacent items (cosmetics only)

---

## 8. Economy & Monetization

### 8.1 Currencies

| Currency | Name | Earned via |
|----------|------|------------|
| **Spirit Shards** (free) | Pecahan Roh | Runs, quests, daily login |
| **Robux** (paid) | Robux | Purchase |

**No pay-to-win.** Robux only buys cosmetics and convenience.

### 8.2 Robux Items

| Item | Price (R$) | Type |
|------|-----------|------|
| Hunter Outfit Pack | 149 | Cosmetic |
| Island Theme Pack | 99 | Visual only |
| Ghost Trail Effect | 79 | Cosmetic |
| XP Boost (1 day) | 49 | Convenience |
| Extra Bottle Slot (+5) | 49 | Convenience |
| Compendium Frame Pack | 129 | Cosmetic |
| Premium Battle Pass | 399/season | Cosmetic + XP track |

### 8.3 Battle Pass (Season Pass)

- Season = 30 days
- 30 tiers, free track + premium track
- Free track: Spirit Shards, XP boosts, 1 cosmetic
- Premium track (R$399): exclusive ghost cosmetics, bottle skins, island skin, title
- No gameplay-affecting rewards behind paywall

### 8.4 Developer Products

- **Spirit Shard Packs:** 100 / 500 / 1500 shards (R$25 / R$99 / R$249)
- **Run Revive:** spend shards to continue failed run (free currency only)

### 8.5 Gamepass

| Gamepass | Price | Benefit |
|----------|-------|---------|
| VIP Hunter | R$299 | +10% XP, exclusive lobby, VIP badge |
| Extra Bottle Bag | R$149 | +10 bottle carrying capacity |
| Auto-Shard Collector | R$199 | Shards auto-collected while exploring |

---

## 9. UI / UX Design

### 9.1 Cross-Platform UI Principles

- **Mobile-first layout:** all tap targets ≥ 44×44 px equivalent
- PC/console: same layout, keyboard/controller hints replace touch hints
- **No small text:** minimum font size 14pt equivalent
- All mini-games use single-input mechanics (tap, hold, or directional)
- HUD elements anchored to screen corners with safe area padding

### 9.2 HUD (In-Run)

```
┌─────────────────────────────────────────────────────┐
│ [HP ████░░] [🔦 Lantern 80%]         [⏱ 8:32]      │
│                                       [Players: 3]  │
│                                                      │
│                  [WORLD]                            │
│                                                      │
│ [🎒 Bottles: 3x Biasa]          [📍 Mini-map]       │
│                    [🔍 SCAN]                         │
└─────────────────────────────────────────────────────┘
```

- SCAN button: activates detection pulse (shows cold zones)
- Mini-map: top-down view, ghost traces as question marks
- Mobile: SCAN + action buttons in thumb reach zone

### 9.3 Lobby UI

- Big colorful ghost compendium button (center)
- Quick-play button (large, prominent)
- Shop (top right)
- Daily quests (bottom bar with notification dot)
- Friends list (bottom left)
- Season pass progress bar (top)

### 9.4 Compendium UI

- Grid layout, 5 columns
- Locked slots show silhouette + rarity color border
- Tap ghost → detail card slides in from right
- Filter: by rarity, by biome, by captured/uncaptured

---

## 10. Audio Design

### 10.1 Ambient Sound

- Each biome has unique ambient loop (jungle, village, shore)
- Tension layer adds when ghost is near (fade-in low drone)
- Complete silence = safe zone indicator

### 10.2 Ghost Audio Cues

Each ghost has a **signature sound** heard before visual spawn:
- Pocong: hop thud + cloth rustle
- Kuntilanak: distant giggling
- Genderuwo: deep growl + crack
- Nyi Roro Kidul: ocean waves surging

Audio = gameplay mechanic, not just atmosphere. Players learn to identify ghosts by sound.

### 10.3 UI Audio

- Capture success: triumphant Gamelan note
- Capture fail: hollow glass shatter
- Level up: short Gamelan fanfare
- Mini-game note hits: soft percussion tap

---

## 11. Localization

Roblox's built-in localization system via **LocalizationTable**.

### 11.1 Supported Languages

| Code | Language | Priority |
|------|----------|----------|
| `id` | Bahasa Indonesia | Primary |
| `en` | English | Secondary (default fallback) |

### 11.2 Localization Scope

- All UI labels, button text, quest names, compendium lore
- Ghost names: kept in original Indonesian/local language with romanized EN subtitle
- Error messages, tutorial text, notification strings
- Mini-game instruction overlays

### 11.3 Implementation

```
ReplicatedStorage/
  Assets/
    Localization/
      GameStrings.csv   ← imported as LocalizationTable
```

String key format: `CATEGORY_IDENTIFIER`  
Examples:
- `UI_BUTTON_SCAN` → "Deteksi" (id) / "Scan" (en)
- `GHOST_POCONG_NAME` → "Pocong" (id) / "Pocong" (en)
- `GHOST_POCONG_LORE` → full lore text per language
- `QUEST_DAILY_CAPTURE3` → "Tangkap 3 hantu biasa" / "Capture 3 common ghosts"

---

## 12. Multiplayer Design

### 12.1 Server Structure

- **Server size:** 8 players max per run server
- **Lobby server:** separate, up to 50 players (social hub)
- Party system: invite up to 4 friends → queue together

### 12.2 Cooperation vs. Competition

- **Cooperative:** Team mini-games (mythic captures), shared ghost detection
- **Competitive:** Compendium leaderboard, first-capture bonus, speed run time
- Ghost capture is **per-player** — same ghost can be caught by multiple players in one run (avoids griefing)

### 12.3 Social Features

- Compendium share link → show friends which ghost you caught
- Ghost trading: **not in v1** (deferred — economy risk)
- Lobby ghost display: your rarest captured ghost follows you in lobby

---

## 13. Tutorial

Length: ~3 minutes, skippable after first completion.

**Steps:**
1. Spawn on Tutorial Island (always Kampung Tua)
2. NPC guide (old ghost hunter) walks player through SCAN mechanic
3. Scripted Pocong encounter → Mantra Tap tutorial (slowed speed, forgiving)
4. Capture success → compendium opens, first entry filled
5. NPC explains daily quest
6. Teleport to main lobby

Tutorial ghost (Pocong) not counted in compendium — separate tutorial slot.

---

## 14. Technical Architecture

### 14.1 Project Structure (existing)

```
src/
  server/     ← ServerScriptService
  client/     ← StarterPlayerScripts  
  shared/     ← ReplicatedStorage/Shared
  assets/     ← ReplicatedStorage/Assets
```

### 14.2 Key Systems

| System | Side | Notes |
|--------|------|-------|
| IslandGenerator | Server | Chunk-based procedural assembly |
| GhostSpawnManager | Server | Rarity-weighted random spawn |
| CaptureSession | Server + Client | Mini-game state machine |
| CompendiumData | Server (DataStore) | Per-player ghost collection |
| QuestManager | Server | Daily/weekly reset via os.clock |
| EconomyManager | Server | Shard transactions, anti-exploit |
| LocalizationBridge | Client | Reads LocalizationTable |
| UIManager | Client | Cross-platform layout switcher |

### 14.3 Data Persistence

Roblox DataStore v2:
- Key: `player_{userId}_v1`
- Stores: level, XP, compendium flags, shard balance, quest progress
- Auto-save: every 60 seconds + on leave

### 14.4 Dependencies (wally.toml)

Already configured:
- `evaera/promise` — async DataStore ops
- `sleitnick/signal` — event system
- `sleitnick/component` — entity-component for ghosts
- `flamenco687/maid` — cleanup
- `osyrisrblx/t` — runtime type checking

---

## 15. Content Roadmap

### v1.0 — Launch
- 30 spirits (base roster)
- 6 biomes
- 5 mini-game types
- Compendium
- Battle Pass Season 1
- ID + EN localization
- Tutorial

### v1.1 — Season 2
- 5 new spirits (Malaysia focus: Hantu Penanggal variants, Orang Minyak)
- New biome: Rumah Tua (old Dutch colonial house)
- Ghost race event (limited time)

### v1.2 — Season 3
- 5 new spirits (Philippines/Thailand focus)
- Cooperative raid: 8-player mythic event
- Ghost trading (if economy stable)

### v2.0
- Second map region (larger, permanent)
- Guild / Klan system
- Leaderboard seasons

---

## 16. Risk & Mitigation

| Risk | Mitigation |
|------|------------|
| Mini-games too hard for kids | Difficulty sliders in settings; tutorial uses easiest variant |
| Monetization flagged | All Robux = cosmetic; no loot boxes (direct purchase only) |
| Ghost names culturally sensitive | Review with Indonesian community; keep lore respectful |
| Server performance (voxel gen) | Pre-bake chunk templates; generate at run start not mid-game |
| Cheating / exploit | Server-authoritative capture; EconomyManager validates all shard ops |
| Low player retention | Daily quests + season pass create return loops; session ≤15 min reduces drop-off |

---

## 17. Success Metrics

| Metric | Target (Month 1) |
|--------|-----------------|
| DAU | 5,000 |
| Session length | ≥8 min avg |
| D1 Retention | ≥40% |
| D7 Retention | ≥20% |
| Compendium depth (avg) | ≥8 ghosts by Day 7 |
| Battle Pass conversion | ≥5% of active players |

---

*Document maintained by JihadPixel. Update on each milestone.*
