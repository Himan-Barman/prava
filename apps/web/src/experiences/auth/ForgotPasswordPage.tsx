import { useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { ArrowLeft, Mail } from 'lucide-react';
import {
  PravaBackground,
  GlassCard,
  PravaInput,
  PravaButton
} from '../../ui-system';
import { authService } from '../../services/auth-service';
import toast from 'react-hot-toast';

export default function ForgotPasswordPage() {
  const navigate = useNavigate();

  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);

  const isEmailValid = /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email);
  const canSubmit = isEmailValid && !loading;

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!canSubmit) return;

    setLoading(true);

    try {
      await authService.requestPasswordReset(email.toLowerCase());
      setSent(true);
      toast.success('Password reset link sent');
    } catch (err) {
      // Don't reveal if email exists or not for security
      setSent(true);
      toast.success('If an account exists, a reset link has been sent');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen min-h-dvh flex flex-col">
      <PravaBackground />

      <main className="flex-1 flex items-center justify-center px-5 py-8 sm:px-6 sm:py-12">
        <div className="w-full max-w-[440px]">
          {/* Back Link */}
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

          {/* Header */}
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.52, ease: [0.4, 0, 0.2, 1] }}
            className="mb-6"
          >
            <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary tracking-[-0.6px]">
              Reset password
            </h1>
            <p className="mt-2 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              {sent
                ? "Check your email for a password reset link."
                : "Enter your email and we'll send you a reset link."
              }
            </p>
          </motion.div>

          {/* Card */}
          <GlassCard delay={0.12}>
            {sent ? (
              <div className="text-center py-4">
                <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-prava-success/10 flex items-center justify-center">
                  <Mail className="w-8 h-8 text-prava-success" />
                </div>
                <h2 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary mb-2">
                  Check your inbox
                </h2>
                <p className="text-body-sm text-prava-light-text-secondary dark:text-prava-dark-text-secondary mb-6">
                  We've sent a password reset link to <strong>{email}</strong>
                </p>
                <PravaButton
                  label="Back to login"
                  variant="ghost"
                  onClick={() => navigate('/login')}
                />
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="space-y-5">
                <PravaInput
                  label="Email address"
                  type="email"
                  placeholder="Enter your email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  autoComplete="email"
                />

                <PravaButton
                  type="submit"
                  label="Send reset link"
                  loading={loading}
                  disabled={!canSubmit}
                />
              </form>
            )}
          </GlassCard>
        </div>
      </main>
    </div>
  );
}
