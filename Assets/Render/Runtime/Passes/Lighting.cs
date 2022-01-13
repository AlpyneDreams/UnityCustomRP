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
    public class Lighting : RenderPass
    {
        public Shadows shadows = new Shadows();

        static int 
            ID_DirLightCount        = Shader.PropertyToID("_DirectionalLightCount"),
            ID_DirLightColors       = Shader.PropertyToID("_DirectionalLightColors"),
            ID_DirLightDirections   = Shader.PropertyToID("_DirectionalLightDirections"),
            ID_DirLightShadowData   = Shader.PropertyToID("_DirectionalLightShadowData");

        const uint MAX_DIRECTIONAL_LIGHTS = 4;
        Vector4[]
            dirLightColors      = new Vector4[MAX_DIRECTIONAL_LIGHTS],
            dirLightDirections  = new Vector4[MAX_DIRECTIONAL_LIGHTS],
            dirLightShadowData  = new Vector4[MAX_DIRECTIONAL_LIGHTS];
        
        protected override void Setup()
        {
            shadows.Setup(this);

            uint dirLightCount = 0;
            int lightIndex = 0;

            var visibleLights = cullingResults.visibleLights;
            foreach (var light in visibleLights)
            {
                if (light.lightType == LightType.Directional)
                {
                    if (dirLightCount >= MAX_DIRECTIONAL_LIGHTS)
                        break;

                    uint index = dirLightCount;

                    Vector3 shadowData = shadows.ReserveDirectionalShadows(light.light, lightIndex);

                    dirLightColors[index]       = light.finalColor;
                    dirLightDirections[index]   = -light.localToWorldMatrix.GetColumn(2);
                    dirLightShadowData[index]   = shadowData;
                    dirLightCount++;
                }

                lightIndex++;
            }

            cmd.SetGlobalInt(ID_DirLightCount, unchecked((int)dirLightCount));
            cmd.SetGlobalVectorArray(ID_DirLightColors, dirLightColors);
            cmd.SetGlobalVectorArray(ID_DirLightDirections, dirLightDirections);
            cmd.SetGlobalVectorArray(ID_DirLightShadowData, dirLightShadowData);
            ExecuteCommandBuffer();
        }

        public override void Render()
        {
        }

        public override void Cleanup()
        {
            shadows.Cleanup();
        }
    }
}