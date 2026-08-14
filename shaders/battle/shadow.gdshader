shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_never;

uniform float alpha : hint_range(0.0, 1.0) = 0.36;

void fragment() {
    vec2 p = (UV - vec2(0.5)) * vec2(1.0, 2.55);
    float mask = 1.0 - smoothstep(0.15, 0.50, length(p));
    ALBEDO = vec3(0.003, 0.005, 0.016);
    ALPHA = mask * alpha;
}
