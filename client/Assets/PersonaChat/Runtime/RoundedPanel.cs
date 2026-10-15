using UnityEngine;
using UnityEngine.UI;

namespace PersonaChat
{
    // Native UI geometry: editable color/radius, no baked text or screenshot panels.
    [AddComponentMenu("Persona Chat/Rounded Panel")]
    [RequireComponent(typeof(CanvasRenderer))]
    public sealed class RoundedPanel : MaskableGraphic
    {
        [Min(0)] public float radius = 18;
        protected override void OnPopulateMesh(VertexHelper mesh)
        {
            mesh.Clear();
            Rect r = rectTransform.rect;
            float rad = Mathf.Min(radius, Mathf.Min(r.width, r.height) * .5f);
            mesh.AddVert(r.center, color, Vector2.zero);
            const int steps = 12;
            for (int corner = 0; corner < 4; corner++)
            {
                Vector2 center = new Vector2(corner == 0 || corner == 3 ? r.xMax - rad : r.xMin + rad,
                    corner < 2 ? r.yMax - rad : r.yMin + rad);
                for (int i = 0; i <= steps; i++)
                {
                    float angle = (corner * 90f + i * 90f / steps) * Mathf.Deg2Rad;
                    mesh.AddVert(center + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * rad, color, Vector2.zero);
                }
            }
            int count = 4 * (steps + 1);
            for (int i = 1; i <= count; i++) mesh.AddTriangle(0, i, i == count ? 1 : i + 1);
        }
    }
}
