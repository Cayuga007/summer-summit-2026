shader_type canvas_item;

// Subtle wave blobbing
uniform float wave_speed : hint_range(0.0, 20.0) = 4.0;
uniform float wave_frequency : hint_range(0.0, 50.0) = 14.0;
uniform float wave_amplitude : hint_range(0.0, 0.02) = 0.003;

// Jitter controls
uniform float jitter_fps : hint_range(1.0, 30.0) = 9.0;
uniform float jitter_amplitude : hint_range(0.0, 0.05) = 0.003;
uniform float jitter_frequency : hint_range(1.0, 50.0) = 20.0;

uniform float hover_amount : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
    float current_time = TIME * wave_speed;
    vec2 sine_offset = vec2(
        sin(UV.y * wave_frequency + current_time),
        cos(UV.x * wave_frequency + current_time * 0.8)
    ) * wave_amplitude;

    float stepped_time = floor(TIME * jitter_fps);
    vec2 grid_uv = floor(UV * jitter_frequency);
    vec2 jitter_offset = vec2(
        hash(grid_uv + vec2(stepped_time, 0.0)) - 0.5,
        hash(grid_uv + vec2(0.0, stepped_time)) - 0.5
    ) * 2.0 * jitter_amplitude;

    vec2 total_ambient = (sine_offset + jitter_offset) * hover_amount;
    COLOR = texture(TEXTURE, UV + total_ambient);
}