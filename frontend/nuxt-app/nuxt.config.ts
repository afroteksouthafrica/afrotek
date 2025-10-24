// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true }
})

export default defineNuxtConfig({ modules: ['@pinia/nuxt', '@nuxtjs/i18n'], css: ['~/assets/main.css'] })
