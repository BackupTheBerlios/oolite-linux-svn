/*
	oolite-default-shader.fragment
	Default fragment shader for Oolite ships.
	
	This is similar to normal ship shaders, but has special controlling
	macros (like OOSTD_DIFFUSE_MAP, OOSTD_SPECULAR etc.) which are specific
	to the default shader.
	
	
	Copyright © 2007–2011 Jens Ayton
	
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:
	
	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.
	
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
*/


#define OOSTD_DIFFUSE_MAP 0


#define OOSTD_DIFFUSE_MAP_IS_CUBE_MAP 0

#ifndef OOSTD_SPECULAR
#define OOSTD_SPECULAR 0
#undef OOSTD_SPECULAR_MAP
#endif

#ifndef OOSTD_SPECULAR_MAP
#define OOSTD_SPECULAR_MAP 0
#endif

#ifndef OOSTD_NORMAL_MAP
#define OOSTD_NORMAL_MAP 0
#endif

#ifndef OOSTD_NORMAL_AND_PARALLAX_MAP
#define OOSTD_NORMAL_AND_PARALLAX_MAP 0
#endif

#ifndef OOSTD_EMISSION
#define OOSTD_EMISSION 0
#endif

#ifndef OOSTD_EMISSION_MAP
#define OOSTD_EMISSION_MAP 0
#endif

#ifndef OOSTD_ILLUMINATION_MAP
#define OOSTD_ILLUMINATION_MAP 0
#endif

#ifndef OOSTD_EMISSION_AND_ILLUMINATION_MAP
#define OOSTD_EMISSION_AND_ILLUMINATION_MAP 0
#endif


#if OOSTD_EMISSION_AND_ILLUMINATION_MAP && !OOSTD_EMISSION_MAP
#undef OOSTD_EMISSION_MAP
#define OOSTD_EMISSION_MAP 1
#endif
#if OOSTD_EMISSION_AND_ILLUMINATION_MAP && OOSTD_ILLUMINATION_MAP
#undef OOSTD_EMISSION_AND_ILLUMINATION_MAP
#define OOSTD_EMISSION_AND_ILLUMINATION_MAP 0
#endif
#if OOSTD_NORMAL_AND_PARALLAX_MAP && !OOSTD_NORMAL_MAP
#undef OOSTD_NORMAL_AND_PARALLAX_MAP
#define OOSTD_NORMAL_AND_PARALLAX_MAP 0
#endif


#define NEED_EYE_VECTOR (OOSTD_SPECULAR || OOSTD_NORMAL_AND_PARALLAX_MAP)

#define HAVE_ILLUMINATION (OOSTD_EMISSION_AND_ILLUMINATION_MAP || OOSTD_ILLUMINATION_MAP)

//attribute vec3                  tangent;
vec3                  tangent;

varying vec3			vEyeVector;


varying vec2			vTexCoord;

varying vec3			vLight1Vector;


varying vec3			vCubeTexCoords;

uniform samplerCube		uDiffuseMap;

uniform samplerCube		uSpecularMap;

uniform samplerCube		uEmissionMap;

uniform samplerCube		uNormalMap;

//uniform samplerCube		uCloudMap;

uniform float			uParallaxScale;
uniform float			uParallaxBias;


vec4 CalcDiffuseLight(in vec3 lightVector, in vec3 normal, in vec4 lightColor)
{

	float intensity = dot(normal, lightVector);
	
	intensity = max(intensity, 0.0);
	intensity = pow( intensity , 3.0 );
	return lightColor * intensity;
}


vec4 CalcSpecularLight(in vec3 lightVector, in vec3 eyeVector, in float exponent, in vec3 normal, in vec4 lightColor)
{

	vec3 reflection = -reflect(lightVector, normal);

	float intensity = dot(reflection, eyeVector);
	intensity = pow(max(intensity, 0.0), exponent);
	return lightColor * intensity;
}






void main(void)
{
	vec4 totalColor = vec4(0);


	
	// Get eye vector
	vec3 eyeVector = normalize(vEyeVector);

	// Get light vectors
	vec3 lightVector = normalize(vLight1Vector);
	vec3 invLightVector = -normalize(vLight1Vector);
	// Get texture coords, using parallax mapping if appropriate
	//
	// float parallax = texture2D(uNormalMap, vTexCoord).a;
	float parallax = textureCube(uNormalMap, vCubeTexCoords).a ;
	parallax *= 0.00;
	//vec3 ParallaxCubeTexCoords =  vCubeTexCoords * ( vec3(1.0,1.0,1.0) - (eyeVector * parallax ) );
	vec3  ParallaxCubeTexCoords =  vCubeTexCoords;
/*
	float cloud_alpha = textureCube(uCloudMap,vCubeTexCoords).a;
	float cloud_parallax =  cloud_alpha * 0.05;
	vec3 CloudParallaxCoords = vCubeTexCoords * ( vec3(1.0,1.0,1.0) - (0.05 * eyeVector) );
	

	cloud_alpha = textureCube(uCloudMap,CloudParallaxCoords).a;

	vec3 CloudShadowTexCoords = vCubeTexCoords * ( vec3(1.0,1.0,1.0) - invLightVector *  0.05 ) ;
	float cloud_shadow = 0.5 + ( 1 - textureCube(uCloudMap,CloudShadowTexCoords).a ) * 0.5 ;
	cloud_shadow = 1.0;
*/

	// Get normal
	vec3 normal = normalize( textureCube(uNormalMap, vCubeTexCoords ).rgb - vec3(0.5)   );
	//const vec3 normal = vec3(0.0, 0.0, 1.0);
	

	
	// Get ambient colour
	vec4 ambientLight = gl_LightModel.ambient;
	
	// Get emission colour
	vec4 emissionColor = vec4(1.0);
	//emissionColor *= gl_FrontMaterial.emission;

	vec4 emissionMapColor = textureCube(uEmissionMap, ParallaxCubeTexCoords);
	emissionColor *= emissionMapColor;

	emissionColor.a = 1.0;
	//totalColor += emissionColor;
	
/*	// Get illumination colour
#if OOSTD_EMISSION_AND_ILLUMINATION_MAP
	// Use alpha channel of emission map as white illumination
	vec4 illuminationMapLight = vec4(emissionMapColor.aaa, 1.0);
#elif OOSTD_ILLUMINATION_MAP
	vec4 illuminationMapLight = texture2D(uIlluminationMap, texCoord);
#endif
#ifdef OOSTD_ILLUMINATION_COLOR
	// OOSTD_ILLUMINATION_COLOR, if defined, is a vec4() declaration.
	illuminationMapLight *= OOSTD_ILLUMINATION_COLOR;
#endif
*/
	
	
	vec4 diffuseLight = vec4(0);
	diffuseLight += CalcDiffuseLight(lightVector, normal, gl_LightSource[1].diffuse);
	vec4 diffuseLightFlat = vec4(0);
	diffuseLightFlat += CalcDiffuseLight(lightVector, vec3(0.0,0.0,1.0) , gl_LightSource[1].diffuse);
	

/*	
	// Get specular parameters
	vec4 specularMapColor = textureCube(uSpecularMap, ParallaxCubeTexCoords);
	float specularExponentLevel = pow(specularMapColor.a, 2.0) + 0.001;
	specularMapColor.a = 1.0;
	#define APPLY_MAPPED_EXPONENT exponent = (exponent - 1.0) * specularExponentLevel + 1.0

	// Calculate specular light

	vec4 specularLight = vec4(0);
	//float exponent = gl_FrontMaterial.shininess;
	//APPLY_MAPPED_EXPONENT;
	float exponent = 3;
	//specularLight += CalcSpecularLight(lightVector, eyeVector, exponent, normal, gl_LightSource[1].specular);
	specularLight += CalcSpecularLight(lightVector, eyeVector, exponent, normal , gl_LightSource[1].specular);

	specularLight.a = 1.0;
*/
	
	vec4 ambientColor = gl_FrontMaterial.ambient;
	vec4 diffuseColor = gl_FrontMaterial.diffuse;

	//vec4 specularColor = gl_FrontMaterial.specular;
	vec4 specularColor = vec4(0.5,0.5,0.5,0.5);
	// modulate the hilight per the specular map color
	//specularColor *= specularMapColor;


	// Parallax modified CubeTexCoords
	vec4 diffuseMapColor = textureCube(uDiffuseMap, ParallaxCubeTexCoords);

	diffuseMapColor.a = 1.0;
	diffuseColor *= diffuseMapColor;
	ambientColor *= diffuseMapColor;

	// dim the emission map on the light side.
	float diffuseLightInvert =  pow(1.0 - diffuseLight.a, 3.0 ) ;
	emissionColor *= diffuseLightInvert;
	

//	totalColor += ambientColor * ambientLight + diffuseColor * diffuseLight * cloud_shadow;
	totalColor += ambientColor * ambientLight + diffuseColor * diffuseLight; 

//	totalColor += specularColor * specularLight;

	totalColor += emissionColor;

	// pseudo alpha composite
	//vec4 cloudcolor = vec4(1.0,1.0,1.0,1.0) * cloud_alpha;	
	//totalColor *= 1-cloud_alpha;
	//totalColor += cloudcolor * (diffuseLightFlat + ambientLight);

	
	gl_FragColor = totalColor;
}
