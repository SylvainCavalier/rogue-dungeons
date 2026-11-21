<template>
  <div class="relative w-full aspect-square rounded-xl overflow-hidden border border-stone-700 bg-stone-950 select-none">
    <img :src="'/images/fortress/town_map.webp'" alt="Plan de la ville fortifiée"
      class="absolute inset-0 w-full h-full object-cover" draggable="false" />
    <!-- Vignette -->
    <div class="absolute inset-0 pointer-events-none bg-[radial-gradient(circle_at_center,transparent_45%,rgba(12,10,9,0.85)_100%)]"></div>

    <template v-for="dir in directions" :key="dir">
      <!-- Road highlight / hit zone -->
      <button type="button" @click="$emit('select', dir)"
        class="absolute rounded-full transition duration-300 focus:outline-none"
        :class="selected === dir ? 'bg-amber-400/15 ring-1 ring-amber-400/40' : 'hover:bg-amber-200/10'"
        :style="roadStyle(dir)"
        :aria-label="`Défenses ${label(dir)}`"></button>

      <!-- Synergy aura -->
      <div v-if="synergies(dir).length"
        class="absolute rounded-full pointer-events-none animate-pulse bg-emerald-400/10 shadow-[0_0_30px_8px_rgba(52,211,153,0.25)]"
        :style="roadStyle(dir)"></div>

      <!-- Slots (trap tokens + empty slots) -->
      <div v-for="slot in slots(dir)" :key="`${dir}-${slot.index}`"
        class="absolute -translate-x-1/2 -translate-y-1/2"
        :style="{ left: slot.x + '%', top: slot.y + '%', width: TOKEN_SIZE + '%' }">
        <button v-if="slot.defense" type="button" @click="$emit('select', dir)"
          :title="tokenTitle(slot.defense)"
          class="group relative block w-full aspect-square rounded-full p-[8%] shadow-lg shadow-black/70 transition hover:scale-110"
          :style="{ background: ringGradient(slot.defense) }">
          <img :src="trapIcon(slot.defense.trap_key)" :alt="slot.defense.trap?.name"
            class="w-full h-full rounded-full object-cover bg-stone-900"
            :class="slot.defense.broken ? 'grayscale brightness-50' : ''" draggable="false" />
          <span v-if="slot.defense.broken"
            class="absolute inset-0 flex items-center justify-center text-red-500 font-black text-[clamp(10px,2.4vw,20px)] drop-shadow">✕</span>
          <span v-if="slot.defense.well_placed"
            class="absolute -top-[12%] -right-[12%] text-emerald-400 text-[clamp(9px,1.6vw,14px)] drop-shadow-[0_0_3px_black]">★</span>
        </button>
        <button v-else-if="slot.addable" type="button" @click="$emit('add', dir)"
          title="Ajouter un piège"
          class="block w-full aspect-square rounded-full border-2 border-dashed border-amber-400/70 bg-stone-950/60 text-amber-300 hover:bg-amber-900/50 hover:scale-110 transition text-[clamp(10px,2vw,18px)] leading-none">
          +
        </button>
        <div v-else class="w-full aspect-square rounded-full border border-dashed border-stone-500/50 bg-stone-950/30"></div>
      </div>

      <!-- Gate banner -->
      <button type="button" @click="$emit('select', dir)"
        class="absolute -translate-x-1/2 -translate-y-1/2 flex items-center gap-1.5 rounded-md border px-2 py-0.5 text-[clamp(9px,1.5vw,13px)] font-semibold backdrop-blur-sm transition whitespace-nowrap"
        :class="selected === dir
          ? 'bg-amber-900/80 border-amber-400 text-amber-200'
          : 'bg-stone-950/75 border-stone-600 text-stone-200 hover:border-amber-500'"
        :style="{ left: GATES[dir].labelX + '%', top: GATES[dir].labelY + '%' }">
        <span>{{ label(dir) }}</span>
        <span class="text-stone-400 font-normal">{{ defenses(dir).length }}/{{ maxTraps }}</span>
        <span v-if="!defenses(dir).length" class="text-red-400" title="Aucune défense">!</span>
        <span v-else-if="defenses(dir).some(d => d.broken)" class="text-red-400" title="Défense cassée">⚠</span>
        <span v-if="synergies(dir).length" class="text-emerald-300" :title="synergies(dir).map(s => s.name).join(', ')">✦{{ synergies(dir).length > 1 ? synergies(dir).length : '' }}</span>
      </button>
    </template>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  fortressData: { type: Object, default: null },
  selected: { type: String, default: null }
})
defineEmits(['select', 'add'])

const directions = ['nord', 'sud', 'est', 'ouest']
const TOKEN_SIZE = 8.5
const SLOT_STEP = 7.5

// Gate positions (in % of public/images/fortress/town_map.webp) and inward unit
// vector toward the central square. Slot 0 (front line) sits in the gate,
// following slots go deeper into town along the main street.
const GATES = {
  nord: { x: 50, y: 11, dx: 0, dy: 1, labelX: 50, labelY: 3 },
  sud: { x: 50, y: 86, dx: 0, dy: -1, labelX: 50, labelY: 96 },
  ouest: { x: 13, y: 50, dx: 1, dy: 0, labelX: 7, labelY: 43 },
  est: { x: 87, y: 50, dx: -1, dy: 0, labelX: 93, labelY: 43 }
}
const FRONT_OFFSET = 0

const maxTraps = computed(() => props.fortressData?.max_traps_per_direction || 1)

function defenses(dir) {
  return props.fortressData?.defenses?.[dir]?.defenses || []
}

function synergies(dir) {
  return props.fortressData?.defenses?.[dir]?.synergies || []
}

function label(dir) {
  return { nord: 'Nord', sud: 'Sud', est: 'Est', ouest: 'Ouest' }[dir] || dir
}

function slotPosition(dir, index) {
  const g = GATES[dir]
  const dist = FRONT_OFFSET + index * SLOT_STEP
  return { x: g.x + g.dx * dist, y: g.y + g.dy * dist }
}

function slots(dir) {
  const list = defenses(dir)
  return Array.from({ length: maxTraps.value }, (_, index) => ({
    index,
    ...slotPosition(dir, index),
    defense: list[index] || null,
    addable: index === list.length
  }))
}

function roadStyle(dir) {
  const g = GATES[dir]
  const span = (maxTraps.value - 1) * SLOT_STEP
  const length = span + TOKEN_SIZE + 5
  const thickness = TOKEN_SIZE + 5
  const centerDist = FRONT_OFFSET + span / 2
  const cx = g.x + g.dx * centerDist
  const cy = g.y + g.dy * centerDist
  const vertical = g.dx === 0
  const w = vertical ? thickness : length
  const h = vertical ? length : thickness
  return { left: `${cx - w / 2}%`, top: `${cy - h / 2}%`, width: `${w}%`, height: `${h}%` }
}

function trapIcon(key) {
  return `/images/traps/${key}.webp`
}

function durabilityPct(d) {
  if (!d.max_durability) return 0
  return Math.round((d.durability / d.max_durability) * 100)
}

function ringGradient(d) {
  const pct = durabilityPct(d)
  const color = pct === 0 ? '#7f1d1d' : pct < 35 ? '#ef4444' : pct < 70 ? '#f59e0b' : '#10b981'
  return `conic-gradient(${color} ${pct * 3.6}deg, #292524 0deg)`
}

function tokenTitle(d) {
  const parts = [d.trap?.name || d.trap_key, `Durabilité ${d.durability}/${d.max_durability}`]
  if (d.well_placed) parts.push('Bien placé ★')
  if (d.broken) parts.push('CASSÉ')
  return parts.join(' — ')
}
</script>
