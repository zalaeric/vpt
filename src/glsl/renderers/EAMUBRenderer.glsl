// #part /glsl/shaders/renderers/EAMUB/integrate/vertex

#version 300 es

layout (location = 0) in vec2 aPosition;

out vec2 vPosition;

void main() {
    vPosition = aPosition;
    gl_Position = vec4(aPosition, 0.0, 1.0);
}

// #part /glsl/shaders/renderers/EAMUB/integrate/fragment

#version 300 es
precision mediump float;

#define M_INVPI 0.31830988618
#define M_2PI 6.28318530718
#define EPS 1e-5

// #link /glsl/mixins/Photon
@Photon
// #link /glsl/mixins/rand
@rand
// #link /glsl/mixins/unprojectRand
@unprojectRand
// #link /glsl/mixins/intersectCube
@intersectCube

uniform mediump sampler2D uPosition;
uniform mediump sampler2D uDirection;
uniform mediump sampler2D uTransmittance;
uniform mediump sampler2D uRadiance;

uniform mediump sampler3D uVolume;
uniform mediump sampler2D uTransferFunction;
uniform mediump sampler2D uEnvironment;

uniform mat4 uMvpInverseMatrix;
uniform vec2 uInverseResolution;
uniform float uRandSeed;
uniform float uBlur;

uniform float uAbsorptionCoefficient;
// sipanja NI
// uniform float uScatteringCoefficient;
// uniform float uScatteringBias;
// je pa absorption (zgoraj) in emission:
// uniform float uEmissionCoefficient;
uniform float uMajorant;
uniform uint uMaxBounces;
uniform uint uSteps;

in vec2 vPosition;

layout (location = 0) out vec4 oPosition;
layout (location = 1) out vec4 oDirection;
layout (location = 2) out vec4 oTransmittance;
layout (location = 3) out vec4 oRadiance;

void resetPhoton(inout vec2 randState, inout Photon photon) {
    vec3 from, to;
    unprojectRand(randState, vPosition, uMvpInverseMatrix, uInverseResolution, uBlur, from, to);
    photon.direction = normalize(to - from);
    photon.bounces = 0u;
    vec2 tbounds = max(intersectCube(from, photon.direction), 0.0);
    photon.position = from + tbounds.x * photon.direction;
    photon.transmittance = vec3(1);
}

vec4 sampleEnvironmentMap(vec3 d) {
    vec2 texCoord = vec2(atan(d.x, -d.z), asin(-d.y) * 2.0) * M_INVPI * 0.5 + 0.5;
    return texture(uEnvironment, texCoord);
}

vec4 sampleVolumeColor(vec3 position) {
    vec2 volumeSample = texture(uVolume, position).rg;
    vec4 transferSample = texture(uTransferFunction, volumeSample);
    return transferSample;
}

vec3 randomDirection(vec2 U) {
    float phi = U.x * M_2PI;
    float z = U.y * 2.0 - 1.0;
    float k = sqrt(1.0 - z * z);
    return vec3(k * cos(phi), k * sin(phi), z);
}

float sampleHenyeyGreensteinAngleCosine(float g, float U) {
    float g2 = g * g;
    float c = (1.0 - g2) / (1.0 - g + 2.0 * g * U);
    return (1.0 + g2 - c * c) / (2.0 * g);
}

vec3 sampleHenyeyGreenstein(float g, vec2 U, vec3 direction) {
    // generate random direction and adjust it so that the angle is HG-sampled
    vec3 u = randomDirection(U);
    if (abs(g) < EPS) {
        return u;
    }
    float hgcos = sampleHenyeyGreensteinAngleCosine(g, fract(sin(U.x * 12345.6789) + 0.816723));
    float lambda = hgcos - dot(direction, u);
    return normalize(u + lambda * direction);
}

void main() {
    Photon photon;
    vec2 mappedPosition = vPosition * 0.5 + 0.5;
    photon.position = texture(uPosition, mappedPosition).xyz;
    vec4 directionAndBounces = texture(uDirection, mappedPosition);
    photon.direction = directionAndBounces.xyz;
    photon.bounces = uint(directionAndBounces.w + 0.5);
    photon.transmittance = texture(uTransmittance, mappedPosition).rgb;
    vec4 radianceAndSamples = texture(uRadiance, mappedPosition);
    photon.radiance = radianceAndSamples.rgb;
    photon.samples = uint(radianceAndSamples.w + 0.5);
    //float uAbsorptionCoefficient = volumeSample.a * 

    vec2 r = rand(vPosition * uRandSeed);
    for (uint i = 0u; i < uSteps; i++) {
        r = rand(r);
        float t = -log(r.x) / uMajorant;
        photon.position += t * photon.direction;

        vec4 volumeSample = sampleVolumeColor(photon.position);
        float muAbsorption = volumeSample.a * uAbsorptionCoefficient;
        // float muScattering = volumeSample.a * uScatteringCoefficient;
        // float muEmission = volumeSample.a * uEmissionCoefficient;
        float muMajorant = uMajorant;
        float muNull = muMajorant - muAbsorption;
        float PNull = abs(muNull) / muMajorant;
        float PAbsorption = muAbsorption / muMajorant;
        // float PScattering = muScattering / muMajorant;
        // float PEmission = muEmission / muMajorant;

        if (any(greaterThan(photon.position, vec3(1))) || any(lessThan(photon.position, vec3(0)))) {
            // out of bounds
            // vec4 envSample = sampleEnvironmentMap(photon.direction);
            // vec3 radiance = envSample.rgb; // barva od zadi
            vec3 radiance = vec3(0.0, 0.0, 0.0); 
            photon.samples++;
            photon.radiance += (radiance - photon.radiance) / float(photon.samples);
            resetPhoton(r, photon);
        } else if (r.y < PAbsorption) {

            vec3 radiance = volumeSample.rgb; // barva iz volumna 
            photon.samples++;
            photon.radiance += (radiance - photon.radiance) / float(photon.samples);
            resetPhoton(r, photon);

        } else {

        } /* 
            
            // absorption
            // transmittance is lowered and radiance is lowered?
            // float weightA = muAbsorption / (uMajorant * PAbsorption);
            // photon.transmittance *= 1.0 - weightA;
            // photon.


            else if (photon.bounces >= uMaxBounces) {
            // max bounces achieved -> only estimate transmittance
            // float weightAS = (muAbsorption + muScattering) / uMajorant;
            float weightAS = (muAbsorption + muEmission) / uMajorant;
            photon.transmittance *= 1.0 - weightAS;
        } */ 

        /* else if (r.y < PAbsorption + PScattering) {
            // scattering
            r = rand(r);
            float weightS = muScattering / (uMajorant * PScattering);
            photon.transmittance *= volumeSample.rgb * weightS;
            photon.direction = sampleHenyeyGreenstein(uScatteringBias, r, photon.direction);
            photon.bounces++;
        } * else if (r.y < PAbsorption + PEmission) {
            // emission
            // radiance is added transmittance is added?
            // direction important or no?????
            // r = rand(r);
            float weightE = muEmission / (uMajorant * PEmission);
            photon.transmittance += volumeSample.rgb * weightE;
            photon.radiance += volumeSample.a * uAbsorptionCoefficient;
            // photon.direction = sampleHenyeyGreenstein(uScatteringBias, r, photon.direction);
            // photon.bounces++; // tega ne štejemo, ker gremo od kamere? ali?
        } else {
            // null collision
            // float weightN = muNull / (uMajorant * PNull);
            // photon.transmittance *= weightN;
        } */ 
    }

    oPosition = vec4(photon.position, 0);
    oDirection = vec4(photon.direction, float(photon.bounces));
    oTransmittance = vec4(photon.transmittance, 0);
    oRadiance = vec4(photon.radiance, float(photon.samples));
}

// #part /glsl/shaders/renderers/EAMUB/render/vertex

#version 300 es

layout (location = 0) in vec2 aPosition;
out vec2 vPosition;

void main() {
    vPosition = (aPosition + 1.0) * 0.5;
    gl_Position = vec4(aPosition, 0.0, 1.0);
}

// #part /glsl/shaders/renderers/EAMUB/render/fragment

#version 300 es
precision mediump float;

uniform mediump sampler2D uColor;

in vec2 vPosition;
out vec4 oColor;

void main() {
    oColor = vec4(texture(uColor, vPosition).rgb, 1);
}

// #part /glsl/shaders/renderers/EAMUB/reset/vertex

#version 300 es

layout (location = 0) in vec2 aPosition;

out vec2 vPosition;

void main() {
    vPosition = aPosition;
    gl_Position = vec4(aPosition, 0.0, 1.0);
}

// #part /glsl/shaders/renderers/EAMUB/reset/fragment

#version 300 es
precision mediump float;

// #link /glsl/mixins/Photon
@Photon
// #link /glsl/mixins/rand
@rand
// #link /glsl/mixins/unprojectRand
@unprojectRand
// #link /glsl/mixins/intersectCube
@intersectCube

uniform mat4 uMvpInverseMatrix;
uniform vec2 uInverseResolution;
uniform float uRandSeed;
uniform float uBlur;

in vec2 vPosition;

layout (location = 0) out vec4 oPosition;
layout (location = 1) out vec4 oDirection;
layout (location = 2) out vec4 oTransmittance;
layout (location = 3) out vec4 oRadiance;

void main() {
    Photon photon;
    vec3 from, to;
    vec2 randState = rand(vPosition * uRandSeed);
    unprojectRand(randState, vPosition, uMvpInverseMatrix, uInverseResolution, uBlur, from, to);
    photon.direction = normalize(to - from);
    vec2 tbounds = max(intersectCube(from, photon.direction), 0.0);
    photon.position = from + tbounds.x * photon.direction;
    photon.transmittance = vec3(1);
    photon.radiance = vec3(1); // 0.0 ???????????
    photon.bounces = 0u;
    photon.samples = 0u;
    oPosition = vec4(photon.position, 0);
    oDirection = vec4(photon.direction, float(photon.bounces));
    oTransmittance = vec4(photon.transmittance, 0);
    oRadiance = vec4(photon.radiance, float(photon.samples));
}
