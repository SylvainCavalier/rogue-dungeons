<template>
  <div class="min-h-screen bg-stone-950 text-stone-200">
    <StatusBar />

    <div class="max-w-3xl mx-auto px-4 py-8">
      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold text-amber-400">État des bâtiments</h1>
          <p class="text-stone-500 text-sm mt-1">Réparez les bâtiments endommagés par les sièges</p>
        </div>
        <router-link to="/town" class="text-stone-500 hover:text-amber-400 transition text-sm">
          Retour en ville
        </router-link>
      </div>

      <div v-if="data" class="space-y-4">
        <div class="text-sm text-stone-500 mb-2">
          <span class="text-yellow-400">{{ data.gold }}</span> or disponible
        </div>

        <div v-for="building in data.buildings" :key="building.key"
          class="bg-stone-900 border rounded-xl p-5 transition"
          :class="borderClass(building.damage_level)">
          <div class="flex items-center justify-between">
            <div>
              <div class="flex items-center gap-3">
                <h3 class="font-semibold text-lg" :class="nameClass(building.damage_level)">
                  {{ building.name }}
                </h3>
                <span class="text-xs px-2 py-0.5 rounded-full"
                  :class="statusBadge(building.damage_level)">
                  {{ building.status }}
                </span>
              </div>
              <p v-if="building.damage_level === 1" class="text-amber-400/70 text-xs mt-1">
                {{ damageEffect(building.key) }}
              </p>
              <p v-if="building.damage_level >= 2" class="text-red-400/70 text-xs mt-1">
                Inaccessible tant que non réparé
              </p>
            </div>

            <button v-if="building.damage_level > 0"
              @click="repair(building.key)"
              :disabled="data.gold < building.repair_cost || repairing"
              class="bg-green-700 hover:bg-green-600 disabled:opacity-40 text-white px-4 py-2 rounded-lg text-sm transition whitespace-nowrap">
              {{ repairing ? '...' : `Réparer (${building.repair_cost} or)` }}
            </button>
          </div>
        </div>

        <div v-if="!data.any_damaged" class="text-center py-8 text-stone-500">
          Tous les bâtiments sont en bon état.
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
const repairing = ref(false)

const data = computed(() => gameStore.buildingsData)

function borderClass(level) {
  if (level >= 2) return 'border-red-700'
  if (level === 1) return 'border-amber-700'
  return 'border-stone-700'
}

function nameClass(level) {
  if (level >= 2) return 'text-red-400'
  if (level === 1) return 'text-amber-400'
  return 'text-stone-200'
}

function statusBadge(level) {
  if (level >= 2) return 'bg-red-900 text-red-300'
  if (level === 1) return 'bg-amber-900 text-amber-300'
  return 'bg-green-900 text-green-300'
}

function damageEffect(key) {
  const effects = {
    shop: 'Prix augmentés de 25%',
    academy: 'Apprentissage +2 jours',
    guild: 'Entraînement +2 jours',
    forge: 'Revenus réduits de 30%',
    watchtower: 'Renseignements dégradés',
    workshop: 'Certains pièges indisponibles'
  }
  return effects[key] || 'Performances réduites'
}

async function repair(buildingKey) {
  repairing.value = true
  try {
    await gameStore.repairBuilding(buildingKey)
  } finally {
    repairing.value = false
  }
}

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()
  await gameStore.fetchBuildings()
})
</script>
