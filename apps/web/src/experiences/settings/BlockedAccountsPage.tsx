import React from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowLeft, UserX } from 'lucide-react';
import { GlassCard } from '../../ui-system';

export default function BlockedAccountsPage() {
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
          Blocked Accounts
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          People you have blocked
        </p>
      </motion.div>

      <GlassCard className="text-center py-12">
        <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-prava-light-surface dark:bg-prava-dark-surface flex items-center justify-center">
          <UserX className="w-8 h-8 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary" />
        </div>
        <h3 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary mb-2">
          No blocked accounts
        </h3>
        <p className="text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          People you block will appear here
        </p>
      </GlassCard>
    </div>
  );
}
