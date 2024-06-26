#version 330 core

in vec2 texCoords;
in vec3 viewDir;

out vec4 FragColor;

uniform sampler2D ScreenTexture;
uniform sampler2D DepthTexture;
uniform float near;
uniform float far;
uniform vec3 cameraPos;

// Shadow mapping
uniform sampler2D ShadowMap;
uniform mat4 lightMatrix;
uniform float time;
uniform float lightNoise;
uniform int lightSteps;
uniform vec3 lightColor;
uniform float lightShaftIntensity;

float linearizeDepth(float depth)
{
    return (2.0 * near * far) / (far + near - (depth * 2.0 - 1.0) * (far - near));
}

// Used for testing viewDir
float sphereSDF(vec3 p, vec3 center, float radius) {
    return length(p - center) - radius;
}

// Used for testing viewDir
vec3 rayMarch(vec3 ro, vec3 rd, vec3 sphereCenter, float sphereRadius, float depth)
{
    float maxDist = depth; // Maximum distance to march
    float minDist = 0.001; // Minimum distance to consider a hit
    int maxSteps = 100; // Maximum steps to march

    float dist = 0.0;
    for (int i = 0; i < maxSteps; i++) 
    {
        vec3 pos = ro + rd * dist;
        float d = sphereSDF(pos, sphereCenter, sphereRadius);
        if (d < minDist) 
        {
            return vec3(dist / 10.0, 0.0, 0.0);
        }
        dist += d;
        if (dist >= maxDist) 
        {
            break;
        }
    }
    return vec3(0.0, 0.0, 0.0); // Missed the sphere, return black color
}

bool isInShadow(vec4 posLightSpace)
{
    vec3 projCoords = posLightSpace.xyz / posLightSpace.w;
    projCoords = projCoords * 0.5 + 0.5;
    if (projCoords.z > 1.0) return false;

    float lightDepth = texture(ShadowMap, projCoords.xy).r; 
    float currentDepth = projCoords.z;
    float bias = 0.005;
    return currentDepth - bias > lightDepth ? true : false;
}

vec4 getLightShaft(vec3 rayStart, vec3 rayDir, float depth, float offset)
{
    float n = lightSteps;
    float dstLimit = min(100, depth);
    float dstTravelled = offset;
    float stepSize = dstLimit / n;
    
    float lightScattered = 0;
    float absorptionCoefficient = 0.0005;

    while (dstTravelled < dstLimit)
    {
        vec3 rayPos = rayStart + rayDir * dstTravelled;
        vec4 fragPosLightSpace = lightMatrix * vec4(rayPos, 1.0);
        if (!isInShadow(fragPosLightSpace))
        {
            // Beer's law
            float transmittance = exp(-absorptionCoefficient * dstTravelled);
            lightScattered += 0.1 * stepSize * lightShaftIntensity * transmittance;
        }
        dstTravelled += stepSize;
    }
    return vec4(lightColor, lightScattered);
}

float whiteNoise(vec2 coords) 
{
    return fract(sin(dot(coords.xy, vec2(12.9898, 78.233)) + time) * 43758.5453);
}

void main() 
{
    vec4 screenColor = texture(ScreenTexture, texCoords);
    float depth = linearizeDepth(texture(DepthTexture, texCoords).r);
    vec3 rayOrigin = cameraPos;
    vec3 rayDir = normalize(viewDir);
    vec3 worldPos = rayOrigin + rayDir * depth;

    float offset = whiteNoise(texCoords) * lightNoise;
    vec4 lightShaftColor = getLightShaft(rayOrigin, rayDir, depth, offset);
    FragColor = screenColor * (1 - lightShaftColor.a) + vec4(lightShaftColor.rgb, 0) * lightShaftColor.a;
}
