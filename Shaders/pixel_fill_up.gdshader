shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float pixel_size : hint_range(1.0, 32.0) = 4.0;
uniform vec4 color_light : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_dark  : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;

float hash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p.x + p.y) * 43758.5453123);
}

void fragment() {
	vec2 screen_size = vec2(textureSize(screen_tex, 0));
	vec2 pixel_uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float rand_val = hash(pixel_uv * 50.0);
	float y = pixel_uv.y;

	float threshold = 1.0 - progress;
	float noisy_threshold = threshold - rand_val * 0.2;
	float visible = step(noisy_threshold, y);

	// gradient only between dark and light tones, no colors
	vec4 grad_color = mix(color_dark, color_light, y);

	// slightly add dynamic grain to make pixels feel alive
	float grain = hash(UV * screen_size * 5.0 + TIME) * 0.1;
	grad_color.rgb += grain;

	COLOR = vec4(grad_color.rgb, visible * grad_color.a);
}
