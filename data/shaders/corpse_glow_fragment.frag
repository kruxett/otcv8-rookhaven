// Corpse Glow Shader - Pulsing Glow Effect
// Creates a subtle left-to-right pulsing wave effect on unlooted corpses

uniform vec4 u_GlowColor;              // Glow color (RGBA)
uniform float u_Time;                  // Time in seconds for animation
uniform float u_PulseSpeed;            // Speed of pulse wave (1.0 = default, higher = faster)
uniform float u_PulseIntensity;        // Intensity of pulse (0.0 to 1.0)
uniform int u_PulseDirection;          // Direction: 0=left-to-right, 1=right-to-left, 2=top-to-bottom, 3=bottom-to-top
uniform sampler2D u_Tex0;              // Item texture
varying vec2 v_TexCoord;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    
    // Discard fully transparent pixels
    if(texColor.a < 0.05) {
        discard;
    }
    
    // Calculate pulse based on direction
    float pulse = 0.0;
    float wave = sin(u_Time * u_PulseSpeed * 3.0) * 0.5 + 0.5; // Oscillates between 0 and 1
    
    if(u_PulseDirection == 0) {
        // Left to right: pulse based on X coordinate
        pulse = fract(v_TexCoord.x + wave);
    } else if(u_PulseDirection == 1) {
        // Right to left: pulse based on X coordinate (reversed)
        pulse = fract((1.0 - v_TexCoord.x) + wave);
    } else if(u_PulseDirection == 2) {
        // Top to bottom: pulse based on Y coordinate
        pulse = fract(v_TexCoord.y + wave);
    } else {
        // Bottom to top: pulse based on Y coordinate (reversed)
        pulse = fract((1.0 - v_TexCoord.y) + wave);
    }
    
    // Create a smooth gradient wave that fades in and out
    float gradientWidth = 0.3; // Width of the pulse gradient
    float gradientFalloff = smoothstep(0.0, gradientWidth, pulse) - smoothstep(gradientWidth, gradientWidth * 2.0, pulse);
    
    // Apply glow intensity and modulate by texture alpha
    float glowIntensity = u_PulseIntensity * gradientFalloff * 0.7; // 0.7 = base brightness
    
    // Combine original texture with glow
    vec4 glowColor = u_GlowColor;
    glowColor.a *= glowIntensity;
    
    // Composite: original item + additive glow layer
    gl_FragColor = texColor + glowColor;
    
    // Ensure alpha channel respects original texture
    gl_FragColor.a = mix(texColor.a, 1.0, glowIntensity * 0.3);
}
