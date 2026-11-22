<template>
  <div class="min-h-screen bg-stone-950">
    <StatusBar />
    <div class="max-w-3xl mx-auto px-4 py-8">
      <!-- Header with image -->
      <div class="relative rounded-2xl overflow-hidden mb-6 animate-fade-in-up">
        <img :src="'/images/academie-mages.webp'" alt="Académie des mages" loading="lazy"
          class="w-full h-64 md:h-72 object-cover opacity-60" />
        <div class="absolute inset-0 bg-gradient-to-t from-stone-950 via-stone-950/40 to-transparent"></div>
        <div class="absolute bottom-4 left-6 right-6 flex items-end justify-between">
          <h1 class="text-2xl font-bold text-blue-400 drop-shadow-lg">Académie des mages</h1>
          <router-link to="/town" class="text-stone-400 hover:text-amber-400 text-sm">Retour</router-link>
        </div>
      </div>

      <!-- Tabs -->
      <div class="flex gap-2 mb-6 animate-fade-in-up stagger-1">
        <button v-for="tab in tabs" :key="tab.key" @click="activeTab = tab.key"
          :class="activeTab === tab.key ? (tab.key === 'enchant' ? 'bg-violet-700 text-white' : 'bg-blue-700 text-white') : 'btn-ghost'"
          class="px-4 py-2 rounded-lg text-sm font-medium transition">{{ tab.label }}</button>
      </div>

      <template v-if="activeTab === 'spells'">
      <p class="text-stone-500 text-sm mb-6 animate-fade-in-up stagger-1">
        Choisissez un sort à apprendre. La durée dépend du tier du sort et de votre intelligence.
        Vous devez apprendre les sorts d'un élément dans l'ordre.
      </p>

      <div v-for="(magics, element) in gameStore.availableMagics" :key="element"
        class="mb-6 card p-5 animate-fade-in-up stagger-2">
        <h2 class="text-lg font-semibold mb-3 capitalize flex items-center gap-2" :class="elementColor(element)">
          <span class="w-2 h-2 rounded-full" :class="elementDot(element)"></span>
          {{ elementLabel(element) }}
        </h2>
        <div class="space-y-2">
          <div v-for="magic in magics" :key="magic.key"
            class="bg-stone-800 rounded-lg px-4 py-3 hover:bg-stone-750 transition">
            <div class="flex items-center justify-between gap-3">
              <div class="flex items-center gap-3 min-w-0">
                <div class="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0" :class="elementBg(element)">
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" />
                  </svg>
                </div>
                <div class="min-w-0">
                  <span class="text-stone-200 text-sm font-medium">{{ magic.name }}</span>
                  <span class="text-stone-600 text-xs ml-2">Tier {{ magic.tier }}</span>
                  <span v-if="magic.mana_cost" class="text-cyan-500 text-xs ml-2">{{ magic.mana_cost }} mana</span>
                </div>
              </div>
              <div class="flex-shrink-0">
                <span v-if="magic.learned" class="text-green-400 text-xs font-semibold px-2 py-1 bg-green-900/30 rounded-full">Appris</span>
                <button v-else @click="openConfirm(magic, element)" :disabled="gameStore.isBusy"
                  class="text-xs bg-blue-800 hover:bg-blue-700 text-blue-200 px-3 py-1.5 rounded-lg transition disabled:opacity-30 active:scale-95">
                  Apprendre
                </button>
              </div>
            </div>
            <p v-if="magic.description" class="text-stone-500 text-xs mt-2 leading-snug pl-10">
              {{ magic.description }}
            </p>
          </div>
        </div>
      </div>
      </template>

      <!-- Enchantment tab -->
      <template v-else>
        <div class="card p-5 mb-4 animate-fade-in-up stagger-2">
          <div class="flex flex-wrap items-center gap-x-6 gap-y-2 text-sm">
            <span class="text-stone-300">Jet d'Enchantement :
              <span class="text-violet-300 font-semibold">{{ ench.notation || '—' }}</span></span>
            <span class="text-violet-400 font-semibold">{{ ench.soul_stones || 0 }} pierre(s) d'âme</span>
            <span class="text-yellow-400 font-semibold">{{ gameStore.character?.gold || 0 }} or</span>
          </div>
          <p class="text-stone-500 text-xs mt-3 leading-relaxed">
            Le résultat du jet fixe la puissance de l'enchantement :
            <span class="text-red-400">moins de {{ ench.thresholds?.[0] || 5 }} : échec</span><span v-for="(t, i) in ench.thresholds" :key="t">
              · {{ t }}{{ ench.thresholds[i + 1] ? `–${ench.thresholds[i + 1] - 1}` : '+' }} : niveau {{ i + 1 }}</span>.
            L'or et les pierres d'âme sont consommés même en cas d'échec. Un nouvel enchantement réussi remplace l'ancien.
            Les pierres d'âme s'obtiennent en battant des monstres (toujours sur les boss de la tour).
          </p>
          <p v-if="ench.damage_level === 1" class="text-amber-400 text-xs mt-2">Académie endommagée : enchantements +25% d'or.</p>
          <p v-else-if="ench.damage_level >= 2" class="text-red-400 text-xs mt-2">Académie détruite : réparez-la pour enchanter.</p>
        </div>

        <div class="space-y-2">
          <div v-for="(item, i) in enchantableItems" :key="item.id"
            class="flex items-center gap-3 card p-4 animate-fade-in-up" :class="`stagger-${Math.min(i + 3, 8)}`">
            <ItemIcon type="equipment" :category="item.category" :item-key="item.item_key" />
            <div class="flex-1 min-w-0">
              <span class="text-stone-200 text-sm font-medium">{{ item.name }}</span>
              <span v-if="item.tier" class="text-stone-600 text-xs ml-2">T{{ item.tier }}</span>
              <span v-if="item.equipped" class="text-amber-500 text-xs ml-2">équipé</span>
              <p class="text-xs mt-0.5" :class="item.enchantment ? 'text-violet-400' : 'text-stone-600 italic'">
                {{ item.enchantment ? `${item.enchantment.label} (niveau ${item.enchantment.level})` : 'Aucun enchantement' }}
              </p>
            </div>
            <div class="flex items-center gap-3 flex-shrink-0 text-xs">
              <span class="text-yellow-400">{{ item.cost.gold }} or</span>
              <span class="text-violet-400">{{ item.cost.soul_stones }} pierre(s)</span>
              <button @click="openEnchant(item)" :disabled="ench.damage_level >= 2"
                class="bg-violet-800 hover:bg-violet-700 text-violet-100 px-3 py-1.5 rounded-lg transition disabled:opacity-30 active:scale-95">
                Enchanter
              </button>
            </div>
          </div>
          <p v-if="enchantableItems.length === 0" class="text-stone-500 text-sm italic text-center py-8">
            Aucun équipement à enchanter. Achetez-en à la forge.
          </p>
        </div>
      </template>
    </div>

    <!-- Enchant modal -->
    <div v-if="enchantTarget"
      class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4"
      @click.self="closeEnchant">
      <div class="bg-stone-900 border border-stone-700 rounded-xl p-6 max-w-lg w-full animate-fade-in-up max-h-[90vh] overflow-y-auto">
        <h2 class="text-xl font-bold text-violet-400 mb-1">Enchanter : {{ enchantTarget.name }}</h2>
        <p class="text-stone-500 text-xs mb-4">
          Jet d'Enchantement {{ ench.notation }} ·
          <span class="text-yellow-400">{{ enchantTarget.cost.gold }} or</span> ·
          <span class="text-violet-400">{{ enchantTarget.cost.soul_stones }} pierre(s) d'âme</span>
        </p>

        <div v-if="enchantResult" class="rounded-lg p-4 mb-4 text-sm"
          :class="enchantResult.enchanted ? 'bg-violet-900/30 text-violet-200' : 'bg-red-900/30 text-red-300'">
          {{ enchantResult.message }}
        </div>

        <template v-else>
          <div class="space-y-2 mb-4">
            <label v-for="effect in enchantTarget.effects" :key="effect.key"
              class="block rounded-lg p-3 border cursor-pointer transition"
              :class="selectedEffect === effect.key ? 'border-violet-500 bg-violet-900/20' : 'border-stone-700 bg-stone-800 hover:border-stone-600'">
              <div class="flex items-center gap-2">
                <input type="radio" :value="effect.key" v-model="selectedEffect" class="accent-violet-500" />
                <span class="text-stone-200 text-sm font-medium">{{ effect.name }}</span>
              </div>
              <p class="text-stone-500 text-xs mt-1 pl-5">{{ effect.description }}</p>
              <p class="text-violet-300/80 text-xs mt-1 pl-5">
                <span v-for="(label, lvl) in effect.levels" :key="lvl">{{ lvl ? ' · ' : '' }}{{ label.replace(effect.name + ' ', '') }}</span>
              </p>
            </label>
          </div>
          <p v-if="enchantTarget.enchantment" class="text-amber-400 text-xs mb-4">
            Cet objet porte déjà « {{ enchantTarget.enchantment.label }} » : il sera remplacé si l'enchantement réussit.
          </p>
          <p v-if="!canAffordEnchant" class="text-red-400 text-xs mb-4">
            Ressources insuffisantes.
          </p>
        </template>

        <div class="flex gap-3 justify-end">
          <button @click="closeEnchant" class="btn-ghost px-4 py-2 rounded-lg text-sm">
            {{ enchantResult ? 'Fermer' : 'Annuler' }}
          </button>
          <button v-if="enchantResult" @click="enchantResult = null" :disabled="!canAffordEnchant"
            class="bg-violet-700 hover:bg-violet-600 text-white font-medium px-4 py-2 rounded-lg transition disabled:opacity-40 active:scale-95">
            Recommencer
          </button>
          <button v-else @click="confirmEnchant" :disabled="!selectedEffect || enchanting || !canAffordEnchant"
            class="bg-violet-700 hover:bg-violet-600 text-white font-medium px-4 py-2 rounded-lg transition disabled:opacity-40 active:scale-95">
            {{ enchanting ? 'En cours...' : 'Enchanter' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Confirmation modal -->
    <div v-if="selectedMagic"
      class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4"
      @click.self="selectedMagic = null">
      <div class="bg-stone-900 border border-stone-700 rounded-xl p-6 max-w-md w-full animate-fade-in-up">
        <h2 class="text-xl font-bold mb-1" :class="elementColor(selectedElement)">{{ selectedMagic.name }}</h2>
        <p class="text-stone-500 text-xs mb-3">
          Tier {{ selectedMagic.tier }}
          <span v-if="selectedMagic.mana_cost"> · {{ selectedMagic.mana_cost }} mana</span>
        </p>
        <p v-if="selectedMagic.description" class="text-stone-300 text-sm leading-relaxed mb-4">
          {{ selectedMagic.description }}
        </p>
        <div class="bg-stone-800 rounded-lg p-3 mb-5">
          <p class="text-stone-400 text-xs uppercase tracking-wide mb-1">Durée d'apprentissage</p>
          <p class="text-amber-400 font-bold text-lg">{{ selectedMagic.days_needed }} jour(s)</p>
          <p class="text-stone-500 text-xs mt-1">
            Un jour passera à chaque étape d'étude.
          </p>
        </div>
        <div class="flex gap-3 justify-end">
          <button @click="selectedMagic = null"
            class="btn-ghost px-4 py-2 rounded-lg text-sm">Annuler</button>
          <button @click="confirmLearn" :disabled="learning"
            class="bg-blue-700 hover:bg-blue-600 text-white font-medium px-4 py-2 rounded-lg transition disabled:opacity-40 active:scale-95">
            {{ learning ? 'En cours...' : 'Commencer l\'apprentissage' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useGameStore } from '../stores/game'
import StatusBar from '../components/game/StatusBar.vue'
import ItemIcon from '../components/game/ItemIcon.vue'

const gameStore = useGameStore()
const selectedMagic = ref(null)
const selectedElement = ref(null)
const learning = ref(false)

const tabs = [
  { key: 'spells', label: 'Sorts' },
  { key: 'enchant', label: 'Enchantement' },
]
const activeTab = ref('spells')

// --- Enchantment ---
const ench = computed(() => gameStore.enchantments)
// Equipped items first
const enchantableItems = computed(() =>
  [...(ench.value.items || [])].sort((a, b) => Number(b.equipped) - Number(a.equipped))
)
const enchantTargetId = ref(null)
const enchantTarget = computed(() => (ench.value.items || []).find(i => i.id === enchantTargetId.value) || null)
const selectedEffect = ref(null)
const enchanting = ref(false)
const enchantResult = ref(null)

const canAffordEnchant = computed(() => {
  const item = enchantTarget.value
  if (!item) return false
  return (gameStore.character?.gold || 0) >= item.cost.gold && (ench.value.soul_stones || 0) >= item.cost.soul_stones
})

function openEnchant(item) {
  enchantTargetId.value = item.id
  selectedEffect.value = item.enchantment?.key || item.effects[0]?.key || null
  enchantResult.value = null
}

function closeEnchant() {
  enchantTargetId.value = null
  enchantResult.value = null
}

async function confirmEnchant() {
  if (!enchantTarget.value || !selectedEffect.value) return
  enchanting.value = true
  try {
    enchantResult.value = await gameStore.enchantItem(enchantTarget.value.id, selectedEffect.value)
  } catch {
    // error already notified by the store
  } finally {
    enchanting.value = false
  }
}

function elementLabel(el) {
  const labels = { feu: 'Feu', eau: 'Eau', ombre: 'Ombre', lumiere: 'Lumière', nature: 'Nature' }
  return labels[el] || el
}

function elementColor(el) {
  const colors = {
    feu: 'text-orange-400', eau: 'text-cyan-400', ombre: 'text-violet-400',
    lumiere: 'text-yellow-400', nature: 'text-emerald-400',
  }
  return colors[el] || 'text-stone-400'
}

function elementDot(el) {
  const colors = {
    feu: 'bg-orange-400', eau: 'bg-cyan-400', ombre: 'bg-violet-400',
    lumiere: 'bg-yellow-400', nature: 'bg-emerald-400',
  }
  return colors[el] || 'bg-stone-400'
}

function elementBg(el) {
  const colors = {
    feu: 'bg-orange-900/40 text-orange-400', eau: 'bg-cyan-900/40 text-cyan-400',
    ombre: 'bg-violet-900/40 text-violet-400', lumiere: 'bg-yellow-900/40 text-yellow-400',
    nature: 'bg-emerald-900/40 text-emerald-400',
  }
  return colors[el] || 'bg-stone-800 text-stone-400'
}

function openConfirm(magic, element) {
  selectedMagic.value = magic
  selectedElement.value = element
}

async function confirmLearn() {
  if (!selectedMagic.value) return
  learning.value = true
  try {
    await gameStore.startAcademy(selectedMagic.value.key)
    selectedMagic.value = null
    selectedElement.value = null
  } finally {
    learning.value = false
  }
}

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()
  await Promise.all([gameStore.fetchAvailableMagics(), gameStore.fetchEnchantments()])
})
</script>
