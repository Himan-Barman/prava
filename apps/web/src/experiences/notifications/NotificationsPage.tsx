import React from 'react';
import { motion } from 'framer-motion';
import { Bell, Heart, MessageCircle, UserPlus, Settings, Check } from 'lucide-react';
import { GlassCard, PravaButton } from '../../ui-system';
import { Link } from 'react-router-dom';

const mockNotifications = [
  { id: 1, type: 'like', user: 'Alice', message: 'liked your post', time: '2m', read: false },
  { id: 2, type: 'comment', user: 'Bob', message: 'commented on your post', time: '15m', read: false },
  { id: 3, type: 'friend', user: 'Carol', message: 'sent you a friend request', time: '1h', read: true },
  { id: 4, type: 'message', user: 'David', message: 'sent you a message', time: '3h', read: true },
];

const iconMap = {
  like: Heart,
  comment: MessageCircle,
  friend: UserPlus,
  message: Bell,
};

const colorMap = {
  like: 'text-prava-error bg-prava-error/10',
  comment: 'text-prava-accent bg-prava-accent/10',
  friend: 'text-prava-success bg-prava-success/10',
  message: 'text-prava-warning bg-prava-warning/10',
};

export default function NotificationsPage() {
  return (
    <div className="max-w-2xl mx-auto">
      {/* Page Header */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="mb-6"
      >
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary">
              Notifications
            </h1>
            <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              Stay updated with your activity
            </p>
          </div>
          <Link
            to="/settings"
            className="p-3 rounded-[14px] bg-prava-light-surface dark:bg-prava-dark-surface border border-prava-light-border dark:border-prava-dark-border hover:bg-prava-light-border/50 dark:hover:bg-prava-dark-border/50 transition-colors"
          >
            <Settings className="w-5 h-5 text-prava-light-text-secondary dark:text-prava-dark-text-secondary" />
          </Link>
        </div>
      </motion.div>

      {/* Mark All Read */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.1 }}
        className="flex justify-end mb-4"
      >
        <button className="flex items-center gap-2 px-4 py-2 rounded-[12px] text-body-sm font-medium text-prava-accent hover:bg-prava-accent/10 transition-colors">
          <Check className="w-4 h-4" />
          Mark all as read
        </button>
      </motion.div>

      {/* Notifications List */}
      <div className="space-y-2">
        {mockNotifications.map((notification, i) => {
          const Icon = iconMap[notification.type as keyof typeof iconMap];
          const colorClass = colorMap[notification.type as keyof typeof colorMap];

          return (
            <motion.div
              key={notification.id}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.4, delay: 0.15 + i * 0.05 }}
              className={`flex items-center gap-3 p-4 rounded-[16px] border transition-colors cursor-pointer ${notification.read
                  ? 'bg-white/50 dark:bg-white/[0.02] border-prava-light-border/30 dark:border-prava-dark-border/30'
                  : 'bg-white/80 dark:bg-white/[0.04] border-prava-light-border/50 dark:border-prava-dark-border/50'
                } hover:bg-white dark:hover:bg-white/[0.08]`}
            >
              {/* Icon */}
              <div className={`p-2.5 rounded-full ${colorClass}`}>
                <Icon className="w-5 h-5" />
              </div>

              {/* Content */}
              <div className="flex-1 min-w-0">
                <p className="text-body text-prava-light-text-primary dark:text-prava-dark-text-primary">
                  <span className="font-semibold">{notification.user}</span>{' '}
                  <span className="text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
                    {notification.message}
                  </span>
                </p>
                <p className="text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                  {notification.time}
                </p>
              </div>

              {/* Unread Indicator */}
              {!notification.read && (
                <div className="w-2 h-2 rounded-full bg-prava-accent" />
              )}
            </motion.div>
          );
        })}
      </div>
    </div>
  );
}
