<template>
  <div class="min-h-screen bg-stone-950 text-stone-200">
    <StatusBar />

    <div class="max-w-5xl mx-auto px-4 py-8">
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center gap-3">
          <h1 class="text-2xl font-bold text-amber-400">Forteresse</h1>
          <button @click="showHelp = true"
            class="w-7 h-7 rounded-full bg-stone-800 border border-stone-600 text-stone-400 hover:text-amber-400 hover:border-amber-400 text-sm font-bold transition"
            title="Comment ça marche ?">
            ?
          </button>
        </div>
        <router-link to="/town" class="text-stone-500 hover:text-amber-400 transition text-sm">
          Retour en ville
        </router-link>
      </div>
      <p class="text-stone-500 text-sm mb-6 -mt-4">Placez des défenses pour protéger la ville</p>

      <!-- Info gold + workshop + repair all -->
      <div class="flex flex-wrap gap-4 mb-6 items-center">
        <div class="bg-stone-900 border border-stone-700 rounded-lg px-4 py-2 text-sm">
          <span class="text-yellow-400">{{ fortressData?.gold || 0 }}</span> or
        </div>
        <div class="bg-stone-900 border border-stone-700 rounded-lg px-4 py-2 text-sm">
          Atelier Nv. <span class="text-amber-400">{{ fortressData?.workshop_level || 0 }}</span>
          — Max <span class="text-amber-400">{{ fortressData?.max_traps_per_direction || 1 }}</span> pièges/direction
        </div>
        <button v-if="totalRepairCost > 0"
          @click="repairAll"
          :disabled="(fortressData?.gold || 0) < totalRepairCost"
          class="ml-auto bg-amber-700 hover:bg-amber-600 disabled:opacity-40 disabled:cursor-not-allowed rounded-lg px-4 py-2 text-sm font-semibold transition">
          Tout réparer ({{ totalRepairCost }} or)
        </button>
      </div>

      <!-- 4 directions grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-8">
        <div v-for="dir in directions" :key="dir"
          class="bg-stone-900 border border-stone-700 rounded-xl p-4">
          <div class="flex items-center justify-between mb-3">
            <h3 class="font-semibold text-lg" :class="directionColor(dir)">
              {{ directionLabel(dir) }}
            </h3>
            <span class="text-xs text-stone-500">
              {{ directionDefenses(dir).length }}/{{ fortressData?.max_traps_per_direction || 1 }}
            </span>
          </div>

          <!-- Active synergies in this direction -->
          <div v-if="directionSynergies(dir).length" class="mb-3 flex flex-wrap gap-2">
            <span v-for="syn in directionSynergies(dir)" :key="syn.key"
              :title="syn.description"
              class="text-xs bg-emerald-900/40 border border-emerald-700/60 text-emerald-300 rounded-full px-2 py-0.5">
              ✦ {{ syn.name }}
            </span>
          </div>

          <!-- Placed traps -->
          <div class="space-y-2 mb-3">
            <div v-for="(defense, idx) in directionDefenses(dir)" :key="defense.id"
              class="bg-stone-800 rounded-lg px-3 py-2"
              :class="{ 'opacity-60': defense.broken }">
              <div class="flex items-center justify-between gap-2">
                <div class="flex items-center gap-2 min-w-0">
                  <span class="text-xs text-stone-500 w-5 shrink-0">{{ idx + 1 }}.</span>
                  <div class="min-w-0">
                    <div class="flex items-center gap-2 flex-wrap">
                      <span class="text-sm font-medium truncate">{{ defense.trap?.name || defense.trap_key }}</span>
                      <span class="text-xs" :class="trapTypeColor(defense.trap?.type)">{{ trapTypeLabel(defense.trap?.type) }}</span>
                      <span v-if="defense.well_placed" title="Bien placé : +1 sur l'effet"
                        class="text-xs text-emerald-400">★</span>
                      <span v-if="defense.broken" class="text-xs text-red-500 font-semibold">CASSÉ</span>
                    </div>
                    <!-- Durability bar -->
                    <div class="flex items-center gap-2 mt-1">
                      <div class="h-1.5 bg-stone-700 rounded-full overflow-hidden flex-1 max-w-[120px]">
                        <div class="h-full transition-all"
                          :class="durabilityColor(defense)"
                          :style="{ width: durabilityPct(defense) + '%' }"></div>
                      </div>
                      <span class="text-xs text-stone-500">{{ defense.durability }}/{{ defense.max_durability }}</span>
                    </div>
                  </div>
                </div>
                <div class="flex items-center gap-1 shrink-0">
                  <button v-if="idx > 0" @click="reorder(defense.id, 'up')"
                    class="text-stone-500 hover:text-amber-400 text-xs px-1" title="Monter">▲</button>
                  <button v-if="idx < directionDefenses(dir).length - 1" @click="reorder(defense.id, 'down')"
                    class="text-stone-500 hover:text-amber-400 text-xs px-1" title="Descendre">▼</button>
                  <button v-if="defense.damaged"
                    @click="repair(defense.id)"
                    :disabled="(fortressData?.gold || 0) < defense.repair_cost"
                    class="text-amber-400 hover:text-amber-300 text-xs px-2 disabled:opacity-30 disabled:cursor-not-allowed"
                    :title="`Réparer (${defense.repair_cost} or)`">
                    Réparer
                  </button>
                  <button @click="removeTrap(defense.id)"
                    class="text-red-500 hover:text-red-400 text-xs px-1">
                    ✕
                  </button>
                </div>
              </div>
            </div>
            <div v-if="!directionDefenses(dir).length"
              class="text-stone-600 text-sm text-center py-3">
              Aucune défense
            </div>
          </div>

          <!-- Add trap button -->
          <button v-if="canAddTrap(dir)"
            @click="openTrapSelector(dir)"
            class="w-full bg-stone-800 hover:bg-stone-700 border border-dashed border-stone-600 rounded-lg py-2 text-sm text-stone-400 hover:text-amber-400 transition">
            + Ajouter un piège
          </button>
        </div>
      </div>

      <!-- Help modal -->
      <div v-if="showHelp" class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
        <div class="bg-stone-900 border border-stone-700 rounded-xl p-6 max-w-2xl w-full max-h-[85vh] overflow-y-auto">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-xl font-semibold text-amber-400">Comment défendre la forteresse</h3>
            <button @click="showHelp = false" class="text-stone-500 hover:text-stone-300 transition text-sm">
              Fermer
            </button>
          </div>

          <div class="space-y-5 text-sm text-stone-300">
            <section>
              <h4 class="text-amber-300 font-semibold mb-1">Le principe</h4>
              <p>Chaque semaine, une vague d'ennemis attaque l'une des 4 directions. Vous ignorez laquelle (sauf si la <span class="text-amber-400">Vigie</span> est améliorée). Disposez vos défenses dans les 4 ailes pour parer à toute éventualité.</p>
            </section>

            <section>
              <h4 class="text-amber-300 font-semibold mb-1">Capacité — l'Atelier</h4>
              <p>Le niveau de l'<span class="text-amber-400">Atelier</span> détermine le nombre maximum de pièges par direction (1 à 5). Améliorez-le pour empiler plus de défenses et déclencher des synergies.</p>
            </section>

            <section>
              <h4 class="text-amber-300 font-semibold mb-1">Types de pièges</h4>
              <ul class="space-y-1 ml-4 list-disc">
                <li><span class="text-red-400 font-medium">Dégâts</span> — inflige des dégâts directs à chaque ennemi avant le combat</li>
                <li><span class="text-blue-400 font-medium">Protection</span> — augmente votre résistance aux dégâts (DR) pendant le siège</li>
                <li><span class="text-purple-400 font-medium">Ralentissement</span> — réduit l'esquive des ennemis (plus faciles à toucher)</li>
                <li><span class="text-amber-400 font-medium">Affaiblissement</span> — diminue l'attaque et les dégâts ennemis</li>
              </ul>
            </section>

            <section>
              <h4 class="text-amber-300 font-semibold mb-1">Position dans la ligne <span class="text-emerald-400">★</span></h4>
              <p>Chaque piège a un rôle privilégié indiqué à l'achat :</p>
              <ul class="space-y-1 ml-4 list-disc mt-1">
                <li><span class="text-emerald-400">Ligne avant</span> (1ère position) : barricades, pièges à pointes, murs…</li>
                <li><span class="text-emerald-400">Ligne arrière</span> (dernière position) : ralentisseurs, sceaux, tours…</li>
              </ul>
              <p class="mt-1">Un piège placé à sa position préférée gagne <span class="text-emerald-400">+1 sur son effet</span> et affiche une étoile ★. Utilisez les flèches ▲▼ pour réorganiser.</p>
            </section>

            <section>
              <h4 class="text-amber-300 font-semibold mb-1">Synergies ✦</h4>
              <p class="mb-2">Quand certains types de pièges cohabitent dans la même direction, des synergies s'activent automatiquement (affichées en vert sur la direction concernée) :</p>
              <ul class="space-y-2 ml-4 list-disc">
                <li v-for="(syn, key) in (fortressData?.synergies_catalog || {})" :key="key">
                  <span class="text-emerald-300 font-medium">{{ syn.name }}</span> — {{ syn.description }}
                  <span class="text-stone-500 block text-xs">{{ synergyRequirementText(syn) }}</span>
                </li>
              </ul>
            </section>

            <section>
              <h4 class="text-amber-300 font-semibold mb-1">Durabilité et usure</h4>
              <p>Chaque piège a une barre de durabilité (verte → ambre → rouge). Après chaque siège, les défenses de la direction attaquée s'usent en fonction du <span class="text-amber-400">nombre de tours qu'a duré le combat</span> :</p>
              <ul class="space-y-1 ml-4 list-disc mt-1">
                <li>1 à 3 tours → -1 durabilité</li>
                <li>4 à 6 tours → -2</li>
                <li>7 à 9 tours → -3, etc.</li>
                <li><span class="text-red-400">Défaite : +1 supplémentaire</span></li>
              </ul>
              <p class="mt-1">Un piège à <span class="text-red-500 font-semibold">0 durabilité</span> est cassé et n'a plus aucun effet jusqu'à réparation.</p>
            </section>

            <section>
              <h4 class="text-amber-300 font-semibold mb-1">Réparation</h4>
              <p>Le coût de réparation est proportionnel aux dégâts subis (environ 40 % du prix d'achat pour une défense complètement cassée). Réparez piège par piège ou utilisez le bouton <span class="text-amber-400">"Tout réparer"</span> pour remettre toutes les défenses à neuf d'un coup.</p>
            </section>

            <section>
              <h4 class="text-amber-300 font-semibold mb-1">Stratégie</h4>
              <p>Disposez au moins une défense par direction (l'attaque est aléatoire si la Vigie est faible). Empilez les synergies dans les directions les plus probables une fois la Vigie améliorée. Pensez à réparer entre les sièges !</p>
            </section>
          </div>
        </div>
      </div>

      <!-- Trap selector modal -->
      <div v-if="selectedDirection" class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
        <div class="bg-stone-900 border border-stone-700 rounded-xl p-6 max-w-lg w-full max-h-[80vh] overflow-y-auto">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-semibold text-amber-400">
              Choisir un piège — {{ directionLabel(selectedDirection) }}
            </h3>
            <button @click="selectedDirection = null" class="text-stone-500 hover:text-stone-300 transition">
              Fermer
            </button>
          </div>

          <div class="space-y-2">
            <button v-for="[key, trap] in availableTraps" :key="key"
              @click="placeTrap(key)"
              :disabled="(fortressData?.gold || 0) < trap.cost"
              class="w-full bg-stone-800 hover:bg-stone-700 rounded-lg p-3 text-left transition disabled:opacity-40 disabled:cursor-not-allowed">
              <div class="flex justify-between items-start">
                <div>
                  <div class="font-semibold text-sm flex items-center gap-2">
                    {{ trap.name }}
                    <span class="text-xs" :class="trapTypeColor(trap.type)">{{ trapTypeLabel(trap.type) }}</span>
                    <span v-if="trap.role && trap.role !== 'flex'" class="text-xs text-stone-500">
                      ({{ trap.role === 'front' ? 'ligne avant' : 'ligne arrière' }})
                    </span>
                  </div>
                  <div class="text-xs text-stone-500 mt-1">{{ trap.description }}</div>
                  <div class="text-xs mt-1" :class="trapTypeColor(trap.type)">
                    {{ trapEffectLabel(trap) }}
                  </div>
                  <div class="text-xs text-stone-500 mt-1">
                    Durabilité : {{ trap.max_durability || 5 }}
                  </div>
                </div>
                <span class="text-yellow-400 text-sm whitespace-nowrap ml-3">{{ trap.cost }} or</span>
              </div>
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useGameStore } from '../stores/game'
import StatusBar from '../components/game/StatusBar.vue'

const gameStore = useGameStore()
const selectedDirection = ref(null)
const showHelp = ref(false)

const directions = ['nord', 'sud', 'est', 'ouest']

const fortressData = computed(() => gameStore.fortressData)

const availableTraps = computed(() => {
  if (!fortressData.value?.available_traps) return []
  return Object.entries(fortressData.value.available_traps)
})

const totalRepairCost = computed(() => fortressData.value?.total_repair_cost || 0)

function directionDefenses(dir) {
  return fortressData.value?.defenses?.[dir]?.defenses || []
}

function directionSynergies(dir) {
  return fortressData.value?.defenses?.[dir]?.synergies || []
}

function directionLabel(dir) {
  const labels = { nord: 'Nord', sud: 'Sud', est: 'Est', ouest: 'Ouest' }
  return labels[dir] || dir
}

function directionColor(dir) {
  const colors = { nord: 'text-blue-400', sud: 'text-red-400', est: 'text-green-400', ouest: 'text-purple-400' }
  return colors[dir] || 'text-amber-400'
}

function trapTypeLabel(type) {
  const labels = { damage: 'Dégâts', barrier: 'Protection', slow: 'Ralentissement', weaken: 'Affaiblissement' }
  return labels[type] || type
}

function trapTypeColor(type) {
  const colors = { damage: 'text-red-400', barrier: 'text-blue-400', slow: 'text-purple-400', weaken: 'text-amber-400' }
  return colors[type] || 'text-stone-400'
}

function synergyRequirementText(syn) {
  const parts = []
  if (syn.requires_types?.length) {
    const labels = syn.requires_types.map(t => trapTypeLabel(t))
    parts.push(`Nécessite : ${labels.join(' + ')}`)
  }
  if (syn.requires_count) {
    for (const [type, n] of Object.entries(syn.requires_count)) {
      parts.push(`${n}+ pièges de type ${trapTypeLabel(type)}`)
    }
  }
  return parts.join(' · ')
}

function trapEffectLabel(trap) {
  switch (trap.type) {
    case 'damage': return `${trap.damage} dégâts à chaque ennemi`
    case 'barrier': return `+${trap.dr_bonus} résistance aux dégâts`
    case 'slow': return `-${trap.esquive_penalty} esquive ennemie`
    case 'weaken': return `-${trap.attack_penalty || 0} attaque, -${trap.damage_penalty || 0} dégâts`
    default: return ''
  }
}

function durabilityPct(defense) {
  if (!defense.max_durability) return 0
  return Math.round((defense.durability / defense.max_durability) * 100)
}

function durabilityColor(defense) {
  const pct = durabilityPct(defense)
  if (pct === 0) return 'bg-red-700'
  if (pct < 35) return 'bg-red-500'
  if (pct < 70) return 'bg-amber-500'
  return 'bg-emerald-500'
}

function canAddTrap(dir) {
  const current = directionDefenses(dir).length
  return current < (fortressData.value?.max_traps_per_direction || 1)
}

function openTrapSelector(dir) {
  selectedDirection.value = dir
}

async function placeTrap(trapKey) {
  await gameStore.placeTrap(trapKey, selectedDirection.value)
  selectedDirection.value = null
}

async function removeTrap(defenseId) {
  await gameStore.removeTrap(defenseId)
}

async function repair(defenseId) {
  await gameStore.repairDefense(defenseId)
}

async function repairAll() {
  await gameStore.repairAllDefenses()
}

async function reorder(defenseId, move) {
  await gameStore.reorderDefense(defenseId, move)
}

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()
  await gameStore.fetchFortress()
})
</script>
