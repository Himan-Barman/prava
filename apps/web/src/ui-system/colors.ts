/**
 * Prava Design System — Colors
 * Matching apps/mobile/lib/ui-system/colors.dart
 */

export const colors = {
  light: {
    bgMain: '#FFFFFF',
    bgSurface: '#F6F6F6',
    bgElevated: '#FFFFFF',
    textPrimary: '#0C0C0C',
    textSecondary: '#4A4A4A',
    textTertiary: '#8A8A8A',
    borderSubtle: '#E5E5E5',
  },
  dark: {
    bgMain: '#0C0C0C',
    bgSurface: '#1D1D1D',
    bgElevated: '#292929',
    textPrimary: '#F2F2F2',
    textSecondary: '#B3B3B3',
    textTertiary: '#7A7A7A',
    borderSubtle: '#2E2E2E',
  },
  brand: {
    accentPrimary: '#5B8CFF',
    accentMuted: '#8FA9FF',
    success: '#3CCB7F',
    warning: '#F4C430',
    error: '#E5533D',
  },
} as const;

export type ThemeMode = 'light' | 'dark';

export function getThemeColors(mode: ThemeMode) {
  return mode === 'dark' ? colors.dark : colors.light;
}
