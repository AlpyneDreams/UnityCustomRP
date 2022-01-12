using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.Rendering;
using UnityEngine;
using UnityEngine.Rendering;
using Unity.Collections;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Experimental.Rendering.RenderGraphModule;


using RenderContext = UnityEngine.Rendering.ScriptableRenderContext;

namespace Render
{
    public partial class CustomRenderPipeline
    {
#if UNITY_EDITOR

        internal Material DebugMaterial = new Material(Shader.Find("Hidden/Custom/Debug"));

        partial void InitEditor()
        {
            SceneView.ClearUserDefinedCameraModes();
            SceneView.AddCameraMode("Albedo", "CRP");
            SceneView.AddCameraMode("Normal", "CRP");
            SceneView.AddCameraMode("Gloss", "CRP");
            SceneView.AddCameraMode("Metallic", "CRP");

            InitFullscreenMaterial(DebugMaterial);
        }

        partial void DrawGizmos(RenderContext context)
        {
            if (Handles.ShouldRenderGizmos()) {
                context.DrawGizmos(camera, GizmoSubset.PreImageEffects);
                context.DrawGizmos(camera, GizmoSubset.PostImageEffects);
            }
        }

        partial void DrawDebug(RenderContext context)
        {
            if (camera.cameraType == CameraType.SceneView) {

                var cameraMode = SceneView.currentDrawingSceneView.cameraMode;

                if (cameraMode.section != "CRP")
                    return;

                string keyword = "DEBUG_" + cameraMode.name.ToUpper();

                var cmd = new CommandBuffer();
                cmd.EnableShaderKeyword(keyword);
                CoreUtils.DrawFullScreen(cmd, DebugMaterial);
                cmd.DisableShaderKeyword(keyword);
                context.ExecuteCommandBuffer(cmd);
            }
        }
#endif
    }
}