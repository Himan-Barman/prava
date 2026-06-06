import { ReactNode, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { ArrowRight, ChevronDown, Globe2, ShieldCheck } from 'lucide-react';
import { countryDialCodes, defaultCountryCode, CountryDialInfo } from './countries';

interface AuthFrameProps {
  title: string;
  subtitle: string;
  eyebrow?: string;
  children: ReactNode;
  sideTitle?: string;
  sideSubtitle?: string;
  actionLabel?: string;
  actionTo?: string;
  actionIcon?: ReactNode;
  footer?: ReactNode;
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
  const points = code
    .toUpperCase()
    .split('')
    .map((char) => 127397 + char.charCodeAt(0));
  return String.fromCodePoint(...points);
}

export const defaultCountry = countryDialCodes.find((country) => country.code === defaultCountryCode) || countryDialCodes[0];

export function AuthFrame({
  title,
  subtitle,
  eyebrow = 'Private social network',
  children,
  sideTitle = 'Manage your private world',
  sideSubtitle = 'Secure posts, chats, friends, and profile identity in one encrypted Prava account.',
  actionLabel,
  actionTo,
  actionIcon,
  footer,
}: AuthFrameProps) {
  return (
    <div className="min-h-screen min-h-dvh bg-prava-light-bg text-prava-light-text-primary dark:bg-prava-dark-bg dark:text-prava-dark-text-primary">
      <div className="grid min-h-screen min-h-dvh lg:grid-cols-[minmax(420px,1fr)_minmax(480px,1fr)]">
        <aside className="relative hidden overflow-hidden bg-[#231d1a] px-10 py-10 text-white lg:flex">
          <div className="absolute inset-0 opacity-60">
            <div className="absolute left-[18%] top-[16%] h-64 w-64 rounded-full border border-white/10" />
            <div className="absolute left-[25%] top-[24%] h-40 w-40 rounded-full border border-white/10" />
            <div className="absolute bottom-[-120px] right-[-120px] h-72 w-72 rounded-full bg-prava-accent/10 blur-3xl" />
          </div>

          <div className="relative z-10 flex w-full flex-col">
            <p className="text-caption text-white/68">{eyebrow}</p>

            <div className="flex flex-1 flex-col items-center justify-center">
              <motion.h2
                initial={{ opacity: 0, y: 14 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.45, ease: [0.22, 1, 0.36, 1] }}
                className="max-w-[420px] text-center text-[52px] font-bold leading-[0.96] tracking-normal"
              >
                {sideTitle}
              </motion.h2>

              <motion.div
                initial={{ opacity: 0, y: 22, rotate: -6 }}
                animate={{ opacity: 1, y: 0, rotate: -6 }}
                transition={{ duration: 0.55, delay: 0.08, ease: [0.22, 1, 0.36, 1] }}
                className="mt-10 h-[320px] w-[178px] rounded-[34px] border-[8px] border-black bg-[#0b0b0b] p-3 shadow-[0_30px_70px_rgba(0,0,0,0.5)]"
              >
                <div className="mx-auto mb-5 h-4 w-16 rounded-full bg-black" />
                <div className="rounded-[24px] bg-white p-3 text-[#0c0c0c]">
                  <p className="text-[10px] font-semibold text-black/50">Prava balance</p>
                  <p className="mt-1 text-2xl font-bold">897.00</p>
                  <div className="mt-5 flex h-20 items-end gap-1.5">
                    {[32, 54, 42, 70, 58, 86, 48].map((height, index) => (
                      <span key={index} className="flex-1 rounded-t bg-prava-error" style={{ height }} />
                    ))}
                  </div>
                </div>
                <div className="mt-4 grid grid-cols-2 gap-2">
                  {['Posts', 'Chats', 'Friends', 'Profile'].map((item) => (
                    <div key={item} className="rounded-[16px] bg-white/10 p-2">
                      <p className="text-[9px] text-white/45">{item}</p>
                      <div className="mt-4 h-2 rounded bg-white/30" />
                    </div>
                  ))}
                </div>
              </motion.div>

              <p className="mt-8 max-w-[360px] text-center text-body text-white/62">
                {sideSubtitle}
              </p>
            </div>

            <div className="flex items-center justify-between text-caption text-white/45">
              <span>Prava secure account</span>
              <ShieldCheck className="h-4 w-4 text-prava-accent" strokeWidth={3} />
            </div>
          </div>
        </aside>

        <section className="relative flex min-h-screen min-h-dvh flex-col bg-prava-light-bg px-5 py-5 dark:bg-prava-dark-bg lg:rounded-l-[56px] lg:px-12 lg:py-9">
          <header className="flex h-12 items-center justify-between">
            <Link to="/" className="text-h3 font-bold text-prava-light-text-primary dark:text-prava-dark-text-primary">
              Prava
            </Link>
            {actionLabel && actionTo && (
              <Link
                to={actionTo}
                className="inline-flex items-center gap-2 rounded-full px-3 py-2 text-body-sm font-semibold text-prava-light-text-secondary transition-colors hover:bg-prava-light-surface hover:text-prava-light-text-primary dark:text-prava-dark-text-secondary dark:hover:bg-white/[0.08] dark:hover:text-prava-dark-text-primary"
              >
                {actionIcon}
                {actionLabel}
              </Link>
            )}
          </header>

          <main className="flex flex-1 items-center justify-center py-7">
            <motion.div
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.42, ease: [0.22, 1, 0.36, 1] }}
              className="w-full max-w-[420px]"
            >
              <h1 className="text-[34px] font-semibold leading-[1.05] tracking-normal text-prava-light-text-primary dark:text-prava-dark-text-primary sm:text-[40px]">
                {title}
              </h1>
              <p className="mt-4 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
                {subtitle}
              </p>
              <div className="mt-8">{children}</div>
            </motion.div>
          </main>

          <footer className="flex min-h-8 items-center justify-between gap-4 text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
            {footer || (
              <>
                <span>2026 Prava</span>
                <span>Protected access</span>
              </>
            )}
          </footer>
        </section>
      </div>
    </div>
  );
}

export function AuthStepProgress({ current, total = 4 }: AuthStepProps) {
  return (
    <div className="mb-6">
      <div className="mb-3 flex items-center justify-between">
        <span className="text-caption font-semibold text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Step {current} of {total}
        </span>
        <span className="text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
          Secure setup
        </span>
      </div>
      <div className="flex gap-1.5">
        {Array.from({ length: total }).map((_, index) => (
          <span
            key={index}
            className={`h-1.5 rounded-full transition-all duration-200 ${
              index < current ? 'w-9 bg-prava-accent' : 'w-5 bg-black/10 dark:bg-white/12'
            }`}
          />
        ))}
      </div>
    </div>
  );
}

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
      className="group relative flex h-[48px] w-full items-center justify-center gap-2 overflow-hidden rounded-full bg-prava-accent px-5 text-body font-bold text-white shadow-[0_14px_30px_rgba(91,140,255,0.28)] transition-all hover:bg-prava-accent-muted disabled:cursor-not-allowed disabled:opacity-45"
    >
      <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" strokeWidth={3} />
      {loading ? 'Please wait...' : label}
    </button>
  );
}

export function CountrySelect({ value, onChange, label = 'Country' }: CountrySelectProps) {
  const [query, setQuery] = useState('');
  const [open, setOpen] = useState(false);

  const countries = useMemo(() => {
    return countryDialCodes
      .map((country) => ({
        ...country,
        name: countryName(country.code),
        flag: countryFlag(country.code),
      }))
      .sort((a, b) => a.name.localeCompare(b.name));
  }, []);

  const visible = useMemo(() => {
    const normalized = query.trim().toLowerCase().replace(/^\+/, '');
    if (!normalized) return countries.slice(0, 12);
    return countries
      .filter((country) => {
        return (
          country.name.toLowerCase().includes(normalized) ||
          country.code.toLowerCase().includes(normalized) ||
          country.dialCode.startsWith(normalized)
        );
      })
      .slice(0, 18);
  }, [countries, query]);

  return (
    <div className="relative">
      <label className="mb-2 block text-label font-semibold text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
        {label}
      </label>
      <button
        type="button"
        onClick={() => setOpen((current) => !current)}
        className="flex h-[46px] w-full items-center gap-3 rounded-full border border-prava-light-border bg-prava-light-bg px-4 text-left text-body text-prava-light-text-primary transition-all hover:border-prava-accent/45 dark:border-prava-dark-border dark:bg-prava-dark-bg dark:text-prava-dark-text-primary"
      >
        <span className="text-lg">{countryFlag(value.code)}</span>
        <span className="min-w-0 flex-1 truncate">{countryName(value.code)}</span>
        <span className="font-semibold text-prava-light-text-secondary dark:text-prava-dark-text-secondary">+{value.dialCode}</span>
        <ChevronDown className="h-4 w-4 text-prava-light-text-tertiary" strokeWidth={3} />
      </button>

      {open && (
        <div className="absolute left-0 right-0 top-[78px] z-40 rounded-[18px] border border-prava-light-border bg-prava-light-bg p-2 shadow-[0_18px_50px_rgba(0,0,0,0.16)] dark:border-prava-dark-border dark:bg-prava-dark-elevated">
          <div className="mb-2 flex h-10 items-center gap-2 rounded-full bg-prava-light-surface px-3 dark:bg-prava-dark-surface">
            <Globe2 className="h-4 w-4 text-prava-light-text-tertiary" strokeWidth={3} />
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search country"
              className="min-w-0 flex-1 bg-transparent text-body text-prava-light-text-primary outline-none placeholder:text-prava-light-text-tertiary dark:text-prava-dark-text-primary"
              autoFocus
            />
          </div>
          <div className="max-h-64 overflow-y-auto">
            {visible.map((country) => (
              <button
                type="button"
                key={country.code}
                onClick={() => {
                  onChange(country);
                  setQuery('');
                  setOpen(false);
                }}
                className="flex w-full items-center gap-3 rounded-[14px] px-3 py-2 text-left transition-colors hover:bg-prava-light-surface dark:hover:bg-white/[0.08]"
              >
                <span className="text-lg">{country.flag}</span>
                <span className="min-w-0 flex-1 truncate text-body font-semibold text-prava-light-text-primary dark:text-prava-dark-text-primary">
                  {country.name}
                </span>
                <span className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                  +{country.dialCode}
                </span>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
