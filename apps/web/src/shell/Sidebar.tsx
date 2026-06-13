import { useState, type ReactNode } from 'react';
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
  icon: ReactNode;
}

const mainNavItems: NavItem[] = [
  { path: '/feed', label: 'Feed', icon: <LayoutGrid className="w-6 h-6" strokeWidth={2.4} /> },
  { path: '/chats', label: 'Chats', icon: <MessageCircle className="w-6 h-6" strokeWidth={2.4} /> },
  { path: '/friends', label: 'Friends', icon: <Users className="w-6 h-6" strokeWidth={2.4} /> },
  { path: '/profile', label: 'Profile', icon: <User className="w-6 h-6" strokeWidth={2.4} /> },
];

const secondaryNavItems: NavItem[] = [
  { path: '/notifications', label: 'Notifications', icon: <Bell className="w-6 h-6" strokeWidth={2.4} /> },
  { path: '/search', label: 'Search', icon: <Search className="w-6 h-6" strokeWidth={2.4} /> },
];

const settingsNavItems: NavItem[] = [
  { path: '/settings', label: 'Settings', icon: <Settings className="w-6 h-6" strokeWidth={2.4} /> },
  { path: '/support', label: 'Support', icon: <HelpCircle className="w-6 h-6" strokeWidth={2.4} /> },
];

function NavLink({ item, collapsed }: { item: NavItem; collapsed: boolean }) {
  const location = useLocation();
  const isActive = location.pathname === item.path ||
    (item.path !== '/' && location.pathname.startsWith(item.path));

  return (
    <Link
      to={item.path}
      className="sidebar-navlink"
      data-active={isActive || undefined}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: collapsed ? 0 : 'var(--p-space-4)',
        padding: collapsed ? 'var(--p-space-3)' : 'var(--p-space-3) var(--p-space-4)',
        borderRadius: 'var(--p-radius-lg)',
        fontWeight: 500,
        fontSize: 'var(--p-text-body)',
        transition: 'all var(--p-duration-fast) var(--p-ease-default)',
        textDecoration: 'none',
        justifyContent: collapsed ? 'center' : 'flex-start',
        color: isActive ? 'var(--p-brand)' : 'var(--p-text-secondary)',
        background: isActive ? 'var(--p-bg-selected)' : 'transparent',
        position: 'relative',
      }}
      aria-current={isActive ? 'page' : undefined}
    >
      <span style={{ position: 'relative', zIndex: 10, display: 'flex' }}>{item.icon}</span>

      {!collapsed && (
        <span style={{ fontWeight: isActive ? 600 : 500, letterSpacing: '0.01em' }}>{item.label}</span>
      )}

      {collapsed && (
        <div
          className="sidebar-tooltip"
          style={{
            position: 'absolute',
            left: '100%',
            marginLeft: 12,
            padding: '6px 12px',
            background: 'var(--p-bg-surface-elevated)',
            color: 'var(--p-text-primary)',
            fontSize: 'var(--p-text-caption)',
            fontWeight: 600,
            borderRadius: 'var(--p-radius-sm)',
            opacity: 0,
            pointerEvents: 'none',
            whiteSpace: 'nowrap',
            zIndex: 50,
            boxShadow: 'var(--p-shadow-lg)',
            border: '1px solid var(--p-border)',
            transition: 'opacity var(--p-duration-fast) var(--p-ease-default)',
          }}
        >
          {item.label}
        </div>
      )}
    </Link>
  );
}

interface SidebarProps {
  mobileChromeVisible?: boolean;
  showMobileBottomNav?: boolean;
}

export function Sidebar({ mobileChromeVisible = true, showMobileBottomNav = true }: SidebarProps) {
  const { isDark, toggleTheme } = useTheme();
  const { logout } = useAuth();
  const location = useLocation();
  const [mobileOpen, setMobileOpen] = useState(false);

  const handleLogout = async () => {
    await logout();
    window.location.href = '/login';
  };

  // Desktop Sidebar
  const SidebarContent = ({ collapsed = false }: { collapsed?: boolean }) => (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      {/* Brand */}
      <div style={{
        display: 'flex',
        alignItems: collapsed ? 'center' : 'flex-start',
        justifyContent: collapsed ? 'center' : 'flex-start',
        paddingLeft: collapsed ? 0 : 8,
        marginBottom: 'var(--p-space-8)',
        marginTop: 'var(--p-space-2)',
      }}>
        <div
          className="sidebar-brand"
          style={{
            width: 48,
            height: 48,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            transition: 'transform var(--p-duration-normal) var(--p-ease-default)',
            position: 'relative',
          }}
        >
          <span style={{
            color: 'var(--p-brand)',
            fontWeight: 700,
            fontSize: 28,
            fontFamily: 'var(--p-font-sans)',
          }}>P.</span>

          <div
            className="sidebar-tooltip"
            style={{
              position: 'absolute',
              left: '100%',
              marginLeft: 16,
              padding: '8px 16px',
              background: 'var(--p-bg-surface-elevated)',
              color: 'var(--p-text-primary)',
              fontSize: 'var(--p-text-body-sm)',
              fontWeight: 700,
              borderRadius: 'var(--p-radius-md)',
              opacity: 0,
              pointerEvents: 'none',
              whiteSpace: 'nowrap',
              zIndex: 50,
              boxShadow: 'var(--p-shadow-lg)',
              border: '1px solid var(--p-border)',
              transition: 'opacity var(--p-duration-fast) var(--p-ease-default)',
            }}
          >
            Prava
          </div>
        </div>
      </div>

      {/* Main Nav */}
      <nav style={{ display: 'flex', flexDirection: 'column', gap: 'var(--p-space-1)' }}>
        {mainNavItems.map((item) => (
          <NavLink key={item.path} item={item} collapsed={collapsed} />
        ))}
      </nav>

      {/* Divider */}
      <div style={{
        margin: 'var(--p-space-5) var(--p-space-4)',
        height: 1,
        background: 'var(--p-divider)',
      }} />

      {/* Secondary Nav */}
      <nav style={{ display: 'flex', flexDirection: 'column', gap: 'var(--p-space-1)' }}>
        {secondaryNavItems.map((item) => (
          <NavLink key={item.path} item={item} collapsed={collapsed} />
        ))}
      </nav>

      {/* Spacer */}
      <div style={{ flex: 1 }} />

      {/* Settings Nav */}
      <nav style={{ display: 'flex', flexDirection: 'column', gap: 'var(--p-space-1)', marginTop: 'var(--p-space-4)' }}>
        {settingsNavItems.map((item) => (
          <NavLink key={item.path} item={item} collapsed={collapsed} />
        ))}
      </nav>

      {/* Footer Actions */}
      <div style={{
        marginTop: 'var(--p-space-5)',
        paddingTop: 'var(--p-space-5)',
        borderTop: '1px solid var(--p-divider)',
        display: 'flex',
        flexDirection: collapsed ? 'column' : 'row',
        alignItems: 'center',
        justifyContent: collapsed ? 'center' : 'space-between',
        gap: collapsed ? 'var(--p-space-3)' : 0,
        paddingLeft: collapsed ? 0 : 'var(--p-space-2)',
        paddingRight: collapsed ? 0 : 'var(--p-space-2)',
      }}>
        <button
          onClick={toggleTheme}
          className="sidebar-action-btn"
          style={{
            padding: 'var(--p-space-3)',
            borderRadius: 'var(--p-radius-lg)',
            color: 'var(--p-text-muted)',
            background: 'transparent',
            border: 'none',
            cursor: 'pointer',
            transition: 'all var(--p-duration-fast) var(--p-ease-default)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            position: 'relative',
          }}
          aria-label={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
        >
          {isDark ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
          <span
            className="sidebar-tooltip"
            style={{
              position: 'absolute',
              left: '100%',
              marginLeft: 12,
              padding: '6px 12px',
              background: 'var(--p-bg-surface-elevated)',
              color: 'var(--p-text-primary)',
              fontSize: 'var(--p-text-caption)',
              fontWeight: 600,
              borderRadius: 'var(--p-radius-sm)',
              opacity: 0,
              pointerEvents: 'none',
              whiteSpace: 'nowrap',
              zIndex: 50,
              transition: 'opacity var(--p-duration-fast)',
            }}
          >
            {isDark ? 'Light mode' : 'Dark mode'}
          </span>
        </button>

        <button
          onClick={handleLogout}
          className="sidebar-action-btn"
          style={{
            padding: 'var(--p-space-3)',
            borderRadius: 'var(--p-radius-lg)',
            color: 'var(--p-text-muted)',
            background: 'transparent',
            border: 'none',
            cursor: 'pointer',
            transition: 'all var(--p-duration-fast) var(--p-ease-default)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            position: 'relative',
          }}
          aria-label="Log out"
        >
          <LogOut className="w-5 h-5" />
          <span
            className="sidebar-tooltip"
            style={{
              position: 'absolute',
              left: '100%',
              marginLeft: 12,
              padding: '6px 12px',
              background: 'var(--p-bg-surface-elevated)',
              color: 'var(--p-text-primary)',
              fontSize: 'var(--p-text-caption)',
              fontWeight: 600,
              borderRadius: 'var(--p-radius-sm)',
              opacity: 0,
              pointerEvents: 'none',
              whiteSpace: 'nowrap',
              zIndex: 50,
              transition: 'opacity var(--p-duration-fast)',
            }}
          >
            Log out
          </span>
        </button>
      </div>
    </div>
  );

  return (
    <>
      {/* Desktop/Tablet Sidebar - Collapsed/Compact (Icon Only) */}
      <aside
        style={{
          position: 'fixed',
          left: 0,
          top: 0,
          height: '100vh',
          width: 'var(--p-sidebar-collapsed)',
          padding: 'var(--p-space-3)',
          borderRight: '1px solid var(--p-border)',
          background: 'var(--p-bg-surface)',
          zIndex: 'var(--p-z-sidebar)',
          display: 'none',
        }}
        className="sidebar-desktop"
      >
        <SidebarContent collapsed={true} />
      </aside>

      {/* Mobile Bottom Nav */}
      {showMobileBottomNav && (
      <nav
        className={`app-mobile-bottom-nav ${mobileChromeVisible ? 'app-mobile-bottom-nav--visible' : 'app-mobile-bottom-nav--hidden'}`}
        style={{
          position: 'fixed',
          bottom: 0,
          left: 0,
          right: 0,
          zIndex: 50,
        }}
      >
        <div style={{
          margin: '0 14px 8px',
          display: 'flex',
          height: 58,
          alignItems: 'center',
          justifyContent: 'space-around',
          borderRadius: 22,
          padding: '6px',
          backdropFilter: 'blur(24px)',
          WebkitBackdropFilter: 'blur(24px)',
          background: 'var(--p-bg-surface)',
          border: '1px solid var(--p-border)',
          boxShadow: 'var(--p-shadow-lg)',
        }}>
          {mainNavItems.map((item) => {
            const isActive = location.pathname === item.path ||
              (item.path !== '/' && location.pathname.startsWith(item.path));

            return (
              <Link
                key={item.path}
                to={item.path}
                style={{
                  display: 'flex',
                  flex: 1,
                  flexDirection: 'column',
                  alignItems: 'center',
                  padding: '2px 4px',
                  borderRadius: 'var(--p-radius-lg)',
                  color: isActive ? 'var(--p-brand)' : 'var(--p-text-muted)',
                  textDecoration: 'none',
                  transition: 'color var(--p-duration-fast)',
                  WebkitTapHighlightColor: 'transparent',
                }}
              >
                <span style={{
                  display: 'grid',
                  height: 30,
                  width: 48,
                  placeItems: 'center',
                  borderRadius: 'var(--p-radius-pill)',
                  transition: 'background var(--p-duration-fast)',
                  background: isActive ? 'var(--p-bg-selected)' : 'transparent',
                }}>
                  {item.icon}
                </span>
                <span style={{
                  marginTop: 2,
                  fontSize: 11,
                  lineHeight: 1,
                  fontWeight: isActive ? 700 : 500,
                }}>{item.label}</span>
              </Link>
            );
          })}
        </div>
      </nav>
      )}

      {/* Mobile Menu Overlay */}
      <AnimatePresence>
        {mobileOpen && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setMobileOpen(false)}
              style={{
                position: 'fixed',
                inset: 0,
                background: 'var(--p-bg-overlay)',
                zIndex: 50,
                backdropFilter: 'blur(4px)',
              }}
              className="mobile-menu-overlay"
            />
            <motion.div
              initial={{ x: '100%' }}
              animate={{ x: 0 }}
              exit={{ x: '100%' }}
              transition={{ type: 'spring', damping: 25, stiffness: 300 }}
              style={{
                position: 'fixed',
                right: 0,
                top: 0,
                bottom: 0,
                width: 300,
                background: 'var(--p-bg-surface)',
                zIndex: 50,
                padding: 'var(--p-space-6)',
                borderLeft: '1px solid var(--p-border)',
              }}
              className="mobile-menu-drawer"
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--p-space-8)' }}>
                <span style={{ fontWeight: 700, fontSize: 22, color: 'var(--p-text-primary)' }}>Menu</span>
                <button
                  onClick={() => setMobileOpen(false)}
                  style={{
                    padding: 'var(--p-space-2)',
                    borderRadius: 'var(--p-radius-lg)',
                    background: 'var(--p-bg-subtle)',
                    border: 'none',
                    cursor: 'pointer',
                    color: 'var(--p-text-primary)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                  aria-label="Close menu"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', height: '100%', paddingBottom: 'var(--p-space-8)' }}>
                <nav style={{ display: 'flex', flexDirection: 'column', gap: 'var(--p-space-1)' }}>
                  {[...secondaryNavItems, ...settingsNavItems].map((item) => (
                    <Link
                      key={item.path}
                      to={item.path}
                      onClick={() => setMobileOpen(false)}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 'var(--p-space-4)',
                        padding: 'var(--p-space-4)',
                        borderRadius: 'var(--p-radius-xl)',
                        color: 'var(--p-text-secondary)',
                        textDecoration: 'none',
                        transition: 'background var(--p-duration-fast)',
                        fontSize: 'var(--p-text-section-title)',
                        fontWeight: 600,
                      }}
                    >
                      {item.icon}
                      <span>{item.label}</span>
                    </Link>
                  ))}
                </nav>

                <div style={{
                  marginTop: 'auto',
                  paddingTop: 'var(--p-space-8)',
                  borderTop: '1px solid var(--p-divider)',
                  display: 'flex',
                  gap: 'var(--p-space-4)',
                }}>
                  <button
                    onClick={toggleTheme}
                    style={{
                      flex: 1,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: 8,
                      padding: 'var(--p-space-4)',
                      borderRadius: 'var(--p-radius-xl)',
                      background: 'var(--p-bg-subtle)',
                      border: 'none',
                      cursor: 'pointer',
                      fontWeight: 700,
                      color: 'var(--p-text-primary)',
                      fontSize: 'var(--p-text-body)',
                    }}
                  >
                    {isDark ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
                    {isDark ? 'Light' : 'Dark'}
                  </button>

                  <button
                    onClick={handleLogout}
                    style={{
                      padding: '0 var(--p-space-6)',
                      height: 48,
                      borderRadius: 'var(--p-radius-xl)',
                      background: 'var(--p-danger-subtle)',
                      color: 'var(--p-danger)',
                      border: 'none',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                    aria-label="Log out"
                  >
                    <LogOut className="w-6 h-6" />
                  </button>
                </div>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </>
  );
}
