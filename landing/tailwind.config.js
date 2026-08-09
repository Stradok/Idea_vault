/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        background: '#05050a',
        foreground: '#f5f5f7',
        card: '#0d0d16',
        border: 'rgba(255,255,255,0.08)',
        muted: {
          DEFAULT: 'rgba(255,255,255,0.5)',
          foreground: 'rgba(255,255,255,0.5)',
        },
        primary: {
          DEFAULT: '#7c5cff',
          foreground: '#ffffff',
        },
      },
    },
  },
  plugins: [],
};
