import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { Download, FileText, MessageCircle, Users, Lock } from 'lucide-react';
import { PravaButton } from '../../ui-system';
import { dataExportService, DataExport } from '../../services/data-export-service';
import { smartToast } from '../../ui-system/components/SmartToast';
import { timeAgo } from '../../utils/date-utils';

export default function DataExportPage() {
  const [exportData, setExportData] = useState<DataExport | null>(null);
  const [loading, setLoading] = useState(true);
  const [requesting, setRequesting] = useState(false);

  useEffect(() => {
    const loadExport = async () => {
      try {
        const data = await dataExportService.fetchLatest();
        setExportData(data);
      } catch {
        smartToast.error('Unable to load export status');
      } finally {
        setLoading(false);
      }
    };

    loadExport();
  }, []);

  const handleRequestExport = async () => {
    if (requesting) return;
    setRequesting(true);
    try {
      const data = await dataExportService.requestExport();
      setExportData(data);
      smartToast.success('Export requested');
    } catch {
      smartToast.error('Unable to request export');
    } finally {
      setRequesting(false);
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
          Data Export
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Download a copy of your data
        </p>
      </motion.div>

      <section className="mb-8">
        <div className="flex items-center gap-3 mb-4">
          <Download className="w-5 h-5 text-prava-accent" strokeWidth={3} />
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
            <label key={item.label} className="flex items-center gap-4 py-3 cursor-pointer transition-colors">
              <input type="checkbox" className="w-5 h-5 rounded border-prava-light-border dark:border-prava-dark-border text-prava-accent focus:ring-prava-accent" />
              <item.icon className="w-5 h-5 text-prava-accent" strokeWidth={3} />
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
      </section>

      <div className="flex items-start gap-3 mb-6">
        <Lock className="w-5 h-5 text-prava-warning shrink-0 mt-0.5" strokeWidth={3} />
        <p className="text-body-sm text-prava-light-text-primary dark:text-prava-dark-text-primary">
          End-to-end encrypted messages can only be exported if you have the decryption keys on this device.
        </p>
      </div>

      <div className="space-y-3">
        {loading ? (
          <p className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
            Checking export status...
          </p>
        ) : exportData ? (
          <div className="text-body-sm text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
            Latest export {exportData.createdAt ? timeAgo(exportData.createdAt) : 'recently'} - {exportData.status}
          </div>
        ) : (
          <div className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
            No previous exports found.
          </div>
        )}
        <PravaButton
          label={requesting ? 'Requesting...' : 'Request Export'}
          onClick={handleRequestExport}
          disabled={requesting}
        />
      </div>
    </div>
  );
}
