<template>
  <div class="min-h-screen bg-stone-950">
    <StatusBar />
    <div class="max-w-3xl mx-auto px-4 py-8">
      <!-- Header with image -->
      <div class="relative rounded-2xl overflow-hidden mb-6 animate-fade-in-up">
        <img :src="'/images/guilde-guerriers.webp'" alt="Guilde des guerriers" loading="lazy"
          class="w-full h-36 object-cover opacity-40" />
        <div class="absolute inset-0 bg-gradient-to-t from-stone-950 via-stone-950/60 to-transparent"></div>
        <div class="absolute bottom-4 left-6 right-6 flex items-end justify-between">
          <h1 class="text-2xl font-bold text-red-400 drop-shadow-lg">Guilde des guerriers</h1>
          <router-link to="/town" class="text-stone-400 hover:text-amber-400 text-sm">Retour</router-link>
        </div>
      </div>

      <p class="text-stone-500 text-sm mb-6 animate-fade-in-up stagger-1">
        Choisissez une technique à apprendre. La durée dépend du rang de la technique et de votre vigueur.
      </p>

      <div v-for="(techniques, category) in gameStore.availableTechniques" :key="category"
        class="mb-6 card p-5 animate-fade-in-up stagger-2">
        <h2 class="text-lg font-semibold text-red-400 mb-3 flex items-center gap-2">
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
          </svg>
          {{ categoryLabel(category) }}
        </h2>
        <div class="space-y-2">
          <div v-for="tech in techniques" :key="tech.key"
            class="flex items-center justify-between bg-stone-800 rounded-lg px-4 py-2.5 hover:bg-stone-750 transition">
            <div class="flex items-center gap-3">
              <div class="w-7 h-7 rounded-lg bg-red-900/40 text-red-400 flex items-center justify-center">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3.75l4.5 4.5m0 0l-4.5 9 9-4.5m-4.5-4.5l9 9M14.25 3.75L21 10.5l-2.25 2.25L12 6l2.25-2.25z" />
                </svg>
              </div>
              <span class="text-stone-200 text-sm font-medium">{{ tech.name }}</span>
            </div>
            <div>
              <span v-if="tech.learned" class="text-green-400 text-xs font-semibold px-2 py-1 bg-green-900/30 rounded-full">Appris</span>
              <button v-else @click="learn(tech.key)" :disabled="gameStore.isBusy"
                class="text-xs bg-red-800 hover:bg-red-700 text-red-200 px-3 py-1.5 rounded-lg transition disabled:opacity-30 active:scale-95">
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

function categoryLabel(cat) {
  const labels = {
    offensive: 'Attaques offensives',
    defensive: 'Techniques défensives',
    effect: 'Techniques à effet',
    advanced: 'Techniques avancées',
  }
  return labels[cat] || cat
}

async function learn(key) {
  await gameStore.startGuild(key)
}

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()
  await gameStore.fetchAvailableTechniques()
})
</script>
