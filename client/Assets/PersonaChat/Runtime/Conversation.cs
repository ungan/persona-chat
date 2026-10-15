using System;
using System.Collections.Generic;

namespace PersonaChat
{
    [Serializable] public sealed class ChatMessage
    {
        public string role;
        public string content;
        public ChatMessage(string role, string content) { this.role = role; this.content = content; }
    }
    // Only successful turns are retained. Reset invalidates callbacks from an older conversation.
    public sealed class Conversation
    {
        readonly List<ChatMessage> messages = new List<ChatMessage>();
        public int Version { get; private set; }
        public int Stage { get; private set; }
        public int Count { get { return messages.Count; } }
        public Conversation() { Stage = 3; }
        public void Reset(int stage)
        {
            Stage = stage; Version++; messages.Clear();
        }
        public ChatMessage[] ForRequest(string input)
        {
            var result = new List<ChatMessage>(messages);
            result.Add(new ChatMessage("user", input));
            return result.ToArray();
        }
        public bool Complete(int version, string input, string answer)
        {
            if (version != Version) return false;
            messages.Add(new ChatMessage("user", input));
            messages.Add(new ChatMessage("assistant", answer));
            while (messages.Count > 20) messages.RemoveRange(0, 2);
            return true;
        }
    }
}
