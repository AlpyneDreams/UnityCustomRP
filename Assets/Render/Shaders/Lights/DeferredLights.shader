Shader "Hidden/Custom/DeferredLights"
{
    Properties
    {
        _GBuffer0 ("", any) = "" {}
        _GBuffer1 ("", any) = "" {}
        _ZBuffer ("", any) = "" {}
    }
    SubShader
    {
        Blend One One // Additive
        Cull Front    // Backfaces Only
        ZWrite Off
        ZTest Off

        HLSLINCLUDE
        #include "../Include/InputModel.hlsl"
        #include "../Include/GBuffer.hlsl"
        #include "../Include/Lighting.hlsl"

        // TODO: Are we correctly sampling these?
        // TODO: Maybe move these samplers into GBuffer.hlsl to make SampleGBuffers simpler?
        sampler2D _GBuffer0;
        sampler2D _GBuffer1;
        sampler2D _ZBuffer;
        
        float4 _LightColor;

        // _LightColor.w contains 1/Range^2
        #define _LightRangeInvSq (_LightColor.w)
    
        // Get the position directly from the matrix
        #define _LightPosition   (UNITY_MATRIX_M._m03_m13_m23)

        // Reverse the effect of scaling by range on the angles (faster than normalizing).
        #define _SpotDirection (-UNITY_MATRIX_M._m02_m12_m22 * sqrt(_LightColor.w))

        // TODO: Could this or something similar work other than for point lights?
        // If so, we could change the use of `* sqrt(_LightColor.w)`
        // in _SpotDirection to `/ _LightRange` for possible perf.
        //#define _LightRange      (UNITY_MATRIX_M._m00)

        struct Varyings {
            float4 position : SV_Position;
            float3 uv       : TEXCOORD0;
        };

        #pragma vertex vert

        Varyings vert(float3 position : POSITION)
        {
            Varyings o;
            o.position = TransformObjectToHClip(position);
            o.uv       = TransformObjectToWorld(position); // FIXME: ideally we could get NDC from HClip
            return o;
        }
        ENDHLSL

        Pass
        {
            Name "PointLight"

            HLSLPROGRAM
            #pragma fragment frag

            float4 frag(Varyings i) : SV_Target
            {
                float2 uv = ComputeNormalizedDeviceCoordinates(i.uv, UNITY_MATRIX_VP);

                GBuffer gbuf    = SampleGBuffers(uv, _GBuffer0, _GBuffer1, _ZBuffer);
                Surface surface = UnpackGBuffer(gbuf);
                BRDF brdf       = GetBRDF(surface);
                Light light     = GetLight(surface, _LightColor, _LightPosition, _LightRangeInvSq);
                
                return float4(DirectLight(surface, brdf, light), 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "SpotLight"

            HLSLPROGRAM
            #pragma fragment frag

            // x: 1/(cos(inner/2) - cos(outer/2)), y: -cos(outer/2)
            float4 _LightData;

            float4 frag(Varyings i) : SV_Target
            {
                float2 uv = ComputeNormalizedDeviceCoordinates(i.uv, UNITY_MATRIX_VP);

                GBuffer gbuf    = SampleGBuffers(uv, _GBuffer0, _GBuffer1, _ZBuffer);
                Surface surface = UnpackGBuffer(gbuf);
                BRDF brdf       = GetBRDF(surface);
                Light light     = GetLight(surface, _LightColor, _LightPosition, _LightRangeInvSq);
                
                float spotAtten = SpotAttenuation(_SpotDirection, light.direction, _LightData.x, _LightData.y);

                if (spotAtten <= 0)
                    discard;

                light.attenuation *= spotAtten;
                
                return float4(DirectLight(surface, brdf, light), 1);
            }
            ENDHLSL

        }
        
    }
}
