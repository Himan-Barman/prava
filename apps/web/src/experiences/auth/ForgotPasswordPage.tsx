import { useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { ArrowLeft } from 'lucide-react';
import {
  PravaBackground,
  GlassCard,
  PravaInput,
  PravaButton
} from '../../ui-system';
import { authService } from '../../services/auth-service';
import { ApiException } from '../../adapters/api-client';
import { smartToast } from '../../ui-system/components/SmartToast';

export default function ForgotPasswordPage() {
  const navigate = useNavigate();

  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);

  const normalizedEmail = email.trim().toLowerCase();
  const isEmailValid = /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalizedEmail);
  const canSubmit = isEmailValid && !loading;

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!canSubmit) {
      smartToast.warning('Enter a valid email address');
      return;
    }

    setLoading(true);

    try {
      await authService.requestPasswordReset(normalizedEmail);
      setSent(true);
      smartToast.info('If an account exists, we sent a reset code');
    } catch (err) {
      const message = err instanceof ApiException
        ? err.message
        : 'Unable to send reset code';
      smartToast.error(message);
    } finally {
      setLoading(false);
    }
  };

  const handleOpenReset = () => {
    navigate('/reset-password', {
      state: {
        email: normalizedEmail,
      },
    });
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
              to="/login"
              className="inline-flex items-center gap-2 text-body font-medium text-prava-light-text-secondary dark:text-prava-dark-text-secondary hover:text-prava-light-text-primary dark:hover:text-prava-dark-text-primary transition-colors"
            >
              <ArrowLeft className="w-4 h-4" />
              Back to login
            </Link>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.52, ease: [0.4, 0, 0.2, 1] }}
            className="mb-6"
          >
            <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary tracking-[-0.6px]">
              Reset your password
            </h1>
            <p className="mt-2 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              Enter your email and we will send a secure reset code.
            </p>
          </motion.div>

          <GlassCard delay={0.12}>
            <form onSubmit={handleSubmit} className="space-y-5">
              <PravaInput
                label="Email address"
                type="email"
                placeholder="Email address"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                autoComplete="email"
              />

              <PravaButton
                type="submit"
                label={sent ? 'Resend reset code' : 'Send reset code'}
                loading={loading}
                disabled={!canSubmit}
              />
            </form>

            {sent && (
              <div className="mt-5 p-4 rounded-[16px] bg-black/[0.04] dark:bg-white/[0.04] border border-black/[0.08] dark:border-white/[0.08]">
                <h2 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary">
                  Check your inbox
                </h2>
                <p className="mt-1 text-body-sm text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
                  We sent a reset code to {normalizedEmail}.
                </p>
                <p className="mt-1 text-caption text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
                  Reset codes expire in 10 minutes.
                </p>
                <div className="mt-4">
                  <PravaButton
                    label="Enter reset code"
                    onClick={handleOpenReset}
                  />
                </div>
              </div>
            )}
          </GlassCard>
        </div>
      </main>
    </div>
  );
}
