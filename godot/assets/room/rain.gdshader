shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform bool still = false;
float hash(float n) { return fract(sin(n * 91.7) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float t = still ? 0.0 : TIME * 0.16;
	float lane = floor(uv.x * 110.0);
	float x = fract(uv.x * 110.0);
	float tail = fract(uv.y * (2.0 + hash(lane)) + t * (1.0 + hash(lane + 3.0)) + hash(lane));
	float streak = smoothstep(0.035, 0.0, abs(x - 0.5)) * smoothstep(0.78, 1.0, tail);
	ALBEDO = vec3(0.40, 0.66, 0.72);
	ALPHA = 0.055 + streak * 0.48;
}
