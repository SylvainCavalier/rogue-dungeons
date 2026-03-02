<template>
  <div class="min-h-screen bg-stone-950 flex items-center justify-center px-4">
    <div class="bg-stone-900 border border-amber-900/50 rounded-xl p-8 w-full max-w-md shadow-2xl">
      <h1 class="text-3xl font-bold text-amber-400 text-center mb-2">Rogue Dungeons</h1>
      <p class="text-stone-500 text-center mb-8">Entrez dans la tour</p>

      <form @submit.prevent="login" class="space-y-4">
        <div>
          <label class="block text-sm text-stone-400 mb-1">Email</label>
          <input v-model="email" type="email" required
            class="w-full bg-stone-800 border border-stone-700 rounded-lg px-4 py-2.5 text-stone-200 focus:border-amber-500 focus:outline-none" />
        </div>
        <div>
          <label class="block text-sm text-stone-400 mb-1">Mot de passe</label>
          <input v-model="password" type="password" required
            class="w-full bg-stone-800 border border-stone-700 rounded-lg px-4 py-2.5 text-stone-200 focus:border-amber-500 focus:outline-none" />
        </div>

        <p v-if="error" class="text-red-400 text-sm">{{ error }}</p>

        <button type="submit" :disabled="loading"
          class="w-full bg-amber-700 hover:bg-amber-600 text-white font-semibold py-2.5 rounded-lg transition disabled:opacity-50">
          {{ loading ? 'Connexion...' : 'Se connecter' }}
        </button>
      </form>

      <p class="text-stone-500 text-sm text-center mt-6">
        Pas de compte ?
        <router-link to="/register" class="text-amber-400 hover:text-amber-300">Créer un compte</router-link>
      </p>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const email = ref('')
const password = ref('')
const error = ref('')
const loading = ref(false)

async function login() {
  loading.value = true
  error.value = ''
  try {
    const result = await authStore.login({ email: email.value, password: password.value })
    if (result.success) {
      router.push(result.user.has_character ? '/town' : '/create')
    } else {
      error.value = result.error
    }
  } catch (e) {
    error.value = 'Erreur de connexion'
  } finally {
    loading.value = false
  }
}
</script>
