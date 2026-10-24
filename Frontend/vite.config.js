import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const projectRoot = path.resolve(fileURLToPath(new URL('..', import.meta.url)))

export default defineConfig(({ mode }) => {
  // The backend also reads the project-root .env file for PORT. Keep the dev
  // proxy pointed at that same port, with an explicit override if needed.
  const env = loadEnv(mode, projectRoot, '')
  const apiTarget = env.VITE_API_PROXY_TARGET || `http://localhost:${env.PORT || '5000'}`

  return {
    envDir: projectRoot,
    plugins: [react()],
    server: {
      port: 5173,
      proxy: {
        '/api': {
          target: apiTarget,
          changeOrigin: true,
        },
      },
    },
  }
})
