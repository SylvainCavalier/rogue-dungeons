<template>
  <div class="min-h-screen bg-stone-950">
    <StatusBar />
    <div class="max-w-4xl mx-auto px-4 py-8">
      <!-- Header with image -->
      <div class="relative rounded-2xl overflow-hidden mb-6 animate-fade-in-up">
        <img :src="'/images/forge.webp'" alt="La Forge" loading="lazy"
          class="w-full h-64 md:h-72 object-cover opacity-60" />
        <div class="absolute inset-0 bg-gradient-to-t from-stone-950 via-stone-950/40 to-transparent"></div>
        <div class="absolute bottom-4 left-6 right-6 flex items-end justify-between">
          <h1 class="text-2xl font-bold text-orange-400 drop-shadow-lg">La Forge</h1>
          <div class="flex items-center gap-4">
            <span class="text-yellow-400 font-bold text-lg">{{ gameStore.character?.gold || 0 }} or</span>
            <router-link to="/town" class="text-stone-400 hover:text-amber-400 text-sm">Retour</router-link>
          </div>
        </div>
      </div>

      <!-- Work button -->
      <div class="card p-5 mb-6 flex items-center justify-between animate-fade-in-up stagger-1">
        <div>
          <h2 class="text-lg font-semibold text-orange-300">Travailler à la forge</h2>
          <p class="text-stone-500 text-sm mt-1">
            Gagnez de l'or en échange d'une journée de labeur.
          </p>
        </div>
        <button @click="showWorkModal = true"
          :disabled="!canWork"
          class="bg-orange-700 hover:bg-orange-600 text-white font-medium px-4 py-2 rounded-lg transition disabled:opacity-40 disabled:cursor-not-allowed active:scale-95">
          Travailler
        </button>
      </div>

      <!-- Tabs -->
      <div class="flex gap-2 mb-6 animate-fade-in-up stagger-2">
        <button v-for="tab in tabs" :key="tab.key" @click="activeTab = tab.key"
          :class="activeTab === tab.key ? 'bg-orange-700 text-white' : 'btn-ghost'"
          class="px-4 py-2 rounded-lg text-sm font-medium transition">{{ tab.label }}</button>
        <button @click="activeTab = 'sell'"
          :class="activeTab === 'sell' ? 'bg-red-700 text-white' : 'btn-ghost'"
          class="px-4 py-2 rounded-lg text-sm font-medium transition ml-auto">Vendre</button>
      </div>

      <!-- Buy tabs -->
      <div v-if="activeTab !== 'sell'" class="space-y-2">
        <div v-for="(item, i) in filteredItems" :key="item.key"
          class="flex items-center gap-3 card p-4 animate-fade-in-up"
          :class="`stagger-${Math.min(i + 3, 8)}`">
          <ItemIcon :type="item.item_type" :category="item.data?.category" />
          <div class="flex-1 min-w-0">
            <span class="text-stone-200 text-sm font-medium">{{ item.name }}</span>
            <span v-if="item.data?.tier" class="text-stone-600 text-xs ml-2">T{{ item.data.tier }}</span>
            <p class="text-stone-500 text-xs truncate">{{ item.data?.notes }}</p>
          </div>
          <div class="flex items-center gap-3 flex-shrink-0">
            <span class="text-yellow-400 text-sm font-bold">{{ item.price }} or</span>
            <button @click="buy(item)" :disabled="(gameStore.character?.gold || 0) < item.price"
              class="text-xs bg-green-800 hover:bg-green-700 text-green-200 px-3 py-1.5 rounded-lg transition disabled:opacity-30 active:scale-95">
              Acheter
            </button>
          </div>
        </div>
        <p v-if="filteredItems.length === 0" class="text-stone-500 text-sm italic text-center py-8">
          Aucun équipement dans cette catégorie.
        </p>
      </div>

      <!-- Sell tab -->
      <div v-else class="space-y-2">
        <div v-for="(item, i) in sellableItems" :key="item.id"
          class="flex items-center gap-3 card p-4 animate-fade-in-up"
          :class="`stagger-${Math.min(i + 3, 8)}`">
          <ItemIcon :type="item.item_type" :category="item.data?.category" />
          <div class="flex-1 min-w-0">
            <span class="text-stone-200 text-sm font-medium">{{ item.name }}</span>
            <span v-if="item.quantity > 1" class="text-stone-500 text-xs ml-1">x{{ item.quantity }}</span>
          </div>
          <div class="flex items-center gap-3 flex-shrink-0">
            <span class="text-yellow-400 text-sm">{{ sellPrice(item) }} or</span>
            <button @click="sell(item)"
              class="text-xs bg-red-800 hover:bg-red-700 text-red-200 px-3 py-1.5 rounded-lg transition active:scale-95">
              Vendre
            </button>
          </div>
        </div>
        <p v-if="sellableItems.length === 0" class="text-stone-500 text-sm italic text-center py-8">
          Aucun équipement à vendre.
        </p>
      </div>
    </div>

    <!-- Work confirmation modal -->
    <div v-if="showWorkModal"
      class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4"
      @click.self="showWorkModal = false">
      <div class="bg-stone-900 border border-stone-700 rounded-xl p-6 max-w-md w-full animate-fade-in-up">
        <h2 class="text-xl font-bold text-orange-400 mb-4">Travailler à la forge ?</h2>
        <div class="space-y-3 text-sm text-stone-300">
          <p>
            Vous allez forger pendant une journée.
            <span class="text-stone-500">(1 jour passera.)</span>
          </p>
          <div class="bg-stone-800 rounded-lg p-3">
            <p class="text-stone-400 text-xs uppercase tracking-wide mb-1">Gains estimés</p>
            <p class="text-yellow-400 font-bold text-lg">
              {{ workInfo?.min_gold || 0 }} – {{ workInfo?.max_gold || 0 }} or
            </p>
            <p class="text-stone-500 text-xs mt-1">
              Jet de {{ workInfo?.vigueur || 0 }}D × 5 or
              <span v-if="workInfo?.damage_level === 1" class="text-red-400">(forge endommagée : -30%)</span>
            </p>
          </div>
        </div>
        <div class="flex gap-3 mt-6 justify-end">
          <button @click="showWorkModal = false"
            class="btn-ghost px-4 py-2 rounded-lg text-sm">Annuler</button>
          <button @click="confirmWork" :disabled="working"
            class="bg-orange-700 hover:bg-orange-600 text-white font-medium px-4 py-2 rounded-lg transition disabled:opacity-40 active:scale-95">
            {{ working ? 'En cours...' : 'Confirmer' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useGameStore } from '../stores/game'
import StatusBar from '../components/game/StatusBar.vue'
import ItemIcon from '../components/game/ItemIcon.vue'

const gameStore = useGameStore()
const router = useRouter()
const activeTab = ref('weapons')
const showWorkModal = ref(false)
const working = ref(false)

const tabs = [
  { key: 'weapons', label: 'Armes' },
  { key: 'armor', label: 'Armures' },
]

const workInfo = computed(() => gameStore.forge.work)
const canWork = computed(() => workInfo.value?.can_work)

const filteredItems = computed(() => {
  const equipment = gameStore.forge.equipment || []
  if (activeTab.value === 'weapons') {
    return equipment.filter(e => ['arme_de_melee', 'arme_a_distance'].includes(e.data?.category))
  }
  if (activeTab.value === 'armor') {
    return equipment.filter(e => ['armure', 'casque', 'bottes', 'bouclier'].includes(e.data?.category))
  }
  return []
})

const sellableItems = computed(() =>
  gameStore.inventory.filter(i => !i.equipped && i.item_type === 'equipment')
)

function sellPrice(item) {
  return Math.ceil((item.data?.price || 0) / 2)
}

async function buy(item) {
  await gameStore.buyItem(item.key, item.item_type)
  await gameStore.fetchForge()
}

async function sell(item) {
  await gameStore.sellItem(item.id)
}

async function confirmWork() {
  working.value = true
  try {
    const result = await gameStore.work()
    showWorkModal.value = false
    await gameStore.fetchForge()
    if (result?.siege_pending) router.push('/siege')
  } finally {
    working.value = false
  }
}

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()
  await Promise.all([gameStore.fetchForge(), gameStore.fetchInventory()])
})
</script>
