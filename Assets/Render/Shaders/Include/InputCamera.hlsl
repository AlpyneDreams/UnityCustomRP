#ifndef _INPUT_CAMERA_HLSL
#define _INPUT_CAMERA_HLSL

float4x4 unity_MatrixVP;
float4x4 unity_MatrixV;
float4x4 glstate_matrix_projection;

#define UNITY_MATRIX_V      unity_MatrixV
#define UNITY_MATRIX_VP     unity_MatrixVP
#define UNITY_MATRIX_P      glstate_matrix_projection

float3 _WorldSpaceCameraPos;

#endif