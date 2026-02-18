// Corpse Glow Shader - Subtle Pulsating Glow Effect
// Creates a smooth, time-based pulsating glow on unlooted corpses

uniform sampler2D u_Tex0;              // Item texture
uniform float u_Time;                  // Time uniform (provided by OTCv8)
varying vec2 v_TexCoord;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    
    // Discard fully transparent pixels
    if(texColor.a < 0.05) {
        discard;
    }
    
    // Create a traveling wave that moves left to right across the corpse
    // u_Time makes it travel, v_TexCoord.x adds spatial variation
    float wavePosition = u_Time * 2.0 - v_TexCoord.x * 6.28;
    float wave = sin(wavePosition) * 0.5 + 0.5;  // Normalize to 0-1 range
    
    // Apply wave to glow intensity (15% to 60% range)
    float pulseFactor = wave * 0.45 + 0.15;
    
    // Subtle green-cyan glow color (same as before)
    vec3 glowColor = vec3(0.2, 0.6, 0.5);  // Teal-green
    
    // Additive blend with pulsating intensity
    vec3 finalColor = texColor.rgb + (glowColor * pulseFactor);
    
    gl_FragColor = vec4(finalColor, texColor.a);
}
