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
    path: '/tower',
    name: 'Tower',
    component: () => import('../pages/Tower.vue'),
  },
  {
    path: '/combat',
    name: 'Combat',
    component: () => import('../pages/Combat.vue'),
  },
]
