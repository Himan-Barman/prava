import { useEffect, useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import { Link, useNavigate } from 'react-router-dom';
import { ArrowLeft, Users, Search, X } from 'lucide-react';
import { GlassCard, PravaInput, PravaButton } from '../../ui-system';
import { usersService, UserSearchResult } from '../../services/users-service';
import { messagesService } from '../../services/messages-service';
import { smartToast } from '../../ui-system/components/SmartToast';

export default function NewGroupPage() {
  const navigate = useNavigate();
  const [groupName, setGroupName] = useState('');
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<UserSearchResult[]>([]);
  const [selected, setSelected] = useState<UserSearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [creating, setCreating] = useState(false);

  const selectedIds = useMemo(() => new Set(selected.map((member) => member.id)), [selected]);

  useEffect(() => {
    const trimmed = query.trim();
    if (trimmed.length < 2) {
      setResults([]);
      setSearching(false);
      return;
    }

    setSearching(true);
    const timer = setTimeout(async () => {
      try {
        const data = await usersService.searchUsers(trimmed, 12);
        setResults(data);
      } catch (error) {
        smartToast.error('Search failed');
      } finally {
        setSearching(false);
      }
    }, 300);

    return () => clearTimeout(timer);
  }, [query]);

  const toggleSelect = (user: UserSearchResult) => {
    setSelected((prev) => (
      prev.some((member) => member.id === user.id)
        ? prev.filter((member) => member.id !== user.id)
        : [...prev, user]
    ));
  };

  const handleCreateGroup = async () => {
    const title = groupName.trim();
    if (!title) {
      smartToast.warning('Group name is required');
      return;
    }

    if (selected.length === 0) {
      smartToast.warning('Add at least one member');
      return;
    }

    setCreating(true);
    try {
      await messagesService.createGroup(title, selected.map((member) => member.id));
      smartToast.success('Group created');
      navigate('/chats');
    } catch (error) {
      smartToast.error('Unable to create group');
    } finally {
      setCreating(false);
    }
  };

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
            label="Group name"
            placeholder="Enter group name"
            value={groupName}
            onChange={(e) => setGroupName(e.target.value)}
          />
          <PravaInput
            label="Add members"
            placeholder="Search for people..."
            prefixIcon={<Search className="w-5 h-5" />}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
        </div>

        {selected.length > 0 && (
          <div className="mt-4 flex flex-wrap gap-2">
            {selected.map((member) => (
              <div
                key={member.id}
                className="flex items-center gap-2 px-3 py-2 rounded-full bg-prava-light-surface dark:bg-prava-dark-surface border border-prava-light-border dark:border-prava-dark-border"
              >
                <span className="w-6 h-6 rounded-full bg-prava-accent/15 text-prava-accent flex items-center justify-center text-xs font-semibold">
                  {member.displayName.charAt(0)}
                </span>
                <span className="text-body-sm text-prava-light-text-primary dark:text-prava-dark-text-primary">
                  {member.displayName}
                </span>
                <button
                  type="button"
                  onClick={() => toggleSelect(member)}
                  className="p-1 rounded-full hover:bg-black/5 dark:hover:bg-white/10 transition-colors"
                >
                  <X className="w-3.5 h-3.5 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary" />
                </button>
              </div>
            ))}
          </div>
        )}
      </GlassCard>

      <GlassCard className="mb-6">
        <div className="flex items-center gap-3 mb-4">
          <div className="p-2.5 rounded-[12px] bg-prava-accent/10">
            <Users className="w-5 h-5 text-prava-accent" />
          </div>
          <div>
            <h2 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary">
              Add members
            </h2>
            <p className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
              Search and tap to add people to the group
            </p>
          </div>
        </div>

        {query.trim().length < 2 ? (
          <div className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
            Type at least two characters to search.
          </div>
        ) : searching ? (
          <div className="flex items-center gap-3 text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
            <div className="w-5 h-5 border-2 border-prava-accent border-t-transparent rounded-full animate-spin" />
            Searching...
          </div>
        ) : results.length === 0 ? (
          <div className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
            No results found.
          </div>
        ) : (
          <div className="space-y-2">
            {results.map((user) => {
              const isSelected = selectedIds.has(user.id);
              return (
                <button
                  key={user.id}
                  type="button"
                  onClick={() => toggleSelect(user)}
                  className={`w-full flex items-center gap-3 p-3 rounded-[16px] border transition-colors ${
                    isSelected
                      ? 'bg-prava-success/10 border-prava-success/30'
                      : 'bg-white/70 dark:bg-white/[0.04] border-prava-light-border/60 dark:border-prava-dark-border/60 hover:bg-prava-light-surface dark:hover:bg-prava-dark-surface'
                  }`}
                >
                  <div className="w-10 h-10 rounded-full bg-prava-accent/15 flex items-center justify-center text-prava-accent font-semibold">
                    {user.displayName.charAt(0)}
                  </div>
                  <div className="flex-1 text-left">
                    <p className="font-semibold text-prava-light-text-primary dark:text-prava-dark-text-primary">
                      {user.displayName}
                    </p>
                    <p className="text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                      @{user.username}
                    </p>
                  </div>
                  <span className={`px-3 py-1.5 rounded-full text-caption font-semibold ${
                    isSelected
                      ? 'bg-prava-success/15 text-prava-success'
                      : 'bg-prava-light-surface dark:bg-prava-dark-surface text-prava-light-text-secondary dark:text-prava-dark-text-secondary'
                  }`}>
                    {isSelected ? 'Added' : 'Add'}
                  </span>
                </button>
              );
            })}
          </div>
        )}
      </GlassCard>

      <GlassCard>
        <div className="flex items-center gap-3 p-4 bg-prava-accent/10 rounded-[14px] mb-4">
          <Users className="w-5 h-5 text-prava-accent" />
          <p className="text-body-sm text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
            All group messages are end-to-end encrypted
          </p>
        </div>
        <PravaButton
          label={creating ? 'Creating...' : 'Create group'}
          disabled={creating || !groupName.trim() || selected.length === 0}
          onClick={handleCreateGroup}
        />
      </GlassCard>
    </div>
  );
}
