import { useState, useEffect } from 'react';
import { useLocation, useNavigate, Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Mail, RefreshCw, Clipboard, Loader2 } from 'lucide-react';
import {
  PravaBackground,
  GlassCard,
  OtpInput,
  PravaButton
} from '../../ui-system';
import { authService } from '../../services/auth-service';
import { ApiException } from '../../adapters/api-client';
import toast from 'react-hot-toast';

interface LocationState {
  email: string;
  username?: string;
  flow: 'signup' | 'verify';
}

export default function EmailOtpPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const state = location.state as LocationState | null;

  const [otpValues, setOtpValues] = useState<string[]>(Array(6).fill(''));
  const [loading, setLoading] = useState(false);
  const [resending, setResending] = useState(false);
  const [secondsLeft, setSecondsLeft] = useState(60);

  const email = state?.email || '';
  const username = state?.username;
  const flow = state?.flow || 'signup';

  // Redirect if no email
  useEffect(() => {
    if (!email) {
      navigate('/login');
    }
  }, [email, navigate]);

  // Countdown timer
  useEffect(() => {
    if (secondsLeft <= 0) return;

    const timer = setInterval(() => {
      setSecondsLeft((prev) => prev - 1);
    }, 1000);

    return () => clearInterval(timer);
  }, [secondsLeft]);

  const otp = otpValues.join('');
  const isComplete = otp.length === 6 && !otpValues.includes('');

  const handleVerify = async (code?: string) => {
    const codeToVerify = code || otp;
    if (codeToVerify.length !== 6 || loading) return;

    setLoading(true);

    try {
      await authService.verifyEmailOtp(email, codeToVerify);
      toast.success('Email verified');

      if (flow === 'signup') {
        navigate('/set-password', { state: { email, username } });
      } else {
        navigate('/feed');
      }
    } catch (err) {
      const message = err instanceof ApiException
        ? err.message
        : 'Invalid or expired code';
      toast.error(message);
      setOtpValues(Array(6).fill(''));
    } finally {
      setLoading(false);
    }
  };

  const handleResend = async () => {
    if (resending || secondsLeft > 0) return;

    setResending(true);

    try {
      await authService.requestEmailOtp(email);
      toast.success('Verification code sent');
      setSecondsLeft(60);
    } catch (err) {
      const message = err instanceof ApiException
        ? err.message
        : 'Unable to resend code';
      toast.error(message);
    } finally {
      setResending(false);
    }
  };

  const handlePaste = async () => {
    try {
      const text = await navigator.clipboard.readText();
      const digits = text.replace(/\D/g, '').slice(0, 6);

      if (digits.length < 6) {
        toast.error('Clipboard does not contain a valid code');
        return;
      }

      const newValues = digits.split('');
      setOtpValues(newValues);
      handleVerify(digits);
    } catch {
      toast.error('Unable to access clipboard');
    }
  };

  const handleComplete = (code: string) => {
    handleVerify(code);
  };

  if (!email) return null;

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
            className="mb-6"
          >
            <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary tracking-[-0.6px]">
              Verify your email
            </h1>
            <p className="mt-2 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              Enter the 6-digit code sent to {email}.
            </p>
          </motion.div>

          {/* OTP Card */}
          <GlassCard delay={0.12} className="mb-5">
            {/* Card Header */}
            <div className="flex items-center gap-2 mb-4">
              <Mail className="w-[18px] h-[18px] text-prava-accent" />
              <span className="text-body font-semibold text-prava-light-text-primary dark:text-prava-dark-text-primary">
                Email verification
              </span>
            </div>

            {/* OTP Input */}
            <OtpInput
              value={otpValues}
              onChange={setOtpValues}
              onComplete={handleComplete}
              disabled={loading}
            />

            {/* Resend Row */}
            <div className="flex items-center justify-between mt-4">
              <span className="text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                {secondsLeft > 0 ? `Resend in ${secondsLeft}s` : "Didn't get a code?"}
              </span>

              <button
                type="button"
                onClick={handleResend}
                disabled={secondsLeft > 0 || resending}
                className={`flex items-center gap-1.5 text-caption font-semibold transition-opacity ${secondsLeft > 0 ? 'opacity-40 cursor-not-allowed' : 'opacity-100 cursor-pointer'
                  }`}
              >
                {resending ? (
                  <Loader2 className="w-3.5 h-3.5 animate-spin text-prava-accent" />
                ) : (
                  <RefreshCw className="w-3.5 h-3.5 text-prava-accent" />
                )}
                <span className="text-prava-accent">Resend</span>
              </button>
            </div>

            {/* Action Buttons */}
            <div className="flex gap-3 mt-5">
              <div className="flex-1">
                <PravaButton
                  label={loading ? 'Verifying' : 'Verify'}
                  loading={loading}
                  disabled={!isComplete}
                  onClick={() => handleVerify()}
                />
              </div>

              <button
                type="button"
                onClick={handlePaste}
                className="flex items-center gap-1.5 px-4 py-3 rounded-[14px] 
                  bg-white/[0.06] dark:bg-white/[0.06] 
                  border border-black/[0.08] dark:border-white/[0.12]
                  hover:bg-white/[0.1] dark:hover:bg-white/[0.1]
                  transition-colors"
              >
                <Clipboard className="w-4 h-4 text-prava-light-text-secondary dark:text-prava-dark-text-secondary" />
                <span className="text-caption font-semibold text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
                  Paste
                </span>
              </button>
            </div>
          </GlassCard>

          {/* Change Email Link */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.3 }}
            className="text-center"
          >
            <Link
              to={flow === 'signup' ? '/signup' : '/login'}
              className="text-body font-semibold text-prava-accent hover:text-prava-accent-muted transition-colors"
            >
              Change email
            </Link>
          </motion.div>
        </div>
      </main>
    </div>
  );
}
