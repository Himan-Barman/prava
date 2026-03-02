import { useMemo, useState, type ChangeEvent, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { User, CheckCircle, XCircle } from 'lucide-react';
import {
  PravaBackground,
  GlassCard,
  PravaButton,
  PravaInput,
} from '../../ui-system';
import { authService } from '../../services/auth-service';
import { ApiException } from '../../adapters/api-client';
import { smartToast } from '../../ui-system/components/SmartToast';

function isNameValid(value: string): boolean {
  if (!value || value.length > 64) return false;
  return /^[A-Za-z][A-Za-z '\-]*$/.test(value);
}

function normalizeCountryCode(raw: string): string {
  return raw.replace(/\D/g, '').slice(0, 4);
}

function normalizePhone(raw: string): string {
  return raw.replace(/\D/g, '').slice(0, 14);
}

export default function SetDetailsPage() {
  const navigate = useNavigate();

  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [countryCode, setCountryCode] = useState('');
  const [phoneNumber, setPhoneNumber] = useState('');
  const [loading, setLoading] = useState(false);

  const trimmedFirstName = firstName.trim();
  const trimmedLastName = lastName.trim();
  const countryDigits = normalizeCountryCode(countryCode);
  const phoneDigits = normalizePhone(phoneNumber);

  const firstNameValid = isNameValid(trimmedFirstName);
  const lastNameValid = isNameValid(trimmedLastName);
  const countryValid = countryDigits.length > 0;
  const phoneLengthValid = /^\d{4,14}$/.test(phoneDigits);
  const phoneValid = phoneLengthValid && (countryDigits.length + phoneDigits.length <= 15);
  const canSubmit =
    firstNameValid &&
    lastNameValid &&
    countryValid &&
    phoneValid &&
    !loading;

  const phonePreview = useMemo(() => {
    if (!countryValid || !phoneValid) return '';
    return `+${countryDigits} ${phoneDigits}`;
  }, [countryDigits, countryValid, phoneDigits, phoneValid]);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!canSubmit) return;

    setLoading(true);

    try {
      await authService.updateUserDetails({
        firstName: trimmedFirstName,
        lastName: trimmedLastName,
        phoneCountryCode: `+${countryDigits}`,
        phoneNumber: phoneDigits,
      });

      smartToast.success('Profile details saved');
      navigate('/feed', { replace: true });
    } catch (err) {
      const message = err instanceof ApiException
        ? err.message
        : 'Unable to save details';
      smartToast.error(message);
    } finally {
      setLoading(false);
    }
  };

  const handleNameChange = (setter: (value: string) => void) => (e: ChangeEvent<HTMLInputElement>) => {
    setter(e.target.value.slice(0, 64));
  };

  return (
    <div className="min-h-screen min-h-dvh flex flex-col">
      <PravaBackground />

      <main className="flex-1 flex items-center justify-center px-5 py-8 sm:px-6 sm:py-12">
        <div className="w-full max-w-[440px]">
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.52, ease: [0.4, 0, 0.2, 1] }}
            className="mb-6"
          >
            <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary tracking-[-0.6px]">
              Complete your profile
            </h1>
            <p className="mt-2 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              Add trusted details to protect your account.
            </p>
          </motion.div>

          <GlassCard delay={0.12} className="mb-4">
            <div className="flex items-center gap-2 mb-4">
              <User className="w-[18px] h-[18px] text-prava-accent" />
              <span className="text-body font-semibold text-prava-light-text-primary dark:text-prava-dark-text-primary">
                Identity details
              </span>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <PravaInput
                  label="First name"
                  placeholder="First name"
                  value={firstName}
                  onChange={handleNameChange(setFirstName)}
                  autoComplete="given-name"
                  suffixIcon={
                    trimmedFirstName ? (
                      firstNameValid
                        ? <CheckCircle className="w-[18px] h-[18px] text-prava-success" />
                        : <XCircle className="w-[18px] h-[18px] text-prava-error" />
                    ) : null
                  }
                />

                <PravaInput
                  label="Last name"
                  placeholder="Last name"
                  value={lastName}
                  onChange={handleNameChange(setLastName)}
                  autoComplete="family-name"
                  suffixIcon={
                    trimmedLastName ? (
                      lastNameValid
                        ? <CheckCircle className="w-[18px] h-[18px] text-prava-success" />
                        : <XCircle className="w-[18px] h-[18px] text-prava-error" />
                    ) : null
                  }
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-[170px_1fr] gap-3">
                <PravaInput
                  label="Country code"
                  placeholder="+1"
                  value={countryCode}
                  onChange={(e) => setCountryCode(normalizeCountryCode(e.target.value))}
                  inputMode="numeric"
                  prefixIcon={<span className="text-body font-semibold">+</span>}
                />

                <PravaInput
                  label="Phone number"
                  placeholder="Phone number"
                  value={phoneNumber}
                  onChange={(e) => setPhoneNumber(normalizePhone(e.target.value))}
                  inputMode="numeric"
                  autoComplete="tel"
                  suffixIcon={
                    phoneDigits ? (
                      phoneValid
                        ? <CheckCircle className="w-[18px] h-[18px] text-prava-success" />
                        : <XCircle className="w-[18px] h-[18px] text-prava-error" />
                    ) : null
                  }
                />
              </div>

              {phonePreview ? (
                <p className="text-caption text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
                  Saved as {phonePreview}
                </p>
              ) : (
                <p className="text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                  Enter your full number with country code.
                </p>
              )}

              <PravaButton
                type="submit"
                label="Continue"
                loading={loading}
                disabled={!canSubmit}
              />
            </form>
          </GlassCard>

          <p className="text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
            Your phone stays private and is used for account recovery.
          </p>
        </div>
      </main>
    </div>
  );
}
