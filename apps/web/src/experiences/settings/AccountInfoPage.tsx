import React from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowLeft, User } from 'lucide-react';
import { GlassCard, PravaInput, PravaButton } from '../../ui-system';

export default function AccountInfoPage() {
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
            <PravaInput label="First Name" placeholder="Enter first name" />
            <PravaInput label="Last Name" placeholder="Enter last name" />
          </div>
          <PravaInput label="Email" placeholder="your@email.com" type="email" />
          <PravaInput label="Phone Number" placeholder="+1 (555) 000-0000" />
          <PravaButton label="Save Changes" />
        </div>
      </GlassCard>
    </div>
  );
}
