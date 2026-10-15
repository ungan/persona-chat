using System;
using System.IO;
using System.Text;
using UnityEngine;

namespace PersonaChat
{
    [Serializable]
    public sealed class PortraitSpec
    {
        public string path;
        public int columns = 1;
        public int index;
        public Rect UV { get { return new Rect((float)index / columns, 0, 1f / columns, 1); } }
        public string Resolve(string directory)
        {
            if (columns < 1 || columns > 32 || index < 0 || index >= columns || string.IsNullOrWhiteSpace(path))
                throw new FormatException("Invalid portrait cell");
            string root = Path.GetFullPath(directory) + Path.DirectorySeparatorChar;
            string file = Path.GetFullPath(Path.Combine(directory, path));
            if (!file.StartsWith(root, StringComparison.OrdinalIgnoreCase)) throw new FormatException("Portrait must be inside character folder");
            return file;
        }
    }
    [Serializable]
    public sealed class CharacterProfile
    {
        public string displayName;
        public string playerName;
        public PortraitSpec neutral, happy, sad;
        public static CharacterProfile Load(string file)
        {
            var profile = JsonUtility.FromJson<CharacterProfile>(File.ReadAllText(file, Encoding.UTF8).TrimStart('\uFEFF'));
            if (profile == null || string.IsNullOrWhiteSpace(profile.displayName) || profile.displayName.Length > 40)
                throw new FormatException("Set displayName (1..40 characters) in character.json");
            profile.displayName = profile.displayName.Trim();
            if (string.IsNullOrWhiteSpace(profile.playerName)) profile.playerName = "나";
            return profile;
        }
        public PortraitSpec Portrait(string emotion)
        {
            return emotion == "happy" ? happy : emotion == "sad" ? sad : neutral;
        }
    }
}
