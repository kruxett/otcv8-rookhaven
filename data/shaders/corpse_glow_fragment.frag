// Corpse Glow Shader - Pulsating Glow Effect
// Creates a pulsating glow using mathematical wave patterns (no time dependency)

uniform sampler2D u_Tex0;              // Item texture
varying vec2 v_TexCoord;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    
    // Discard fully transparent pixels
    if(texColor.a < 0.05) {
        discard;
    }
    
    // Create pulsating effect using distance from center
    // This creates concentric rings that naturally appear to pulse
    float dx = v_TexCoord.x - 0.5;
    float dy = v_TexCoord.y - 0.5;
    float distFromCenter = sqrt(dx * dx + dy * dy) * 2.0;  // 0 to ~1.4
    
    // Create pulsating waves using sin of distance
    // Multiple frequencies create complexity
    float pulse1 = sin(distFromCenter * 8.0) * 0.5 + 0.5;           // Fast waves
    float pulse2 = sin(distFromCenter * 3.0 + 1.5) * 0.5 + 0.5;     // Slow waves
    
    // Combine for natural pulsating effect
    float glowPulse = (pulse1 * 0.6 + pulse2 * 0.4);
    
    // Apply stronger glow where pulsing is intense
    float glowAmount = glowPulse * 0.35;  // Keep the 35% we liked
    
    // Subtle green-cyan glow color
    vec3 glowColor = vec3(0.2, 0.6, 0.5);  // Teal-green glow
    
    // Blend: add pulsating glow
    vec3 finalColor = texColor.rgb + (glowColor * glowAmount);
    
    gl_FragColor = vec4(finalColor, texColor.a);
}
