<template>
  <div class="min-h-screen bg-stone-950">
    <StatusBar />

    <div class="max-w-5xl mx-auto px-4 py-8">
      <!-- Header with town image -->
      <div class="relative rounded-2xl overflow-hidden mb-8 animate-fade-in-up">
        <img :src="'/images/ville.webp'" alt="La ville" loading="lazy"
          class="w-full h-48 md:h-56 object-cover opacity-60" />
        <div class="absolute inset-0 bg-gradient-to-t from-stone-950 via-stone-950/40 to-transparent"></div>
        <div class="absolute bottom-4 left-6">
          <h1 class="text-3xl font-bold text-amber-400 drop-shadow-lg">La Ville</h1>
          <p class="text-stone-400 text-sm mt-1">{{ gameStore.character?.date }}</p>
        </div>
      </div>

      <!-- Activité en cours -->
      <div v-if="gameStore.isBusy"
        class="bg-amber-900/20 border border-amber-700/40 rounded-xl p-5 mb-6 animate-fade-in-up animate-glow">
        <div class="flex items-center justify-between">
          <div>
            <p class="text-amber-300 font-semibold text-lg">{{ activityLabel }}</p>
            <p class="text-amber-400/60 text-sm mt-1">
              {{ gameStore.character.activity_days_left }} jour(s) restant(s)
            </p>
          </div>
          <button @click="advanceActivity" :disabled="advancing" class="btn-primary">
            {{ advancing ? 'En cours...' : 'Passer un jour' }}
          </button>
        </div>
      </div>

      <!-- Grille des lieux -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <TownCard to="/town/character" :delay="1"
          label="Fiche personnage" subtitle="Stats et compétences"
          icon-color="text-amber-400">
          <template #icon>
            <svg class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
            </svg>
          </template>
        </TownCard>

        <TownCard to="/town/inventory" :delay="2"
          label="Inventaire" subtitle="Équipement et objets"
          icon-color="text-amber-400">
          <template #icon>
            <svg class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" />
            </svg>
          </template>
        </TownCard>

        <TownCard to="/town/shop" :delay="3"
          label="Magasin" subtitle="Acheter et vendre"
          icon-color="text-yellow-400"
          image="/images/magasin.webp">
          <template #icon>
            <svg class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 21v-7.5a.75.75 0 01.75-.75h3a.75.75 0 01.75.75V21m-4.5 0H2.36m11.14 0H18m0 0h3.64m-1.39 0V9.349m-16.5 11.65V9.35m0 0a3.001 3.001 0 003.75-.615A2.993 2.993 0 009.75 9.75c.896 0 1.7-.393 2.25-1.016a2.993 2.993 0 002.25 1.016c.896 0 1.7-.393 2.25-1.016a3.001 3.001 0 003.75.614m-16.5 0a3.004 3.004 0 01-.621-4.72L4.318 3.44A1.5 1.5 0 015.378 3h13.243a1.5 1.5 0 011.06.44l1.19 1.189a3 3 0 01-.621 4.72m-13.5 8.65h3.75a.75.75 0 00.75-.75V13.5a.75.75 0 00-.75-.75H6.75a.75.75 0 00-.75.75v3.15c0 .415.336.75.75.75z" />
            </svg>
          </template>
        </TownCard>

        <TownCard :delay="4" @click="handleWork" :disabled="gameStore.isBusy"
          label="La Forge" subtitle="Travailler pour de l'or"
          icon-color="text-orange-400"
          image="/images/forge.webp">
          <template #icon>
            <svg class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15.362 5.214A8.252 8.252 0 0112 21 8.25 8.25 0 016.038 7.048 8.287 8.287 0 009 9.6a8.983 8.983 0 013.361-6.867 8.21 8.21 0 003 2.48z" />
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 18a3.75 3.75 0 00.495-7.467 5.99 5.99 0 00-1.925 3.546 5.974 5.974 0 01-2.133-1A3.75 3.75 0 0012 18z" />
            </svg>
          </template>
        </TownCard>

        <TownCard to="/town/academy" :delay="5" :disabled="gameStore.isBusy"
          label="Académie des mages" subtitle="Apprendre des magies"
          icon-color="text-blue-400"
          image="/images/academie-mages.webp">
          <template #icon>
            <svg class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 00-2.455 2.456z" />
            </svg>
          </template>
        </TownCard>

        <TownCard to="/town/guild" :delay="6" :disabled="gameStore.isBusy"
          label="Guilde des guerriers" subtitle="Apprendre des techniques"
          icon-color="text-red-400"
          image="/images/guilde-guerriers.webp">
          <template #icon>
            <svg class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9 5.25h.008v.008H12v-.008z" />
            </svg>
          </template>
        </TownCard>

        <TownCard :delay="7" @click="handleRest" :disabled="gameStore.isBusy"
          label="Se reposer" subtitle="Récupérer PV et mana"
          icon-color="text-green-400"
          image="/images/apothicaire.webp">
          <template #icon>
            <svg class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z" />
            </svg>
          </template>
        </TownCard>

        <TownCard to="/tower" :delay="8" :disabled="gameStore.isBusy"
          label="Tour d'ascension" :subtitle="`Étage ${nextFloor} / 100`"
          icon-color="text-red-400" variant="danger"
          image="/images/tour-ascension.webp">
          <template #icon>
            <svg class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5m-1.5 3h1.5m-1.5 3h1.5m3-6H15m-1.5 3H15m-1.5 3H15M9 21v-3.375c0-.621.504-1.125 1.125-1.125h3.75c.621 0 1.125.504 1.125 1.125V21" />
            </svg>
          </template>
        </TownCard>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useGameStore } from '../stores/game'
import StatusBar from '../components/game/StatusBar.vue'
import TownCard from '../components/game/TownCard.vue'

const gameStore = useGameStore()
const advancing = ref(false)

const nextFloor = computed(() => (gameStore.character?.current_floor || 0) + 1)

const activityLabel = computed(() => {
  const a = gameStore.character?.activity
  if (a === 'academie') return `Apprentissage : ${gameStore.character.activity_data?.magic_name || 'Magie'}`
  if (a === 'guilde') return `Entraînement : ${gameStore.character.activity_data?.technique_name || 'Technique'}`
  return 'Activité en cours'
})

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()
  gameStore.fetchTownStatus()
})

async function handleWork() {
  if (gameStore.isBusy) return
  await gameStore.work()
}

async function handleRest() {
  if (gameStore.isBusy) return
  await gameStore.rest()
}

async function advanceActivity() {
  advancing.value = true
  try {
    const a = gameStore.character?.activity
    if (a === 'academie') await gameStore.advanceAcademy()
    else if (a === 'guilde') await gameStore.advanceGuild()
  } finally {
    advancing.value = false
  }
}
</script>
