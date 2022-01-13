using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Unity.Collections;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Experimental.Rendering.RenderGraphModule;

using RenderContext = UnityEngine.Rendering.ScriptableRenderContext;
using ShadowFilterMode = Render.ShadowSettings.FilterMode;

namespace Render
{
    public class Shadows : RenderPass
    {
        // Sould match Shadows.hlsl
        public const uint MAX_SHADOWED_DIRECTIONAL_LIGHTS = 4;
        public const uint MAX_SHADOW_CASCADES = 4;

        static int
            ID_DirShadowAtlas    = Shader.PropertyToID("_DirectionalShadowAtlas"),
            ID_DirShadowMatrices = Shader.PropertyToID("_DirectionalShadowMatrices"),
            ID_CascadeCount      = Shader.PropertyToID("_ShadowCascadeCount"),
            ID_CascadeSpheres    = Shader.PropertyToID("_ShadowCascadeCullingSpheres"),
            ID_CascadeData       = Shader.PropertyToID("_ShadowCascadeData"),
            ID_ShadowAtlasSize   = Shader.PropertyToID("_ShadowAtlasSize"),
            ID_ShadowDistFade    = Shader.PropertyToID("_ShadowDistanceFade");

        static string[] k_DirectionalFilters = {
            "SHADOW_DIRECTIONAL_PCF3",
            "SHADOW_DIRECTIONAL_PCF5",
            "SHADOW_DIRECTIONAL_PCF7"
        };

        struct ShadowDirLight {
            public int visibleLightIndex;
            public float slopeScaleBias;
            public float nearPlaneOffset;
        };
        
        uint shadowDirLightCount = 0;

        ShadowDirLight[] shadowDirLights = new ShadowDirLight[MAX_SHADOWED_DIRECTIONAL_LIGHTS];
        Matrix4x4[] dirShadowMatrices    = new Matrix4x4[MAX_SHADOWED_DIRECTIONAL_LIGHTS * MAX_SHADOW_CASCADES];
        Vector4[] cascadeCullingSpheres  = new Vector4[MAX_SHADOW_CASCADES];
        Vector4[] cascadeData            = new Vector4[MAX_SHADOW_CASCADES];

        protected override void Setup()
        {
            shadowDirLightCount = 0;
        }

        // Return type is DirectionalShadowData: strength, tileIndex, normalBias
        public Vector3 ReserveDirectionalShadows(Light light, int index)
        {
            if (
                shadowDirLightCount < MAX_SHADOWED_DIRECTIONAL_LIGHTS
                && light.isActiveAndEnabled
                && light.shadows != LightShadows.None && light.shadowStrength > 0f
                && cullingResults.GetShadowCasterBounds(index, out Bounds b)
            ) {
                uint i = shadowDirLightCount++;
                shadowDirLights[i] = new ShadowDirLight {
                    visibleLightIndex = index,
                    slopeScaleBias    = light.shadowBias,
                    nearPlaneOffset   = light.shadowNearPlane
                };
                return new Vector3(
                    light.shadowStrength,
                    settings.shadows.directional.cascadeCount * i,
                    light.shadowNormalBias
                );
            }
            return new Vector3(0, 0, 0);
        }

        public override void Render()
        {
            if (shadowDirLightCount > 0) {
                RenderDirectionalShadows();
            } else {
                // Create 1x1 dummy texture to release later
                cmd.GetTemporaryRT(
                    ID_DirShadowAtlas, 1, 1, 32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap
                );
                ExecuteCommandBuffer();
            }
        }

        void RenderDirectionalShadows()
        {
            int atlasSize = (int)settings.shadows.directional.atlasSize;

            cmd.GetTemporaryRT(
                ID_DirShadowAtlas, atlasSize, atlasSize, 32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap
            );
            cmd.SetRenderTarget(ID_DirShadowAtlas, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            cmd.ClearRenderTarget(true, false, Color.clear);
            cmd.BeginSample(cmd.name);
            ExecuteCommandBuffer();

            uint tiles = shadowDirLightCount * settings.shadows.directional.cascadeCount;
            int split = tiles <= 1 ? 1 : (tiles <= 4 ? 2 : 4);
            int tileSize = atlasSize / split;

            for (int index = 0; index < shadowDirLightCount; index++)
            {
                ShadowDirLight light = shadowDirLights[index];
                var shadowSettings = new ShadowDrawingSettings(cullingResults, light.visibleLightIndex);

                int cascadeCount = (int)settings.shadows.directional.cascadeCount;
                int tileOffset = index * cascadeCount;
                float[] ratios = settings.shadows.directional.cascadeRatios;
                float cullingFactor = Mathf.Max(0f, 0.8f - settings.shadows.directional.cascadeFade);

                for (int c = 0; c < cascadeCount; c++)
                {
                    Vector3 splitRatios = new Vector3(ratios[0], ratios[1], ratios[2]);

                    // Compute Matrices
                    cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(
                        light.visibleLightIndex, c, cascadeCount, splitRatios, tileSize, light.nearPlaneOffset,
                        out Matrix4x4 view, out Matrix4x4 proj, out ShadowSplitData splitData
                    );

                    splitData.shadowCascadeBlendCullingFactor = cullingFactor;
                    shadowSettings.splitData = splitData;
                    if (index == 0) {
                        SetCascadeData(c, splitData.cullingSphere, tileSize);
                    }

                    int tileIndex = tileOffset + c;
                    
                    // Set Viewport & Matrices
                    var offset = SetTileViewport(tileIndex, split, tileSize);
                    dirShadowMatrices[tileIndex] = GetAtlasMatrix(proj * view, offset, split);
                    cmd.SetViewProjectionMatrices(view, proj);

                    cmd.SetGlobalDepthBias(0f, light.slopeScaleBias);
                    ExecuteCommandBuffer();
                    
                    // Draw Shadows
                    context.DrawShadows(ref shadowSettings);

                    cmd.SetGlobalDepthBias(0f, 0f);
                }
            }
            
            // Set shadow parameters
            cmd.SetGlobalInt(ID_CascadeCount, unchecked((int)settings.shadows.directional.cascadeCount));
            cmd.SetGlobalVectorArray(ID_CascadeSpheres, cascadeCullingSpheres);
            cmd.SetGlobalVectorArray(ID_CascadeData, cascadeData);
            cmd.SetGlobalMatrixArray(ID_DirShadowMatrices, dirShadowMatrices);
            float cascadeFade = 1f - settings.shadows.directional.cascadeFade;
            cmd.SetGlobalVector(ID_ShadowDistFade, new Vector4(
                1f / settings.shadows.maxDistance,      // Pre-divide for performance
                1f / settings.shadows.distanceFade, 
                1f / (1f - cascadeFade * cascadeFade)   // Using square distance here
            ));
            cmd.SetGlobalVector(ID_ShadowAtlasSize, new Vector4(atlasSize, 1f/atlasSize));

            SetKeywords();
            cmd.EndSample(cmd.name);
            ExecuteCommandBuffer();
        }

        void SetKeywords()
        {
            int filter = (int)settings.shadows.directional.filter;
            foreach (var (i, keyword) in k_DirectionalFilters.Entries()) {
                cmd.SetShaderKeyword(keyword, i+2 == filter);
            }
        }

        // sqrt(2). Texels are square.
        const float SQRT2 = 1.4142136f;

        void SetCascadeData(int index, Vector4 cullingSphere, float tileSize)
        {
            float texelSize  = 2f * cullingSphere.w / tileSize;
            float filterSize = texelSize * 4; // PCF filter size is 4 (16 samples)
            cullingSphere.w -= filterSize;
            cullingSphere.w *= cullingSphere.w; // Store square radius for efficiency
            cascadeCullingSpheres[index] = cullingSphere;
            cascadeData[index] = new Vector4(1f/cullingSphere.w, filterSize * SQRT2);

        }

        Vector2 SetTileViewport(int index, int split, float tileSize)
        {
            Vector2 offset = new Vector2(index % split, index / split);
            cmd.SetViewport(new Rect(offset * tileSize, Vector2.one * tileSize));
            return offset;
        }

        Matrix4x4 GetAtlasMatrix(Matrix4x4 m, Vector2 offset, int split)
        {
            if (SystemInfo.usesReversedZBuffer) {
                m.m20 = -m.m20;
                m.m21 = -m.m21;
                m.m22 = -m.m22;
                m.m23 = -m.m23;
		    }
            float scale = 1f / split;
            m.m00 = (0.5f * (m.m00 + m.m30) + offset.x * m.m30) * scale;
            m.m01 = (0.5f * (m.m01 + m.m31) + offset.x * m.m31) * scale;
            m.m02 = (0.5f * (m.m02 + m.m32) + offset.x * m.m32) * scale;
            m.m03 = (0.5f * (m.m03 + m.m33) + offset.x * m.m33) * scale;
            m.m10 = (0.5f * (m.m10 + m.m30) + offset.y * m.m30) * scale;
            m.m11 = (0.5f * (m.m11 + m.m31) + offset.y * m.m31) * scale;
            m.m12 = (0.5f * (m.m12 + m.m32) + offset.y * m.m32) * scale;
            m.m13 = (0.5f * (m.m13 + m.m33) + offset.y * m.m33) * scale;
            m.m20 = 0.5f * (m.m20 + m.m30);
            m.m21 = 0.5f * (m.m21 + m.m31);
            m.m22 = 0.5f * (m.m22 + m.m32);
            m.m23 = 0.5f * (m.m23 + m.m33);
            return m;
        }

        public override void Cleanup()
        {
            cmd.ReleaseTemporaryRT(ID_DirShadowAtlas);
            ExecuteCommandBuffer();
        }
    }
}