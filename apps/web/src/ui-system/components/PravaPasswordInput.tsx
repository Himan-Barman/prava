import { forwardRef, useState, type InputHTMLAttributes } from 'react';
import { Eye, EyeOff } from 'lucide-react';

interface PravaPasswordInputProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'type'> {
  label?: string;
  hint?: string;
  error?: string;
  showStrength?: boolean;
}

function getPasswordStrength(password: string): { level: number; label: string; color: string } {
  if (!password) return { level: 0, label: '', color: '' };

  let score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 12) score++;
  if (/[a-z]/.test(password) && /[A-Z]/.test(password)) score++;
  if (/[0-9]/.test(password)) score++;
  if (/[^a-zA-Z0-9]/.test(password)) score++;

  if (score <= 1) return { level: 1, label: 'Weak', color: 'bg-prava-error' };
  if (score <= 2) return { level: 2, label: 'Fair', color: 'bg-prava-warning' };
  if (score <= 3) return { level: 3, label: 'Good', color: 'bg-prava-accent' };
  return { level: 4, label: 'Strong', color: 'bg-prava-success' };
}

export const PravaPasswordInput = forwardRef<HTMLInputElement, PravaPasswordInputProps>(
  ({ label, hint, error, showStrength = false, className = '', value, ...props }, ref) => {
    const [showPassword, setShowPassword] = useState(false);
    const hasError = !!error;
    const strength = showStrength ? getPasswordStrength(String(value || '')) : null;

    return (
      <div className="w-full">
        {label && (
          <label className="block text-label text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary font-semibold mb-2">
            {label}
          </label>
        )}
        <div className="relative">
          <input
            ref={ref}
            type={showPassword ? 'text' : 'password'}
            value={value}
            className={`
              w-full px-4 py-3.5 pr-12 rounded-[16px] text-body
              bg-prava-light-surface dark:bg-prava-dark-surface
              border transition-all duration-200
              text-prava-light-text-primary dark:text-prava-dark-text-primary
              placeholder:text-prava-light-text-tertiary dark:placeholder:text-prava-dark-text-tertiary
              focus:outline-none focus:ring-2 focus:ring-prava-accent/35 focus:border-prava-accent/45
              ${hasError
                ? 'border-prava-error focus:ring-prava-error/35 focus:border-prava-error'
                : 'border-prava-light-border dark:border-prava-dark-border'
              }
              ${className}
            `}
            {...props}
          />
          <button
            type="button"
            onClick={() => setShowPassword(!showPassword)}
            className="absolute right-4 top-1/2 -translate-y-1/2 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary hover:text-prava-light-text-secondary dark:hover:text-prava-dark-text-secondary transition-colors"
          >
            {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
          </button>
        </div>

        {showStrength && value && (
          <div className="mt-3">
            <div className="flex gap-1.5 mb-1.5">
              {[1, 2, 3, 4].map((i) => (
                <div
                  key={i}
                  className={`h-1 flex-1 rounded-full transition-all duration-300 ${i <= strength!.level ? strength!.color : 'bg-prava-light-border dark:bg-prava-dark-border'
                    }`}
                />
              ))}
            </div>
            <p className={`text-caption font-medium ${strength!.level <= 1 ? 'text-prava-error' :
                strength!.level <= 2 ? 'text-prava-warning' :
                  strength!.level <= 3 ? 'text-prava-accent' : 'text-prava-success'
              }`}>
              {strength!.label}
            </p>
          </div>
        )}

        {hint && !error && !showStrength && (
          <p className="mt-2 text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
            {hint}
          </p>
        )}
        {error && (
          <p className="mt-2 text-caption text-prava-error">
            {error}
          </p>
        )}
      </div>
    );
  }
);

PravaPasswordInput.displayName = 'PravaPasswordInput';
