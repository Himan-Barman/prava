import { useState, useEffect, type FormEvent } from 'react';
import { useLocation, useNavigate, Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Shield, CheckCircle } from 'lucide-react';
import {
  PravaBackground,
  GlassCard,
  PravaPasswordInput,
  PravaButton
} from '../../ui-system';
import { useAuth } from '../../context/auth-context';
import { ApiException } from '../../adapters/api-client';
import toast from 'react-hot-toast';

interface LocationState {
  email: string;
  username?: string;
}

export default function SetPasswordPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { register } = useAuth();
  const state = location.state as LocationState | null;

  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const email = state?.email || '';
  const username = state?.username;

  // Redirect if no email
  useEffect(() => {
    if (!email) {
      navigate('/signup');
    }
  }, [email, navigate]);

  const isPasswordValid = password.length >= 8;
  const passwordsMatch = password === confirmPassword && confirmPassword.length > 0;
  const canSubmit = isPasswordValid && passwordsMatch && !loading;

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!canSubmit) {
      if (!isPasswordValid) {
        toast.error('Password must be at least 8 characters');
      } else if (!passwordsMatch) {
        toast.error('Passwords do not match');
      }
      return;
    }

    setLoading(true);

    try {
      await register(email, password, username);
      toast.success('Account created successfully!');
      navigate('/feed');
    } catch (err) {
      const message = err instanceof ApiException
        ? err.message
        : 'Registration failed, please try again';
      toast.error(message);
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
          {/* Header */}
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.52, ease: [0.4, 0, 0.2, 1] }}
            className="mb-4"
          >
            <div className="flex items-start justify-between gap-3">
              <div className="flex-1">
                <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary tracking-[-0.6px]">
                  Create password
                </h1>
                <p className="mt-2 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
                  Choose a strong password to secure your account.
                </p>
              </div>

              {/* Step Badge */}
              <div className="shrink-0 px-3 py-2 rounded-full bg-black/[0.04] dark:bg-white/[0.08] border border-black/[0.08] dark:border-white/[0.16]">
                <span className="text-caption font-semibold text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
                  Step 3 of 3
                </span>
              </div>
            </div>

            {/* Step Indicator */}
            <div className="flex gap-1.5 mt-4">
              <div className="h-1.5 w-9 rounded-full bg-prava-accent" />
              <div className="h-1.5 w-9 rounded-full bg-prava-accent" />
              <div className="h-1.5 w-9 rounded-full bg-prava-accent" />
            </div>
          </motion.div>

          {/* Password Card */}
          <GlassCard delay={0.12} className="mt-5 mb-6">
            {/* Account Info */}
            <div className="flex items-center gap-3 p-3 rounded-[14px] bg-prava-success/10 mb-5">
              <div className="p-2 rounded-full bg-prava-success/20">
                <CheckCircle className="w-5 h-5 text-prava-success" />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-body-sm font-medium text-prava-light-text-primary dark:text-prava-dark-text-primary truncate">
                  {email}
                </p>
                {username && (
                  <p className="text-caption text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
                    @{username}
                  </p>
                )}
              </div>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              <PravaPasswordInput
                label="Password"
                placeholder="Create a strong password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="new-password"
                showStrength
              />

              <PravaPasswordInput
                label="Confirm password"
                placeholder="Re-enter your password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                autoComplete="new-password"
                error={
                  confirmPassword && !passwordsMatch
                    ? 'Passwords do not match'
                    : undefined
                }
              />

              {/* Security Hint */}
              <div className="flex items-start gap-2 p-3 rounded-[12px] bg-prava-accent/10">
                <Shield className="w-4 h-4 text-prava-accent mt-0.5 shrink-0" />
                <p className="text-caption text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
                  Your password is hashed with Argon2 — the most secure hashing algorithm available.
                </p>
              </div>

              <PravaButton
                type="submit"
                label="Complete Registration"
                loading={loading}
                disabled={!canSubmit}
              />
            </form>
          </GlassCard>

          {/* Back Link */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.3 }}
            className="text-center"
          >
            <Link
              to="/signup"
              className="text-body font-semibold text-prava-accent hover:text-prava-accent-muted transition-colors"
            >
              Start over
            </Link>
          </motion.div>
        </div>
      </main>
    </div>
  );
}
