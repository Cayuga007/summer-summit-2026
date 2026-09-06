shader_type canvas_item;

// Normalized hit origin on the button (0.0 to 1.0)
uniform vec2 hit_origin = vec2(0.0, 0.5);

// Elapsed time since impact
uniform float wave_time = 99.0;

// Slime jelly physical parameters
uniform float wave_speed : hint_range(0.5, 6.0) = 2.0;         // Speed of wave spreading
uniform float wave_frequency : hint_range(5.0, 40.0) = 18.0;    // Oscillation ripple rate
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.04;     // Indentation depth
uniform float wave_damping : hint_range(1.0, 15.0) = 6.0;       // Damping absorption rate

void fragment() {
    vec2 uv = UV;
    vec2 diff = uv - hit_origin;
    float dist = length(diff);
    
    // Direction pushing inwards towards the button mass
    vec2 push_dir = (dist > 0.001) ? normalize(diff) : vec2(1.0, 0.0);
    
    // Wavefront arrival time: pixels further away get hit strictly later
    float arrival_time = dist / wave_speed;
    
    vec2 displacement = vec2(0.0);
    
    // STRICT WAVEFRONT CHECK:
    // If the wave has not physically reached this pixel, displacement remains strictly 0
    if (wave_time > arrival_time) {
        float local_time = wave_time - arrival_time;
        float decay = exp(-wave_damping * local_time);
        
        // Negative sign causes initial inward indentation followed by ripples
        float wave = sin(local_time * wave_frequency) * decay * wave_amplitude;
        
        // Attenuate slightly as the wave travels across distance
        wave *= clamp(1.0 - dist * 0.4, 0.2, 1.0);
        
        displacement = -push_dir * wave;
    }
    
    // Sample the entire composited button texture smoothly
    COLOR = texture(TEXTURE, uv + displacement);
}