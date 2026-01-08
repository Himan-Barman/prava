import React from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowLeft, HelpCircle, MessageSquare, Bug, Lightbulb, FileText, ExternalLink } from 'lucide-react';
import { GlassCard, PravaButton, PravaInput } from '../../ui-system';

const helpTopics = [
  { label: 'Getting Started', icon: Lightbulb, description: 'Learn the basics of Prava' },
  { label: 'Account Issues', icon: HelpCircle, description: 'Password, login, and account recovery' },
  { label: 'Privacy & Security', icon: FileText, description: 'End-to-end encryption explained' },
];

export default function SupportPage() {
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
          to="/settings"
          className="inline-flex items-center gap-2 text-body font-medium text-prava-light-text-secondary dark:text-prava-dark-text-secondary hover:text-prava-light-text-primary dark:hover:text-prava-dark-text-primary transition-colors mb-4"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Settings
        </Link>
        <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary">
          Help & Support
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Get help or send us feedback
        </p>
      </motion.div>

      {/* Quick Help */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.1 }}
        className="mb-6"
      >
        <h2 className="text-label font-semibold text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary uppercase tracking-wider mb-3">
          Quick Help
        </h2>
        <div className="grid gap-3">
          {helpTopics.map((topic, i) => (
            <GlassCard key={topic.label} delay={0.15 + i * 0.05}>
              <div className="flex items-center gap-4">
                <div className="p-2.5 rounded-[12px] bg-prava-accent/10">
                  <topic.icon className="w-5 h-5 text-prava-accent" />
                </div>
                <div className="flex-1">
                  <p className="font-medium text-body text-prava-light-text-primary dark:text-prava-dark-text-primary">
                    {topic.label}
                  </p>
                  <p className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                    {topic.description}
                  </p>
                </div>
                <ExternalLink className="w-4 h-4 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary" />
              </div>
            </GlassCard>
          ))}
        </div>
      </motion.div>

      {/* Contact Form */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.3 }}
      >
        <h2 className="text-label font-semibold text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary uppercase tracking-wider mb-3">
          Contact Us
        </h2>
        <GlassCard>
          <div className="flex items-center gap-3 mb-6">
            <div className="p-2.5 rounded-[12px] bg-prava-accent/10">
              <MessageSquare className="w-5 h-5 text-prava-accent" />
            </div>
            <div>
              <h3 className="font-semibold text-body text-prava-light-text-primary dark:text-prava-dark-text-primary">
                Send us a message
              </h3>
              <p className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                We typically respond within 24 hours
              </p>
            </div>
          </div>

          <div className="space-y-4">
            <div className="flex gap-3">
              <button className="flex-1 px-4 py-2.5 rounded-[12px] bg-prava-light-surface dark:bg-prava-dark-surface border border-prava-light-border dark:border-prava-dark-border text-body-sm font-medium hover:border-prava-accent/50 transition-colors">
                <Bug className="w-4 h-4 inline mr-2" />
                Report Bug
              </button>
              <button className="flex-1 px-4 py-2.5 rounded-[12px] bg-prava-light-surface dark:bg-prava-dark-surface border border-prava-light-border dark:border-prava-dark-border text-body-sm font-medium hover:border-prava-accent/50 transition-colors">
                <Lightbulb className="w-4 h-4 inline mr-2" />
                Suggestion
              </button>
            </div>

            <PravaInput
              label="Subject"
              placeholder="Brief description of your issue"
            />

            <div>
              <label className="block text-label font-semibold text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary mb-2">
                Message
              </label>
              <textarea
                placeholder="Describe your issue or feedback in detail..."
                className="w-full p-4 rounded-[16px] bg-prava-light-surface dark:bg-prava-dark-surface border border-prava-light-border dark:border-prava-dark-border text-body text-prava-light-text-primary dark:text-prava-dark-text-primary placeholder:text-prava-light-text-tertiary dark:placeholder:text-prava-dark-text-tertiary focus:outline-none focus:ring-2 focus:ring-prava-accent/30 resize-none"
                rows={4}
              />
            </div>

            <PravaButton label="Send Message" />
          </div>
        </GlassCard>
      </motion.div>
    </div>
  );
}
