import type { ReactNode } from 'react';
import { motion } from 'framer-motion';

interface GlassCardProps {
  children: ReactNode;
  className?: string;
  animate?: boolean;
  delay?: number;
}

export function GlassCard({
  children,
  className = '',
  animate = true,
  delay = 0
}: GlassCardProps) {
  const content = (
    <div
      className={`
        relative overflow-hidden
        px-4 py-4 sm:px-5 sm:py-5
        rounded-[18px]
        backdrop-blur-[18px]
        bg-white/90 dark:bg-white/[0.06]
        border border-black/[0.08] dark:border-white/[0.12]
        shadow-[0_10px_28px_rgba(15,20,40,0.07)] dark:shadow-[0_10px_28px_rgba(0,0,0,0.36)]
        ${className}
      `}
    >
      {children}
    </div>
  );

  if (!animate) return content;

  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{
        duration: 0.32,
        ease: [0.4, 0, 0.2, 1],
        delay
      }}
    >
      {content}
    </motion.div>
  );
}
