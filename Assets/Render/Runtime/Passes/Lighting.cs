using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Unity.Collections;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Experimental.Rendering.RenderGraphModule;
using Unity.Mathematics;
using static Unity.Mathematics.math;

using RenderContext = UnityEngine.Rendering.ScriptableRenderContext;

namespace Render
{
    public class Lighting : RenderPass
    {
        public Shadows shadows = new Shadows();

        static int 
            ID_Lights               = Shader.PropertyToID("_Lights"),
            ID_LightCount           = Shader.PropertyToID("_LightCount"),
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
        
        // Should align with LightData in LightsBuffer.hlsl
        public struct LightData {
            public float4 color;
            public float3 position;
            public int    type;
            public float3 spotDirection;
            public float4 spotData;
        };

        ComputeBuffer buffer;
        public List<LightData> lights = new List<LightData>();

        public Lighting()
        {
            int stride = System.Runtime.InteropServices.Marshal.SizeOf(typeof(LightData));
            buffer = new ComputeBuffer(16, stride, ComputeBufferType.Structured);
        }

        protected override void Setup()
        {
            shadows.Setup(this);

            uint dirLightCount = 0, shadowLightCount = 0;

            lights.Clear();

            foreach (var (lightIndex, light) in cullingResults.visibleLights.Entries())
            {
                Vector4 lightColor = light.finalColor;
                lightColor.w = 1f / Mathf.Max(light.range * light.range, 0.00001f);

                LightData data = new LightData {
                    color     = lightColor,
                    position  = new float4(light.localToWorldMatrix.GetColumn(3)).xyz,
                    type      = (int)light.lightType
                };

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
                    {
                        data.spotDirection = float4(-light.localToWorldMatrix.GetColumn(2)).xyz;

                        float cosInner = Mathf.Cos(Mathf.Deg2Rad * light.light.innerSpotAngle * 0.5f);
                        float cosOuter = Mathf.Cos(Mathf.Deg2Rad * light.spotAngle * 0.5f);
                        float invAngleDiff = 1 / Mathf.Max(cosInner - cosOuter, 0.001f);
                        data.spotData = new Vector4(invAngleDiff, -cosOuter);

                        goto default;
                    }
                    case LightType.Point:
                    default:
                    {
                        // NOTE: Using index based on number of shadow lights rather than total number of lights
                        // since deferred handles non-shadowed lights by itself.
                        if (!Shadows.ShouldCastShadows(light.light)) {
                            lights.Add(data);
                            break;
                        }

                        uint index = shadowLightCount++;
                        float4 shadowData = lightShadowData[index] = shadows.ReserveShadows(light.light, lightIndex);
                        
                        data.spotData.zw = shadowData.xy;
                        
                        lights.Add(data);
                        break;
                    }
                }
            }

            cmd.SetGlobalInt(ID_DirLightCount, unchecked((int)dirLightCount));
            cmd.SetGlobalVectorArray(ID_DirLightColors, dirLightColors);
            cmd.SetGlobalVectorArray(ID_DirLightDirections, dirLightDirections);
            cmd.SetGlobalVectorArray(ID_DirLightShadowData, dirLightShadowData);

            buffer.SetData(lights);
            cmd.SetGlobalBuffer(ID_Lights, buffer);
            cmd.SetGlobalInt(ID_LightCount, lights.Count);
            
            ExecuteCommandBuffer();
        }

        public override void Render()
        {
        }

        public override void Cleanup()
        {
            shadows.Cleanup();
        }

        public void Dispose()
        {
            if (buffer != null)
                buffer.Release();
        }
    }
}