shader_type particles;

// These default values are completely overwritten by the GDScript at runtime.
uniform sampler2D sprite_texture : hint_default_black;
uniform vec2 sprite_size = vec2(32.0, 32.0); 

// Physics and Collision.
uniform float gravity_strength = 450.0;
uniform float spread_horizontal = 35.0;
uniform vec2 emitter_velocity = vec2(0.0, 0.0);
uniform float inherit_ratio = 1.0;

// Fake floor collision (Distance from center of sprite to the ground).
// Adjust this in the Inspector -> Shader Parameters to match half your character's height.
uniform float floor_y_offset = 16.0; 

uniform float horizontal_damping = 4.0;
uniform float velocity_deadzone = 2.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void start() {
    int total_pixels = int(sprite_size.x * sprite_size.y);
    int p_index = int(INDEX) % total_pixels;

    float px = float(p_index % int(sprite_size.x));
    float py = float(p_index / int(sprite_size.x));

    // Standard UV mapping for individual PNGs.
    vec2 uv = (vec2(px, py) + 0.5) / sprite_size;

    vec4 col = texture(sprite_texture, uv);

    if (col.a >= 0.1) {
        COLOR = col;
        vec2 local_pos = vec2(px, py) - (sprite_size * 0.5);
        TRANSFORM[3].xy = local_pos;

        float rnd = hash(vec2(px, py));
        float h_jitter = (rnd - 0.5) * spread_horizontal;
        vec2 initial_2d = (emitter_velocity * inherit_ratio) + vec2(h_jitter, -rnd * 20.0);
        VELOCITY = vec3(initial_2d.x, initial_2d.y, 0.0);
    } else {
        ACTIVE = false;
    }
}

void process() {
    // Custom floor collision to replace LightOccluder2D.
    if (TRANSFORM[3].y >= floor_y_offset) {
        TRANSFORM[3].y = floor_y_offset;
        VELOCITY = vec3(0.0);
    } else {
        // Still in air: Apply gravity and damping.
        VELOCITY.y += gravity_strength * DELTA;
        VELOCITY.x = mix(VELOCITY.x, 0.0, clamp(DELTA * horizontal_damping, 0.0, 1.0));

        if (length(VELOCITY.xy) < velocity_deadzone) {
            VELOCITY = vec3(0.0);
        }
    }
}