import React, { useRef, useEffect, KeyboardEvent, ClipboardEvent } from 'react';

interface OtpInputProps {
  length?: number;
  value: string[];
  onChange: (value: string[]) => void;
  onComplete?: (code: string) => void;
  disabled?: boolean;
}

export function OtpInput({
  length = 6,
  value,
  onChange,
  onComplete,
  disabled = false,
}: OtpInputProps) {
  const inputRefs = useRef<(HTMLInputElement | null)[]>([]);

  useEffect(() => {
    // Auto-focus first input on mount
    inputRefs.current[0]?.focus();
  }, []);

  const handleChange = (index: number, inputValue: string) => {
    // Handle paste of full code
    if (inputValue.length > 1) {
      const digits = inputValue.replace(/\D/g, '').slice(0, length);
      if (digits.length >= length) {
        const newValue = digits.split('');
        onChange(newValue);
        inputRefs.current[length - 1]?.focus();
        onComplete?.(digits);
        return;
      }
    }

    // Single character input
    const digit = inputValue.replace(/\D/g, '').slice(-1);
    const newValue = [...value];
    newValue[index] = digit;
    onChange(newValue);

    // Move to next input
    if (digit && index < length - 1) {
      inputRefs.current[index + 1]?.focus();
    }

    // Check if complete
    const code = newValue.join('');
    if (code.length === length && !newValue.includes('')) {
      onComplete?.(code);
    }
  };

  const handleKeyDown = (index: number, e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Backspace') {
      if (!value[index] && index > 0) {
        // Move back and clear previous
        inputRefs.current[index - 1]?.focus();
        const newValue = [...value];
        newValue[index - 1] = '';
        onChange(newValue);
      } else {
        // Clear current
        const newValue = [...value];
        newValue[index] = '';
        onChange(newValue);
      }
    } else if (e.key === 'ArrowLeft' && index > 0) {
      inputRefs.current[index - 1]?.focus();
    } else if (e.key === 'ArrowRight' && index < length - 1) {
      inputRefs.current[index + 1]?.focus();
    }
  };

  const handlePaste = (e: ClipboardEvent<HTMLInputElement>) => {
    e.preventDefault();
    const pastedData = e.clipboardData.getData('text');
    const digits = pastedData.replace(/\D/g, '').slice(0, length);

    if (digits.length > 0) {
      const newValue = digits.split('').concat(Array(length - digits.length).fill(''));
      onChange(newValue.slice(0, length));

      const focusIndex = Math.min(digits.length, length - 1);
      inputRefs.current[focusIndex]?.focus();

      if (digits.length === length) {
        onComplete?.(digits);
      }
    }
  };

  return (
    <div className="flex justify-between gap-2 sm:gap-3">
      {Array.from({ length }).map((_, index) => (
        <input
          key={index}
          ref={(el) => (inputRefs.current[index] = el)}
          type="text"
          inputMode="numeric"
          maxLength={6}
          value={value[index] || ''}
          onChange={(e) => handleChange(index, e.target.value)}
          onKeyDown={(e) => handleKeyDown(index, e)}
          onPaste={handlePaste}
          disabled={disabled}
          className={`
            w-10 h-12 sm:w-12 sm:h-14
            text-center text-h2 font-semibold
            rounded-[14px]
            bg-prava-light-surface dark:bg-prava-dark-surface
            border border-prava-light-border dark:border-prava-dark-border
            text-prava-light-text-primary dark:text-prava-dark-text-primary
            transition-all duration-200
            focus:outline-none focus:ring-2 focus:ring-prava-accent/40 focus:border-prava-accent
            disabled:opacity-50 disabled:cursor-not-allowed
          `}
        />
      ))}
    </div>
  );
}
