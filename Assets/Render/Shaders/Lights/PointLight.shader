Shader "Hidden/Custom/PointLight"
{
    Properties
    {
        _GBuffer0 ("", any) = "" {}
        _GBuffer1 ("", any) = "" {}
        _ZBuffer ("", any) = "" {}
    }
    SubShader
    {
        HLSLINCLUDE
        ENDHLSL
        
        Pass
        {
            Blend One One // Additive
            Cull Front
            ZWrite Off
            ZTest Off

            HLSLPROGRAM
            #include "../Include/InputModel.hlsl"
            #include "../Include/GBuffer.hlsl"
            #include "../Include/Lighting.hlsl"
            #pragma vertex vert
            #pragma fragment frag

            // TODO: Are we correctly sampling these?
            // TODO: Maybe move these samplers into GBuffer.hlsl to make SampleGBuffers simpler?
            sampler2D _GBuffer0;
            sampler2D _GBuffer1;
            sampler2D _ZBuffer;
            
            // _LightColor.a contains 1/Range^2
            float4 _LightColor;

            struct Varyings {
                float4 position : SV_Position;
                float3 uv       : TEXCOORD0;
            };

            Varyings vert(float3 position : POSITION)
            {
                Varyings o;
                o.position = TransformObjectToHClip(position);
                o.uv = TransformObjectToWorld(position);

                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float2 uv = ComputeNormalizedDeviceCoordinates(i.uv, UNITY_MATRIX_VP);

                GBuffer gbuf = SampleGBuffers(uv, _GBuffer0, _GBuffer1, _ZBuffer);
                Surface surface = UnpackGBuffer(gbuf);
                BRDF brdf = GetBRDF(surface);

                float3 lightPos = UNITY_MATRIX_M._m03_m13_m23;
                float range = UNITY_MATRIX_M._m00;
                float3 ray = lightPos - surface.position;
                float3 lightDir = normalize(ray);
                float ndotl = dot(lightDir, surface.normal);

                float distSq = max(dot(ray, ray), 0.00001);

                Light light;
                light.color = _LightColor;
                light.direction = lightDir;
                float rangeAtten = square(saturate(1 - square(distSq * _LightColor.a)));
                light.attenuation = rangeAtten / distSq;
                
                return float4(Lighting(surface, brdf, light), 1);
            }

            ENDHLSL

        }
    }
}
