import { createRouter, createWebHistory } from 'vue-router'
import routes from './routes'

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach((to, from, next) => {
  const token = localStorage.getItem('authToken')
  const isPublic = to.meta?.public

  if (!isPublic && !token) {
    next('/login')
  } else if (isPublic && token && (to.name === 'Login' || to.name === 'Register')) {
    next('/town')
  } else {
    next()
  }
})

export default router
