<template>
  <div v-if="data" class="space-y-6">
    <div class="card p-5">
      <p class="text-stone-400 text-sm leading-relaxed">
        Recrutez des défenseurs pour protéger la ville pendant les sièges, puis postez-les à une porte depuis la
        <router-link to="/town/fortress" class="text-amber-400 hover:underline">forteresse</router-link>.
        Seuls ceux de la porte attaquée combattent à vos côtés. Un défenseur tombé au combat est perdu.
      </p>
      <div class="flex flex-wrap gap-3 mt-4 text-sm">
        <span class="bg-stone-800 rounded-lg px-3 py-1.5">
          Recrues cette semaine : <span class="text-amber-400 font-semibold">{{ data.recruits_left }}/{{ data.recruits_per_week }}</span>
        </span>
        <span class="bg-stone-800 rounded-lg px-3 py-1.5">
          Défenseurs : <span class="text-amber-400 font-semibold">{{ data.count }}/{{ data.capacity }}</span>
          <span class="text-stone-500 text-xs ml-1">(capacité de la forteresse)</span>
        </span>
        <span class="bg-stone-800 rounded-lg px-3 py-1.5"><span class="text-yellow-400">{{ data.gold }}</span> or</span>
      </div>
      <p v-if="data.guild_destroyed" class="text-red-400 text-sm mt-3">La guilde est détruite : réparez-la pour recruter.</p>
    </div>

    <!-- Catalog -->
    <div class="card p-5">
      <h2 class="text-lg font-semibold text-red-400 mb-3">Recrues disponibles</h2>
      <div class="space-y-2">
        <div v-for="d in data.catalog" :key="d.key" class="bg-stone-800 rounded-lg px-4 py-3">
          <div class="flex items-center justify-between gap-3">
            <div class="flex items-center gap-3 min-w-0">
              <MonsterPortrait :monster-key="d.key" :name="d.name" image-dir="defenders" size="sm" />
              <div class="min-w-0">
                <div class="text-stone-200 text-sm font-medium">{{ d.name }}</div>
                <div class="text-stone-500 text-xs">{{ d.description }}</div>
              </div>
            </div>
            <div class="flex-shrink-0 flex items-center gap-3">
              <span class="text-yellow-400 text-sm whitespace-nowrap">{{ d.cost }} or</span>
              <span v-if="!d.rank_met" class="text-stone-500 text-xs px-2 py-1 bg-stone-900 rounded-full whitespace-nowrap">
                Rang {{ d.required_rank_name }}
              </span>
              <button v-else @click="recruit(d.key)" :disabled="busy || !canRecruit(d)"
                class="text-xs bg-red-800 hover:bg-red-700 text-red-200 px-3 py-1.5 rounded-lg transition disabled:opacity-30 active:scale-95">
                Recruter
              </button>
            </div>
          </div>
          <p class="text-xs text-stone-400 mt-2 pl-[3.75rem] flex flex-wrap gap-x-3">
            <span v-for="part in statParts(d.stats)" :key="part">{{ part }}</span>
          </p>
        </div>
      </div>
    </div>

    <!-- Current defenders -->
    <div class="card p-5">
      <h2 class="text-lg font-semibold text-red-400 mb-3">Garde de la ville</h2>
      <div v-if="!data.defenders.length" class="text-stone-600 text-sm text-center py-3">Aucun défenseur recruté</div>
      <div v-else class="space-y-2">
        <div v-for="d in data.defenders" :key="d.id"
          class="bg-stone-800 rounded-lg px-4 py-2 flex items-center justify-between gap-3">
          <div class="flex items-center gap-3 min-w-0">
            <MonsterPortrait :monster-key="d.key" :name="d.name" image-dir="defenders" size="sm" />
            <span class="text-sm text-stone-200 truncate">{{ d.name }}</span>
            <span class="text-xs" :class="d.direction ? 'text-emerald-400' : 'text-stone-500'">
              {{ d.direction ? `Porte ${directionLabel(d.direction)}` : 'En réserve' }}
            </span>
          </div>
          <button @click="dismiss(d)" :disabled="busy"
            class="text-xs text-red-500 hover:text-red-400 disabled:opacity-30">Renvoyer</button>
        </div>
      </div>
    </div>
  </div>
  <div v-else class="text-center py-10 text-stone-500">Chargement...</div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useGameStore } from '../../stores/game'
import MonsterPortrait from './MonsterPortrait.vue'
import { defenderStatParts, directionLabel } from '../../composables/useDefenders'

const gameStore = useGameStore()
const busy = ref(false)
const data = computed(() => gameStore.recruitsData)

const statParts = defenderStatParts

function canRecruit(d) {
  const v = data.value
  return !v.guild_destroyed && v.recruits_left > 0 && v.count < v.capacity && v.gold >= d.cost
}

async function run(fn) {
  busy.value = true
  try { await fn() } catch { /* notified by the store */ } finally { busy.value = false }
}

const recruit = key => run(() => gameStore.recruitDefender(key))
const dismiss = d => run(() => gameStore.dismissDefender(d.id))

onMounted(() => gameStore.fetchRecruits())
</script>
