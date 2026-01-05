import {
  Bell,
  BookOpen,
  ClipboardList,
  Compass,
  FolderArchive,
  HelpCircle,
  LayoutGrid,
  MessageCircle,
  Settings,
  ShieldCheck,
  Star,
  User,
  Users,
  Search,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';

export interface NavItem {
  label: string;
  path: string;
  icon: LucideIcon;
  group: 'core' | 'community' | 'settings';
}

export const navItems: NavItem[] = [
  { label: 'Feed', path: '/feed', icon: LayoutGrid, group: 'core' },
  { label: 'Chats', path: '/chats', icon: MessageCircle, group: 'core' },
  { label: 'Friends', path: '/friends', icon: Users, group: 'core' },
  { label: 'Search', path: '/search', icon: Search, group: 'core' },
  { label: 'Notifications', path: '/notifications', icon: Bell, group: 'core' },
  { label: 'Profile', path: '/profile', icon: User, group: 'community' },
  { label: 'Broadcast', path: '/broadcast', icon: Compass, group: 'community' },
  { label: 'Archived chats', path: '/chats/archived', icon: FolderArchive, group: 'community' },
  { label: 'Starred messages', path: '/chats/starred', icon: Star, group: 'community' },
  { label: 'New group', path: '/chats/new', icon: ClipboardList, group: 'community' },
  { label: 'Security center', path: '/settings/security', icon: ShieldCheck, group: 'settings' },
  { label: 'Help & feedback', path: '/support', icon: HelpCircle, group: 'settings' },
  { label: 'Legal', path: '/settings/legal', icon: BookOpen, group: 'settings' },
  { label: 'Settings', path: '/settings', icon: Settings, group: 'settings' },
];

export const pageTitles: Record<string, { title: string; subtitle: string }> = {
  '/feed': { title: 'Feed', subtitle: 'Your algorithmic stream and latest posts.' },
  '/chats': { title: 'Chats', subtitle: 'Conversations, groups, and broadcast rooms.' },
  '/friends': { title: 'Friends', subtitle: 'Follow requests, connections, and people.' },
  '/search': { title: 'Search', subtitle: 'Discover people, topics, and trending tags.' },
  '/notifications': { title: 'Notifications', subtitle: 'Mentions, replies, and social pings.' },
  '/profile': { title: 'Profile', subtitle: 'Your presence, stats, and latest posts.' },
  '/broadcast': { title: 'Broadcast', subtitle: 'Host live updates and community rooms.' },
  '/chats/archived': { title: 'Archived chats', subtitle: 'Keep quiet conversations handy.' },
  '/chats/starred': { title: 'Starred messages', subtitle: 'Pinned highlights and saved notes.' },
  '/chats/new': { title: 'New group', subtitle: 'Start group chats and spaces.' },
  '/settings': { title: 'Settings', subtitle: 'Personalize your Prava experience.' },
  '/settings/account': { title: 'Account information', subtitle: 'Control your identity and profile.' },
  '/settings/handle': { title: 'Handle & links', subtitle: 'Manage your Prava ID and bio links.' },
  '/settings/security': { title: 'Security center', subtitle: 'Protect your account and devices.' },
  '/settings/devices': { title: 'Devices', subtitle: 'Review active sessions and sign-ins.' },
  '/settings/blocked': { title: 'Blocked accounts', subtitle: 'Keep your space curated.' },
  '/settings/muted': { title: 'Muted words', subtitle: 'Quiet unwanted topics and phrases.' },
  '/settings/language': { title: 'Language', subtitle: 'Pick your preferred experience.' },
  '/settings/export': { title: 'Data export', subtitle: 'Request your account archive.' },
  '/settings/legal': { title: 'Legal', subtitle: 'Policies and terms.' },
  '/support': { title: 'Help & feedback', subtitle: 'Support, reports, and ideas.' },
};
