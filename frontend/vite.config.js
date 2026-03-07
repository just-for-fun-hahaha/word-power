import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const buildTime = new Date().toISOString()

  return {
    base: env.VITE_BASE || '/',
    define: {
      __APP_BUILD_TIME__: JSON.stringify(buildTime),
    },
    plugins: [vue()],
    server: {
      port: 3000,
    },
  }
})
