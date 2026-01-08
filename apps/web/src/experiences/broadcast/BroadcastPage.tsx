import React from 'react';
import { motion } from 'framer-motion';
import { Radio, Users, Send, Lock } from 'lucide-react';
import { GlassCard, PravaButton, PravaInput } from '../../ui-system';

export default function BroadcastPage() {
  return (
    <div className="max-w-2xl mx-auto">
      {/* Page Header */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="mb-6"
      >
        <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary">
          Broadcast
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Send encrypted messages to multiple recipients
        </p>
      </motion.div>

      {/* Info Banner */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.1 }}
        className="mb-6"
      >
        <div className="flex items-start gap-3 p-4 rounded-[16px] bg-prava-accent/10 border border-prava-accent/20">
          <Lock className="w-5 h-5 text-prava-accent shrink-0 mt-0.5" />
          <p className="text-body-sm text-prava-light-text-primary dark:text-prava-dark-text-primary">
            Broadcast messages are individually encrypted for each recipient. Only they can read the message.
          </p>
        </div>
      </motion.div>

      {/* Create Broadcast */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.15 }}
      >
        <GlassCard>
          <div className="flex items-center gap-3 mb-6">
            <div className="p-2.5 rounded-[12px] bg-prava-accent/10">
              <Radio className="w-5 h-5 text-prava-accent" />
            </div>
            <h2 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary">
              New Broadcast
            </h2>
          </div>

          <div className="space-y-4">
            <PravaInput
              label="Broadcast Name"
              placeholder="Give your broadcast a name"
            />

            <div>
              <label className="block text-label font-semibold text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary mb-2">
                Select Recipients
              </label>
              <div className="p-4 rounded-[16px] bg-prava-light-surface dark:bg-prava-dark-surface border border-prava-light-border dark:border-prava-dark-border min-h-[100px] flex items-center justify-center">
                <div className="text-center">
                  <Users className="w-8 h-8 mx-auto mb-2 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary" />
                  <p className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                    Click to select recipients
                  </p>
                </div>
              </div>
            </div>

            <div>
              <label className="block text-label font-semibold text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary mb-2">
                Message
              </label>
              <textarea
                placeholder="Write your broadcast message..."
                className="w-full p-4 rounded-[16px] bg-prava-light-surface dark:bg-prava-dark-surface border border-prava-light-border dark:border-prava-dark-border text-body text-prava-light-text-primary dark:text-prava-dark-text-primary placeholder:text-prava-light-text-tertiary dark:placeholder:text-prava-dark-text-tertiary focus:outline-none focus:ring-2 focus:ring-prava-accent/30 resize-none"
                rows={4}
              />
            </div>

            <PravaButton
              label="Send Broadcast"
              icon={<Send className="w-4 h-4" />}
              disabled
            />
          </div>
        </GlassCard>
      </motion.div>
    </div>
  );
}
