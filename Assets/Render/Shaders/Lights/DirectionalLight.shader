Shader "Hidden/Custom/DirectionalLight"
{
    Properties
    {
        _AlbedoBuffer ("", any) = "" {}
        _NormalBuffer ("", any) = "" {}
        _DepthBuffer ("", any) = "" {}
    }
    SubShader
    {
        HLSLINCLUDE
        ENDHLSL
        
        Pass
        {
            //Blend DstColor Zero // Multiply
            ZWrite Off
            ZTest Off
            Tags { "LightMode" = "Deferred" }

            HLSLPROGRAM
            #include "../Include/InputCamera.hlsl"
            #include "../Include/Fullscreen.hlsl"
            #include "../Include/Lighting.hlsl"
            #pragma vertex vertFullscreen
            #pragma fragment frag

            sampler2D _AlbedoBuffer;
            sampler2D _NormalBuffer;
            sampler2D _DepthBuffer;

            float4 frag(Varyings i) : SV_TARGET
            {
                Surface surface;
                surface.albedo = tex2D(_AlbedoBuffer, i.uv);
                surface.normal = tex2D(_NormalBuffer, i.uv);

                surface.alpha = 1;
                surface.metallic = 0;
                surface.gloss = 0;

                // TODO: Get viewDirection (or worldPosition) here somehow.
                // Reading from depth buffer is complicated but possible,
                // inverse matrix projection may not be needed to get viewDirection?
                // (i.e. because camera has known pos in view space)
                surface.viewDirection = float3(1, 1, 1);

                return float4(Lighting(surface), 1);
            }

            ENDHLSL

        }
    }
}
