shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
uniform vec4 shallow_color : source_color = vec4(0.035, 0.24, 0.32, 1.0);
uniform vec4 deep_color : source_color = vec4(0.015, 0.085, 0.17, 1.0);
uniform float storm_scale : hint_range(0.0, 4.0) = 1.0;
uniform float t = 0.0;
uniform vec2 wind_direction = vec2(1.0,0.0);
uniform float storminess = 0.0;
uniform vec3 waves[4];
varying float crest;
varying vec2 wave_world;
varying float slope_strength;
void vertex() {
    vec2 pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
    vec3 displacement = vec3(0.0);
    for (int i = 0; i < 4; i++) {
        float angle = radians(waves[i].x);
        vec2 dir = vec2(cos(angle), sin(angle));
        float k = 6.2831853 / max(waves[i].z, 0.01);
        float c = sqrt(9.8 / k);
        float wind_alignment = 0.78 + 0.22 * abs(dot(dir, normalize(wind_direction + vec2(0.0001))));
        float amplitude = waves[i].y * storm_scale * wind_alignment;
        float phase = k * (dot(dir, pos) - c * t);
        displacement += vec3(dir.x * amplitude * cos(phase), amplitude * sin(phase), dir.y * amplitude * cos(phase));
    }
    VERTEX += displacement;
    crest = displacement.y;
    wave_world = pos;
    // The mesh's original normals stay flat unless we compute the displaced surface derivatives.
    float dhdx = 0.0;
    float dhdz = 0.0;
    for (int i = 0; i < 4; i++) {
        float angle = radians(waves[i].x);
        vec2 dir = vec2(cos(angle), sin(angle));
        float k = 6.2831853 / max(waves[i].z, 0.01);
        float c = sqrt(9.8 / k);
        float a = waves[i].y * storm_scale * (0.78 + 0.22 * abs(dot(dir, normalize(wind_direction + vec2(0.0001)))));
        float gradient = a * k * cos(k * (dot(dir, pos) - c * t));
        dhdx += dir.x * gradient;
        dhdz += dir.y * gradient;
    }
    NORMAL = normalize(vec3(-dhdx, 1.0, -dhdz));
    slope_strength = length(vec2(dhdx,dhdz));
}
void fragment() {
    float foam = smoothstep(mix(0.36, 0.25, storminess), mix(0.72, 0.47, storminess), crest + slope_strength * 0.65);
    float ripples = sin(UV.x * 830.0 + t * 2.8) * sin(UV.y * 790.0 - t * 3.7);
    foam = max(foam, smoothstep(0.80, 0.99, ripples) * storminess * 0.10);
    float animated_banding = sin(wave_world.x * 0.85 + wave_world.y * 0.34 - t * 1.9) * sin(wave_world.y * 1.15 + t * 1.4);
    ALBEDO = mix(deep_color.rgb, shallow_color.rgb, clamp(0.38 + crest * 0.58 + slope_strength * 0.7 + animated_banding * 0.045, 0.0, 1.0));
    ALBEDO = mix(ALBEDO, vec3(0.7, 0.83, 0.85), foam * 0.45);
    ROUGHNESS = 0.12 + foam * 0.50 + storminess * 0.07;
    METALLIC = 0.04;
}
