#pragma once

float square(float x) {
    return x * x;
}

float DistanceSquared(float3 a, float3 b) {
    return dot(a - b, a - b);
}