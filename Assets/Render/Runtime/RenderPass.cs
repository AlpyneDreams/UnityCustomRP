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
    public abstract class RenderPass
    {
        protected CustomRenderPipeline pipeline;
        protected CustomRenderPipelineAsset settings;
        protected RenderContext context;
        protected CullingResults cullingResults;

        protected CommandBuffer cmd;

        public RenderPass()
        {
            cmd = new CommandBuffer { name = GetType().Name };
        }

        protected void ExecuteCommandBuffer()
        {
            context.ExecuteAndClear(cmd);
        }

        public void Setup(RenderPass parent)
        {
            this.pipeline = parent.pipeline;
            this.settings = parent.settings;
            this.context = parent.context;
            this.cullingResults = parent.cullingResults;
            Setup();
        }

        public void Setup(CustomRenderPipeline pipeline, RenderContext context, CullingResults cullingResults)
        {
            this.pipeline = pipeline;
            this.settings = pipeline.settings;
            this.context = context;
            this.cullingResults = cullingResults;
            Setup();
        }

        protected abstract void Setup();
        public abstract void Render();
        public abstract void Cleanup();
    }
}