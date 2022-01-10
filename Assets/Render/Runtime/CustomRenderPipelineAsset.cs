using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Render
{
    [CreateAssetMenu(menuName = "Rendering/Custom Render Pipeline Asset")]
    public class CustomRenderPipelineAsset : RenderPipelineAsset
    {
        public bool useDynamicBatching  = false;
        public bool useGPUInstancing    = true;
        public bool useSRPBatcher       = true;

        protected override RenderPipeline CreatePipeline()
        {
            return new CustomRenderPipeline(this);
        }
    }
}