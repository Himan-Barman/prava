/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // Light mode — Graphite neutral scale
        'prava-light': {
          bg: '#F7F9FC',         // graphite-50
          surface: '#EFF3F7',    // graphite-100
          elevated: '#FCFDFE',   // graphite-25
          'text-primary': '#131B25',   // graphite-900
          'text-secondary': '#4F5B6A', // graphite-600
          'text-tertiary': '#687485',  // graphite-500
          border: '#E1E7EE',     // graphite-200
        },
        // Dark mode — Graphite neutral scale
        'prava-dark': {
          bg: '#080D14',          // graphite-1000
          surface: '#131B25',     // graphite-900
          elevated: '#1B2531',    // graphite-850
          'text-primary': '#F7F9FC',   // graphite-50
          'text-secondary': '#C9D2DD', // graphite-300
          'text-tertiary': '#9AA6B4',  // graphite-400
          border: '#1B2531',      // graphite-850
        },
        // Brand — Sapphire scale
        'prava': {
          accent: '#3D63F0',       // sapphire-600 (light primary)
          'accent-muted': '#A8BEFF', // sapphire-300
          success: '#137A50',
          warning: '#A85F00',
          error: '#C23B52',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        display: ['Inter', 'system-ui', 'sans-serif'],
      },
      fontSize: {
        'h1': ['24px', { lineHeight: '1.2', letterSpacing: '-0.3px', fontWeight: '800' }],
        'h2': ['18px', { lineHeight: '1.3', letterSpacing: '-0.2px', fontWeight: '700' }],
        'h3': ['15px', { lineHeight: '1.35', fontWeight: '600' }],
        'body-lg': ['15px', { lineHeight: '1.45', fontWeight: '400' }],
        'body': ['14px', { lineHeight: '1.45', fontWeight: '400' }],
        'body-sm': ['13px', { lineHeight: '1.4', fontWeight: '400' }],
        'label': ['11px', { lineHeight: '1.4', letterSpacing: '0.06em', fontWeight: '600' }],
        'caption': ['12px', { lineHeight: '1.35', fontWeight: '400' }],
        'button': ['13px', { lineHeight: '1.35', fontWeight: '600' }],
      },
      borderRadius: {
        'prava': '14px',
        'prava-lg': '18px',
        'prava-sm': '10px',
        'prava-xs': '8px',
      },
      boxShadow: {
        'prava': '0 4px 12px rgba(11, 17, 25, 0.08)',
        'prava-dark': '0 4px 12px rgba(0, 0, 0, 0.32)',
        'prava-soft': '0 1px 3px rgba(11, 17, 25, 0.06)',
        'prava-lg': '0 8px 24px rgba(11, 17, 25, 0.10)',
      },
      backdropBlur: {
        'prava': '20px',
      },
      animation: {
        'fade-up': 'fadeUp 0.4s ease-out',
        'fade-in': 'fadeIn 0.3s ease-out',
        'slide-up': 'slideUp 0.5s ease-out',
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
      },
      keyframes: {
        fadeUp: {
          '0%': { opacity: '0', transform: 'translateY(8px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(16px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
      },
      screens: {
        'xs': '375px',
        'mobile': { 'max': '500px' },
        'tablet': { 'min': '501px', 'max': '1024px' },
        'laptop': { 'min': '1025px', 'max': '1440px' },
        'desktop': { 'min': '1441px' },
      },
    },
  },
  plugins: [],
}
