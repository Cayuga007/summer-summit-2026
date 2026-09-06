shader_type canvas_item;
render_mode unshaded;

// Screen texture sampler to read what's rendered underneath
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Global random offset injected via script for per-level randomization
uniform vec2 global_offset = vec2(0.0);

// 1. Physical Paper Texture
uniform sampler2D paper_texture : repeat_enable, filter_linear;
uniform float uv_scale = 0.002;

// 2. Color Distribution Noise 
uniform sampler2D color_noise : repeat_enable, filter_linear;
uniform float color_noise_scale = 0.0005; 
uniform sampler2D color_gradient;

// Paper intensity and contrast
uniform float paper_strength : hint_range(0.0, 1.0) = 0.45;
uniform float paper_contrast : hint_range(0.5, 3.0) = 1.2;

// Outline properties
uniform vec4 outline_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 2.0;

void fragment() {
    vec4 scene_color = texture(screen_texture, SCREEN_UV);
    
    // Apply the random offset to the global fragment coordinate
    vec2 randomized_coord = FRAGCOORD.xy + global_offset;
    
    // --- Step 1: Process Physical Paper Grain ---
    vec2 paper_uv = randomized_coord * uv_scale;
    vec4 paper_sample = texture(paper_texture, paper_uv);
    float paper_gray = dot(paper_sample.rgb, vec3(0.299, 0.587, 0.114));
    paper_gray = clamp(pow(paper_gray, paper_contrast), 0.0, 1.0);
    
    // --- Step 2: Process Color Distribution ---
    vec2 noise_uv = randomized_coord * color_noise_scale;
    float noise_val = texture(color_noise, noise_uv).r;
    vec3 distributed_color = texture(color_gradient, vec2(noise_val, 0.5)).rgb;
    
    // --- Step 3: Combine Pigment and Grain ---
    vec3 final_pigment = distributed_color * paper_gray;
    vec3 multiplied = scene_color.rgb * final_pigment;
    vec3 final_watercolor_rgb = mix(scene_color.rgb, multiplied, paper_strength);

    // --- Step 4: 8-Tap Outline Detection (Fixes 270-degree corners) ---
    vec2 px = SCREEN_PIXEL_SIZE * outline_width;
    
    // Orthogonal neighbors
    float a_up    = texture(screen_texture, SCREEN_UV + vec2(0.0, -px.y)).a;
    float a_down  = texture(screen_texture, SCREEN_UV + vec2(0.0, px.y)).a;
    float a_left  = texture(screen_texture, SCREEN_UV + vec2(-px.x, 0.0)).a;
    float a_right = texture(screen_texture, SCREEN_UV + vec2(px.x, 0.0)).a;
    
    // Diagonal neighbors
    float a_ul = texture(screen_texture, SCREEN_UV + vec2(-px.x, -px.y)).a;
    float a_ur = texture(screen_texture, SCREEN_UV + vec2(px.x, -px.y)).a;
    float a_dl = texture(screen_texture, SCREEN_UV + vec2(-px.x, px.y)).a;
    float a_dr = texture(screen_texture, SCREEN_UV + vec2(px.x, px.y)).a;

    // Get max alpha from all 8 directions to fully seal corners
    float max_ortho = max(max(a_up, a_down), max(a_left, a_right));
    float max_diag  = max(max(a_ul, a_ur), max(a_dl, a_dr));
    float max_neighbor_a = max(max_ortho, max_diag);

    float is_transparent = step(scene_color.a, 0.1);
    float has_solid_neighbor = step(0.1, max_neighbor_a);
    float outline_mask = is_transparent * has_solid_neighbor;

    COLOR.rgb = mix(final_watercolor_rgb, outline_color.rgb, outline_mask);
    COLOR.a = max(scene_color.a, outline_mask);
}