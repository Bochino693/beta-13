shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;

uniform sampler2D albedo : source_color;
uniform float brilho : hint_range(0.0, 2.0) = 1.0;
uniform float tempo : hint_range(0.0, 100.0) = 0.0;

void fragment() {
    vec4 tex = texture(albedo, UV);
    float pulso = 0.92 + sin(tempo * 1.2 + UV.x * 6.283) * 0.08;
    ALBEDO = tex.rgb * brilho * pulso;
    ALPHA = tex.a;
}
