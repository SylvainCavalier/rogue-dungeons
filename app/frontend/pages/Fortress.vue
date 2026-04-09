<template>
  <div class="min-h-screen bg-stone-950 text-stone-200">
    <StatusBar />

    <div class="max-w-5xl mx-auto px-4 py-8">
      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold text-amber-400">Forteresse</h1>
          <p class="text-stone-500 text-sm mt-1">Placez des défenses pour protéger la ville</p>
        </div>
        <router-link to="/town" class="text-stone-500 hover:text-amber-400 transition text-sm">
          Retour en ville
        </router-link>
      </div>

      <!-- Info gold + workshop -->
      <div class="flex gap-4 mb-6">
        <div class="bg-stone-900 border border-stone-700 rounded-lg px-4 py-2 text-sm">
          <span class="text-yellow-400">{{ fortressData?.gold || 0 }}</span> or
        </div>
        <div class="bg-stone-900 border border-stone-700 rounded-lg px-4 py-2 text-sm">
          Atelier Nv. <span class="text-amber-400">{{ fortressData?.workshop_level || 0 }}</span>
          — Max <span class="text-amber-400">{{ fortressData?.max_traps_per_direction || 1 }}</span> pièges/direction
        </div>
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
              {{ (fortressData?.defenses?.[dir] || []).length }}/{{ fortressData?.max_traps_per_direction || 1 }}
            </span>
          </div>

          <!-- Placed traps -->
          <div class="space-y-2 mb-3">
            <div v-for="defense in (fortressData?.defenses?.[dir] || [])" :key="defense.id"
              class="flex items-center justify-between bg-stone-800 rounded-lg px-3 py-2">
              <div>
                <span class="text-sm font-medium">{{ defense.trap?.name || defense.trap_key }}</span>
                <span class="text-xs text-stone-500 ml-2">{{ trapTypeLabel(defense.trap?.type) }}</span>
              </div>
              <button @click="removeTrap(defense.id)"
                class="text-red-500 hover:text-red-400 text-xs transition">
                Retirer
              </button>
            </div>
            <div v-if="!(fortressData?.defenses?.[dir] || []).length"
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
                  <div class="font-semibold text-sm">{{ trap.name }}</div>
                  <div class="text-xs text-stone-500 mt-1">{{ trap.description }}</div>
                  <div class="text-xs mt-1" :class="trapTypeColor(trap.type)">
                    {{ trapEffectLabel(trap) }}
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

const directions = ['nord', 'sud', 'est', 'ouest']

const fortressData = computed(() => gameStore.fortressData)

const availableTraps = computed(() => {
  if (!fortressData.value?.available_traps) return []
  return Object.entries(fortressData.value.available_traps)
})

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

function trapEffectLabel(trap) {
  switch (trap.type) {
    case 'damage': return `${trap.damage} dégâts à chaque ennemi`
    case 'barrier': return `+${trap.dr_bonus} résistance aux dégâts`
    case 'slow': return `-${trap.esquive_penalty} esquive ennemie`
    case 'weaken': return `-${trap.attack_penalty || 0} attaque, -${trap.damage_penalty || 0} dégâts`
    default: return ''
  }
}

function canAddTrap(dir) {
  const current = (fortressData.value?.defenses?.[dir] || []).length
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

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()
  await gameStore.fetchFortress()
})
</script>
