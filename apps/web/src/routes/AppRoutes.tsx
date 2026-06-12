import { lazy, Suspense } from 'react';
import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import type { ReactNode } from 'react';
import { useAuth } from '../context/auth-context';
import { ErrorBoundary } from '../components/ErrorBoundary';
import { PageLoader } from '../components/PageLoader';

// Landing Page — loaded eagerly (entry point)
import { LandingPage } from '../experiences/landing';

// Auth Pages — loaded eagerly (critical path)
import {
  LoginPage,
  SignupPage,
  EmailOtpPage,
  SetPasswordPage,
  ForgotPasswordPage,
  ResetPasswordPage,
  SetDetailsPage,
} from '../experiences/auth';

// ═══ Lazy-loaded app pages ═══
const FeedPage = lazy(() => import('../experiences/feed/FeedPage'));
const PostDetailPage = lazy(() => import('../experiences/feed/PostDetailPage'));
const ChatsPage = lazy(() => import('../experiences/chats/ChatsPage'));
const ArchivedChatsPage = lazy(() => import('../experiences/chats/ArchivedChatsPage'));
const StarredMessagesPage = lazy(() => import('../experiences/chats/StarredMessagesPage'));
const NewGroupPage = lazy(() => import('../experiences/chats/NewGroupPage'));
const FriendsPage = lazy(() => import('../experiences/friends/FriendsPage'));
const SearchPage = lazy(() => import('../experiences/search/SearchPage'));
const NotificationsPage = lazy(() => import('../experiences/notifications/NotificationsPage'));
const ProfilePage = lazy(() => import('../experiences/profile/ProfilePage'));
const BroadcastPage = lazy(() => import('../experiences/broadcast/BroadcastPage'));
const SettingsPage = lazy(() => import('../experiences/settings/SettingsPage'));
const AccountInfoPage = lazy(() => import('../experiences/settings/AccountInfoPage'));
const HandleLinksPage = lazy(() => import('../experiences/settings/HandleLinksPage'));
const SecurityCenterPage = lazy(() => import('../experiences/settings/SecurityCenterPage'));
const DevicesPage = lazy(() => import('../experiences/settings/DevicesPage'));
const BlockedAccountsPage = lazy(() => import('../experiences/settings/BlockedAccountsPage'));
const MutedWordsPage = lazy(() => import('../experiences/settings/MutedWordsPage'));
const LanguagePage = lazy(() => import('../experiences/settings/LanguagePage'));
const DataExportPage = lazy(() => import('../experiences/settings/DataExportPage'));
const LegalPage = lazy(() => import('../experiences/settings/LegalPage'));
const SupportPage = lazy(() => import('../experiences/support/SupportPage'));

// ═══ Route Guards ═══
function ProtectedRoute({ children }: { children: ReactNode }) {
  const { isAuthenticated, isLoading } = useAuth();
  const location = useLocation();

  if (isLoading) return <PageLoader />;
  if (!isAuthenticated) return <Navigate to="/login" state={{ from: location }} replace />;
  return <>{children}</>;
}

function PublicRoute({ children }: { children: ReactNode }) {
  const { isAuthenticated, isLoading } = useAuth();

  if (isLoading) return <PageLoader />;
  if (isAuthenticated) return <Navigate to="/feed" replace />;
  return <>{children}</>;
}

function AuthRedirect() {
  const { isAuthenticated, isLoading } = useAuth();
  const location = useLocation();

  if (isLoading) return <PageLoader />;
  return <Navigate to={isAuthenticated ? '/feed' : '/'} state={{ from: location }} replace />;
}

// Wrap lazy component with Suspense + ErrorBoundary
function LazyRoute({ children }: { children: ReactNode }) {
  return (
    <ErrorBoundary>
      <Suspense fallback={<PageLoader />}>
        {children}
      </Suspense>
    </ErrorBoundary>
  );
}

const AppRoutes = () => {
  return (
    <Routes>
      {/* Auth Routes (Public) */}
      <Route path="/login" element={<PublicRoute><LoginPage /></PublicRoute>} />
      <Route path="/signup" element={<PublicRoute><SignupPage /></PublicRoute>} />
      <Route path="/verify-email" element={<EmailOtpPage />} />
      <Route path="/set-password" element={<SetPasswordPage />} />
      <Route path="/forgot-password" element={<PublicRoute><ForgotPasswordPage /></PublicRoute>} />
      <Route path="/reset-password" element={<PublicRoute><ResetPasswordPage /></PublicRoute>} />
      <Route path="/set-details" element={<ProtectedRoute><SetDetailsPage /></ProtectedRoute>} />

      {/* Landing Page (Public) */}
      <Route path="/" element={<LandingPage />} />

      {/* Protected Routes — all lazy-loaded */}
      <Route path="/feed" element={<ProtectedRoute><LazyRoute><FeedPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/post/:postId" element={<ProtectedRoute><LazyRoute><PostDetailPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/chats" element={<ProtectedRoute><LazyRoute><ChatsPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/chats/archived" element={<ProtectedRoute><LazyRoute><ArchivedChatsPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/chats/starred" element={<ProtectedRoute><LazyRoute><StarredMessagesPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/chats/new" element={<ProtectedRoute><LazyRoute><NewGroupPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/friends" element={<ProtectedRoute><LazyRoute><FriendsPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/search" element={<ProtectedRoute><LazyRoute><SearchPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/notifications" element={<ProtectedRoute><LazyRoute><NotificationsPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/profile" element={<ProtectedRoute><LazyRoute><ProfilePage /></LazyRoute></ProtectedRoute>} />
      <Route path="/profile/:id" element={<ProtectedRoute><LazyRoute><ProfilePage /></LazyRoute></ProtectedRoute>} />
      <Route path="/broadcast" element={<ProtectedRoute><LazyRoute><BroadcastPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/settings" element={<ProtectedRoute><LazyRoute><SettingsPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/settings/account" element={<ProtectedRoute><LazyRoute><AccountInfoPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/settings/handle" element={<ProtectedRoute><LazyRoute><HandleLinksPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/settings/security" element={<ProtectedRoute><LazyRoute><SecurityCenterPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/settings/devices" element={<ProtectedRoute><LazyRoute><DevicesPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/settings/blocked" element={<ProtectedRoute><LazyRoute><BlockedAccountsPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/settings/muted" element={<ProtectedRoute><LazyRoute><MutedWordsPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/settings/language" element={<ProtectedRoute><LazyRoute><LanguagePage /></LazyRoute></ProtectedRoute>} />
      <Route path="/settings/export" element={<ProtectedRoute><LazyRoute><DataExportPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/settings/legal" element={<ProtectedRoute><LazyRoute><LegalPage /></LazyRoute></ProtectedRoute>} />
      <Route path="/support" element={<ProtectedRoute><LazyRoute><SupportPage /></LazyRoute></ProtectedRoute>} />

      {/* Catch all */}
      <Route path="*" element={<AuthRedirect />} />
    </Routes>
  );
};

export default AppRoutes;
