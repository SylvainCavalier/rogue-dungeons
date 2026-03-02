import { createApp } from 'vue'
import { createPinia } from 'pinia'
import router from '../router'
import App from '../components/App.vue'
import '../styles/application.css'
import '../plugins/axios'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)
app.use(router)
app.mount('#app')
