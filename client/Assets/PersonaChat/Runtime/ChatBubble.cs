using UnityEngine;
using UnityEngine.UI;

namespace PersonaChat
{
    // Re-measure when the window changes size, including long Korean replies.
    public sealed class ChatBubble : MonoBehaviour
    {
        public Text body;
        public LayoutElement layout;
        void LateUpdate() { Measure(); }
        public void Measure()
        {
            if (body == null || layout == null) return;
            float width = body.rectTransform.rect.width;
            if (width <= 0) return;
            // Text.preferredHeight already converts font pixels to Canvas units.
            // Re-check after font-atlas and layout updates, not only width changes.
            float height = Mathf.Max(36, Mathf.Ceil(body.preferredHeight) + 8) + 62;
            if (Mathf.Abs(layout.preferredHeight - height) < .5f) return;
            layout.preferredHeight = height;
            LayoutRebuilder.MarkLayoutForRebuild((RectTransform)transform);
        }
    }
}
