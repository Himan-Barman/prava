import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { CheckCircle2, Search, ShieldCheck } from 'lucide-react';

import {
  categoryTrailing,
  allSettingsItems,
  settingsGroups,
  type SettingsMeta,
} from './settings-config';
import {
  defaultSettings,
  settingsService,
  type SettingsAccount,
  type SettingsState,
} from '../../services/settings-service';
import { smartToast } from '../../ui-system/components/SmartToast';
import { useAuth } from '../../context/auth-context';

function initials(name: string) {
  const clean = name.trim();
  if (!clean) return 'P';
  return clean.slice(0, 1).toUpperCase();
}

function accountLabel(account?: SettingsAccount | null) {
  if (!account) return 'Personal account';
  return account.accountType === 'creator'
    ? 'Creator account'
    : account.accountType === 'professional'
      ? 'Professional account'
      : 'Personal account';
}

export default function SettingsPage() {
  const { user } = useAuth();
  const [settings, setSettings] = useState<SettingsState>(defaultSettings);
  const [account, setAccount] = useState<SettingsAccount | null>(null);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState('');

  useEffect(() => {
    let active = true;
    settingsService
      .fetchBundle()
      .then((bundle) => {
        if (!active) return;
        setSettings({ ...defaultSettings, ...(bundle.legacy ?? {}) });
        setAccount(bundle.account ?? null);
      })
      .catch(() => smartToast.error('Unable to load settings'))
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
    };
  }, []);

  const filteredGroups = useMemo(() => {
    const term = query.trim().toLowerCase();
    if (!term) return settingsGroups;
    return settingsGroups
      .map((group) => ({
        ...group,
        items: group.items.filter((item) =>
          `${item.title} ${item.subtitle} ${item.key} ${item.keywords}`.toLowerCase().includes(term)
        ),
      }))
      .filter((group) => group.items.length > 0);
  }, [query]);

  const quickItems = allSettingsItems.filter((item) =>
    ['privacy', 'security', 'notifications', 'feed', 'appearance', 'data_storage'].includes(item.key)
  );
  const displayName =
    account?.displayName ||
    user?.displayName ||
    user?.username ||
    'Prava account';
  const username = account?.username || user?.username || '';
  const completion = account?.profileCompletion ?? 0;

  return (
    <div className="p-page settings-home-page">
      <motion.header
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.24 }}
        className="settings-sticky-header"
      >
        <div>
          <h1 className="p-page-title">Settings</h1>
          <p className="p-page-subtitle">Control your Prava account, privacy, feed, and app experience.</p>
        </div>
        <label className="settings-search" aria-label="Search settings">
          <Search size={17} strokeWidth={2.8} />
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search settings"
          />
        </label>
      </motion.header>

      {!query.trim() && (
        <>
          <motion.section
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.24, delay: 0.03 }}
            className="settings-account-card"
          >
            <div className="settings-account-card__avatar">
              {account?.avatarUrl ? (
                <img src={account.avatarUrl} alt="" />
              ) : (
                <span>{initials(displayName)}</span>
              )}
            </div>
            <div className="settings-account-card__body">
              <div className="settings-account-card__name">
                <span>{displayName}</span>
                {account?.isVerified && <CheckCircle2 size={16} strokeWidth={2.8} />}
              </div>
              <p>{username ? `@${username}` : accountLabel(account)}</p>
              <div className="settings-progress" aria-label={`Profile ${completion}% complete`}>
                <span style={{ width: `${Math.max(4, completion)}%` }} />
              </div>
              <small>{loading ? 'Syncing settings...' : `${completion}% complete · ${accountLabel(account)}`}</small>
            </div>
            <Link to="/settings/account" className="p-btn p-btn--secondary p-btn--sm">
              Manage
            </Link>
          </motion.section>

          <section className="settings-quick-grid" aria-label="Quick controls">
            {quickItems.map((item, index) => (
              <QuickControl key={item.key} item={item} index={index} />
            ))}
          </section>
        </>
      )}

      <div className="settings-groups">
        {filteredGroups.length === 0 ? (
          <div className="p-empty">
            <div className="p-empty__icon">
              <Search size={24} />
            </div>
            <p className="p-empty__title">No settings found</p>
            <p className="p-empty__desc">Try privacy, username, notifications, feed, data, or delete.</p>
          </div>
        ) : (
          filteredGroups.map((group) => (
            <section key={group.title} className="settings-group">
              <p className="p-section-label">{group.title}</p>
              <div className="settings-list">
                {group.items.map((item, index) => (
                  <SettingsRow
                    key={item.key}
                    item={item}
                    index={index}
                    trailing={categoryTrailing(item.key, settings)}
                  />
                ))}
              </div>
            </section>
          ))
        )}
      </div>
    </div>
  );
}

function QuickControl({ item, index }: { item: SettingsMeta; index: number }) {
  const Icon = item.icon;
  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.2, delay: 0.04 + index * 0.025 }}
    >
      <Link to={item.path} className="settings-quick-card">
        <Icon size={21} strokeWidth={2.8} style={{ color: item.accent }} />
        <span>{item.title}</span>
      </Link>
    </motion.div>
  );
}

function SettingsRow({
  item,
  index,
  trailing,
}: {
  item: SettingsMeta;
  index: number;
  trailing: string;
}) {
  const Icon = item.icon;
  return (
    <motion.div
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.18, delay: index * 0.015 }}
    >
      <Link to={item.path} className="settings-row">
        <span className="settings-row__icon" style={{ color: item.accent }}>
          {item.key === 'security' ? (
            <ShieldCheck size={22} strokeWidth={2.8} />
          ) : (
            <Icon size={22} strokeWidth={2.8} />
          )}
        </span>
        <span className="settings-row__body">
          <strong>{item.title}</strong>
          <small>{item.subtitle}</small>
        </span>
        <span className="settings-row__trailing">{trailing}</span>
      </Link>
    </motion.div>
  );
}
