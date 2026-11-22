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
      <div class="flex flex-wrap gap-2 mb-6 animate-fade-in-up stagger-2">
        <button v-for="tab in tabs" :key="tab.key" @click="activeTab = tab.key"
          :class="activeTab === tab.key ? 'bg-orange-700 text-white' : 'btn-ghost'"
          class="px-4 py-2 rounded-lg text-sm font-medium transition">{{ tab.label }}</button>
        <button @click="activeTab = 'sell'"
          :class="activeTab === 'sell' ? 'bg-red-700 text-white' : 'btn-ghost'"
          class="px-4 py-2 rounded-lg text-sm font-medium transition">Vendre</button>
        <button @click="activeTab = 'repair'"
          :class="activeTab === 'repair' ? 'bg-sky-700 text-white' : 'btn-ghost'"
          class="px-4 py-2 rounded-lg text-sm font-medium transition">
          Réparation<span v-if="repairs.length" class="ml-1 text-xs opacity-80">({{ repairs.length }})</span>
        </button>
      </div>

      <!-- Repair tab -->
      <div v-if="activeTab === 'repair'" class="space-y-2">
        <p class="text-stone-500 text-xs mb-3">
          Chaque combat use l'équipement porté (-1 durabilité, -10 en cas de défaite).
          Une remise à neuf complète coûte la moitié du prix de vente de l'objet.
        </p>
        <div v-for="(item, i) in repairs" :key="item.id"
          @click="toggleRepair(item.id)"
          class="flex items-center gap-3 card p-4 cursor-pointer animate-fade-in-up"
          :class="[`stagger-${Math.min(i + 3, 8)}`, selectedRepairs.includes(item.id) ? 'ring-1 ring-sky-600' : '']">
          <input type="checkbox" :checked="selectedRepairs.includes(item.id)" @click.stop="toggleRepair(item.id)"
            class="accent-sky-600 w-4 h-4 flex-shrink-0" />
          <ItemIcon type="equipment" :category="item.data?.category" :item-key="item.item_key" />
          <div class="flex-1 min-w-0">
            <span class="text-stone-200 text-sm font-medium">{{ item.name }}</span>
            <span v-if="item.equipped" class="text-amber-500 text-xs ml-2">porté</span>
            <span v-if="item.enchantment" class="text-violet-400 text-xs ml-2">{{ item.enchantment.label }}</span>
            <div class="flex items-center gap-2 mt-1">
              <div class="h-1.5 w-32 bg-stone-800 rounded-full overflow-hidden">
                <div class="h-full rounded-full" :class="durabilityColor(item.durability)"
                  :style="{ width: `${item.durability}%` }"></div>
              </div>
              <span class="text-xs" :class="item.durability === 0 ? 'text-red-400' : 'text-stone-400'">
                {{ item.durability }}/{{ item.max_durability }}
              </span>
            </div>
          </div>
          <span class="text-yellow-400 text-sm font-bold flex-shrink-0">{{ item.repair_cost }} or</span>
        </div>
        <p v-if="repairs.length === 0" class="text-stone-500 text-sm italic text-center py-8">
          Tout votre équipement est en parfait état.
        </p>
        <div v-else class="flex items-center justify-between card p-4 mt-4">
          <button @click="toggleAllRepairs" class="btn-ghost px-3 py-1.5 rounded-lg text-xs">
            {{ selectedRepairs.length === repairs.length ? 'Tout désélectionner' : 'Tout sélectionner' }}
          </button>
          <div class="flex items-center gap-3">
            <span class="text-stone-400 text-sm">Total : <span class="text-yellow-400 font-bold">{{ repairTotal }} or</span></span>
            <button @click="repair"
              :disabled="!selectedRepairs.length || repairing || (gameStore.character?.gold || 0) < repairTotal"
              class="bg-sky-700 hover:bg-sky-600 text-white text-sm font-medium px-4 py-2 rounded-lg transition disabled:opacity-40 disabled:cursor-not-allowed active:scale-95">
              {{ repairing ? 'Réparation...' : 'Réparer' }}
            </button>
          </div>
        </div>
      </div>

      <!-- Buy tabs -->
      <div v-else-if="activeTab !== 'sell'" class="space-y-2">
        <div v-for="(item, i) in filteredItems" :key="item.key"
          class="flex items-center gap-3 card p-4 animate-fade-in-up"
          :class="`stagger-${Math.min(i + 3, 8)}`">
          <ItemIcon :type="item.item_type" :category="item.data?.category" :item-key="item.item_key || item.key" />
          <div class="flex-1 min-w-0">
            <span class="text-stone-200 text-sm font-medium">{{ item.name }}</span>
            <span v-if="item.data?.tier" class="text-stone-600 text-xs ml-2">T{{ item.data.tier }}</span>
            <p v-if="itemStats(item.data).length" class="flex flex-wrap gap-x-3 text-xs mt-0.5">
              <span v-for="stat in itemStats(item.data)" :key="stat.label" :class="stat.class">
                {{ stat.label }} <span class="font-semibold">{{ stat.value }}</span>
              </span>
            </p>
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
          <ItemIcon :type="item.item_type" :category="item.data?.category" :item-key="item.item_key || item.key" />
          <div class="flex-1 min-w-0">
            <span class="text-stone-200 text-sm font-medium">{{ item.name }}</span>
            <span v-if="item.quantity > 1" class="text-stone-500 text-xs ml-1">x{{ item.quantity }}</span>
            <span v-if="item.enchantment" class="text-violet-400 text-xs ml-2">{{ item.enchantment.label }}</span>
            <p v-if="itemStats(item.data).length" class="flex flex-wrap gap-x-3 text-xs mt-0.5">
              <span v-for="stat in itemStats(item.data)" :key="stat.label" :class="stat.class">
                {{ stat.label }} <span class="font-semibold">{{ stat.value }}</span>
              </span>
            </p>
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
              Jet de Forge ({{ workInfo?.notation || '1D' }}) × {{ workInfo?.gold_per_point || 0 }} or
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
const activeTab = ref('swords')
const showWorkModal = ref(false)
const working = ref(false)

// Each tab matches equipment by category and, for melee weapons, by weapon_type.
const tabs = [
  { key: 'swords', label: 'Épées', category: 'arme_de_melee', types: ['epee', 'rapiere', 'dague'] },
  { key: 'axes', label: 'Haches', category: 'arme_de_melee', types: ['hache'] },
  { key: 'polearms', label: 'Lances', category: 'arme_de_melee', types: ['lance', 'arme_d_hast'] },
  { key: 'ranged', label: 'Distance', category: 'arme_a_distance' },
  { key: 'shields', label: 'Boucliers', category: 'bouclier' },
  { key: 'armor', label: 'Armures', category: 'armure' },
  { key: 'helmets', label: 'Casques', category: 'casque' },
  { key: 'boots', label: 'Bottes', category: 'bottes' },
]

const workInfo = computed(() => gameStore.forge.work)

// --- Repair tab ---
const selectedRepairs = ref([])
const repairing = ref(false)
const repairs = computed(() => gameStore.forge.repairs || [])
const repairTotal = computed(() =>
  repairs.value.filter(i => selectedRepairs.value.includes(i.id)).reduce((sum, i) => sum + i.repair_cost, 0)
)

function toggleRepair(id) {
  selectedRepairs.value = selectedRepairs.value.includes(id)
    ? selectedRepairs.value.filter(x => x !== id)
    : [...selectedRepairs.value, id]
}

function toggleAllRepairs() {
  selectedRepairs.value = selectedRepairs.value.length === repairs.value.length ? [] : repairs.value.map(i => i.id)
}

function durabilityColor(value) {
  if (value >= 70) return 'bg-green-600'
  if (value >= 30) return 'bg-amber-500'
  return 'bg-red-600'
}

async function repair() {
  repairing.value = true
  try {
    await gameStore.repairItems(selectedRepairs.value)
    selectedRepairs.value = []
  } finally {
    repairing.value = false
  }
}
const canWork = computed(() => workInfo.value?.can_work)

const filteredItems = computed(() => {
  const tab = tabs.find(t => t.key === activeTab.value)
  if (!tab) return []
  return (gameStore.forge.equipment || []).filter(e =>
    e.data?.category === tab.category && (!tab.types || tab.types.includes(e.data?.weapon_type))
  )
})

function dice(mastery = 0, bonus = 0) {
  if (!mastery) return bonus ? `+${bonus}` : '0'
  if (!bonus) return `${mastery}D`
  return bonus > 0 ? `${mastery}D+${bonus}` : `${mastery}D${bonus}`
}

function signed(n) {
  return n > 0 ? `+${n}` : `${n}`
}

// Combat stats shown on the item row: weapon damage dice, armor protection, accuracy modifier.
function itemStats(data) {
  if (!data) return []
  const stats = []
  if (['arme_de_melee', 'arme_a_distance'].includes(data.category)) {
    // Player damage = characteristic dice + weapon dice (see CombatService#player_damage)
    const ranged = data.category === 'arme_a_distance'
    const statLabel = ranged ? 'Dex' : 'Vig'
    const statValue = gameStore.character?.[ranged ? 'dexterite' : 'vigueur'] || 0
    const weapon = dice(data.damage_mastery, data.damage_bonus)
    const total = dice(statValue + (data.damage_mastery || 0), data.damage_bonus || 0)
    stats.push({ label: 'Dégâts', value: `${total} (${statLabel} ${statValue} + arme ${weapon})`, class: 'text-red-300' })
  } else if (data.dr_mastery !== undefined || data.dr_bonus !== undefined) {
    stats.push({ label: 'Protection', value: dice(data.dr_mastery, data.dr_bonus), class: 'text-sky-300' })
  }
  if (data.accuracy_bonus) {
    stats.push({ label: 'Précision', value: signed(data.accuracy_bonus), class: data.accuracy_bonus > 0 ? 'text-green-300' : 'text-orange-300' })
  }
  const extras = [['esquive_bonus', 'Esquive'], ['parade_bonus', 'Parade'], ['flee_bonus', 'Fuite'], ['speed_bonus', 'Vitesse']]
  extras.forEach(([field, label]) => {
    if (data[field]) stats.push({ label, value: signed(data[field]), class: 'text-emerald-300' })
  })
  if (data.two_handed) stats.push({ label: 'Deux mains', value: '', class: 'text-stone-400' })
  if (data.pierce_targets > 1) stats.push({ label: `Transperce ${data.pierce_targets} ennemis`, value: '', class: 'text-amber-300' })
  return stats
}

const sellableItems = computed(() =>
  gameStore.inventory.filter(i => !i.equipped && i.item_type === 'equipment')
)

// Computed by the server (enchanted items sell for more)
function sellPrice(item) {
  return item.sell_price ?? Math.ceil((item.data?.price || 0) / 2)
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
