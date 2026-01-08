import React from 'react';
import { motion } from 'framer-motion';

interface PravaBackgroundProps {
  className?: string;
}

export function PravaBackground({ className = '' }: PravaBackgroundProps) {
  return (
    <div className={`fixed inset-0 -z-10 overflow-hidden ${className}`}>
      {/* Base background */}
      <div className="absolute inset-0 bg-prava-light-bg dark:bg-prava-dark-bg" />

      {/* Animated gradient orbs */}
      <motion.div
        className="absolute top-[-20%] left-[-10%] w-[50%] h-[50%] rounded-full opacity-40 dark:opacity-20"
        style={{
          background: 'radial-gradient(circle, rgba(91, 140, 255, 0.3) 0%, transparent 70%)',
        }}
        animate={{
          x: [0, 30, 0],
          y: [0, 20, 0],
        }}
        transition={{
          duration: 20,
          repeat: Infinity,
          ease: 'easeInOut',
        }}
      />

      <motion.div
        className="absolute top-[10%] right-[-5%] w-[40%] h-[40%] rounded-full opacity-30 dark:opacity-15"
        style={{
          background: 'radial-gradient(circle, rgba(143, 169, 255, 0.35) 0%, transparent 70%)',
        }}
        animate={{
          x: [0, -20, 0],
          y: [0, 30, 0],
        }}
        transition={{
          duration: 25,
          repeat: Infinity,
          ease: 'easeInOut',
        }}
      />

      <motion.div
        className="absolute bottom-[-10%] right-[20%] w-[45%] h-[45%] rounded-full opacity-25 dark:opacity-10"
        style={{
          background: 'radial-gradient(circle, rgba(60, 203, 127, 0.25) 0%, transparent 70%)',
        }}
        animate={{
          x: [0, -25, 0],
          y: [0, -15, 0],
        }}
        transition={{
          duration: 22,
          repeat: Infinity,
          ease: 'easeInOut',
        }}
      />

      {/* Subtle noise overlay */}
      <div
        className="absolute inset-0 opacity-[0.015] dark:opacity-[0.03]"
        style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.8' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E")`,
        }}
      />
    </div>
  );
}
