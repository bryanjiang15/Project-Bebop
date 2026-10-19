shader_type canvas_item;

uniform sampler2D team_mask;
uniform vec4 team_color : source_color = vec4(1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float m = texture(team_mask, UV).a;
	c.rgb = mix(c.rgb, clamp(c.rgb * team_color.rgb * (255.0 / 184.0), 0.0, 1.0), m);
	COLOR = c;
}
