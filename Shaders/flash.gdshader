shader_type canvas_item;

//
// --- Parameters ---
//
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0; // Red flash control

uniform float fade_amount : hint_range(0.0, 1.0) = 0.0;    // 0 = normal, 1 = fully dissolved
uniform vec4 fade_color : source_color = vec4(0.6, 0.2, 0.8, 1.0); // Purple tint

//
// --- Simple hash function to make pseudo-random noise per pixel ---
//
float hash(vec2 p) {
    // Produces repeatable randomness based on UV position
    return fract(sin(dot(p ,vec2(127.1,311.7))) * 43758.5453123);
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // Step 1: Apply red flash effect
    vec3 flash_mix = mix(tex.rgb, flash_color.rgb, flash_modifier);

    // Step 2: Add purple fade mix
    vec3 faded = mix(flash_mix, fade_color.rgb, fade_amount);

    // Step 3: Generate noisy dissolve threshold (creates scattered pixels)
    float rnd = hash(floor(UV * 128.0));   // adjust 128.0 for pixel grain density
    float mask = step(fade_amount, rnd);   // pixels disappear randomly over time

    // Step 4: Apply dissolve + fade
    COLOR = vec4(faded, tex.a * mask);
}
