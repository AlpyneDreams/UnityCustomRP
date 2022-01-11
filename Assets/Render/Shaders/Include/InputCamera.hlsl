#ifndef _INPUT_CAMERA_HLSL
#define _INPUT_CAMERA_HLSL

float3 _WorldSpaceCameraPos;

float4x4 unity_MatrixVP;
float4x4 unity_MatrixV;
float4x4 glstate_matrix_projection;

#define UNITY_MATRIX_V      unity_MatrixV
#define UNITY_MATRIX_VP     unity_MatrixVP
#define UNITY_MATRIX_P      glstate_matrix_projection

/// Inverse matrices ///

float4x4 unity_MatrixInvVP;

#define UNITY_MATRIX_I_VP   unity_MatrixInvVP

#endif