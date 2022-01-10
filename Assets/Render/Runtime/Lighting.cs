using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Unity.Collections;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Experimental.Rendering.RenderGraphModule;


using RenderContext = UnityEngine.Rendering.ScriptableRenderContext;

namespace Render
{
    public static class Lighting
    {
        static int 
            ID_DirLightCount        = Shader.PropertyToID("_DirectionalLightCount"),
            ID_DirLightColors       = Shader.PropertyToID("_DirectionalLightColors"),
            ID_DirLightDirections   = Shader.PropertyToID("_DirectionalLightDirections");

        const uint MAX_DIRECTIONAL_LIGHTS = 4;
        static Vector4[]
            DirLightColors      = new Vector4[MAX_DIRECTIONAL_LIGHTS],
            DirLightDirections  = new Vector4[MAX_DIRECTIONAL_LIGHTS];
        
        public static void Setup(RenderContext context, CullingResults cullingResults)
        {
            uint DirLightCount = 0;

            var visibleLights = cullingResults.visibleLights;
            foreach (var light in visibleLights)
            {
                if (light.lightType == LightType.Directional)
                {
                    if (DirLightCount >= MAX_DIRECTIONAL_LIGHTS)
                        break;
                    
                    uint index = DirLightCount;
                    DirLightColors[index]       = light.finalColor;
                    DirLightDirections[index]   = -light.localToWorldMatrix.GetColumn(2);
                    DirLightCount++;
                }
            }

            var cmd = new CommandBuffer() { name = "Lighting" };
            cmd.SetGlobalInt(ID_DirLightCount, unchecked((int)DirLightCount));
            cmd.SetGlobalVectorArray(ID_DirLightColors, DirLightColors);
            cmd.SetGlobalVectorArray(ID_DirLightDirections, DirLightDirections);
            context.ExecuteCommandBuffer(cmd);
        }
    }
}