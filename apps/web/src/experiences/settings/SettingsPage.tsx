import type { ElementType } from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import {
  AtSign, Bell, ChevronRight, Database, Download, FileText, Globe,
  HelpCircle, MessageSquareOff, Shield, Smartphone, User, UserX,
} from 'lucide-react';

interface SettingsItem { label: string; description: string; icon: ElementType; path: string; }

const sections: Array<{ title: string; items: SettingsItem[] }> = [
  {
    title: 'Account center',
    items: [
      { label: 'Account information', description: 'Email, name, and phone number', icon: User, path: '/settings/account' },
      { label: 'Username', description: 'Search and change your username', icon: AtSign, path: '/settings/handle' },
    ],
  },
  {
    title: 'Security',
    items: [
      { label: 'Security center', description: 'Login, password, and app protection', icon: Shield, path: '/settings/security' },
      { label: 'Devices', description: 'Manage signed in devices', icon: Smartphone, path: '/settings/devices' },
    ],
  },
  {
    title: 'Privacy',
    items: [
      { label: 'Blocked accounts', description: 'Manage blocked profiles', icon: UserX, path: '/settings/blocked' },
      { label: 'Muted words', description: 'Hide topics and phrases', icon: MessageSquareOff, path: '/settings/muted' },
    ],
  },
  {
    title: 'General',
    items: [
      { label: 'Language', description: 'Display language', icon: Globe, path: '/settings/language' },
      { label: 'Data export', description: 'Download your data', icon: Download, path: '/settings/export' },
      { label: 'Legal', description: 'Terms and privacy policy', icon: FileText, path: '/settings/legal' },
      { label: 'Notification controls', description: 'Alerts and notification access', icon: Bell, path: '/notifications' },
      { label: 'Storage', description: 'Data and cache controls', icon: Database, path: '/settings/export' },
    ],
  },
  {
    title: 'Support',
    items: [
      { label: 'Help and feedback', description: 'Get help or report an issue', icon: HelpCircle, path: '/support' },
    ],
  },
];

export default function SettingsPage() {
  let rowIdx = 0;
  return (
    <div className="p-page">
      <motion.div initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }} className="p-page-header">
        <h1 className="p-page-title">Settings</h1>
      </motion.div>

      {sections.map((section) => (
        <section key={section.title} style={{ marginBottom: 8 }}>
          <p className="p-section-label" style={{ marginTop: 16 }}>{section.title}</p>
          <hr className="p-divider" />
          {section.items.map((item) => {
            const idx = rowIdx++;
            const Icon = item.icon;
            return (
              <motion.div key={`${section.title}-${item.label}`} initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.22, delay: idx * 0.02 }}>
                <Link to={item.path} className="p-settings-row">
                  <div className="p-settings-row__icon"><Icon size={17} strokeWidth={2.4} /></div>
                  <div className="p-settings-row__body">
                    <p className="p-settings-row__label">{item.label}</p>
                    <p className="p-settings-row__desc">{item.description}</p>
                  </div>
                  <ChevronRight size={16} style={{ color: 'var(--p-text-muted)', flexShrink: 0 }} />
                </Link>
              </motion.div>
            );
          })}
        </section>
      ))}
    </div>
  );
}
