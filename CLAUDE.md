# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Rogue Dungeons** — a single-player, turn-based RPG played in the browser. The player creates a character, lives in a town (shop, forge, inn, guild, academy, fortress…), climbs a 100-floor tower fighting monsters, and defends the town against a weekly siege. All rolls use a d6 dice-pool system.

Rails 8.0 monolith with a Vue 3 SPA frontend (Vite). Rails is a JSON API under `/api`; Vue handles all UI. The game is **still in development**: several characteristics and skills exist but have no effect yet (see tables below).

Player-facing text (UI strings, combat log, catalog data) is in **French**. Code (identifiers, comments) is in English.

## Common Commands

```bash
foreman start -f Procfile.dev   # Rails (3000) + Vite dev server
bundle install && npm install
bin/rails db:create db:migrate
bin/rails test                  # Minitest (test/ is almost empty for now)
bundle exec rspec               # RSpec (spec/, only a User spec for now)
npm run lint / npm run lint:fix # ESLint
bundle exec rubocop [-a]
bundle exec brakeman ; bundle exec bundler-audit
```

## Architecture

- Catch-all route sends HTML requests to `SpaController#index`; Vue Router does client navigation. API controllers live in `app/controllers/api/` (inherit `Api::BaseController`, use `require_character!`).
- Axios instance with CSRF + auth token: `app/frontend/plugins/axios.js`. Game state is in the Pinia store `app/frontend/stores/game.js`.
- Game logic lives in **service objects** (`app/services/`), not in controllers:
  - `CombatService` — the whole combat engine (tower and siege fights). Combat state is a JSON hash in `characters.combat_state`.
  - `DiceRoller` — `roll(mastery, bonus)`, `opposed_roll(...)`, `notation(mastery, bonus)`.
  - `GameCatalog` — loads and caches all game data from `config/catalog/` (call `GameCatalog.reload!` after editing a catalog in a console; restart the server otherwise).
  - `MonsterFactory` (tower enemies), `SiegeService` + `SiegeWaveFactory` (siege), `GuildService` / `AcademyService` (learning), `WorkService` (forge work), `SkillUpgradeService`, `WatchtowerIntelService`.
- Combat animations are frontend-only and derived from the action type + HP diff + log lines: `app/frontend/composables/useCombatFx.js`. If you add a technique/magic type, map it in `describe()` there (scope `target` / `all` / `self`).

## Game data (`config/catalog/`)

Two kinds of files, and the pairing matters:

| File | Role |
|---|---|
| `techniques.md` | **List + order + category** of techniques. Key = `name.parameterize(separator: "_")`. Rank in its category drives learning time. |
| `techniques.yml` | **Mechanics** of each technique, by the same key. |
| `magies.md` | **List + element + tier** of magics (tier = position under the `## Element` heading, 1..7). |
| `magies.yml` | **Mechanics** of each magic. |
| `statuts.md` / `statuts.yml` | Status list (positive/negative) / status mechanics. |
| `tour.md` | Floor composition (`12. 2x Bandit + Chef bandit`, boss floors as `### Étage N – Boss`). |
| `monstres.yml` | Monster stats + `name_to_key` map (names in `tour.md` → monster keys, plural forms included). |
| `equipement.yml`, `objets.yaml` | Equipment and consumable items. |
| `siege.yml` | Traps, synergies, siege monsters, waves, watchtower/workshop levels, repair costs. |
| `config/art/prompts.yml` | Prompts for `bin/rails art:generate` (fal.ai, paid). Removed items keep their prompt under `archived:` and their image in `config/art/archive/items/` — don't delete artwork, archive it. |
| `competences.md` | Human-readable skill list. **Documentation only** — the source of truth is `Character::SKILLS_MAP`. Keep both in sync. |

A technique/magic must exist in **both** its `.md` and `.yml` with matching keys: the `.md` makes it appear in the guild/academy, the `.yml` makes it do something in combat (`GameCatalog.technique_data` / `magic_data`).

## Dice system

- Everything is `XD+Y`: `mastery` = number of d6, `bonus` = flat add (0..2). A skill upgrade adds +1 bonus; at +3 it becomes +1D+0 (`Skill#upgrade!`). Upgrade cost = current mastery in XP.
- **Opposed roll**: attacker total vs defender total. `margin > 0` = hit, `margin == 0` = graze ("touché de peu": damage dice −1D, no status/debuff applied), `< 0` = miss.
- **Every stat is mastery + bonus**, including catalog data: a weapon with `damage_mastery: 3, damage_bonus: 1` is 3D+1 (4–19).
- **Player weapon damage** (`player_damage`): characteristic dice (Vigueur, or Dextérité for `arme_a_distance`) **+** weapon dice and bonus. Vigueur 2 + 3D+1 weapon = 5D+1. Bare hands = Vigueur D.
- **Physical damage**: `damage roll − resistance roll` (min 1). Enemy resistance = its `vigueur` + `dr`. Player resistance = Vigueur + equipment DR (+ stance / "Protégé").
- **Magic damage**: damage roll only, no resistance roll subtracted (but elemental resistances apply).
- Each additional enemy attack in the same turn gives the player −1D on dodge ("Esquive affaiblie").

## Characteristics

5 characteristics, 12 points at creation, each 1..4. They **cannot be raised afterwards** (only max PV/PM can be bought with XP, via `Character#bonus_max_hp/mana`).

| Characteristic | Effects today |
|---|---|
| Vigueur | Max PV = Vigueur×3 (+bonus). Melee damage dice. Player physical resistance. Guild learning time (`rank×2 − Vigueur` days). |
| Dextérité | Ranged damage dice. Fallback for weapon accuracy and dodge. Flee roll mastery (`Esquive` bonus added). |
| Intelligence | Max PM = Intelligence×3 (+bonus). Fallback for magic accuracy. Academy learning time (`tier×3 − Intelligence` days). |
| Charisme | **Not used yet.** |
| Perception | Fallback for Observation only. |

## Skills

Each character gets every skill of `Character::SKILLS_MAP` at creation, with `mastery = parent characteristic`, `bonus = 0` (`Character#initialize_skills`). After that, skills evolve independently through XP. Code looks skills up **by their French name** (`character.skills.find_by(name: "Esquive")`) and falls back to the characteristic if missing.

| Skill (category) | Used for | Where |
|---|---|---|
| Forge (Vigueur) | Gold earned working at the forge (roll × 3 gold) | `WorkService`, `Character#forge_roll`, `ForgeController` |
| Alchimie (Intelligence) | Gold earned working at the apothecary (roll × 3 gold) | `WorkService`, `Character#alchemy_roll`, `ApothecaryController` |
| Arc (Dextérité) | Accuracy with `arme_a_distance` (all ranged weapons are `two_handed` for the shield rule, but keep using Arc) | `CombatService#weapon_skill_name` |
| Arme à une main (Dextérité) | Accuracy with one-handed melee (and default) | same |
| Arme à deux mains (Dextérité) | Accuracy with `two_handed: true` melee (can't be equipped with a shield: equipping one unequips the other, `InventoryController#free_hands_for`) | same |
| Esquive (Dextérité) | Player defense in **esquive** mode; its bonus is also used for fleeing | `Character#defense_roll`, `player_defense_vs`, `character_dex_bonus` |
| Parade (Dextérité) | Player defense in **parade** mode | `Character#defense_roll`, `player_defense_vs` |
| Feu / Eau / Ombre / Lumière / Nature (Intelligence) | Accuracy of magics of that element | `find_player_skill_for_element` |
| Observation (Perception) | "Analyser" action (reveals enemy resistances) | `resolve_analyze` |
| Fouille (Perception) | Gold multiplier after a tower victory | `resolve_search_loot` |
| Endurance, Escalade, Natation, Bras de fer, Résistance à l'alcool (Vigueur) | **Not used yet** | — |
| Discrétion, Vitesse (Dextérité) | **Not used yet** (boots already carry a `speed_bonus` for Vitesse) | — |
| Enchantement (Intelligence) | **Not used yet** | — |
| Persuasion, Marchandage, Dressage (Charisme) | **Not used yet** | — |
| Intuition, Sang-Froid (Perception) | **Not used yet** | — |

### Adding a new skill

1. Add the name to `Character::SKILLS_MAP` under its characteristic, and to `config/catalog/competences.md` (same `## Category` section).
2. Write a **data migration** so existing characters get it (new characters get it via `initialize_skills`). Pattern: `db/migrate/20261122100000_add_forge_skill_to_existing_characters.rb` (INSERT … SELECT with `mastery = GREATEST(characteristic, 1)`, `WHERE NOT EXISTS`).
3. Use it with `character.skills.find_by(name: "…")`, falling back to the characteristic (`skill ? [skill.mastery, skill.bonus] : [characteristic, 0]`). If it's reused, add a helper on `Character` (like `forge_roll`).
4. Show the dice to the player (`DiceRoller.notation`) in the log/UI. The character sheet lists skills automatically (grouped by `category`), and upgrading via XP works without extra code.
5. Update the skills table above.

## Combat (`CombatService`)

Turn order: player action → (victory check) → every living enemy acts → statuses tick (DoT/HoT, durations decrease). Player actions: `attack`, `technique`, `magic`, `item`, `analyze`, plus `flee` (Dextérité + Esquive bonus vs `floor/10 + 3`).

- **Targeting**: only `attack` and `analyze` use the chosen `target` index. Single-target techniques and magics always hit **the first living enemy** (`living_enemies.first`) — **intentional**, to keep fights fast; don't "fix" it unless asked. AoE types loop over all living enemies with **one opposed roll per target** (so some can be missed).
- **Piercing weapons** (`pierce_targets: 2` in `equipement.yml`, the spears): a basic `attack` also hits the next living enemy after the chosen target (wrapping around), with one roll per target (`pierced_targets`, `resolve_attack_on`). Techniques don't pierce.
- **Player defense mode** (`characters.defense_mode`, `esquive` | `parade`): a toggle in the combat screen (`DefenseToggle.vue`, `PATCH /api/character/defense_mode`), persisted until the player changes it, applied automatically to every enemy attack (basic attacks, techniques, damage/drain spells).
  - *Esquive*: Esquive skill roll; a success avoids all damage. Technique/stance `esquive_bonus` adds dice.
  - *Parade*: Parade skill roll + `CombatService::PARRY_ROLL_BONUS` (easier), but a success still deals `PARRY_CHIP_DAMAGE` (1) — logged as "paré !". Technique/stance `parade_bonus` adds flat bonus.
  - With a ranged weapon equipped, parry is impossible: `Character#effective_defense_mode` forces esquive (the saved choice is kept for when a melee weapon comes back) and the toggle greys out Parade.
  - Equipment adds a flat bonus to the matching mode: boots `esquive_bonus`, helmets `parade_bonus` (`Character#defense_roll`, `#equipment_bonus`). Boots also have `flee_bonus` (added to the flee roll) and `speed_bonus` (stored for the future Vitesse mechanic, not used yet).
  - Bonuses of the other mode are ignored. Snapshots expose `player.defense` (`{ mode, esquive, parade }` dice notations).
- **Player accuracy**: weapon skill (+ weapon `accuracy_bonus`) ± status modifiers. **Magic accuracy**: element skill (fallback Intelligence), against the enemy's `esquive`.
- **Enemies**: 30% chance per turn to use one of their `abilities` (keys of `techniques.yml` or `magies.yml`; a `mana_cost` key means it's resolved as a magic), otherwise a basic attack.
- **End** (`finish_combat`): `floor > 0` means a tower fight. Tower victory gives half the XP and gold scaled by the Fouille roll. Siege fights have no floor: full rewards, a day passes, then `SiegeService#finish_siege` applies the siege outcome. Defeat → 1 PV, tower session ends.

### Technique types (`techniques.yml` → `resolve_technique`)

`attack_modifier` (accuracy/damage bonus, optional status), `multi_attack` (`hits` strikes on the first enemy, not an AoE), `aoe` (every enemy), `armor_pierce` (`dr_reduction_percent`), `debuff_attack` (persistent `debuff` like `parade_reduction`), `execute` (`damage_multiplier` under `hp_threshold`%), `status_attack` (`inflict_status`), `counter` / `combo` (counter-attack on enemy hit/miss), `stance` (esquive/parade/DR bonus for the enemy phase), `heal`. Some yml fields are not read by the engine yet (`skip_attack`, `apply_to`): techniques are not finished, this is expected.

### Magic types (`magies.yml` → `resolve_magic`)

All cost `mana_cost` and check the "Silencé" status. `damage`, `damage_status` (status on hit), `damage_aoe` (every enemy), `status`, `heal`, `heal_cure`, `cure`, `buff` (`buff_status`), `drain` (`drain_percent`). Learning a tier N magic requires the tier N−1 magic of the same element.

### Statuses (`statuts.yml`)

Applied as `{ name, remaining }` on the player or an enemy; re-applying refreshes to the max duration. Mechanics are data-driven (`tick_damage_*`, `tick_heal_*`, `mastery_penalty`, `accuracy_mastery_penalty`, `bonus_all`…), except a few hardcoded by name in `CombatService`: Étourdi (lose turn), Paralysé (50% lose turn), Confus (25% self-hit), Invisible (next attack auto-hits), Protégé (+1D resistance), Accéléré (+1 dodge), Silencé (no magic).

### Weaknesses / resistances and Analyze

- Monsters have `resistances: { feu: -50, physical: 25, magical: 10, … }` in `monstres.yml`. Keys: `physical`, `magical`, and elements `feu`, `eau`, `ombre`, `lumiere`, `nature`. Value in % (−100..100): positive = resistance, negative = weakness (vulnerability), ≥100 = immunity.
- `apply_target_resistance(damage, target, kind, element)`: the element key wins over the generic `magical`; physical attacks use `physical`. Multiplier = `(100 − value) / 100`. The log shows "résiste X%", "vulnérabilité X%" or "immunité".
- **Analyze** (`resolve_analyze`): Observation roll vs DC `8 + floor/5`. Fail → nothing. Success → reveals 1 unknown resistance, 2 if margin ≥ 5, all if margin ≥ 10. Knowledge is **permanent per monster type** (`MonsterKnowledge`, `revealed_keys`) and sent to the frontend as `revealed_resistances` in every combat snapshot.

## Town, time and siege

- Work (`WorkService`, `POST /api/town/work` with `place`): a day at the forge (Forge skill) or the apothecary (Alchimie skill) earns `roll × gold_per_point` gold (forge 3, apothecary 3). Add a workplace in `WorkService::WORKPLACES` + `Character#work_roll`.
- Shops: the apothecary sells catalog items with `vendor: "apothecary"` (`GameCatalog.apothecary_items`), the shop sells the other items; both buy/sell through `ShopController`.
- Time: `Character#advance_day` (7 days/week, 4 weeks/month, 12 months). Working, the inn, learning days and entering the tower (once per tower session) each cost a day. A new week triggers a pending **siege** (`siege_state`).
- Buildings (`SiegeService::BUILDINGS`: `shop academy guild forge watchtower workshop apothecary`) can be damaged (penalties: −30% forge gold, +2 learning days) or destroyed (unusable) by sieges; repaired with gold.
- Siege: traps placed per direction in the fortress (`FortressDefense`, with synergies and durability), watchtower intel on the attack direction, then a fight run through `CombatService`.

## Key Dependencies

**Backend:** Rails 8.0, PostgreSQL, Devise, Pundit, GoodJob, Pagy 43, PaperTrail
**Frontend:** Vue 3.5, Vite 5, Pinia, Vue Router, Axios, Tailwind CSS 3.4
**Requires:** Ruby 3.3.5, Node 20.x

## Life Dashboard

Projet du life-dashboard : `rogue_dungeons` (`/historyupdate` envoie chaque session au journal de bord de ce projet).
