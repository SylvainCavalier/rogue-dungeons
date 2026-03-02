<template>
  <div class="min-h-screen bg-stone-950">
    <StatusBar />
    <div class="max-w-4xl mx-auto px-4 py-8">
      <!-- Header with image -->
      <div class="relative rounded-2xl overflow-hidden mb-6 animate-fade-in-up">
        <img :src="'/images/magasin.webp'" alt="Magasin" loading="lazy"
          class="w-full h-36 object-cover opacity-40" />
        <div class="absolute inset-0 bg-gradient-to-t from-stone-950 via-stone-950/60 to-transparent"></div>
        <div class="absolute bottom-4 left-6 right-6 flex items-end justify-between">
          <h1 class="text-2xl font-bold text-amber-400 drop-shadow-lg">Magasin</h1>
          <div class="flex items-center gap-4">
            <span class="text-yellow-400 font-bold text-lg">{{ gameStore.character?.gold || 0 }} or</span>
            <router-link to="/town" class="text-stone-400 hover:text-amber-400 text-sm">Retour</router-link>
          </div>
        </div>
      </div>

      <!-- Tabs -->
      <div class="flex gap-2 mb-6 animate-fade-in-up stagger-1">
        <button v-for="tab in tabs" :key="tab.key" @click="activeTab = tab.key"
          :class="activeTab === tab.key ? 'bg-amber-700 text-white' : 'btn-ghost'"
          class="px-4 py-2 rounded-lg text-sm font-medium transition">{{ tab.label }}</button>
        <button @click="activeTab = 'sell'"
          :class="activeTab === 'sell' ? 'bg-red-700 text-white' : 'btn-ghost'"
          class="px-4 py-2 rounded-lg text-sm font-medium transition ml-auto">Vendre</button>
      </div>

      <!-- Buy tabs -->
      <div v-if="activeTab !== 'sell'" class="space-y-2">
        <div v-for="(item, i) in filteredItems" :key="item.key"
          class="flex items-center gap-3 card p-4 animate-fade-in-up"
          :class="`stagger-${Math.min(i + 2, 8)}`">
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
          Aucun article dans cette catégorie.
        </p>
      </div>

      <!-- Sell tab -->
      <div v-else class="space-y-2">
        <div v-for="(item, i) in sellableItems" :key="item.id"
          class="flex items-center gap-3 card p-4 animate-fade-in-up"
          :class="`stagger-${Math.min(i + 2, 8)}`">
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
          Rien à vendre.
        </p>
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
const activeTab = ref('weapons')

const tabs = [
  { key: 'weapons', label: 'Armes' },
  { key: 'armor', label: 'Armures' },
  { key: 'items', label: 'Objets' },
]

const filteredItems = computed(() => {
  if (activeTab.value === 'weapons') {
    return gameStore.shop.equipment.filter(e => ['arme_de_melee', 'arme_a_distance'].includes(e.data?.category))
  }
  if (activeTab.value === 'armor') {
    return gameStore.shop.equipment.filter(e => ['armure', 'casque', 'bottes', 'bouclier'].includes(e.data?.category))
  }
  if (activeTab.value === 'items') {
    return gameStore.shop.items
  }
  return []
})

const sellableItems = computed(() => gameStore.inventory.filter(i => !i.equipped))

function sellPrice(item) {
  return Math.ceil((item.data?.price || 0) / 2)
}

async function buy(item) {
  await gameStore.buyItem(item.key, item.item_type)
}

async function sell(item) {
  await gameStore.sellItem(item.id)
}

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()
  await Promise.all([gameStore.fetchShop(), gameStore.fetchInventory()])
})
</script>
