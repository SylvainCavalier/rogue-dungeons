import { defineStore } from 'pinia'
import apiClient from '../plugins/axios'

export const useGameStore = defineStore('game', {
  state: () => ({
    character: null,
    skills: [],
    inventory: [],
    equipment: {},
    shop: { equipment: [], items: [] },
    availableMagics: {},
    availableTechniques: {},
    townStatus: null,
    towerInfo: null,
    combatState: null,
    loading: false,
    notification: null,
  }),

  getters: {
    hasCharacter: (state) => !!state.character,
    isBusy: (state) => state.character?.activity && state.character?.activity_days_left > 0,
    inCombat: (state) => state.character?.in_combat,
    currentDate: (state) => state.character?.date || '',
    hp: (state) => state.character ? { current: state.character.current_hp, max: state.character.max_hp } : null,
    mana: (state) => state.character ? { current: state.character.current_mana, max: state.character.max_mana } : null,
    skillsByCategory: (state) => {
      const grouped = {}
      state.skills.forEach(s => {
        if (!grouped[s.category]) grouped[s.category] = []
        grouped[s.category].push(s)
      })
      return grouped
    },
    inventoryItems: (state) => state.inventory.filter(i => !i.equipped),
    equippedItems: (state) => state.equipment,
  },

  actions: {
    notify(message, type = 'info') {
      this.notification = { message, type, id: Date.now() }
      setTimeout(() => { this.notification = null }, 4000)
    },

    // --- Character ---
    async fetchCharacter() {
      this.loading = true
      try {
        const { data } = await apiClient.get('/character')
        this.character = data
        this.skills = data.skills || []
        return data
      } catch (e) {
        if (e.response?.status === 404) this.character = null
        throw e
      } finally { this.loading = false }
    },

    async createCharacter(charData) {
      this.loading = true
      try {
        const { data } = await apiClient.post('/character', { character: charData })
        this.character = data
        this.skills = data.skills || []
        this.notify(`${data.name} a été créé(e) !`, 'success')
        return data
      } finally { this.loading = false }
    },

    // --- Skills ---
    async fetchSkills() {
      const { data } = await apiClient.get('/skills')
      this.skills = data.skills
      if (this.character) this.character.xp = data.available_xp
      return data
    },

    async upgradeSkill(skillId) {
      try {
        const { data } = await apiClient.patch(`/skills/${skillId}/upgrade`)
        if (this.character) this.character.xp = data.xp_remaining
        const idx = this.skills.findIndex(s => s.id === skillId)
        if (idx !== -1) this.skills[idx] = data.skill
        this.notify(data.message, 'success')
        return data
      } catch (e) {
        this.notify(e.response?.data?.error || 'Erreur', 'error')
        throw e
      }
    },

    // --- Inventory ---
    async fetchInventory() {
      const { data } = await apiClient.get('/inventory')
      this.inventory = data.items
      this.equipment = data.equipment
      return data
    },

    async equipItem(itemId) {
      try {
        const { data } = await apiClient.post(`/inventory/${itemId}/equip`)
        this.equipment = data.equipment
        this.notify(data.message, 'success')
        await this.fetchInventory()
        return data
      } catch (e) {
        this.notify(e.response?.data?.error || 'Erreur', 'error')
        throw e
      }
    },

    async unequipItem(itemId) {
      try {
        const { data } = await apiClient.post(`/inventory/${itemId}/unequip`)
        this.equipment = data.equipment
        this.notify(data.message, 'success')
        await this.fetchInventory()
        return data
      } catch (e) {
        this.notify(e.response?.data?.error || 'Erreur', 'error')
        throw e
      }
    },

    async useItem(itemId) {
      try {
        const { data } = await apiClient.post(`/inventory/${itemId}/use`)
        Object.assign(this.character, data.character)
        this.notify(data.message, 'success')
        await this.fetchInventory()
        return data
      } catch (e) {
        this.notify(e.response?.data?.error || 'Erreur', 'error')
        throw e
      }
    },

    // --- Shop ---
    async fetchShop() {
      const { data } = await apiClient.get('/shop')
      this.shop = data
      return data
    },

    async buyItem(itemKey, itemType, quantity = 1) {
      try {
        const { data } = await apiClient.post('/shop/buy', { item_key: itemKey, item_type: itemType, quantity })
        if (this.character) this.character.gold = data.gold
        this.notify(data.message, 'success')
        await this.fetchInventory()
        return data
      } catch (e) {
        this.notify(e.response?.data?.error || 'Erreur', 'error')
        throw e
      }
    },

    async sellItem(itemId, quantity = 1) {
      try {
        const { data } = await apiClient.post('/shop/sell', { id: itemId, quantity })
        if (this.character) this.character.gold = data.gold
        this.notify(data.message, 'success')
        await this.fetchInventory()
        return data
      } catch (e) {
        this.notify(e.response?.data?.error || 'Erreur', 'error')
        throw e
      }
    },

    // --- Town ---
    async fetchTownStatus() {
      const { data } = await apiClient.get('/town/status')
      this.townStatus = data
      if (this.character) {
        Object.assign(this.character, {
          current_hp: data.current_hp, max_hp: data.max_hp,
          current_mana: data.current_mana, max_mana: data.max_mana,
          gold: data.gold, xp: data.xp, current_floor: data.current_floor,
          activity: data.activity, activity_days_left: data.activity_days_left,
          activity_data: data.activity_data, date: data.date,
        })
      }
      return data
    },

    async work() {
      try {
        const { data } = await apiClient.post('/town/work')
        if (this.character) {
          this.character.gold = data.gold
          this.character.date = data.date
        }
        this.notify(data.message, 'success')
        await this.fetchTownStatus()
        return data
      } catch (e) {
        this.notify(e.response?.data?.error || 'Erreur', 'error')
        throw e
      }
    },

    async rest() {
      try {
        const { data } = await apiClient.post('/town/rest')
        if (this.character) {
          this.character.current_hp = data.current_hp
          this.character.max_hp = data.max_hp
          this.character.current_mana = data.current_mana
          this.character.max_mana = data.max_mana
          this.character.date = data.date
        }
        this.notify(data.message, 'success')
        return data
      } catch (e) {
        this.notify(e.response?.data?.error || 'Erreur', 'error')
        throw e
      }
    },

    async startAcademy(magicKey) {
      try {
        const { data } = await apiClient.post('/town/academy/start', { magic_key: magicKey })
        this.notify(data.message, 'success')
        await this.fetchTownStatus()
        return data
      } catch (e) {
        this.notify(e.response?.data?.error || 'Erreur', 'error')
        throw e
      }
    },

    async advanceAcademy() {
      try {
        const { data } = await apiClient.post('/town/academy/advance')
        this.notify(data.message, data.completed ? 'success' : 'info')
        await this.fetchTownStatus()
        if (data.completed) await this.fetchCharacter()
        return data
      } catch (e) {
        this.notify(e.response?.data?.error || 'Erreur', 'error')
        throw e
      }
    },

    async startGuild(techniqueKey) {
      try {
        const { data } = await apiClient.post('/town/guild/start', { technique_key: techniqueKey })
        this.notify(data.message, 'success')
        await this.fetchTownStatus()
        return data
      } catch (e) {
        this.notify(e.response?.data?.error || 'Erreur', 'error')
        throw e
      }
    },

    async advanceGuild() {
      try {
        const { data } = await apiClient.post('/town/guild/advance')
        this.notify(data.message, data.completed ? 'success' : 'info')
        await this.fetchTownStatus()
        if (data.completed) await this.fetchCharacter()
        return data
      } catch (e) {
        this.notify(e.response?.data?.error || 'Erreur', 'error')
        throw e
      }
    },

    async fetchAvailableMagics() {
      const { data } = await apiClient.get('/town/available_magics')
      this.availableMagics = data.magics
      return data
    },

    async fetchAvailableTechniques() {
      const { data } = await apiClient.get('/town/available_techniques')
      this.availableTechniques = data.techniques
      return data
    },

    // --- Tower & Combat ---
    async fetchTowerInfo() {
      const { data } = await apiClient.get('/tower')
      this.towerInfo = data
      return data
    },

    async enterTower() {
      try {
        const { data } = await apiClient.post('/tower/enter')
        this.combatState = data
        return data
      } catch (e) {
        this.notify(e.response?.data?.error || 'Erreur', 'error')
        throw e
      }
    },

    async fetchCombatState() {
      try {
        const { data } = await apiClient.get('/tower/combat')
        this.combatState = data
        return data
      } catch (e) {
        this.combatState = null
        throw e
      }
    },

    async combatAction(actionType, params = {}) {
      try {
        const { data } = await apiClient.post('/tower/combat/action', {
          action_type: actionType,
          ...params
        })
        this.combatState = data
        if (data.status === 'victory') {
          this.notify(`Victoire ! +${data.rewards?.xp || 0} XP, +${data.rewards?.gold || 0} or`, 'success')
          await this.fetchCharacter()
        } else if (data.status === 'defeat') {
          this.notify('Défaite... Vous revenez en ville.', 'error')
          await this.fetchCharacter()
        }
        return data
      } catch (e) {
        this.notify(e.response?.data?.error || 'Erreur', 'error')
        throw e
      }
    },

    async fleeCombat() {
      try {
        const { data } = await apiClient.post('/tower/flee')
        this.combatState = data
        if (data.status === 'fled') {
          this.notify('Fuite réussie !', 'info')
          await this.fetchCharacter()
        } else if (data.status === 'defeat') {
          this.notify('Défaite...', 'error')
          await this.fetchCharacter()
        }
        return data
      } catch (e) {
        this.notify(e.response?.data?.error || 'Erreur', 'error')
        throw e
      }
    },
  }
})
