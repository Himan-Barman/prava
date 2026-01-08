import React, { forwardRef } from 'react';

interface PravaInputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  hint?: string;
  error?: string;
  suffixIcon?: React.ReactNode;
  prefixIcon?: React.ReactNode;
}

export const PravaInput = forwardRef<HTMLInputElement, PravaInputProps>(
  ({ label, hint, error, suffixIcon, prefixIcon, className = '', ...props }, ref) => {
    const hasError = !!error;

    return (
      <div className="w-full">
        {label && (
          <label className="block text-label text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary font-semibold mb-2">
            {label}
          </label>
        )}
        <div className="relative">
          {prefixIcon && (
            <div className="absolute left-4 top-1/2 -translate-y-1/2 text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              {prefixIcon}
            </div>
          )}
          <input
            ref={ref}
            className={`
              w-full px-4 py-3.5 rounded-[16px] text-body
              bg-prava-light-surface dark:bg-prava-dark-surface
              border transition-all duration-200
              text-prava-light-text-primary dark:text-prava-dark-text-primary
              placeholder:text-prava-light-text-tertiary dark:placeholder:text-prava-dark-text-tertiary
              focus:outline-none focus:ring-2 focus:ring-prava-accent/35 focus:border-prava-accent/45
              ${hasError
                ? 'border-prava-error focus:ring-prava-error/35 focus:border-prava-error'
                : 'border-prava-light-border dark:border-prava-dark-border'
              }
              ${prefixIcon ? 'pl-12' : ''}
              ${suffixIcon ? 'pr-12' : ''}
              ${className}
            `}
            {...props}
          />
          {suffixIcon && (
            <div className="absolute right-4 top-1/2 -translate-y-1/2">
              {suffixIcon}
            </div>
          )}
        </div>
        {hint && !error && (
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

PravaInput.displayName = 'PravaInput';
