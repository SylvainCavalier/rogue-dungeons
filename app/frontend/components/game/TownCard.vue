<template>
  <component :is="to ? 'router-link' : 'div'"
    :to="to || undefined"
    class="group relative overflow-hidden rounded-xl transition-all duration-300 cursor-pointer animate-fade-in-up"
    :class="[
      disabled ? 'opacity-40 pointer-events-none' : '',
      variant === 'danger' ? 'card-danger' : 'card-hover',
      `stagger-${delay}`
    ]"
    @click="!to && !disabled && $emit('click')">

    <!-- Background image -->
    <div v-if="image" class="absolute inset-0">
      <img :src="image" :alt="label" loading="lazy"
        class="w-full h-full object-cover opacity-20 group-hover:opacity-30 transition-opacity duration-500 group-hover:scale-105 transform" />
      <div class="absolute inset-0 bg-gradient-to-t from-stone-900 via-stone-900/80 to-stone-900/40"></div>
    </div>

    <!-- Content -->
    <div class="relative p-5">
      <div class="mb-3" :class="iconColor">
        <slot name="icon" />
      </div>
      <h3 class="font-semibold text-sm leading-tight"
        :class="variant === 'danger' ? 'text-red-400 group-hover:text-red-300' : 'text-amber-400 group-hover:text-amber-300'">
        {{ label }}
      </h3>
      <p class="text-stone-500 text-xs mt-1 leading-snug">{{ subtitle }}</p>
    </div>
  </component>
</template>

<script setup>
defineProps({
  to: { type: String, default: '' },
  label: { type: String, required: true },
  subtitle: { type: String, default: '' },
  iconColor: { type: String, default: 'text-amber-400' },
  image: { type: String, default: '' },
  variant: { type: String, default: 'default' },
  disabled: { type: Boolean, default: false },
  delay: { type: Number, default: 0 },
})

defineEmits(['click'])
</script>
