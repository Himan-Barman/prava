import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { UserX } from 'lucide-react';
import { privacyService, BlockedUser } from '../../services/privacy-service';
import { smartToast } from '../../ui-system/components/SmartToast';
import { timeAgo } from '../../utils/date-utils';

export default function BlockedAccountsPage() {
  const [blocked, setBlocked] = useState<BlockedUser[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadBlocked = async () => {
      try {
        const data = await privacyService.fetchBlocked();
        setBlocked(data);
      } catch (error) {
        smartToast.error('Unable to load blocked accounts');
      } finally {
        setLoading(false);
      }
    };

    loadBlocked();
  }, []);

  const handleUnblock = async (userId: string) => {
    try {
      await privacyService.unblockUser(userId);
      setBlocked((prev) => prev.filter((item) => item.id !== userId));
      smartToast.success('User unblocked');
    } catch {
      smartToast.error('Unable to unblock user');
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
        <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary">
          Blocked Accounts
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          People you have blocked
        </p>
      </motion.div>

      {loading ? (
        <div className="text-center py-12">
          <div className="w-8 h-8 border-2 border-prava-accent border-t-transparent rounded-full animate-spin mx-auto mb-3" />
          <p className="text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
            Loading blocked accounts...
          </p>
        </div>
      ) : blocked.length === 0 ? (
        <div className="text-center py-12">
          <UserX className="w-10 h-10 mx-auto mb-4 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary" strokeWidth={3} />
          <h3 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary mb-2">
            No blocked accounts
          </h3>
          <p className="text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
            People you block will appear here
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {blocked.map((user) => (
            <div key={user.id} className="flex items-center gap-4 py-3">
              <div className="w-12 h-12 rounded-full bg-prava-accent/15 flex items-center justify-center text-prava-accent font-semibold">
                {user.displayName.charAt(0)}
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-semibold text-prava-light-text-primary dark:text-prava-dark-text-primary">
                  {user.displayName}
                </p>
                <p className="text-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                  @{user.username} - {user.blockedAt ? timeAgo(user.blockedAt) : 'recently'}
                </p>
              </div>
              <button
                onClick={() => handleUnblock(user.id)}
                className="px-3 py-2 text-prava-accent hover:bg-prava-accent/10 rounded-[12px] transition-colors text-body-sm font-semibold"
              >
                Unblock
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
