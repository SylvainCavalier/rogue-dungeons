<template>
  <div class="relative shrink-0 overflow-hidden rounded-lg border bg-stone-950"
    :class="[sizeClass, alive ? 'border-stone-600' : 'border-stone-800']">
    <img :src="src" :alt="name" loading="lazy" @error="onError"
      class="w-full h-full object-cover transition duration-700"
      :class="alive ? '' : 'grayscale brightness-[0.35]'" />
    <!-- Inner vignette to blend with the dark UI -->
    <div class="absolute inset-0 pointer-events-none shadow-[inset_0_0_12px_rgba(0,0,0,0.9)]"></div>
    <!-- Hit flash -->
    <div v-if="hit" class="absolute inset-0 bg-red-600/50 mix-blend-multiply animate-hit pointer-events-none"></div>
    <div v-if="!alive" class="absolute inset-0 flex items-center justify-center text-red-900/80 text-2xl font-bold pointer-events-none">
      ✕
    </div>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue'

const props = defineProps({
  monsterKey: { type: String, default: '' },
  name: { type: String, default: '' },
  hp: { type: Number, default: 0 },
  alive: { type: Boolean, default: true },
  size: { type: String, default: 'md' }
})

const FALLBACK = '/images/monsters/unknown.webp'
const failed = ref(false)
const hit = ref(false)

const src = computed(() => {
  if (failed.value || !props.monsterKey) return FALLBACK
  return `/images/monsters/${props.monsterKey}.webp`
})

const sizeClass = computed(() => ({
  sm: 'w-12 h-12',
  md: 'w-16 h-16',
  lg: 'w-24 h-24'
}[props.size] || 'w-16 h-16'))

function onError() {
  failed.value = true
}

watch(() => props.monsterKey, () => { failed.value = false })

let hitTimer = null
watch(() => props.hp, (newHp, oldHp) => {
  if (oldHp !== undefined && newHp < oldHp) {
    hit.value = false
    window.clearTimeout(hitTimer)
    window.requestAnimationFrame(() => {
      hit.value = true
      hitTimer = window.setTimeout(() => { hit.value = false }, 450)
    })
  }
})
</script>

<style scoped>
@keyframes hit {
  0% { opacity: 1; }
  100% { opacity: 0; }
}
.animate-hit {
  animation: hit 0.45s ease-out forwards;
}
</style>
