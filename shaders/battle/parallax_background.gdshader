shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D albedo : source_color;
uniform float alpha : hint_range(0.0, 1.0) = 0.85;

void fragment() {
    vec4 tex = texture(albedo, UV);
    ALBEDO = tex.rgb;
    ALPHA = tex.a * alpha;
}
