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
        protected Camera camera;

        protected CommandBuffer cmd;

        public RenderPass()
        {
            cmd = new CommandBuffer { name = GetType().Name };
        }

        protected void ExecuteCommandBuffer()
        {
            context.ExecuteAndClear(cmd);
        }

        public void Init(CustomRenderPipeline pipeline)
        {
            this.pipeline = pipeline;
            Init();
        }

        public void Setup(RenderPass parent)
        {
            this.pipeline = parent.pipeline;
            this.settings = parent.settings;
            this.context = parent.context;
            this.cullingResults = parent.cullingResults;
            this.camera = parent.camera;
            Setup();
        }

        public void Setup(RenderContext context)
        {
            if (this.pipeline == null) {
                Debug.LogWarning("RenderPass.Setup called before RenderPass.Init!");
                return;
            }
            this.settings = pipeline.settings;
            this.context = context;
            this.cullingResults = pipeline.cullingResults;
            this.camera = pipeline.camera;
            Setup();
        }

        public void Render(CommandBuffer cmd)
        {
            this.cmd = cmd;
            Render();
        }

        protected virtual void Init() {}
        protected virtual void Setup() {}
        public virtual void Render() {}
        public virtual void Cleanup() {}
    }
}