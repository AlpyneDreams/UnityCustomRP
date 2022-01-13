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
    public partial class CustomRenderPipeline : RenderPipeline
    {
        public CustomRenderPipelineAsset settings;

        // Current render context
        Camera          camera;
        CullingResults  cullingResults;

        static ShaderTagId TagDeferred  = new ShaderTagId("Deferred");
        static ShaderTagId TagForward   = new ShaderTagId("Forward");

        static int ID_MatrixInvVP = Shader.PropertyToID("unity_MatrixInvVP");

        RenderGraph renderGraph = new RenderGraph("CRP");

        RTHandle GBuffer0, GBuffer1, ZBuffer, LightBuffer;

        Material DirectionalLight = new Material(Shader.Find("Hidden/Custom/DirectionalLight"));

        Lighting lighting = new Lighting();

        public CustomRenderPipeline(CustomRenderPipelineAsset asset)
        {
            this.settings = asset;
            GraphicsSettings.useScriptableRenderPipelineBatching = settings.useSRPBatcher;

            // This is the total monitor resolution. Don't use Screen.width / Screen.height, they're unreliable.
            var (width, height) = (Screen.currentResolution.width, Screen.currentResolution.height);

            RTHandles.Initialize(width, height);
            RTHandles.SetReferenceSize(width, height);

            GBuffer0    = RTHandles.Alloc(Vector2.one, name: "GBuffer0", dimension: TextureDimension.Tex2D);
            GBuffer1    = RTHandles.Alloc(Vector2.one, name: "GBuffer1", dimension: TextureDimension.Tex2D, colorFormat: GraphicsFormat.R32G32B32A32_SFloat);
            ZBuffer     = RTHandles.Alloc(Vector2.one, name: "DepthStencil", depthBufferBits: DepthBits.Depth32, dimension: TextureDimension.Tex2D);
            LightBuffer = RTHandles.Alloc(Vector2.one, name: "LightBuffer", dimension: TextureDimension.Tex2D);

            InitFullscreenMaterial(DirectionalLight);

            //Debug.Log("GBuffer0: " + GBuffer0.rt.format);

            InitEditor();
        }

        void InitFullscreenMaterial(Material material)
        {
            material.SetTexture("_GBuffer0", GBuffer0);
            material.SetTexture("_GBuffer1", GBuffer1);
            material.SetTexture("_ZBuffer",  ZBuffer);
        }

        // Editor-Only Methods
        partial void InitEditor();
        partial void DrawGizmos(RenderContext context);
        partial void DrawDebug(RenderContext context);

        class PassData
        {
            public TextureHandle output, gbuffer0, gbuffer1;
            public Material material;
        }
        
        protected override void Render(RenderContext context, Camera[] cameras)
        {
            // Render Cameras
            foreach (Camera camera in cameras)
            {
                this.camera = camera;

                // Culling
                if (!camera.TryGetCullingParameters(out var cullParams))
                    return;
                cullParams.shadowDistance = Mathf.Min(settings.shadows.maxDistance, camera.farClipPlane);
                cullingResults = context.Cull(ref cullParams);

                var cmd = new CommandBuffer {name = camera.name};

                cmd.BeginSample(camera.name);
                context.ExecuteAndClear(cmd);

                // Update Lighting Parameters
                lighting.Setup(this, context, cullingResults);

                // Render Shadowmaps
                lighting.shadows.Render();

                cmd.SetRenderTarget(BuiltinRenderTextureType.CameraTarget);
                cmd.ClearRenderTarget(camera.clearFlags, camera.backgroundColor);
                
                cmd.EndSample(camera.name);
                context.ExecuteAndClear(cmd);

                // Update Camera Parameters
                context.SetupCameraProperties(camera);

                // Set inverse matrices
                {
                    Matrix4x4 V, P, IVP;
                    V = camera.worldToCameraMatrix;
                    P = GL.GetGPUProjectionMatrix(camera.projectionMatrix, true);

                    IVP = Matrix4x4.Inverse(P * V);

                    cmd.SetGlobalMatrix(ID_MatrixInvVP, IVP);
                    context.ExecuteAndClear(cmd);
                }

                switch (camera.renderingPath) {
                    default:
                    case RenderingPath.Forward:
                        RenderForward(context, cmd);
                        break;
                    case RenderingPath.DeferredShading:
                        RenderDeferred(context, cmd);
                        break;
                }

                DrawGizmos(context);

                lighting.Cleanup();

                context.Submit();
                cmd.Release();
            }
        }

        void RenderForward(RenderContext context, CommandBuffer cmd)
        {
            cmd.BeginSample(camera.name);
            context.ExecuteAndClear(cmd);

            // Draw Opaque
            DrawOpaque(context, TagForward);

            // Skybox
            DrawSkybox(context);

            // Draw Transparent
            DrawTransparent(context, TagForward);

            cmd.EndSample(camera.name);
            context.ExecuteAndClear(cmd);
        }

        void RenderDeferred(RenderContext context, CommandBuffer cmd)
        {            
            var renderGraphParams = new RenderGraphParameters()
            {
                scriptableRenderContext = context,
                commandBuffer = cmd,
                executionName = camera.name,
                currentFrameIndex = Time.frameCount,
            };

            using (renderGraph.RecordAndExecute(renderGraphParams))
            {
                var backbuffer = renderGraph.ImportBackbuffer(BuiltinRenderTextureType.CameraTarget);

                var gbuffer0 = renderGraph.ImportTexture(GBuffer0);
                var gbuffer1 = renderGraph.ImportTexture(GBuffer1);
                var zbuffer  = renderGraph.ImportTexture(ZBuffer);
                
                // GBuffer Pass
                using (var builder = renderGraph.AddRenderPass<PassData>("MainPass", out var passData))
                {
                    passData.output     = builder.UseColorBuffer(gbuffer0, 0);
                    passData.gbuffer1   = builder.UseColorBuffer(gbuffer1, 1);
                    builder.UseDepthBuffer(zbuffer, DepthAccess.ReadWrite);
                    
                    builder.SetRenderFunc(
                    (PassData data, RenderGraphContext ctx) => 
                    {
                        ctx.cmd.ClearRenderTarget(true, true, Color.clear);
                        ctx.renderContext.ExecuteAndClear(ctx.cmd);

                        DrawOpaque(ctx.renderContext, TagDeferred);
                    });
                }

                // Lights Pass
                /*using (var builder = renderGraph.AddRenderPass<PassData>("FinalBlit", out var passData))
                {
                    passData.gbuffer0 = builder.ReadTexture(gbuffer0);
                    
                    passData.output = builder.UseColorBuffer(backbuffer, 0);

                    passData.material = DirectionalLight;

                    builder.SetRenderFunc(
                    (PassData data, RenderGraphContext ctx) => 
                    {
                        
                    });
                }*/
            }


            cmd.Blit(GBuffer0, LightBuffer);
            cmd.SetRenderTarget(LightBuffer);

            // Draw Directional Lights
            CoreUtils.DrawFullScreen(cmd, DirectionalLight);

            cmd.SetRenderTarget(LightBuffer, ZBuffer);

            cmd.BeginSample(camera.name);
            context.ExecuteAndClear(cmd);

            // Skybox
            DrawSkybox(context);
            
            // Forward Render Transparents
            DrawTransparent(context, TagForward);

            cmd.EndSample(camera.name);

            // Blit to backbuffer
            cmd.Blit(LightBuffer, BuiltinRenderTextureType.CameraTarget);

            context.ExecuteAndClear(cmd);

            // Editor Scene View Draw Modes
            DrawDebug(context);
        }

        void DrawSkybox(RenderContext context)
        {
            if (camera.clearFlags == CameraClearFlags.Skybox && RenderSettings.skybox != null) {
                context.DrawSkybox(camera);
            }
        }

        void DrawOpaque(RenderContext context, ShaderTagId tagID)
        {
            DrawFiltered(context, tagID, SortingCriteria.CommonOpaque, RenderQueueRange.opaque);
        }

        void DrawTransparent(RenderContext context, ShaderTagId tagID)
        {
            DrawFiltered(context, tagID, SortingCriteria.CommonTransparent, RenderQueueRange.transparent);
        }
        
        void DrawFiltered(RenderContext context,
            ShaderTagId tagID, SortingCriteria criteria, RenderQueueRange range
        )
        {
            var sortingSettings = new SortingSettings(camera) { criteria = criteria };
            var drawingSettings = new DrawingSettings(tagID, sortingSettings) {
                    enableDynamicBatching = settings.useDynamicBatching,
                    enableInstancing      = settings.useGPUInstancing,
                    perObjectData         = PerObjectData.ReflectionProbes
            };
            var filteringSettings = new FilteringSettings(range);

            context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
        }
        
        protected override void Dispose(bool disposing)
        {
            base.Dispose(disposing);

            GBuffer0.Release();
            GBuffer1.Release();
            ZBuffer.Release();
            LightBuffer.Release();
            
            renderGraph.Cleanup();
            renderGraph = null;
        }
    }
}