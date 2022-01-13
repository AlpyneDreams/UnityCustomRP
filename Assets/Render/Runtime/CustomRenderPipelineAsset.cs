using System;
using System.Linq;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Render
{
    [System.Serializable]
    public class ShadowSettings
    {
        public enum TextureSize {
            _256 = 256, _512 = 512, _1024 = 1024,
            _2048 = 2048, _4096 = 4096, _8192 = 8192
        }

        // Value corresponds to sqrt of number of samples
        // needed by a tent filter using bilinear sampling.
        public enum FilterMode {
            PCF2x2 = 1, PCF3x3, PCF5x5, PCF7x7
        }

        [Min(0f)]
        public float maxDistance = 100f;

        [Range(0.001f, 1f)]
        public float distanceFade = 0.1f;
        
        [System.Serializable]
        public class Directional
        {
            public TextureSize atlasSize = TextureSize._2048;
            public FilterMode filter     = FilterMode.PCF7x7;

            [Range(1, Shadows.MAX_SHADOW_CASCADES)]
            public uint cascadeCount = 4;

            [Range(0f, 1f)]
            public float[] cascadeRatios = {0.1f, 0.25f, 0.5f};

            [Range(0.001f, 1f)]
            public float cascadeFade = 0.1f;
        }
        public Directional directional;
    }

    [CreateAssetMenu(menuName = "Rendering/Custom Render Pipeline Asset")]
    public class CustomRenderPipelineAsset : RenderPipelineAsset
    {
        public bool useDynamicBatching  = false;
        public bool useGPUInstancing    = true;
        public bool useSRPBatcher       = true;

        public ShadowSettings shadows = default;

        protected override RenderPipeline CreatePipeline()
        {
            return new CustomRenderPipeline(this);
        }

        protected override void OnValidate()
        {
            base.OnValidate();

            int cascadeRatios = shadows.directional.cascadeRatios.Length;
            int cascadeCount = (int)shadows.directional.cascadeCount;

            if (cascadeRatios < cascadeCount - 1) {
                Debug.LogWarning("[CRP] Must have at least " + (cascadeCount - 1) + " cascade ratios with " + cascadeCount + " cascades.");                
                shadows.directional.cascadeRatios = new ShadowSettings.Directional().cascadeRatios;
                Array.Resize(ref shadows.directional.cascadeRatios, cascadeCount - 1);
            }
        }
    }
}