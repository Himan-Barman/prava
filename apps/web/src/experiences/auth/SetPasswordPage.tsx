import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Lock } from 'lucide-react';
import {
  PravaBackground,
  GlassCard,
  PravaPasswordInput,
  PravaButton
} from '../../ui-system';
import { useAuth } from '../../context/auth-context';
import { ApiException } from '../../adapters/api-client';
import { smartToast } from '../../ui-system/components/SmartToast';

interface LocationState {
  email: string;
  username?: string;
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

function RuleItem({ label, satisfied }: { label: string; satisfied: boolean }) {
  return (
    <div className="flex items-center gap-2">
      <div
        className={`w-4 h-4 rounded-full border ${satisfied
          ? 'bg-prava-success border-prava-success'
          : 'border-prava-light-border dark:border-prava-dark-border'
          }`}
      />
      <span
        className={`text-caption ${satisfied
          ? 'text-prava-success'
          : 'text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary'
          }`}
      >
        {label}
      </span>
    </div>
  );
}

export default function SetPasswordPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { register } = useAuth();
  const state = location.state as LocationState | null;

  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const email = state?.email?.trim() || '';
  const username = state?.username?.trim();

  useEffect(() => {
    if (!email) {
      navigate('/signup', { replace: true });
    }
  }, [email, navigate]);

  const hasLength = password.length >= 12;
  const hasUpper = /[A-Z]/.test(password);
  const hasLower = /[a-z]/.test(password);
  const hasNumber = /\d/.test(password);
  const hasSymbol = /[!@#$&*~%^()\-_=+]/.test(password);
  const matches = confirmPassword.length > 0 && confirmPassword === password;

  const passwordScore = useMemo(() => getPasswordScore(password), [password]);
  const canSubmit =
    hasLength &&
    hasUpper &&
    hasLower &&
    hasNumber &&
    hasSymbol &&
    matches &&
    !loading;

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!canSubmit) return;

    setLoading(true);

    try {
      const session = await register(email, password, username);

      if (!session.isVerified) {
        smartToast.info('Check your email to verify the account');
      }

      smartToast.success('Password set successfully');
      navigate('/set-details', { replace: true });
    } catch (err) {
      const message = err instanceof ApiException
        ? err.message
        : 'Failed to set password';
      smartToast.error(message);
    } finally {
      setLoading(false);
    }
  };

  if (!email) return null;

  return (
    <div className="min-h-screen min-h-dvh flex flex-col">
      <PravaBackground />

      <main className="flex-1 flex items-center justify-center px-5 py-8 sm:px-6 sm:py-12">
        <div className="w-full max-w-[440px]">
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.52, ease: [0.4, 0, 0.2, 1] }}
            className="mb-6"
          >
            <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary tracking-[-0.6px]">
              Secure your account
            </h1>
            <p className="mt-2 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              Create a strong password to unlock your private workspace.
            </p>
          </motion.div>

          <GlassCard delay={0.12} className="mb-4">
            <div className="flex items-center gap-2 mb-4">
              <Lock className="w-[18px] h-[18px] text-prava-accent" />
              <span className="text-body font-semibold text-prava-light-text-primary dark:text-prava-dark-text-primary">
                Password security
              </span>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              <PravaPasswordInput
                label="Password"
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="new-password"
              />

              <div className="h-1.5 rounded-full bg-black/[0.12] dark:bg-white/[0.12] overflow-hidden">
                <div
                  className={`h-full transition-all duration-200 ${getStrengthColor(passwordScore)}`}
                  style={{ width: `${Math.max(6, passwordScore * 100)}%` }}
                />
              </div>

              <div className="space-y-1.5">
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
                onChange={(e) => setConfirmPassword(e.target.value)}
                autoComplete="new-password"
                error={
                  confirmPassword && !matches
                    ? 'Passwords must match'
                    : undefined
                }
              />

              <PravaButton
                type="submit"
                label="Set password"
                loading={loading}
                disabled={!canSubmit}
              />
            </form>
          </GlassCard>

          <p className="text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
            Protected with Argon2id hashing and zero-knowledge design.
          </p>
        </div>
      </main>
    </div>
  );
}
