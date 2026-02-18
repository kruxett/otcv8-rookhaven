// Corpse Glow Shader - Left to Right Pulsating Glow Effect
// Creates a pulsating wave that travels across the corpse from left to right

uniform sampler2D u_Tex0;              // Item texture
varying vec2 v_TexCoord;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    
    // Discard fully transparent pixels
    if(texColor.a < 0.05) {
        discard;
    }
    
    // Create pulsating wave across X axis (left to right)
    // v_TexCoord.x goes from 0 (left) to 1 (right)
    
    // Create multiple wave frequencies for a complex pulsating effect
    float wave1 = sin(v_TexCoord.x * 6.28) * 0.5 + 0.5;           // One full wave across width
    float wave2 = sin(v_TexCoord.x * 3.14 + 1.57) * 0.5 + 0.5;    // Half wave, offset
    
    // Also add a subtle vertical component to affect whole corpse
    float verticalInfluence = sin(v_TexCoord.y * 3.14) * 0.2 + 0.8;  // Reduces at top/bottom
    
    // Combine waves for natural pulsating look
    float glowPulse = (wave1 * 0.6 + wave2 * 0.4) * verticalInfluence;
    
    // Apply glow intensity
    float glowAmount = glowPulse * 0.35;  // Keep the 35% we liked
    
    // Subtle green-cyan glow color
    vec3 glowColor = vec3(0.2, 0.6, 0.5);  // Teal-green glow
    
    // Blend: add pulsating glow
    vec3 finalColor = texColor.rgb + (glowColor * glowAmount);
    
    gl_FragColor = vec4(finalColor, texColor.a);
}
