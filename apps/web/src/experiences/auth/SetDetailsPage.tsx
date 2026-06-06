import { useMemo, useState, type ChangeEvent, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { CheckCircle, XCircle } from 'lucide-react';
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

  const nameStatusIcon = (value: string, valid: boolean) => {
    if (!value) return null;
    return valid
      ? <CheckCircle className="auth-status-icon auth-status-icon--success" />
      : <XCircle className="auth-status-icon auth-status-icon--error" />;
  };

  return (
    <AuthFrame
      title={step === 0 ? 'Complete Profile' : 'Add Phone Number'}
      subtitle={step === 0
        ? 'Tell us your name before we secure your contact details.'
        : 'India is selected by default. You can change it anytime.'}
    >
      <AuthStepProgress current={4} />

      {step === 0 ? (
        <form onSubmit={handleIdentitySubmit} className="auth-form">
          <div className="auth-field-row">
            <div className="auth-field">
              <label className="auth-label">First name</label>
              <div className="auth-input-wrap">
                <input
                  placeholder="First name"
                  value={firstName}
                  onChange={handleNameChange(setFirstName)}
                  autoComplete="given-name"
                  className="auth-input auth-input--has-suffix"
                />
                <span className="auth-input-suffix">{nameStatusIcon(trimmedFirstName, firstNameValid)}</span>
              </div>
            </div>
            <div className="auth-field">
              <label className="auth-label">Last name</label>
              <div className="auth-input-wrap">
                <input
                  placeholder="Last name"
                  value={lastName}
                  onChange={handleNameChange(setLastName)}
                  autoComplete="family-name"
                  className="auth-input auth-input--has-suffix"
                />
                <span className="auth-input-suffix">{nameStatusIcon(trimmedLastName, lastNameValid)}</span>
              </div>
            </div>
          </div>

          <AuthSubmitButton label="Continue" disabled={!identityValid} />
        </form>
      ) : (
        <form onSubmit={handleSubmit} className="auth-form">
          <CountrySelect value={selectedCountry} onChange={setSelectedCountry} />

          <div className="auth-field">
            <label className="auth-label">Phone number</label>
            <div className="auth-input-wrap">
              <input
                placeholder="Phone number"
                value={phoneNumber}
                onChange={(e) => setPhoneNumber(normalizePhone(e.target.value))}
                inputMode="numeric"
                autoComplete="tel"
                className="auth-input auth-input--has-suffix"
              />
              <span className="auth-input-suffix">
                {phoneDigits
                  ? phoneValid
                    ? <CheckCircle className="auth-status-icon auth-status-icon--success" />
                    : <XCircle className="auth-status-icon auth-status-icon--error" />
                  : null}
              </span>
            </div>
            <p className="auth-field-hint">
              {phonePreview || 'Enter your mobile number without the country code.'}
            </p>
          </div>

          <div className="auth-actions-row">
            <button
              type="button"
              onClick={() => setStep(0)}
              className="auth-btn-back"
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
