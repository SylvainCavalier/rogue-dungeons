<template>
  <div class="min-h-screen bg-stone-950 text-stone-200">
    <StatusBar />

    <div class="max-w-3xl mx-auto px-4 py-8">
      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold text-amber-400">Atelier</h1>
          <p class="text-stone-500 text-sm mt-1">Améliorez vos défenses</p>
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
              <h3 class="text-lg font-semibold text-amber-400">{{ data.level_data?.name || 'Pas d\'atelier' }}</h3>
              <p class="text-stone-500 text-sm mt-1">{{ data.level_data?.description }}</p>
              <p class="text-stone-400 text-sm mt-2">
                Pièges par direction : <span class="text-amber-400 font-bold">{{ data.level_data?.max_traps_per_direction || 1 }}</span>
              </p>
            </div>
            <div class="text-3xl font-bold text-amber-400">Nv. {{ data.level }}</div>
          </div>

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

        <!-- Traps catalog -->
        <div class="bg-stone-900 border border-stone-700 rounded-xl p-6">
          <h3 class="text-sm font-semibold text-stone-400 mb-4 uppercase tracking-wider">
            Catalogue des défenses
          </h3>
          <div class="space-y-3">
            <div v-for="trap in data.traps" :key="trap.key"
              class="bg-stone-800 rounded-lg p-3"
              :class="trap.unlocked ? '' : 'opacity-40'">
              <div class="flex justify-between items-start">
                <div>
                  <div class="flex items-center gap-2">
                    <span class="font-semibold text-sm">{{ trap.name }}</span>
                    <span v-if="trap.unlocked" class="text-xs text-green-400">Débloqué</span>
                    <span v-else class="text-xs text-stone-500">Atelier Nv. {{ trap.workshop_level }}</span>
                  </div>
                  <p class="text-xs text-stone-500 mt-1">{{ trap.description }}</p>
                  <p class="text-xs mt-1" :class="trapTypeColor(trap.type)">
                    {{ trapEffectLabel(trap) }}
                  </p>
                </div>
                <span class="text-yellow-400 text-sm whitespace-nowrap ml-3">{{ trap.cost }} or</span>
              </div>
            </div>
          </div>
        </div>

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

const data = computed(() => gameStore.workshopData)

function trapTypeColor(type) {
  const colors = { damage: 'text-red-400', barrier: 'text-blue-400', slow: 'text-purple-400', weaken: 'text-amber-400' }
  return colors[type] || 'text-stone-400'
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

async function upgrade() {
  upgrading.value = true
  try {
    await gameStore.upgradeWorkshop()
  } finally {
    upgrading.value = false
  }
}

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()
  await gameStore.fetchWorkshop()
})
</script>
