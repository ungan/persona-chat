using System;
using System.Collections;
using System.IO;
using System.Text;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;
using UnityEngine.Networking;

namespace PersonaChat
{
    [ExecuteAlways]
    public sealed class ChatApp : MonoBehaviour
    {
        [Serializable] sealed class Config { public string url; public string token; public string contentRoot; }
        [Serializable] sealed class Health { public string service; public string model; }
        [Serializable] sealed class Request { public int stage; public ChatMessage[] messages; }
        [Serializable] sealed class Reply { public string reply; public string error; public bool truncated; public string emotion; }
        readonly Conversation conversation = new Conversation();
        Config config;
        Font font;
        [SerializeField] Text status, transcript, stageText, titleText, portraitLabel;
        [SerializeField] Text characterNameText, chatTitle, emptyState;
        [SerializeField] RectTransform messageRoot;
        readonly Queue<GameObject> messageRows = new Queue<GameObject>();
        static readonly Color Ink = new Color(.13f, .17f, .23f);
        static readonly Color Gold = new Color(.84f, .69f, .43f);
        static readonly Color Cream = new Color(.99f, .97f, .91f);
        [SerializeField] InputField input;
        [SerializeField] Button send, reconnect, clear;
        [SerializeField] Button[] stages = new Button[3];
        [SerializeField] ScrollRect scroll;
        [SerializeField] RawImage portrait;
        readonly Dictionary<string, Texture2D> textures = new Dictionary<string, Texture2D>();
        CharacterProfile character;
        string characterDirectory;
        string CharacterName { get { return character == null ? "캐릭터" : character.displayName; } }
        UnityWebRequest pending;
        bool ready, busy;
        string model = "";

        void Awake()
        {
            if (!Application.isPlaying) return;
            Application.runInBackground = true;
            if (input == null || portrait == null) { Debug.LogError("Open Persona Chat > Create Chat Scene first."); enabled = false; return; }
            RefreshAppearance();
            send.onClick.AddListener(Send);
            input.onSubmit.AddListener(_ => Send());
            reconnect.onClick.AddListener(() => { Reset(conversation.Stage); StartCoroutine(Connect()); });
            clear.onClick.AddListener(() => { Reset(conversation.Stage); if (!ready) StartCoroutine(Connect()); });
            for (int i = 0; i < stages.Length; i++) { int stage = i + 1; stages[i].onClick.AddListener(() => { Reset(stage); if (!ready) StartCoroutine(Connect()); }); }
            Reset(3);
            StartCoroutine(Connect());
        }
        void OnEnable()
        {
            if (!Application.isPlaying && titleText != null && portrait != null) RefreshAppearance();
        }
        string ConfigPath()
        {
            string[] args = Environment.GetCommandLineArgs();
            for (int i = 0; i + 1 < args.Length; i++) if (args[i] == "--config") return args[i + 1];
            return Path.GetFullPath(Path.Combine(Application.dataPath, "../../.run/client.json"));
        }
        IEnumerator Connect()
        {
            ready = false;
            try
            {
                config = JsonUtility.FromJson<Config>(File.ReadAllText(ConfigPath(), Encoding.UTF8));
                var uri = new Uri(config.url);
                if (uri.Scheme != "http" || uri.Host != "127.0.0.1" || uri.AbsolutePath != "/api"
                    || !string.IsNullOrEmpty(uri.UserInfo) || !string.IsNullOrEmpty(uri.Query)
                    || !string.IsNullOrEmpty(uri.Fragment) || config.token == null || config.token.Length < 32)
                    throw new FormatException();
            }
            catch { status.text = "서버 설정이 없습니다. Start-Server.cmd 또는 Start.cmd를 먼저 실행해 주세요."; yield break; }
            if (!LoadCharacter(string.IsNullOrEmpty(config.contentRoot) ? Path.GetFullPath(Path.Combine(Path.GetDirectoryName(ConfigPath()), "..")) : config.contentRoot))
            { status.text = "character/character.json의 이름과 JSON 형식을 확인해 주세요."; yield break; }
            using (var req = UnityWebRequest.Get(config.url + "/health"))
            {
                req.SetRequestHeader("X-Chat-Token", config.token);
                req.timeout = 10; req.redirectLimit = 0;
                yield return req.SendWebRequest();
                if (req.result != UnityWebRequest.Result.Success)
                { status.text = "서버에 연결할 수 없습니다. 서버 실행 후 ‘재연결’을 눌러 주세요."; yield break; }
                Health health = null;
                try { health = JsonUtility.FromJson<Health>(req.downloadHandler.text); } catch { }
                if (health == null || health.service != "persona-chat") { status.text = "서버 종류를 확인해 주세요."; yield break; }
                model = health.model; ready = true; status.text = "연결됨 · " + model;
                Debug.Log("PersonaChat: connected to local server; model=" + model);
            }
        }
        void Reset(int stage)
        {
            if (pending != null) { pending.Abort(); pending.Dispose(); pending = null; }
            StopAllCoroutines(); busy = false;
            conversation.Reset(stage);
            if (transcript != null) transcript.text = "";
            while (messageRows.Count > 0) { var row = messageRows.Dequeue(); row.SetActive(false); Destroy(row); }
            if (emptyState != null) emptyState.gameObject.SetActive(true);
            input.text = "";
            SetEmotion("neutral");
            stageText.text = new[] { "", "이름만 지정", "이름 · 관계 · 말투", "관계 · 말투 · 행동 범위 · 예시" }[stage];
            PaintStages(stage);
            status.text = ready ? "새 대화 · " + model : "서버 연결을 준비합니다.";
            input.interactable = true; send.interactable = true;
        }
        void Send()
        {
            if (busy || !ready || string.IsNullOrWhiteSpace(input.text)) return;
            string text = input.text.Trim(); input.text = "";
            StartCoroutine(SendRequest(text));
        }
        IEnumerator SendRequest(string text)
        {
            busy = true; send.interactable = false; input.interactable = false;
            int version = conversation.Version;
            AddLine(character == null ? "나" : character.playerName, text, true);
            status.text = CharacterName + " · 답변을 준비하고 있어요…";
            var req = new UnityWebRequest(config.url + "/chat", "POST");
            pending = req;
            var body = new Request { stage = conversation.Stage, messages = conversation.ForRequest(text) };
            req.uploadHandler = new UploadHandlerRaw(Encoding.UTF8.GetBytes(JsonUtility.ToJson(body)));
            req.downloadHandler = new DownloadHandlerBuffer();
            req.SetRequestHeader("Content-Type", "application/json"); req.SetRequestHeader("X-Chat-Token", config.token);
            req.timeout = 115; req.redirectLimit = 0;
            yield return req.SendWebRequest();
            if (version != conversation.Version) { req.Dispose(); yield break; }
            Reply response = null;
            try { response = JsonUtility.FromJson<Reply>(req.downloadHandler.text); } catch { }
            if (req.result == UnityWebRequest.Result.Success && response != null && !string.IsNullOrWhiteSpace(response.reply))
            {
                conversation.Complete(version, text, response.reply);
                AddLine(CharacterName, response.reply);
                SetEmotion(response.emotion);
                Debug.Log("PersonaChat: reply received; emotion=" + response.emotion);
                status.text = response.truncated ? "답변이 길이 한도에서 끝났습니다. .env의 출력 한도를 확인해 주세요." : "연결됨 · " + model;
            }
            else
            {
                string code = response != null && !string.IsNullOrEmpty(response.error) ? response.error : "CONNECTION_FAILED";
                status.text = FriendlyError(code);
                AddLine("알림", "전송 실패 · 이 질문은 대화 이력에 저장되지 않았습니다.");
                input.text = text;
            }
            req.Dispose(); pending = null; busy = false; send.interactable = true; input.interactable = true;
            input.ActivateInputField();
        }
        static string FriendlyError(string code)
        {
            switch (code)
            {
                case "CONTEXT_TOO_LONG": return "대화가 앱의 문자 제한을 넘었습니다. 새 대화를 시작하거나 설정을 확인해 주세요.";
                case "API_KEY_OR_MODEL_ACCESS_DENIED": return "API 키 또는 모델 접근 권한을 확인해 주세요.";
                case "API_QUOTA_OR_RATE_LIMIT": return "API 사용 한도·잔액을 확인하고 잠시 후 다시 시도해 주세요.";
                case "MODEL_PARAMETERS_OR_CONTEXT_INVALID": return "모델의 입력 한도 또는 지원 옵션을 확인해 주세요. README 오류 안내를 참고하세요.";
                case "MODEL_NOT_FOUND_OR_UNAVAILABLE": return "LLM_MODEL 이름과 계정의 사용 권한을 확인해 주세요.";
                case "EMPTY_REPLY_CHECK_TOKEN_BUDGET": return "빈 답변입니다. 출력 토큰 한도와 모델 설정을 확인해 주세요.";
                case "OUTPUT_TRUNCATED": return "답변 형식이 완성되기 전에 출력 한도에 도달했습니다. 출력 토큰 한도를 늘려 주세요.";
                case "INVALID_MODEL_RESPONSE": return "답변 형식을 읽지 못했습니다. 구조화 출력을 지원하는 모델인지 확인해 주세요.";
                case "MODEL_REFUSAL": return "모델이 이 요청에 답변하지 못했습니다. 질문을 바꿔 주세요.";
                case "REQUEST_IN_PROGRESS": return "서버가 이전 요청을 처리 중입니다. 잠시 후 다시 시도해 주세요.";
                default: return "요청 실패: " + code + " · 서버 실행 상태와 README를 확인해 주세요.";
            }
        }
        void AddLine(string who, string text, bool fromPlayer = false)
        {
            if (messageRoot == null)
            {
                transcript.text += (transcript.text.Length > 0 ? "\n\n" : "") + who + "\n" + text;
                if (transcript.text.Length > 60000) transcript.text = transcript.text.Substring(transcript.text.Length - 50000);
            }
            else
            {
                emptyState.gameObject.SetActive(false);
                var row = Box("Message", messageRoot, Vector2.zero, Vector2.one, Vector2.zero, Vector2.zero);
                var layout = row.gameObject.AddComponent<LayoutElement>(); layout.preferredHeight = 110;
                float left = fromPlayer ? .12f : 0, right = fromPlayer ? 1 : .88f;
                var nameRect = Box("Speaker", row, new Vector2(left, 1), new Vector2(right, 1), new Vector2(4, -30), new Vector2(-4, 0));
                Label(who, nameRect, 18, new Color(.39f,.40f,.43f), fromPlayer ? TextAnchor.MiddleRight : TextAnchor.MiddleLeft);
                var bubble = Box("Bubble Border", row, new Vector2(left, 0), new Vector2(right, 1), Vector2.zero, new Vector2(0,-34), fromPlayer ? Gold : new Color(.86f,.83f,.76f));
                var inside = Box("Bubble", bubble, Vector2.zero, Vector2.one, Vector2.one, -Vector2.one, fromPlayer ? new Color(1,.91f,.68f) : Color.white);
                var label = Label(text, inside, 24, Ink, TextAnchor.UpperLeft);
                label.verticalOverflow = VerticalWrapMode.Overflow;
                label.rectTransform.offsetMin = new Vector2(18,14); label.rectTransform.offsetMax = new Vector2(-18,-14);
                label.lineSpacing = 1.05f;
                var measured = row.gameObject.AddComponent<ChatBubble>(); measured.body = label; measured.layout = layout;
                messageRows.Enqueue(row.gameObject);
                // Bound visible UI independently from the last 20 model-context messages.
                while (messageRows.Count > 80) { var old = messageRows.Dequeue(); old.SetActive(false); Destroy(old); }
                Canvas.ForceUpdateCanvases(); measured.Measure();
                LayoutRebuilder.ForceRebuildLayoutImmediate(messageRoot);
            }
            Canvas.ForceUpdateCanvases(); scroll.verticalNormalizedPosition = 0;
        }
        void PaintStages(int selected)
        {
            for (int i = 0; i < stages.Length; i++)
            {
                if (stages[i] == null) continue;
                bool active = i + 1 == selected;
                stages[i].targetGraphic.color = active ? new Color(.96f,.80f,.48f) : new Color(.18f,.24f,.32f,.94f);
                stages[i].GetComponentInChildren<Text>().color = active ? Ink : Cream;
            }
        }
        void ReleaseTextures()
        {
            foreach (var texture in textures.Values) { if (Application.isPlaying) Destroy(texture); else DestroyImmediate(texture); }
            textures.Clear();
        }
        void OnDestroy()
        {
            if (pending != null) { pending.Abort(); pending.Dispose(); pending = null; }
            ReleaseTextures();
            if (font != null) { if (Application.isPlaying) Destroy(font); else DestroyImmediate(font); }
        }
        public void RefreshAppearance()
        {
            if (font != null) { if (Application.isPlaying) Destroy(font); else DestroyImmediate(font); }
            font = Font.CreateDynamicFontFromOSFont(new[] { "Malgun Gothic", "맑은 고딕", "Arial" }, 24);
            font.hideFlags = HideFlags.HideAndDontSave;
            foreach (var label in GetComponentsInChildren<Text>(true)) label.font = font;
            foreach (var picture in GetComponentsInChildren<RawImage>(true))
                if (picture.name == "Library Background")
                    picture.color = picture.texture == null ? new Color(.10f,.14f,.21f) : Color.white;
            string root = Path.GetFullPath(Path.Combine(Application.dataPath, "../.."));
            if (Application.isPlaying)
            {
                try { var local = JsonUtility.FromJson<Config>(File.ReadAllText(ConfigPath(), Encoding.UTF8)); if (!string.IsNullOrEmpty(local.contentRoot)) root = local.contentRoot; }
                catch { }
            }
            LoadCharacter(root);
            Canvas.ForceUpdateCanvases();
        }
        bool LoadCharacter(string root)
        {
            try
            {
                characterDirectory = Path.Combine(root, "character");
                character = CharacterProfile.Load(Path.Combine(characterDirectory, "character.json"));
                ReleaseTextures();
                titleText.text = CharacterName + "와 대화하기";
                if (characterNameText != null) characterNameText.text = CharacterName;
                if (chatTitle != null) chatTitle.text = CharacterName + "와의 대화";
                ((Text)input.placeholder).text = CharacterName + "에게 할 말을 입력하세요…";
                SetEmotion("neutral");
                return true;
            }
            catch { Debug.LogWarning("Cannot load character/character.json. Check its name and JSON format."); return false; }
        }
        bool TryPortrait(PortraitSpec spec)
        {
            if (spec == null) return false;
            try
            {
                string file = spec.Resolve(characterDirectory);
                Texture2D texture;
                if (!textures.TryGetValue(file, out texture))
                {
                    if (new FileInfo(file).Length > 16 * 1024 * 1024) return false;
                    texture = new Texture2D(2, 2, TextureFormat.RGBA32, false);
                    if (!texture.LoadImage(File.ReadAllBytes(file))) { if (Application.isPlaying) Destroy(texture); else DestroyImmediate(texture); return false; }
                    texture.hideFlags = HideFlags.HideAndDontSave;
                    textures[file] = texture;
                }
                portrait.texture = texture; portrait.uvRect = spec.UV; portrait.enabled = true;
                portrait.GetComponent<AspectRatioFitter>().aspectRatio = (float)texture.width / spec.columns / texture.height;
                return true;
            }
            catch { return false; }
        }
        void SetEmotion(string emotion)
        {
            if (portrait == null) return;
            if (emotion != "happy" && emotion != "sad") emotion = "neutral";
            bool loaded = character != null && TryPortrait(character.Portrait(emotion));
            if (!loaded && emotion != "neutral") { emotion = "neutral"; loaded = character != null && TryPortrait(character.neutral); }
            if (!loaded) { portrait.texture = null; portrait.enabled = false; }
            portraitLabel.text = (loaded ? (emotion == "happy" ? "기쁨" : emotion == "sad" ? "걱정·슬픔" : "평상시") : "이미지 없음");
        }
        RectTransform Box(string name, Transform parent, Vector2 min, Vector2 max, Vector2 lo, Vector2 hi, Color? fill = null)
        {
            var g = new GameObject(name, typeof(RectTransform)); g.transform.SetParent(parent, false);
            var r = (RectTransform)g.transform; r.anchorMin = min; r.anchorMax = max; r.offsetMin = lo; r.offsetMax = hi;
            if (fill.HasValue) g.AddComponent<RoundedPanel>().color = fill.Value;
            return r;
        }
        Text Label(string value, Transform parent, int size, Color color, TextAnchor alignment = TextAnchor.MiddleLeft)
        {
            var r = Box("Text", parent, Vector2.zero, Vector2.one, new Vector2(12, 4), new Vector2(-12, -4));
            var t = r.gameObject.AddComponent<Text>(); t.font = font; t.fontSize = size; t.color = color;
            t.text = value; t.alignment = alignment; t.supportRichText = false; t.raycastTarget = false;
            return t;
        }
        Button ButtonAt(string value, Transform parent, Vector2 min, Vector2 max, Vector2 lo, Vector2 hi, UnityEngine.Events.UnityAction action)
        {
            var r = Box(value, parent, min, max, lo, hi, new Color(.96f,.80f,.48f));
            var b = r.gameObject.AddComponent<Button>(); b.targetGraphic = r.GetComponent<RoundedPanel>();
            var colors = b.colors; colors.highlightedColor = new Color(1,.96f,.85f); colors.pressedColor = new Color(.8f,.75f,.63f); b.colors = colors;
            Label(value, r, 20, new Color(.12f, .14f, .18f), TextAnchor.MiddleCenter);
            return b;
        }
        // Editor factory calls this once to save real, editable scene objects.
        public void BuildEditorUi(Texture2D background = null)
        {
            font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            if (FindAnyObjectByType<EventSystem>() == null) new GameObject("EventSystem", typeof(EventSystem), typeof(StandaloneInputModule));
            var root = new GameObject("Chat Canvas", typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            root.transform.SetParent(transform, false); root.GetComponent<Canvas>().renderMode = RenderMode.ScreenSpaceOverlay;
            var scaler = root.GetComponent<CanvasScaler>(); scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1440, 900); scaler.matchWidthOrHeight = 0;
            var back = Box("Library Background", root.transform, Vector2.zero, Vector2.one, Vector2.zero, Vector2.zero);
            var backdrop = back.gameObject.AddComponent<RawImage>(); backdrop.texture = background; backdrop.raycastTarget = false;
            backdrop.color = background == null ? new Color(.10f,.14f,.21f) : Color.white;
            var shade = Box("Atmosphere", back, Vector2.zero, Vector2.one, Vector2.zero, Vector2.zero, new Color(.04f,.07f,.12f,.40f));
            shade.GetComponent<RoundedPanel>().radius = 0; shade.GetComponent<RoundedPanel>().raycastTarget = false;
            var title = Box("Title", back, new Vector2(0,1), new Vector2(.42f,1), new Vector2(32,-86), new Vector2(-8,-20));
            titleText = Label("캐릭터와 대화하기", title, 34, Cream); titleText.fontStyle = FontStyle.Bold;
            titleText.resizeTextForBestFit = true; titleText.resizeTextMinSize = 18; titleText.resizeTextMaxSize = 34;
            for (int i=1; i<=3; i++)
                stages[i-1] = ButtonAt(i + "단계", back, new Vector2(.43f,1), new Vector2(.43f,1), new Vector2((i-1)*120,-78), new Vector2(108+(i-1)*120,-28), null);
            PaintStages(3);
            reconnect = ButtonAt("재연결", back, Vector2.one, Vector2.one, new Vector2(-146,-78), new Vector2(-32,-28), null);
            reconnect.targetGraphic.color = new Color(.88f,.84f,.72f);
            var stageRect = Box("Stage", back, new Vector2(0,1), new Vector2(1,1), new Vector2(34,-122), new Vector2(-34,-88));
            stageText = Label("관계 · 말투 · 행동 범위 · 예시", stageRect, 18, new Color(.88f,.84f,.73f));

            var characterPanel = Box("Character", back, Vector2.zero, new Vector2(.34f,1), new Vector2(28,46), new Vector2(-12,-138));
            var portraitArea = Box("Portrait Area", characterPanel, Vector2.zero, Vector2.one, new Vector2(-10,90), new Vector2(10,0));
            var picture = Box("Portrait", portraitArea, new Vector2(.5f,.5f), new Vector2(.5f,.5f), Vector2.zero, Vector2.zero);
            portrait = picture.gameObject.AddComponent<RawImage>(); portrait.raycastTarget = false;
            picture.gameObject.AddComponent<AspectRatioFitter>().aspectMode = AspectRatioFitter.AspectMode.FitInParent;
            var nameplate = Box("Nameplate Border", characterPanel, Vector2.zero, new Vector2(1,0), new Vector2(10,0), new Vector2(-10,102), Gold);
            var nameFill = Box("Nameplate", nameplate, Vector2.zero, Vector2.one, new Vector2(2,2), new Vector2(-2,-2), Cream);
            var name = Box("Name", nameFill, Vector2.zero, Vector2.one, new Vector2(12,40), new Vector2(-12,-7));
            characterNameText = Label("캐릭터", name, 30, Ink); characterNameText.fontStyle = FontStyle.Bold;
            characterNameText.resizeTextForBestFit = true; characterNameText.resizeTextMinSize = 16; characterNameText.resizeTextMaxSize = 30;
            var caption = Box("Expression Badge", nameFill, Vector2.zero, new Vector2(1,0), new Vector2(16,12), new Vector2(-16,42), new Color(1,.91f,.68f));
            portraitLabel = Label("평상시", caption, 18, Ink, TextAnchor.MiddleCenter);

            var frame = Box("Conversation Gold Border", back, new Vector2(.34f,0), Vector2.one, new Vector2(10,46), new Vector2(-32,-138), Gold);
            var panel = Box("Conversation", frame, Vector2.zero, Vector2.one, new Vector2(2,2), new Vector2(-2,-2), Cream);
            var header = Box("Chat Title", panel, new Vector2(0,1), Vector2.one, new Vector2(22,-74), new Vector2(-190,-14));
            chatTitle = Label("캐릭터와의 대화", header, 28, Ink); chatTitle.fontStyle = FontStyle.Bold;
            chatTitle.resizeTextForBestFit = true; chatTitle.resizeTextMinSize = 16; chatTitle.resizeTextMaxSize = 28;
            clear = ButtonAt("새 대화", panel, Vector2.one, Vector2.one, new Vector2(-162,-68), new Vector2(-24,-22), null);
            clear.targetGraphic.color = new Color(.93f,.89f,.80f);
            Box("Header Divider", panel, new Vector2(0,1), Vector2.one, new Vector2(24,-88), new Vector2(-24,-87), new Color(.87f,.83f,.75f));
            var chatArea = Box("Scroll Area", panel, Vector2.zero, Vector2.one, new Vector2(24,182), new Vector2(-24,-102));
            scroll = chatArea.gameObject.AddComponent<ScrollRect>(); scroll.horizontal = false; scroll.scrollSensitivity = 40;
            scroll.movementType = ScrollRect.MovementType.Clamped;
            var viewport = Box("Viewport", chatArea, Vector2.zero, Vector2.one, Vector2.zero, new Vector2(-12,0), new Color(1,1,1,0));
            viewport.gameObject.AddComponent<RectMask2D>(); scroll.viewport = viewport;
            var bar = Box("Scroll Track", chatArea, new Vector2(1,0), Vector2.one, new Vector2(-7,0), Vector2.zero, new Color(.93f,.90f,.83f));
            var handle = Box("Scroll Handle", bar, Vector2.zero, Vector2.one, Vector2.zero, Vector2.zero, Gold);
            var scrollbar = bar.gameObject.AddComponent<Scrollbar>(); scrollbar.handleRect = handle;
            scrollbar.targetGraphic = handle.GetComponent<RoundedPanel>(); scrollbar.direction = Scrollbar.Direction.BottomToTop;
            scroll.verticalScrollbar = scrollbar; scroll.verticalScrollbarVisibility = ScrollRect.ScrollbarVisibility.AutoHide;
            messageRoot = Box("History", viewport, new Vector2(0,1), Vector2.one, Vector2.zero, Vector2.zero);
            messageRoot.pivot = new Vector2(.5f,1); scroll.content = messageRoot;
            var layout = messageRoot.gameObject.AddComponent<VerticalLayoutGroup>(); layout.spacing = 10;
            layout.padding = new RectOffset(2,12,8,8); layout.childControlWidth = true; layout.childControlHeight = true;
            layout.childForceExpandWidth = true; layout.childForceExpandHeight = false;
            var fitter = messageRoot.gameObject.AddComponent<ContentSizeFitter>(); fitter.verticalFit = ContentSizeFitter.FitMode.PreferredSize;
            transcript = null;
            emptyState = Label("어떤 이야기를 나눠볼까요?\n\n아래에 메시지를 입력해 대화를 시작하세요.", viewport, 23, new Color(.50f,.48f,.44f), TextAnchor.MiddleCenter);
            var inputBorder = Box("Input Border", panel, Vector2.zero, new Vector2(1,0), new Vector2(24,42), new Vector2(-144,164), new Color(.85f,.79f,.66f));
            var inputRect = Box("Input", inputBorder, Vector2.zero, Vector2.one, Vector2.one, -Vector2.one, Color.white);
            var inputText = Label("", inputRect, 23, Ink, TextAnchor.UpperLeft);
            var placeholder = Label("캐릭터에게 할 말을 입력하세요…", inputRect, 23, new Color(.52f,.54f,.57f), TextAnchor.UpperLeft);
            inputText.rectTransform.offsetMin = placeholder.rectTransform.offsetMin = new Vector2(16,12);
            inputText.rectTransform.offsetMax = placeholder.rectTransform.offsetMax = new Vector2(-16,-12);
            input = inputRect.gameObject.AddComponent<ChatInputField>(); input.textComponent = inputText; input.placeholder = placeholder;
            ((ChatInputField)input).ConfigureLayout(inputBorder, chatArea);
            input.targetGraphic = inputRect.GetComponent<RoundedPanel>();
            input.lineType = InputField.LineType.MultiLineNewline; input.characterLimit = 4000;
            input.selectionColor = new Color(.90f,.72f,.35f,.35f); input.caretColor = Ink; input.customCaretColor = true;
            send = ButtonAt("전송", panel, new Vector2(1,0), new Vector2(1,0), new Vector2(-128,42), new Vector2(-24,130), null);
            var hint = Box("Input Hint", panel, Vector2.zero, new Vector2(1,0), new Vector2(30,10), new Vector2(-24,36));
            Label("Enter 전송 · Shift+Enter 줄바꿈", hint, 15, new Color(.53f,.51f,.46f));
            var statusRect = Box("Status", back, Vector2.zero, new Vector2(1,0), new Vector2(34,4), new Vector2(-34,39));
            status = Label("Start-Server.cmd 실행 후 Play를 눌러 주세요.", statusRect, 17, Cream);
            font = null; // The built-in asset is not owned by this component.
        }
    }
}
