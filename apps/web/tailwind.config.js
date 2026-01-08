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
        // Light mode
        'prava-light': {
          bg: '#FFFFFF',
          surface: '#F6F6F6',
          elevated: '#FFFFFF',
          'text-primary': '#0C0C0C',
          'text-secondary': '#4A4A4A',
          'text-tertiary': '#8A8A8A',
          border: '#E5E5E5',
        },
        // Dark mode
        'prava-dark': {
          bg: '#0C0C0C',
          surface: '#1D1D1D',
          elevated: '#292929',
          'text-primary': '#F2F2F2',
          'text-secondary': '#B3B3B3',
          'text-tertiary': '#7A7A7A',
          border: '#2E2E2E',
        },
        // Brand colors
        'prava': {
          accent: '#5B8CFF',
          'accent-muted': '#8FA9FF',
          success: '#3CCB7F',
          warning: '#F4C430',
          error: '#E5533D',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        display: ['Inter', 'system-ui', 'sans-serif'],
      },
      fontSize: {
        'h1': ['28px', { lineHeight: '1.2', letterSpacing: '-0.5px', fontWeight: '700' }],
        'h2': ['22px', { lineHeight: '1.3', letterSpacing: '-0.3px', fontWeight: '600' }],
        'h3': ['18px', { lineHeight: '1.4', fontWeight: '600' }],
        'body-lg': ['16px', { lineHeight: '1.4', fontWeight: '400' }],
        'body': ['14px', { lineHeight: '1.4', fontWeight: '400' }],
        'body-sm': ['12px', { lineHeight: '1.3', fontWeight: '400' }],
        'label': ['12px', { lineHeight: '1.4', letterSpacing: '0.2px', fontWeight: '500' }],
        'caption': ['11px', { lineHeight: '1.3', letterSpacing: '0.2px', fontWeight: '400' }],
        'button': ['14px', { lineHeight: '1.4', letterSpacing: '0.3px', fontWeight: '600' }],
      },
      borderRadius: {
        'prava': '16px',
        'prava-lg': '24px',
        'prava-sm': '14px',
      },
      boxShadow: {
        'prava': '0 14px 40px rgba(15, 20, 40, 0.08)',
        'prava-dark': '0 14px 40px rgba(0, 0, 0, 0.55)',
        'prava-soft': '0 12px 30px rgba(15, 20, 40, 0.06)',
        'prava-glow': '0 10px 24px rgba(91, 140, 255, 0.3)',
      },
      backdropBlur: {
        'prava': '18px',
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
