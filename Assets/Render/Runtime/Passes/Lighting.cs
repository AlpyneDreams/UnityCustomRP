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

        public Vector4[] lightShadowData = new Vector4[Shadows.MAX_SHADOWED_LIGHTS];
        
        protected override void Setup()
        {
            shadows.Setup(this);

            uint dirLightCount = 0, shadowLightCount = 0;;

            foreach (var (lightIndex, light) in cullingResults.visibleLights.Entries())
            {
                switch (light.lightType)
                {
                    case LightType.Directional:
                    {
                        if (dirLightCount >= MAX_DIRECTIONAL_LIGHTS)
                            continue;

                        uint index = dirLightCount++;

                        Vector3 shadowData = shadows.ReserveDirectionalShadows(light.light, lightIndex);

                        dirLightColors[index]       = light.finalColor;
                        dirLightDirections[index]   = -light.localToWorldMatrix.GetColumn(2);
                        dirLightShadowData[index]   = shadowData;
                        break;
                    }
                    case LightType.Spot:
                    case LightType.Point:
                    {
                        // NOTE: Using index based on number of shadow lights rather than total number of lights
                        // since deferred handles non-shadowed lights by itself.
                        if (!Shadows.ShouldCastShadows(light.light)) {
                            continue;
                        }

                        uint index = shadowLightCount++;
                        lightShadowData[index] = shadows.ReserveShadows(light.light, lightIndex);
                        break;
                    }
                }
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