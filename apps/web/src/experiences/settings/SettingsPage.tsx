import { motion } from 'framer-motion';
import type { ElementType } from 'react';
import { Link } from 'react-router-dom';
import {
  User, Link as LinkIcon, Shield, Smartphone, UserX,
  MessageSquareOff, Globe, Download, FileText, HelpCircle,
  ChevronRight, Lock
} from 'lucide-react';
import { GlassCard } from '../../ui-system';

interface SettingsItem {
  label: string;
  description: string;
  icon: ElementType;
  path: string;
}

const accountSettings: SettingsItem[] = [
  { label: 'Account Info', description: 'Manage your personal details', icon: User, path: '/settings/account' },
  { label: 'Handle & Links', description: 'Your username and profile links', icon: LinkIcon, path: '/settings/handle' },
];

const securitySettings: SettingsItem[] = [
  { label: 'Security Center', description: 'Password, 2FA, and more', icon: Shield, path: '/settings/security' },
  { label: 'Devices', description: 'Manage logged-in devices', icon: Smartphone, path: '/settings/devices' },
];

const privacySettings: SettingsItem[] = [
  { label: 'Blocked Accounts', description: 'People you have blocked', icon: UserX, path: '/settings/blocked' },
  { label: 'Muted Words', description: 'Content filtering preferences', icon: MessageSquareOff, path: '/settings/muted' },
];

const generalSettings: SettingsItem[] = [
  { label: 'Language', description: 'Change your display language', icon: Globe, path: '/settings/language' },
  { label: 'Data Export', description: 'Download your data', icon: Download, path: '/settings/export' },
  { label: 'Legal', description: 'Terms and privacy policy', icon: FileText, path: '/settings/legal' },
];

function SettingsGroup({ title, items }: { title: string; items: SettingsItem[] }) {
  return (
    <div className="mb-6">
      <h2 className="text-label font-semibold text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary uppercase tracking-wider mb-3 px-1">
        {title}
      </h2>
      <GlassCard className="divide-y divide-prava-light-border/50 dark:divide-prava-dark-border/50">
        {items.map((item) => (
          <Link
            key={item.path}
            to={item.path}
            className="flex items-center gap-4 p-4 -mx-5 sm:-mx-6 px-5 sm:px-6 first:rounded-t-[24px] last:rounded-b-[24px] hover:bg-prava-light-surface/50 dark:hover:bg-prava-dark-surface/50 transition-colors"
          >
            <div className="p-2.5 rounded-[12px] bg-prava-accent/10">
              <item.icon className="w-5 h-5 text-prava-accent" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="font-medium text-body text-prava-light-text-primary dark:text-prava-dark-text-primary">
                {item.label}
              </p>
              <p className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                {item.description}
              </p>
            </div>
            <ChevronRight className="w-5 h-5 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary" />
          </Link>
        ))}
      </GlassCard>
    </div>
  );
}

export default function SettingsPage() {
  return (
    <div className="max-w-2xl mx-auto">
      {/* Page Header */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="mb-6"
      >
        <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary">
          Settings
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Manage your account and preferences
        </p>
      </motion.div>

      {/* Security Banner */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.1 }}
        className="mb-6"
      >
        <div className="flex items-center gap-3 p-4 rounded-[16px] bg-prava-success/10 border border-prava-success/20">
          <Lock className="w-5 h-5 text-prava-success shrink-0" />
          <p className="text-body-sm text-prava-light-text-primary dark:text-prava-dark-text-primary">
            Your account is protected with end-to-end encryption
          </p>
        </div>
      </motion.div>

      {/* Settings Groups */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.15 }}
      >
        <SettingsGroup title="Account" items={accountSettings} />
        <SettingsGroup title="Security" items={securitySettings} />
        <SettingsGroup title="Privacy" items={privacySettings} />
        <SettingsGroup title="General" items={generalSettings} />
      </motion.div>

      {/* Support Link */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.25 }}
      >
        <Link
          to="/support"
          className="flex items-center gap-4 p-4 rounded-[16px] bg-prava-accent/10 border border-prava-accent/20 hover:bg-prava-accent/15 transition-colors"
        >
          <div className="p-2.5 rounded-[12px] bg-prava-accent/20">
            <HelpCircle className="w-5 h-5 text-prava-accent" />
          </div>
          <div className="flex-1">
            <p className="font-medium text-body text-prava-light-text-primary dark:text-prava-dark-text-primary">
              Help & Support
            </p>
            <p className="text-body-sm text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              Get help, report issues, or send feedback
            </p>
          </div>
          <ChevronRight className="w-5 h-5 text-prava-accent" />
        </Link>
      </motion.div>
    </div>
  );
}
