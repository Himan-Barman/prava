import { useEffect, useRef, useState, type ReactNode } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useAuth } from '../context/auth-context';
import { motion, AnimatePresence } from 'framer-motion';
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
      <div className="min-h-screen flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-prava-accent border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!isAuthenticated) {
    return <>{children}</>;
  }

  return (
    <LenisProvider>
      <div className={`prava-app min-h-screen min-h-dvh bg-prava-light-bg dark:bg-prava-dark-bg ${isMainTabRoute ? 'prava-main-tab' : 'prava-detail-route'} ${mobileChromeVisible ? '' : 'mobile-chrome-hidden'}`}>
        {/* Background Gradient */}
        <div className="fixed inset-0 -z-10 prava-gradient-bg opacity-60 dark:opacity-40" />

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
        <main className="
          min-h-screen min-h-dvh
          pb-[78px] tablet:pb-0 laptop:pb-0 desktop:pb-0
          tablet:ml-[72px] laptop:ml-[72px] desktop:ml-[72px]
        ">
          <AnimatePresence mode="wait">
            <motion.div
              key={location.pathname}
              initial={{ opacity: 0, x: 10, scale: 0.992 }}
              animate={{ opacity: 1, x: 0, scale: 1 }}
              exit={{ opacity: 0, x: -8, scale: 0.992 }}
              transition={{ duration: 0.22, ease: [0.22, 1, 0.36, 1] }}
              className="prava-app-content px-4 py-2 sm:px-5 sm:py-4 lg:px-6 lg:py-5"
            >
              {children}
            </motion.div>
          </AnimatePresence>
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
      className={`app-mobile-topbar safe-top tablet:hidden laptop:hidden desktop:hidden ${visible ? 'app-mobile-topbar--visible' : 'app-mobile-topbar--hidden'}`}
    >
      <div className="app-mobile-topbar__inner">
        <h1>{title}</h1>
        <div className="app-mobile-topbar__actions">
          {pathname === '/feed' && (
            <>
              <Link to="/search" aria-label="Search">
                <Search className="h-[27px] w-[27px]" strokeWidth={3} />
              </Link>
              <Link to="/notifications" aria-label="Notifications">
                <Bell className="h-[27px] w-[27px]" strokeWidth={3} />
              </Link>
              <Link to="/settings" aria-label="Settings">
                <Menu className="h-[29px] w-[29px]" strokeWidth={3} />
              </Link>
            </>
          )}
          {pathname === '/chats' && (
            <Link to="/settings" aria-label="Chat options">
              <MoreVertical className="h-[27px] w-[27px]" strokeWidth={3} />
            </Link>
          )}
          {pathname === '/profile' && (
            <Link to="/settings/account" aria-label="Edit profile">
              <Edit3 className="h-[26px] w-[26px]" strokeWidth={3} />
            </Link>
          )}
        </div>
      </div>
    </header>
  );
}
