import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowLeft, MessageSquareOff, Plus } from 'lucide-react';
import { GlassCard, PravaInput, PravaButton } from '../../ui-system';
import { privacyService, MutedWord } from '../../services/privacy-service';
import { smartToast } from '../../ui-system/components/SmartToast';
import { timeAgo } from '../../utils/date-utils';

export default function MutedWordsPage() {
  const [words, setWords] = useState<MutedWord[]>([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(true);
  const [adding, setAdding] = useState(false);

  useEffect(() => {
    const loadWords = async () => {
      try {
        const data = await privacyService.fetchMutedWords();
        setWords(data);
      } catch (error) {
        smartToast.error('Unable to load muted words');
      } finally {
        setLoading(false);
      }
    };

    loadWords();
  }, []);

  const handleAdd = async () => {
    if (!input.trim() || adding) return;
    setAdding(true);
    try {
      const created = await privacyService.addMutedWord(input.trim());
      if (created) {
        setWords((prev) => [created, ...prev]);
        setInput('');
      }
      smartToast.success('Muted word added');
    } catch {
      smartToast.error('Unable to add muted word');
    } finally {
      setAdding(false);
    }
  };

  const handleRemove = async (wordId: string) => {
    try {
      await privacyService.removeMutedWord(wordId);
      setWords((prev) => prev.filter((word) => word.id !== wordId));
      smartToast.info('Muted word removed');
    } catch {
      smartToast.error('Unable to remove muted word');
    }
  };

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
            <PravaInput
              placeholder="Enter word or phrase to mute"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              disabled={loading}
            />
          </div>
          <PravaButton
            label={adding ? 'Adding...' : 'Add'}
            icon={<Plus className="w-4 h-4" />}
            fullWidth={false}
            onClick={handleAdd}
            disabled={adding || loading}
          />
        </div>
      </GlassCard>

      {loading ? (
        <GlassCard className="text-center py-12">
          <div className="w-8 h-8 border-2 border-prava-accent border-t-transparent rounded-full animate-spin mx-auto mb-3" />
          <p className="text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
            Loading muted words...
          </p>
        </GlassCard>
      ) : words.length === 0 ? (
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
      ) : (
        <div className="space-y-3">
          {words.map((word) => (
            <GlassCard key={word.id} className="flex items-center justify-between">
              <div>
                <p className="font-semibold text-prava-light-text-primary dark:text-prava-dark-text-primary">
                  {word.phrase}
                </p>
                <p className="text-xs text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                  Added {word.createdAt ? timeAgo(word.createdAt) : 'recently'}
                </p>
              </div>
              <button
                onClick={() => handleRemove(word.id)}
                className="px-3 py-2 text-prava-error hover:bg-prava-error/10 rounded-[12px] transition-colors text-body-sm font-semibold"
              >
                Remove
              </button>
            </GlassCard>
          ))}
        </div>
      )}
    </div>
  );
}
