// Corpse Glow Shader - Subtle Left to Right Pulsating Glow
// Creates a subtle pulsating effect that moves left to right across corpses

uniform sampler2D u_Tex0;              // Item texture
varying vec2 v_TexCoord;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    
    // Discard fully transparent pixels
    if(texColor.a < 0.05) {
        discard;
    }
    
    // Create a subtle pulsating glow based on X coordinate
    // X: 0 = left edge, 1 = right edge
    
    // Create a sine wave that makes the glow pulse as it goes left to right
    // This creates the illusion of a moving wave
    float glowPulse = sin(v_TexCoord.x * 6.28 + 0.0) * 0.5 + 0.5;  // 0 to 1
    
    // Make it subtle by only using the edges of the material
    // Edges (low alpha in original) will glow more obviously
    float edgeFactor = texColor.a;  // Use texture alpha to modulate
    
    // Very subtle glow intensity - only 0.1 to 0.2 range
    float glowAmount = glowPulse * 0.35 * edgeFactor;  // Max 35% brightness increase
    
    // Subtle green-cyan glow color (increased brightness for visibility)
    vec3 glowColor = vec3(0.2, 0.6, 0.5);  // Teal-green glow
    
    // Additive blend: add glow on top of original
    vec3 finalColor = texColor.rgb + (glowColor * glowAmount);
    
    gl_FragColor = vec4(finalColor, texColor.a);
}
