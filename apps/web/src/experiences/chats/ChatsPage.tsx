import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ConversationList } from './components/ConversationList';
import { ChatWindow } from './components/ChatWindow';
import { ConversationSummary } from '../../services/messages-service';
import { MessageCircle } from 'lucide-react';

export default function ChatsPage() {
  const navigate = useNavigate();
  const [activeChat, setActiveChat] = useState<ConversationSummary | null>(null);

  return (
    <div className="chats-layout">
      {/* Sidebar / List */}
      <div className={`chats-layout__sidebar ${activeChat ? 'chats-layout__sidebar--hidden-mobile' : ''}`}>
        <ConversationList
          activeId={activeChat?.id}
          onSelect={setActiveChat}
          onNewChat={() => {
            navigate('/chats/new');
          }}
        />
      </div>

      {/* Chat Window */}
      <div className={`chats-layout__main ${!activeChat ? 'chats-layout__main--hidden-mobile' : ''}`}>
        {activeChat ? (
          <ChatWindow
            conversation={activeChat}
            onBack={() => setActiveChat(null)}
          />
        ) : (
          <div className="chats-layout__empty">
            <div className="chats-layout__empty-inner">
              <div className="chats-layout__empty-icon">
                <MessageCircle size={40} />
              </div>
              <h3>Select a conversation</h3>
              <p>Choose a person from the list to start chatting securely.</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
