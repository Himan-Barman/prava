import { useState, useEffect, type ChangeEvent, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { CheckCircle, XCircle, Loader2, AlertCircle } from 'lucide-react';
import {
  PravaBackground,
  GlassCard,
  PravaInput,
  PravaButton
} from '../../ui-system';
import { authService } from '../../services/auth-service';
import { ApiException } from '../../adapters/api-client';
import toast from 'react-hot-toast';

// Debounce hook
function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState<T>(value);

  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => {
      clearTimeout(handler);
    };
  }, [value, delay]);

  return debouncedValue;
}

export default function SignupPage() {
  const navigate = useNavigate();

  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);

  // Username checking
  const [checkingUsername, setCheckingUsername] = useState(false);
  const [usernameAvailable, setUsernameAvailable] = useState(false);
  const [usernameChecked, setUsernameChecked] = useState(false);
  const [usernameCheckFailed, setUsernameCheckFailed] = useState(false);

  const debouncedUsername = useDebounce(username, 500);

  const isUsernameValid = (value: string) => /^[a-z0-9_]{3,32}$/.test(value);
  const isEmailValid = (value: string) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value);

  const canSubmit =
    usernameChecked &&
    usernameAvailable &&
    isEmailValid(email) &&
    !loading &&
    !checkingUsername;

  // Check username availability
  useEffect(() => {
    async function checkUsername() {
      const normalized = debouncedUsername.toLowerCase().trim();

      if (!normalized) {
        setUsernameAvailable(false);
        setUsernameChecked(false);
        setUsernameCheckFailed(false);
        return;
      }

      if (!isUsernameValid(normalized)) {
        setUsernameAvailable(false);
        setUsernameChecked(true);
        setUsernameCheckFailed(false);
        return;
      }

      setCheckingUsername(true);
      setUsernameChecked(false);
      setUsernameCheckFailed(false);

      try {
        const available = await authService.isUsernameAvailable(normalized);
        setUsernameAvailable(available);
        setUsernameChecked(true);
        setUsernameCheckFailed(false);
      } catch {
        setUsernameAvailable(false);
        setUsernameChecked(true);
        setUsernameCheckFailed(true);
      } finally {
        setCheckingUsername(false);
      }
    }

    checkUsername();
  }, [debouncedUsername]);

  const handleUsernameChange = (e: ChangeEvent<HTMLInputElement>) => {
    // Force lowercase and valid characters only
    const value = e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, '').slice(0, 32);
    setUsername(value);
    setUsernameChecked(false);
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!canSubmit) {
      if (checkingUsername) {
        toast('Checking username availability...', { icon: '⏳' });
      } else if (usernameCheckFailed) {
        toast.error('Unable to verify username. Try again.');
      } else if (!isUsernameValid(username)) {
        toast.error('Username must be 3-32 characters (a-z, 0-9, _)');
      } else if (!isEmailValid(email)) {
        toast.error('Enter a valid email address');
      } else if (!usernameAvailable) {
        toast.error('Username is not available');
      }
      return;
    }

    setLoading(true);

    try {
      await authService.requestEmailOtp(email.toLowerCase());
      toast.success('Verification code sent');
      navigate('/verify-email', {
        state: {
          email: email.toLowerCase(),
          username: username.toLowerCase(),
          flow: 'signup'
        }
      });
    } catch (err) {
      const message = err instanceof ApiException
        ? err.message
        : 'Unable to send verification code';
      toast.error(message);
    } finally {
      setLoading(false);
    }
  };

  const renderUsernameStatus = () => {
    if (!username) return null;

    if (checkingUsername) {
      return (
        <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-full bg-black/[0.05] dark:bg-white/[0.08]">
          <Loader2 className="w-3 h-3 animate-spin text-prava-light-text-secondary dark:text-prava-dark-text-secondary" />
          <span className="text-caption font-semibold text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
            Checking
          </span>
        </div>
      );
    }

    if (!isUsernameValid(username)) {
      return (
        <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-full bg-prava-error/10">
          <XCircle className="w-3 h-3 text-prava-error" />
          <span className="text-caption font-semibold text-prava-error">Invalid</span>
        </div>
      );
    }

    if (usernameCheckFailed) {
      return (
        <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-full bg-prava-warning/10">
          <AlertCircle className="w-3 h-3 text-prava-warning" />
          <span className="text-caption font-semibold text-prava-warning">Retry</span>
        </div>
      );
    }

    if (usernameChecked && usernameAvailable) {
      return (
        <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-full bg-prava-success/10">
          <CheckCircle className="w-3 h-3 text-prava-success" />
          <span className="text-caption font-semibold text-prava-success">Available</span>
        </div>
      );
    }

    if (usernameChecked && !usernameAvailable) {
      return (
        <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-full bg-prava-error/10">
          <XCircle className="w-3 h-3 text-prava-error" />
          <span className="text-caption font-semibold text-prava-error">Taken</span>
        </div>
      );
    }

    return null;
  };

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
                  Create your account
                </h1>
                <p className="mt-2 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
                  Secure signup with verified email and device-bound sessions.
                </p>
              </div>

              {/* Step Badge */}
              <div className="shrink-0 px-3 py-2 rounded-full bg-black/[0.04] dark:bg-white/[0.08] border border-black/[0.08] dark:border-white/[0.16]">
                <span className="text-caption font-semibold text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
                  Step 1 of 3
                </span>
              </div>
            </div>

            {/* Step Indicator */}
            <div className="flex gap-1.5 mt-4">
              <div className="h-1.5 w-9 rounded-full bg-prava-accent" />
              <div className="h-1.5 w-[18px] rounded-full bg-black/[0.12] dark:bg-white/[0.16]" />
              <div className="h-1.5 w-[18px] rounded-full bg-black/[0.12] dark:bg-white/[0.16]" />
            </div>
          </motion.div>

          {/* Signup Card */}
          <GlassCard delay={0.12} className="mt-5 mb-6">
            <form onSubmit={handleSubmit} className="space-y-5">
              {/* Username Field */}
              <div>
                <label className="block text-label font-semibold text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary mb-2">
                  Prava ID
                </label>
                <div className="relative flex items-center gap-2 px-4 py-1 rounded-[16px] bg-prava-light-surface dark:bg-prava-dark-surface border border-prava-light-border dark:border-prava-dark-border">
                  <span className="text-body font-semibold text-prava-light-text-primary dark:text-prava-dark-text-primary">
                    @
                  </span>
                  <div className="w-px h-[22px] bg-prava-light-border dark:bg-prava-dark-border" />
                  <input
                    type="text"
                    placeholder="username"
                    value={username}
                    onChange={handleUsernameChange}
                    autoComplete="username"
                    className="flex-1 py-3 bg-transparent text-body text-prava-light-text-primary dark:text-prava-dark-text-primary placeholder:text-prava-light-text-tertiary dark:placeholder:text-prava-dark-text-tertiary focus:outline-none"
                  />
                  {renderUsernameStatus()}
                </div>
              </div>

              {/* Email Field */}
              <div>
                <label className="block text-label font-semibold text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary mb-2">
                  Email address
                </label>
                <PravaInput
                  type="email"
                  placeholder="Email address"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  autoComplete="email"
                  suffixIcon={
                    email && (
                      isEmailValid(email)
                        ? <CheckCircle className="w-[18px] h-[18px] text-prava-success" />
                        : <XCircle className="w-[18px] h-[18px] text-prava-error" />
                    )
                  }
                />
              </div>

              <PravaButton
                type="submit"
                label="Send verification code"
                loading={loading}
                disabled={!canSubmit}
              />
            </form>
          </GlassCard>

          {/* Back to Sign In */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.3 }}
            className="text-center"
          >
            <Link
              to="/login"
              className="text-body font-semibold text-prava-accent hover:text-prava-accent-muted transition-colors"
            >
              Back to sign in
            </Link>
          </motion.div>
        </div>
      </main>
    </div>
  );
}
