import { apiClient } from '../adapters/api-client';

export interface FriendUser {
  id: string;
  username: string;
  displayName: string;
  bio?: string;
  avatarUrl?: string;
  location?: string;
  isVerified?: boolean;
  isOnline?: boolean;
}

export interface FriendRequest {
  user: FriendUser;
  message: string;
  receivedAt: string; // "2h ago", "recently"
  priorityLabel?: string; // "New", "Priority"
}

export interface SentRequest {
  user: FriendUser;
  status: 'pending' | 'seen';
  timeLabel: string; // "Sent 2h ago"
  note?: string;
}

export interface FriendConnection {
  user: FriendUser;
  connectedSince: string;
  isFavorite: boolean;
  isMuted: boolean;
  isPinned: boolean;
}

export interface FriendsResponse {
  requests: FriendRequest[];
  sent: SentRequest[];
  friends: FriendConnection[];
}

// Mock Data
const MOCK_USERS: FriendUser[] = [
  { id: '1', username: 'alice', displayName: 'Alice Cooper', bio: 'Digital Artist 🎨', location: 'New York', isVerified: true, isOnline: true },
  { id: '2', username: 'bob', displayName: 'Bob Smith', bio: 'Tech Enthusiast', location: 'London', isOnline: false },
  { id: '3', username: 'carol', displayName: 'Carol Davis', bio: 'Photography 📸', location: 'Paris', isOnline: true },
  { id: '4', username: 'david', displayName: 'David Wilson', location: 'Berlin', isOnline: false },
  { id: '5', username: 'eve', displayName: 'Eve Johnson', bio: 'Designer', location: 'Toronto', isOnline: true },
  { id: '6', username: 'frank', displayName: 'Frank Lee', bio: 'Developer', isOnline: true },
  { id: '7', username: 'grace', displayName: 'Grace Kim', bio: 'Musician 🎸', isVerified: true, isOnline: false },
];

class FriendsService {
  async getConnections(): Promise<FriendsResponse> {
    // Simulating API call
    await new Promise(resolve => setTimeout(resolve, 800));

    return {
      requests: [
        {
          user: MOCK_USERS[5],
          message: 'Wants to connect on Prava.',
          receivedAt: '2h ago',
          priorityLabel: 'New'
        },
        {
          user: MOCK_USERS[6],
          message: 'Based in Seoul. Wants to connect.',
          receivedAt: '1d ago',
        }
      ],
      sent: [
        {
          user: MOCK_USERS[4],
          status: 'pending',
          timeLabel: 'Sent yesterday',
          note: 'Awaiting response.'
        }
      ],
      friends: [
        {
          user: MOCK_USERS[0],
          connectedSince: 'Connected 2y ago',
          isFavorite: true,
          isMuted: false,
          isPinned: true
        },
        {
          user: MOCK_USERS[1],
          connectedSince: 'Connected 1y ago',
          isFavorite: false,
          isMuted: false,
          isPinned: false
        },
        {
          user: MOCK_USERS[2],
          connectedSince: 'Connected 3mo ago',
          isFavorite: false,
          isMuted: true,
          isPinned: false
        }
      ]
    };
  }

  // Mock Actions
  async acceptRequest(userId: string) {
    await new Promise(resolve => setTimeout(resolve, 500));
    return true;
  }

  async declineRequest(userId: string) {
    await new Promise(resolve => setTimeout(resolve, 500));
    return true;
  }

  async cancelRequest(userId: string) {
    await new Promise(resolve => setTimeout(resolve, 500));
    return true;
  }

  async removeFriend(userId: string) {
    await new Promise(resolve => setTimeout(resolve, 500));
    return true;
  }
}

export const friendsService = new FriendsService();
