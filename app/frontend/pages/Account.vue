<template>
  <div class="min-h-screen bg-stone-950">
    <StatusBar v-if="gameStore.character" />

    <div class="max-w-2xl mx-auto px-4 py-8">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-3xl font-bold text-amber-400">Mon compte</h1>
        <router-link to="/town" class="text-stone-400 hover:text-amber-400 text-sm">
          ← Retour
        </router-link>
      </div>

      <div class="bg-stone-900 border border-stone-800 rounded-xl p-6 mb-6">
        <p class="text-stone-400 text-sm">Email</p>
        <p class="text-stone-200 font-medium">{{ authStore.user?.email }}</p>
      </div>

      <!-- Change password -->
      <div class="bg-stone-900 border border-stone-800 rounded-xl p-6 mb-6">
        <h2 class="text-xl font-semibold text-amber-300 mb-4">Changer le mot de passe</h2>
        <form @submit.prevent="submitPassword" class="space-y-4">
          <div>
            <label class="block text-sm text-stone-400 mb-1">Mot de passe actuel</label>
            <input v-model="pwd.current" type="password" required autocomplete="current-password"
              class="w-full bg-stone-800 border border-stone-700 rounded-lg px-4 py-2.5 text-stone-200 focus:border-amber-500 focus:outline-none" />
          </div>
          <div>
            <label class="block text-sm text-stone-400 mb-1">Nouveau mot de passe</label>
            <input v-model="pwd.next" type="password" required minlength="6" autocomplete="new-password"
              class="w-full bg-stone-800 border border-stone-700 rounded-lg px-4 py-2.5 text-stone-200 focus:border-amber-500 focus:outline-none" />
          </div>
          <div>
            <label class="block text-sm text-stone-400 mb-1">Confirmation</label>
            <input v-model="pwd.confirm" type="password" required minlength="6" autocomplete="new-password"
              class="w-full bg-stone-800 border border-stone-700 rounded-lg px-4 py-2.5 text-stone-200 focus:border-amber-500 focus:outline-none" />
          </div>

          <p v-if="pwdMessage" :class="pwdSuccess ? 'text-green-400' : 'text-red-400'" class="text-sm">
            {{ pwdMessage }}
          </p>

          <button type="submit" :disabled="pwdLoading"
            class="bg-amber-700 hover:bg-amber-600 text-white font-semibold py-2.5 px-5 rounded-lg transition disabled:opacity-50">
            {{ pwdLoading ? 'Mise à jour...' : 'Mettre à jour' }}
          </button>
        </form>
      </div>

      <!-- Reset character -->
      <div class="bg-stone-900 border border-red-900/50 rounded-xl p-6 mb-6">
        <h2 class="text-xl font-semibold text-red-400 mb-2">Réinitialiser le personnage</h2>
        <p class="text-stone-400 text-sm mb-4">
          Supprime définitivement votre personnage, son équipement, ses compétences et sa progression.
          Vous pourrez en créer un nouveau ensuite.
        </p>

        <div v-if="!confirmingReset">
          <button v-if="gameStore.character" @click="confirmingReset = true"
            class="bg-red-800 hover:bg-red-700 text-white font-semibold py-2.5 px-5 rounded-lg transition">
            Réinitialiser
          </button>
          <p v-else class="text-stone-500 text-sm italic">Aucun personnage à réinitialiser.</p>
        </div>

        <div v-else class="space-y-3">
          <p class="text-red-300 text-sm font-medium">
            Êtes-vous sûr ? Cette action est irréversible.
          </p>
          <div class="flex gap-3">
            <button @click="resetCharacter" :disabled="resetLoading"
              class="bg-red-700 hover:bg-red-600 text-white font-semibold py-2.5 px-5 rounded-lg transition disabled:opacity-50">
              {{ resetLoading ? 'Suppression...' : 'Oui, supprimer' }}
            </button>
            <button @click="confirmingReset = false" :disabled="resetLoading"
              class="bg-stone-700 hover:bg-stone-600 text-stone-200 font-semibold py-2.5 px-5 rounded-lg transition">
              Annuler
            </button>
          </div>
        </div>
      </div>

      <!-- Logout -->
      <div class="bg-stone-900 border border-stone-800 rounded-xl p-6">
        <h2 class="text-xl font-semibold text-stone-300 mb-2">Déconnexion</h2>
        <button @click="logout"
          class="bg-stone-700 hover:bg-stone-600 text-stone-100 font-semibold py-2.5 px-5 rounded-lg transition">
          Se déconnecter
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useGameStore } from '../stores/game'
import apiClient from '../plugins/axios'
import StatusBar from '../components/game/StatusBar.vue'

const router = useRouter()
const authStore = useAuthStore()
const gameStore = useGameStore()

const pwd = reactive({ current: '', next: '', confirm: '' })
const pwdLoading = ref(false)
const pwdMessage = ref('')
const pwdSuccess = ref(false)

const confirmingReset = ref(false)
const resetLoading = ref(false)

async function submitPassword() {
  pwdLoading.value = true
  pwdMessage.value = ''
  try {
    const { data } = await apiClient.patch('/auth/password', {
      user: {
        current_password: pwd.current,
        password: pwd.next,
        password_confirmation: pwd.confirm,
      },
    })
    pwdSuccess.value = true
    pwdMessage.value = data.message || 'Mot de passe mis à jour'
    pwd.current = ''
    pwd.next = ''
    pwd.confirm = ''
  } catch (e) {
    pwdSuccess.value = false
    pwdMessage.value = e.response?.data?.errors?.join(', ')
      || e.response?.data?.error
      || 'Erreur lors de la mise à jour'
  } finally {
    pwdLoading.value = false
  }
}

async function resetCharacter() {
  resetLoading.value = true
  try {
    await apiClient.delete('/character')
    gameStore.character = null
    gameStore.skills = []
    gameStore.inventory = []
    gameStore.equipment = {}
    gameStore.townStatus = null
    if (authStore.user) authStore.user.has_character = false
    router.push('/create')
  } catch (e) {
    gameStore.notify(e.response?.data?.error || 'Erreur', 'error')
    resetLoading.value = false
    confirmingReset.value = false
  }
}

async function logout() {
  await authStore.logout()
  router.push('/login')
}
</script>
