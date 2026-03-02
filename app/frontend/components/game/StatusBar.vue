<template>
  <div v-if="gameStore.character" class="bg-stone-900 border-b border-amber-900/50 px-4 py-2 flex items-center gap-6 text-sm">
    <span class="font-bold text-amber-400">{{ gameStore.character.name }}</span>

    <div class="flex items-center gap-1">
      <span class="text-red-400">PV</span>
      <div class="w-24 h-3 bg-stone-700 rounded-full overflow-hidden">
        <div class="h-full bg-red-600 transition-all duration-500" :style="{ width: hpPercent + '%' }"></div>
      </div>
      <span class="text-red-300 text-xs">{{ gameStore.character.current_hp }}/{{ gameStore.character.max_hp }}</span>
    </div>

    <div class="flex items-center gap-1">
      <span class="text-blue-400">PM</span>
      <div class="w-24 h-3 bg-stone-700 rounded-full overflow-hidden">
        <div class="h-full bg-blue-600 transition-all duration-500" :style="{ width: manaPercent + '%' }"></div>
      </div>
      <span class="text-blue-300 text-xs">{{ gameStore.character.current_mana }}/{{ gameStore.character.max_mana }}</span>
    </div>

    <div class="flex items-center gap-4 ml-auto text-xs">
      <span class="text-yellow-400">{{ gameStore.character.gold }} or</span>
      <span class="text-purple-400">{{ gameStore.character.xp }} XP</span>
      <span class="text-stone-400">Étage {{ gameStore.character.current_floor }}</span>
      <span class="text-stone-500">{{ gameStore.character.date }}</span>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useGameStore } from '../../stores/game'
const gameStore = useGameStore()

const hpPercent = computed(() => {
  const c = gameStore.character
  return c ? (c.current_hp / c.max_hp) * 100 : 0
})
const manaPercent = computed(() => {
  const c = gameStore.character
  return c && c.max_mana > 0 ? (c.current_mana / c.max_mana) * 100 : 0
})
</script>
