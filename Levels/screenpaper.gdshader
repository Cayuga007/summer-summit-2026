shader_type canvas_item;
render_mode unshaded;

// Screen texture sampler to read what's rendered underneath
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Your seamless or high-res paper texture
uniform sampler2D paper_texture : repeat_enable, filter_linear;

// Texture scale control
uniform vec2 uv_scale = vec2(1.0, 1.0);

// Paper intensity / blend strength (0.0 = invisible, 1.0 = full effect)
uniform float paper_strength : hint_range(0.0, 1.0) = 0.35;

// Subtle contrast adjustment for the paper grain
uniform float paper_contrast : hint_range(0.5, 3.0) = 1.2;

void fragment() {
    // Read the rendered scene pixels beneath this layer
    vec4 scene_color = texture(screen_texture, SCREEN_UV);
    
    // Sample paper texture using screen coordinates
    vec2 paper_uv = SCREEN_UV * uv_scale;
    vec4 paper_sample = texture(paper_texture, paper_uv);
    
    // Calculate grayscale luminosity and adjust contrast
    float paper_gray = dot(paper_sample.rgb, vec3(0.299, 0.587, 0.114));
    paper_gray = clamp(pow(paper_gray, paper_contrast), 0.0, 1.0);
    
    // Multiply blend mode (simulates pigment soaking into paper fibers)
    vec3 multiplied = scene_color.rgb * vec3(paper_gray);
    
    // Mix the original scene with the multiplied result based on strength
    COLOR.rgb = mix(scene_color.rgb, multiplied, paper_strength);
    COLOR.a = scene_color.a;
}