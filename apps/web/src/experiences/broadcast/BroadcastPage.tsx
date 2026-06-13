import { motion } from 'framer-motion';
import { Radio, Users, Send, Lock } from 'lucide-react';

export default function BroadcastPage() {
  return (
    <div className="max-w-2xl mx-auto pb-8">
      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35 }}
        className="app-page-header"
      >
        <h1 className="app-page-title">Broadcast</h1>
        <p className="app-page-subtitle">Send encrypted messages to multiple recipients</p>
      </motion.div>

      {/* Info Banner */}
      <motion.div
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, delay: 0.05 }}
        style={{
          display: 'flex', alignItems: 'flex-start', gap: 10,
          padding: '12px 14px', borderRadius: 12, marginBottom: 16,
          background: 'rgba(91,140,255,0.06)',
          border: '1px solid rgba(91,140,255,0.12)',
        }}
      >
        <Lock size={16} style={{ color: 'var(--p-brand)', flexShrink: 0, marginTop: 1 }} />
        <p style={{ fontSize: 13, color: 'var(--text-secondary)', lineHeight: 1.5 }}>
          Broadcast messages are individually encrypted for each recipient. Only they can read the message.
        </p>
      </motion.div>

      {/* Create Broadcast */}
      <motion.div
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, delay: 0.1 }}
        className="app-card"
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16 }}>
          <div className="app-settings-row__icon">
            <Radio size={16} />
          </div>
          <h2 style={{ fontSize: 16, fontWeight: 700, color: 'var(--text-primary)' }}>New Broadcast</h2>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          {/* Name */}
          <div>
            <label style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-tertiary)', display: 'block', marginBottom: 4 }}>
              BROADCAST NAME
            </label>
            <input
              className="app-search-input"
              placeholder="Give your broadcast a name"
              style={{ paddingLeft: 14 }}
            />
          </div>

          {/* Recipients */}
          <div>
            <label style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-tertiary)', display: 'block', marginBottom: 4 }}>
              SELECT RECIPIENTS
            </label>
            <div style={{
              padding: 24, borderRadius: 12, textAlign: 'center',
              background: 'var(--hover-bg)',
              border: '1px solid var(--border)',
            }}>
              <Users size={22} style={{ margin: '0 auto 6px', color: 'var(--text-tertiary)' }} />
              <p style={{ fontSize: 13, color: 'var(--text-tertiary)' }}>Click to select recipients</p>
            </div>
          </div>

          {/* Message */}
          <div>
            <label style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-tertiary)', display: 'block', marginBottom: 4 }}>
              MESSAGE
            </label>
            <textarea
              placeholder="Write your broadcast message..."
              rows={4}
              style={{
                width: '100%', padding: 12, borderRadius: 12, resize: 'none',
                background: 'var(--card-bg)', border: '1px solid var(--border)',
                color: 'var(--text-primary)', fontSize: 14,
                fontFamily: 'inherit', outline: 'none',
              }}
            />
          </div>

          <button className="app-btn app-btn--primary" disabled style={{ opacity: 0.4 }}>
            <Send size={14} />
            Send Broadcast
          </button>
        </div>
      </motion.div>
    </div>
  );
}
