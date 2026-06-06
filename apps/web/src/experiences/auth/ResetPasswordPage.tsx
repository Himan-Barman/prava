import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
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
  if (score < 0.4) return '#E5533D';
  if (score < 0.7) return '#F4C430';
  return '#3CCB7F';
}

export default function ResetPasswordPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const state = location.state as LocationState | null;

  const [token, setToken] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
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
      actionLabel="Request Code"
      actionTo="/forgot-password"
    >
      <form onSubmit={handleSubmit} className="auth-form">
        <div className="auth-field">
          <label className="auth-label">6-digit reset code</label>
          <input
            placeholder="123456"
            value={token}
            onChange={(e) => setToken(e.target.value.replace(/\D/g, '').slice(0, 6))}
            inputMode="numeric"
            autoComplete="one-time-code"
            className="auth-input"
          />
        </div>

        <div className="auth-field">
          <label className="auth-label">New password</label>
          <div className="auth-input-wrap">
            <input
              type={showPassword ? 'text' : 'password'}
              placeholder="Create a strong password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="new-password"
              className="auth-input auth-input--has-suffix"
            />
            <button
              type="button"
              onClick={() => setShowPassword(!showPassword)}
              className="auth-input-toggle"
            >
              {showPassword ? 'Hide' : 'Show'}
            </button>
          </div>
        </div>

        {/* Strength bar */}
        {password.length > 0 && (
          <div className="auth-strength">
            <div className="auth-strength-track">
              <div
                className="auth-strength-fill"
                style={{
                  width: `${Math.max(6, passwordScore * 100)}%`,
                  background: strengthColor(passwordScore),
                }}
              />
            </div>
          </div>
        )}

        <div className="auth-field">
          <label className="auth-label">Confirm password</label>
          <div className="auth-input-wrap">
            <input
              type={showConfirm ? 'text' : 'password'}
              placeholder="Re-enter your password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              autoComplete="new-password"
              className="auth-input auth-input--has-suffix"
            />
            <button
              type="button"
              onClick={() => setShowConfirm(!showConfirm)}
              className="auth-input-toggle"
            >
              {showConfirm ? 'Hide' : 'Show'}
            </button>
          </div>
          {confirmPassword && !passwordMatch && (
            <p className="auth-field-error">Passwords must match</p>
          )}
        </div>

        <AuthSubmitButton label="Update password" loading={loading} disabled={!canSubmit} />
      </form>

      <p className="auth-alt-text">
        Need a new code?{' '}
        <Link to="/forgot-password" className="auth-alt-link">Send again</Link>
      </p>
    </AuthFrame>
  );
}
