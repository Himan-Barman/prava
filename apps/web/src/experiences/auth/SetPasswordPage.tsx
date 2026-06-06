import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { CheckCircle } from 'lucide-react';
import { useAuth } from '../../context/auth-context';
import { ApiException } from '../../adapters/api-client';
import { smartToast } from '../../ui-system/components/SmartToast';
import { AuthFrame, AuthStepProgress, AuthSubmitButton } from './AuthFrame';

interface LocationState {
  email: string;
  username?: string;
}

function getErrorMessage(error: unknown): string {
  if (error instanceof ApiException) return error.message;
  if (error instanceof Error) return error.message;
  return String(error ?? '');
}

function shouldAutoLoginAfterRegisterError(error: unknown): boolean {
  if (error instanceof ApiException && typeof error.statusCode === 'number' && error.statusCode >= 500) return true;
  return /account created|email already exists|please sign in/i.test(getErrorMessage(error));
}

async function loginWithRetry(
  loginFn: (email: string, password: string) => Promise<unknown>,
  email: string,
  password: string,
) {
  for (let index = 0; index < 3; index += 1) {
    try {
      await loginFn(email, password);
      return true;
    } catch {
      if (index < 2) await new Promise((resolve) => window.setTimeout(resolve, 400));
    }
  }
  return false;
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

function strengthLabel(score: number) {
  if (score < 0.4) return 'Weak';
  if (score < 0.7) return 'Fair';
  return 'Strong';
}

function strengthColor(score: number) {
  if (score < 0.4) return '#E5533D';
  if (score < 0.7) return '#F4C430';
  return '#3CCB7F';
}

function RuleItem({ label, satisfied }: { label: string; satisfied: boolean }) {
  return (
    <div className="auth-rule-item">
      <CheckCircle
        size={14}
        style={{ color: satisfied ? '#3CCB7F' : '#3a3a3a' }}
      />
      <span style={{ color: satisfied ? '#b3b3b3' : '#5a5a5a' }}>{label}</span>
    </div>
  );
}

export default function SetPasswordPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { register, login } = useAuth();
  const state = location.state as LocationState | null;
  const searchParams = new URLSearchParams(location.search);

  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [loading, setLoading] = useState(false);

  const email = (state?.email || searchParams.get('email') || '').trim();
  const username = (state?.username || searchParams.get('username') || '').trim() || undefined;

  useEffect(() => {
    if (!email) navigate('/signup', { replace: true });
  }, [email, navigate]);

  const hasLength = password.length >= 12;
  const hasUpper = /[A-Z]/.test(password);
  const hasLower = /[a-z]/.test(password);
  const hasNumber = /\d/.test(password);
  const hasSymbol = /[!@#$&*~%^()\-_=+]/.test(password);
  const matches = confirmPassword.length > 0 && confirmPassword === password;
  const passwordScore = useMemo(() => getPasswordScore(password), [password]);
  const canSubmit = hasLength && hasUpper && hasLower && hasNumber && hasSymbol && matches && !loading;

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    if (!canSubmit) return;
    setLoading(true);

    try {
      const session = await register(email, password, username);
      if (!session.isVerified) smartToast.info('Check your email to verify the account');
      smartToast.success('Account created successfully');
      navigate('/set-details', { replace: true });
    } catch (err) {
      if (shouldAutoLoginAfterRegisterError(err)) {
        const loggedIn = await loginWithRetry(login, email, password);
        if (loggedIn) {
          smartToast.success('Account created successfully');
          navigate('/set-details', { replace: true });
          return;
        }
      }
      smartToast.error(getErrorMessage(err) || 'Failed to set password');
    } finally {
      setLoading(false);
    }
  };

  if (!email) return null;

  return (
    <AuthFrame
      title="Set Password"
      subtitle="Create a strong password to protect your private workspace."
    >
      <AuthStepProgress current={3} />

      <form onSubmit={handleSubmit} className="auth-form">
        {/* Password field */}
        <div className="auth-field">
          <label className="auth-label">Password</label>
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
            <span className="auth-strength-label" style={{ color: strengthColor(passwordScore) }}>
              {strengthLabel(passwordScore)}
            </span>
          </div>
        )}

        {/* Password rules */}
        <div className="auth-rules">
          <RuleItem label="12+ characters" satisfied={hasLength} />
          <RuleItem label="Uppercase letter" satisfied={hasUpper} />
          <RuleItem label="Lowercase letter" satisfied={hasLower} />
          <RuleItem label="Number" satisfied={hasNumber} />
          <RuleItem label="Symbol (!@#$…)" satisfied={hasSymbol} />
        </div>

        {/* Confirm password */}
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
          {confirmPassword && !matches && (
            <p className="auth-field-error">Passwords must match</p>
          )}
        </div>

        <AuthSubmitButton label="Set password" loading={loading} disabled={!canSubmit} />
      </form>

      <p className="auth-hint">
        Passwords are protected with Argon2id hashing.
      </p>
    </AuthFrame>
  );
}
