<template>
  <div v-if="info" class="card p-5 mb-6 animate-fade-in-up stagger-1">
    <div class="flex items-start justify-between gap-4">
      <div>
        <p class="text-stone-500 text-xs uppercase tracking-wide">Votre rang</p>
        <p class="text-lg font-bold" :class="info.rank ? accentClass : 'text-stone-400'">{{ info.rank_name }}</p>
      </div>
      <div v-if="info.next_rank" class="text-right">
        <button @click="advance" :disabled="busy || !info.next_rank.ready"
          class="text-sm font-medium px-4 py-2 rounded-lg transition disabled:opacity-40 disabled:cursor-not-allowed active:scale-95"
          :class="buttonClass">
          {{ info.next_rank.join ? `S'inscrire (${info.next_rank.cost} or)` : `Passer l'épreuve : ${info.next_rank.name}` }}
        </button>
      </div>
      <p v-else class="text-emerald-400 text-sm font-medium">Rang le plus élevé atteint</p>
    </div>

    <div v-if="info.next_rank" class="mt-3">
      <p class="text-stone-400 text-xs mb-1">
        {{ info.next_rank.join ? 'Conditions d\'inscription (rang Apprenti)' : `Conditions pour devenir ${info.next_rank.name}` }}
      </p>
      <ul class="space-y-0.5">
        <li v-for="c in info.next_rank.conditions" :key="c.label" class="text-xs flex items-center gap-2"
          :class="c.met ? 'text-emerald-300' : 'text-stone-500'">
          <span class="w-3 text-center">{{ c.met ? '✓' : '·' }}</span>{{ c.label }}
        </li>
      </ul>
    </div>
    <p v-if="!info.rank" class="text-stone-500 text-xs mt-3">
      Seuls les membres peuvent apprendre ici.
    </p>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useGameStore } from '../../stores/game'

// Rank of the player in the warriors guild or the mages academy, with the
// join / promotion button and the checklist of the next rank's conditions.
const props = defineProps({
  guild: { type: String, required: true }, // 'warriors' | 'mages'
  info: { type: Object, default: null },
  accentClass: { type: String, default: 'text-amber-400' },
  buttonClass: { type: String, default: 'bg-amber-700 hover:bg-amber-600 text-white' }
})

const gameStore = useGameStore()
const busy = ref(false)

async function advance() {
  busy.value = true
  try {
    await gameStore.advanceGuildRank(props.guild)
  } catch {
    // error already notified by the store
  } finally {
    busy.value = false
  }
}
</script>
