import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowLeft, Link as LinkIcon, Copy } from 'lucide-react';
import { GlassCard, PravaInput, PravaButton } from '../../ui-system';
import { accountService } from '../../services/account-service';
import { authService } from '../../services/auth-service';
import { smartToast } from '../../ui-system/components/SmartToast';

export default function HandleLinksPage() {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [username, setUsername] = useState('');
  const [originalUsername, setOriginalUsername] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [bio, setBio] = useState('');
  const [location, setLocation] = useState('');
  const [website, setWebsite] = useState('');
  const [checkingUsername, setCheckingUsername] = useState(false);
  const [usernameAvailable, setUsernameAvailable] = useState<boolean | null>(null);

  useEffect(() => {
    const loadProfile = async () => {
      try {
        const info = await accountService.fetchAccountInfo();
        setUsername(info.username || '');
        setOriginalUsername(info.username || '');
        setDisplayName(info.displayName || '');
        setBio(info.bio || '');
        setLocation(info.location || '');
        setWebsite(info.website || '');
      } catch (error) {
        smartToast.error('Unable to load profile details');
      } finally {
        setLoading(false);
      }
    };

    loadProfile();
  }, []);

  useEffect(() => {
    const trimmed = username.trim();
    if (!trimmed || trimmed === originalUsername) {
      setUsernameAvailable(null);
      setCheckingUsername(false);
      return;
    }

    if (trimmed.length < 3) {
      setUsernameAvailable(false);
      setCheckingUsername(false);
      return;
    }

    setCheckingUsername(true);
    const timer = setTimeout(async () => {
      try {
        const available = await authService.isUsernameAvailable(trimmed);
        setUsernameAvailable(available);
      } catch {
        setUsernameAvailable(false);
      } finally {
        setCheckingUsername(false);
      }
    }, 400);

    return () => clearTimeout(timer);
  }, [username, originalUsername]);

  const handleSave = async () => {
    if (saving) return;
    if (!username.trim()) {
      smartToast.warning('Username is required');
      return;
    }
    if (usernameAvailable === false) {
      smartToast.warning('Choose a different username');
      return;
    }

    setSaving(true);
    try {
      const updated = await accountService.updateHandle({
        username: username.trim(),
        displayName: displayName.trim(),
        bio: bio.trim(),
        location: location.trim(),
        website: website.trim(),
      });
      if (updated?.username) {
        setOriginalUsername(updated.username);
        setUsername(updated.username);
      }
      smartToast.success('Profile updated');
    } catch (error) {
      smartToast.error('Unable to update profile');
    } finally {
      setSaving(false);
    }
  };

  const usernameHint = checkingUsername
    ? 'Checking availability...'
    : usernameAvailable === null
      ? 'Username'
      : usernameAvailable
        ? 'Username is available'
        : 'Username is taken';

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
          Handle & Links
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Your username and profile links
        </p>
      </motion.div>

      <GlassCard className="mb-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="p-2.5 rounded-[12px] bg-prava-accent/10">
            <LinkIcon className="w-5 h-5 text-prava-accent" />
          </div>
          <h2 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary">
            Your Handle
          </h2>
        </div>

        <PravaInput
          label={usernameHint}
          placeholder="username"
          prefixIcon={<span className="text-prava-light-text-secondary dark:text-prava-dark-text-secondary">@</span>}
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          disabled={loading}
        />

        <div className="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-4">
          <PravaInput
            label="Display Name"
            placeholder="Your name"
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            disabled={loading}
          />
          <PravaInput
            label="Location"
            placeholder="City, Country"
            value={location}
            onChange={(e) => setLocation(e.target.value)}
            disabled={loading}
          />
        </div>

        <div className="mt-4">
          <label className="block text-label font-semibold text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary mb-2">
            Bio
          </label>
          <textarea
            placeholder="Tell people a bit about you..."
            className="w-full p-4 rounded-[16px] bg-prava-light-surface dark:bg-prava-dark-surface border border-prava-light-border dark:border-prava-dark-border text-body text-prava-light-text-primary dark:text-prava-dark-text-primary placeholder:text-prava-light-text-tertiary dark:placeholder:text-prava-dark-text-tertiary focus:outline-none focus:ring-2 focus:ring-prava-accent/30 resize-none"
            rows={3}
            value={bio}
            onChange={(e) => setBio(e.target.value)}
            disabled={loading}
          />
        </div>

        <div className="mt-4">
          <PravaInput
            label="Website"
            placeholder="https://your.site"
            value={website}
            onChange={(e) => setWebsite(e.target.value)}
            disabled={loading}
          />
        </div>

        <div className="mt-4 p-3 rounded-[12px] bg-prava-light-surface dark:bg-prava-dark-surface">
          <p className="text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary mb-1">
            Your profile link
          </p>
          <div className="flex items-center gap-2">
            <code className="flex-1 text-body-sm text-prava-accent">
              prava.app/@{username.trim() || 'username'}
            </code>
            <button className="p-2 rounded-[8px] hover:bg-prava-light-border dark:hover:bg-prava-dark-border transition-colors">
              <Copy className="w-4 h-4 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary" />
            </button>
          </div>
        </div>
      </GlassCard>

      <PravaButton label={saving ? 'Saving...' : 'Save Changes'} onClick={handleSave} disabled={saving || loading} />
    </div>
  );
}
