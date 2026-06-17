import type { LucideIcon } from 'lucide-react';
import {
  Accessibility,
  AtSign,
  Bell,
  Bot,
  CircleUserRound,
  Database,
  Eye,
  FileText,
  Flag,
  HardDrive,
  HelpCircle,
  Languages,
  LockKeyhole,
  MessageCircle,
  Palette,
  Shield,
  ShieldOff,
  Smartphone,
  Sparkles,
  UserX,
  Users,
} from 'lucide-react';

import type { SettingsCategoryKey, SettingsState } from '../../services/settings-service';

export type SettingsPageKey =
  | SettingsCategoryKey
  | 'account'
  | 'handle'
  | 'devices'
  | 'blocked'
  | 'muted'
  | 'language'
  | 'support'
  | 'legal'
  | 'danger';

export interface SettingsMeta {
  key: SettingsPageKey;
  title: string;
  subtitle: string;
  path: string;
  icon: LucideIcon;
  keywords: string;
  accent: string;
}

export const featureCategoryKeys: SettingsCategoryKey[] = [
  'profile_visibility',
  'privacy',
  'security',
  'notifications',
  'chats',
  'feed',
  'friends',
  'appearance',
  'accessibility',
  'data_storage',
  'ai_personalization',
  'creator',
];

export const settingsGroups: Array<{ title: string; items: SettingsMeta[] }> = [
  {
    title: 'Account center',
    items: [
      {
        key: 'account',
        title: 'Account information',
        subtitle: 'Name, email, phone, country, and account details',
        path: '/settings/account',
        icon: CircleUserRound,
        accent: 'var(--p-brand)',
        keywords: 'account email phone name details profile',
      },
      {
        key: 'handle',
        title: 'Username',
        subtitle: 'Search, verify, and change your Prava username',
        path: '/settings/handle',
        icon: AtSign,
        accent: 'var(--p-brand)',
        keywords: 'username handle prava id change password verification',
      },
      {
        key: 'profile_visibility',
        title: 'Profile & visibility',
        subtitle: 'Private account, posts, media, followers, and search visibility',
        path: '/settings/profile-visibility',
        icon: Eye,
        accent: 'var(--p-info)',
        keywords: 'private profile visibility posts media followers following public',
      },
    ],
  },
  {
    title: 'Privacy and safety',
    items: [
      {
        key: 'privacy',
        title: 'Privacy',
        subtitle: 'Activity status, mentions, tags, messages, and filters',
        path: '/settings/privacy',
        icon: Shield,
        accent: 'var(--p-success)',
        keywords: 'privacy activity read receipts mentions tags sensitive content messages',
      },
      {
        key: 'security',
        title: 'Security',
        subtitle: 'Password, two-factor, login alerts, lock, and sessions',
        path: '/settings/security',
        icon: LockKeyhole,
        accent: 'var(--p-warning)',
        keywords: 'security password two factor login app lock sessions devices',
      },
      {
        key: 'blocked',
        title: 'Blocked accounts',
        subtitle: 'Review people who cannot interact with you',
        path: '/settings/blocked',
        icon: UserX,
        accent: 'var(--p-danger)',
        keywords: 'blocked accounts users privacy',
      },
      {
        key: 'muted',
        title: 'Muted words',
        subtitle: 'Hide phrases, hashtags, and topics from your experience',
        path: '/settings/muted',
        icon: ShieldOff,
        accent: 'var(--p-text-muted)',
        keywords: 'muted words hashtags topics hidden content',
      },
    ],
  },
  {
    title: 'Notifications and communication',
    items: [
      {
        key: 'notifications',
        title: 'Notifications',
        subtitle: 'Push, email, sounds, mentions, follows, and quiet hours',
        path: '/settings/notifications',
        icon: Bell,
        accent: 'var(--p-brand)',
        keywords: 'notifications push email sound haptics mentions follows quiet hours',
      },
      {
        key: 'chats',
        title: 'Chats & messages',
        subtitle: 'Message privacy, read receipts, group invites, and media',
        path: '/settings/chats',
        icon: MessageCircle,
        accent: 'var(--p-repost-active)',
        keywords: 'chats messages read receipts groups media previews',
      },
      {
        key: 'devices',
        title: 'Devices',
        subtitle: 'Review active sessions and signed-in devices',
        path: '/settings/devices',
        icon: Smartphone,
        accent: 'var(--p-info)',
        keywords: 'devices sessions signed in security',
      },
    ],
  },
  {
    title: 'Experience',
    items: [
      {
        key: 'feed',
        title: 'Feed & content',
        subtitle: 'For You, following, personalization, topics, and autoplay',
        path: '/settings/feed',
        icon: Sparkles,
        accent: 'var(--p-brand)',
        keywords: 'feed for you following personalization trending autoplay recommendations',
      },
      {
        key: 'friends',
        title: 'Friends & social graph',
        subtitle: 'Friend requests, mutual activity, and suggestions',
        path: '/settings/friends',
        icon: Users,
        accent: 'var(--p-success)',
        keywords: 'friends follow requests mutual suggestions close friends',
      },
      {
        key: 'appearance',
        title: 'Appearance',
        subtitle: 'Theme, density, text size, motion, and interface feel',
        path: '/settings/appearance',
        icon: Palette,
        accent: 'var(--p-premium-content)',
        keywords: 'appearance theme dark light density font text motion',
      },
      {
        key: 'accessibility',
        title: 'Accessibility',
        subtitle: 'Contrast, larger touch targets, labels, and autoplay',
        path: '/settings/accessibility',
        icon: Accessibility,
        accent: 'var(--p-info)',
        keywords: 'accessibility contrast motion text touch screen reader autoplay',
      },
      {
        key: 'language',
        title: 'Language',
        subtitle: 'Choose display language and region defaults',
        path: '/settings/language',
        icon: Languages,
        accent: 'var(--p-brand)',
        keywords: 'language region locale',
      },
    ],
  },
  {
    title: 'Data and intelligence',
    items: [
      {
        key: 'data_storage',
        title: 'Data & storage',
        subtitle: 'Data saver, cache metadata, media quality, and export',
        path: '/settings/data-storage',
        icon: Database,
        accent: 'var(--p-warning)',
        keywords: 'data storage cache export saver download media quality',
      },
      {
        key: 'ai_personalization',
        title: 'AI & personalization',
        subtitle: 'Recommendations, smart replies, friend suggestions, and safety',
        path: '/settings/ai',
        icon: Bot,
        accent: 'var(--p-brand)',
        keywords: 'ai personalization recommendations smart replies suggestions safety',
      },
      {
        key: 'creator',
        title: 'Creator / professional',
        subtitle: 'Creator mode, professional profile, badge, and contact button',
        path: '/settings/creator',
        icon: Flag,
        accent: 'var(--p-premium-content)',
        keywords: 'creator professional badge analytics contact',
      },
    ],
  },
  {
    title: 'Support and legal',
    items: [
      {
        key: 'support',
        title: 'Help & feedback',
        subtitle: 'Get support, report bugs, and send product feedback',
        path: '/support',
        icon: HelpCircle,
        accent: 'var(--p-info)',
        keywords: 'support help feedback report bug',
      },
      {
        key: 'legal',
        title: 'Legal & about',
        subtitle: 'Terms, privacy policy, licenses, and app version',
        path: '/settings/legal',
        icon: FileText,
        accent: 'var(--p-text-muted)',
        keywords: 'legal privacy terms policy licenses about version',
      },
      {
        key: 'danger',
        title: 'Danger zone',
        subtitle: 'Logout, deactivate account, or request deletion',
        path: '/settings/danger',
        icon: HardDrive,
        accent: 'var(--p-danger)',
        keywords: 'danger logout delete deactivate account',
      },
    ],
  },
];

export const allSettingsItems = settingsGroups.flatMap((group) => group.items);

export function findSettingsMeta(key: SettingsPageKey) {
  return allSettingsItems.find((item) => item.key === key);
}

export function categoryTrailing(key: SettingsPageKey, settings: SettingsState) {
  switch (key) {
    case 'profile_visibility':
      return settings.privateAccount ? 'Private' : 'Public';
    case 'privacy':
      return settings.activityStatus ? 'Active' : 'Quiet';
    case 'security':
      return settings.twoFactor ? '2FA on' : 'Basic';
    case 'notifications':
      return settings.pushNotifications ? 'Push on' : 'Muted';
    case 'chats':
      return labelValue(settings.whoCanMessage);
    case 'feed':
      return labelValue(settings.defaultFeedMode);
    case 'friends':
      return settings.aiFriendSuggestions ? 'Smart' : 'Manual';
    case 'appearance':
      return settings.themeIndex === 2 ? 'Dark' : settings.themeIndex === 1 ? 'Light' : 'System';
    case 'accessibility':
      return settings.highContrast ? 'Contrast' : `${Math.round(settings.textScale * 100)}%`;
    case 'data_storage':
      return settings.dataSaver ? 'Saver' : labelValue(settings.mediaQuality);
    case 'ai_personalization':
      return settings.aiPersonalizedFeed ? 'Enabled' : 'Off';
    case 'creator':
      return settings.creatorMode ? 'Creator' : 'Personal';
    case 'language':
      return settings.languageLabel;
    default:
      return 'Open';
  }
}

export function labelValue(value: string) {
  if (!value) return '';
  return value
    .replace(/([A-Z])/g, ' $1')
    .replace(/_/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/^./, (letter) => letter.toUpperCase());
}
