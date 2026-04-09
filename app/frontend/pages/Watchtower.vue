<template>
  <div class="min-h-screen bg-stone-950 text-stone-200">
    <StatusBar />

    <div class="max-w-3xl mx-auto px-4 py-8">
      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold text-amber-400">Vigie</h1>
          <p class="text-stone-500 text-sm mt-1">Surveillez les mouvements ennemis</p>
        </div>
        <router-link to="/town" class="text-stone-500 hover:text-amber-400 transition text-sm">
          Retour en ville
        </router-link>
      </div>

      <div v-if="data" class="space-y-6">
        <!-- Current level -->
        <div class="bg-stone-900 border border-stone-700 rounded-xl p-6">
          <div class="flex items-center justify-between mb-4">
            <div>
              <h3 class="text-lg font-semibold text-amber-400">{{ data.level_data?.name || 'Pas de vigie' }}</h3>
              <p class="text-stone-500 text-sm mt-1">{{ data.level_data?.description }}</p>
            </div>
            <div class="text-3xl font-bold text-amber-400">Nv. {{ data.level }}</div>
          </div>

          <!-- Upgrade -->
          <div v-if="data.upgrade_cost" class="mt-4 pt-4 border-t border-stone-700">
            <button @click="upgrade" :disabled="!data.can_upgrade || upgrading"
              class="bg-amber-700 hover:bg-amber-600 disabled:opacity-40 text-white px-6 py-2 rounded-lg transition text-sm">
              {{ upgrading ? '...' : `Améliorer (${data.upgrade_cost} or)` }}
            </button>
          </div>
          <div v-else class="mt-4 pt-4 border-t border-stone-700 text-green-400 text-sm">
            Niveau maximum atteint
          </div>
        </div>

        <!-- Intel -->
        <div class="bg-stone-900 border border-stone-700 rounded-xl p-6">
          <h3 class="text-sm font-semibold text-stone-400 mb-3 uppercase tracking-wider">
            Renseignements sur le prochain siège
          </h3>

          <div v-if="data.intel.certainty === 'none'" class="text-stone-500 text-center py-6">
            <div class="text-4xl mb-3">???</div>
            <p>{{ data.intel.message }}</p>
            <p class="text-xs mt-2">Améliorez la vigie pour obtenir des informations</p>
          </div>

          <div v-else class="space-y-3">
            <p class="text-stone-300">{{ data.intel.message }}</p>
            <div class="flex gap-2 flex-wrap">
              <span v-for="dir in data.intel.directions" :key="dir"
                class="px-3 py-1 rounded-lg text-sm font-medium"
                :class="intelDirectionClass(data.intel.certainty)">
                {{ directionLabel(dir) }}
              </span>
            </div>
            <p class="text-xs text-stone-600">
              Fiabilité :
              <span :class="certaintyCls">{{ certaintyLabel }}</span>
            </p>
          </div>
        </div>

        <!-- Gold -->
        <div class="text-center text-sm text-stone-500">
          <span class="text-yellow-400">{{ data.gold }}</span> or disponible
        </div>
      </div>

      <div v-else class="text-center py-20 text-stone-500">Chargement...</div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useGameStore } from '../stores/game'
import StatusBar from '../components/game/StatusBar.vue'

const gameStore = useGameStore()
const upgrading = ref(false)

const data = computed(() => gameStore.watchtowerData)

const certaintyLabel = computed(() => {
  const labels = { vague: 'Vague', partial: 'Partielle', precise: 'Précise' }
  return labels[data.value?.intel?.certainty] || 'Inconnue'
})

const certaintyCls = computed(() => {
  const cls = { vague: 'text-yellow-400', partial: 'text-amber-400', precise: 'text-green-400' }
  return cls[data.value?.intel?.certainty] || 'text-stone-400'
})

function directionLabel(dir) {
  const labels = { nord: 'Nord', sud: 'Sud', est: 'Est', ouest: 'Ouest' }
  return labels[dir] || dir
}

function intelDirectionClass(certainty) {
  if (certainty === 'precise') return 'bg-green-900/40 text-green-400 border border-green-700'
  if (certainty === 'partial') return 'bg-amber-900/40 text-amber-400 border border-amber-700'
  return 'bg-yellow-900/40 text-yellow-400 border border-yellow-700'
}

async function upgrade() {
  upgrading.value = true
  try {
    await gameStore.upgradeWatchtower()
  } finally {
    upgrading.value = false
  }
}

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()
  await gameStore.fetchWatchtower()
})
</script>
