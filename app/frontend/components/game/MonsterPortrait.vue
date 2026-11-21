<template>
  <div class="relative shrink-0" :class="[sizeClass, motionClass]">
    <div class="relative w-full h-full overflow-hidden rounded-lg border bg-stone-950"
      :class="shownAlive ? 'border-stone-600' : 'border-stone-800'">
      <img :src="src" :alt="name" loading="lazy" @error="onError"
        class="w-full h-full object-cover transition duration-700"
        :class="[shownAlive ? '' : 'grayscale brightness-[0.35]', hitting ? 'portrait-flicker' : '']" />
      <!-- Inner vignette to blend with the dark UI -->
      <div class="absolute inset-0 pointer-events-none shadow-[inset_0_0_12px_rgba(0,0,0,0.9)]"></div>
      <!-- Hit flash -->
      <div v-if="hitting" class="absolute inset-0 bg-red-600/50 mix-blend-multiply animate-hit pointer-events-none"></div>
      <div v-if="!shownAlive" class="absolute inset-0 flex items-center justify-center text-red-900/80 text-2xl font-bold pointer-events-none portrait-death">
        ✕
      </div>
    </div>
    <CombatFx v-if="fxState" :fx="fxState.fx" :floats="fxState.floats" />
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue'
import CombatFx from './CombatFx.vue'

const props = defineProps({
  monsterKey: { type: String, default: '' },
  name: { type: String, default: '' },
  hp: { type: Number, default: 0 },
  alive: { type: Boolean, default: true },
  size: { type: String, default: 'md' },
  // Reactive target from useCombatFx (fx, floats, shake, lunge counters)
  fxState: { type: Object, default: null }
})

const FALLBACK = '/images/monsters/unknown.webp'
const failed = ref(false)
const hitting = ref(false)
const motion = ref(null)
const shownAlive = ref(props.alive)

const src = computed(() => {
  if (failed.value || !props.monsterKey) return FALLBACK
  return `/images/monsters/${props.monsterKey}.webp`
})

const sizeClass = computed(() => ({
  sm: 'w-12 h-12',
  md: 'w-16 h-16',
  lg: 'w-24 h-24'
}[props.size] || 'w-16 h-16'))

const motionClass = computed(() => motion.value ? `portrait-${motion.value}` : '')

function onError() {
  failed.value = true
}

watch(() => props.monsterKey, () => { failed.value = false })

let hitTimer = null
function flashHit() {
  window.clearTimeout(hitTimer)
  hitting.value = false
  window.requestAnimationFrame(() => {
    hitting.value = true
    hitTimer = window.setTimeout(() => { hitting.value = false }, 500)
  })
}

function move(kind) {
  motion.value = null
  window.requestAnimationFrame(() => window.requestAnimationFrame(() => { motion.value = kind }))
}

// Without an fx driver (tower preview, analyze list) keep the simple hp flash
watch(() => props.hp, (newHp, oldHp) => {
  if (!props.fxState && oldHp !== undefined && newHp < oldHp) flashHit()
})

watch(() => props.fxState?.shake, (v) => {
  if (!v) return
  move('shake')
  flashHit()
})

watch(() => props.fxState?.lunge, (v) => { if (v) move('lunge') })

// Let the killing blow land before greying the portrait out
watch(() => props.alive, (alive) => {
  if (alive || !props.fxState) {
    shownAlive.value = alive
    return
  }
  window.setTimeout(() => { shownAlive.value = false }, 550)
})
</script>

<style scoped>
@keyframes hit {
  0% { opacity: 1; }
  100% { opacity: 0; }
}
.animate-hit {
  animation: hit 0.5s ease-out forwards;
}

@keyframes portrait-shake {
  0%, 100% { transform: translate(0, 0) rotate(0); }
  15% { transform: translate(-5px, 1px) rotate(-3deg); }
  30% { transform: translate(5px, -1px) rotate(3deg); }
  45% { transform: translate(-4px, 0) rotate(-2deg); }
  60% { transform: translate(3px, 1px) rotate(1deg); }
  80% { transform: translate(-1px, 0) rotate(0); }
}
.portrait-shake { animation: portrait-shake 0.45s ease-out; }

@keyframes portrait-flicker {
  0%, 100% { filter: brightness(1); }
  10% { filter: brightness(2.6) saturate(0.3); }
  25% { filter: brightness(0.7); }
  40% { filter: brightness(2) saturate(0.5); }
  60% { filter: brightness(0.85); }
  75% { filter: brightness(1.5); }
}
.portrait-flicker { animation: portrait-flicker 0.5s steps(1, end); }

/* Enemy attacking: wind up then dash towards the player (left) */
@keyframes portrait-lunge {
  0%, 100% { transform: translateX(0) scale(1); }
  30% { transform: translateX(6px) scale(0.96); }
  55% { transform: translateX(-18px) scale(1.12); }
  75% { transform: translateX(-4px) scale(1.02); }
}
.portrait-lunge { animation: portrait-lunge 0.42s cubic-bezier(.4,0,.2,1); position: relative; z-index: 30; }

@keyframes portrait-death {
  0% { opacity: 0; transform: scale(2); }
  100% { opacity: 1; transform: scale(1); }
}
.portrait-death { animation: portrait-death 0.35s ease-out; }
</style>
