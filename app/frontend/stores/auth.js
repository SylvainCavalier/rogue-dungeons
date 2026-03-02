import { defineStore } from 'pinia'
import apiClient from '../plugins/axios'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null,
    isAuthenticated: false,
    loading: false,
    error: null,
  }),

  getters: {
    currentUser: (state) => state.user,
    isLoggedIn: (state) => state.isAuthenticated,
  },

  actions: {
    setUser(user) {
      this.user = user
      this.isAuthenticated = !!user
    },

    clearUser() {
      this.user = null
      this.isAuthenticated = false
      localStorage.removeItem('authToken')
    },

    async checkAuth() {
      const token = localStorage.getItem('authToken')
      if (!token) { this.clearUser(); return false }

      try {
        const { data } = await apiClient.get('/auth/me')
        this.setUser(data.user)
        return true
      } catch {
        this.clearUser()
        return false
      }
    },

    async login(credentials) {
      this.loading = true
      this.error = null
      try {
        const { data } = await apiClient.post('/auth/login', { user: credentials })
        if (data.token) localStorage.setItem('authToken', data.token)
        this.setUser(data.user)
        return { success: true, user: data.user }
      } catch (e) {
        const message = e.response?.data?.error || 'Connexion échouée'
        this.error = message
        return { success: false, error: message }
      } finally {
        this.loading = false
      }
    },

    async register(userData) {
      this.loading = true
      this.error = null
      try {
        const { data } = await apiClient.post('/auth/register', { user: userData })
        if (data.token) localStorage.setItem('authToken', data.token)
        this.setUser(data.user)
        return { success: true, user: data.user }
      } catch (e) {
        const message = e.response?.data?.errors?.join(', ') || e.response?.data?.error || 'Inscription échouée'
        this.error = message
        return { success: false, error: message }
      } finally {
        this.loading = false
      }
    },

    async logout() {
      try {
        await apiClient.delete('/auth/logout')
      } catch { /* ignore */ }
      this.clearUser()
    },
  },
})
