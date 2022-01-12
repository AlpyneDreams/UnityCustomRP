#pragma once

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

#include "InputCamera.hlsl"

CBUFFER_START(UnityPerDraw)
    float4x4 unity_ObjectToWorld;
    float4x4 unity_WorldToObject;

    float4  unity_LODFade;
    real4   unity_WorldTransformParams;
CBUFFER_END

float4x4 unity_MatrixPreviousM;
float4x4 unity_MatrixPreviousMI;

#define UNITY_MATRIX_M      unity_ObjectToWorld
#define UNITY_MATRIX_I_M    unity_WorldToObject

#define UNITY_PREV_MATRIX_M   unity_MatrixPreviousM
#define UNITY_PREV_MATRIX_I_M unity_MatrixPreviousMI

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
