<template>
  <div class="min-h-screen bg-stone-950">
    <StatusBar />
    <div class="max-w-3xl mx-auto px-4 py-8">
      <div class="flex items-center justify-between mb-6 animate-fade-in-up">
        <h1 class="text-2xl font-bold text-amber-400">Inventaire</h1>
        <router-link to="/town" class="text-stone-400 hover:text-amber-400 text-sm">Retour</router-link>
      </div>

      <!-- Équipement porté -->
      <section class="card p-5 mb-6 animate-fade-in-up stagger-1">
        <h2 class="text-lg font-semibold text-amber-400 mb-4">Équipement porté</h2>
        <div class="grid grid-cols-2 md:grid-cols-5 gap-3">
          <div v-for="slot in slots" :key="slot.key"
            class="bg-stone-800 rounded-lg p-3 text-center border border-stone-700/50">
            <div class="text-xs text-stone-500 uppercase mb-2">{{ slot.label }}</div>
            <div v-if="gameStore.equipment[slot.key]">
              <ItemIcon :type="'equipment'" :category="slotCategory(slot.key)" size="lg" class="mx-auto mb-1" />
              <div class="text-xs text-stone-200 leading-tight">
                {{ gameStore.equipment[slot.key].name }}
              </div>
              <button @click="unequip(gameStore.equipment[slot.key].id)"
                class="mt-2 text-xs text-red-400 hover:text-red-300 transition">Retirer</button>
            </div>
            <div v-else class="py-2">
              <div class="w-9 h-9 mx-auto mb-1 rounded-lg bg-stone-700/50 border border-dashed border-stone-600 flex items-center justify-center">
                <span class="text-stone-600 text-lg">+</span>
              </div>
              <div class="text-xs text-stone-600 italic">Vide</div>
            </div>
          </div>
        </div>
      </section>

      <!-- Sac -->
      <section class="card p-5 animate-fade-in-up stagger-2">
        <h2 class="text-lg font-semibold text-amber-400 mb-4">Sac</h2>
        <div v-if="unequippedItems.length === 0" class="text-stone-500 text-sm italic text-center py-6">
          Votre sac est vide.
        </div>
        <div v-else class="space-y-2">
          <div v-for="item in unequippedItems" :key="item.id"
            class="flex items-center gap-3 bg-stone-800 rounded-lg px-4 py-3 hover:bg-stone-750 transition">
            <ItemIcon :type="item.item_type" :category="item.data?.category" />
            <div class="flex-1 min-w-0">
              <span class="text-stone-200 text-sm font-medium">{{ item.name }}</span>
              <span v-if="item.quantity > 1" class="text-stone-500 text-xs ml-1">x{{ item.quantity }}</span>
              <p class="text-stone-500 text-xs truncate">{{ item.data?.notes }}</p>
            </div>
            <div class="flex gap-2 flex-shrink-0">
              <button v-if="item.item_type === 'equipment'" @click="equip(item.id)"
                class="text-xs bg-amber-800 hover:bg-amber-700 text-amber-200 px-3 py-1.5 rounded-lg transition active:scale-95">
                Équiper
              </button>
              <button v-if="item.data?.consumable" @click="use(item.id)"
                class="text-xs bg-green-800 hover:bg-green-700 text-green-200 px-3 py-1.5 rounded-lg transition active:scale-95">
                Utiliser
              </button>
            </div>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted } from 'vue'
import { useGameStore } from '../stores/game'
import StatusBar from '../components/game/StatusBar.vue'
import ItemIcon from '../components/game/ItemIcon.vue'

const gameStore = useGameStore()

const slots = [
  { key: 'weapon', label: 'Arme' },
  { key: 'armor', label: 'Armure' },
  { key: 'helmet', label: 'Casque' },
  { key: 'boots', label: 'Bottes' },
  { key: 'shield', label: 'Bouclier' },
]

function slotCategory(slotKey) {
  const map = { weapon: 'arme_de_melee', armor: 'armure', helmet: 'casque', boots: 'bottes', shield: 'bouclier' }
  return map[slotKey] || ''
}

const unequippedItems = computed(() => gameStore.inventory.filter(i => !i.equipped))

async function equip(id) { await gameStore.equipItem(id) }
async function unequip(id) { await gameStore.unequipItem(id) }
async function use(id) { await gameStore.useItem(id) }

onMounted(async () => {
  if (!gameStore.character) await gameStore.fetchCharacter()
  await gameStore.fetchInventory()
})
</script>
