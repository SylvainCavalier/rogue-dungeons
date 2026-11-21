<template>
  <div class="relative" :class="shaking ? 'frame-shake' : ''">
    <slot />
    <div v-if="flash" class="absolute inset-0 rounded-[inherit] pointer-events-none frame-flash"></div>
    <CombatFx :fx="state.fx" :floats="state.floats" />
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'
import CombatFx from './CombatFx.vue'

// Wraps the player card: plays combat effects over it and shakes on hits.
const props = defineProps({
  state: { type: Object, required: true }
})

const shaking = ref(false)
const flash = ref(false)
let timer = null

watch(() => props.state.shake, (v) => {
  if (!v) return
  shaking.value = false
  flash.value = false
  window.clearTimeout(timer)
  window.requestAnimationFrame(() => {
    shaking.value = true
    flash.value = true
    timer = window.setTimeout(() => { shaking.value = false; flash.value = false }, 450)
  })
})
</script>

<style scoped>
@keyframes frame-shake {
  0%, 100% { transform: translate(0, 0); }
  20% { transform: translate(-6px, 2px); }
  40% { transform: translate(5px, -2px); }
  60% { transform: translate(-3px, 1px); }
  80% { transform: translate(2px, 0); }
}
.frame-shake { animation: frame-shake 0.4s ease-out; }

@keyframes frame-flash {
  0% { box-shadow: inset 0 0 0 2px rgba(239, 68, 68, 0.9), inset 0 0 40px rgba(220, 38, 38, 0.55); }
  100% { box-shadow: inset 0 0 0 2px rgba(239, 68, 68, 0), inset 0 0 40px rgba(220, 38, 38, 0); }
}
.frame-flash { animation: frame-flash 0.45s ease-out forwards; }
</style>
