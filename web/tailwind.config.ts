import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#1565C0',
          dark: '#0D47A1',
          light: '#42A5F5',
          50: '#E3F2FD',
          100: '#BBDEFB',
          200: '#90CAF9',
          300: '#64B5F6',
          400: '#42A5F5',
          500: '#1565C0',
          600: '#0D47A1',
          700: '#0A3780',
        },
        accent: {
          DEFAULT: '#FF6B35',
          hover: '#E55A25',
          light: '#FF8F65',
          50: '#FFF3ED',
        },
        success: { DEFAULT: '#10B981', light: '#D1FAE5' },
        warning: { DEFAULT: '#F59E0B', light: '#FEF3C7' },
        danger:  { DEFAULT: '#EF4444', light: '#FEE2E2' },
        dark: '#0F1923',
        soft: '#F5F7FA',
        muted: '#64748B',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      borderRadius: {
        '2xl': '1rem',
        '3xl': '1.5rem',
      },
      boxShadow: {
        'soft': '0 2px 15px rgba(0,0,0,0.05)',
        'medium': '0 4px 30px rgba(0,0,0,0.08)',
        'large': '0 10px 50px rgba(0,0,0,0.12)',
        'blue': '0 4px 30px rgba(21,101,192,0.2)',
        'orange': '0 4px 30px rgba(255,107,53,0.2)',
      },
    },
  },
  plugins: [],
};

export default config;
