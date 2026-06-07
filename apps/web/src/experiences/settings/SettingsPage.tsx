import type { ElementType } from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import {
  AtSign,
  Bell,
  ChevronRight,
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

function SettingsRow({ item, index }: { item: SettingsItem; index: number }) {
  const Icon = item.icon;
  return (
    <motion.div
      initial={{ opacity: 0, y: 4 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.25, delay: index * 0.02 }}
    >
      <Link to={item.path} className="app-settings-row">
        <div className="app-settings-row__icon">
          <Icon size={17} strokeWidth={2.4} />
        </div>
        <div className="app-settings-row__body">
          <p className="app-settings-row__label">{item.label}</p>
          <p className="app-settings-row__desc">{item.description}</p>
        </div>
        <ChevronRight size={16} className="app-settings-row__chevron" />
      </Link>
    </motion.div>
  );
}

export default function SettingsPage() {
  let rowIndex = 0;

  return (
    <div className="mx-auto max-w-2xl pb-8">
      <motion.div
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35 }}
        className="app-page-header"
      >
        <h1 className="app-page-title">Settings</h1>
      </motion.div>

      {sections.map((section) => (
        <section key={section.title} style={{ marginBottom: 8 }}>
          <p style={{
            fontSize: 11, fontWeight: 700,
            textTransform: 'uppercase' as const, letterSpacing: '0.08em',
            color: 'var(--text-tertiary)',
            marginBottom: 4, marginTop: 16,
          }}>
            {section.title}
          </p>
          <div className="app-divider" />
          {section.items.map((item) => {
            const idx = rowIndex++;
            return (
              <SettingsRow key={`${section.title}-${item.label}`} item={item} index={idx} />
            );
          })}
        </section>
      ))}
    </div>
  );
}
