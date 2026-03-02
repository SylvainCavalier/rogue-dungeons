<template>
  <div class="min-h-screen bg-stone-950">
    <StatusBar />
    <div class="max-w-2xl mx-auto px-4 py-8">
      <!-- Header with image -->
      <div class="relative rounded-2xl overflow-hidden mb-6 animate-fade-in-up">
        <img :src="'/images/tour-ascension.webp'" alt="Tour d'ascension" loading="lazy"
          class="w-full h-44 object-cover opacity-50" />
        <div class="absolute inset-0 bg-gradient-to-t from-stone-950 via-stone-950/50 to-transparent"></div>
        <div class="absolute bottom-4 left-6 right-6 flex items-end justify-between">
          <h1 class="text-2xl font-bold text-red-400 drop-shadow-lg">Tour d'ascension</h1>
          <router-link to="/town" class="text-stone-400 hover:text-amber-400 text-sm">Retour</router-link>
        </div>
      </div>

      <div class="card p-6 text-center animate-fade-in-up stagger-1">
        <h2 class="text-xl text-stone-200 font-semibold mb-2">Prochain étage : {{ nextFloor }}</h2>

        <div v-if="towerInfo?.floor_preview"
          class="bg-stone-800 rounded-lg p-4 mb-4 text-sm text-left animate-fade-in-up stagger-2">
          <p class="text-stone-400 mb-2 font-semibold">
            <span v-if="towerInfo.floor_preview.boss"
              class="text-red-500 bg-red-900/30 px-2 py-0.5 rounded mr-2 text-xs uppercase font-bold">Boss</span>
            Ennemis :
          </p>
          <ul class="text-stone-300 space-y-1">
            <li v-for="(e, i) in towerInfo.floor_preview.enemies" :key="i" class="flex items-center gap-2">
              <span class="text-amber-400 font-mono">{{ e.count }}x</span>
              <span>{{ e.name }}</span>
            </li>
          </ul>
        </div>

        <div class="bg-stone-800 rounded-lg p-4 mb-6 text-sm text-stone-400 space-y-1">
          <div class="flex justify-between">
            <span>Étage max atteint</span>
            <span class="text-amber-400 font-bold">{{ gameStore.character?.current_floor || 0 }}</span>
          </div>
          <div class="flex justify-between">
            <span>PV actuels</span>
            <span class="text-red-400">{{ gameStore.character?.current_hp }}/{{ gameStore.character?.max_hp }}</span>
          </div>
          <div class="flex justify-between">
            <span>Mana actuelle</span>
            <span class="text-blue-400">{{ gameStore.character?.current_mana }}/{{ gameStore.character?.max_mana }}</span>
          </div>
        </div>

        <p v-if="nextFloor > 100" class="text-amber-400 text-lg font-bold mb-4 animate-glow">
          Vous avez conquis la Tour d'ascension !
        </p>

        <button v-else @click="enterFloor" :disabled="loading || !canEnter" class="btn-danger px-8 py-3 text-lg">
          {{ loading ? 'Entrée en cours...' : `Entrer dans l'étage ${nextFloor}` }}
        </button>

        <p v-if="!canEnter && nextFloor <= 100" class="text-red-500/70 text-xs mt-3">
          Vous êtes trop faible ou occupé pour entrer dans la tour.
        </p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useGameStore } from '../stores/game'
import StatusBar from '../components/game/StatusBar.vue'

const gameStore = useGameStore()
const router = useRouter()
const loading = ref(false)
const towerInfo = ref(null)

const nextFloor = computed(() => (gameStore.character?.current_floor || 0) + 1)
const canEnter = computed(() => {
  const c = gameStore.character
  if (!c) return false
  return c.current_hp > 0 && !c.activity
})

async function enterFloor() {
  loading.value = true
  try {
    await gameStore.enterTower()
    router.push('/combat')
  } catch (e) {
    // handled by store
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()

  if (gameStore.character?.in_combat) {
    router.push('/combat')
    return
  }

  try {
    const data = await gameStore.fetchTowerInfo()
    towerInfo.value = data
  } catch (e) { /* handled */ }
})
</script>
