shader_type canvas_item;

const float FULL_TURN = 6.28318530718;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float radius : hint_range(0.0, 1.0) = 0.5;
uniform vec4 mask_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float distance_to_center = length(centered_uv);
	if (distance_to_center > radius) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		return;
	}

	float angle = atan(centered_uv.x, -centered_uv.y);
	if (angle < 0.0) {
		angle += FULL_TURN;
	}

	float cleared_sweep = clamp(progress, 0.0, 1.0) * FULL_TURN;
	if (angle <= cleared_sweep) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		return;
	}

	COLOR = mask_color;
}
