import { useMemo, useState, type ChangeEvent, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { CheckCircle, XCircle } from 'lucide-react';
import { PravaInput } from '../../ui-system';
import { authService } from '../../services/auth-service';
import { ApiException } from '../../adapters/api-client';
import { smartToast } from '../../ui-system/components/SmartToast';
import { AuthFrame, AuthStepProgress, AuthSubmitButton, CountrySelect, defaultCountry } from './AuthFrame';
import { CountryDialInfo } from './countries';

function isNameValid(value: string) {
  if (!value || value.length > 64) return false;
  return /^[A-Za-z][A-Za-z '\-]*$/.test(value);
}

function normalizePhone(raw: string) {
  return raw.replace(/\D/g, '').slice(0, 14);
}

export default function SetDetailsPage() {
  const navigate = useNavigate();

  const [step, setStep] = useState(0);
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [selectedCountry, setSelectedCountry] = useState<CountryDialInfo>(defaultCountry);
  const [phoneNumber, setPhoneNumber] = useState('');
  const [loading, setLoading] = useState(false);

  const trimmedFirstName = firstName.trim();
  const trimmedLastName = lastName.trim();
  const phoneDigits = normalizePhone(phoneNumber);
  const firstNameValid = isNameValid(trimmedFirstName);
  const lastNameValid = isNameValid(trimmedLastName);
  const identityValid = firstNameValid && lastNameValid;
  const phoneValid = /^\d{4,14}$/.test(phoneDigits) && selectedCountry.dialCode.length + phoneDigits.length <= 15;
  const canSubmit = identityValid && phoneValid && !loading;

  const phonePreview = useMemo(() => {
    if (!phoneValid) return '';
    return `+${selectedCountry.dialCode} ${phoneDigits}`;
  }, [phoneDigits, phoneValid, selectedCountry.dialCode]);

  const handleNameChange = (setter: (value: string) => void) => (event: ChangeEvent<HTMLInputElement>) => {
    setter(event.target.value.slice(0, 64));
  };

  const handleIdentitySubmit = (event: FormEvent) => {
    event.preventDefault();
    if (!identityValid) {
      smartToast.warning('Enter a valid first and last name');
      return;
    }
    setStep(1);
  };

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    if (!canSubmit) {
      smartToast.warning('Enter a valid phone number');
      return;
    }

    setLoading(true);

    try {
      await authService.updateUserDetails({
        firstName: trimmedFirstName,
        lastName: trimmedLastName,
        phoneCountryCode: `+${selectedCountry.dialCode}`,
        phoneNumber: phoneDigits,
      });
      smartToast.success('Profile details saved');
      navigate('/feed', { replace: true });
    } catch (err) {
      const message = err instanceof ApiException ? err.message : 'Unable to save details';
      smartToast.error(message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthFrame
      title={step === 0 ? 'Complete Profile' : 'Add Phone Number'}
      subtitle={step === 0 ? 'Tell us your name before we secure your contact details.' : 'India is selected by default. You can change it anytime.'}
      sideTitle="Finish your Prava identity"
    >
      <AuthStepProgress current={4} />

      {step === 0 ? (
        <form onSubmit={handleIdentitySubmit} className="space-y-4">
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <PravaInput
              label="First name"
              placeholder="First name"
              value={firstName}
              onChange={handleNameChange(setFirstName)}
              autoComplete="given-name"
              suffixIcon={
                trimmedFirstName ? (
                  firstNameValid
                    ? <CheckCircle className="h-4 w-4 text-prava-success" />
                    : <XCircle className="h-4 w-4 text-prava-error" />
                ) : null
              }
              className="rounded-full bg-prava-light-bg py-3 dark:bg-prava-dark-bg"
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
                    ? <CheckCircle className="h-4 w-4 text-prava-success" />
                    : <XCircle className="h-4 w-4 text-prava-error" />
                ) : null
              }
              className="rounded-full bg-prava-light-bg py-3 dark:bg-prava-dark-bg"
            />
          </div>
          <div className="pt-3">
            <AuthSubmitButton label="Continue" disabled={!identityValid} />
          </div>
        </form>
      ) : (
        <form onSubmit={handleSubmit} className="space-y-4">
          <CountrySelect value={selectedCountry} onChange={setSelectedCountry} />

          <PravaInput
            label="Phone number"
            placeholder="Phone number"
            value={phoneNumber}
            onChange={(event) => setPhoneNumber(normalizePhone(event.target.value))}
            inputMode="numeric"
            autoComplete="tel"
            suffixIcon={
              phoneDigits ? (
                phoneValid
                  ? <CheckCircle className="h-4 w-4 text-prava-success" />
                  : <XCircle className="h-4 w-4 text-prava-error" />
              ) : null
            }
            className="rounded-full bg-prava-light-bg py-3 dark:bg-prava-dark-bg"
          />

          <p className="text-caption text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
            {phonePreview || 'Enter your mobile number without the country code.'}
          </p>

          <div className="flex gap-3 pt-3">
            <button
              type="button"
              onClick={() => setStep(0)}
              className="h-[48px] rounded-full bg-prava-light-surface px-5 text-body-sm font-bold text-prava-light-text-secondary transition-colors hover:bg-prava-light-border dark:bg-white/[0.08] dark:text-prava-dark-text-secondary"
            >
              Back
            </button>
            <AuthSubmitButton label="Finish" loading={loading} disabled={!canSubmit} />
          </div>
        </form>
      )}
    </AuthFrame>
  );
}
