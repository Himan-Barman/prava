import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowLeft, Star } from 'lucide-react';
import { GlassCard } from '../../ui-system';

export default function StarredMessagesPage() {
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
          Starred Messages
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Messages you have marked as important
        </p>
      </motion.div>

      {/* Empty State */}
      <GlassCard className="text-center py-12">
        <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-prava-warning/10 flex items-center justify-center">
          <Star className="w-8 h-8 text-prava-warning" />
        </div>
        <h3 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary mb-2">
          No starred messages
        </h3>
        <p className="text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Star important messages to find them easily
        </p>
      </GlassCard>
    </div>
  );
}
