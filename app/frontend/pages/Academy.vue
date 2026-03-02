<template>
  <div class="min-h-screen bg-stone-950">
    <StatusBar />
    <div class="max-w-3xl mx-auto px-4 py-8">
      <!-- Header with image -->
      <div class="relative rounded-2xl overflow-hidden mb-6 animate-fade-in-up">
        <img :src="'/images/academie-mages.webp'" alt="Académie des mages" loading="lazy"
          class="w-full h-36 object-cover opacity-40" />
        <div class="absolute inset-0 bg-gradient-to-t from-stone-950 via-stone-950/60 to-transparent"></div>
        <div class="absolute bottom-4 left-6 right-6 flex items-end justify-between">
          <h1 class="text-2xl font-bold text-blue-400 drop-shadow-lg">Académie des mages</h1>
          <router-link to="/town" class="text-stone-400 hover:text-amber-400 text-sm">Retour</router-link>
        </div>
      </div>

      <p class="text-stone-500 text-sm mb-6 animate-fade-in-up stagger-1">
        Choisissez un sort à apprendre. La durée dépend du tier du sort et de votre intelligence.
        Vous devez apprendre les sorts d'un élément dans l'ordre.
      </p>

      <div v-for="(magics, element) in gameStore.availableMagics" :key="element"
        class="mb-6 card p-5 animate-fade-in-up stagger-2">
        <h2 class="text-lg font-semibold mb-3 capitalize flex items-center gap-2" :class="elementColor(element)">
          <span class="w-2 h-2 rounded-full" :class="elementDot(element)"></span>
          {{ elementLabel(element) }}
        </h2>
        <div class="space-y-2">
          <div v-for="magic in magics" :key="magic.key"
            class="flex items-center justify-between bg-stone-800 rounded-lg px-4 py-2.5 hover:bg-stone-750 transition">
            <div class="flex items-center gap-3">
              <div class="w-7 h-7 rounded-lg flex items-center justify-center" :class="elementBg(element)">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" />
                </svg>
              </div>
              <div>
                <span class="text-stone-200 text-sm font-medium">{{ magic.name }}</span>
                <span class="text-stone-600 text-xs ml-2">Tier {{ magic.tier }}</span>
              </div>
            </div>
            <div>
              <span v-if="magic.learned" class="text-green-400 text-xs font-semibold px-2 py-1 bg-green-900/30 rounded-full">Appris</span>
              <button v-else @click="learn(magic.key)" :disabled="gameStore.isBusy"
                class="text-xs bg-blue-800 hover:bg-blue-700 text-blue-200 px-3 py-1.5 rounded-lg transition disabled:opacity-30 active:scale-95">
                Apprendre
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { onMounted } from 'vue'
import { useGameStore } from '../stores/game'
import StatusBar from '../components/game/StatusBar.vue'

const gameStore = useGameStore()

function elementLabel(el) {
  const labels = { feu: 'Feu', eau: 'Eau', ombre: 'Ombre', lumiere: 'Lumière', nature: 'Nature' }
  return labels[el] || el
}

function elementColor(el) {
  const colors = {
    feu: 'text-orange-400', eau: 'text-cyan-400', ombre: 'text-violet-400',
    lumiere: 'text-yellow-400', nature: 'text-emerald-400',
  }
  return colors[el] || 'text-stone-400'
}

function elementDot(el) {
  const colors = {
    feu: 'bg-orange-400', eau: 'bg-cyan-400', ombre: 'bg-violet-400',
    lumiere: 'bg-yellow-400', nature: 'bg-emerald-400',
  }
  return colors[el] || 'bg-stone-400'
}

function elementBg(el) {
  const colors = {
    feu: 'bg-orange-900/40 text-orange-400', eau: 'bg-cyan-900/40 text-cyan-400',
    ombre: 'bg-violet-900/40 text-violet-400', lumiere: 'bg-yellow-900/40 text-yellow-400',
    nature: 'bg-emerald-900/40 text-emerald-400',
  }
  return colors[el] || 'bg-stone-800 text-stone-400'
}

async function learn(key) {
  await gameStore.startAcademy(key)
}

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()
  await gameStore.fetchAvailableMagics()
})
</script>
