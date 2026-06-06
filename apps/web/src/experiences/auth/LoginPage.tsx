import { useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { LogIn, UserPlus } from 'lucide-react';
import { PravaInput, PravaPasswordInput } from '../../ui-system';
import { useAuth } from '../../context/auth-context';
import { authService } from '../../services/auth-service';
import { ApiException } from '../../adapters/api-client';
import { smartToast } from '../../ui-system/components/SmartToast';
import { AuthFrame, AuthSubmitButton } from './AuthFrame';

export default function LoginPage() {
  const navigate = useNavigate();
  const { login } = useAuth();

  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
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

  return (
    <AuthFrame
      title="Sign In"
      subtitle="Use your Prava username or email to continue."
      sideTitle="Manage your private network"
      actionLabel="Sign Up"
      actionTo="/signup"
      actionIcon={<UserPlus className="h-4 w-4" strokeWidth={3} />}
      footer={
        <>
          <span>2026 Prava</span>
          <Link to="/forgot-password" className="font-semibold text-prava-accent">
            Forgot password?
          </Link>
        </>
      }
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        <PravaInput
          placeholder="Email or Username"
          type="text"
          value={identifier}
          onChange={(event) => setIdentifier(event.target.value)}
          autoComplete="username"
          className="rounded-full border-prava-light-border bg-prava-light-bg py-3 dark:bg-prava-dark-bg"
        />

        <PravaPasswordInput
          placeholder="Password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          autoComplete="current-password"
          className="rounded-full border-prava-light-border bg-prava-light-bg py-3 dark:bg-prava-dark-bg"
        />

        <div className="flex justify-start">
          <Link
            to="/forgot-password"
            className="text-caption font-semibold text-prava-error transition-colors hover:text-prava-accent"
          >
            Forgot password?
          </Link>
        </div>

        <div className="pt-3">
          <AuthSubmitButton label="Sign In" loading={loading} disabled={!canSubmit} />
        </div>
      </form>

      <div className="mt-6 flex justify-center lg:hidden">
        <Link to="/signup" className="inline-flex items-center gap-2 text-body-sm font-semibold text-prava-accent">
          <LogIn className="h-4 w-4" strokeWidth={3} />
          Create new account
        </Link>
      </div>
    </AuthFrame>
  );
}
