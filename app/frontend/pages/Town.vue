<template>
  <div class="min-h-screen bg-stone-950">
    <StatusBar />

    <div class="max-w-6xl mx-auto px-4 py-8">
      <div class="flex items-end justify-between mb-4 animate-fade-in-up">
        <h1 class="text-3xl font-bold text-amber-400">La Ville</h1>
        <p class="text-stone-500 text-sm">{{ gameStore.character?.date }}</p>
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

      <!-- Interactive town square -->
      <div class="animate-fade-in-up stagger-1">
        <TownMap :busy="gameStore.isBusy" :next-floor="nextFloor"
          :siege-subtitle="siegeSubtitle" :siege-imminent="siegeImminent"
          :has-building-damage="hasBuildingDamage" />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useGameStore } from '../stores/game'
import StatusBar from '../components/game/StatusBar.vue'
import TownMap from '../components/game/TownMap.vue'

const gameStore = useGameStore()
const router = useRouter()
const advancing = ref(false)

const nextFloor = computed(() => (gameStore.character?.current_floor || 0) + 1)

const siegeSubtitle = computed(() => {
  const days = gameStore.townStatus?.days_until_siege
  if (days !== undefined && days <= 1) return 'Siège imminent !'
  if (days !== undefined) return `Siège dans ${days} jours`
  return 'Défenses de la ville'
})

const siegeImminent = computed(() => {
  const days = gameStore.townStatus?.days_until_siege
  return days !== undefined && days <= 1
})

const hasBuildingDamage = computed(() => {
  const dmg = gameStore.character?.building_damage || gameStore.townStatus?.building_damage
  if (!dmg) return false
  return Object.values(dmg).some(v => v > 0)
})

const activityLabel = computed(() => {
  const a = gameStore.character?.activity
  if (a === 'academie') return `Apprentissage : ${gameStore.character.activity_data?.magic_name || 'Magie'}`
  if (a === 'guilde') return `Entraînement : ${gameStore.character.activity_data?.technique_name || 'Technique'}`
  return 'Activité en cours'
})

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()
  await gameStore.fetchTownStatus()

  // Redirect if siege is pending
  if (gameStore.character?.siege_pending || gameStore.townStatus?.siege_pending) {
    router.push('/siege')
  }
})

async function advanceActivity() {
  advancing.value = true
  try {
    const a = gameStore.character?.activity
    let result
    if (a === 'academie') result = await gameStore.advanceAcademy()
    else if (a === 'guilde') result = await gameStore.advanceGuild()
    if (result?.siege_pending) router.push('/siege')
  } finally {
    advancing.value = false
  }
}
</script>
