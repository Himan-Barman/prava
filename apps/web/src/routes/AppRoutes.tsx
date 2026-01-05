import { Navigate, Route, Routes } from 'react-router-dom';

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

const AppRoutes = () => {
  return (
    <Routes>
      <Route path="/" element={<Navigate to="/feed" replace />} />
      <Route path="/feed" element={<FeedPage />} />
      <Route path="/chats" element={<ChatsPage />} />
      <Route path="/chats/archived" element={<ArchivedChatsPage />} />
      <Route path="/chats/starred" element={<StarredMessagesPage />} />
      <Route path="/chats/new" element={<NewGroupPage />} />
      <Route path="/friends" element={<FriendsPage />} />
      <Route path="/search" element={<SearchPage />} />
      <Route path="/notifications" element={<NotificationsPage />} />
      <Route path="/profile" element={<ProfilePage />} />
      <Route path="/broadcast" element={<BroadcastPage />} />
      <Route path="/settings" element={<SettingsPage />} />
      <Route path="/settings/account" element={<AccountInfoPage />} />
      <Route path="/settings/handle" element={<HandleLinksPage />} />
      <Route path="/settings/security" element={<SecurityCenterPage />} />
      <Route path="/settings/devices" element={<DevicesPage />} />
      <Route path="/settings/blocked" element={<BlockedAccountsPage />} />
      <Route path="/settings/muted" element={<MutedWordsPage />} />
      <Route path="/settings/language" element={<LanguagePage />} />
      <Route path="/settings/export" element={<DataExportPage />} />
      <Route path="/settings/legal" element={<LegalPage />} />
      <Route path="/support" element={<SupportPage />} />
      <Route path="*" element={<Navigate to="/feed" replace />} />
    </Routes>
  );
};

export default AppRoutes;
