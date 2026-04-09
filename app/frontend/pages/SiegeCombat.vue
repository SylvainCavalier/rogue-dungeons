<template>
  <div class="min-h-screen bg-stone-950 text-stone-200">
    <div class="max-w-4xl mx-auto px-4 py-6">

      <!-- Header -->
      <div class="flex items-center justify-between mb-4">
        <h1 class="text-xl font-bold text-red-400">
          Siège — Semaine {{ siege?.siege_week }} — Tour {{ siege?.turn }}
        </h1>
        <span v-if="siege?.status === 'active'" class="text-xs text-red-500 animate-pulse">
          SIEGE EN COURS
        </span>
      </div>

      <!-- Attack direction banner -->
      <div v-if="siege?.attack_direction" class="bg-red-900/20 border border-red-700/40 rounded-xl p-4 mb-4">
        <div class="flex items-center justify-between">
          <div>
            <p class="text-red-400 font-semibold">Les monstres attaquent par le {{ directionLabel(siege.attack_direction) }} !</p>
            <p v-if="siege.barrier_dr_bonus > 0" class="text-blue-400 text-sm mt-1">
              Bonus de défense des pièges : +{{ siege.barrier_dr_bonus }} DR
            </p>
          </div>
        </div>
      </div>

      <!-- Combat terminé -->
      <div v-if="isFinished" class="bg-stone-900 border rounded-xl p-8 text-center mb-6"
           :class="siege.status === 'victory' ? 'border-green-700' : 'border-red-700'">
        <div class="text-5xl mb-4">
          {{ siege.status === 'victory' ? '🛡️' : '💀' }}
        </div>
        <h2 class="text-2xl font-bold mb-2"
            :class="siege.status === 'victory' ? 'text-green-400' : 'text-red-400'">
          {{ siege.status === 'victory' ? 'Siège repoussé !' : 'Les défenses ont cédé...' }}
        </h2>
        <div v-if="siege.rewards" class="text-amber-400 text-lg mb-2">
          +{{ siege.rewards.xp }} XP, +{{ siege.rewards.gold }} Or
        </div>
        <p v-if="siege.status === 'defeat'" class="text-red-400/70 text-sm mb-4">
          Des bâtiments de la ville ont été endommagés.
        </p>
        <button @click="returnToTown"
          class="bg-stone-700 hover:bg-stone-600 text-white px-6 py-2 rounded-lg transition">
          Retour en ville
        </button>
      </div>

      <!-- Combat actif -->
      <template v-else-if="siege?.status === 'active'">
        <!-- Player & Enemies -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
          <!-- Player -->
          <div class="bg-stone-900 border border-stone-700 rounded-xl p-4">
            <h3 class="text-sm font-semibold text-amber-400 mb-3 uppercase tracking-wider">Défenseur</h3>
            <div class="mb-2">
              <div class="flex justify-between text-sm mb-1">
                <span class="text-red-400">PV</span>
                <span>{{ siege.player.hp }}/{{ siege.player.max_hp }}</span>
              </div>
              <div class="w-full bg-stone-800 rounded-full h-3">
                <div class="bg-red-600 h-3 rounded-full transition-all duration-500"
                     :style="{ width: hpPercent + '%' }"></div>
              </div>
            </div>
            <div class="mb-2">
              <div class="flex justify-between text-sm mb-1">
                <span class="text-blue-400">Mana</span>
                <span>{{ siege.player.mana }}/{{ siege.player.max_mana }}</span>
              </div>
              <div class="w-full bg-stone-800 rounded-full h-3">
                <div class="bg-blue-600 h-3 rounded-full transition-all duration-500"
                     :style="{ width: manaPercent + '%' }"></div>
              </div>
            </div>
            <div v-if="siege.player.statuses?.length" class="flex flex-wrap gap-1 mt-2">
              <span v-for="s in siege.player.statuses" :key="s.name"
                class="text-xs px-2 py-0.5 rounded-full"
                :class="isPositiveStatus(s.name) ? 'bg-green-900 text-green-300' : 'bg-red-900 text-red-300'">
                {{ s.name }} ({{ s.remaining }})
              </span>
            </div>
          </div>

          <!-- Enemies -->
          <div class="bg-stone-900 border border-stone-700 rounded-xl p-4">
            <h3 class="text-sm font-semibold text-red-400 mb-3 uppercase tracking-wider">Assaillants</h3>
            <div v-for="(enemy, i) in siege.enemies" :key="i" class="mb-3 last:mb-0">
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
            </div>
          </div>
        </div>

        <!-- Actions -->
        <div class="bg-stone-900 border border-stone-700 rounded-xl p-4 mb-4">
          <h3 class="text-sm font-semibold text-amber-400 mb-3 uppercase tracking-wider">Actions</h3>

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

          <div v-if="activeTab === 'attack'" class="space-y-2">
            <button @click="doAction('attack')" :disabled="acting"
              class="w-full bg-red-800 hover:bg-red-700 text-white py-3 rounded-lg font-semibold transition disabled:opacity-50">
              {{ acting ? '...' : 'Attaque' }}
            </button>
          </div>

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

          <div v-if="activeTab === 'magic'" class="space-y-2">
            <div v-if="!learnedMagics.length" class="text-stone-500 text-sm text-center py-4">
              Aucune magie apprise.
            </div>
            <button v-for="mag in learnedMagics" :key="mag.key"
              @click="doAction('magic', { key: mag.key })" :disabled="acting || siege.player.mana < (mag.mana_cost || 0)"
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

          <!-- No flee during siege -->
          <div class="mt-3 pt-3 border-t border-stone-800">
            <span class="text-stone-600 text-sm italic">
              Impossible de fuir pendant un siège
            </span>
          </div>
        </div>

        <!-- Combat log -->
        <div class="bg-stone-900 border border-stone-700 rounded-xl p-4">
          <h3 class="text-sm font-semibold text-stone-400 mb-3 uppercase tracking-wider">Journal de siège</h3>
          <div ref="logContainer" class="max-h-64 overflow-y-auto space-y-1 text-sm font-mono">
            <div v-for="(line, i) in displayLog" :key="i"
              class="py-0.5 px-2 rounded"
              :class="logLineClass(line)">
              {{ line }}
            </div>
          </div>
        </div>
      </template>

      <!-- Siege pending - pre-combat -->
      <div v-else-if="siegePending" class="text-center py-12">
        <div class="bg-red-900/20 border border-red-700 rounded-xl p-8 max-w-lg mx-auto">
          <div class="text-5xl mb-4">⚔️</div>
          <h2 class="text-2xl font-bold text-red-400 mb-3">Siège imminent !</h2>
          <p class="text-stone-400 mb-6">Les monstres approchent de la ville. Préparez-vous au combat !</p>
          <button @click="startSiege" :disabled="starting"
            class="bg-red-700 hover:bg-red-600 text-white px-8 py-3 rounded-lg font-semibold transition disabled:opacity-50">
            {{ starting ? 'Préparation...' : 'Défendre la ville !' }}
          </button>
        </div>
      </div>

      <!-- Loading -->
      <div v-else class="text-center py-20">
        <div class="text-stone-500">Chargement...</div>
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

const siege = computed(() => gameStore.siegeState)
const acting = ref(false)
const starting = ref(false)
const activeTab = ref('attack')
const logContainer = ref(null)
const learnedTechniques = ref([])
const learnedMagics = ref([])
const usableItems = ref([])

const siegePending = computed(() => {
  return gameStore.character?.siege_pending || (gameStore.siegeStatus?.siege_pending)
})

const isFinished = computed(() =>
  siege.value && ['victory', 'defeat'].includes(siege.value.status)
)

const hpPercent = computed(() => {
  if (!siege.value?.player) return 0
  return (siege.value.player.hp / siege.value.player.max_hp * 100)
})

const manaPercent = computed(() => {
  if (!siege.value?.player) return 0
  return (siege.value.player.mana / siege.value.player.max_mana * 100)
})

const displayLog = computed(() => {
  if (!siege.value) return []
  if (siege.value.recent_log?.length) return siege.value.recent_log
  return siege.value.log || []
})

const actionTabs = [
  { id: 'attack', label: 'Attaque' },
  { id: 'techniques', label: 'Techniques' },
  { id: 'magic', label: 'Magie' },
  { id: 'items', label: 'Objets' },
]

const positiveStatuses = ['Régénération', 'Protégé', 'Béni', 'Invisible', 'Concentré', 'Accéléré', 'Inspiré']

function isPositiveStatus(name) {
  return positiveStatuses.includes(name)
}

function directionLabel(dir) {
  const labels = { nord: 'Nord', sud: 'Sud', est: 'Est', ouest: 'Ouest' }
  return labels[dir] || dir
}

async function startSiege() {
  starting.value = true
  try {
    await gameStore.startSiege()
    await loadCombatResources()
  } finally {
    starting.value = false
  }
}

async function doAction(type, params = {}) {
  acting.value = true
  try {
    await gameStore.siegeAction(type, params)
    scrollLog()
  } finally {
    acting.value = false
  }
}

function returnToTown() {
  gameStore.siegeState = null
  router.push('/town')
}

function scrollLog() {
  nextTick(() => {
    if (logContainer.value) {
      logContainer.value.scrollTop = logContainer.value.scrollHeight
    }
  })
}

function logLineClass(line) {
  if (line.includes('Victoire') || line.includes('repoussé') || line.includes('vaincu')) return 'bg-green-900/30 text-green-300'
  if (line.includes('Défaite') || line.includes('tombé') || line.includes('cédé')) return 'bg-red-900/30 text-red-300'
  if (line.includes('raté')) return 'text-stone-500'
  if (line.includes('dégâts') && line.includes('vous')) return 'text-red-300'
  if (line.includes('dégâts')) return 'text-amber-300'
  if (line.includes('défenses') || line.includes('piège') || line.includes('Piège')) return 'text-blue-300'
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
  } catch (e) { /* optional */ }
}

watch(displayLog, () => scrollLog())

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()

  // Check if siege combat is already active
  try {
    await gameStore.fetchSiegeCombat()
    if (siege.value) {
      await loadCombatResources()
      return
    }
  } catch (e) { /* no active siege combat */ }

  // Check if siege is pending
  await gameStore.fetchSiegeStatus()
})
</script>
