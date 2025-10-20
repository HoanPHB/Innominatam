shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0); // fade color
uniform float intensity : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	// normalized UV (0..1)
	vec2 uv = UV;
	vec2 center = vec2(0.5, 0.5);
	vec2 delta = uv - center;

	// Swirl rotation matrix (construct using vec2 columns)
	float angle = progress * 6.2831853 * intensity; // 2π * intensity * progress
	float s = sin(angle);
	float c = cos(angle);
	mat2 rot = mat2(vec2(c, s), vec2(-s, c)); // columns: (c, s) and (-s, c)
	delta = rot * delta;

	// distance-based mask (controls where the effect appears)
	float dist = length(delta) * 2.0;
	float mask = smoothstep(progress - 0.25, progress, dist);

	// Mix a colored overlay according to mask. You can invert mixing if you want different look.
	// Here mask goes from 0 (no overlay) to 1 (full overlay color).
	COLOR = mix(vec4(0.0), color, mask);
}
