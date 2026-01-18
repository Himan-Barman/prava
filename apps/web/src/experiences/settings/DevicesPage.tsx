import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowLeft, Smartphone, Monitor, Tablet, Trash2 } from 'lucide-react';
import { GlassCard, PravaButton } from '../../ui-system';
import { sessionService, DeviceSession } from '../../services/session-service';
import { smartToast } from '../../ui-system/components/SmartToast';
import { timeAgo } from '../../utils/date-utils';

const iconMap: Record<string, typeof Monitor> = {
  web: Monitor,
  ios: Smartphone,
  android: Smartphone,
  desktop: Monitor,
  mobile: Smartphone,
  tablet: Tablet,
};

export default function DevicesPage() {
  const [sessions, setSessions] = useState<DeviceSession[]>([]);
  const [loading, setLoading] = useState(true);
  const [currentDeviceId, setCurrentDeviceId] = useState('');

  useEffect(() => {
    const loadSessions = async () => {
      try {
        setCurrentDeviceId(sessionService.currentDeviceId());
        const data = await sessionService.listSessions();
        setSessions(data);
      } catch (error) {
        smartToast.error('Unable to load devices');
      } finally {
        setLoading(false);
      }
    };

    loadSessions();
  }, []);

  const handleRevoke = async (deviceId: string) => {
    try {
      await sessionService.revokeSession(deviceId);
      setSessions((prev) => prev.filter((session) => session.deviceId !== deviceId));
      smartToast.success('Device revoked');
    } catch {
      smartToast.error('Unable to revoke device');
    }
  };

  const handleRevokeOthers = async () => {
    try {
      await sessionService.revokeOtherSessions(currentDeviceId);
      setSessions((prev) => prev.filter((session) => session.deviceId === currentDeviceId));
      smartToast.success('Other sessions removed');
    } catch {
      smartToast.error('Unable to revoke other devices');
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
          Devices
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Manage your logged-in devices
        </p>
      </motion.div>

      <div className="space-y-3">
        {loading ? (
          <GlassCard className="text-center py-10">
            <div className="w-8 h-8 border-2 border-prava-accent border-t-transparent rounded-full animate-spin mx-auto mb-3" />
            <p className="text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              Loading devices...
            </p>
          </GlassCard>
        ) : sessions.length === 0 ? (
          <GlassCard className="text-center py-10">
            <p className="text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              No active sessions found.
            </p>
          </GlassCard>
        ) : (
          sessions.map((device, i) => {
          const Icon = iconMap[device.platform] || Monitor;
          const isCurrent = device.deviceId === currentDeviceId;
          const lastActive = device.lastSeenAt ? timeAgo(device.lastSeenAt) : 'Recently';
          return (
            <motion.div
              key={device.deviceId}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.4, delay: 0.1 + i * 0.05 }}
            >
              <GlassCard className={isCurrent ? 'border-prava-success/30 bg-prava-success/5' : ''}>
                <div className="flex items-center gap-4">
                  <div className={`p-2.5 rounded-[12px] ${isCurrent ? 'bg-prava-success/10' : 'bg-prava-accent/10'}`}>
                    <Icon className={`w-5 h-5 ${isCurrent ? 'text-prava-success' : 'text-prava-accent'}`} />
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <p className="font-medium text-body text-prava-light-text-primary dark:text-prava-dark-text-primary">
                        {device.deviceName || device.platform}
                      </p>
                      {isCurrent && (
                        <span className="px-2 py-0.5 rounded-full bg-prava-success/10 text-prava-success text-caption font-semibold">
                          This device
                        </span>
                      )}
                    </div>
                    <p className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                      Last active {lastActive}
                    </p>
                  </div>
                  {!isCurrent && (
                    <button
                      onClick={() => handleRevoke(device.deviceId)}
                      className="p-2.5 rounded-[12px] text-prava-error hover:bg-prava-error/10 transition-colors"
                    >
                      <Trash2 className="w-5 h-5" />
                    </button>
                  )}
                </div>
              </GlassCard>
            </motion.div>
          );
        })
        )}
      </div>

      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.3 }}
        className="mt-6"
      >
        <PravaButton label="Log out all other devices" variant="soft" onClick={handleRevokeOthers} disabled={loading || sessions.length <= 1} />
      </motion.div>
    </div>
  );
}
