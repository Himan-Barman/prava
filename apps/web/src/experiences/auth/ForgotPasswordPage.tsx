import { useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Mail } from 'lucide-react';
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
      subtitle="Enter your email and we'll send a secure 6-digit reset code."
      actionLabel="Sign In"
      actionTo="/login"
    >
      <form onSubmit={handleSubmit} className="auth-form">
        <div className="auth-field">
          <label className="auth-label">Email address</label>
          <input
            type="email"
            placeholder="Enter your email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="email"
            className="auth-input"
          />
        </div>

        <AuthSubmitButton
          label={sent ? 'Resend reset code' : 'Send reset code'}
          loading={loading}
          disabled={!canSubmit}
        />
      </form>

      {sent && (
        <div className="auth-info-card">
          <div className="auth-info-icon">
            <Mail size={18} />
          </div>
          <h3 className="auth-info-title">Check your inbox</h3>
          <p className="auth-info-desc">
            We sent a reset code to <strong>{normalizedEmail}</strong>. Codes expire in 10 minutes.
          </p>
          <button
            type="button"
            onClick={() => navigate('/reset-password', { state: { email: normalizedEmail } })}
            className="auth-info-action"
          >
            Enter reset code
          </button>
        </div>
      )}

      <p className="auth-alt-text">
        Remembered it?{' '}
        <Link to="/login" className="auth-alt-link">Sign in</Link>
      </p>
    </AuthFrame>
  );
}
