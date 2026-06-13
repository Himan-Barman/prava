/**
 * Prava Design System — Obsidian Sapphire Colors
 * Matching apps/mobile/lib/ui-system/colors.dart
 *
 * Semantic tokens for programmatic usage in React components.
 * CSS tokens in tokens.css are the canonical source; these are mirrors.
 */

export const colors = {
  light: {
    bgCanvas: '#F7F9FC',     // graphite-50
    bgSurface: '#FFFFFF',    // graphite-0
    bgElevated: '#FCFDFE',   // graphite-25
    bgSubtle: '#EFF3F7',     // graphite-100
    textPrimary: '#131B25',  // graphite-900
    textSecondary: '#4F5B6A', // graphite-600
    textTertiary: '#687485',  // graphite-500
    textDisabled: '#9AA6B4',  // graphite-400
    borderSubtle: '#E1E7EE', // graphite-200
    borderDefault: '#C9D2DD', // graphite-300
  },
  dark: {
    bgCanvas: '#080D14',      // graphite-1000
    bgSurface: '#0B1119',     // graphite-950
    bgElevated: '#1B2531',    // graphite-850
    bgSubtle: '#131B25',      // graphite-900
    textPrimary: '#F7F9FC',   // graphite-50
    textSecondary: '#C9D2DD', // graphite-300
    textTertiary: '#9AA6B4',  // graphite-400
    textDisabled: '#687485',  // graphite-500
    borderSubtle: '#1B2531',  // graphite-850
    borderDefault: '#252F3B', // graphite-800
  },
  brand: {
    primary: '#3D63F0',       // sapphire-600
    primaryHover: '#2C4FCC',  // sapphire-700
    primaryActive: '#263FA3', // sapphire-800
    muted: '#A8BEFF',         // sapphire-300
    container: '#E7EDFF',     // sapphire-100
    content: '#2C4FCC',       // sapphire-700
    // Dark mode brand
    darkPrimary: '#7E9FFF',   // sapphire-400
    darkHover: '#A8BEFF',     // sapphire-300
    darkContent: '#A8BEFF',   // sapphire-300
  },
  status: {
    success: '#137A50',
    successContainer: '#EAF8F1',
    warning: '#A85F00',
    warningContainer: '#FFF5DF',
    error: '#C23B52',
    errorContainer: '#FFF0F2',
    // Dark mode statuses
    darkSuccess: '#64DDA5',
    darkWarning: '#F6C564',
    darkError: '#FF8394',
  },
} as const;

export type ThemeMode = 'light' | 'dark';

export function getThemeColors(mode: ThemeMode) {
  return mode === 'dark' ? colors.dark : colors.light;
}
