<template>
  <div v-if="allies?.length" class="mt-3 pt-3 border-t border-stone-800 space-y-2">
    <div v-for="(ally, i) in allies" :key="`${ally.key}-${i}`" class="flex gap-3 items-center">
      <!-- Raised undead reuse the monster portrait with a ghastly green tint -->
      <div :class="ally.undead ? 'sepia hue-rotate-60 saturate-150' : ''">
        <MonsterPortrait :monster-key="ally.key" :name="ally.name" :hp="ally.hp" :alive="ally.alive"
          :image-dir="ally.image_dir || 'summons'" size="md" />
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex justify-between items-center mb-1">
          <span class="text-sm" :class="ally.alive ? (ally.undead ? 'text-lime-300' : ally.defender ? 'text-sky-300' : 'text-fuchsia-300') : 'text-stone-600 line-through'">
            {{ ally.name }}
            <span class="text-[10px] text-stone-500 ml-1"
              title="Part des coups ennemis qui visent la créature plutôt que vous">
              {{ ally.undead ? 'Mort-vivant' : ally.defender ? (ally.role === 'heal' ? 'Défenseur soigneur' : 'Défenseur') : ally.role === 'heal' ? 'Soutien' : 'Allié' }} · attire {{ ally.taunt }}
            </span>
          </span>
          <span class="text-xs" :class="ally.alive ? 'text-stone-400' : 'text-stone-600'">
            {{ ally.hp }}/{{ ally.max_hp }}
          </span>
        </div>
        <div v-if="ally.alive" class="w-full bg-stone-800 rounded-full h-2">
          <div class="h-2 rounded-full transition-all duration-500" :class="ally.defender ? 'bg-sky-600' : 'bg-fuchsia-600'"
            :style="{ width: (ally.hp / ally.max_hp * 100) + '%' }"></div>
        </div>
        <p v-else class="text-[11px] text-stone-600">{{ ally.defender ? 'Tombé au combat' : 'Détruit' }}</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import MonsterPortrait from './MonsterPortrait.vue'

// Allies shown under the player card: summoned creatures (Invocation school),
// raised undead and siege defenders.
defineProps({
  allies: { type: Array, default: () => [] }
})
</script>
