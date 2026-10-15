using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace PersonaChat
{
    // Keep Unity's caret, selection, paste and IME support; only route Enter differently.
    public class ChatInputField : InputField
    {
        readonly Event keyboardEvent = new Event();
        int lastCompositionFrame = -100;
        [SerializeField] RectTransform composerBorder;
        [SerializeField] RectTransform historyArea;
        protected virtual string CompositionText => Input.compositionString;

        public void ConfigureLayout(RectTransform border, RectTransform history)
        {
            composerBorder = border;
            historyArea = history;
        }

        public void ResizeComposer()
        {
            if (composerBorder == null || historyArea == null || textComponent == null) return;
            var settings = textComponent.GetGenerationSettings(new Vector2(textComponent.rectTransform.rect.width, 0));
            // A final visible character makes the empty line after Shift+Enter count too.
            float height = textComponent.cachedTextGeneratorForLayout.GetPreferredHeight(text + "\u200B", settings) / textComponent.pixelsPerUnit;
            // Dynamic Korean fonts can render taller ascenders/descenders than preferredHeight.
            float wanted = Mathf.Clamp(Mathf.Ceil(height) + textComponent.fontSize * 1.5f + 30, 122, 218);
            float top = composerBorder.offsetMin.y + wanted;
            if (Mathf.Abs(composerBorder.offsetMax.y - top) < .5f) return;
            composerBorder.offsetMax = new Vector2(composerBorder.offsetMax.x, top);
            historyArea.offsetMin = new Vector2(historyArea.offsetMin.x, top + 18);
            UpdateLabel();
        }

        void ObserveComposition()
        {
            if (!string.IsNullOrEmpty(CompositionText)) lastCompositionFrame = Time.frameCount;
        }

        protected override void LateUpdate()
        {
            ObserveComposition();
            ResizeComposer();
            base.LateUpdate();
        }

        public override void OnUpdateSelected(BaseEventData eventData)
        {
            if (!isFocused || !IsInteractable()) return;
            ObserveComposition();
            while (Event.PopEvent(keyboardEvent))
            {
                if (keyboardEvent.rawType == EventType.KeyDown)
                {
                    HandleKey(keyboardEvent);
                    if (!IsInteractable() || !isFocused) break;
                }
                else if ((keyboardEvent.type == EventType.ValidateCommand || keyboardEvent.type == EventType.ExecuteCommand)
                    && keyboardEvent.commandName == "SelectAll")
                    SelectAll();
            }
            UpdateLabel();
            eventData.Use();
        }

        protected void HandleKey(Event key)
        {
            ObserveComposition();
            if (key.keyCode == KeyCode.Return || key.keyCode == KeyCode.KeypadEnter)
            {
                // IME may clear its composition string on the same frame it confirms a syllable.
                if (Time.frameCount - lastCompositionFrame <= 1) return;
                if (key.shift)
                {
                    // Let InputField insert at the caret and replace a selected range normally.
                    var newline = new Event(key) { character = '\n' };
                    KeyPressed(newline);
                    UpdateLabel();
                }
                else SendOnSubmit();
                return;
            }
            if (KeyPressed(key) == EditState.Finish) DeactivateInputField();
        }
    }
}
