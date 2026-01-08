import React from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowLeft, Users, Search } from 'lucide-react';
import { GlassCard, PravaInput, PravaButton } from '../../ui-system';

export default function NewGroupPage() {
  return (
    <div className="max-w-2xl mx-auto">
      {/* Page Header */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="mb-6"
      >
        <Link
          to="/chats"
          className="inline-flex items-center gap-2 text-body font-medium text-prava-light-text-secondary dark:text-prava-dark-text-secondary hover:text-prava-light-text-primary dark:hover:text-prava-dark-text-primary transition-colors mb-4"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Chats
        </Link>
        <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary">
          New Group
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Create a new encrypted group chat
        </p>
      </motion.div>

      <GlassCard className="mb-6">
        <div className="space-y-4">
          <PravaInput
            label="Group Name"
            placeholder="Enter group name"
          />
          <PravaInput
            label="Add Members"
            placeholder="Search for friends..."
            prefixIcon={<Search className="w-5 h-5" />}
          />
        </div>
      </GlassCard>

      <GlassCard>
        <div className="flex items-center gap-3 p-4 bg-prava-accent/10 rounded-[14px] mb-4">
          <Users className="w-5 h-5 text-prava-accent" />
          <p className="text-body-sm text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
            All group messages are end-to-end encrypted
          </p>
        </div>
        <PravaButton label="Create Group" disabled />
      </GlassCard>
    </div>
  );
}
