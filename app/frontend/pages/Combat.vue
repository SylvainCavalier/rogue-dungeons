<template>
  <div class="min-h-screen bg-stone-950 text-stone-200">
    <div class="max-w-4xl mx-auto px-4 py-6">

      <!-- Header -->
      <div class="flex items-center justify-between mb-4">
        <h1 class="text-xl font-bold text-red-400">
          Étage {{ combat?.floor }} — Tour {{ combat?.turn }}
        </h1>
        <span v-if="combat?.status === 'active'" class="text-xs text-stone-500">
          EN COMBAT
        </span>
      </div>

      <!-- Combat terminé -->
      <div v-if="isFinished" class="bg-stone-900 border rounded-xl p-8 text-center mb-6"
           :class="combat.status === 'victory' ? 'border-green-700' : 'border-red-700'">
        <div class="text-5xl mb-4">
          {{ combat.status === 'victory' ? '⚔️' : combat.status === 'fled' ? '🏃' : '💀' }}
        </div>
        <h2 class="text-2xl font-bold mb-2"
            :class="combat.status === 'victory' ? 'text-green-400' : combat.status === 'fled' ? 'text-yellow-400' : 'text-red-400'">
          {{ combat.status === 'victory' ? 'Victoire !' : combat.status === 'fled' ? 'Fuite réussie' : 'Défaite...' }}
        </h2>
        <div v-if="combat.rewards" class="text-amber-400 text-lg mb-4">
          +{{ combat.rewards.xp }} XP, +{{ combat.rewards.gold }} Or
        </div>
        <button @click="returnToTower"
          class="bg-stone-700 hover:bg-stone-600 text-white px-6 py-2 rounded-lg transition">
          Retour à la tour
        </button>
      </div>

      <!-- Combat actif -->
      <template v-else-if="combat?.status === 'active'">
        <!-- Player & Enemies side by side -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">

          <!-- Player card -->
          <div class="bg-stone-900 border border-stone-700 rounded-xl p-4">
            <h3 class="text-sm font-semibold text-amber-400 mb-3 uppercase tracking-wider">Joueur</h3>
            <div class="mb-2">
              <div class="flex justify-between text-sm mb-1">
                <span class="text-red-400">PV</span>
                <span>{{ combat.player.hp }}/{{ combat.player.max_hp }}</span>
              </div>
              <div class="w-full bg-stone-800 rounded-full h-3">
                <div class="bg-red-600 h-3 rounded-full transition-all duration-500"
                     :style="{ width: hpPercent + '%' }"></div>
              </div>
            </div>
            <div class="mb-2">
              <div class="flex justify-between text-sm mb-1">
                <span class="text-blue-400">Mana</span>
                <span>{{ combat.player.mana }}/{{ combat.player.max_mana }}</span>
              </div>
              <div class="w-full bg-stone-800 rounded-full h-3">
                <div class="bg-blue-600 h-3 rounded-full transition-all duration-500"
                     :style="{ width: manaPercent + '%' }"></div>
              </div>
            </div>
            <div v-if="combat.player.statuses?.length" class="flex flex-wrap gap-1 mt-2">
              <span v-for="s in combat.player.statuses" :key="s.name"
                class="text-xs px-2 py-0.5 rounded-full"
                :class="s.name === 'Régénération' || s.name === 'Protégé' || s.name === 'Béni' || s.name === 'Invisible' || s.name === 'Concentré' || s.name === 'Accéléré' || s.name === 'Inspiré'
                  ? 'bg-green-900 text-green-300' : 'bg-red-900 text-red-300'">
                {{ s.name }} ({{ s.remaining }})
              </span>
            </div>
          </div>

          <!-- Enemies card -->
          <div class="bg-stone-900 border border-stone-700 rounded-xl p-4">
            <h3 class="text-sm font-semibold text-red-400 mb-3 uppercase tracking-wider">Ennemis</h3>
            <div v-for="(enemy, i) in combat.enemies" :key="i" class="mb-3 last:mb-0">
              <div class="flex justify-between items-center mb-1">
                <span class="text-sm" :class="enemy.alive ? 'text-stone-200' : 'text-stone-600 line-through'">
                  {{ enemy.name }}
                </span>
                <span class="text-xs" :class="enemy.alive ? 'text-stone-400' : 'text-stone-600'">
                  {{ enemy.hp }}/{{ enemy.max_hp }}
                </span>
              </div>
              <div v-if="enemy.alive" class="w-full bg-stone-800 rounded-full h-2">
                <div class="bg-red-700 h-2 rounded-full transition-all duration-500"
                     :style="{ width: (enemy.hp / enemy.max_hp * 100) + '%' }"></div>
              </div>
              <div v-if="enemy.statuses?.length" class="flex flex-wrap gap-1 mt-1">
                <span v-for="s in enemy.statuses" :key="s.name"
                  class="text-xs px-1.5 py-0.5 rounded bg-amber-900/50 text-amber-300">
                  {{ s.name }} ({{ s.remaining }})
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Actions -->
        <div class="bg-stone-900 border border-stone-700 rounded-xl p-4 mb-4">
          <h3 class="text-sm font-semibold text-amber-400 mb-3 uppercase tracking-wider">Actions</h3>

          <!-- Tab buttons -->
          <div class="flex flex-wrap gap-2 mb-3">
            <button v-for="tab in actionTabs" :key="tab.id"
              @click="activeTab = tab.id"
              class="px-3 py-1.5 rounded-lg text-sm font-medium transition"
              :class="activeTab === tab.id
                ? 'bg-amber-700 text-white'
                : 'bg-stone-800 text-stone-400 hover:text-stone-200'">
              {{ tab.label }}
            </button>
          </div>

          <!-- Attack tab -->
          <div v-if="activeTab === 'attack'" class="space-y-2">
            <button @click="doAction('attack')" :disabled="acting"
              class="w-full bg-red-800 hover:bg-red-700 text-white py-3 rounded-lg font-semibold transition disabled:opacity-50">
              {{ acting ? '...' : 'Attaque simple' }}
            </button>
          </div>

          <!-- Techniques tab -->
          <div v-if="activeTab === 'techniques'" class="space-y-2">
            <div v-if="!learnedTechniques.length" class="text-stone-500 text-sm text-center py-4">
              Aucune technique apprise.
            </div>
            <button v-for="tech in learnedTechniques" :key="tech.key"
              @click="doAction('technique', { key: tech.key })" :disabled="acting"
              class="w-full bg-stone-800 hover:bg-stone-700 text-stone-200 py-2 px-4 rounded-lg text-sm text-left transition disabled:opacity-50">
              <span class="font-semibold">{{ tech.name }}</span>
              <span class="text-stone-500 ml-2 text-xs">{{ tech.description }}</span>
            </button>
          </div>

          <!-- Magic tab -->
          <div v-if="activeTab === 'magic'" class="space-y-2">
            <div v-if="!learnedMagics.length" class="text-stone-500 text-sm text-center py-4">
              Aucune magie apprise.
            </div>
            <button v-for="mag in learnedMagics" :key="mag.key"
              @click="doAction('magic', { key: mag.key })" :disabled="acting || combat.player.mana < (mag.mana_cost || 0)"
              class="w-full bg-stone-800 hover:bg-stone-700 text-stone-200 py-2 px-4 rounded-lg text-sm text-left transition disabled:opacity-50">
              <div class="flex justify-between">
                <span>
                  <span class="font-semibold">{{ mag.name }}</span>
                  <span class="text-stone-500 ml-2 text-xs">{{ mag.description }}</span>
                </span>
                <span class="text-blue-400 text-xs whitespace-nowrap ml-2">{{ mag.mana_cost }} mana</span>
              </div>
            </button>
          </div>

          <!-- Items tab -->
          <div v-if="activeTab === 'items'" class="space-y-2">
            <div v-if="!usableItems.length" class="text-stone-500 text-sm text-center py-4">
              Aucun objet utilisable.
            </div>
            <button v-for="item in usableItems" :key="item.id"
              @click="doAction('item', { item_id: item.id })" :disabled="acting"
              class="w-full bg-stone-800 hover:bg-stone-700 text-stone-200 py-2 px-4 rounded-lg text-sm text-left transition disabled:opacity-50">
              <span class="font-semibold">{{ item.name }}</span>
              <span class="text-stone-500 ml-2">x{{ item.quantity }}</span>
            </button>
          </div>

          <!-- Flee -->
          <div class="mt-3 pt-3 border-t border-stone-800">
            <button @click="tryFlee" :disabled="acting"
              class="text-stone-500 hover:text-yellow-400 text-sm transition disabled:opacity-50">
              Fuir le combat
            </button>
          </div>
        </div>

        <!-- Combat log -->
        <div class="bg-stone-900 border border-stone-700 rounded-xl p-4">
          <h3 class="text-sm font-semibold text-stone-400 mb-3 uppercase tracking-wider">Journal de combat</h3>
          <div ref="logContainer" class="max-h-64 overflow-y-auto space-y-1 text-sm font-mono">
            <div v-for="(line, i) in displayLog" :key="i"
              class="py-0.5 px-2 rounded"
              :class="logLineClass(line)">
              {{ line }}
            </div>
          </div>
        </div>
      </template>

      <!-- Loading -->
      <div v-else class="text-center py-20">
        <div class="text-stone-500">Chargement du combat...</div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useGameStore } from '../stores/game'
import apiClient from '../plugins/axios'

const gameStore = useGameStore()
const router = useRouter()

const combat = computed(() => gameStore.combatState)
const acting = ref(false)
const activeTab = ref('attack')
const logContainer = ref(null)
const learnedTechniques = ref([])
const learnedMagics = ref([])
const usableItems = ref([])

const isFinished = computed(() =>
  combat.value && ['victory', 'defeat', 'fled'].includes(combat.value.status)
)

const hpPercent = computed(() => {
  if (!combat.value?.player) return 0
  return (combat.value.player.hp / combat.value.player.max_hp * 100)
})

const manaPercent = computed(() => {
  if (!combat.value?.player) return 0
  return (combat.value.player.mana / combat.value.player.max_mana * 100)
})

const displayLog = computed(() => {
  if (!combat.value) return []
  if (combat.value.recent_log?.length) return combat.value.recent_log
  return combat.value.log || []
})

const actionTabs = [
  { id: 'attack', label: 'Attaque' },
  { id: 'techniques', label: 'Techniques' },
  { id: 'magic', label: 'Magie' },
  { id: 'items', label: 'Objets' },
]

async function doAction(type, params = {}) {
  acting.value = true
  try {
    await gameStore.combatAction(type, params)
    scrollLog()
  } finally {
    acting.value = false
  }
}

async function tryFlee() {
  acting.value = true
  try {
    await gameStore.fleeCombat()
    scrollLog()
  } finally {
    acting.value = false
  }
}

function returnToTower() {
  gameStore.combatState = null
  router.push('/tower')
}

function scrollLog() {
  nextTick(() => {
    if (logContainer.value) {
      logContainer.value.scrollTop = logContainer.value.scrollHeight
    }
  })
}

function logLineClass(line) {
  if (line.includes('Victoire') || line.includes('vaincu')) return 'bg-green-900/30 text-green-300'
  if (line.includes('Défaite') || line.includes('tombé')) return 'bg-red-900/30 text-red-300'
  if (line.includes('raté') || line.includes('Fuite échouée')) return 'text-stone-500'
  if (line.includes('dégâts') && line.includes('vous')) return 'text-red-300'
  if (line.includes('dégâts')) return 'text-amber-300'
  if (line.includes('PV') && (line.includes('+') || line.includes('récupér'))) return 'text-green-300'
  if (line.startsWith('---')) return 'text-stone-600 font-semibold'
  return 'text-stone-400'
}

async function loadCombatResources() {
  try {
    const [techRes, magRes, invRes] = await Promise.all([
      apiClient.get('/town/available_techniques'),
      apiClient.get('/town/available_magics'),
      apiClient.get('/inventory')
    ])

    const allTechs = Object.values(techRes.data.techniques || {}).flat()
    learnedTechniques.value = allTechs.filter(t => t.learned)

    const allMags = Object.values(magRes.data.magics || {}).flat()
    learnedMagics.value = allMags.filter(m => m.learned)

    usableItems.value = (invRes.data.items || []).filter(i => !i.equipped && i.item_type === 'item')
  } catch (e) { /* resources optional */ }
}

watch(displayLog, () => scrollLog())

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()

  try {
    await gameStore.fetchCombatState()
  } catch (e) {
    router.push('/tower')
    return
  }

  await loadCombatResources()
})
</script>
