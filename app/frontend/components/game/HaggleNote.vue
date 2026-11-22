<template>
  <p v-if="haggle" class="text-xs text-stone-400 mb-4">
    Marchandage <span class="text-amber-400 font-semibold">{{ haggle.notation }}</span> :
    <template v-if="haggle.percent > 0">
      <span class="text-emerald-400">−{{ haggle.percent }} %</span> à l'achat,
      <span class="text-emerald-400">+{{ haggle.percent }} %</span> à la revente.
    </template>
    <template v-else>aucune réduction (améliorez la compétence pour négocier les prix).</template>
  </p>
</template>

<script setup>
defineProps({ haggle: { type: Object, default: null } })
</script>
