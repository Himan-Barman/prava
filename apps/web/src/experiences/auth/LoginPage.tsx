import { useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Lock, ArrowRight } from 'lucide-react';
import {
  PravaBackground,
  GlassCard,
  PravaInput,
  PravaPasswordInput,
  PravaButton
} from '../../ui-system';
import { useAuth } from '../../context/auth-context';
import { authService } from '../../services/auth-service';
import { ApiException } from '../../adapters/api-client';
import { smartToast } from '../../ui-system/components/SmartToast';

export default function LoginPage() {
  const navigate = useNavigate();
  const { login, setUser } = useAuth();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const canSubmit = email.trim().length > 0 && password.length > 0;

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!canSubmit || loading) return;

    setLoading(true);

    try {
      const session = await login(email.trim(), password);

      if (!session.isVerified) {
        // User needs to verify email first
        await authService.requestEmailOtp(session.email);
        smartToast.success(`Verification code sent to ${session.email}`);
        navigate('/verify-email', { state: { email: session.email, flow: 'verify' } });
        return;
      }

      smartToast.success('Welcome back!');
      navigate('/feed');
    } catch (err) {
      const message = err instanceof ApiException
        ? err.message
        : 'Login failed, please try again';
      smartToast.error(message);
    } finally {
      setLoading(false);
    }
  };

  const handleDevLogin = () => {
    setUser({
      id: 'dev-user-id',
      email: 'dev@example.com',
      isVerified: true,
    });
    // Store a dummy token to persist session if auth service checks it
    localStorage.setItem('prava_token', 'dev-token');

    smartToast.success('Dev login active');
    navigate('/feed');
  };

  const isDev = import.meta.env.DEV || window.location.hostname === 'localhost';

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
            className="mb-7"
          >
            <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary tracking-[-0.8px]">
              Prava
            </h1>
            <p className="mt-2.5 text-body-lg text-prava-light-text-secondary dark:text-prava-dark-text-secondary tracking-[0.2px]">
              Sign in to your private workspace
            </p>
          </motion.div>

          {/* Login Card */}
          <GlassCard delay={0.12} className="mb-5">
            <h2 className="text-h2 text-prava-light-text-primary dark:text-prava-dark-text-primary tracking-[-0.3px]">
              Welcome back
            </h2>
            <p className="mt-1.5 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              Use your Prava ID or email to continue.
            </p>

            <form onSubmit={handleSubmit} className="mt-6 space-y-4">
              <PravaInput
                placeholder="Email or username"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                autoComplete="email"
              />

              <PravaPasswordInput
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="current-password"
              />

              <div className="flex justify-end">
                <Link
                  to="/forgot-password"
                  className="text-caption font-semibold text-prava-accent hover:text-prava-accent-muted transition-colors"
                >
                  Forgot password?
                </Link>
              </div>

              <motion.div
                animate={{ opacity: canSubmit ? 1 : 0.6 }}
                transition={{ duration: 0.16 }}
              >
                <PravaButton
                  type="submit"
                  label="Sign In"
                  loading={loading}
                  disabled={!canSubmit}
                />
              </motion.div>
            </form>
          </GlassCard>

          {/* Signup Link */}
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.56, delay: 0.2, ease: [0.4, 0, 0.2, 1] }}
            className="flex justify-center"
          >
            <Link
              to="/signup"
              className="inline-flex items-center gap-1.5 px-4 py-3 rounded-[18px] 
                bg-white/75 dark:bg-white/[0.04]
                border border-black/[0.06] dark:border-white/[0.1]
                hover:bg-white dark:hover:bg-white/[0.08]
                transition-all duration-200"
            >
              <span className="text-body-sm text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
                New here?
              </span>
              <span className="text-body-sm font-semibold text-prava-accent">
                Create account
              </span>
              <ArrowRight className="w-4 h-4 text-prava-accent" />
            </Link>
          </motion.div>
        </div>

        {/* Dev Login */}
        {isDev && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 1 }}
            className="mt-8 flex justify-center"
          >
            <button
              onClick={handleDevLogin}
              className="text-caption font-semibold text-prava-accent hover:text-prava-accent-muted transition-colors opacity-60 hover:opacity-100"
            >
              Dev login (debug only)
            </button>
          </motion.div>
        )}
      </main>

      {/* Security Footer */}
      <motion.footer
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 1.6, delay: 0.5 }}
        className="py-4 flex justify-center"
      >
        <motion.div
          className="flex items-center gap-1.5"
          animate={{ opacity: [0.35, 0.9, 0.35] }}
          transition={{ duration: 3, repeat: Infinity, ease: 'easeInOut' }}
        >
          <Lock className="w-4 h-4 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary" />
          <span className="text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary tracking-[0.2px]">
            End-to-end encrypted
          </span>
        </motion.div>
      </motion.footer>
    </div>
  );
}
