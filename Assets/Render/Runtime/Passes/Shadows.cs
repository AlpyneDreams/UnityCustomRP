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
        public const uint MAX_SHADOWED_LIGHTS = 16;
        public const uint MAX_SHADOWED_DIRECTIONAL_LIGHTS = 4;
        public const uint MAX_SHADOW_CASCADES = 4;

        static int
            ID_ShadowAtlas       = Shader.PropertyToID("_ShadowAtlas"),
            ID_ShadowMatrices    = Shader.PropertyToID("_ShadowMatrices"),
            ID_DirShadowAtlas    = Shader.PropertyToID("_DirectionalShadowAtlas"),
            ID_DirShadowMatrices = Shader.PropertyToID("_DirectionalShadowMatrices"),
            ID_CascadeCount      = Shader.PropertyToID("_ShadowCascadeCount"),
            ID_CascadeSpheres    = Shader.PropertyToID("_ShadowCascadeCullingSpheres"),
            ID_CascadeData       = Shader.PropertyToID("_ShadowCascadeData"),
            ID_ShadowAtlasSize   = Shader.PropertyToID("_ShadowAtlasSize"),
            ID_ShadowDistFade    = Shader.PropertyToID("_ShadowDistanceFade"),
            ID_ShadowPancaking   = Shader.PropertyToID("_ShadowPancaking"),
            ID_ShadowTiles       = Shader.PropertyToID("_ShadowTiles");

        static string[] k_ShadowsFilters = {
            "SHADOW_PCF3",
            "SHADOW_PCF5",
            "SHADOW_PCF7"
        };

        static string[] k_DirectionalFilters = {
            "SHADOW_DIRECTIONAL_PCF3",
            "SHADOW_DIRECTIONAL_PCF5",
            "SHADOW_DIRECTIONAL_PCF7"
        };

        struct ShadowLight {
            public int visibleLightIndex;
            public float slopeScaleBias;
            public float normalBias;
        };

        struct ShadowDirLight {
            public int visibleLightIndex;
            public float slopeScaleBias;
            public float nearPlaneOffset;
        };

        Vector4 atlasSizes;
        
        uint shadowLightCount = 0;
        ShadowLight[] shadowLights = new ShadowLight[MAX_SHADOWED_LIGHTS];
        Matrix4x4[] shadowMatrices = new Matrix4x4[MAX_SHADOWED_LIGHTS]; 
        Vector4[] shadowTiles      = new Vector4[MAX_SHADOWED_LIGHTS];

        uint shadowDirLightCount = 0;
        ShadowDirLight[] shadowDirLights = new ShadowDirLight[MAX_SHADOWED_DIRECTIONAL_LIGHTS];
        Matrix4x4[] dirShadowMatrices    = new Matrix4x4[MAX_SHADOWED_DIRECTIONAL_LIGHTS * MAX_SHADOW_CASCADES];
        Vector4[] cascadeCullingSpheres  = new Vector4[MAX_SHADOW_CASCADES];
        Vector4[] cascadeData            = new Vector4[MAX_SHADOW_CASCADES];

        public static bool ShouldCastShadows(Light light) =>
                light.isActiveAndEnabled
            &&  light.shadows != LightShadows.None
            &&  light.shadowStrength > 0f;

        protected override void Setup()
        {
            shadowDirLightCount = shadowLightCount = 0;
        }

        // Return type is ShadowData: strength, tileIndex, ...
        public Vector3 ReserveShadows(Light light, int index)
        {
            if (!ShouldCastShadows(light)) {
                return new Vector3(0f, 0f, 0f);
            }

            shadowLights[shadowLightCount] = new ShadowLight {
                visibleLightIndex = index,
                slopeScaleBias    = light.shadowBias,
                normalBias        = light.shadowNormalBias
            };

            if (shadowLightCount >= MAX_SHADOWED_LIGHTS || !cullingResults.GetShadowCasterBounds(index, out Bounds b)) {
                // Baked shadows only
                return new Vector3(0f, 0f, 0f);//new Vector4(-light.shadowStrength, 0f, 0f, maskChannel);
            }

            return new Vector3(light.shadowStrength, shadowLightCount++, 0f);
        }

        // Return type is DirectionalShadowData: strength, tileIndex, normalBias
        public Vector3 ReserveDirectionalShadows(Light light, int index)
        {
            if (
                shadowDirLightCount < MAX_SHADOWED_DIRECTIONAL_LIGHTS
                && ShouldCastShadows(light)
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

            if (shadowLightCount > 0) {
                RenderShadows();
            } else {
                // Use directional shadow atlas as a dummy
                cmd.SetGlobalTexture(ID_ShadowAtlas, ID_DirShadowAtlas);
            }

            // Set shared shadow parameters
            cmd.SetGlobalVector(ID_ShadowAtlasSize, atlasSizes);
            float cascadeFade = 1f - settings.shadows.directional.cascadeFade;
            cmd.SetGlobalVector(ID_ShadowDistFade, new Vector4(
                1f / settings.shadows.maxDistance,      // Pre-divide for performance
                1f / settings.shadows.distanceFade, 
                1f / (1f - cascadeFade * cascadeFade)   // Using square distance here
            ));
            
            ExecuteCommandBuffer();
        }

        void RenderShadows()
        {
            int atlasSize = (int)settings.shadows.general.atlasSize;
            atlasSizes.z = atlasSize;
            atlasSizes.w = 1f / atlasSize;

            cmd.GetTemporaryRT(ID_ShadowAtlas, atlasSize, atlasSize, 32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap);
            cmd.SetRenderTarget(ID_ShadowAtlas, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            cmd.ClearRenderTarget(true, false, Color.clear);
            cmd.BeginSample(cmd.name);
            ExecuteCommandBuffer();

            uint tiles = shadowLightCount;
            int split = tiles <= 1 ? 1 : (tiles <= 4 ? 2 : 4);
            int tileSize = atlasSize / split;

            for (int index = 0; index < shadowLightCount; index++)
            {
                RenderSpotShadows(index, split, tileSize);
            }
            
            // Set shadow parameters
            cmd.SetGlobalMatrixArray(ID_ShadowMatrices, shadowMatrices);
            cmd.SetGlobalVectorArray(ID_ShadowTiles, shadowTiles);
            SetKeywords(k_ShadowsFilters, (int)settings.shadows.general.filter - 2);
            
            cmd.EndSample(cmd.name);
            ExecuteCommandBuffer();
            
        }

        void RenderSpotShadows(int index, int split, int tileSize)
        {
            ShadowLight light  = shadowLights[index];
            var shadowSettings = new ShadowDrawingSettings(cullingResults, light.visibleLightIndex);
            
            // Compute matrices
            cullingResults.ComputeSpotShadowMatricesAndCullingPrimitives(
                light.visibleLightIndex, out Matrix4x4 view, out Matrix4x4 proj, out ShadowSplitData splitData
            );

            shadowSettings.splitData = splitData;

            // Set Viewport & Matrices
            var offset = SetTileViewport(index, split, tileSize);
            shadowMatrices[index] = GetAtlasMatrix(proj * view, offset, split);
            cmd.SetViewProjectionMatrices(view, proj);

            // Equivalent to SetCascadeData for general lights 
            float texelSize = 2f / (tileSize * proj.m00);
            float filterSize = texelSize * ((int)settings.shadows.general.filter);
            float bias = light.normalBias * filterSize * SQRT2;
            SetTileData(index, bias);

            cmd.SetGlobalDepthBias(0f, light.slopeScaleBias);
            ExecuteCommandBuffer();

            // Draw Shadows
            context.DrawShadows(ref shadowSettings);

            cmd.SetGlobalDepthBias(0f, 0f);
        }

        void RenderDirectionalShadows()
        {
            int atlasSize = (int)settings.shadows.directional.atlasSize;
            atlasSizes.x = atlasSize;
            atlasSizes.y = 1f / atlasSize;

            // Directional lights need shadow pancaking
            cmd.SetGlobalFloat(ID_ShadowPancaking, 1f);

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
            
            // Set directional shadow parameters
            cmd.SetGlobalInt(ID_CascadeCount, unchecked((int)settings.shadows.directional.cascadeCount));
            cmd.SetGlobalVectorArray(ID_CascadeSpheres, cascadeCullingSpheres);
            cmd.SetGlobalVectorArray(ID_CascadeData, cascadeData);
            cmd.SetGlobalMatrixArray(ID_DirShadowMatrices, dirShadowMatrices);
            SetKeywords(k_DirectionalFilters, (int)settings.shadows.directional.filter - 2);
            
            cmd.EndSample(cmd.name);
            ExecuteCommandBuffer();
        }

        void SetKeywords(string[] keywords, int enabled)
        {
            foreach (var (i, keyword) in keywords.Entries()) {
                cmd.SetShaderKeyword(keyword, enabled == i);
            }
        }

        // sqrt(2). Texels are square.
        const float SQRT2 = 1.4142136f;

        void SetCascadeData(int index, Vector4 cullingSphere, float tileSize)
        {
            float texelSize  = 2f * cullingSphere.w / tileSize;
            float filterSize = texelSize * ((int)settings.shadows.directional.filter);
            cullingSphere.w -= filterSize;
            cullingSphere.w *= cullingSphere.w; // Store square radius for efficiency
            cascadeCullingSpheres[index] = cullingSphere;
            cascadeData[index] = new Vector4(1f/cullingSphere.w, filterSize * SQRT2);
        }

        void SetTileData(int index, float bias)
        {
            Vector4 data = Vector4.zero;
            data.w = bias;
            shadowTiles[index] = data;
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
            if (shadowLightCount > 0)
                cmd.ReleaseTemporaryRT(ID_ShadowAtlas);
            ExecuteCommandBuffer();
        }
    }
}