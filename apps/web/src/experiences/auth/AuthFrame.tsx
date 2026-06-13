import { ReactNode, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { ChevronDown, Globe2, Lock, ShieldCheck, Sparkles } from 'lucide-react';
import { countryDialCodes, defaultCountryCode, CountryDialInfo } from './countries';

/* ─── Floating Particles (matches landing) ─── */
function AuthParticles() {
  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none">
      {[...Array(5)].map((_, i) => (
        <motion.div
          key={i}
          className="absolute rounded-full"
          style={{
            width: 3 + Math.random() * 4,
            height: 3 + Math.random() * 4,
            background: `rgba(61, 99, 240, ${0.12 + Math.random() * 0.18})`,
            left: `${10 + Math.random() * 80}%`,
            top: `${10 + Math.random() * 80}%`,
          }}
          animate={{ y: [0, -25, 0], opacity: [0.25, 0.6, 0.25] }}
          transition={{
            duration: 4 + Math.random() * 3,
            repeat: Infinity,
            delay: i * 0.9,
            ease: 'easeInOut',
          }}
        />
      ))}
    </div>
  );
}

/* ─── Types ─── */
interface AuthFrameProps {
  title: string;
  subtitle: string;
  children: ReactNode;
  actionLabel?: string;
  actionTo?: string;
  actionIcon?: ReactNode;
  footer?: ReactNode;
  /** Step progress props */
  step?: { current: number; total?: number };
}

interface AuthStepProps {
  current: number;
  total?: number;
}

interface CountrySelectProps {
  value: CountryDialInfo;
  onChange: (country: CountryDialInfo) => void;
  label?: string;
}

/* ─── Display names helper ─── */
const displayNames = (() => {
  const DisplayNamesCtor = (Intl as typeof Intl & {
    DisplayNames?: new (locales: string[], options: { type: 'region' }) => { of: (code: string) => string | undefined };
  }).DisplayNames;
  return DisplayNamesCtor ? new DisplayNamesCtor(['en'], { type: 'region' }) : null;
})();

function countryName(code: string) {
  return displayNames?.of(code) || code;
}

function countryFlag(code: string) {
  if (code.length !== 2) return '';
  const points = code.toUpperCase().split('').map((char) => 127397 + char.charCodeAt(0));
  return String.fromCodePoint(...points);
}

export const defaultCountry = countryDialCodes.find((c) => c.code === defaultCountryCode) || countryDialCodes[0];

/* ═══════════════════════════════════════════════════════
   AUTH FRAME — Premium dark-luxury layout (matches landing)
   ═══════════════════════════════════════════════════════ */
export function AuthFrame({
  title,
  subtitle,
  children,
  actionLabel,
  actionTo,
  actionIcon,
  footer,
}: AuthFrameProps) {
  return (
    <div className="auth-root">
      <AuthParticles />

      {/* Ambient glow */}
      <div className="auth-glow" />

      {/* ─── Navbar ─── */}
      <nav className="auth-nav">
        <div className="auth-nav-inner">
          <Link to="/" className="auth-logo">PRAVA</Link>
          <div className="auth-nav-actions">
            {actionLabel && actionTo && (
              <Link to={actionTo} className="auth-nav-link">
                {actionIcon}
                {actionLabel}
              </Link>
            )}
          </div>
        </div>
      </nav>

      {/* ─── Main content ─── */}
      <main className="auth-main">
        <motion.div
          initial={{ opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.55, ease: [0.25, 0.46, 0.45, 0.94] }}
          className="auth-card"
        >
          {/* Badge */}
          <div className="auth-badge">
            <Sparkles size={13} className="text-prava-accent" />
            <span>Secure Access</span>
          </div>

          {/* Title */}
          <h1 className="auth-title">{title}</h1>
          <p className="auth-subtitle">{subtitle}</p>

          {/* Form content */}
          <div className="auth-body">{children}</div>
        </motion.div>
      </main>

      {/* ─── Footer ─── */}
      <footer className="auth-footer">
        {footer || (
          <>
            <div className="auth-footer-left">
              <Lock size={13} className="text-prava-accent" />
              <span>End-to-end encrypted</span>
            </div>
            <span>© {new Date().getFullYear()} Prava</span>
          </>
        )}
      </footer>
    </div>
  );
}

/* ═══ STEP PROGRESS ═══ */
export function AuthStepProgress({ current, total = 4 }: AuthStepProps) {
  return (
    <div className="auth-steps">
      <div className="auth-steps-header">
        <span className="auth-steps-label">Step {current} of {total}</span>
        <span className="auth-steps-hint">
          <ShieldCheck size={12} />
          Secure setup
        </span>
      </div>
      <div className="auth-steps-bar">
        {Array.from({ length: total }).map((_, index) => (
          <span
            key={index}
            className={`auth-step-dot ${index < current ? 'auth-step-dot--active' : ''}`}
          />
        ))}
      </div>
    </div>
  );
}

/* ═══ SUBMIT BUTTON ═══ */
export function AuthSubmitButton({
  label,
  loading,
  disabled,
}: {
  label: string;
  loading?: boolean;
  disabled?: boolean;
}) {
  return (
    <button
      type="submit"
      disabled={disabled || loading}
      className="auth-submit"
    >
      {loading ? (
        <span className="auth-submit-spinner" />
      ) : null}
      {loading ? 'Please wait...' : label}
    </button>
  );
}

/* ═══ COUNTRY SELECT ═══ */
export function CountrySelect({ value, onChange, label = 'Country' }: CountrySelectProps) {
  const [query, setQuery] = useState('');
  const [open, setOpen] = useState(false);

  const countries = useMemo(() => {
    return countryDialCodes
      .map((country) => ({ ...country, name: countryName(country.code), flag: countryFlag(country.code) }))
      .sort((a, b) => a.name.localeCompare(b.name));
  }, []);

  const visible = useMemo(() => {
    const normalized = query.trim().toLowerCase().replace(/^\+/, '');
    if (!normalized) return countries.slice(0, 12);
    return countries
      .filter((c) =>
        c.name.toLowerCase().includes(normalized) ||
        c.code.toLowerCase().includes(normalized) ||
        c.dialCode.startsWith(normalized)
      )
      .slice(0, 18);
  }, [countries, query]);

  return (
    <div className="relative">
      <label className="auth-label">{label}</label>
      <button
        type="button"
        onClick={() => setOpen((prev) => !prev)}
        className="auth-country-trigger"
      >
        <span className="text-lg">{countryFlag(value.code)}</span>
        <span className="min-w-0 flex-1 truncate">{countryName(value.code)}</span>
        <span className="font-semibold text-[#8a8a8a]">+{value.dialCode}</span>
        <ChevronDown size={14} className="text-[#5a5a5a]" />
      </button>

      {open && (
        <div className="auth-country-dropdown">
          <div className="auth-country-search">
            <Globe2 size={14} className="text-[#5a5a5a]" />
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search country"
              className="auth-country-search-input"
              autoFocus
            />
          </div>
          <div className="max-h-64 overflow-y-auto">
            {visible.map((country) => (
              <button
                type="button"
                key={country.code}
                onClick={() => { onChange(country); setQuery(''); setOpen(false); }}
                className="auth-country-option"
              >
                <span className="text-lg">{country.flag}</span>
                <span className="min-w-0 flex-1 truncate font-semibold text-[#F2F2F2]">{country.name}</span>
                <span className="text-[13px] text-[#5a5a5a]">+{country.dialCode}</span>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
