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

        partial void InitEditor()
        {
            SceneView.ClearUserDefinedCameraModes();
            SceneView.AddCameraMode("Albedo", "CRP");
            SceneView.AddCameraMode("Normal", "CRP");
        }

        RTHandle GetDebugBuffer(string cameraModeName) => cameraModeName switch {
            "Albedo"    => GBuffer0,
            "Normal"    => GBuffer1,
            _           => null,
        };

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
                
                var buffer = GetDebugBuffer(cameraMode.name);
                if (buffer == null) {
                    return;
                }

                var cmd = new CommandBuffer();
                cmd.Blit(buffer, BuiltinRenderTextureType.CameraTarget);
                context.ExecuteCommandBuffer(cmd);
            }
        }
#endif
    }
}