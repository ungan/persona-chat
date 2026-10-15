using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace PersonaChat.Editor
{
    [InitializeOnLoad]
    public static class ChatBuild
    {
        const string ScenePath = "Assets/PersonaChat/Scenes/Chat.unity";
        static ChatBuild()
        {
            EditorSceneManager.sceneOpened += (scene, mode) => RefreshPreview();
            if (!Application.isBatchMode) EditorApplication.delayCall += () => {
                if (!File.Exists(ScenePath)) CreateScene(); else RefreshPreview();
            };
        }
        [MenuItem("Persona Chat/Refresh Character Preview")]
        public static void RefreshPreview()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) return;
            if (EditorSceneManager.GetActiveScene().path == ScenePath && Object.FindAnyObjectByType<Camera>() == null)
            {
                var camera = new GameObject("UI Camera").AddComponent<Camera>();
                camera.clearFlags = CameraClearFlags.SolidColor;
                camera.backgroundColor = new Color(.95f,.96f,.98f);
                camera.cullingMask = 0;
                camera.orthographic = true;
                EditorSceneManager.MarkSceneDirty(camera.gameObject.scene);
                EditorSceneManager.SaveScene(camera.gameObject.scene);
            }
            foreach (var app in Object.FindObjectsByType<ChatApp>(FindObjectsSortMode.None)) app.RefreshAppearance();
            SceneView.RepaintAll();
        }
        [MenuItem("Persona Chat/Create Chat Scene")]
        public static void CreateScene()
        {
            if (!Application.isBatchMode && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            if (File.Exists(ScenePath) && !Application.isBatchMode && !EditorUtility.DisplayDialog("Recreate Chat Scene", "Chat.unity의 UI 배치를 기본값으로 다시 만듭니다. 계속할까요?", "다시 만들기", "취소")) return;
            Directory.CreateDirectory("Assets/PersonaChat/Scenes");
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            var root = new GameObject("Persona Chat");
            var background = AssetDatabase.LoadAssetAtPath<Texture2D>("Assets/PersonaChat/Resources/PersonaChat/LibraryBackground.png");
            if (background == null) Debug.Log("Private background is absent; using a plain background.");
            root.AddComponent<ChatApp>().BuildEditorUi(background);
            Directory.CreateDirectory("Assets/PersonaChat/Prefabs");
            PrefabUtility.SaveAsPrefabAssetAndConnect(root, "Assets/PersonaChat/Prefabs/ChatUI.prefab", InteractionMode.AutomatedAction);
            EditorSceneManager.SaveScene(scene, ScenePath);
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
            RefreshPreview();
        }
        [MenuItem("Persona Chat/Build Windows")]
        public static void Windows()
        {
            if (!File.Exists(ScenePath)) CreateScene();
            PlayerSettings.companyName = "PersonaChat"; PlayerSettings.productName = "Persona Chat";
            PlayerSettings.defaultScreenWidth = 1440; PlayerSettings.defaultScreenHeight = 900;
            PlayerSettings.fullScreenMode = FullScreenMode.Windowed; PlayerSettings.resizableWindow = true;
            PlayerSettings.runInBackground = true;
            var output = Path.GetFullPath(Path.Combine(Application.dataPath, "../../release/client/PersonaChat.exe"));
            Directory.CreateDirectory(Path.GetDirectoryName(output));
            var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions {
                scenes = new[] { ScenePath }, locationPathName = output,
                target = BuildTarget.StandaloneWindows64, options = BuildOptions.None
            });
            if (report.summary.result != BuildResult.Succeeded) throw new System.Exception("Unity build failed: " + report.summary.result);
        }
    }
}
