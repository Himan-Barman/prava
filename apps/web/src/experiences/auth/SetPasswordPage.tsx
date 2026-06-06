import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { CheckCircle } from 'lucide-react';
import { PravaPasswordInput } from '../../ui-system';
import { useAuth } from '../../context/auth-context';
import { ApiException } from '../../adapters/api-client';
import { smartToast } from '../../ui-system/components/SmartToast';
import { AuthFrame, AuthStepProgress, AuthSubmitButton } from './AuthFrame';

interface LocationState {
  email: string;
  username?: string;
}

function getErrorMessage(error: unknown): string {
  if (error instanceof ApiException) return error.message;
  if (error instanceof Error) return error.message;
  return String(error ?? '');
}

function shouldAutoLoginAfterRegisterError(error: unknown): boolean {
  if (error instanceof ApiException && typeof error.statusCode === 'number' && error.statusCode >= 500) {
    return true;
  }
  return /account created|email already exists|please sign in/i.test(getErrorMessage(error));
}

async function loginWithRetry(
  loginFn: (email: string, password: string) => Promise<unknown>,
  email: string,
  password: string,
) {
  for (let index = 0; index < 3; index += 1) {
    try {
      await loginFn(email, password);
      return true;
    } catch {
      if (index < 2) {
        await new Promise((resolve) => window.setTimeout(resolve, 400));
      }
    }
  }
  return false;
}

function getPasswordScore(password: string) {
  let score = 0;
  if (password.length >= 12) score += 0.25;
  if (/[A-Z]/.test(password)) score += 0.15;
  if (/[a-z]/.test(password)) score += 0.15;
  if (/\d/.test(password)) score += 0.2;
  if (/[!@#$&*~%^()\-_=+]/.test(password)) score += 0.25;
  return Math.min(1, Math.max(0, score));
}

function strengthColor(score: number) {
  if (score < 0.4) return 'bg-prava-error';
  if (score < 0.7) return 'bg-prava-warning';
  return 'bg-prava-success';
}

function RuleItem({ label, satisfied }: { label: string; satisfied: boolean }) {
  return (
    <div className="flex items-center gap-2">
      <CheckCircle className={`h-4 w-4 ${satisfied ? 'text-prava-success' : 'text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary'}`} />
      <span className={`text-caption ${satisfied ? 'text-prava-success' : 'text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary'}`}>
        {label}
      </span>
    </div>
  );
}

export default function SetPasswordPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { register, login } = useAuth();
  const state = location.state as LocationState | null;
  const searchParams = new URLSearchParams(location.search);

  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const email = (state?.email || searchParams.get('email') || '').trim();
  const username = (state?.username || searchParams.get('username') || '').trim() || undefined;

  useEffect(() => {
    if (!email) navigate('/signup', { replace: true });
  }, [email, navigate]);

  const hasLength = password.length >= 12;
  const hasUpper = /[A-Z]/.test(password);
  const hasLower = /[a-z]/.test(password);
  const hasNumber = /\d/.test(password);
  const hasSymbol = /[!@#$&*~%^()\-_=+]/.test(password);
  const matches = confirmPassword.length > 0 && confirmPassword === password;
  const passwordScore = useMemo(() => getPasswordScore(password), [password]);
  const canSubmit = hasLength && hasUpper && hasLower && hasNumber && hasSymbol && matches && !loading;

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    if (!canSubmit) return;
    setLoading(true);

    try {
      const session = await register(email, password, username);
      if (!session.isVerified) smartToast.info('Check your email to verify the account');
      smartToast.success('Account created successfully');
      navigate('/set-details', { replace: true });
    } catch (err) {
      if (shouldAutoLoginAfterRegisterError(err)) {
        const loggedIn = await loginWithRetry(login, email, password);
        if (loggedIn) {
          smartToast.success('Account created successfully');
          navigate('/set-details', { replace: true });
          return;
        }
      }
      smartToast.error(getErrorMessage(err) || 'Failed to set password');
    } finally {
      setLoading(false);
    }
  };

  if (!email) return null;

  return (
    <AuthFrame
      title="Set Password"
      subtitle="Create a strong password to protect your private workspace."
      sideTitle="Lock your account securely"
    >
      <AuthStepProgress current={3} />

      <form onSubmit={handleSubmit} className="space-y-4">
        <PravaPasswordInput
          label="Password"
          placeholder="Password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          autoComplete="new-password"
          className="rounded-full bg-prava-light-bg py-3 dark:bg-prava-dark-bg"
        />

        <div className="h-1.5 overflow-hidden rounded-full bg-black/10 dark:bg-white/12">
          <div
            className={`h-full transition-all duration-200 ${strengthColor(passwordScore)}`}
            style={{ width: `${Math.max(6, passwordScore * 100)}%` }}
          />
        </div>

        <div className="grid grid-cols-1 gap-1.5 sm:grid-cols-2">
          <RuleItem label="12+ characters" satisfied={hasLength} />
          <RuleItem label="Uppercase letter" satisfied={hasUpper} />
          <RuleItem label="Lowercase letter" satisfied={hasLower} />
          <RuleItem label="Number" satisfied={hasNumber} />
          <RuleItem label="Symbol" satisfied={hasSymbol} />
        </div>

        <PravaPasswordInput
          label="Confirm password"
          placeholder="Confirm password"
          value={confirmPassword}
          onChange={(event) => setConfirmPassword(event.target.value)}
          autoComplete="new-password"
          error={confirmPassword && !matches ? 'Passwords must match' : undefined}
          className="rounded-full bg-prava-light-bg py-3 dark:bg-prava-dark-bg"
        />

        <div className="pt-3">
          <AuthSubmitButton label="Set password" loading={loading} disabled={!canSubmit} />
        </div>
      </form>

      <p className="mt-5 text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
        Passwords are protected with Argon2id hashing.
      </p>
    </AuthFrame>
  );
}
