shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 cor : source_color = vec3(0.2, 0.5, 1.0);
uniform float tempo : hint_range(0.0, 100.0) = 0.0;

void fragment() {
    vec2 grid = abs(fract(UV * 40.0 - 0.5) - 0.5) / fwidth(UV * 40.0);
    float linha = min(grid.x, grid.y);
    float glow = 1.0 - smoothstep(0.0, 1.5, linha);
    float pulso = 0.7 + sin(tempo * 2.0 + UV.y * 10.0) * 0.3;
    ALBEDO = cor * glow * pulso * 0.15;
    ALPHA = glow * pulso * 0.15;
}
