import { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, useInView, useScroll, useTransform } from 'framer-motion';
import {
  Shield, MessageCircle, Users, Radio, Lock, Eye, Fingerprint,
  Zap, Instagram, Linkedin,
  ArrowUp, Sparkles, KeyRound, BellRing
} from 'lucide-react';

/* ─── Animate-on-scroll wrapper ─── */
function Reveal({ children, delay = 0, className = '' }: { children: React.ReactNode; delay?: number; className?: string }) {
  const ref = useRef(null);
  const inView = useInView(ref, { once: true, margin: '-60px' });
  return (
    <motion.div
      ref={ref}
      initial={{ opacity: 0, y: 32 }}
      animate={inView ? { opacity: 1, y: 0 } : {}}
      transition={{ duration: 0.7, delay, ease: [0.25, 0.46, 0.45, 0.94] }}
      className={className}
    >
      {children}
    </motion.div>
  );
}

/* ─── Feature Card ─── */
function FeatureCard({ icon: Icon, title, desc, accent, delay }: { icon: any; title: string; desc: string; accent: string; delay: number }) {
  return (
    <Reveal delay={delay} className="h-full">
      <div className="landing-feature-card">
        <div className="landing-icon-wrap" style={{ background: accent }}>
          <Icon size={20} strokeWidth={2} className="text-white" />
        </div>
        <h3 className="landing-feature-title">{title}</h3>
        <p className="landing-feature-desc">{desc}</p>
      </div>
    </Reveal>
  );
}

/* ─── Floating Particles ─── */
function Particles() {
  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none">
      {[...Array(6)].map((_, i) => (
        <motion.div
          key={i}
          className="absolute rounded-full"
          style={{
            width: 4 + Math.random() * 4,
            height: 4 + Math.random() * 4,
            background: `rgba(91, 140, 255, ${0.15 + Math.random() * 0.2})`,
            left: `${10 + Math.random() * 80}%`,
            top: `${10 + Math.random() * 80}%`,
          }}
          animate={{
            y: [0, -30, 0],
            opacity: [0.3, 0.7, 0.3],
          }}
          transition={{
            duration: 4 + Math.random() * 3,
            repeat: Infinity,
            delay: i * 0.8,
            ease: 'easeInOut',
          }}
        />
      ))}
    </div>
  );
}

/* ─── Main Landing Page ─── */
export default function LandingPage() {
  const navigate = useNavigate();
  const [showScrollTop, setShowScrollTop] = useState(false);
  const heroRef = useRef<HTMLDivElement>(null);
  const { scrollY } = useScroll();
  const heroOpacity = useTransform(scrollY, [0, 500], [1, 0]);
  const heroScale = useTransform(scrollY, [0, 500], [1, 0.95]);

  useEffect(() => {
    const handler = () => setShowScrollTop(window.scrollY > 600);
    window.addEventListener('scroll', handler, { passive: true });
    return () => window.removeEventListener('scroll', handler);
  }, []);

  const features = [
    { icon: MessageCircle, title: 'Encrypted Chats', desc: 'End-to-end encrypted messaging with Double Ratchet protocol. Your conversations stay truly private.', accent: 'linear-gradient(135deg, #3D63F0, #7E9FFF)' },
    { icon: Users, title: 'Social Feed', desc: 'Share moments with your circle. A beautifully crafted feed experience designed for genuine connections.', accent: 'linear-gradient(135deg, #3CCB7F, #5EDBA0)' },
    { icon: Radio, title: 'Broadcasts', desc: 'Reach your audience with powerful broadcast channels. Share updates with everyone who matters.', accent: 'linear-gradient(135deg, #F4C430, #FFD966)' },
    { icon: Shield, title: 'Security Center', desc: 'Full control over your security. Device management, blocked accounts, and threat monitoring built in.', accent: 'linear-gradient(135deg, #E5533D, #FF7B6B)' },
    { icon: Fingerprint, title: 'Identity Protection', desc: 'Handle-based identity system with privacy-first account verification and data export tools.', accent: 'linear-gradient(135deg, #A855F7, #C084FC)' },
    { icon: BellRing, title: 'Smart Notifications', desc: 'Intelligent notification system that respects your focus. Muted words, quiet hours, and priority alerts.', accent: 'linear-gradient(135deg, #06B6D4, #67E8F9)' },
  ];

  const securityFeatures = [
    { icon: Lock, title: 'End-to-End Encryption', desc: 'Every message encrypted with Signal Protocol.' },
    { icon: KeyRound, title: 'Double Ratchet', desc: 'Forward secrecy with continuous key rotation.' },
    { icon: Eye, title: 'Zero-Knowledge', desc: 'We cannot read your messages. Ever.' },
    { icon: Zap, title: 'Threat Detection', desc: 'Real-time security threat monitoring and alerts.' },
  ];

  return (
    <div className="landing-root">
      {/* ═══ NAVBAR ═══ */}
      <nav className="landing-nav">
        <div className="landing-nav-inner">
          <span className="landing-logo">PRAVA</span>
          <div className="landing-nav-actions">
            <button onClick={() => navigate('/signup')} className="landing-btn-ghost">Sign Up</button>
            <button onClick={() => navigate('/login')} className="landing-btn-primary">
              Log In
            </button>
          </div>
        </div>
      </nav>

      {/* ═══ HERO ═══ */}
      <motion.section ref={heroRef} style={{ opacity: heroOpacity, scale: heroScale }} className="landing-hero">
        <Particles />
        <div className="landing-hero-glow" />

        <div className="landing-hero-content">
          <Reveal>
            <div className="landing-badge">
              <Sparkles size={14} className="text-prava-accent" />
              <span>Privacy-First Social Platform</span>
            </div>
          </Reveal>

          <Reveal delay={0.1}>
            <h1 className="landing-hero-heading">
              Your Space.<br />
              <span className="landing-blue-text">Your Rules.</span>
            </h1>
          </Reveal>

          <Reveal delay={0.2}>
            <p className="landing-hero-sub">
              Prava is a next-generation social platform where privacy isn't a feature — it's the foundation. Connect, share, and communicate with confidence.
            </p>
          </Reveal>

          <Reveal delay={0.3}>
            <div className="landing-hero-ctas">
              <button onClick={() => navigate('/login')} className="landing-btn-hero">
                Get Started
              </button>
              <a href="#features" className="landing-btn-outline">
                Explore Features
              </a>
            </div>
          </Reveal>
        </div>

        {/* Hero bottom fade */}
        <div className="absolute bottom-0 left-0 right-0 h-32 bg-gradient-to-t from-[#080D14] to-transparent" />
      </motion.section>

      {/* ═══ FEATURES ═══ */}
      <section id="features" className="landing-section">
        <div className="landing-container">
          <Reveal>
            <p className="landing-section-label">Features</p>
            <h2 className="landing-section-title">Everything you need,<br />nothing you don't.</h2>
            <p className="landing-section-desc">Crafted with obsessive attention to detail. Every feature serves a purpose.</p>
          </Reveal>

          <div className="landing-features-grid">
            {features.map((f, i) => (
              <FeatureCard key={f.title} {...f} delay={i * 0.1} />
            ))}
          </div>
        </div>
      </section>

      {/* ═══ SECURITY ═══ */}
      <section className="landing-section relative">
        <div className="absolute inset-0 bg-gradient-to-b from-transparent via-[#3D63F0]/[0.03] to-transparent pointer-events-none" />
        <div className="landing-container relative z-10">
          <Reveal>
            <p className="landing-section-label">Security</p>
            <h2 className="landing-section-title">Built on trust.<br />Verified by cryptography.</h2>
            <p className="landing-section-desc">Military-grade encryption protocols protecting every interaction on the platform.</p>
          </Reveal>

          <div className="landing-security-grid">
            {securityFeatures.map((f, i) => (
              <Reveal key={f.title} delay={i * 0.1}>
                <div className="landing-security-card">
                  <f.icon size={20} className="text-prava-accent mb-3" />
                  <h4 className="landing-security-title">{f.title}</h4>
                  <p className="landing-security-desc">{f.desc}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* ═══ CTA ═══ */}
      <section className="landing-section">
        <div className="landing-container">
          <Reveal>
            <div className="landing-cta-card">
              <div className="landing-cta-glow" />
              <h2 className="landing-cta-title">
                Ready to take control?
              </h2>
              <p className="landing-cta-desc">
                Join Prava today and experience social media the way it should be — private, secure, and yours.
              </p>
              <button onClick={() => navigate('/login')} className="landing-btn-hero relative z-10">
                Join Prava
              </button>
            </div>
          </Reveal>
        </div>
      </section>

      {/* ═══ TERMS & CONDITIONS ═══ */}
      <section id="terms" className="landing-section border-t border-[#1d1d1d]">
        <div className="landing-container">
          <Reveal>
            <p className="landing-section-label">Legal</p>
            <h2 className="landing-section-title landing-section-title--sm">Terms &amp; Conditions</h2>
          </Reveal>

          <Reveal delay={0.1}>
            <div className="landing-terms-list">
              {[
                { title: '1. Acceptance of Terms', body: 'By accessing or using Prava, you agree to be bound by these Terms of Service and all applicable laws and regulations. If you do not agree, please do not use the platform.' },
                { title: '2. Privacy & Data', body: 'Your privacy is our highest priority. We employ end-to-end encryption for all messages and do not sell, share, or monetize your personal data. You retain full ownership of your content.' },
                { title: '3. User Conduct', body: 'Users must not engage in harassment, hate speech, spam, or any activity that violates applicable laws. Accounts found in violation may be suspended or permanently removed.' },
                { title: '4. Content Ownership', body: 'You retain all rights to the content you create and share on Prava. By posting, you grant Prava a limited license to display your content within the platform.' },
                { title: '5. Security', body: 'While we implement industry-leading security measures including E2EE and Double Ratchet protocols, users are responsible for maintaining the security of their account credentials.' },
                { title: '6. Service Availability', body: 'Prava strives for 99.9% uptime but does not guarantee uninterrupted service. We reserve the right to modify or discontinue features with reasonable notice.' },
              ].map((t) => (
                <div key={t.title} className="landing-term-item">
                  <h4>{t.title}</h4>
                  <p>{t.body}</p>
                </div>
              ))}
            </div>
          </Reveal>
        </div>
      </section>

      {/* ═══ FOOTER ═══ */}
      <footer className="landing-footer">
        <div className="landing-container">
          <div className="landing-footer-inner">
            {/* Brand */}
            <div className="landing-footer-brand">
              <span className="landing-logo landing-logo--sm">PRAVA</span>
              <p className="landing-footer-tagline">Privacy-first social platform.</p>
            </div>

            {/* Links */}
            <div className="landing-footer-links">
              <a href="#features">Features</a>
              <a href="#terms">Terms</a>
              <button onClick={() => navigate('/login')}>Login</button>
            </div>

            {/* Social */}
            <div className="landing-footer-social">
              <a
                href="https://www.instagram.com/isrhimanbarman"
                target="_blank"
                rel="noopener noreferrer"
                className="landing-social-icon"
                aria-label="Instagram"
              >
                <Instagram size={18} />
              </a>
              <a
                href="https://www.linkedin.com/in/isrhimanbarman"
                target="_blank"
                rel="noopener noreferrer"
                className="landing-social-icon"
                aria-label="LinkedIn"
              >
                <Linkedin size={18} />
              </a>
            </div>
          </div>

          {/* Copyright */}
          <div className="landing-copyright">
            <p>© {new Date().getFullYear()} Prava. All rights reserved. Built with ♥ by Himan Barman.</p>
          </div>
        </div>
      </footer>

      {/* ═══ SCROLL TO TOP ═══ */}
      <motion.button
        initial={{ opacity: 0, scale: 0.8 }}
        animate={showScrollTop ? { opacity: 1, scale: 1 } : { opacity: 0, scale: 0.8 }}
        onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
        className="landing-scroll-top"
        aria-label="Scroll to top"
      >
        <ArrowUp size={16} />
      </motion.button>
    </div>
  );
}
