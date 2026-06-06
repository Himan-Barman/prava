import { useEffect, useState, type ChangeEvent, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { CheckCircle, Loader2, XCircle } from 'lucide-react';
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

function isUsernameValid(value: string) { return /^[a-z0-9_]{3,32}$/.test(value); }
function isEmailValid(value: string) { return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value); }

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
      if (!normalized) { setUsernameAvailable(false); setUsernameChecked(false); setUsernameCheckFailed(false); return; }
      if (!isUsernameValid(normalized)) { setUsernameAvailable(false); setUsernameChecked(true); setUsernameCheckFailed(false); return; }

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

  const canSubmit = usernameChecked && usernameAvailable && isEmailValid(normalizedEmail) && !loading && !checkingUsername;

  const handleUsernameChange = (event: ChangeEvent<HTMLInputElement>) => {
    const value = event.target.value.toLowerCase().replace(/[^a-z0-9_]/g, '').slice(0, 32);
    setUsername(value);
    setUsernameChecked(false);
  };

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    if (!canSubmit) {
      if (checkingUsername) smartToast.info('Checking username availability');
      else if (usernameCheckFailed) smartToast.warning('Unable to verify username. Try again.');
      else if (!isUsernameValid(username)) smartToast.warning('Username must be 3-32 characters (a-z, 0-9, _)');
      else if (!isEmailValid(normalizedEmail)) smartToast.warning('Enter a valid email address');
      else smartToast.warning('Username is not available');
      return;
    }

    setLoading(true);
    try {
      await authService.requestEmailOtp(normalizedEmail, username);
      smartToast.success('Verification code sent');
      const params = new URLSearchParams({ email: normalizedEmail, username, flow: 'signup' });
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

  const usernameStatusIcon = () => {
    if (!username) return null;
    if (checkingUsername) return <Loader2 className="auth-status-icon auth-status-icon--spin" />;
    if (!isUsernameValid(username)) return <XCircle className="auth-status-icon auth-status-icon--error" />;
    if (usernameCheckFailed) return <XCircle className="auth-status-icon auth-status-icon--warn" />;
    if (usernameChecked && usernameAvailable) return <CheckCircle className="auth-status-icon auth-status-icon--success" />;
    if (usernameChecked) return <XCircle className="auth-status-icon auth-status-icon--error" />;
    return null;
  };

  const emailStatusIcon = () => {
    if (!email) return null;
    return isEmailValid(normalizedEmail)
      ? <CheckCircle className="auth-status-icon auth-status-icon--success" />
      : <XCircle className="auth-status-icon auth-status-icon--error" />;
  };

  return (
    <AuthFrame
      title="Create Account"
      subtitle="Choose a Prava ID and verify your email before setting a password."
      actionLabel="Sign In"
      actionTo="/login"
    >
      <AuthStepProgress current={1} />

      <form onSubmit={handleSubmit} className="auth-form">
        <div className="auth-field">
          <label className="auth-label">Prava ID</label>
          <div className="auth-input-wrap">
            <span className="auth-input-prefix">@</span>
            <input
              value={username}
              onChange={handleUsernameChange}
              placeholder="username"
              autoComplete="username"
              className="auth-input auth-input--has-prefix auth-input--has-suffix"
            />
            <span className="auth-input-suffix">{usernameStatusIcon()}</span>
          </div>
        </div>

        <div className="auth-field">
          <label className="auth-label">Email address</label>
          <div className="auth-input-wrap">
            <input
              type="email"
              placeholder="Enter your email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="email"
              className="auth-input auth-input--has-suffix"
            />
            <span className="auth-input-suffix">{emailStatusIcon()}</span>
          </div>
        </div>

        <AuthSubmitButton label="Send verification code" loading={loading} disabled={!canSubmit} />
      </form>

      <p className="auth-alt-text">
        Already have an account?{' '}
        <Link to="/login" className="auth-alt-link">Sign in</Link>
      </p>
    </AuthFrame>
  );
}
