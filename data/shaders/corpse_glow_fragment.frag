// Corpse Glow Shader - Subtle Glow Effect
// Provides a base subtle green glow effect on unlooted corpses
// Animation is handled by Lua pulsing the marked color

uniform sampler2D u_Tex0;              // Item texture
varying vec2 v_TexCoord;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    
    // Discard fully transparent pixels
    if(texColor.a < 0.05) {
        discard;
    }
    
    // Create a subtle glow effect based on distance from center
    // This gives unlooted corpses a gentle aura
    
    // Distance from center (0 at center, sqrt(2) at corners)
    float dx = v_TexCoord.x - 0.5;
    float dy = v_TexCoord.y - 0.5;
    float distFromCenter = sqrt(dx * dx + dy * dy);
    
    // Subtle glow: brightest at edges
    float glowAmount = 1.0 - distFromCenter;  // 1.0 in center, 0 at edges
    glowAmount = 1.0 - glowAmount;  // Invert: 0 in center, 1 at edges
    glowAmount = smoothstep(0.0, 1.0, glowAmount) * 0.15;  // Keep very subtle (0.15 max)
    
    // Subtle green glow color
    vec3 glowColor = vec3(0.2, 0.5, 0.35);  // Subtle teal-green
    
    // Blend: add subtle glow
    vec3 finalColor = texColor.rgb + (glowColor * glowAmount);
    
    gl_FragColor = vec4(finalColor, texColor.a);
}
