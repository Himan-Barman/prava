import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Search, ShieldCheck } from 'lucide-react';

import {
  categoryTrailing,
  settingsGroups,
  type SettingsMeta,
} from './settings-config';
import {
  defaultSettings,
  settingsService,
  type SettingsState,
} from '../../services/settings-service';
import { smartToast } from '../../ui-system/components/SmartToast';

export default function SettingsPage() {
  const [settings, setSettings] = useState<SettingsState>(defaultSettings);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState('');

  useEffect(() => {
    let active = true;
    settingsService
      .fetchSettings()
      .then((next) => {
        if (active) setSettings({ ...defaultSettings, ...next });
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
          <p className="p-page-subtitle">Control account, privacy, feed, chats, and app experience.</p>
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

      {loading ? (
        <div className="settings-loading">
          <div className="p-spinner" />
        </div>
      ) : (
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
      )}
    </div>
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
