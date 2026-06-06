import { useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { LogIn } from 'lucide-react';
import { PravaInput } from '../../ui-system';
import { authService } from '../../services/auth-service';
import { ApiException } from '../../adapters/api-client';
import { smartToast } from '../../ui-system/components/SmartToast';
import { AuthFrame, AuthSubmitButton } from './AuthFrame';

export default function ForgotPasswordPage() {
  const navigate = useNavigate();

  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);

  const normalizedEmail = email.trim().toLowerCase();
  const isEmailValid = /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalizedEmail);
  const canSubmit = isEmailValid && !loading;

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
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
      const message = err instanceof ApiException ? err.message : 'Unable to send reset code';
      smartToast.error(message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthFrame
      title="Reset Password"
      subtitle="Enter your email and we will send a secure 6-digit reset code."
      sideTitle="Recover access safely"
      actionLabel="Sign In"
      actionTo="/login"
      actionIcon={<LogIn className="h-4 w-4" strokeWidth={3} />}
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        <PravaInput
          label="Email address"
          type="email"
          placeholder="Email address"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          autoComplete="email"
          className="rounded-full bg-prava-light-bg py-3 dark:bg-prava-dark-bg"
        />

        <div className="pt-3">
          <AuthSubmitButton
            label={sent ? 'Resend reset code' : 'Send reset code'}
            loading={loading}
            disabled={!canSubmit}
          />
        </div>
      </form>

      {sent && (
        <div className="mt-6 rounded-[18px] bg-prava-light-surface p-4 dark:bg-white/[0.08]">
          <h2 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary">
            Check your inbox
          </h2>
          <p className="mt-1 text-body-sm text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
            We sent a reset code to {normalizedEmail}. Codes expire in 10 minutes.
          </p>
          <button
            type="button"
            onClick={() => navigate('/reset-password', { state: { email: normalizedEmail } })}
            className="mt-4 rounded-full bg-prava-accent px-5 py-2.5 text-body-sm font-bold text-white"
          >
            Enter reset code
          </button>
        </div>
      )}

      <p className="mt-5 text-center text-body-sm text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
        Remembered it?{' '}
        <Link to="/login" className="font-bold text-prava-accent">
          Sign in
        </Link>
      </p>
    </AuthFrame>
  );
}
