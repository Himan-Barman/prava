import React, { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import {
  LayoutGrid,
  MessageCircle,
  Users,
  User,
  Bell,
  Settings,
  HelpCircle,
  Search,
  Menu,
  X,
  LogOut,
  Moon,
  Sun
} from 'lucide-react';
import { useTheme } from '../ui-system/theme';
import { useAuth } from '../context/auth-context';

interface NavItem {
  path: string;
  label: string;
  icon: React.ReactNode;
}

const mainNavItems: NavItem[] = [
  { path: '/feed', label: 'Feed', icon: <LayoutGrid className="w-6 h-6" /> },
  { path: '/chats', label: 'Chats', icon: <MessageCircle className="w-6 h-6" /> },
  { path: '/friends', label: 'Friends', icon: <Users className="w-6 h-6" /> },
  { path: '/profile', label: 'Profile', icon: <User className="w-6 h-6" /> },
];

const secondaryNavItems: NavItem[] = [
  { path: '/notifications', label: 'Notifications', icon: <Bell className="w-6 h-6" /> },
  { path: '/search', label: 'Search', icon: <Search className="w-6 h-6" /> },
];

const settingsNavItems: NavItem[] = [
  { path: '/settings', label: 'Settings', icon: <Settings className="w-6 h-6" /> },
  { path: '/support', label: 'Support', icon: <HelpCircle className="w-6 h-6" /> },
];

function NavLink({ item, collapsed }: { item: NavItem; collapsed: boolean }) {
  const location = useLocation();
  const isActive = location.pathname === item.path ||
    (item.path !== '/' && location.pathname.startsWith(item.path));

  return (
    <Link
      to={item.path}
      className={`
        group relative flex items-center gap-4 px-4 py-3.5 rounded-[18px]
        font-medium transition-all duration-300
        ${isActive
          ? 'text-prava-accent bg-prava-accent/10 dark:bg-prava-accent/20'
          : 'text-prava-light-text-secondary dark:text-prava-dark-text-secondary hover:text-prava-light-text-primary dark:hover:text-white hover:bg-black/5 dark:hover:bg-white/10'
        }
        ${collapsed ? 'justify-center px-3' : ''}
      `}
    >
      {/* Icon */}
      <span className="relative z-10">{item.icon}</span>

      {/* Label */}
      {!collapsed && (
        <span className="font-semibold tracking-wide">{item.label}</span>
      )}

      {/* Hover Name Tooltip for Collapsed State */}
      {collapsed && (
        <div className="absolute left-full ml-3 px-3 py-1.5 bg-prava-dark-surface text-white text-xs font-semibold rounded-[8px] opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap z-50 shadow-xl border border-white/10">
          {item.label}
        </div>
      )}
    </Link>
  );
}

export function Sidebar() {
  const { isDark, toggleTheme } = useTheme();
  const { logout } = useAuth();
  const [mobileOpen, setMobileOpen] = useState(false);

  const handleLogout = async () => {
    await logout();
    window.location.href = '/login';
  };

  // Desktop Sidebar
  const SidebarContent = ({ collapsed = false }: { collapsed?: boolean }) => (
    <div className="flex flex-col h-full">
      {/* Brand - Updated to only specific "P" Logo */}
      <div className={`flex items-center ${collapsed ? 'justify-center' : 'pl-2'} mb-8 mt-2`}>
        <div className="w-12 h-12 flex items-center justify-center cursor-pointer hover:scale-105 transition-transform duration-300 group relative">
          <span className="text-prava-accent font-bold text-3xl font-outfit">P.</span>

          {/* Brand Name on Hover (as requested: "branding logo show only P" ... "if hover then show the name") */}
          <div className="absolute left-full ml-4 px-4 py-2 bg-prava-dark-surface text-white text-sm font-bold rounded-[12px] opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap z-50 shadow-xl border border-white/10">
            Prava Social
          </div>
        </div>
      </div>

      {/* Main Nav */}
      <nav className="flex flex-col gap-2">
        {mainNavItems.map((item) => (
          <NavLink key={item.path} item={item} collapsed={collapsed} />
        ))}
      </nav>

      {/* Divider */}
      <div className="my-6 h-px bg-prava-light-border dark:bg-prava-dark-border mx-4 opacity-50" />

      {/* Secondary Nav */}
      <nav className="flex flex-col gap-2">
        {secondaryNavItems.map((item) => (
          <NavLink key={item.path} item={item} collapsed={collapsed} />
        ))}
      </nav>

      {/* Spacer */}
      <div className="flex-1" />

      {/* Settings Nav */}
      <nav className="flex flex-col gap-2 mt-4">
        {settingsNavItems.map((item) => (
          <NavLink key={item.path} item={item} collapsed={collapsed} />
        ))}
      </nav>

      {/* Footer Actions */}
      <div className={`mt-6 pt-6 border-t border-prava-light-border dark:border-prava-dark-border flex ${collapsed ? 'flex-col items-center gap-3' : 'items-center justify-between px-2'}`}>
        <button
          onClick={toggleTheme}
          className="p-3 rounded-[16px] text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary hover:bg-white dark:hover:bg-white/[0.08] transition-colors relative group"
        >
          {isDark ? <Sun className="w-6 h-6" /> : <Moon className="w-6 h-6" />}
          {/* Tooltip */}
          <span className="absolute left-full ml-3 px-3 py-1.5 bg-prava-dark-surface text-white text-xs font-semibold rounded-[8px] opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap z-50">
            {isDark ? 'Light' : 'Dark'}
          </span>
        </button>

        <button
          onClick={handleLogout}
          className="p-3 rounded-[16px] text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary hover:bg-prava-error/10 hover:text-prava-error transition-colors relative group"
        >
          <LogOut className="w-6 h-6" />
          <span className="absolute left-full ml-3 px-3 py-1.5 bg-prava-dark-surface text-white text-xs font-semibold rounded-[8px] opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap z-50">
            Logout
          </span>
        </button>
      </div>
    </div>
  );

  return (
    <>
      {/* Desktop/Tablet Sidebar - ALWAYS Collapsed/Compact (Icon Only) */}
      <aside className="hidden tablet:flex laptop:flex desktop:flex fixed left-0 top-0 h-screen w-[80px] p-4 border-r border-prava-light-border dark:border-prava-dark-border bg-prava-light-bg/80 dark:bg-prava-dark-bg/80 backdrop-blur-2xl z-40">
        <SidebarContent collapsed={true} />
      </aside>

      {/* Mobile Bottom Nav */}
      <nav className="fixed bottom-0 left-0 right-0 tablet:hidden laptop:hidden desktop:hidden z-50 px-4 pb-safe">
        <div className="flex items-center justify-around py-2 px-2 rounded-t-[24px] bg-white/90 dark:bg-[#1D1D1D]/90 backdrop-blur-xl border-t border-x border-prava-light-border dark:border-prava-dark-border shadow-[0_-4px_30px_rgba(0,0,0,0.06)]">
          {mainNavItems.map((item) => {
            const location = useLocation();
            const isActive = location.pathname === item.path ||
              (item.path !== '/' && location.pathname.startsWith(item.path));

            return (
              <Link
                key={item.path}
                to={item.path}
                className={`flex flex-col items-center gap-1 p-2 rounded-[14px] transition-colors
                  ${isActive
                    ? 'text-prava-accent'
                    : 'text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary'
                  }
                `}
              >
                {item.icon}
                <span className="text-[10px] font-bold">{item.label}</span>
              </Link>
            );
          })}

          {/* More Button */}
          <button
            onClick={() => setMobileOpen(true)}
            className="flex flex-col items-center gap-1 p-2 rounded-[14px] text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary"
          >
            <Menu className="w-6 h-6" />
            <span className="text-[10px] font-bold">More</span>
          </button>
        </div>
      </nav>

      {/* Mobile Menu Overlay */}
      <AnimatePresence>
        {mobileOpen && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setMobileOpen(false)}
              className="fixed inset-0 bg-black/60 z-50 tablet:hidden laptop:hidden desktop:hidden backdrop-blur-sm"
            />
            <motion.div
              initial={{ x: '100%' }}
              animate={{ x: 0 }}
              exit={{ x: '100%' }}
              transition={{ type: 'spring', damping: 25, stiffness: 300 }}
              className="fixed right-0 top-0 bottom-0 w-[300px] bg-prava-light-bg dark:bg-prava-dark-bg z-50 p-6 tablet:hidden laptop:hidden desktop:hidden border-l border-prava-light-border dark:border-prava-dark-border"
            >
              <div className="flex justify-between items-center mb-8">
                <span className="font-bold text-2xl text-prava-light-text-primary dark:text-prava-dark-text-primary">Menu</span>
                <button
                  onClick={() => setMobileOpen(false)}
                  className="p-2 rounded-[14px] bg-prava-light-surface dark:bg-prava-dark-surface hover:bg-prava-light-border dark:hover:bg-prava-dark-border"
                >
                  <X className="w-6 h-6" />
                </button>
              </div>

              <div className="flex flex-col h-full pb-8">
                <nav className="flex flex-col gap-2">
                  {[...secondaryNavItems, ...settingsNavItems].map((item) => (
                    <Link
                      key={item.path}
                      to={item.path}
                      onClick={() => setMobileOpen(false)}
                      className="flex items-center gap-4 px-4 py-4 rounded-[18px] text-prava-light-text-secondary dark:text-prava-dark-text-secondary hover:bg-prava-light-surface dark:hover:bg-prava-dark-surface transition-colors"
                    >
                      {item.icon}
                      <span className="font-bold text-lg">{item.label}</span>
                    </Link>
                  ))}
                </nav>

                <div className="mt-auto pt-8 border-t border-prava-light-border dark:border-prava-dark-border">
                  <div className="flex items-center justify-between gap-4">
                    <button
                      onClick={toggleTheme}
                      className="flex-1 flex items-center justify-center gap-2 px-4 py-4 rounded-[18px] bg-prava-light-surface dark:bg-prava-dark-surface font-bold text-prava-light-text-primary dark:text-prava-dark-text-primary"
                    >
                      {isDark ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
                      {isDark ? 'Light' : 'Dark'}
                    </button>

                    <button
                      onClick={handleLogout}
                      className="px-6 py-4 rounded-[18px] bg-[#E5533D]/10 text-[#E5533D]"
                    >
                      <LogOut className="w-6 h-6" />
                    </button>
                  </div>
                </div>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </>
  );
}

