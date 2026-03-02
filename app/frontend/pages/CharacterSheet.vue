<template>
  <div class="min-h-screen bg-stone-950">
    <StatusBar />
    <div class="max-w-3xl mx-auto px-4 py-8">
      <div class="flex items-center justify-between mb-6 animate-fade-in-up">
        <h1 class="text-2xl font-bold text-amber-400">{{ gameStore.character?.name }}</h1>
        <router-link to="/town" class="text-stone-400 hover:text-amber-400 text-sm">Retour</router-link>
      </div>

      <div v-if="gameStore.character" class="space-y-6">
        <!-- Caractéristiques -->
        <section class="card p-5 animate-fade-in-up stagger-1">
          <h2 class="text-lg font-semibold text-amber-400 mb-4 flex items-center gap-2">
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z" />
            </svg>
            Caractéristiques
          </h2>
          <div class="grid grid-cols-2 md:grid-cols-5 gap-3">
            <div v-for="stat in charStats" :key="stat.key"
              class="bg-stone-800 rounded-lg p-3 text-center border border-stone-700/50 hover:border-amber-700/30 transition">
              <div class="text-xs text-stone-500 uppercase tracking-wider">{{ stat.label }}</div>
              <div class="text-2xl font-bold text-amber-400 mt-1">{{ gameStore.character[stat.key] }}</div>
            </div>
          </div>
        </section>

        <!-- Compétences par catégorie -->
        <section v-for="(skills, category) in gameStore.skillsByCategory" :key="category"
          class="card p-5 animate-fade-in-up stagger-2">
          <h2 class="text-lg font-semibold text-amber-400 mb-3 capitalize">{{ categoryLabel(category) }}</h2>
          <div class="space-y-1.5">
            <div v-for="skill in skills" :key="skill.id"
              class="flex items-center justify-between bg-stone-800 rounded-lg px-4 py-2 hover:bg-stone-750 transition group">
              <span class="text-stone-300 text-sm">{{ skill.name }}</span>
              <div class="flex items-center gap-3">
                <span class="text-amber-400 font-mono font-bold text-sm">{{ skill.notation }}</span>
                <button @click="upgrade(skill)"
                  :disabled="gameStore.character.xp < skill.upgrade_cost"
                  class="text-xs bg-purple-800 hover:bg-purple-700 text-purple-200 px-2.5 py-1 rounded-lg transition disabled:opacity-30 active:scale-95 opacity-60 group-hover:opacity-100"
                  :title="`Coût : ${skill.upgrade_cost} XP`">
                  +{{ skill.upgrade_cost }} XP
                </button>
              </div>
            </div>
          </div>
        </section>

        <!-- Techniques apprises -->
        <section v-if="gameStore.character.techniques?.length" class="card p-5 animate-fade-in-up stagger-3">
          <h2 class="text-lg font-semibold text-red-400 mb-3 flex items-center gap-2">
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
            </svg>
            Techniques
          </h2>
          <div class="flex flex-wrap gap-2">
            <span v-for="t in gameStore.character.techniques" :key="t.id"
              class="bg-red-900/30 text-red-300 border border-red-800/40 text-xs px-3 py-1.5 rounded-full font-medium">
              {{ t.name }}
            </span>
          </div>
        </section>

        <!-- Magies apprises -->
        <section v-if="gameStore.character.magics?.length" class="card p-5 animate-fade-in-up stagger-4">
          <h2 class="text-lg font-semibold text-blue-400 mb-3 flex items-center gap-2">
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" />
            </svg>
            Magies
          </h2>
          <div class="flex flex-wrap gap-2">
            <span v-for="m in gameStore.character.magics" :key="m.id"
              class="text-xs px-3 py-1.5 rounded-full border font-medium"
              :class="magicClass(m.element)">
              {{ m.name }}
            </span>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>

<script setup>
import { onMounted } from 'vue'
import { useGameStore } from '../stores/game'
import StatusBar from '../components/game/StatusBar.vue'

const gameStore = useGameStore()

const charStats = [
  { key: 'vigueur', label: 'Vigueur' },
  { key: 'dexterite', label: 'Dextérité' },
  { key: 'intelligence', label: 'Intelligence' },
  { key: 'charisme', label: 'Charisme' },
  { key: 'perception', label: 'Perception' },
]

function categoryLabel(cat) {
  const labels = { vigueur: 'Vigueur', dexterite: 'Dextérité', intelligence: 'Intelligence', charisme: 'Charisme', perception: 'Perception' }
  return labels[cat] || cat
}

function magicClass(element) {
  const classes = {
    feu: 'bg-orange-900/30 text-orange-300 border-orange-800/40',
    eau: 'bg-cyan-900/30 text-cyan-300 border-cyan-800/40',
    ombre: 'bg-violet-900/30 text-violet-300 border-violet-800/40',
    lumiere: 'bg-yellow-900/30 text-yellow-300 border-yellow-800/40',
    nature: 'bg-emerald-900/30 text-emerald-300 border-emerald-800/40',
  }
  return classes[element] || 'bg-stone-800 text-stone-300 border-stone-700'
}

async function upgrade(skill) {
  await gameStore.upgradeSkill(skill.id)
}

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()
  await gameStore.fetchSkills()
})
</script>
