export default [
  {
    path: '/',
    redirect: '/login',
  },
  {
    path: '/login',
    name: 'Login',
    component: () => import('../pages/Login.vue'),
    meta: { public: true },
  },
  {
    path: '/register',
    name: 'Register',
    component: () => import('../pages/Register.vue'),
    meta: { public: true },
  },
  {
    path: '/create',
    name: 'CharacterCreation',
    component: () => import('../pages/CharacterCreation.vue'),
  },
  {
    path: '/account',
    name: 'Account',
    component: () => import('../pages/Account.vue'),
  },
  {
    path: '/town',
    name: 'Town',
    component: () => import('../pages/Town.vue'),
  },
  {
    path: '/town/character',
    name: 'CharacterSheet',
    component: () => import('../pages/CharacterSheet.vue'),
  },
  {
    path: '/town/inventory',
    name: 'Inventory',
    component: () => import('../pages/Inventory.vue'),
  },
  {
    path: '/town/shop',
    name: 'Shop',
    component: () => import('../pages/Shop.vue'),
  },
  {
    path: '/town/forge',
    name: 'Forge',
    component: () => import('../pages/Forge.vue'),
  },
  {
    path: '/town/inn',
    name: 'Inn',
    component: () => import('../pages/Inn.vue'),
  },
  {
    path: '/town/academy',
    name: 'Academy',
    component: () => import('../pages/Academy.vue'),
  },
  {
    path: '/town/guild',
    name: 'Guild',
    component: () => import('../pages/Guild.vue'),
  },
  {
    path: '/town/fortress',
    name: 'Fortress',
    component: () => import('../pages/Fortress.vue'),
  },
  {
    path: '/town/watchtower',
    name: 'Watchtower',
    component: () => import('../pages/Watchtower.vue'),
  },
  {
    path: '/town/workshop',
    name: 'Workshop',
    component: () => import('../pages/Workshop.vue'),
  },
  {
    path: '/town/buildings',
    name: 'Buildings',
    component: () => import('../pages/Buildings.vue'),
  },
  {
    path: '/tower',
    name: 'Tower',
    component: () => import('../pages/Tower.vue'),
  },
  {
    path: '/siege',
    name: 'SiegeCombat',
    component: () => import('../pages/SiegeCombat.vue'),
  },
  {
    path: '/combat',
    name: 'Combat',
    component: () => import('../pages/Combat.vue'),
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'NotFound',
    component: () => import('../pages/NotFound.vue'),
  },
]
