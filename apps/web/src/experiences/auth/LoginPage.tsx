import { useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { LogIn } from 'lucide-react';
import { useAuth } from '../../context/auth-context';
import { authService } from '../../services/auth-service';
import { ApiException } from '../../adapters/api-client';
import { smartToast } from '../../ui-system/components/SmartToast';
import { AuthFrame, AuthSubmitButton } from './AuthFrame';

const IS_DEV = import.meta.env.DEV;

export default function LoginPage() {
  const navigate = useNavigate();
  const { login, setUser } = useAuth();

  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);

  const canSubmit = identifier.trim().length > 0 && password.length > 0 && !loading;

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    if (!canSubmit) {
      smartToast.warning('Username / email and password are required');
      return;
    }

    setLoading(true);

    try {
      const session = await login(identifier.trim(), password);

      if (!session.isVerified) {
        await authService.requestEmailOtp(session.email);
        smartToast.info(`Verification code sent to ${session.email}`);
        navigate('/verify-email', {
          state: { email: session.email, flow: 'verify' },
        });
        return;
      }

      smartToast.success('Welcome back');
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

  const handleDemoLogin = () => {
    setUser({
      id: 'demo-user-001',
      email: 'demo@prava.app',
      username: 'demouser',
      displayName: 'Demo User',
      isVerified: true,
    });
    smartToast.success('Logged in as Demo User');
    navigate('/feed');
  };

  return (
    <AuthFrame
      title="Welcome back"
      subtitle="Sign in with your Prava username or email to continue."
      actionLabel="Create Account"
      actionTo="/signup"
    >
      <form onSubmit={handleSubmit} className="auth-form">
        <div className="auth-field">
          <label className="auth-label">Email or Username</label>
          <input
            type="text"
            placeholder="Enter your email or username"
            value={identifier}
            onChange={(e) => setIdentifier(e.target.value)}
            autoComplete="username"
            className="auth-input"
          />
        </div>

        <div className="auth-field">
          <div className="auth-label-row">
            <label className="auth-label">Password</label>
            <Link to="/forgot-password" className="auth-link-sm">Forgot password?</Link>
          </div>
          <div className="auth-input-wrap">
            <input
              type={showPassword ? 'text' : 'password'}
              placeholder="Enter your password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
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

        <AuthSubmitButton label="Sign In" loading={loading} disabled={!canSubmit} />
      </form>

      {IS_DEV && (
        <>
          <div className="auth-divider">
            <span>dev only</span>
          </div>
          <button
            type="button"
            onClick={handleDemoLogin}
            id="demo-login-btn"
            className="auth-submit"
            style={{
              background: 'linear-gradient(135deg, #137A50 0%, #14845D 100%)',
              boxShadow: '0 8px 28px rgba(19, 122, 80, 0.28)',
            }}
          >
            Demo Login (Skip Auth)
          </button>
        </>
      )}

      <div className="auth-divider">
        <span>or</span>
      </div>

      <p className="auth-alt-text">
        Don't have an account?{' '}
        <Link to="/signup" className="auth-alt-link">
          <LogIn size={14} />
          Create account
        </Link>
      </p>
    </AuthFrame>
  );
}
