// Corpse Glow Shader - Upward Wave Effect
// Creates a visible wave that travels from bottom to top
// This effect is ONLY possible with a shader, not with color marking

uniform sampler2D u_Tex0;              // Item texture
varying vec2 v_TexCoord;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    
    // Discard fully transparent pixels
    if(texColor.a < 0.05) {
        discard;
    }
    
    // Create visible wave bands that travel upward
    // Y coordinate: 0 = top, 1 = bottom
    // We invert Y (1 - v_TexCoord.y) so wave travels from bottom to top
    
    float waveY = 1.0 - v_TexCoord.y;  // Flip Y so bottom = 1, top = 0
    
    // Create repeating wave pattern (3 full cycles across texture)
    float wavePattern = sin(waveY * 6.28 * 3.0) * 0.5 + 0.5;  // 0 to 1
    
    // Add a static underlying glow
    float baseGlow = 1.0 - waveY;  // Brightest at top (where wave starts)
    
    // Combine wave + base glow
    float totalGlow = (wavePattern * 0.4) + (baseGlow * 0.3);
    
    // Only glow where texture is opaque enough
    totalGlow *= texColor.a;
    totalGlow = clamp(totalGlow, 0.0, 0.6);  // Cap at 0.6 (not too bright)
    
    // Green-cyan glow color
    vec3 glowColor = vec3(0.0, 0.8, 0.6);  // Bright cyan-green
    
    // Blend with original texture
    vec3 finalColor = texColor.rgb + (glowColor * totalGlow);
    
    gl_FragColor = vec4(finalColor, texColor.a);
}
