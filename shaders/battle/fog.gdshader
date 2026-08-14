shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 cor : source_color = vec3(0.4, 0.6, 0.9);
uniform float tempo : hint_range(0.0, 100.0) = 0.0;
uniform float densidade : hint_range(0.0, 1.0) = 0.5;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 uv = UV * 3.0;
    float n = noise(uv + tempo * 0.15) * 0.5 + noise(uv * 2.0 - tempo * 0.08) * 0.25;
    float mask = smoothstep(0.2, 0.8, n) * densidade;
    ALBEDO = cor * mask;
    ALPHA = mask * 0.35;
}
