# Plan d'implémentation – Rogue Dungeons

## Vue d'ensemble

Jeu solo textuel + images sur Rails 8 (API) + Vue 3 (SPA) + Tailwind CSS.
Le joueur crée un personnage, explore une ville, s'équipe, apprend des techniques et des magies, et progresse dans une tour d'ascension de 100 étages.

Système de dés D6 : `mastery` (nombre de D6 à lancer) + `bonus` (ajouté au total).
Notation : `2D+3` signifie lancer 2 dés à 6 faces et ajouter 3 au résultat.

---

## Phase 1 – Modèles de données et migrations

### Objectif
Poser le schéma de base de données complet. Tout le jeu repose sur ces modèles.

### 1.1 – Modèle `Character` (table `characters`)

Le personnage du joueur. Un User a un seul Character (has_one).

| Colonne | Type | Notes |
|---|---|---|
| `id` | bigint PK | |
| `user_id` | bigint FK | `belongs_to :user` |
| `name` | string | Nom du personnage, obligatoire |
| `vigueur` | integer | Min 1, max 8, total carac = 12 |
| `dexterite` | integer | Min 1, max 8 |
| `intelligence` | integer | Min 1, max 8 |
| `charisme` | integer | Min 1, max 8 |
| `perception` | integer | Min 1, max 8 |
| `current_hp` | integer | PV actuels |
| `max_hp` | integer | = vigueur × 3 |
| `current_mana` | integer | PM actuels (si mana retenue) |
| `max_mana` | integer | = intelligence × 3 |
| `xp` | integer | Points d'expérience, défaut 0 |
| `gold` | integer | Pièces d'or, défaut 50 (or de départ) |
| `current_floor` | integer | Dernier étage atteint dans la tour, défaut 0 |
| `day` | integer | Jour courant, défaut 1 |
| `week` | integer | Semaine courante, défaut 1 |
| `month` | integer | Mois courant, défaut 1 |
| `year` | integer | Année courante, défaut 1 |
| `status` | string | Statut actif (ou null) |
| `status_duration` | integer | Jours restants du statut |
| `activity` | string | Activité en cours : null, "forge", "academie", "guilde" |
| `activity_days_left` | integer | Jours restants d'activité en cours |
| `activity_data` | jsonb | Données supplémentaires (ex: quelle magie/technique en apprentissage) |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**Validations :**
- Somme des 5 caractéristiques = 12
- Chaque caractéristique >= 1
- `name` présent et unique par user

**Callbacks :**
- `before_validation` : calculer `max_hp` = vigueur × 3 et `max_mana` = intelligence × 3
- `after_create` : initialiser les compétences de base et l'inventaire de départ

**Méthodes de modèle :**
- `advance_day(n)` : faire passer n jours (gère semaine/mois/année : 7 jours = 1 semaine, 4 semaines = 1 mois, 12 mois = 1 année)
- `alive?` : current_hp > 0
- `full_heal` : remet current_hp à max_hp
- `formatted_date` : renvoie "Jour X, Semaine Y, Mois Z, Année W"

### 1.2 – Modèle `Skill` (table `skills`)

Représente le niveau d'une compétence pour un personnage.

| Colonne | Type | Notes |
|---|---|---|
| `id` | bigint PK | |
| `character_id` | bigint FK | |
| `name` | string | Ex: "Arc", "Esquive", "Feu" |
| `category` | string | La caractéristique liée : "vigueur", "dexterite", etc. |
| `mastery` | integer | Nombre de D6 |
| `bonus` | integer | Bonus fixe, défaut 0 |

**Logique :**
- À la création du personnage, chaque compétence est initialisée avec mastery = valeur de la caractéristique liée, bonus = 0.
- Coût pour monter d'un cran : `mastery` XP actuels (pas le nouveau mastery).
  - 3D → 3D+1 coûte 3 XP, 3D+1 → 3D+2 coûte 3 XP, 3D+2 → 4D coûte 3 XP
  - 4D → 4D+1 coûte 4 XP, etc.
- Montée : bonus += 1 ; si bonus atteint 3 → bonus = 0, mastery += 1

### 1.3 – Modèle `InventoryItem` (table `inventory_items`)

Un objet dans l'inventaire du personnage.

| Colonne | Type | Notes |
|---|---|---|
| `id` | bigint PK | |
| `character_id` | bigint FK | |
| `item_key` | string | Clé du catalogue (ex: "potion_healing_minor") |
| `item_type` | string | "equipment" ou "item" |
| `quantity` | integer | Nombre possédé, défaut 1 |
| `equipped` | boolean | Est-ce porté/équipé ? défaut false |
| `slot` | string | Slot d'équipement : "weapon", "armor", "helmet", "boots", "shield", null pour items |

**Contraintes :**
- Un seul équipement par slot par personnage (unicité character_id + slot pour equipped = true)
- Les consommables ont quantity >= 1

### 1.4 – Modèle `LearnedTechnique` (table `learned_techniques`)

| Colonne | Type | Notes |
|---|---|---|
| `id` | bigint PK | |
| `character_id` | bigint FK | |
| `technique_key` | string | Clé unique de la technique |
| `name` | string | Nom affiché |
| `category` | string | "offensive", "defensive", "effect", "advanced" |

### 1.5 – Modèle `LearnedMagic` (table `learned_magics`)

| Colonne | Type | Notes |
|---|---|---|
| `id` | bigint PK | |
| `character_id` | bigint FK | |
| `magic_key` | string | Clé unique |
| `name` | string | Nom affiché |
| `element` | string | "feu", "eau", "ombre", "lumiere", "nature" |
| `tier` | integer | Rang dans la liste de l'élément (1-7) |

### 1.6 – Modèle `CombatLog` (table `combat_logs`)

Historique de combat pour affichage et revue.

| Colonne | Type | Notes |
|---|---|---|
| `id` | bigint PK | |
| `character_id` | bigint FK | |
| `floor` | integer | Étage de la tour |
| `result` | string | "victory", "defeat", "fled" |
| `log_data` | jsonb | Détail tour par tour du combat |
| `xp_gained` | integer | |
| `gold_gained` | integer | |
| `created_at` | datetime | |

### 1.7 – Données de catalogue (fichiers YAML, pas de table)

Les catalogues existants dans `config/catalog/` sont chargés en mémoire au boot de l'application via un service `GameCatalog`. Pas de tables en base : ces données sont statiques.

**Fichier `app/services/game_catalog.rb` :**
- Charge `equipement.yml`, `objets.yaml` au démarrage
- Parse `competences.md`, `magies.md`, `techniques.md`, `statuts.md`, `tour.md` pour extraire les listes
- Expose des méthodes de classe : `GameCatalog.weapon(key)`, `GameCatalog.item(key)`, `GameCatalog.floor(n)`, etc.

---

## Phase 2 – Backend : API et Services de jeu

### Objectif
Implémenter toute la logique de jeu côté serveur (API JSON).

### 2.1 – Authentification (Devise + JWT)

Adapter le Devise existant pour une API JSON (devise-jwt ou devise token auth simple).

**Routes API :**
```
POST   /api/auth/register      → inscription
POST   /api/auth/login         → connexion, renvoie un token
DELETE /api/auth/logout         → déconnexion
GET    /api/auth/me             → utilisateur courant + personnage
```

### 2.2 – API Personnage

**Controller `Api::CharactersController`**

```
POST   /api/character              → créer son personnage (nom + répartition carac)
GET    /api/character              → récupérer son personnage complet
GET    /api/character/stats        → stats détaillées (carac + compétences calculées)
```

**Validations :**
- Un seul personnage par utilisateur
- Somme des carac = 12, chaque carac >= 1
- Nom obligatoire

### 2.3 – API Compétences

**Controller `Api::SkillsController`**

```
GET    /api/skills                 → toutes les compétences du personnage
PATCH  /api/skills/:id/upgrade    → monter une compétence (dépense XP)
```

**Service `SkillUpgradeService` :**
- Vérifie que le personnage a assez d'XP
- Calcule le coût : mastery actuel XP
- Incrémente bonus ; si bonus == 3, reset bonus à 0 et mastery += 1
- Déduit l'XP

### 2.4 – API Inventaire et Équipement

**Controller `Api::InventoryController`**

```
GET    /api/inventory              → inventaire complet
POST   /api/inventory/equip       → équiper un objet (par id)
POST   /api/inventory/unequip     → déséquiper
POST   /api/inventory/use         → utiliser un consommable
```

### 2.5 – API Magasin

**Controller `Api::ShopController`**

```
GET    /api/shop                   → catalogue complet (items + équipements à vendre)
POST   /api/shop/buy               → acheter (item_key, quantity)
POST   /api/shop/sell              → vendre (inventory_item_id, quantity)
```

**Logique :**
- Achat : vérifier l'or suffisant, déduire, ajouter à l'inventaire
- Vente : prix de revente = 50% du prix d'achat, arrondi au supérieur
- Bonus de marchandage : le jet de charisme/marchandage peut donner un meilleur prix (optionnel, phase ultérieure)

### 2.6 – API Actions en ville

**Controller `Api::TownController`**

```
POST   /api/town/work              → travailler à la forge
POST   /api/town/academy/start     → commencer l'apprentissage d'une magie
POST   /api/town/academy/complete  → terminer/vérifier l'apprentissage
POST   /api/town/guild/start       → commencer l'apprentissage d'une technique
POST   /api/town/guild/complete    → terminer/vérifier l'apprentissage
POST   /api/town/rest              → se reposer (regagne PV, fait passer 1 jour)
```

**Service `WorkService` :**
- Fait gagner de l'or : jet de vigueur × 5 pièces d'or
- Avance le temps de 1 jour

**Service `AcademyService` :**
- Choisir un élément et un sort (doit respecter l'ordre des tiers)
- Durée d'apprentissage = `(tier × 3) - intelligence` jours (minimum 1)
- Verrouille le personnage pendant la durée (activity = "academie")
- Chaque appel à `complete` fait passer 1 jour et décompte ; si fini, ajoute la magie

**Service `GuildService` :**
- Même logique que l'académie mais pour les techniques
- Durée = `(rang × 2) - vigueur` jours (minimum 1)
- Verrouille le personnage (activity = "guilde")

### 2.7 – API Combat (Tour d'ascension)

**Controller `Api::TowerController`**

```
GET    /api/tower                  → info sur l'étage actuel / prochain
POST   /api/tower/enter            → entrer dans l'étage suivant, initialise le combat
GET    /api/tower/combat           → état du combat en cours
POST   /api/tower/combat/action    → jouer une action (attack, technique, magic, item)
POST   /api/tower/flee             → fuir le combat
```

**Service `CombatService` (le cœur du jeu) :**

Ce service gère un combat complet. L'état du combat est stocké en session ou en cache (Redis/mémoire) pendant le combat, puis enregistré en `CombatLog` à la fin.

**État du combat (stocké en `combat_sessions`, cache ou jsonb temporaire) :**
```ruby
{
  floor: 5,
  turn: 1,
  player: { hp: 12, max_hp: 12, mana: 9, max_mana: 9, statuses: [] },
  enemies: [
    { key: "gobelin", name: "Gobelin", hp: 6, max_hp: 6, stats: {...}, statuses: [] },
    ...
  ],
  log: ["Le combat commence à l'étage 5 !"]
}
```

**Déroulement d'un tour :**
1. **Action du joueur** : choix parmi attaque / technique / magie / objet
2. **Résolution de l'action joueur** :
   - **Attaque simple** : jet de compétence d'arme (ex: "Arme à une main" si épée) + accuracy_bonus de l'arme → opposé au jet d'esquive OU de parade de l'ennemi. Si touché : jet de dégâts = vigueur (mêlée) ou dextérité (distance) + damage_mastery/bonus de l'arme − jet de vigueur de l'ennemi (résistance corporelle) − DR armure ennemi. Minimum 0 dégâts (ou 1 si touché).
   - **Technique** : effet spécifique selon la technique (voir section Techniques)
   - **Magie** : jet d'intelligence + compétence d'élément pour toucher, effets variables
   - **Objet** : effet immédiat (soin, buff, dégâts)
3. **Actions des ennemis** : chaque ennemi vivant attaque le joueur
4. **Gestion des statuts** : tick des statuts (poison, saignement, régénération, etc.)
5. **Vérification de fin** : tous les ennemis morts → victoire ; joueur mort → défaite

**Système de jets de dés :**
```ruby
# Service DiceRoller
def self.roll(mastery, bonus = 0)
  total = Array.new(mastery) { rand(1..6) }.sum + bonus
  { total: total, rolls: rolls, bonus: bonus }
end

def self.opposed_roll(attacker_mastery, attacker_bonus, defender_mastery, defender_bonus)
  attack = roll(attacker_mastery, attacker_bonus)
  defense = roll(defender_mastery, defender_bonus)
  { hit: attack[:total] > defense[:total], attack: attack, defense: defense, margin: attack[:total] - defense[:total] }
end
```

**Récompenses de victoire :**
- XP : basé sur l'étage (formule : `etage × 3 + 5`, ajustable)
- Or : butin aléatoire (formule : `etage × 2 + rand(1..etage)`)
- Le temps avance de 1 jour

### 2.8 – Service `MonsterFactory`

Génère les monstres pour chaque étage à partir du catalogue `tour.md`.

Chaque type de monstre a des stats prédéfinies (à définir dans un fichier `config/catalog/monstres.yml`) :

```yaml
monsters:
  rat_geant:
    name: "Rat géant"
    hp: 4
    vigueur: { mastery: 1, bonus: 0 }
    dexterite: { mastery: 1, bonus: 1 }
    esquive: { mastery: 1, bonus: 0 }
    attack: { mastery: 1, bonus: 0 }
    damage: { mastery: 1, bonus: 0 }
    xp_value: 3
    gold_value: 2
    abilities: []

  gobelin:
    name: "Gobelin"
    hp: 6
    vigueur: { mastery: 1, bonus: 0 }
    # ...etc
```

**Il faudra créer ce fichier `config/catalog/monstres.yml`** avec tous les types de monstres de la tour. C'est un gros fichier, à faire en une étape dédiée.

---

## Phase 3 – Frontend : Pages et composants Vue

### Objectif
Construire l'interface utilisateur complète en Vue 3 + Tailwind.
Ambiance : médiéval-fantastique sombre, palette de couleurs terre/or/rouge foncé.

### 3.1 – Store Pinia principal : `useGameStore`

```
app/frontend/stores/game.js
```

**State :**
- `character` : données complètes du personnage
- `skills` : compétences
- `inventory` : inventaire
- `equipment` : équipement porté
- `combat` : état du combat en cours (null si pas en combat)
- `loading` : état de chargement
- `notifications` : messages de jeu

**Actions :**
- `fetchCharacter()` – charge le personnage depuis l'API
- `createCharacter(data)` – crée le personnage
- `fetchSkills()`, `upgradeSkill(id)`
- `fetchInventory()`, `equipItem(id)`, `unequipItem(id)`, `useItem(id)`
- `work()`, `startAcademy(magic)`, `startGuild(technique)`
- `enterFloor()`, `combatAction(action)`, `flee()`

### 3.2 – Layout et navigation

**`App.vue`** – Layout principal avec :
- Barre de navigation latérale (en ville) OU interface de combat (en tour)
- Zone de contenu principale
- Barre de statut en haut (PV, mana, or, XP, date)

### 3.3 – Pages

| Route | Composant | Description |
|---|---|---|
| `/` | `Login.vue` | Page de connexion Devise |
| `/register` | `Register.vue` | Page d'inscription |
| `/create` | `CharacterCreation.vue` | Création de personnage |
| `/town` | `Town.vue` | Dashboard principal, la ville |
| `/town/character` | `CharacterSheet.vue` | Fiche du personnage |
| `/town/inventory` | `Inventory.vue` | Inventaire et équipement |
| `/town/shop` | `Shop.vue` | Le magasin |
| `/town/forge` | `Forge.vue` | Travailler à la forge |
| `/town/academy` | `Academy.vue` | Académie des mages |
| `/town/guild` | `Guild.vue` | Guilde des guerriers |
| `/tower` | `Tower.vue` | Tour d'ascension (info) |
| `/tower/combat` | `Combat.vue` | Interface de combat |

### 3.4 – Composants réutilisables

| Composant | Rôle |
|---|---|
| `StatusBar.vue` | Barre de statut persistante (PV, mana, or, XP, date) |
| `DiceResult.vue` | Affichage animé d'un jet de dés |
| `ItemCard.vue` | Carte d'objet/équipement |
| `SkillRow.vue` | Ligne de compétence avec bouton upgrade |
| `CombatLog.vue` | Journal de combat scrollable |
| `EnemyCard.vue` | Carte d'ennemi avec barre de PV |
| `ActionMenu.vue` | Menu d'actions en combat |
| `TownNav.vue` | Navigation entre les lieux de la ville |
| `HealthBar.vue` | Barre de PV animée |
| `Notification.vue` | Toast de notification |
| `Modal.vue` | Modale réutilisable |
| `DiceAnimation.vue` | Animation de lancer de dés |

### 3.5 – Page de création de personnage (`CharacterCreation.vue`)

- Champ de nom
- 5 sliders/compteurs pour répartir 12 points (min 1, max 8 chacun)
- Affichage en temps réel des PV calculés (vigueur × 3)
- Affichage en temps réel de la mana calculée (intelligence × 3)
- Récapitulatif des compétences de départ
- Bouton de validation avec confirmation

### 3.6 – Dashboard Ville (`Town.vue`)

Écran central avec des cartes cliquables pour chaque lieu :
- **La forge** (icône enclume) – travailler pour de l'or
- **Le magasin** (icône bourse) – acheter/vendre
- **L'académie des mages** (icône livre) – apprendre des magies
- **La guilde des guerriers** (icône épée) – apprendre des techniques
- **La tour d'ascension** (icône tour) – entrer dans la tour
- **Fiche personnage** (icône parchemin) – voir ses stats
- **Inventaire** (icône sac) – gérer son inventaire

Si le personnage est en activité (forge/académie/guilde), afficher un message indiquant l'activité en cours et les jours restants, avec un bouton pour passer le(s) jour(s).

### 3.7 – Interface de combat (`Combat.vue`)

- **Zone supérieure** : les ennemis avec leurs barres de PV et noms
- **Zone centrale** : le journal de combat (défilant, dernières actions)
- **Zone inférieure** : menu d'action du joueur
  - Onglet Attaque : attaque simple avec l'arme équipée
  - Onglet Techniques : liste des techniques apprises
  - Onglet Magies : liste des magies apprises
  - Onglet Objets : consommables de l'inventaire
  - Bouton Fuir
- **Barre latérale** : PV/Mana du joueur, statuts actifs

Chaque action déclenche un appel API et affiche le résultat avec des animations de dés.

---

## Phase 4 – Mécaniques de jeu détaillées

### 4.1 – Fichier `config/catalog/monstres.yml`

Créer un fichier complet avec tous les monstres de la tour. Chaque monstre a :
- `name`, `hp`, `vigueur`, `dexterite`, `esquive`, `attack_skill`, `damage`, `dr` (réduction de dégâts), `abilities` (techniques/magies), `xp_value`, `gold_value`

Les stats montent progressivement :
- Étages 1-10 : mastery 1, faibles PV
- Étages 11-20 : mastery 1-2
- Étages 21-30 : mastery 2
- ...jusqu'à mastery 5-6+ pour les derniers étages

Les boss ont des stats spéciales et des capacités uniques.

### 4.2 – Détail des techniques

Chaque technique a un effet mécanique précis. À définir dans `config/catalog/techniques.yml` :

**Exemples d'effets :**
- **Coup rapide** : attaque à +2 bonus précision, -1 bonus dégâts
- **Coup chargé** : attaque à -1 bonus précision, +3 bonus dégâts
- **Double entaille** : 2 attaques à -1 mastery chacune
- **Frappe circulaire** : touche tous les ennemis, -1 mastery
- **Estoc perforant** : ignore la moitié de la DR ennemie
- **Brise-garde** : réduit la parade ennemie de 2 pour le reste du combat
- **Exécution** : dégâts ×2 si l'ennemi a moins de 25% PV
- **Parade parfaite** : jet de parade à +3, contre-attaque si réussi
- **Posture défensive** : +2 esquive/parade ce tour, pas d'attaque
- **Contre-attaque** : si l'ennemi rate, riposte automatique
- **Saignée** : inflige Saignement (1D dégâts/tour pendant 3 tours)
- **Étourdissement** : chance d'infliger Étourdi (perd son prochain tour)
- ...etc.

### 4.3 – Détail des magies

À définir dans `config/catalog/magies.yml` (version enrichie) :

**Chaque magie a :** `key`, `name`, `element`, `tier`, `mana_cost`, `effect_type`, `base_damage_mastery`, `base_damage_bonus`, `accuracy_mastery_modifier`, `special_effect`, `description`

**Exemples :**
- **Étincelle** (Feu T1) : 2 mana, 1D+2 dégâts feu
- **Boule de feu** (Feu T2) : 4 mana, 2D+1 dégâts feu, chance de Brûlé
- **Soin léger** (Lumière T2) : 3 mana, soigne 1D+2 PV
- **Drain vital** (Ombre T3) : 5 mana, dégâts et soigne le lanceur de la moitié
- ...etc.

Précision magique = compétence de l'élément (Intelligence + bonus) vs esquive ennemie.

### 4.4 – Détail des statuts

À définir dans `config/catalog/statuts.yml` :

| Statut | Type | Effet |
|---|---|---|
| Empoisonné | Négatif | -1D PV par tour pendant 3 tours |
| Brûlé | Négatif | -1D+1 PV par tour pendant 2 tours |
| Gelé | Négatif | -1 mastery à toutes les actions pendant 2 tours |
| Paralysé | Négatif | 50% de chance de ne pas agir, 1 tour |
| Aveuglé | Négatif | -2 mastery en précision pendant 2 tours |
| Saignement | Négatif | -1D PV par tour pendant 3 tours |
| Confus | Négatif | 25% chance de se frapper, 2 tours |
| Terrorisé | Négatif | -1 mastery à tout pendant 2 tours |
| Maudit | Négatif | -1 à tous les bonus pendant 3 tours |
| Affaibli | Négatif | -1 mastery en dégâts pendant 3 tours |
| Silencé | Négatif | Impossible d'utiliser la magie pendant 2 tours |
| Étourdi | Négatif | Perd son prochain tour |
| Régénération | Positif | +1D PV par tour pendant 3 tours |
| Enragé | Positif | +1 mastery dégâts, -1 mastery défense, 3 tours |
| Inspiré | Positif | +1 bonus à tout pendant 2 tours |
| Concentré | Positif | +1 mastery précision pendant 2 tours |
| Protégé | Positif | +1 mastery DR pendant 2 tours |
| Accéléré | Positif | Agit en premier + +1 esquive, 2 tours |
| Béni | Positif | +1 à tous les jets pendant 3 tours |
| Invisible | Positif | Première attaque automatiquement réussie, 1 tour |

### 4.5 – Calculs de combat détaillés

**Attaque mêlée :**
1. Jet de toucher : compétence d'arme (ex: "Arme à une main") + accuracy_bonus équipement
2. Jet de défense : esquive OU parade de la cible
3. Si toucher > défense → touché
4. Jet de dégâts : vigueur du joueur + damage_mastery/bonus de l'arme
5. Jet de résistance : vigueur de la cible + DR armure
6. Dégâts infligés = max(1, dégâts - résistance) si touché

**Attaque à distance :**
- Idem mais compétence "Arc" pour toucher
- Dégâts = dextérité + damage_mastery/bonus de l'arme
- La cible ne peut pas parer (esquive uniquement)

**Attaque magique :**
- Jet de toucher : compétence de l'élément (ex: "Feu") + bonus éventuels
- Défense : esquive de la cible
- Dégâts : base de la magie (indépendant des stats, mais modifié par le tier)

---

## Phase 5 – Finitions et polish

### 5.1 – Images et assets

- Préparer des images d'ambiance pour chaque lieu de la ville
- Images pour les monstres de la tour (au moins par catégorie)
- Icônes pour les objets, équipements, compétences
- Fond de page thématique

### 5.2 – Animations et UX

- Animation de lancer de dés (CSS/JS)
- Transitions entre les pages
- Animations de barres de PV (descente progressive)
- Effets visuels pour les coups critiques
- Sons optionnels (cliquetis de dés, coups d'épée)

### 5.3 – Équilibrage

- Tester la progression de difficulté de la tour
- Ajuster les prix du magasin
- Vérifier que les revenus de la forge sont cohérents
- Vérifier les durées d'apprentissage
- S'assurer qu'aucun build n'est totalement non-viable

---

## Ordre d'implémentation recommandé

### Sprint 1 – Fondations (Phase 1 + 2.1-2.2) ✅ TERMINÉ
1. ✅ ~~Migrations de base de données (Character, Skill, InventoryItem, LearnedTechnique, LearnedMagic, CombatLog)~~
2. ✅ ~~Modèles Rails avec validations et associations~~
3. ✅ ~~Service GameCatalog (chargement des fichiers YAML/MD)~~
4. ✅ ~~Service DiceRoller~~
5. ✅ ~~Initialisation automatique des compétences à la création~~
6. ✅ ~~Auth API (adapter Devise pour JSON avec token)~~
7. ✅ ~~API Character (création + consultation + stats)~~

### Sprint 2 – Ville et économie (Phase 2.3-2.6 + Phase 3.1-3.6) ✅ TERMINÉ
8. ✅ ~~API Compétences + SkillUpgradeService~~
9. ✅ ~~API Inventaire + Équipement~~
10. ✅ ~~API Magasin (achat/vente)~~
11. ✅ ~~API Actions en ville (forge, académie, guilde, repos)~~
12. ✅ ~~Frontend : Store Pinia game.js~~
13. ✅ ~~Frontend : pages Login, Register, CharacterCreation~~
14. ✅ ~~Frontend : Town dashboard + navigation + StatusBar~~
15. ✅ ~~Frontend : CharacterSheet, Inventory, Shop, Academy, Guild, Tower~~

### Sprint 3 – Combat (Phase 2.7-2.8 + Phase 3.7 + Phase 4) ✅ TERMINÉ
16. ✅ ~~Créer `config/catalog/monstres.yml` complet~~ (53 types de monstres, mapping noms→clés)
17. ✅ ~~Créer `config/catalog/techniques.yml` et `config/catalog/magies.yml` enrichis~~ (30 techniques, 35 magies)
18. ✅ ~~Créer `config/catalog/statuts.yml`~~ (20 statuts avec effets mécaniques)
18. ✅ ~~Service DiceRoller~~
19. ✅ ~~Service MonsterFactory~~ (génération depuis tour.md + monstres.yml)
20. ✅ ~~Service CombatService~~ (attaque, techniques, magie, objets, fuite, statuts, ennemis IA)
21. ✅ ~~API Tower + Combat~~ (TowerController: info/enter/combat/action/flee)
22. ✅ ~~Frontend : Tower info + Combat UI~~ (Tower.vue refait + Combat.vue complet)
23. ✅ ~~Frontend : Animations de dés et combat~~

### Sprint 4 – Polish (Phase 5) ✅ TERMINÉ
24. ✅ ~~Images et assets~~ (8 images compressées PNG→WebP, 92% réduction, icônes SVG pour objets/équipements)
25. ✅ ~~Animations et transitions~~ (fade-in-up staggeré, transitions de page, CSS animations dés/shake/glow)
26. ✅ ~~UX et thème visuel~~ (refonte Town avec images, cards avec bg images, design system CSS, composants TownCard/ItemIcon)

---

## Schéma de la base de données (résumé)

```
users
  ├── has_one :character
  
characters
  ├── has_many :skills
  ├── has_many :inventory_items
  ├── has_many :learned_techniques
  ├── has_many :learned_magics
  ├── has_many :combat_logs
```

## Arborescence des fichiers à créer

```
app/
├── controllers/
│   └── api/
│       ├── base_controller.rb
│       ├── auth_controller.rb
│       ├── characters_controller.rb
│       ├── skills_controller.rb
│       ├── inventory_controller.rb
│       ├── shop_controller.rb
│       ├── town_controller.rb
│       └── tower_controller.rb
├── models/
│   ├── user.rb (modifier)
│   ├── character.rb
│   ├── skill.rb
│   ├── inventory_item.rb
│   ├── learned_technique.rb
│   ├── learned_magic.rb
│   └── combat_log.rb
├── services/
│   ├── game_catalog.rb
│   ├── dice_roller.rb
│   ├── skill_upgrade_service.rb
│   ├── work_service.rb
│   ├── academy_service.rb
│   ├── guild_service.rb
│   ├── monster_factory.rb
│   ├── combat_service.rb
│   └── shop_service.rb
├── frontend/
│   ├── stores/
│   │   └── game.js
│   ├── pages/
│   │   ├── Login.vue
│   │   ├── Register.vue
│   │   ├── CharacterCreation.vue
│   │   ├── Town.vue
│   │   ├── CharacterSheet.vue
│   │   ├── Inventory.vue
│   │   ├── Shop.vue
│   │   ├── Forge.vue
│   │   ├── Academy.vue
│   │   ├── Guild.vue
│   │   ├── Tower.vue
│   │   └── Combat.vue
│   └── components/
│       ├── StatusBar.vue
│       ├── DiceResult.vue
│       ├── ItemCard.vue
│       ├── SkillRow.vue
│       ├── CombatLog.vue
│       ├── EnemyCard.vue
│       ├── ActionMenu.vue
│       ├── TownNav.vue
│       ├── HealthBar.vue
│       ├── Notification.vue
│       ├── Modal.vue
│       └── DiceAnimation.vue
config/
└── catalog/
    ├── competences.md ✅ (existe)
    ├── equipement.yml ✅ (existe)
    ├── magies.md ✅ (existe)
    ├── objets.yaml ✅ (existe)
    ├── statuts.md ✅ (existe)
    ├── techniques.md ✅ (existe)
    ├── tour.md ✅ (existe)
    ├── monstres.yml (À CRÉER)
    ├── techniques.yml (À CRÉER – version enrichie avec mécaniques)
    ├── magies.yml (À CRÉER – version enrichie avec mécaniques)
    └── statuts.yml (À CRÉER – version enrichie avec mécaniques)
db/
└── migrate/
    ├── xxx_create_characters.rb
    ├── xxx_create_skills.rb
    ├── xxx_create_inventory_items.rb
    ├── xxx_create_learned_techniques.rb
    ├── xxx_create_learned_magics.rb
    └── xxx_create_combat_logs.rb
```

---

## Notes techniques

- **État du combat** : stocké côté serveur dans un champ `combat_state` (jsonb) sur le Character, ou dans le cache Rails. Cela évite la triche côté client. Le client ne fait qu'envoyer des actions et recevoir les résultats.
- **Sérialisation API** : utiliser des serializers simples (ou `as_json` avec `only/include`) pour les réponses JSON. Pas besoin de gems complexes pour ce projet.
- **Sécurité** : toute la logique de jeu est côté serveur. Le client affiche et envoie des commandes. Le joueur ne peut pas tricher sur ses stats, ses dés, ou ses PV.
- **Seed de données** : un fichier `db/seeds.rb` pour créer un utilisateur de test avec un personnage pré-fait (utile pour le développement).
