import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { ArrowLeft } from 'lucide-react';
import {
  PravaBackground,
  GlassCard,
  PravaInput,
  PravaPasswordInput,
  PravaButton,
} from '../../ui-system';
import { authService } from '../../services/auth-service';
import { ApiException } from '../../adapters/api-client';
import { smartToast } from '../../ui-system/components/SmartToast';

interface LocationState {
  email?: string;
  initialToken?: string;
}

function getPasswordScore(password: string): number {
  let score = 0;
  if (password.length >= 12) score += 0.25;
  if (/[A-Z]/.test(password)) score += 0.15;
  if (/[a-z]/.test(password)) score += 0.15;
  if (/\d/.test(password)) score += 0.2;
  if (/[!@#$&*~%^()\-_=+]/.test(password)) score += 0.25;
  return Math.min(1, Math.max(0, score));
}

function getStrengthColor(score: number): string {
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
    if (tokenFromState) {
      setToken(tokenFromState.replace(/\D/g, '').slice(0, 6));
      return;
    }
    if (tokenFromQuery) {
      setToken(tokenFromQuery.replace(/\D/g, '').slice(0, 6));
    }
  }, [location.search, state?.initialToken]);

  const passwordScore = useMemo(() => getPasswordScore(password), [password]);

  const tokenValid = /^\d{6}$/.test(token.trim());
  const passwordValid = passwordScore >= 0.7;
  const passwordMatch = password.length > 0 && password === confirmPassword;
  const canSubmit = tokenValid && passwordValid && passwordMatch && !loading;

  const subtitle = email
    ? `Enter the 6-digit reset code sent to ${email}.`
    : 'Enter the 6-digit reset code from your email and choose a new password.';

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!canSubmit) return;

    setLoading(true);

    try {
      await authService.confirmPasswordReset(token.trim(), password);
      smartToast.success('Password updated. Sign in again.');
      navigate('/login', { replace: true });
    } catch (err) {
      const message = err instanceof ApiException
        ? err.message
        : 'Unable to reset password';
      smartToast.error(message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen min-h-dvh flex flex-col">
      <PravaBackground />

      <main className="flex-1 flex items-center justify-center px-5 py-8 sm:px-6 sm:py-12">
        <div className="w-full max-w-[440px]">
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.3 }}
            className="mb-6"
          >
            <Link
              to="/forgot-password"
              className="inline-flex items-center gap-2 text-body font-medium text-prava-light-text-secondary dark:text-prava-dark-text-secondary hover:text-prava-light-text-primary dark:hover:text-prava-dark-text-primary transition-colors"
            >
              <ArrowLeft className="w-4 h-4" />
              Back
            </Link>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.52, ease: [0.4, 0, 0.2, 1] }}
            className="mb-6"
          >
            <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary tracking-[-0.6px]">
              Set a new password
            </h1>
            <p className="mt-2 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              {subtitle}
            </p>
          </motion.div>

          <GlassCard delay={0.12}>
            <form onSubmit={handleSubmit} className="space-y-4">
              <PravaInput
                label="6-digit reset code"
                placeholder="123456"
                value={token}
                onChange={(e) => setToken(e.target.value.replace(/\D/g, '').slice(0, 6))}
                inputMode="numeric"
                autoComplete="one-time-code"
              />

              <PravaPasswordInput
                label="New password"
                placeholder="Create a strong password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="new-password"
              />

              <div className="space-y-2">
                <div className="h-1.5 rounded-full bg-black/[0.12] dark:bg-white/[0.12] overflow-hidden">
                  <div
                    className={`h-full transition-all duration-200 ${getStrengthColor(passwordScore)}`}
                    style={{ width: `${Math.max(6, passwordScore * 100)}%` }}
                  />
                </div>
              </div>

              <PravaPasswordInput
                label="Confirm password"
                placeholder="Re-enter your password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                autoComplete="new-password"
                error={
                  confirmPassword && !passwordMatch
                    ? 'Passwords must match'
                    : undefined
                }
              />

              <div className="pt-1">
                <PravaButton
                  type="submit"
                  label="Update password"
                  loading={loading}
                  disabled={!canSubmit}
                />
              </div>

              <p className="text-caption text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
                For security, all active sessions will be signed out.
              </p>
            </form>
          </GlassCard>
        </div>
      </main>
    </div>
  );
}
