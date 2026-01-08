import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Search as SearchIcon, Users, MessageCircle, Hash, Clock } from 'lucide-react';
import { GlassCard, PravaInput } from '../../ui-system';

const recentSearches = ['alice', 'team discussion', 'project updates'];

export default function SearchPage() {
  const [query, setQuery] = useState('');

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
          Search
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Find people, messages, and more
        </p>
      </motion.div>

      {/* Search Input */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.1 }}
        className="mb-6"
      >
        <PravaInput
          placeholder="Search for anything..."
          prefixIcon={<SearchIcon className="w-5 h-5" />}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
      </motion.div>

      {/* Quick Filters */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.15 }}
        className="flex flex-wrap gap-2 mb-6"
      >
        {[
          { label: 'People', icon: Users },
          { label: 'Messages', icon: MessageCircle },
          { label: 'Tags', icon: Hash },
        ].map((filter) => (
          <button
            key={filter.label}
            className="flex items-center gap-2 px-4 py-2.5 rounded-[12px] bg-prava-light-surface dark:bg-prava-dark-surface border border-prava-light-border dark:border-prava-dark-border text-body-sm font-medium text-prava-light-text-secondary dark:text-prava-dark-text-secondary hover:text-prava-light-text-primary dark:hover:text-prava-dark-text-primary hover:border-prava-accent/50 transition-colors"
          >
            <filter.icon className="w-4 h-4" />
            {filter.label}
          </button>
        ))}
      </motion.div>

      {/* Recent Searches */}
      {!query && (
        <motion.div
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4, delay: 0.2 }}
        >
          <div className="flex items-center gap-2 mb-3">
            <Clock className="w-4 h-4 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary" />
            <h2 className="text-label font-semibold text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary uppercase tracking-wider">
              Recent Searches
            </h2>
          </div>
          <GlassCard>
            <div className="space-y-1">
              {recentSearches.map((search, i) => (
                <button
                  key={i}
                  onClick={() => setQuery(search)}
                  className="w-full flex items-center gap-3 p-3 rounded-[12px] text-left hover:bg-prava-light-surface dark:hover:bg-prava-dark-surface transition-colors"
                >
                  <SearchIcon className="w-4 h-4 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary" />
                  <span className="text-body text-prava-light-text-primary dark:text-prava-dark-text-primary">
                    {search}
                  </span>
                </button>
              ))}
            </div>
          </GlassCard>
        </motion.div>
      )}

      {/* Search Results Placeholder */}
      {query && (
        <motion.div
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3 }}
        >
          <GlassCard className="text-center py-12">
            <SearchIcon className="w-12 h-12 mx-auto mb-4 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary" />
            <h3 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary mb-2">
              Searching for &quot;{query}&quot;
            </h3>
            <p className="text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              Results will appear here
            </p>
          </GlassCard>
        </motion.div>
      )}
    </div>
  );
}
