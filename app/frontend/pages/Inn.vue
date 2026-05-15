<template>
  <div class="min-h-screen bg-stone-950">
    <StatusBar />
    <div class="max-w-3xl mx-auto px-4 py-8">
      <!-- Header with image -->
      <div class="relative rounded-2xl overflow-hidden mb-6 animate-fade-in-up">
        <img :src="'/images/apothicaire.webp'" alt="Auberge" loading="lazy"
          class="w-full h-64 md:h-72 object-cover opacity-60" />
        <div class="absolute inset-0 bg-gradient-to-t from-stone-950 via-stone-950/40 to-transparent"></div>
        <div class="absolute bottom-4 left-6 right-6 flex items-end justify-between">
          <h1 class="text-2xl font-bold text-green-400 drop-shadow-lg">Auberge</h1>
          <div class="flex items-center gap-4">
            <span class="text-yellow-400 font-bold text-lg">{{ gameStore.character?.gold || 0 }} or</span>
            <router-link to="/town" class="text-stone-400 hover:text-amber-400 text-sm">Retour</router-link>
          </div>
        </div>
      </div>

      <div class="card p-6 animate-fade-in-up stagger-1">
        <p class="text-stone-300 text-sm leading-relaxed mb-4">
          L'aubergiste vous accueille chaleureusement. Un lit moelleux et un bon repas
          vous rendront vos forces : récupération complète des PV et de la mana.
        </p>

        <div class="flex items-center justify-between bg-stone-800 rounded-lg px-4 py-3 mb-5">
          <div>
            <p class="text-stone-400 text-xs uppercase tracking-wide">Prix pour la nuit</p>
            <p class="text-yellow-400 font-bold text-lg">{{ INN_COST }} or</p>
          </div>
          <div class="text-right">
            <p class="text-stone-400 text-xs uppercase tracking-wide">PV / Mana</p>
            <p class="text-stone-200 text-sm">
              {{ gameStore.character?.current_hp }}/{{ gameStore.character?.max_hp }} ·
              {{ gameStore.character?.current_mana }}/{{ gameStore.character?.max_mana }}
            </p>
          </div>
        </div>

        <button @click="showModal = true"
          :disabled="!canSleep"
          class="w-full bg-green-700 hover:bg-green-600 text-white font-medium px-4 py-2.5 rounded-lg transition disabled:opacity-40 disabled:cursor-not-allowed active:scale-95">
          Passer la nuit
        </button>
        <p v-if="!canAfford" class="text-red-400 text-xs mt-2 text-center">
          Or insuffisant.
        </p>
      </div>
    </div>

    <!-- Confirmation modal -->
    <div v-if="showModal"
      class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4"
      @click.self="showModal = false">
      <div class="bg-stone-900 border border-stone-700 rounded-xl p-6 max-w-md w-full animate-fade-in-up">
        <h2 class="text-xl font-bold text-green-400 mb-4">Passer la nuit à l'auberge ?</h2>
        <div class="space-y-3 text-sm text-stone-300">
          <p>
            Vous allez dépenser <span class="text-yellow-400 font-semibold">{{ INN_COST }} or</span>
            pour dormir et récupérer tous vos PV et votre mana.
          </p>
          <p class="text-stone-500">
            Un jour passera.
          </p>
        </div>
        <div class="flex gap-3 mt-6 justify-end">
          <button @click="showModal = false"
            class="btn-ghost px-4 py-2 rounded-lg text-sm">Annuler</button>
          <button @click="confirmSleep" :disabled="sleeping"
            class="bg-green-700 hover:bg-green-600 text-white font-medium px-4 py-2 rounded-lg transition disabled:opacity-40 active:scale-95">
            {{ sleeping ? 'En cours...' : 'Confirmer' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useGameStore } from '../stores/game'
import StatusBar from '../components/game/StatusBar.vue'

const INN_COST = 10

const gameStore = useGameStore()
const router = useRouter()
const showModal = ref(false)
const sleeping = ref(false)

const canAfford = computed(() => (gameStore.character?.gold || 0) >= INN_COST)
const canSleep = computed(() => canAfford.value && !gameStore.isBusy)

async function confirmSleep() {
  sleeping.value = true
  try {
    const result = await gameStore.sleepAtInn()
    showModal.value = false
    if (result?.siege_pending) router.push('/siege')
  } finally {
    sleeping.value = false
  }
}

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()
})
</script>
