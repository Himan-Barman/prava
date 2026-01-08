import React from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowLeft, MessageSquareOff, Plus } from 'lucide-react';
import { GlassCard, PravaInput, PravaButton } from '../../ui-system';

export default function MutedWordsPage() {
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
          Muted Words
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Filter content containing specific words
        </p>
      </motion.div>

      <GlassCard className="mb-6">
        <div className="flex items-center gap-3 mb-4">
          <div className="p-2.5 rounded-[12px] bg-prava-accent/10">
            <MessageSquareOff className="w-5 h-5 text-prava-accent" />
          </div>
          <h2 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary">
            Add Muted Word
          </h2>
        </div>
        <div className="flex gap-3">
          <div className="flex-1">
            <PravaInput placeholder="Enter word or phrase to mute" />
          </div>
          <PravaButton label="Add" icon={<Plus className="w-4 h-4" />} fullWidth={false} />
        </div>
      </GlassCard>

      <GlassCard className="text-center py-12">
        <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-prava-light-surface dark:bg-prava-dark-surface flex items-center justify-center">
          <MessageSquareOff className="w-8 h-8 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary" />
        </div>
        <h3 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary mb-2">
          No muted words
        </h3>
        <p className="text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Add words above to filter them from your feed
        </p>
      </GlassCard>
    </div>
  );
}
