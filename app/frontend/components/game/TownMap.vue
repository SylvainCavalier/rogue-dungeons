<template>
  <div class="relative w-full aspect-[1440/800] rounded-2xl overflow-hidden border border-stone-800 bg-stone-950 select-none">
    <img :src="IMAGE" alt="La place de la ville" class="absolute inset-0 w-full h-full object-cover" draggable="false" />

    <!-- Darken everything slightly while a building is hovered, so it pops out -->
    <div class="absolute inset-0 bg-stone-950 pointer-events-none transition-opacity duration-300"
      :class="hovered ? 'opacity-40' : 'opacity-0'"></div>

    <!-- Clickable building silhouettes (drawn back to front so foreground wins) -->
    <svg class="absolute inset-0 w-full h-full" viewBox="0 0 1440 800" preserveAspectRatio="none">
      <defs>
        <clipPath v-for="b in buildings" :id="`town-clip-${b.key}`" :key="b.key">
          <polygon :points="b.points" />
        </clipPath>
      </defs>
      <g v-for="b in buildings" :key="b.key"
        :class="b.disabled ? 'cursor-not-allowed' : 'cursor-pointer'"
        role="link" :aria-label="b.label" :aria-disabled="b.disabled"
        @mouseenter="hovered = b.key" @mouseleave="hovered = null" @click="go(b)">
        <!-- Highlighted copy of the building, clipped to its silhouette -->
        <g class="transition-opacity duration-300" :class="hovered === b.key ? 'opacity-100' : 'opacity-0'"
          :style="{ filter: b.disabled ? 'grayscale(1) brightness(0.9)' : 'drop-shadow(0 0 10px rgba(251,191,36,0.85))' }">
          <image :href="IMAGE" width="1440" height="800" :clip-path="`url(#town-clip-${b.key})`"
            :style="{ filter: b.disabled ? 'none' : 'brightness(1.35) saturate(1.15)' }" />
        </g>
        <polygon :points="b.points" fill="transparent" />
      </g>
    </svg>

    <!-- Building labels -->
    <button v-for="b in buildings" :key="`label-${b.key}`" type="button"
      class="absolute hidden sm:flex -translate-x-1/2 -translate-y-1/2 flex-col items-center rounded-md border px-2 py-0.5 backdrop-blur-sm transition duration-200 whitespace-nowrap leading-tight"
      :class="labelClass(b)"
      :style="{ left: (b.label_at[0] / 14.4) + '%', top: (b.label_at[1] / 8) + '%' }"
      @mouseenter="hovered = b.key" @mouseleave="hovered = null" @click="go(b)">
      <span class="text-[clamp(10px,1.1vw,13px)] font-semibold">
        <span v-if="b.disabled">🔒 </span>{{ b.label }}
      </span>
      <span v-if="b.subtitle && (hovered === b.key || b.alert)"
        class="text-[clamp(9px,0.9vw,11px)] font-normal"
        :class="b.alert ? 'text-red-300' : 'text-stone-300'">{{ b.subtitle }}</span>
    </button>

    <!-- Corner shortcuts (not buildings) -->
    <div class="absolute top-2 left-2 sm:top-3 sm:left-3 flex gap-2">
      <router-link v-for="s in shortcuts" :key="s.to" :to="s.to" :title="s.label"
        class="group relative flex items-center justify-center w-9 h-9 sm:w-11 sm:h-11 rounded-full border backdrop-blur-sm transition"
        :class="s.alert
          ? 'bg-red-950/80 border-red-500 text-red-300 animate-pulse hover:animate-none'
          : 'bg-stone-950/75 border-stone-600 text-amber-400 hover:border-amber-400 hover:bg-stone-900'">
        <svg class="w-5 h-5 sm:w-6 sm:h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" :d="s.icon" />
        </svg>
        <span class="pointer-events-none absolute left-1/2 top-full mt-1 -translate-x-1/2 whitespace-nowrap rounded bg-stone-900/90 px-2 py-0.5 text-xs text-stone-200 opacity-0 group-hover:opacity-100 transition">
          {{ s.label }}
        </span>
      </router-link>
    </div>
  </div>

  <!-- Mobile: labels are too small on the picture, list the places below it -->
  <div class="sm:hidden grid grid-cols-3 gap-2 mt-3">
    <button v-for="b in buildings" :key="`m-${b.key}`" type="button" @click="go(b)" :disabled="b.disabled"
      class="rounded-lg border px-2 py-2 text-xs font-medium transition disabled:opacity-40"
      :class="b.alert ? 'border-red-700 bg-red-950/40 text-red-300' : 'border-stone-700 bg-stone-900 text-stone-200'">
      {{ b.label }}
    </button>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'

const props = defineProps({
  busy: { type: Boolean, default: false },
  nextFloor: { type: Number, default: 1 },
  siegeSubtitle: { type: String, default: '' },
  siegeImminent: { type: Boolean, default: false },
  hasBuildingDamage: { type: Boolean, default: false }
})

const router = useRouter()
const hovered = ref(null)

// Silhouettes and label anchors are in pixels of the 1440x800 source image
// (public/images/town/town_square.webp). Re-check them if the image is regenerated.
const IMAGE = '/images/town/town_square.webp'

const buildings = computed(() => [
  { key: 'tower', label: "Tour d'ascension", subtitle: `Étage ${props.nextFloor} / 100`, to: '/tower', busyLocked: true,
    points: '735,0 770,110 790,230 845,300 850,440 600,440 600,300 650,200 700,110', label_at: [725, 330] },
  { key: 'academy', label: 'Académie des mages', subtitle: 'Apprendre des magies', to: '/town/academy', busyLocked: true,
    points: '425,30 448,70 472,110 482,160 486,480 424,480 420,398 362,398 366,160 378,110 402,70', label_at: [425, 250] },
  { key: 'guild', label: 'Guilde des guerriers', subtitle: 'Apprendre des techniques', to: '/town/guild', busyLocked: true,
    points: '38,180 100,160 292,185 296,330 300,480 170,490 165,420 38,380', label_at: [190, 360] },
  { key: 'watchtower', label: 'Vigie', subtitle: 'Renseignements ennemis', to: '/town/watchtower',
    points: '932,95 978,190 962,232 958,472 904,472 904,232 886,190', label_at: [932, 300] },
  { key: 'fortress', label: 'Forteresse', subtitle: props.siegeSubtitle, to: '/town/fortress', alert: props.siegeImminent,
    points: '1025,128 1110,128 1110,178 1208,178 1214,95 1258,148 1262,300 1186,300 1182,422 1058,422 1032,330', label_at: [1140, 240] },
  { key: 'shop', label: 'Magasin', subtitle: 'Acheter et vendre', to: '/town/shop',
    points: '230,440 278,398 382,398 420,445 422,598 232,598', label_at: [326, 520] },
  { key: 'workshop', label: 'Atelier', subtitle: 'Améliorer les défenses', to: '/town/workshop',
    points: '984,440 1030,398 1132,398 1176,440 1174,582 988,582', label_at: [1080, 510] },
  { key: 'forge', label: 'La Forge', subtitle: 'Armes, armures et travail', to: '/town/forge',
    points: '0,325 72,322 168,330 188,500 178,725 0,735', label_at: [92, 600] },
  { key: 'inn', label: 'Auberge', subtitle: 'Passer la nuit (10 or)', to: '/town/inn', busyLocked: true,
    points: '1212,330 1300,248 1440,165 1440,780 1202,780 1202,600', label_at: [1330, 420] }
].map(b => ({ ...b, disabled: !!b.busyLocked && props.busy })))

const shortcuts = computed(() => {
  const list = [
    { to: '/town/character', label: 'Fiche personnage',
      icon: 'M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z' },
    { to: '/town/inventory', label: 'Inventaire',
      icon: 'M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z' }
  ]
  if (props.hasBuildingDamage) {
    list.push({ to: '/town/buildings', label: 'Bâtiments endommagés', alert: true,
      icon: 'M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z' })
  }
  return list
})

function labelClass(b) {
  if (b.disabled) return 'bg-stone-950/70 border-stone-700 text-stone-500 cursor-not-allowed'
  if (b.alert) return 'bg-red-950/80 border-red-500 text-red-200 animate-pulse'
  if (hovered.value === b.key) return 'bg-amber-900/85 border-amber-400 text-amber-100 scale-105'
  return 'bg-stone-950/65 border-stone-600/80 text-stone-200'
}

function go(b) {
  if (b.disabled) return
  router.push(b.to)
}
</script>
