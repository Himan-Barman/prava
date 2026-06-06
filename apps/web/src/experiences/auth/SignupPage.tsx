import { useEffect, useState, type ChangeEvent, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { AlertCircle, CheckCircle, Loader2, LogIn, XCircle } from 'lucide-react';
import { PravaInput } from '../../ui-system';
import { authService } from '../../services/auth-service';
import { ApiException } from '../../adapters/api-client';
import { smartToast } from '../../ui-system/components/SmartToast';
import { AuthFrame, AuthStepProgress, AuthSubmitButton } from './AuthFrame';

function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState<T>(value);

  useEffect(() => {
    const handler = window.setTimeout(() => setDebouncedValue(value), delay);
    return () => window.clearTimeout(handler);
  }, [value, delay]);

  return debouncedValue;
}

function isUsernameValid(value: string) {
  return /^[a-z0-9_]{3,32}$/.test(value);
}

function isEmailValid(value: string) {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value);
}

export default function SignupPage() {
  const navigate = useNavigate();

  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [checkingUsername, setCheckingUsername] = useState(false);
  const [usernameAvailable, setUsernameAvailable] = useState(false);
  const [usernameChecked, setUsernameChecked] = useState(false);
  const [usernameCheckFailed, setUsernameCheckFailed] = useState(false);

  const debouncedUsername = useDebounce(username, 500);
  const normalizedEmail = email.trim().toLowerCase();

  useEffect(() => {
    async function checkUsername() {
      const normalized = debouncedUsername.toLowerCase().trim();

      if (!normalized) {
        setUsernameAvailable(false);
        setUsernameChecked(false);
        setUsernameCheckFailed(false);
        return;
      }

      if (!isUsernameValid(normalized)) {
        setUsernameAvailable(false);
        setUsernameChecked(true);
        setUsernameCheckFailed(false);
        return;
      }

      setCheckingUsername(true);
      setUsernameChecked(false);
      setUsernameCheckFailed(false);

      try {
        const available = await authService.isUsernameAvailable(normalized, normalizedEmail);
        setUsernameAvailable(available);
        setUsernameChecked(true);
      } catch {
        setUsernameAvailable(false);
        setUsernameChecked(true);
        setUsernameCheckFailed(true);
      } finally {
        setCheckingUsername(false);
      }
    }

    checkUsername();
  }, [debouncedUsername, normalizedEmail]);

  const canSubmit =
    usernameChecked &&
    usernameAvailable &&
    isEmailValid(normalizedEmail) &&
    !loading &&
    !checkingUsername;

  const handleUsernameChange = (event: ChangeEvent<HTMLInputElement>) => {
    const value = event.target.value.toLowerCase().replace(/[^a-z0-9_]/g, '').slice(0, 32);
    setUsername(value);
    setUsernameChecked(false);
  };

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    if (!canSubmit) {
      if (checkingUsername) {
        smartToast.info('Checking username availability');
      } else if (usernameCheckFailed) {
        smartToast.warning('Unable to verify username. Try again.');
      } else if (!isUsernameValid(username)) {
        smartToast.warning('Username must be 3-32 characters (a-z, 0-9, _)');
      } else if (!isEmailValid(normalizedEmail)) {
        smartToast.warning('Enter a valid email address');
      } else {
        smartToast.warning('Username is not available');
      }
      return;
    }

    setLoading(true);
    try {
      await authService.requestEmailOtp(normalizedEmail, username);
      smartToast.success('Verification code sent');
      const params = new URLSearchParams({
        email: normalizedEmail,
        username,
        flow: 'signup',
      });
      navigate(`/verify-email?${params.toString()}`, {
        state: { email: normalizedEmail, username, flow: 'signup' },
      });
    } catch (err) {
      const message = err instanceof ApiException ? err.message : 'Unable to send verification code';
      smartToast.error(message);
    } finally {
      setLoading(false);
    }
  };

  const usernameStatus = () => {
    if (!username) return null;
    if (checkingUsername) return <Loader2 className="h-4 w-4 animate-spin text-prava-light-text-tertiary" />;
    if (!isUsernameValid(username)) return <XCircle className="h-4 w-4 text-prava-error" />;
    if (usernameCheckFailed) return <AlertCircle className="h-4 w-4 text-prava-warning" />;
    if (usernameChecked && usernameAvailable) return <CheckCircle className="h-4 w-4 text-prava-success" />;
    if (usernameChecked) return <XCircle className="h-4 w-4 text-prava-error" />;
    return null;
  };

  return (
    <AuthFrame
      title="Create Account"
      subtitle="Choose a Prava ID and verify your email before setting a password."
      sideTitle="Create your secure profile"
      actionLabel="Sign In"
      actionTo="/login"
      actionIcon={<LogIn className="h-4 w-4" strokeWidth={3} />}
    >
      <AuthStepProgress current={1} />

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="mb-2 block text-label font-semibold text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
            Prava ID
          </label>
          <div className="flex h-[46px] items-center gap-2 rounded-full border border-prava-light-border bg-prava-light-bg px-4 dark:border-prava-dark-border dark:bg-prava-dark-bg">
            <span className="font-bold text-prava-accent">@</span>
            <input
              value={username}
              onChange={handleUsernameChange}
              placeholder="username"
              autoComplete="username"
              className="min-w-0 flex-1 bg-transparent text-body text-prava-light-text-primary outline-none placeholder:text-prava-light-text-tertiary dark:text-prava-dark-text-primary"
            />
            {usernameStatus()}
          </div>
        </div>

        <PravaInput
          label="Email address"
          type="email"
          placeholder="Email address"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          autoComplete="email"
          suffixIcon={
            email ? (
              isEmailValid(normalizedEmail)
                ? <CheckCircle className="h-4 w-4 text-prava-success" />
                : <XCircle className="h-4 w-4 text-prava-error" />
            ) : null
          }
          className="rounded-full bg-prava-light-bg py-3 dark:bg-prava-dark-bg"
        />

        <div className="pt-3">
          <AuthSubmitButton label="Send verification code" loading={loading} disabled={!canSubmit} />
        </div>
      </form>

      <p className="mt-5 text-center text-body-sm text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
        Already have an account?{' '}
        <Link to="/login" className="font-bold text-prava-accent">
          Sign in
        </Link>
      </p>
    </AuthFrame>
  );
}
