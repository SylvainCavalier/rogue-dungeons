<template>
  <div class="mt-3">
    <div class="flex items-center justify-between mb-1">
      <span class="text-xs text-stone-500 uppercase tracking-wide">Défense</span>
      <span class="text-[10px] text-stone-600">{{ hint }}</span>
    </div>
    <div class="grid grid-cols-2 gap-1 bg-stone-800 rounded-lg p-1">
      <button v-for="opt in options" :key="opt.mode" type="button"
        :disabled="saving || disabled"
        :title="opt.title"
        class="text-xs py-1.5 rounded-md transition disabled:opacity-60"
        :class="current === opt.mode ? 'bg-amber-700 text-white font-semibold' : 'text-stone-400 hover:text-stone-200'"
        @click="select(opt.mode)">
        {{ opt.label }} <span class="opacity-75">{{ defense?.[opt.mode] }}</span>
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import apiClient from '../../plugins/axios'

const props = defineProps({
  defense: { type: Object, default: null },
  disabled: { type: Boolean, default: false }
})
const emit = defineEmits(['update'])

const options = [
  { mode: 'esquive', label: 'Esquive', title: 'Jet plus difficile, mais évite tous les dégâts' },
  { mode: 'parade', label: 'Parade', title: 'Jet plus facile, mais 1 dégât subi même en cas de réussite' }
]

const current = ref(props.defense?.mode || 'esquive')
const saving = ref(false)

watch(() => props.defense?.mode, (mode) => { if (mode) current.value = mode })

const hint = computed(() => current.value === 'parade'
  ? 'Plus facile, 1 dégât subi'
  : 'Plus difficile, aucun dégât')

async function select(mode) {
  if (mode === current.value || saving.value) return
  const previous = current.value
  current.value = mode
  saving.value = true
  try {
    const { data } = await apiClient.patch('/character/defense_mode', { mode })
    emit('update', data.defense)
  } catch (e) {
    current.value = previous
  } finally {
    saving.value = false
  }
}
</script>
