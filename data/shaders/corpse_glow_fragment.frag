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
    
    // Create smooth pulsation using sine wave
    // u_Time increases continuously, creating smooth animation
    // Pulse between 0.25 and 0.45 (25%-45% glow intensity)
    // Speed of 0.5 rad/sec = ~1.26 second cycle
    float pulseFactor = sin(u_Time * 0.5) * 0.1 + 0.35;  // Range: 0.25 to 0.45
    
    // Subtle green-cyan glow color (same as before)
    vec3 glowColor = vec3(0.2, 0.6, 0.5);  // Teal-green
    
    // Additive blend with pulsating intensity
    vec3 finalColor = texColor.rgb + (glowColor * pulseFactor);
    
    gl_FragColor = vec4(finalColor, texColor.a);
}
