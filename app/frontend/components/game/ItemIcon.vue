<template>
  <div class="inline-flex items-center justify-center rounded-lg flex-shrink-0"
    :class="[sizeClass, bgClass]">
    <svg :class="svgClass" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
      <path v-if="icon === 'sword'" stroke-linecap="round" stroke-linejoin="round"
        d="M3.75 3.75l4.5 4.5m0 0l-4.5 9 9-4.5m-4.5-4.5l9 9M14.25 3.75L21 10.5l-2.25 2.25L12 6l2.25-2.25z" />
      <path v-else-if="icon === 'bow'" stroke-linecap="round" stroke-linejoin="round"
        d="M4.5 19.5l15-15m0 0H8.25m11.25 0v11.25" />
      <path v-else-if="icon === 'shield'" stroke-linecap="round" stroke-linejoin="round"
        d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
      <path v-else-if="icon === 'armor'" stroke-linecap="round" stroke-linejoin="round"
        d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z" />
      <path v-else-if="icon === 'helmet'" stroke-linecap="round" stroke-linejoin="round"
        d="M12 3c-4.97 0-9 3.582-9 8 0 1.5.75 3 .75 3h16.5s.75-1.5.75-3c0-4.418-4.03-8-9-8zM6 14v3.75A2.25 2.25 0 008.25 20h7.5A2.25 2.25 0 0018 17.75V14" />
      <path v-else-if="icon === 'boots'" stroke-linecap="round" stroke-linejoin="round"
        d="M8.25 3v4.875c0 .621-.504 1.125-1.125 1.125H5.25m0 0v8.25c0 .414.336.75.75.75h3l1.5-1.5H15l3 1.5h.75a.75.75 0 00.75-.75V9H16.5a1.125 1.125 0 01-1.125-1.125V3" />
      <path v-else-if="icon === 'potion'" stroke-linecap="round" stroke-linejoin="round"
        d="M9.75 3.104v5.714a2.25 2.25 0 01-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 014.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M5 14.5a2.25 2.25 0 00-.75 1.685v1.065c0 1.242 1.008 2.25 2.25 2.25h11c1.242 0 2.25-1.008 2.25-2.25v-1.065A2.25 2.25 0 0019 14.75" />
      <path v-else-if="icon === 'scroll'" stroke-linecap="round" stroke-linejoin="round"
        d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
      <path v-else-if="icon === 'gold'" stroke-linecap="round" stroke-linejoin="round"
        d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      <!-- Default: generic item -->
      <path v-else stroke-linecap="round" stroke-linejoin="round"
        d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5m8.25 3v6.75m0 0l-3-3m3 3l3-3M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" />
    </svg>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  type: { type: String, default: 'item' },
  category: { type: String, default: '' },
  size: { type: String, default: 'md' },
})

const icon = computed(() => {
  if (props.category === 'arme_de_melee') return 'sword'
  if (props.category === 'arme_a_distance') return 'bow'
  if (props.category === 'bouclier') return 'shield'
  if (props.category === 'armure') return 'armor'
  if (props.category === 'casque') return 'helmet'
  if (props.category === 'bottes') return 'boots'
  if (props.type === 'item') return 'potion'
  return 'item'
})

const sizeClass = computed(() => ({
  sm: 'w-7 h-7 p-1',
  md: 'w-9 h-9 p-1.5',
  lg: 'w-11 h-11 p-2',
}[props.size] || 'w-9 h-9 p-1.5'))

const svgClass = computed(() => ({
  sm: 'w-4 h-4',
  md: 'w-5 h-5',
  lg: 'w-6 h-6',
}[props.size] || 'w-5 h-5'))

const bgClass = computed(() => {
  const colors = {
    sword: 'bg-red-900/40 text-red-400',
    bow: 'bg-green-900/40 text-green-400',
    shield: 'bg-blue-900/40 text-blue-400',
    armor: 'bg-stone-800 text-stone-400',
    helmet: 'bg-stone-800 text-stone-400',
    boots: 'bg-amber-900/40 text-amber-400',
    potion: 'bg-emerald-900/40 text-emerald-400',
    scroll: 'bg-violet-900/40 text-violet-400',
    gold: 'bg-yellow-900/40 text-yellow-400',
  }
  return colors[icon.value] || 'bg-stone-800 text-stone-400'
})
</script>
