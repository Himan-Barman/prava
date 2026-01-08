import React from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowLeft, Download, FileText, MessageCircle, Users, Lock } from 'lucide-react';
import { GlassCard, PravaButton } from '../../ui-system';

export default function DataExportPage() {
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
          Data Export
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Download a copy of your data
        </p>
      </motion.div>

      <GlassCard className="mb-6">
        <div className="flex items-center gap-3 mb-4">
          <div className="p-2.5 rounded-[12px] bg-prava-accent/10">
            <Download className="w-5 h-5 text-prava-accent" />
          </div>
          <h2 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary">
            Export Options
          </h2>
        </div>

        <p className="text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary mb-4">
          Select the data you want to export. Your data will be prepared and sent to your email.
        </p>

        <div className="space-y-3">
          {[
            { icon: FileText, label: 'Posts', description: 'All your posts and media' },
            { icon: MessageCircle, label: 'Messages', description: 'Chat history (if decryptable)' },
            { icon: Users, label: 'Connections', description: 'Friends and followers' },
          ].map((item) => (
            <label key={item.label} className="flex items-center gap-4 p-4 rounded-[14px] bg-prava-light-surface dark:bg-prava-dark-surface cursor-pointer hover:bg-prava-light-border/50 dark:hover:bg-prava-dark-border/50 transition-colors">
              <input type="checkbox" className="w-5 h-5 rounded border-prava-light-border dark:border-prava-dark-border text-prava-accent focus:ring-prava-accent" />
              <item.icon className="w-5 h-5 text-prava-accent" />
              <div className="flex-1">
                <p className="font-medium text-body text-prava-light-text-primary dark:text-prava-dark-text-primary">
                  {item.label}
                </p>
                <p className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                  {item.description}
                </p>
              </div>
            </label>
          ))}
        </div>
      </GlassCard>

      <div className="flex items-start gap-3 p-4 rounded-[14px] bg-prava-warning/10 border border-prava-warning/20 mb-6">
        <Lock className="w-5 h-5 text-prava-warning shrink-0 mt-0.5" />
        <p className="text-body-sm text-prava-light-text-primary dark:text-prava-dark-text-primary">
          End-to-end encrypted messages can only be exported if you have the decryption keys on this device.
        </p>
      </div>

      <PravaButton label="Request Export" />
    </div>
  );
}
