import React from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowLeft, Shield, Key, Smartphone, CheckCircle } from 'lucide-react';
import { GlassCard, PravaButton } from '../../ui-system';

export default function SecurityCenterPage() {
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
          Security Center
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Manage your account security
        </p>
      </motion.div>

      {/* Security Status */}
      <GlassCard className="mb-6 bg-gradient-to-br from-prava-success/10 to-transparent">
        <div className="flex items-center gap-4">
          <div className="p-3 rounded-full bg-prava-success/20">
            <Shield className="w-6 h-6 text-prava-success" />
          </div>
          <div>
            <h3 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary">
              Your account is secure
            </h3>
            <p className="text-body-sm text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              All security features are enabled
            </p>
          </div>
        </div>
      </GlassCard>

      {/* Security Options */}
      <div className="space-y-4">
        <GlassCard>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <div className="p-2.5 rounded-[12px] bg-prava-accent/10">
                <Key className="w-5 h-5 text-prava-accent" />
              </div>
              <div>
                <p className="font-medium text-body text-prava-light-text-primary dark:text-prava-dark-text-primary">
                  Change Password
                </p>
                <p className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                  Last changed: 30 days ago
                </p>
              </div>
            </div>
            <PravaButton label="Change" variant="ghost" fullWidth={false} />
          </div>
        </GlassCard>

        <GlassCard>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <div className="p-2.5 rounded-[12px] bg-prava-success/10">
                <Smartphone className="w-5 h-5 text-prava-success" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <p className="font-medium text-body text-prava-light-text-primary dark:text-prava-dark-text-primary">
                    Two-Factor Authentication
                  </p>
                  <span className="px-2 py-0.5 rounded-full bg-prava-success/10 text-prava-success text-caption font-semibold">
                    Enabled
                  </span>
                </div>
                <p className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                  Using authenticator app
                </p>
              </div>
            </div>
            <PravaButton label="Manage" variant="ghost" fullWidth={false} />
          </div>
        </GlassCard>
      </div>
    </div>
  );
}
