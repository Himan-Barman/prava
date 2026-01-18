import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import type { ReactNode } from 'react';
import { useAuth } from '../context/auth-context';

// Auth Pages
import {
  LoginPage,
  SignupPage,
  EmailOtpPage,
  SetPasswordPage,
  ForgotPasswordPage,
} from '../experiences/auth';

// Main Pages
import {
  FeedPage,
  ChatsPage,
  ArchivedChatsPage,
  StarredMessagesPage,
  NewGroupPage,
  FriendsPage,
  SearchPage,
  NotificationsPage,
  ProfilePage,
  BroadcastPage,
  SettingsPage,
  AccountInfoPage,
  HandleLinksPage,
  SecurityCenterPage,
  DevicesPage,
  BlockedAccountsPage,
  MutedWordsPage,
  LanguagePage,
  DataExportPage,
  LegalPage,
  SupportPage,
} from '../experiences';

// Protected Route wrapper
function ProtectedRoute({ children }: { children: ReactNode }) {
  const { isAuthenticated, isLoading } = useAuth();
  const location = useLocation();

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-prava-accent border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  return <>{children}</>;
}

// Public Route wrapper (redirect if already logged in)
function PublicRoute({ children }: { children: ReactNode }) {
  const { isAuthenticated, isLoading } = useAuth();

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-prava-accent border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (isAuthenticated) {
    return <Navigate to="/feed" replace />;
  }

  return <>{children}</>;
}

// Root redirect with auth awareness
function AuthRedirect() {
  const { isAuthenticated, isLoading } = useAuth();
  const location = useLocation();

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-prava-accent border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <Navigate
      to={isAuthenticated ? '/feed' : '/login'}
      state={{ from: location }}
      replace
    />
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

      {/* Protected Routes */}
      <Route path="/" element={<AuthRedirect />} />
      <Route path="/feed" element={<ProtectedRoute><FeedPage /></ProtectedRoute>} />
      <Route path="/chats" element={<ProtectedRoute><ChatsPage /></ProtectedRoute>} />
      <Route path="/chats/archived" element={<ProtectedRoute><ArchivedChatsPage /></ProtectedRoute>} />
      <Route path="/chats/starred" element={<ProtectedRoute><StarredMessagesPage /></ProtectedRoute>} />
      <Route path="/chats/new" element={<ProtectedRoute><NewGroupPage /></ProtectedRoute>} />
      <Route path="/friends" element={<ProtectedRoute><FriendsPage /></ProtectedRoute>} />
      <Route path="/search" element={<ProtectedRoute><SearchPage /></ProtectedRoute>} />
      <Route path="/notifications" element={<ProtectedRoute><NotificationsPage /></ProtectedRoute>} />
      <Route path="/profile" element={<ProtectedRoute><ProfilePage /></ProtectedRoute>} />
      <Route path="/broadcast" element={<ProtectedRoute><BroadcastPage /></ProtectedRoute>} />
      <Route path="/settings" element={<ProtectedRoute><SettingsPage /></ProtectedRoute>} />
      <Route path="/settings/account" element={<ProtectedRoute><AccountInfoPage /></ProtectedRoute>} />
      <Route path="/settings/handle" element={<ProtectedRoute><HandleLinksPage /></ProtectedRoute>} />
      <Route path="/settings/security" element={<ProtectedRoute><SecurityCenterPage /></ProtectedRoute>} />
      <Route path="/settings/devices" element={<ProtectedRoute><DevicesPage /></ProtectedRoute>} />
      <Route path="/settings/blocked" element={<ProtectedRoute><BlockedAccountsPage /></ProtectedRoute>} />
      <Route path="/settings/muted" element={<ProtectedRoute><MutedWordsPage /></ProtectedRoute>} />
      <Route path="/settings/language" element={<ProtectedRoute><LanguagePage /></ProtectedRoute>} />
      <Route path="/settings/export" element={<ProtectedRoute><DataExportPage /></ProtectedRoute>} />
      <Route path="/settings/legal" element={<ProtectedRoute><LegalPage /></ProtectedRoute>} />
      <Route path="/support" element={<ProtectedRoute><SupportPage /></ProtectedRoute>} />

      {/* Catch all */}
      <Route path="*" element={<AuthRedirect />} />
    </Routes>
  );
};

export default AppRoutes;
