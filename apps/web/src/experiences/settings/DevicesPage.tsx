import React from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowLeft, Smartphone, Monitor, Tablet, Trash2, CheckCircle } from 'lucide-react';
import { GlassCard, PravaButton } from '../../ui-system';

const devices = [
  { id: 1, name: 'Chrome on Windows', type: 'desktop', location: 'New York, US', current: true, lastActive: 'Now' },
  { id: 2, name: 'Safari on iPhone', type: 'mobile', location: 'New York, US', current: false, lastActive: '2h ago' },
  { id: 3, name: 'Chrome on MacBook', type: 'laptop', location: 'Boston, US', current: false, lastActive: '1d ago' },
];

const iconMap = {
  desktop: Monitor,
  mobile: Smartphone,
  laptop: Monitor,
  tablet: Tablet,
};

export default function DevicesPage() {
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
          Devices
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Manage your logged-in devices
        </p>
      </motion.div>

      <div className="space-y-3">
        {devices.map((device, i) => {
          const Icon = iconMap[device.type as keyof typeof iconMap] || Monitor;
          return (
            <motion.div
              key={device.id}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.4, delay: 0.1 + i * 0.05 }}
            >
              <GlassCard className={device.current ? 'border-prava-success/30 bg-prava-success/5' : ''}>
                <div className="flex items-center gap-4">
                  <div className={`p-2.5 rounded-[12px] ${device.current ? 'bg-prava-success/10' : 'bg-prava-accent/10'}`}>
                    <Icon className={`w-5 h-5 ${device.current ? 'text-prava-success' : 'text-prava-accent'}`} />
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <p className="font-medium text-body text-prava-light-text-primary dark:text-prava-dark-text-primary">
                        {device.name}
                      </p>
                      {device.current && (
                        <span className="px-2 py-0.5 rounded-full bg-prava-success/10 text-prava-success text-caption font-semibold">
                          This device
                        </span>
                      )}
                    </div>
                    <p className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                      {device.location} - {device.lastActive}
                    </p>
                  </div>
                  {!device.current && (
                    <button className="p-2.5 rounded-[12px] text-prava-error hover:bg-prava-error/10 transition-colors">
                      <Trash2 className="w-5 h-5" />
                    </button>
                  )}
                </div>
              </GlassCard>
            </motion.div>
          );
        })}
      </div>

      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.3 }}
        className="mt-6"
      >
        <PravaButton label="Log out all other devices" variant="soft" />
      </motion.div>
    </div>
  );
}
