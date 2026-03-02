<template>
  <div class="min-h-screen bg-stone-950 flex items-center justify-center px-4 py-8">
    <div class="bg-stone-900 border border-amber-900/50 rounded-xl p-8 w-full max-w-lg shadow-2xl">
      <h1 class="text-2xl font-bold text-amber-400 text-center mb-1">Création du personnage</h1>
      <p class="text-stone-500 text-center mb-6 text-sm">Répartissez vos {{ TOTAL_POINTS }} points de caractéristiques</p>

      <form @submit.prevent="create" class="space-y-5">
        <div>
          <label class="block text-sm text-stone-400 mb-1">Nom du personnage</label>
          <input v-model="name" type="text" required
            class="w-full bg-stone-800 border border-stone-700 rounded-lg px-4 py-2.5 text-stone-200 focus:border-amber-500 focus:outline-none" />
        </div>

        <div class="space-y-3">
          <div v-for="stat in stats" :key="stat.key" class="flex items-center gap-3">
            <span class="w-28 text-sm text-stone-300">{{ stat.label }}</span>
            <button type="button" @click="decrement(stat.key)"
              class="w-8 h-8 rounded bg-stone-700 hover:bg-stone-600 text-stone-300 font-bold transition disabled:opacity-30"
              :disabled="form[stat.key] <= 1">-</button>
            <span class="w-8 text-center font-bold text-lg text-amber-400">{{ form[stat.key] }}</span>
            <button type="button" @click="increment(stat.key)"
              class="w-8 h-8 rounded bg-stone-700 hover:bg-stone-600 text-stone-300 font-bold transition disabled:opacity-30"
              :disabled="remaining <= 0 || form[stat.key] >= 8">+</button>
            <span class="text-xs text-stone-500">{{ stat.desc }}</span>
          </div>
        </div>

        <div class="text-center text-sm" :class="remaining === 0 ? 'text-green-400' : 'text-amber-400'">
          Points restants : {{ remaining }}
        </div>

        <div class="bg-stone-800 rounded-lg p-4 text-sm text-stone-400 space-y-1">
          <div class="flex justify-between"><span>Points de vie</span><span class="text-red-400 font-bold">{{ form.vigueur * 3 }} PV</span></div>
          <div class="flex justify-between"><span>Points de mana</span><span class="text-blue-400 font-bold">{{ form.intelligence * 3 }} PM</span></div>
        </div>

        <p v-if="error" class="text-red-400 text-sm">{{ error }}</p>

        <button type="submit" :disabled="loading || remaining !== 0"
          class="w-full bg-amber-700 hover:bg-amber-600 text-white font-semibold py-2.5 rounded-lg transition disabled:opacity-50">
          {{ loading ? 'Création...' : 'Créer mon personnage' }}
        </button>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useGameStore } from '../stores/game'

const router = useRouter()
const gameStore = useGameStore()

const TOTAL_POINTS = 12
const name = ref('')
const error = ref('')
const loading = ref(false)

const form = reactive({ vigueur: 2, dexterite: 3, intelligence: 2, charisme: 3, perception: 2 })

const stats = [
  { key: 'vigueur', label: 'Vigueur', desc: 'PV, dégâts mêlée' },
  { key: 'dexterite', label: 'Dextérité', desc: 'Armes, esquive' },
  { key: 'intelligence', label: 'Intelligence', desc: 'Mana, magies' },
  { key: 'charisme', label: 'Charisme', desc: 'Marchandage' },
  { key: 'perception', label: 'Perception', desc: 'Observation' },
]

const total = computed(() => Object.values(form).reduce((a, b) => a + b, 0))
const remaining = computed(() => TOTAL_POINTS - total.value)

function increment(key) { if (remaining.value > 0 && form[key] < 8) form[key]++ }
function decrement(key) { if (form[key] > 1) form[key]-- }

async function create() {
  if (remaining.value !== 0) return
  loading.value = true
  error.value = ''
  try {
    await gameStore.createCharacter({ name: name.value, ...form })
    router.push('/town')
  } catch (e) {
    error.value = e.response?.data?.errors?.join(', ') || 'Erreur lors de la création'
  } finally {
    loading.value = false
  }
}
</script>
