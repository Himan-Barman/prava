import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { PravaInput, PravaPasswordInput } from '../../ui-system';
import { authService } from '../../services/auth-service';
import { ApiException } from '../../adapters/api-client';
import { smartToast } from '../../ui-system/components/SmartToast';
import { AuthFrame, AuthSubmitButton } from './AuthFrame';

interface LocationState {
  email?: string;
  initialToken?: string;
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

export default function ResetPasswordPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const state = location.state as LocationState | null;

  const [token, setToken] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const email = state?.email?.trim() ?? '';

  useEffect(() => {
    const tokenFromState = state?.initialToken?.trim() ?? '';
    const tokenFromQuery = new URLSearchParams(location.search).get('token')?.trim() ?? '';
    const next = tokenFromState || tokenFromQuery;
    if (next) setToken(next.replace(/\D/g, '').slice(0, 6));
  }, [location.search, state?.initialToken]);

  const passwordScore = useMemo(() => getPasswordScore(password), [password]);
  const tokenValid = /^\d{6}$/.test(token.trim());
  const passwordValid = passwordScore >= 0.7;
  const passwordMatch = password.length > 0 && password === confirmPassword;
  const canSubmit = tokenValid && passwordValid && passwordMatch && !loading;

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    if (!canSubmit) return;

    setLoading(true);

    try {
      await authService.confirmPasswordReset(token.trim(), password);
      smartToast.success('Password updated. Sign in again.');
      navigate('/login', { replace: true });
    } catch (err) {
      const message = err instanceof ApiException ? err.message : 'Unable to reset password';
      smartToast.error(message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthFrame
      title="Set New Password"
      subtitle={email ? `Enter the reset code sent to ${email}.` : 'Enter your reset code and choose a new password.'}
      sideTitle="Set a safer password"
      actionLabel="Request Code"
      actionTo="/forgot-password"
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        <PravaInput
          label="6-digit reset code"
          placeholder="123456"
          value={token}
          onChange={(event) => setToken(event.target.value.replace(/\D/g, '').slice(0, 6))}
          inputMode="numeric"
          autoComplete="one-time-code"
          className="rounded-full bg-prava-light-bg py-3 dark:bg-prava-dark-bg"
        />

        <PravaPasswordInput
          label="New password"
          placeholder="Create a strong password"
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

        <PravaPasswordInput
          label="Confirm password"
          placeholder="Re-enter your password"
          value={confirmPassword}
          onChange={(event) => setConfirmPassword(event.target.value)}
          autoComplete="new-password"
          error={confirmPassword && !passwordMatch ? 'Passwords must match' : undefined}
          className="rounded-full bg-prava-light-bg py-3 dark:bg-prava-dark-bg"
        />

        <div className="pt-3">
          <AuthSubmitButton label="Update password" loading={loading} disabled={!canSubmit} />
        </div>
      </form>

      <p className="mt-5 text-center text-body-sm text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
        Need a new code?{' '}
        <Link to="/forgot-password" className="font-bold text-prava-accent">
          Send again
        </Link>
      </p>
    </AuthFrame>
  );
}
