<template>
  <div class="w-full">
    <div class="flex justify-between text-xs mb-1">
      <span :class="labelClass">{{ label }}</span>
      <span :class="labelClass">{{ current }}/{{ max }}</span>
    </div>
    <div class="w-full h-2.5 bg-stone-700 rounded-full overflow-hidden">
      <div class="h-full transition-all duration-500 rounded-full" :class="barClass" :style="{ width: percent + '%' }"></div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  current: { type: Number, required: true },
  max: { type: Number, required: true },
  label: { type: String, default: 'PV' },
  color: { type: String, default: 'red' },
})

const percent = computed(() => props.max > 0 ? (props.current / props.max) * 100 : 0)
const barClass = computed(() => ({
  'bg-red-600': props.color === 'red',
  'bg-blue-600': props.color === 'blue',
  'bg-green-600': props.color === 'green',
  'bg-amber-600': props.color === 'amber',
}))
const labelClass = computed(() => ({
  'text-red-400': props.color === 'red',
  'text-blue-400': props.color === 'blue',
  'text-green-400': props.color === 'green',
  'text-amber-400': props.color === 'amber',
}))
</script>
