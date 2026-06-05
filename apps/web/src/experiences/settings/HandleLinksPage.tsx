import { useEffect, useMemo, useState } from 'react';
import { CheckCircle2, XCircle, Loader2, AtSign } from 'lucide-react';
import { PravaButton, PravaInput } from '../../ui-system';
import { accountService, type AccountInfo } from '../../services/account-service';
import { authService } from '../../services/auth-service';
import { smartToast } from '../../ui-system/components/SmartToast';

const usernamePattern = /^[a-z0-9_.]{3,32}$/;

function formatDate(value?: string | null) {
  if (!value) return '';
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return '';
  return new Intl.DateTimeFormat(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(parsed);
}

function apiMessage(error: unknown) {
  if (error && typeof error === 'object' && 'response' in error) {
    const response = (error as { response?: { data?: { message?: string }; status?: number } }).response;
    if (response?.status === 401) return 'Password is incorrect';
    if (response?.status === 409) return 'Username is not available';
    if (response?.status === 429) return 'Username can be changed once every 3 months';
    return response?.data?.message ?? 'Unable to change username';
  }
  return 'Unable to change username';
}

export default function HandleLinksPage() {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [checking, setChecking] = useState(false);
  const [account, setAccount] = useState<AccountInfo | null>(null);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [checkedUsername, setCheckedUsername] = useState('');
  const [available, setAvailable] = useState<boolean | null>(null);

  const candidate = username.trim().toLowerCase();
  const currentUsername = account?.username.trim().toLowerCase() ?? '';
  const changed = candidate.length > 0 && candidate !== currentUsername;
  const valid = usernamePattern.test(candidate);
  const canChange = account?.canChangeUsername === true;
  const canSubmit =
    !saving &&
    canChange &&
    changed &&
    valid &&
    available === true &&
    checkedUsername === candidate &&
    password.length > 0;

  useEffect(() => {
    let active = true;
    accountService
      .fetchAccountInfo()
      .then((info) => {
        if (!active) return;
        setAccount(info);
        setUsername(info.username ?? '');
      })
      .catch(() => smartToast.error('Unable to load username settings'))
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    setAvailable(null);
    setCheckedUsername('');
    if (!changed || !valid) return;

    const timer = window.setTimeout(() => {
      void checkAvailability();
    }, 450);
    return () => window.clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [candidate, changed, valid]);

  const status = useMemo(() => {
    if (!changed) return { text: 'Current username', tone: 'muted' };
    if (!valid) {
      return {
        text: 'Use 3-32 letters, numbers, dots, or underscores',
        tone: 'error',
      };
    }
    if (checking) return { text: 'Checking database...', tone: 'muted' };
    if (checkedUsername !== candidate) {
      return { text: 'Waiting to check availability', tone: 'muted' };
    }
    if (available) return { text: 'Username is available', tone: 'success' };
    if (available === false) return { text: 'Username is taken', tone: 'error' };
    return { text: 'Search your preferred username', tone: 'muted' };
  }, [available, candidate, changed, checkedUsername, checking, valid]);

  const checkAvailability = async () => {
    if (!changed) return;
    if (!valid) {
      setAvailable(false);
      setCheckedUsername(candidate);
      return;
    }
    setChecking(true);
    try {
      const result = await authService.isUsernameAvailable(candidate);
      setAvailable(result);
      setCheckedUsername(candidate);
    } catch {
      setAvailable(false);
      setCheckedUsername(candidate);
      smartToast.error('Unable to check username');
    } finally {
      setChecking(false);
    }
  };

  const changeUsername = async () => {
    if (!canSubmit) {
      if (!changed) smartToast.warning('Enter a new username');
      else if (!valid) smartToast.warning('Use a valid username');
      else if (available !== true || checkedUsername !== candidate) {
        smartToast.warning('Check username availability first');
      } else if (!password) smartToast.warning('Enter your password');
      return;
    }

    setSaving(true);
    try {
      const updated = await accountService.changeUsername({
        username: candidate,
        password,
      });
      setAccount(updated);
      setUsername(updated.username);
      setPassword('');
      setAvailable(null);
      setCheckedUsername('');
      smartToast.success('Username changed');
    } catch (error) {
      smartToast.error(apiMessage(error));
    } finally {
      setSaving(false);
    }
  };

  const suffixIcon = checking ? (
    <Loader2 className="h-5 w-5 animate-spin text-prava-accent" />
  ) : changed && checkedUsername === candidate && available === true ? (
    <CheckCircle2 className="h-5 w-5 text-prava-success" />
  ) : changed && checkedUsername === candidate && available === false ? (
    <XCircle className="h-5 w-5 text-prava-error" />
  ) : null;

  const statusClass =
    status.tone === 'success'
      ? 'text-prava-success'
      : status.tone === 'error'
        ? 'text-prava-error'
        : 'text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary';

  return (
    <div className="mx-auto max-w-2xl">
      <div className="sticky top-0 z-10 -mx-4 mb-4 bg-prava-light-bg/90 px-4 pb-3 pt-1 backdrop-blur-xl dark:bg-prava-dark-bg/90 sm:static sm:mx-0 sm:bg-transparent sm:px-0 sm:pt-0 sm:backdrop-blur-0">
        <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary">
          Username
        </h1>
      </div>

      {loading ? (
        <div className="py-20 text-center">
          <Loader2 className="mx-auto h-8 w-8 animate-spin text-prava-accent" />
        </div>
      ) : (
        <div className="space-y-6">
          <section>
            <p className="text-caption font-semibold text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
              Current username
            </p>
            <p className="mt-1 text-h3 font-extrabold text-prava-light-text-primary dark:text-prava-dark-text-primary">
              @{account?.username ?? ''}
            </p>
          </section>

          <section className="space-y-3">
            <PravaInput
              placeholder="Search username"
              value={username}
              onChange={(event) =>
                setUsername(event.target.value.toLowerCase().replace(/[^a-z0-9_.]/g, ''))
              }
              prefixIcon={<AtSign className="h-5 w-5" />}
              suffixIcon={suffixIcon}
              maxLength={32}
              autoComplete="username"
            />
            <p className={`text-caption font-semibold ${statusClass}`}>{status.text}</p>
            <PravaButton
              label={checking ? 'Checking...' : 'Check availability'}
              onClick={checkAvailability}
              disabled={!changed || !valid || checking}
            />
          </section>

          <section className="space-y-3">
            <h2 className="text-body font-bold text-prava-light-text-primary dark:text-prava-dark-text-primary">
              Password verification
            </h2>
            <PravaInput
              placeholder="Password"
              type="password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              autoComplete="current-password"
            />
            <p className="text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
              {canChange
                ? 'You can change your username now. After changing it, the next change is available after 3 months.'
                : account?.nextUsernameChangeAt
                  ? `You can change your username again after ${formatDate(account.nextUsernameChangeAt)}.`
                  : 'Username can be changed once every 3 months.'}
            </p>
          </section>

          <PravaButton
            label={saving ? 'Changing...' : 'Change username'}
            onClick={changeUsername}
            disabled={!canSubmit}
          />
        </div>
      )}
    </div>
  );
}
