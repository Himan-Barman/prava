import { useState } from 'react';
import { motion } from 'framer-motion';
import { HelpCircle, MessageSquare, Bug, Lightbulb, ExternalLink, Send } from 'lucide-react';
import { supportService } from '../../services/support-service';
import { smartToast } from '../../ui-system/components/SmartToast';

const helpTopics = [
  { label: 'Getting Started', icon: Lightbulb, description: 'Learn the basics of Prava' },
  { label: 'Account Issues', icon: HelpCircle, description: 'Password, login, and account recovery' },
  { label: 'Privacy & Security', icon: MessageSquare, description: 'End-to-end encryption explained' },
];

export default function SupportPage() {
  const [mode, setMode] = useState<'report' | 'feedback'>('report');
  const [subject, setSubject] = useState('');
  const [message, setMessage] = useState('');
  const [sending, setSending] = useState(false);

  const handleSubmit = async () => {
    if (!message.trim()) {
      smartToast.warning('Please enter a message');
      return;
    }

    setSending(true);
    try {
      const fullMessage = subject.trim().length > 0
        ? `${subject.trim()}\n\n${message.trim()}`
        : message.trim();

      if (mode === 'report') {
        await supportService.sendReport({
          category: 'bug',
          message: fullMessage,
          includeLogs: false,
        });
      } else {
        await supportService.sendFeedback({
          score: 5,
          message: fullMessage,
          allowContact: true,
        });
      }

      smartToast.success('Message sent');
      setSubject('');
      setMessage('');
    } catch {
      smartToast.error('Failed to send message');
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto pb-8">
      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35 }}
        className="app-page-header"
      >
        <h1 className="app-page-title">Help & Support</h1>
        <p className="app-page-subtitle">Get help or send us feedback</p>
      </motion.div>

      {/* Quick Help */}
      <motion.div
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, delay: 0.05 }}
        style={{ marginBottom: 20 }}
      >
        <p style={{
          fontSize: 11, fontWeight: 700,
          textTransform: 'uppercase' as const, letterSpacing: '0.08em',
          color: 'var(--text-tertiary)', marginBottom: 8,
        }}>Quick Help</p>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          {helpTopics.map((topic) => {
            const Icon = topic.icon;
            return (
              <div key={topic.label} className="app-list-item" style={{ cursor: 'pointer' }}>
                <div className="app-settings-row__icon">
                  <Icon size={16} />
                </div>
                <div className="app-list-item__body">
                  <div className="app-list-item__name">{topic.label}</div>
                  <div className="app-list-item__meta">{topic.description}</div>
                </div>
                <ExternalLink size={14} style={{ color: 'var(--text-tertiary)' }} />
              </div>
            );
          })}
        </div>
      </motion.div>

      {/* Contact Form */}
      <motion.div
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, delay: 0.1 }}
      >
        <p style={{
          fontSize: 11, fontWeight: 700,
          textTransform: 'uppercase' as const, letterSpacing: '0.08em',
          color: 'var(--text-tertiary)', marginBottom: 8,
        }}>Contact Us</p>

        <div className="app-card">
          {/* Mode toggle */}
          <div style={{ display: 'flex', gap: 6, marginBottom: 14 }}>
            <button
              onClick={() => setMode('report')}
              className={`app-btn app-btn--sm ${mode === 'report' ? 'app-btn--primary' : 'app-btn--ghost'}`}
              style={{ flex: 1 }}
            >
              <Bug size={13} /> Report Bug
            </button>
            <button
              onClick={() => setMode('feedback')}
              className={`app-btn app-btn--sm ${mode === 'feedback' ? 'app-btn--primary' : 'app-btn--ghost'}`}
              style={{ flex: 1 }}
            >
              <Lightbulb size={13} /> Suggestion
            </button>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <div>
              <label style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-tertiary)', display: 'block', marginBottom: 4 }}>
                SUBJECT
              </label>
              <input
                className="app-search-input"
                placeholder="Brief description"
                value={subject}
                onChange={(e) => setSubject(e.target.value)}
                style={{ paddingLeft: 14 }}
              />
            </div>

            <div>
              <label style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-tertiary)', display: 'block', marginBottom: 4 }}>
                MESSAGE
              </label>
              <textarea
                placeholder="Describe your issue or feedback..."
                rows={4}
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                style={{
                  width: '100%', padding: 12, borderRadius: 12, resize: 'none',
                  background: 'var(--card-bg)', border: '1px solid var(--border)',
                  color: 'var(--text-primary)', fontSize: 14,
                  fontFamily: 'inherit', outline: 'none',
                }}
              />
            </div>

            <button
              className="app-btn app-btn--primary"
              onClick={handleSubmit}
              disabled={sending}
              style={{ width: '100%', height: 42 }}
            >
              <Send size={14} />
              {sending ? 'Sending...' : 'Send Message'}
            </button>
          </div>
        </div>
      </motion.div>
    </div>
  );
}
