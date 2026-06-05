import type { ElementType } from 'react';
import { Link } from 'react-router-dom';
import {
  AtSign,
  Bell,
  Database,
  Download,
  FileText,
  Globe,
  HelpCircle,
  MessageSquareOff,
  Shield,
  Smartphone,
  User,
  UserX,
} from 'lucide-react';

interface SettingsItem {
  label: string;
  description: string;
  icon: ElementType;
  path: string;
}

const sections: Array<{ title: string; items: SettingsItem[] }> = [
  {
    title: 'Account center',
    items: [
      {
        label: 'Account information',
        description: 'Email, name, and phone number',
        icon: User,
        path: '/settings/account',
      },
      {
        label: 'Username',
        description: 'Search and change your username',
        icon: AtSign,
        path: '/settings/handle',
      },
    ],
  },
  {
    title: 'Security',
    items: [
      {
        label: 'Security center',
        description: 'Login, password, and app protection',
        icon: Shield,
        path: '/settings/security',
      },
      {
        label: 'Devices',
        description: 'Manage signed in devices',
        icon: Smartphone,
        path: '/settings/devices',
      },
    ],
  },
  {
    title: 'Privacy',
    items: [
      {
        label: 'Blocked accounts',
        description: 'Manage blocked profiles',
        icon: UserX,
        path: '/settings/blocked',
      },
      {
        label: 'Muted words',
        description: 'Hide topics and phrases',
        icon: MessageSquareOff,
        path: '/settings/muted',
      },
    ],
  },
  {
    title: 'General',
    items: [
      {
        label: 'Language',
        description: 'Display language',
        icon: Globe,
        path: '/settings/language',
      },
      {
        label: 'Data export',
        description: 'Download your data',
        icon: Download,
        path: '/settings/export',
      },
      {
        label: 'Legal',
        description: 'Terms and privacy policy',
        icon: FileText,
        path: '/settings/legal',
      },
      {
        label: 'Notification controls',
        description: 'Alerts and notification access',
        icon: Bell,
        path: '/notifications',
      },
      {
        label: 'Storage',
        description: 'Data and cache controls',
        icon: Database,
        path: '/settings/export',
      },
    ],
  },
  {
    title: 'Support',
    items: [
      {
        label: 'Help and feedback',
        description: 'Get help or report an issue',
        icon: HelpCircle,
        path: '/support',
      },
    ],
  },
];

function SettingsRow({ item }: { item: SettingsItem }) {
  const Icon = item.icon;
  return (
    <Link
      to={item.path}
      className="flex items-center gap-4 py-4 transition-colors hover:text-prava-accent"
    >
      <Icon className="h-6 w-6 shrink-0 text-prava-accent" strokeWidth={2.6} />
      <div className="min-w-0 flex-1">
        <p className="truncate text-body font-extrabold text-prava-light-text-primary dark:text-prava-dark-text-primary">
          {item.label}
        </p>
        <p className="truncate text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
          {item.description}
        </p>
      </div>
    </Link>
  );
}

export default function SettingsPage() {
  return (
    <div className="mx-auto max-w-2xl">
      <div className="sticky top-0 z-10 -mx-4 bg-prava-light-bg/90 px-4 pb-3 pt-1 backdrop-blur-xl dark:bg-prava-dark-bg/90 sm:static sm:mx-0 sm:bg-transparent sm:px-0 sm:pt-0 sm:backdrop-blur-0">
        <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary">
          Settings
        </h1>
      </div>

      <div className="divide-y divide-prava-light-border/70 dark:divide-prava-dark-border/70">
        {sections.map((section) => (
          <section key={section.title} className="py-4 first:pt-1">
            <h2 className="mb-1 text-label font-bold uppercase tracking-[0.08em] text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
              {section.title}
            </h2>
            <div className="divide-y divide-prava-light-border/50 dark:divide-prava-dark-border/50">
              {section.items.map((item) => (
                <SettingsRow key={`${section.title}-${item.label}`} item={item} />
              ))}
            </div>
          </section>
        ))}
      </div>
    </div>
  );
}
