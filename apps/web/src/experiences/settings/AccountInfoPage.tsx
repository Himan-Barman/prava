import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowLeft, User } from 'lucide-react';
import { GlassCard, PravaInput, PravaButton } from '../../ui-system';
import { accountService } from '../../services/account-service';
import { smartToast } from '../../ui-system/components/SmartToast';

export default function AccountInfoPage() {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [email, setEmail] = useState('');
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [phoneCountryCode, setPhoneCountryCode] = useState('');
  const [phoneNumber, setPhoneNumber] = useState('');

  useEffect(() => {
    const loadAccount = async () => {
      try {
        const info = await accountService.fetchAccountInfo();
        setEmail(info.email || '');
        setFirstName(info.firstName || '');
        setLastName(info.lastName || '');
        setPhoneCountryCode(info.phoneCountryCode || '');
        setPhoneNumber(info.phoneNumber || '');
      } catch (error) {
        smartToast.error('Unable to load account details');
      } finally {
        setLoading(false);
      }
    };

    loadAccount();
  }, []);

  const handleSave = async () => {
    if (saving) return;
    setSaving(true);
    try {
      if (email.trim().length > 0) {
        await accountService.updateEmail(email.trim());
      }

      const normalizedCountry = phoneCountryCode.trim().startsWith('+')
        ? phoneCountryCode.trim()
        : phoneCountryCode.trim()
          ? `+${phoneCountryCode.trim()}`
          : '';

      await accountService.updateDetails({
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        phoneCountryCode: normalizedCountry,
        phoneNumber: phoneNumber.replace(/\D/g, ''),
      });

      smartToast.success('Account details updated');
    } catch (error) {
      smartToast.error('Unable to update account details');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto">
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="mb-6"
      >
        <Link
          to="/settings"
          className="inline-flex items-center gap-2 text-body font-medium text-prava-light-text-secondary dark:text-prava-dark-text-secondary hover:text-prava-light-text-primary dark:hover:text-prava-dark-text-primary transition-colors mb-4"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Settings
        </Link>
        <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary">
          Account Info
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Manage your personal details
        </p>
      </motion.div>

      <GlassCard>
        <div className="flex items-center gap-3 mb-6">
          <div className="p-2.5 rounded-[12px] bg-prava-accent/10">
            <User className="w-5 h-5 text-prava-accent" />
          </div>
          <h2 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary">
            Personal Information
          </h2>
        </div>

        <div className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <PravaInput
              label="First Name"
              placeholder="Enter first name"
              value={firstName}
              onChange={(e) => setFirstName(e.target.value)}
              disabled={loading}
            />
            <PravaInput
              label="Last Name"
              placeholder="Enter last name"
              value={lastName}
              onChange={(e) => setLastName(e.target.value)}
              disabled={loading}
            />
          </div>
          <PravaInput
            label="Email"
            placeholder="your@email.com"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            disabled={loading}
          />
          <div className="grid grid-cols-1 sm:grid-cols-[140px_1fr] gap-4">
            <PravaInput
              label="Country Code"
              placeholder="+1"
              value={phoneCountryCode}
              onChange={(e) => setPhoneCountryCode(e.target.value)}
              disabled={loading}
            />
            <PravaInput
              label="Phone Number"
              placeholder="(555) 000-0000"
              value={phoneNumber}
              onChange={(e) => setPhoneNumber(e.target.value)}
              disabled={loading}
            />
          </div>
          <PravaButton label={saving ? 'Saving...' : 'Save Changes'} onClick={handleSave} disabled={saving || loading} />
        </div>
      </GlassCard>
    </div>
  );
}
