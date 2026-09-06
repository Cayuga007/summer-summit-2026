shader_type particles;


uniform sampler2D sprite_texture : hint_default_black;
uniform vec2 sprite_size = vec2(32.0, 32.0);


uniform float gravity_strength = 350.0;
uniform float spread_horizontal = 40.0;


float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void start() {

    int total_pixels = int(sprite_size.x * sprite_size.y);
    int p_index = int(INDEX) % total_pixels;

    float px = float(p_index % int(sprite_size.x));
    float py = float(p_index / int(sprite_size.x));
    vec2 uv = (vec2(px, py) + 0.5) / sprite_size;


    vec4 col = texture(sprite_texture, uv);


    if (col.a < 0.1) {
        ACTIVE = false;
       
    }

    COLOR = col;


    vec2 local_pos = vec2(px, py) - (sprite_size * 0.5);
    TRANSFORM[3].xy = local_pos;


    float rnd = hash(vec2(px, py));
    VELOCITY.x = (rnd - 0.5) * spread_horizontal;
    
 
    VELOCITY.y = -rnd * 15.0; 
}

void process() {

    VELOCITY.y += gravity_strength * DELTA;


    VELOCITY.x = mix(VELOCITY.x, 0.0, clamp(DELTA * 4.0, 0.0, 1.0));
}