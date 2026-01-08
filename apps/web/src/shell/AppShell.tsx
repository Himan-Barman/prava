import React from 'react';
import { useLocation } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { Sidebar } from './Sidebar';
import { LenisProvider } from './LenisProvider';
import { smartToast } from '../ui-system/components/SmartToast';

interface AppShellProps {
  children: React.ReactNode;
}

// Routes that don't show the sidebar
const authRoutes = ['/login', '/signup', '/verify-email', '/set-password', '/forgot-password', '/reset-password'];

export default function AppShell({ children }: AppShellProps) {
  const location = useLocation();
  const isAuthRoute = authRoutes.some(route => location.pathname.startsWith(route));

  // Dismiss toasts on route change
  React.useEffect(() => {
    smartToast.dismissAll();
  }, [location.pathname]);

  // Auth pages have no shell
  if (isAuthRoute) {
    return <>{children}</>;
  }

  return (
    <LenisProvider>
      <div className="min-h-screen min-h-dvh bg-prava-light-bg dark:bg-prava-dark-bg">
        {/* Background Gradient */}
        <div className="fixed inset-0 -z-10 prava-gradient-bg opacity-60 dark:opacity-40" />

        <Sidebar />

        {/* Main Content - Responsive margins */}
        <main className="
          min-h-screen min-h-dvh
          pb-20 tablet:pb-0 laptop:pb-0 desktop:pb-0
          tablet:ml-[80px] laptop:ml-[80px] desktop:ml-[80px]
        ">
          <AnimatePresence mode="wait">
            <motion.div
              key={location.pathname}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -8 }}
              transition={{ duration: 0.2, ease: [0.4, 0, 0.2, 1] }}
              className="p-4 sm:p-6 lg:p-8"
            >
              {children}
            </motion.div>
          </AnimatePresence>
        </main>
      </div>
    </LenisProvider>
  );
}
