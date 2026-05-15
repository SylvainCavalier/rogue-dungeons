<template>
  <div class="min-h-screen bg-stone-950">
    <StatusBar />
    <div class="max-w-3xl mx-auto px-4 py-8">
      <!-- Header with image -->
      <div class="relative rounded-2xl overflow-hidden mb-6 animate-fade-in-up">
        <img :src="'/images/guilde-guerriers.webp'" alt="Guilde des guerriers" loading="lazy"
          class="w-full h-64 md:h-72 object-cover opacity-60" />
        <div class="absolute inset-0 bg-gradient-to-t from-stone-950 via-stone-950/40 to-transparent"></div>
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
            class="bg-stone-800 rounded-lg px-4 py-3 hover:bg-stone-750 transition">
            <div class="flex items-center justify-between gap-3">
              <div class="flex items-center gap-3 min-w-0">
                <div class="w-7 h-7 rounded-lg bg-red-900/40 text-red-400 flex items-center justify-center flex-shrink-0">
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3.75l4.5 4.5m0 0l-4.5 9 9-4.5m-4.5-4.5l9 9M14.25 3.75L21 10.5l-2.25 2.25L12 6l2.25-2.25z" />
                  </svg>
                </div>
                <span class="text-stone-200 text-sm font-medium truncate">{{ tech.name }}</span>
                <span v-if="tech.rank" class="text-stone-600 text-xs flex-shrink-0">Rang {{ tech.rank }}</span>
              </div>
              <div class="flex-shrink-0">
                <span v-if="tech.learned" class="text-green-400 text-xs font-semibold px-2 py-1 bg-green-900/30 rounded-full">Appris</span>
                <button v-else @click="openConfirm(tech)" :disabled="gameStore.isBusy"
                  class="text-xs bg-red-800 hover:bg-red-700 text-red-200 px-3 py-1.5 rounded-lg transition disabled:opacity-30 active:scale-95">
                  Apprendre
                </button>
              </div>
            </div>
            <p v-if="tech.description" class="text-stone-500 text-xs mt-2 leading-snug pl-10">
              {{ tech.description }}
            </p>
          </div>
        </div>
      </div>
    </div>

    <!-- Confirmation modal -->
    <div v-if="selectedTech"
      class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4"
      @click.self="selectedTech = null">
      <div class="bg-stone-900 border border-stone-700 rounded-xl p-6 max-w-md w-full animate-fade-in-up">
        <h2 class="text-xl font-bold text-red-400 mb-2">{{ selectedTech.name }}</h2>
        <p v-if="selectedTech.description" class="text-stone-300 text-sm leading-relaxed mb-4">
          {{ selectedTech.description }}
        </p>
        <div class="bg-stone-800 rounded-lg p-3 mb-5">
          <p class="text-stone-400 text-xs uppercase tracking-wide mb-1">Durée d'apprentissage</p>
          <p class="text-amber-400 font-bold text-lg">{{ selectedTech.days_needed }} jour(s)</p>
          <p class="text-stone-500 text-xs mt-1">
            Un jour passera à chaque étape d'entraînement.
          </p>
        </div>
        <div class="flex gap-3 justify-end">
          <button @click="selectedTech = null"
            class="btn-ghost px-4 py-2 rounded-lg text-sm">Annuler</button>
          <button @click="confirmLearn" :disabled="learning"
            class="bg-red-700 hover:bg-red-600 text-white font-medium px-4 py-2 rounded-lg transition disabled:opacity-40 active:scale-95">
            {{ learning ? 'En cours...' : 'Commencer l\'apprentissage' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useGameStore } from '../stores/game'
import StatusBar from '../components/game/StatusBar.vue'

const gameStore = useGameStore()
const selectedTech = ref(null)
const learning = ref(false)

function categoryLabel(cat) {
  const labels = {
    offensive: 'Attaques offensives',
    defensive: 'Techniques défensives',
    effect: 'Techniques à effet',
    advanced: 'Techniques avancées',
  }
  return labels[cat] || cat
}

function openConfirm(tech) {
  selectedTech.value = tech
}

async function confirmLearn() {
  if (!selectedTech.value) return
  learning.value = true
  try {
    await gameStore.startGuild(selectedTech.value.key)
    selectedTech.value = null
  } finally {
    learning.value = false
  }
}

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()
  await gameStore.fetchAvailableTechniques()
})
</script>
