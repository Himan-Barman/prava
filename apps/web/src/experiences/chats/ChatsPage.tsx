import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ConversationList } from './components/ConversationList';
import { ChatWindow } from './components/ChatWindow';
import { ConversationSummary } from '../../services/messages-service';
import { MessageCircle } from 'lucide-react';

export default function ChatsPage() {
  const navigate = useNavigate();
  const [activeChat, setActiveChat] = useState<ConversationSummary | null>(null);

  // For mobile view logic usually, but we'll implement simple conditional for now
  // Or CSS Grid/Flex for desktop split

  return (
    <div className="h-[calc(100vh-120px)] max-w-6xl mx-auto flex gap-6 overflow-hidden">
      {/* Sidebar / List - Hidden on mobile if chat is active, shown on desktop always */}
      <div className={`w-full md:w-80 lg:w-96 flex-shrink-0 flex flex-col ${activeChat ? 'hidden md:flex' : 'flex'}`}>
        <ConversationList
          activeId={activeChat?.id}
          onSelect={setActiveChat}
          onNewChat={() => {
            navigate('/chats/new');
          }}
        />
      </div>

      {/* Chat Window - Hidden on mobile if no chat active, shown on desktop always */}
      <div className={`flex-1 flex flex-col ${!activeChat ? 'hidden md:flex' : 'flex'}`}>
        {activeChat ? (
          <ChatWindow
            conversation={activeChat}
            onBack={() => setActiveChat(null)}
          />
        ) : (
          <div className="h-full flex items-center justify-center">
            <div className="text-center p-8 opacity-60">
              <div className="w-20 h-20 bg-prava-accent/10 rounded-full flex items-center justify-center mx-auto mb-4">
                <MessageCircle className="w-10 h-10 text-prava-accent" />
              </div>
              <h3 className="text-xl font-semibold mb-2">Select a conversation</h3>
              <p className="max-w-xs mx-auto">Choose a person from the list to start chatting securely.</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
