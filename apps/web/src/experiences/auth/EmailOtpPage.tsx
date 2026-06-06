import { useEffect, useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { Clipboard, Loader2, RefreshCw } from 'lucide-react';
import { OtpInput } from '../../ui-system';
import { authService } from '../../services/auth-service';
import { ApiException } from '../../adapters/api-client';
import { smartToast } from '../../ui-system/components/SmartToast';
import { AuthFrame, AuthStepProgress, AuthSubmitButton } from './AuthFrame';

interface LocationState {
  email: string;
  username?: string;
  flow: 'signup' | 'verify';
}

export default function EmailOtpPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const state = location.state as LocationState | null;
  const searchParams = new URLSearchParams(location.search);

  const [otpValues, setOtpValues] = useState<string[]>(Array(6).fill(''));
  const [loading, setLoading] = useState(false);
  const [resending, setResending] = useState(false);
  const [secondsLeft, setSecondsLeft] = useState(60);

  const email = state?.email || searchParams.get('email') || '';
  const username = state?.username || searchParams.get('username') || undefined;
  const flowParam = state?.flow || searchParams.get('flow');
  const flow: 'signup' | 'verify' = flowParam === 'verify' ? 'verify' : 'signup';
  const otp = otpValues.join('');
  const isComplete = otp.length === 6 && !otpValues.includes('');

  useEffect(() => {
    if (!email) navigate('/login');
  }, [email, navigate]);

  useEffect(() => {
    if (secondsLeft <= 0) return undefined;
    const timer = window.setInterval(() => setSecondsLeft((prev) => prev - 1), 1000);
    return () => window.clearInterval(timer);
  }, [secondsLeft]);

  const handleVerify = async (code = otp) => {
    if (code.length !== 6 || loading) return;
    setLoading(true);

    try {
      await authService.verifyEmailOtp(email, code);
      smartToast.success('Email verified');

      if (flow === 'signup') {
        const params = new URLSearchParams({ email });
        if (username) params.set('username', username);
        navigate(`/set-password?${params.toString()}`, { state: { email, username } });
      } else {
        navigate('/feed');
      }
    } catch (err) {
      const message = err instanceof ApiException ? err.message : 'Invalid or expired code';
      smartToast.error(message);
      setOtpValues(Array(6).fill(''));
    } finally {
      setLoading(false);
    }
  };

  const handleResend = async () => {
    if (resending || secondsLeft > 0) return;
    setResending(true);

    try {
      await authService.requestEmailOtp(email, flow === 'signup' ? username : undefined);
      smartToast.success('Verification code sent');
      setSecondsLeft(60);
    } catch (err) {
      const message = err instanceof ApiException ? err.message : 'Unable to resend code';
      smartToast.error(message);
    } finally {
      setResending(false);
    }
  };

  const handlePaste = async () => {
    try {
      const text = await navigator.clipboard.readText();
      const digits = text.replace(/\D/g, '').slice(0, 6);
      if (digits.length < 6) {
        smartToast.warning('Clipboard does not contain a valid code');
        return;
      }
      setOtpValues(digits.split(''));
      handleVerify(digits);
    } catch {
      smartToast.error('Unable to access clipboard');
    }
  };

  if (!email) return null;

  return (
    <AuthFrame
      title="Verify Email"
      subtitle={`Enter the 6-digit code sent to ${email}.`}
      sideTitle="Verify your secure identity"
      actionLabel="Change Email"
      actionTo={flow === 'signup' ? '/signup' : '/login'}
    >
      {flow === 'signup' && <AuthStepProgress current={2} />}

      <div className="space-y-5">
        <OtpInput
          value={otpValues}
          onChange={setOtpValues}
          onComplete={handleVerify}
          disabled={loading}
        />

        <div className="flex items-center justify-between">
          <span className="text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
            {secondsLeft > 0 ? `Resend in ${secondsLeft}s` : "Didn't get a code?"}
          </span>
          <button
            type="button"
            onClick={handleResend}
            disabled={secondsLeft > 0 || resending}
            className="inline-flex items-center gap-1.5 text-caption font-bold text-prava-accent disabled:opacity-40"
          >
            {resending ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <RefreshCw className="h-3.5 w-3.5" strokeWidth={3} />}
            Resend
          </button>
        </div>

        <AuthSubmitButton label="Verify" loading={loading} disabled={!isComplete} />

        <button
          type="button"
          onClick={handlePaste}
          className="mx-auto flex items-center gap-2 rounded-full px-4 py-2 text-body-sm font-semibold text-prava-light-text-secondary transition-colors hover:bg-prava-light-surface dark:text-prava-dark-text-secondary dark:hover:bg-white/[0.08]"
        >
          <Clipboard className="h-4 w-4" strokeWidth={3} />
          Paste code
        </button>
      </div>

      <p className="mt-6 text-center text-body-sm text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
        Wrong email?{' '}
        <Link to={flow === 'signup' ? '/signup' : '/login'} className="font-bold text-prava-accent">
          Start again
        </Link>
      </p>
    </AuthFrame>
  );
}
