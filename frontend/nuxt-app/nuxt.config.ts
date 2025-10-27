// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  // ✅ Latest Nitro compatibility date
  compatibilityDate: '2025-10-24',

  // ✅ Enable DevTools
  devtools: { enabled: true },

  // ✅ Nuxt modules
  modules: [
    '@pinia/nuxt',
    '@nuxtjs/i18n'
  ],

  // Global CSS is imported from `app/app.vue` to avoid alias resolution issues
  css: [],

  // ✅ Basic i18n setup to remove warnings
  i18n: {
    defaultLocale: 'en',
    locales: [
      { code: 'en', name: 'English' }
    ]
  }
})
