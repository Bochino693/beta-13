shader_type canvas_item;

uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform float aura_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 aura_color : source_color = vec4(0.4, 0.95, 1.0, 0.9);
uniform float pulse_speed : hint_range(0.2, 3.0) = 1.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec2 px = TEXTURE_PIXEL_SIZE * 3.0;
	float around = 0.0;
	around = max(around, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	around = max(around, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	around = max(around, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	around = max(around, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	around = max(around, texture(TEXTURE, UV + px).a);
	around = max(around, texture(TEXTURE, UV - px).a);
	float pulse = 0.78 + sin(TIME * 6.28318530718 * pulse_speed) * 0.22;
	float edge = max(around - base.a, 0.0) * aura_strength * pulse;
	vec3 lit = base.rgb + aura_color.rgb * edge;
	lit = mix(lit, vec3(1.0), hit_flash * base.a);
	COLOR = vec4(lit, max(base.a, edge * aura_color.a));
}
