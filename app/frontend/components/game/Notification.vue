<template>
  <transition name="slide">
    <div v-if="gameStore.notification" :class="notifClass" class="fixed top-4 right-4 z-50 px-5 py-3 rounded-lg shadow-lg text-sm font-medium max-w-sm">
      {{ gameStore.notification.message }}
    </div>
  </transition>
</template>

<script setup>
import { computed } from 'vue'
import { useGameStore } from '../../stores/game'
const gameStore = useGameStore()

const notifClass = computed(() => {
  const t = gameStore.notification?.type || 'info'
  return {
    'bg-green-800 text-green-100 border border-green-600': t === 'success',
    'bg-red-800 text-red-100 border border-red-600': t === 'error',
    'bg-amber-800 text-amber-100 border border-amber-600': t === 'info',
  }
})
</script>

<style scoped>
.slide-enter-active, .slide-leave-active { transition: all 0.3s ease; }
.slide-enter-from, .slide-leave-to { opacity: 0; transform: translateX(30px); }
</style>
