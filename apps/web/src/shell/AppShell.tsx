import { useEffect, useRef, useState, type ReactNode } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useAuth } from '../context/auth-context';
import { motion } from 'framer-motion';
import { Bell, Edit3, Menu, MoreVertical, Search } from 'lucide-react';
import { Sidebar } from './Sidebar';
import { LenisProvider } from './LenisProvider';
import { smartToast } from '../ui-system/components/SmartToast';

interface AppShellProps {
  children: ReactNode;
}

// Routes that don't show the sidebar
const authRoutes = ['/', '/login', '/signup', '/verify-email', '/set-password', '/forgot-password', '/reset-password', '/set-details'];
const mainTabTitles: Record<string, string> = {
  '/feed': 'Prava',
  '/chats': 'Chats',
  '/friends': 'Friends',
  '/profile': 'Profile',
};

export default function AppShell({ children }: AppShellProps) {
  const location = useLocation();
  const { isAuthenticated, isLoading } = useAuth();
  const isAuthRoute = location.pathname === '/' || authRoutes.slice(1).some(route => location.pathname.startsWith(route));
  const isMainTabRoute = Object.prototype.hasOwnProperty.call(mainTabTitles, location.pathname);
  const [mobileChromeVisible, setMobileChromeVisible] = useState(true);
  const lastScrollY = useRef(0);

  // Dismiss toasts on route change
  useEffect(() => {
    smartToast.dismissAll();
  }, [location.pathname]);

  useEffect(() => {
    setMobileChromeVisible(true);
    lastScrollY.current = window.scrollY;
  }, [location.pathname]);

  useEffect(() => {
    if (location.pathname !== '/feed') {
      return undefined;
    }

    const handleScroll = () => {
      const current = window.scrollY;
      const delta = current - lastScrollY.current;

      if (current <= 8) {
        setMobileChromeVisible(true);
      } else if (delta > 3) {
        setMobileChromeVisible(false);
      } else if (delta < -3) {
        setMobileChromeVisible(true);
      }

      lastScrollY.current = current;
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, [location.pathname]);

  // Auth pages have no shell
  if (isAuthRoute) {
    return <>{children}</>;
  }

  if (isLoading) {
    return (
      <div style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'var(--p-bg-app)',
      }}>
        <div className="p-spinner" />
      </div>
    );
  }

  if (!isAuthenticated) {
    return <>{children}</>;
  }

  return (
    <LenisProvider>
      <div
        className={`prava-app ${isMainTabRoute ? 'prava-main-tab' : 'prava-detail-route'} ${mobileChromeVisible ? '' : 'mobile-chrome-hidden'}`}
        style={{
          minHeight: '100vh',
          background: 'var(--p-bg-app)',
        }}
      >

        {isMainTabRoute && (
          <MobileTopBar
            title={mainTabTitles[location.pathname]}
            pathname={location.pathname}
            visible={mobileChromeVisible}
          />
        )}

        <Sidebar
          mobileChromeVisible={mobileChromeVisible}
          showMobileBottomNav={isMainTabRoute}
        />

        {/* Main Content - Responsive margins */}
        <main
          className="prava-app-main"
          style={{
            minHeight: '100vh',
            paddingBottom: isMainTabRoute ? 78 : 0,
          }}
        >
          <motion.div
            key={location.pathname}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.18, ease: [0.22, 1, 0.36, 1] }}
            className="prava-app-content"
            style={{
              padding: '8px 16px 16px',
            }}
          >
              {children}
          </motion.div>
        </main>
      </div>
    </LenisProvider>
  );
}

function MobileTopBar({
  title,
  pathname,
  visible,
}: {
  title: string;
  pathname: string;
  visible: boolean;
}) {
  return (
    <header
      className={`app-mobile-topbar safe-top ${visible ? 'app-mobile-topbar--visible' : 'app-mobile-topbar--hidden'}`}
      style={{ display: 'block' }}
    >
      <div className="app-mobile-topbar__inner">
        <h1>{title}</h1>
        <div className="app-mobile-topbar__actions">
          {pathname === '/feed' && (
            <>
              <Link to="/search" aria-label="Search">
                <Search className="h-[26px] w-[26px]" strokeWidth={3} />
              </Link>
              <Link to="/notifications" aria-label="Notifications">
                <Bell className="h-[26px] w-[26px]" strokeWidth={3} />
              </Link>
              <Link to="/settings" aria-label="Settings">
                <Menu className="h-[28px] w-[28px]" strokeWidth={3} />
              </Link>
            </>
          )}
          {pathname === '/chats' && (
            <Link to="/settings" aria-label="Chat options">
              <MoreVertical className="h-[26px] w-[26px]" strokeWidth={3} />
            </Link>
          )}
          {pathname === '/profile' && (
            <Link to="/settings/account" aria-label="Edit profile">
              <Edit3 className="h-[24px] w-[24px]" strokeWidth={3} />
            </Link>
          )}
        </div>
      </div>
    </header>
  );
}
