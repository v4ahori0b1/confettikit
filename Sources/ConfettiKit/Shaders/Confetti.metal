#include <metal_stdlib>
using namespace metal;

struct ParticleInstance {
    float4 color;
    float2 position;
    float2 size;
    float angle;
    float life;
};

struct VertexOut {
    float4 position [[position]];
    float2 corner;
    float4 color;
};

vertex VertexOut confetti_vertex(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant ParticleInstance *instances [[buffer(0)]],
    constant float2 &viewport [[buffer(1)]]
) {
    // One unit quad expanded into an instanced particle.
    const float2 corners[4] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1)
    };

    ParticleInstance particle = instances[instanceID];
    float2 corner = corners[vertexID];

    float cosine = cos(particle.angle);
    float sine = sin(particle.angle);
    float2 rotated = float2(
        corner.x * cosine - corner.y * sine,
        corner.x * sine + corner.y * cosine
    );

    float2 pixels = particle.position * viewport + rotated * particle.size * 0.5;
    float2 clip = float2(
        pixels.x / viewport.x * 2.0 - 1.0,
        1.0 - pixels.y / viewport.y * 2.0
    );

    VertexOut out;
    out.position = float4(clip, 0.0, 1.0);
    out.corner = rotated;
    out.color = float4(particle.color.rgb, particle.color.a * particle.life);
    return out;
}

fragment float4 confetti_fragment(VertexOut in [[stage_in]]) {
    return in.color;
}
