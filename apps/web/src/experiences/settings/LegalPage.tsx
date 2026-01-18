import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowLeft, FileText, ExternalLink } from 'lucide-react';
import { GlassCard } from '../../ui-system';

const legalDocs = [
  { label: 'Terms of Service', description: 'Rules for using Prava' },
  { label: 'Privacy Policy', description: 'How we handle your data' },
  { label: 'Cookie Policy', description: 'Information about cookies' },
  { label: 'Community Guidelines', description: 'Standards for content' },
];

export default function LegalPage() {
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
          Legal
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Terms, privacy, and policies
        </p>
      </motion.div>

      <GlassCard>
        <div className="flex items-center gap-3 mb-4">
          <div className="p-2.5 rounded-[12px] bg-prava-accent/10">
            <FileText className="w-5 h-5 text-prava-accent" />
          </div>
          <h2 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary">
            Legal Documents
          </h2>
        </div>

        <div className="space-y-2">
          {legalDocs.map((doc) => (
            <button
              key={doc.label}
              className="w-full flex items-center justify-between p-4 rounded-[14px] hover:bg-prava-light-surface dark:hover:bg-prava-dark-surface transition-colors text-left"
            >
              <div>
                <p className="font-medium text-body text-prava-light-text-primary dark:text-prava-dark-text-primary">
                  {doc.label}
                </p>
                <p className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                  {doc.description}
                </p>
              </div>
              <ExternalLink className="w-4 h-4 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary" />
            </button>
          ))}
        </div>
      </GlassCard>

      <motion.p
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.4, delay: 0.3 }}
        className="mt-6 text-center text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary"
      >
        Prava v1.0.0 - Built with privacy in mind
      </motion.p>
    </div>
  );
}
