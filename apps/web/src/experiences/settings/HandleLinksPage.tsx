import React from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowLeft, Link as LinkIcon, Copy, Check } from 'lucide-react';
import { GlassCard, PravaInput, PravaButton } from '../../ui-system';

export default function HandleLinksPage() {
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
          Handle & Links
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Your username and profile links
        </p>
      </motion.div>

      <GlassCard className="mb-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="p-2.5 rounded-[12px] bg-prava-accent/10">
            <LinkIcon className="w-5 h-5 text-prava-accent" />
          </div>
          <h2 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary">
            Your Handle
          </h2>
        </div>

        <PravaInput
          label="Username"
          placeholder="username"
          prefixIcon={<span className="text-prava-light-text-secondary dark:text-prava-dark-text-secondary">@</span>}
        />

        <div className="mt-4 p-3 rounded-[12px] bg-prava-light-surface dark:bg-prava-dark-surface">
          <p className="text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary mb-1">
            Your profile link
          </p>
          <div className="flex items-center gap-2">
            <code className="flex-1 text-body-sm text-prava-accent">
              prava.app/@username
            </code>
            <button className="p-2 rounded-[8px] hover:bg-prava-light-border dark:hover:bg-prava-dark-border transition-colors">
              <Copy className="w-4 h-4 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary" />
            </button>
          </div>
        </div>
      </GlassCard>

      <PravaButton label="Save Changes" />
    </div>
  );
}
