shader_type spatial;
uniform vec4 wood_color : source_color = vec4(0.24, 0.13, 0.065, 1.0);
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	float grain = sin(local_position.x * 62.0 + sin(local_position.z * 7.0) * 2.0);
	float fine = sin(local_position.x * 287.0 + local_position.z * 3.0);
	ALBEDO = wood_color.rgb * (0.92 + 0.06 * grain + 0.02 * fine);
	ROUGHNESS = 0.56;
}
