import type { ReactNode } from 'react';
import { motion } from 'framer-motion';
import { Loader2 } from 'lucide-react';

interface PravaButtonProps {
  label: string;
  onClick?: () => void;
  loading?: boolean;
  disabled?: boolean;
  type?: 'button' | 'submit';
  variant?: 'primary' | 'ghost' | 'soft';
  fullWidth?: boolean;
  icon?: ReactNode;
  className?: string;
}

export function PravaButton({
  label,
  onClick,
  loading = false,
  disabled = false,
  type = 'button',
  variant = 'primary',
  fullWidth = true,
  icon,
  className = '',
}: PravaButtonProps) {
  const isDisabled = disabled || loading;

  const baseClasses = `
    relative flex items-center justify-center gap-2 
    px-6 py-3.5 rounded-[16px] font-semibold text-[14px] tracking-[0.3px]
    transition-all duration-200 ease-out
    focus:outline-none focus:ring-2 focus:ring-prava-accent/40 focus:ring-offset-2
    disabled:cursor-not-allowed
    ${fullWidth ? 'w-full' : 'w-auto'}
  `;

  const variantClasses = {
    primary: `
      text-white
      bg-gradient-to-r from-prava-accent to-prava-accent-muted
      shadow-prava-glow
      hover:shadow-[0_12px_28px_rgba(91,140,255,0.4)]
      disabled:opacity-60
    `,
    ghost: `
      text-prava-light-text-secondary dark:text-prava-dark-text-secondary
      bg-transparent
      hover:bg-prava-light-surface dark:hover:bg-prava-dark-surface
      hover:text-prava-light-text-primary dark:hover:text-prava-dark-text-primary
      disabled:opacity-50
    `,
    soft: `
      text-prava-accent
      bg-prava-accent/12
      border border-prava-accent/30
      hover:bg-prava-accent/20
      disabled:opacity-50
    `,
  };

  return (
    <motion.button
      type={type}
      onClick={onClick}
      disabled={isDisabled}
      whileTap={isDisabled ? {} : { scale: 0.98 }}
      whileHover={isDisabled ? {} : { y: -1 }}
      className={`${baseClasses} ${variantClasses[variant]} ${className}`}
    >
      {loading ? (
        <>
          <Loader2 className="w-5 h-5 animate-spin" />
          <span className="opacity-80">{label}</span>
        </>
      ) : (
        <>
          {icon && <span className="w-5 h-5">{icon}</span>}
          <span>{label}</span>
        </>
      )}
    </motion.button>
  );
}
