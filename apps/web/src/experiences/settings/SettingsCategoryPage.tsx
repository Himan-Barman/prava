import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import {
  AlertTriangle,
  Bell,
  Bot,
  CheckCircle2,
  Database,
  Eye,
  Flag,
  LockKeyhole,
  LogOut,
  MessageCircle,
  Palette,
  RotateCcw,
  Shield,
  Sparkles,
  Trash2,
  Users,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';

import {
  findSettingsMeta,
  labelValue,
  type SettingsPageKey,
} from './settings-config';
import {
  defaultSettings,
  settingsService,
  type SettingsCategoryKey,
  type SettingsState,
} from '../../services/settings-service';
import { smartToast } from '../../ui-system/components/SmartToast';
import { useAuth } from '../../context/auth-context';

export type SettingsCategoryRouteKey = SettingsCategoryKey | 'danger';

interface SettingsCategoryPageProps {
  category: SettingsCategoryRouteKey;
}

type Patch = Partial<SettingsState>;

const audienceOptions = ['everyone', 'followers', 'friends', 'closeFriends', 'nobody'];
const groupOptions = ['everyone', 'friends', 'nobody'];
const feedModeOptions = ['forYou', 'following', 'friends', 'latest', 'trending'];
const personalizationOptions = ['low', 'balanced', 'high'];
const safetyOptions = ['strict', 'balanced', 'open'];
const densityOptions = ['compact', 'comfortable', 'spacious'];
const fontOptions = ['small', 'default', 'large', 'extraLarge'];
const mediaOptions = ['auto', 'low', 'standard', 'high'];

function metaFor(category: SettingsCategoryRouteKey) {
  return findSettingsMeta(category as SettingsPageKey) ?? {
    key: category,
    title: 'Settings',
    subtitle: 'Manage this part of Prava.',
    path: '/settings',
    icon: Shield,
    keywords: '',
    accent: 'var(--p-brand)',
  };
}

function themeLabel(index: number) {
  if (index === 1) return 'Light';
  if (index === 2) return 'Dark';
  return 'System';
}

function themeIndexFromValue(value: string) {
  if (value === 'light') return 1;
  if (value === 'dark') return 2;
  return 0;
}

export default function SettingsCategoryPage({ category }: SettingsCategoryPageProps) {
  const navigate = useNavigate();
  const { logout } = useAuth();
  const [settings, setSettings] = useState<SettingsState>(defaultSettings);
  const [loading, setLoading] = useState(true);
  const [savingKey, setSavingKey] = useState<string | null>(null);
  const meta = metaFor(category);
  const Icon = meta.icon;

  useEffect(() => {
    let active = true;
    settingsService
      .fetchSettings()
      .then((next) => {
        if (active) setSettings(next);
      })
      .catch(() => smartToast.error('Unable to load settings'))
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
    };
  }, []);

  const update = async (patch: Patch, key: string) => {
    if (savingKey) return;
    const previous = settings;
    setSavingKey(key);
    setSettings((current) => ({ ...current, ...patch }));
    try {
      const saved = await settingsService.updateSettings(patch);
      setSettings(saved);
    } catch {
      setSettings(previous);
      smartToast.error('Unable to update setting');
    } finally {
      setSavingKey(null);
    }
  };

  const actions = {
    privacyCheckup: async () => {
      try {
        const result = await settingsService.runPrivacyCheckup();
        smartToast.info(`Privacy score ${result.score}. ${result.recommendations[0] ?? 'No action needed.'}`);
      } catch {
        smartToast.error('Privacy checkup failed');
      }
    },
    securityCheckup: async () => {
      try {
        const result = await settingsService.runSecurityCheckup();
        smartToast.info(`Security score ${result.score}. ${result.recommendations[0] ?? 'No action needed.'}`);
      } catch {
        smartToast.error('Security checkup failed');
      }
    },
    resetFeed: async () => {
      if (!window.confirm('Reset feed personalization history?')) return;
      try {
        await settingsService.resetFeedPersonalization();
        smartToast.success('Feed personalization reset');
      } catch {
        smartToast.error('Unable to reset feed');
      }
    },
    clearSearch: async () => {
      try {
        await settingsService.clearSearchHistory();
        smartToast.success('Search history cleared');
      } catch {
        smartToast.error('Unable to clear search history');
      }
    },
    clearCache: async () => {
      try {
        await settingsService.clearCacheMetadata();
        smartToast.success('Cache metadata cleared');
      } catch {
        smartToast.error('Unable to clear cache metadata');
      }
    },
    exportData: async () => {
      try {
        const request = await settingsService.requestDataExport();
        smartToast.success(`Export queued: ${request.status}`);
      } catch {
        smartToast.error('Unable to request export');
      }
    },
    logoutAll: async () => {
      if (!window.confirm('Log out every active session?')) return;
      try {
        await settingsService.logoutAllSessions();
        await logout();
        navigate('/login', { replace: true });
      } catch {
        smartToast.error('Unable to log out sessions');
      }
    },
    deactivate: async () => {
      const password = window.prompt('Enter your password to request deactivation');
      if (!password) return;
      try {
        await settingsService.deactivateAccount(password);
        smartToast.success('Deactivation request created');
      } catch {
        smartToast.error('Unable to request deactivation');
      }
    },
    deleteAccount: async () => {
      const confirmation = window.prompt('Type DELETE to request account deletion');
      if (confirmation !== 'DELETE') return;
      const password = window.prompt('Enter your password to confirm account deletion');
      if (!password) return;
      try {
        await settingsService.requestAccountDeletion(password, confirmation);
        smartToast.success('Deletion request created');
      } catch {
        smartToast.error('Unable to request deletion');
      }
    },
  };

  const sections = useMemo(
    () => buildSections(category, settings, update, actions, savingKey),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [category, settings, savingKey]
  );

  return (
    <div className="p-page settings-category-page">
      <motion.header
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.22 }}
        className="settings-category-header"
      >
        <span className="settings-category-header__icon" style={{ color: meta.accent }}>
          <Icon size={24} strokeWidth={2.9} />
        </span>
        <div>
          <h1 className="p-page-title">{meta.title}</h1>
          <p className="p-page-subtitle">{meta.subtitle}</p>
        </div>
      </motion.header>

      {loading ? (
        <div className="settings-loading">
          <div className="p-spinner" />
        </div>
      ) : (
        <div className="settings-section-stack">
          {sections.map((section) => (
            <SettingSection key={section.title} title={section.title} subtitle={section.subtitle}>
              {section.rows}
            </SettingSection>
          ))}
        </div>
      )}
    </div>
  );
}

interface BuiltSection {
  title: string;
  subtitle: string;
  rows: ReactNode[];
}

function buildSections(
  category: SettingsCategoryRouteKey,
  s: SettingsState,
  update: (patch: Patch, key: string) => Promise<void>,
  actions: Record<string, () => Promise<void>>,
  savingKey: string | null
): BuiltSection[] {
  switch (category) {
    case 'profile_visibility':
      return [
        {
          title: 'Profile visibility',
          subtitle: 'Control who can see your profile and social lists.',
          rows: [
            <ToggleRow key="privateAccount" icon={Eye} title="Private account" subtitle="Only approved people can follow and see follower-only content." value={s.privateAccount} disabled={savingKey === 'privateAccount'} onChange={(value) => update({ privateAccount: value }, 'privateAccount')} />,
            <ActionRow key="account" icon={Shield} title="Profile account details" subtitle="Edit display name, email, and phone information." to="/settings/account" />,
            <ActionRow key="username" icon={CheckCircle2} title="Username" subtitle="Change your username with password verification." to="/settings/handle" />,
          ],
        },
      ];
    case 'privacy':
      return [
        {
          title: 'Social privacy',
          subtitle: 'Choose what other people can see and use.',
          rows: [
            <ToggleRow key="privateAccount" icon={Shield} title="Private account" subtitle="Require approval before people can follow you." value={s.privateAccount} disabled={savingKey === 'privateAccount'} onChange={(value) => update({ privateAccount: value }, 'privateAccount')} />,
            <ToggleRow key="activityStatus" icon={Sparkles} title="Activity status" subtitle="Show online and recently active status." value={s.activityStatus} disabled={savingKey === 'activityStatus'} onChange={(value) => update({ activityStatus: value }, 'activityStatus')} />,
            <ToggleRow key="readReceipts" icon={MessageCircle} title="Read receipts" subtitle="Let people know when you have seen messages." value={s.readReceipts} disabled={savingKey === 'readReceipts'} onChange={(value) => update({ readReceipts: value }, 'readReceipts')} />,
            <ToggleRow key="locationSharing" icon={Eye} title="Location sharing" subtitle="Allow location context where supported." value={s.locationSharing} disabled={savingKey === 'locationSharing'} onChange={(value) => update({ locationSharing: value }, 'locationSharing')} />,
          ],
        },
        {
          title: 'Content safety',
          subtitle: 'Filter posts, mentions, and message requests.',
          rows: [
            <ToggleRow key="sensitiveContent" icon={AlertTriangle} title="Sensitive content filter" subtitle="Reduce sensitive content in feeds and discovery." value={s.sensitiveContent} disabled={savingKey === 'sensitiveContent'} onChange={(value) => update({ sensitiveContent: value }, 'sensitiveContent')} />,
            <OptionRow key="whoCanMessage" icon={MessageCircle} title="Who can message you" value={s.whoCanMessage} options={audienceOptions} onChange={(value) => update({ whoCanMessage: value }, 'whoCanMessage')} />,
            <OptionRow key="contentSafetyLevel" icon={Shield} title="Content safety level" value={s.contentSafetyLevel} options={safetyOptions} onChange={(value) => update({ contentSafetyLevel: value }, 'contentSafetyLevel')} />,
            <ButtonRow key="privacyCheckup" icon={Shield} title="Privacy checkup" subtitle="Review recommended privacy changes." label="Run" onClick={actions.privacyCheckup} />,
          ],
        },
      ];
    case 'security':
      return [
        {
          title: 'Account protection',
          subtitle: 'Keep login and account recovery controls strict.',
          rows: [
            <ToggleRow key="twoFactor" icon={LockKeyhole} title="Two-factor authentication" subtitle="Require a second verification step at login." value={s.twoFactor} disabled={savingKey === 'twoFactor'} onChange={(value) => update({ twoFactor: value }, 'twoFactor')} />,
            <ToggleRow key="loginAlerts" icon={Bell} title="Login alerts" subtitle="Notify you about new and suspicious sign-ins." value={s.loginAlerts} disabled={savingKey === 'loginAlerts'} onChange={(value) => update({ loginAlerts: value }, 'loginAlerts')} />,
            <ToggleRow key="appLock" icon={LockKeyhole} title="App lock" subtitle="Require device unlock before opening Prava." value={s.appLock} disabled={savingKey === 'appLock'} onChange={(value) => update({ appLock: value }, 'appLock')} />,
            <ToggleRow key="biometrics" icon={Shield} title="Biometrics" subtitle="Use fingerprint or face unlock where available." value={s.biometrics} disabled={savingKey === 'biometrics'} onChange={(value) => update({ biometrics: value }, 'biometrics')} />,
          ],
        },
        {
          title: 'Sessions',
          subtitle: 'Review devices and session recovery.',
          rows: [
            <ActionRow key="devices" icon={Database} title="Signed-in devices" subtitle="Manage active devices and sessions." to="/settings/devices" />,
            <ButtonRow key="securityCheckup" icon={Shield} title="Security checkup" subtitle="Review account protection score." label="Run" onClick={actions.securityCheckup} />,
            <ButtonRow key="logoutAll" icon={LogOut} title="Log out all sessions" subtitle="Sign out all active sessions." label="Log out" danger onClick={actions.logoutAll} />,
          ],
        },
      ];
    case 'notifications':
      return [
        {
          title: 'Delivery',
          subtitle: 'Choose where notifications can reach you.',
          rows: [
            <ToggleRow key="pushNotifications" icon={Bell} title="Push notifications" subtitle="Device alerts for important activity." value={s.pushNotifications} disabled={savingKey === 'pushNotifications'} onChange={(value) => update({ pushNotifications: value }, 'pushNotifications')} />,
            <ToggleRow key="emailNotifications" icon={Bell} title="Email notifications" subtitle="Digest and security emails." value={s.emailNotifications} disabled={savingKey === 'emailNotifications'} onChange={(value) => update({ emailNotifications: value }, 'emailNotifications')} />,
            <ToggleRow key="inAppSounds" icon={Bell} title="In-app sounds" subtitle="Play notification tones in Prava." value={s.inAppSounds} disabled={savingKey === 'inAppSounds'} onChange={(value) => update({ inAppSounds: value }, 'inAppSounds')} />,
            <ToggleRow key="inAppHaptics" icon={Bell} title="Haptics" subtitle="Use vibration feedback on supported devices." value={s.inAppHaptics} disabled={savingKey === 'inAppHaptics'} onChange={(value) => update({ inAppHaptics: value }, 'inAppHaptics')} />,
          ],
        },
        {
          title: 'Notification types',
          subtitle: 'Filter social, message, and content notifications.',
          rows: [
            <ToggleRow key="notifyPosts" icon={Sparkles} title="Posts and recommendations" subtitle="Updates for posts, trending content, and suggestions." value={s.notifyPosts} disabled={savingKey === 'notifyPosts'} onChange={(value) => update({ notifyPosts: value }, 'notifyPosts')} />,
            <ToggleRow key="notifyChats" icon={MessageCircle} title="Chats" subtitle="Direct and group message notifications." value={s.notifyChats} disabled={savingKey === 'notifyChats'} onChange={(value) => update({ notifyChats: value }, 'notifyChats')} />,
            <ToggleRow key="notifyMentions" icon={Bell} title="Mentions" subtitle="Posts and replies that mention you." value={s.notifyMentions} disabled={savingKey === 'notifyMentions'} onChange={(value) => update({ notifyMentions: value }, 'notifyMentions')} />,
            <ToggleRow key="notifyFollows" icon={Users} title="Follows and friends" subtitle="Follow, request, and friend activity." value={s.notifyFollows} disabled={savingKey === 'notifyFollows'} onChange={(value) => update({ notifyFollows: value }, 'notifyFollows')} />,
            <ToggleRow key="messagePreview" icon={Eye} title="Notification preview" subtitle="Show message text in notifications." value={s.messagePreview} disabled={savingKey === 'messagePreview'} onChange={(value) => update({ messagePreview: value }, 'messagePreview')} />,
            <ToggleRow key="quietHours" icon={Bell} title="Quiet hours" subtitle="Pause non-critical alerts during quiet hours." value={s.quietHours} disabled={savingKey === 'quietHours'} onChange={(value) => update({ quietHours: value }, 'quietHours')} />,
          ],
        },
      ];
    case 'chats':
      return [
        {
          title: 'Message privacy',
          subtitle: 'Control who can reach you and how messages behave.',
          rows: [
            <OptionRow key="whoCanMessage" icon={MessageCircle} title="Who can message you" value={s.whoCanMessage} options={audienceOptions} onChange={(value) => update({ whoCanMessage: value }, 'whoCanMessage')} />,
            <ToggleRow key="readReceipts" icon={CheckCircle2} title="Read receipts" subtitle="Show when you have read a message." value={s.readReceipts} disabled={savingKey === 'readReceipts'} onChange={(value) => update({ readReceipts: value }, 'readReceipts')} />,
            <ToggleRow key="messagePreview" icon={Eye} title="Message previews" subtitle="Show message preview text in alerts." value={s.messagePreview} disabled={savingKey === 'messagePreview'} onChange={(value) => update({ messagePreview: value }, 'messagePreview')} />,
          ],
        },
        {
          title: 'Groups and media',
          subtitle: 'Tune group invite and media behavior.',
          rows: [
            <OptionRow key="whoCanAddToGroups" icon={Users} title="Who can add you to groups" value={s.whoCanAddToGroups} options={groupOptions} onChange={(value) => update({ whoCanAddToGroups: value }, 'whoCanAddToGroups')} />,
            <ToggleRow key="autoDownload" icon={Database} title="Auto-download media" subtitle="Download images and videos automatically." value={s.autoDownload} disabled={savingKey === 'autoDownload'} onChange={(value) => update({ autoDownload: value }, 'autoDownload')} />,
            <ToggleRow key="dataSaver" icon={Database} title="Data saver media" subtitle="Reduce media usage in chats." value={s.dataSaver} disabled={savingKey === 'dataSaver'} onChange={(value) => update({ dataSaver: value }, 'dataSaver')} />,
          ],
        },
      ];
    case 'feed':
      return [
        {
          title: 'Feed ranking',
          subtitle: 'Shape For You, following, and discovery behavior.',
          rows: [
            <OptionRow key="defaultFeedMode" icon={Sparkles} title="Default feed" value={s.defaultFeedMode} options={feedModeOptions} onChange={(value) => update({ defaultFeedMode: value }, 'defaultFeedMode')} />,
            <OptionRow key="personalizationLevel" icon={Bot} title="Personalization level" value={s.personalizationLevel} options={personalizationOptions} onChange={(value) => update({ personalizationLevel: value }, 'personalizationLevel')} />,
            <ToggleRow key="showRecommendedPosts" icon={Sparkles} title="Recommended posts" subtitle="Show posts from accounts you may like." value={s.showRecommendedPosts} disabled={savingKey === 'showRecommendedPosts'} onChange={(value) => update({ showRecommendedPosts: value }, 'showRecommendedPosts')} />,
            <ToggleRow key="showTrendingPosts" icon={Sparkles} title="Trending posts" subtitle="Include trending posts and topics in discovery." value={s.showTrendingPosts} disabled={savingKey === 'showTrendingPosts'} onChange={(value) => update({ showTrendingPosts: value }, 'showTrendingPosts')} />,
            <ToggleRow key="showFriendsFirst" icon={Users} title="Friends first" subtitle="Prioritize friends and close connections." value={s.showFriendsFirst} disabled={savingKey === 'showFriendsFirst'} onChange={(value) => update({ showFriendsFirst: value }, 'showFriendsFirst')} />,
            <ToggleRow key="autoPlayVideos" icon={Sparkles} title="Autoplay media" subtitle="Play videos automatically in feed." value={s.autoPlayVideos} disabled={savingKey === 'autoPlayVideos'} onChange={(value) => update({ autoPlayVideos: value }, 'autoPlayVideos')} />,
            <ButtonRow key="resetFeed" icon={RotateCcw} title="Reset feed personalization" subtitle="Clear served history and feedback signals." label="Reset" onClick={actions.resetFeed} />,
          ],
        },
      ];
    case 'friends':
      return [
        {
          title: 'Friend discovery',
          subtitle: 'Tune suggestions and relationship signals.',
          rows: [
            <ToggleRow key="aiFriendSuggestions" icon={Users} title="People you may know" subtitle="Suggest accounts based on profile and activity." value={s.aiFriendSuggestions} disabled={savingKey === 'aiFriendSuggestions'} onChange={(value) => update({ aiFriendSuggestions: value }, 'aiFriendSuggestions')} />,
            <ToggleRow key="showFriendsFirst" icon={Users} title="Show friends first" subtitle="Prioritize friend activity in feed and discovery." value={s.showFriendsFirst} disabled={savingKey === 'showFriendsFirst'} onChange={(value) => update({ showFriendsFirst: value }, 'showFriendsFirst')} />,
            <ActionRow key="friends" icon={Users} title="Open friends" subtitle="Review friends, requests, and suggestions." to="/friends" />,
          ],
        },
      ];
    case 'appearance':
      return [
        {
          title: 'Interface',
          subtitle: 'Make Prava feel compact and premium across devices.',
          rows: [
            <OptionRow key="themeIndex" icon={Palette} title="Theme" value={themeLabel(s.themeIndex).toLowerCase()} options={['system', 'light', 'dark']} onChange={(value) => update({ themeIndex: themeIndexFromValue(value) }, 'themeIndex')} />,
            <OptionRow key="fontSize" icon={Palette} title="Font size" value={s.fontSize} options={fontOptions} onChange={(value) => update({ fontSize: value }, 'fontSize')} />,
            <OptionRow key="displayDensity" icon={Palette} title="Display density" value={s.displayDensity} options={densityOptions} onChange={(value) => update({ displayDensity: value }, 'displayDensity')} />,
            <ToggleRow key="reduceMotion" icon={Palette} title="Reduce motion" subtitle="Use calmer transitions." value={s.reduceMotion} disabled={savingKey === 'reduceMotion'} onChange={(value) => update({ reduceMotion: value }, 'reduceMotion')} />,
            <ToggleRow key="inAppHaptics" icon={Palette} title="Haptic feedback" subtitle="Use tactile feedback on supported devices." value={s.inAppHaptics} disabled={savingKey === 'inAppHaptics'} onChange={(value) => update({ inAppHaptics: value }, 'inAppHaptics')} />,
          ],
        },
      ];
    case 'accessibility':
      return [
        {
          title: 'Reading and interaction',
          subtitle: 'Improve readability, contrast, and controls.',
          rows: [
            <RangeRow key="textScale" title="Text scale" value={s.textScale} min={0.9} max={1.2} step={0.05} onChange={(value) => update({ textScale: value }, 'textScale')} />,
            <ToggleRow key="highContrast" icon={Shield} title="High contrast" subtitle="Increase contrast across text and controls." value={s.highContrast} disabled={savingKey === 'highContrast'} onChange={(value) => update({ highContrast: value }, 'highContrast')} />,
            <ToggleRow key="boldText" icon={CheckCircle2} title="Bold text" subtitle="Use heavier text for key labels." value={s.boldText} disabled={savingKey === 'boldText'} onChange={(value) => update({ boldText: value }, 'boldText')} />,
            <ToggleRow key="largerTouchTargets" icon={CheckCircle2} title="Larger touch targets" subtitle="Increase tap areas on compact controls." value={s.largerTouchTargets} disabled={savingKey === 'largerTouchTargets'} onChange={(value) => update({ largerTouchTargets: value }, 'largerTouchTargets')} />,
            <ToggleRow key="reduceTransparency" icon={Eye} title="Reduce transparency" subtitle="Use more solid surfaces." value={s.reduceTransparency} disabled={savingKey === 'reduceTransparency'} onChange={(value) => update({ reduceTransparency: value }, 'reduceTransparency')} />,
            <ToggleRow key="screenReaderEnhancedLabels" icon={Shield} title="Enhanced screen reader labels" subtitle="Add richer labels for assistive technology." value={s.screenReaderEnhancedLabels} disabled={savingKey === 'screenReaderEnhancedLabels'} onChange={(value) => update({ screenReaderEnhancedLabels: value }, 'screenReaderEnhancedLabels')} />,
            <ToggleRow key="disableAutoplay" icon={Sparkles} title="Disable autoplay" subtitle="Stop media from playing automatically." value={s.disableAutoplay} disabled={savingKey === 'disableAutoplay'} onChange={(value) => update({ disableAutoplay: value }, 'disableAutoplay')} />,
          ],
        },
      ];
    case 'data_storage':
      return [
        {
          title: 'Network and media',
          subtitle: 'Keep media and cache usage under control.',
          rows: [
            <ToggleRow key="dataSaver" icon={Database} title="Data saver" subtitle="Reduce network usage across Prava." value={s.dataSaver} disabled={savingKey === 'dataSaver'} onChange={(value) => update({ dataSaver: value }, 'dataSaver')} />,
            <ToggleRow key="autoDownload" icon={Database} title="Auto-download" subtitle="Download media automatically on trusted networks." value={s.autoDownload} disabled={savingKey === 'autoDownload'} onChange={(value) => update({ autoDownload: value }, 'autoDownload')} />,
            <ToggleRow key="autoPlayVideos" icon={Sparkles} title="Autoplay videos" subtitle="Play videos automatically while scrolling." value={s.autoPlayVideos} disabled={savingKey === 'autoPlayVideos'} onChange={(value) => update({ autoPlayVideos: value }, 'autoPlayVideos')} />,
            <OptionRow key="mediaQuality" icon={Database} title="Media quality" value={s.mediaQuality} options={mediaOptions} onChange={(value) => update({ mediaQuality: value }, 'mediaQuality')} />,
          ],
        },
        {
          title: 'Account data',
          subtitle: 'Clear metadata or request a downloadable archive.',
          rows: [
            <ButtonRow key="clearCache" icon={Database} title="Clear cache metadata" subtitle="Refresh local cache metadata records." label="Clear" onClick={actions.clearCache} />,
            <ButtonRow key="clearSearch" icon={Database} title="Clear search history" subtitle="Remove search history for this account." label="Clear" onClick={actions.clearSearch} />,
            <ButtonRow key="exportData" icon={Database} title="Request data export" subtitle="Queue a JSON account archive." label="Export" onClick={actions.exportData} />,
            <ActionRow key="export" icon={Database} title="Data export page" subtitle="Review export status and archive options." to="/settings/export" />,
          ],
        },
      ];
    case 'ai_personalization':
      return [
        {
          title: 'AI controls',
          subtitle: 'Choose how AI can personalize Prava.',
          rows: [
            <ToggleRow key="aiPersonalizedFeed" icon={Bot} title="Personalized feed" subtitle="Use AI signals to rank For You." value={s.aiPersonalizedFeed} disabled={savingKey === 'aiPersonalizedFeed'} onChange={(value) => update({ aiPersonalizedFeed: value }, 'aiPersonalizedFeed')} />,
            <ToggleRow key="aiFriendSuggestions" icon={Users} title="Friend suggestions" subtitle="Suggest accounts and friends with AI." value={s.aiFriendSuggestions} disabled={savingKey === 'aiFriendSuggestions'} onChange={(value) => update({ aiFriendSuggestions: value }, 'aiFriendSuggestions')} />,
            <ToggleRow key="aiPostRecommendations" icon={Sparkles} title="Post recommendations" subtitle="Recommend posts based on activity." value={s.aiPostRecommendations} disabled={savingKey === 'aiPostRecommendations'} onChange={(value) => update({ aiPostRecommendations: value }, 'aiPostRecommendations')} />,
            <ToggleRow key="aiSmartReplies" icon={MessageCircle} title="Smart replies" subtitle="Suggest quick replies in chats." value={s.aiSmartReplies} disabled={savingKey === 'aiSmartReplies'} onChange={(value) => update({ aiSmartReplies: value }, 'aiSmartReplies')} />,
          ],
        },
      ];
    case 'creator':
      return [
        {
          title: 'Professional profile',
          subtitle: 'Turn on creator tools and public profile actions.',
          rows: [
            <ToggleRow key="creatorMode" icon={Flag} title="Creator mode" subtitle="Show creator features and insights." value={s.creatorMode} disabled={savingKey === 'creatorMode'} onChange={(value) => update({ creatorMode: value }, 'creatorMode')} />,
            <ToggleRow key="professionalMode" icon={Flag} title="Professional mode" subtitle="Enable professional account controls." value={s.professionalMode} disabled={savingKey === 'professionalMode'} onChange={(value) => update({ professionalMode: value }, 'professionalMode')} />,
            <ToggleRow key="publicContactButton" icon={MessageCircle} title="Public contact button" subtitle="Let people contact you from public profile." value={s.publicContactButton} disabled={savingKey === 'publicContactButton'} onChange={(value) => update({ publicContactButton: value }, 'publicContactButton')} />,
            <ToggleRow key="showCreatorBadge" icon={CheckCircle2} title="Creator badge" subtitle="Show a creator badge on profile." value={s.showCreatorBadge} disabled={savingKey === 'showCreatorBadge'} onChange={(value) => update({ showCreatorBadge: value }, 'showCreatorBadge')} />,
          ],
        },
      ];
    case 'danger':
      return [
        {
          title: 'Account access',
          subtitle: 'Sensitive actions require confirmation.',
          rows: [
            <ButtonRow key="logoutAll" icon={LogOut} title="Log out all sessions" subtitle="Sign out from every device." label="Log out" danger onClick={actions.logoutAll} />,
            <ButtonRow key="deactivate" icon={AlertTriangle} title="Deactivate account" subtitle="Create a deactivation request after password verification." label="Request" danger onClick={actions.deactivate} />,
            <ButtonRow key="delete" icon={Trash2} title="Delete account" subtitle="Request account deletion with 30-day recovery." label="Delete" danger onClick={actions.deleteAccount} />,
          ],
        },
      ];
    default:
      return [];
  }
}

function SettingSection({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle: string;
  children: ReactNode;
}) {
  return (
    <section className="settings-control-section">
      <div className="settings-control-section__head">
        <h2>{title}</h2>
        <p>{subtitle}</p>
      </div>
      <div className="settings-control-list">{children}</div>
    </section>
  );
}

function RowFrame({
  icon: Icon,
  title,
  subtitle,
  children,
  danger = false,
}: {
  icon: LucideIcon;
  title: string;
  subtitle?: string;
  children: ReactNode;
  danger?: boolean;
}) {
  return (
    <div className="settings-control-row">
      <span className={`settings-control-row__icon ${danger ? 'settings-control-row__icon--danger' : ''}`}>
        <Icon size={21} strokeWidth={2.8} />
      </span>
      <span className="settings-control-row__body">
        <strong>{title}</strong>
        {subtitle && <small>{subtitle}</small>}
      </span>
      <span className="settings-control-row__action">{children}</span>
    </div>
  );
}

function ToggleRow({
  icon,
  title,
  subtitle,
  value,
  onChange,
  disabled,
}: {
  icon: LucideIcon;
  title: string;
  subtitle: string;
  value: boolean;
  onChange: (value: boolean) => void;
  disabled?: boolean;
}) {
  return (
    <RowFrame icon={icon} title={title} subtitle={subtitle}>
      <label className="settings-switch">
        <input
          type="checkbox"
          checked={value}
          disabled={disabled}
          onChange={(event) => onChange(event.target.checked)}
        />
        <span />
      </label>
    </RowFrame>
  );
}

function OptionRow({
  icon,
  title,
  value,
  options,
  onChange,
}: {
  icon: LucideIcon;
  title: string;
  value: string;
  options: string[];
  onChange: (value: string) => void;
}) {
  return (
    <RowFrame icon={icon} title={title} subtitle={labelValue(value)}>
      <select
        className="settings-select"
        value={value}
        onChange={(event) => onChange(event.target.value)}
        aria-label={title}
      >
        {options.map((option) => (
          <option key={option} value={option}>
            {labelValue(option)}
          </option>
        ))}
      </select>
    </RowFrame>
  );
}

function RangeRow({
  title,
  value,
  min,
  max,
  step,
  onChange,
}: {
  title: string;
  value: number;
  min: number;
  max: number;
  step: number;
  onChange: (value: number) => void;
}) {
  const [draft, setDraft] = useState(value);

  useEffect(() => {
    setDraft(value);
  }, [value]);

  const commit = () => {
    if (Math.abs(draft - value) >= 0.001) {
      onChange(draft);
    }
  };

  return (
    <div className="settings-control-row settings-control-row--range">
      <span className="settings-control-row__body">
        <strong>{title}</strong>
        <small>{Math.round(draft * 100)}%</small>
      </span>
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={draft}
        onChange={(event) => setDraft(Number(event.target.value))}
        onMouseUp={commit}
        onTouchEnd={commit}
        onBlur={commit}
      />
    </div>
  );
}

function ActionRow({
  icon,
  title,
  subtitle,
  to,
}: {
  icon: LucideIcon;
  title: string;
  subtitle: string;
  to: string;
}) {
  return (
    <RowFrame icon={icon} title={title} subtitle={subtitle}>
      <Link to={to} className="p-btn p-btn--ghost p-btn--sm">
        Open
      </Link>
    </RowFrame>
  );
}

function ButtonRow({
  icon,
  title,
  subtitle,
  label,
  onClick,
  danger = false,
}: {
  icon: LucideIcon;
  title: string;
  subtitle: string;
  label: string;
  onClick: () => Promise<void>;
  danger?: boolean;
}) {
  const [loading, setLoading] = useState(false);
  const handleClick = async () => {
    if (loading) return;
    setLoading(true);
    try {
      await onClick();
    } finally {
      setLoading(false);
    }
  };

  return (
    <RowFrame icon={icon} title={title} subtitle={subtitle} danger={danger}>
      <button
        type="button"
        className={`p-btn ${danger ? 'p-btn--danger' : 'p-btn--secondary'} p-btn--sm`}
        onClick={handleClick}
        disabled={loading}
      >
        {loading ? 'Working' : label}
      </button>
    </RowFrame>
  );
}
