import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowLeft, Globe, Check } from 'lucide-react';
import { GlassCard } from '../../ui-system';
import { settingsService } from '../../services/settings-service';
import { smartToast } from '../../ui-system/components/SmartToast';

const languages = [
  { code: 'en', name: 'English', native: 'English', selected: true },
  { code: 'es', name: 'Spanish', native: 'Espanol', selected: false },
  { code: 'fr', name: 'French', native: 'Francais', selected: false },
  { code: 'de', name: 'German', native: 'Deutsch', selected: false },
  { code: 'ja', name: 'Japanese', native: 'Nihongo', selected: false },
];

export default function LanguagePage() {
  const [selected, setSelected] = useState<string>('English');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadSettings = async () => {
      try {
        const settings = await settingsService.fetchSettings();
        setSelected(settings.languageLabel || 'English');
      } catch {
        smartToast.error('Unable to load language settings');
      } finally {
        setLoading(false);
      }
    };

    loadSettings();
  }, []);

  const handleSelect = async (name: string) => {
    if (loading || selected === name) return;
    setSelected(name);
    try {
      await settingsService.updateSettings({ languageLabel: name });
      smartToast.success('Language updated');
    } catch {
      smartToast.error('Unable to update language');
    }
  };

  return (
    <div className="max-w-2xl mx-auto">
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="mb-6"
      >
        <Link
          to="/settings"
          className="inline-flex items-center gap-2 text-body font-medium text-prava-light-text-secondary dark:text-prava-dark-text-secondary hover:text-prava-light-text-primary dark:hover:text-prava-dark-text-primary transition-colors mb-4"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Settings
        </Link>
        <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary">
          Language
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Choose your display language
        </p>
      </motion.div>

      <GlassCard>
        <div className="flex items-center gap-3 mb-4">
          <div className="p-2.5 rounded-[12px] bg-prava-accent/10">
            <Globe className="w-5 h-5 text-prava-accent" />
          </div>
          <h2 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary">
            Select Language
          </h2>
        </div>

        <div className="space-y-2">
          {languages.map((lang) => {
            const isSelected = lang.name === selected;
            return (
            <button
              key={lang.code}
              onClick={() => handleSelect(lang.name)}
              className={`w-full flex items-center justify-between p-4 rounded-[14px] transition-colors ${isSelected
                  ? 'bg-prava-accent/10 border border-prava-accent/30'
                  : 'hover:bg-prava-light-surface dark:hover:bg-prava-dark-surface'
                }`}
            >
              <div className="text-left">
                <p className="font-medium text-body text-prava-light-text-primary dark:text-prava-dark-text-primary">
                  {lang.name}
                </p>
                <p className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                  {lang.native}
                </p>
              </div>
              {isSelected && (
                <div className="p-1.5 rounded-full bg-prava-accent">
                  <Check className="w-4 h-4 text-white" />
                </div>
              )}
            </button>
          );
          })}
        </div>
      </GlassCard>
    </div>
  );
}
