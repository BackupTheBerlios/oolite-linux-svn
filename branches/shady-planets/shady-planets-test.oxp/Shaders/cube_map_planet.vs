/*
	oolite-tangent-space-vertex.vertex
	Basic vertex shader for Oolite ships using tangent-space effects.
	
	Copyright © 2008 Jens Ayton
	
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

//attribute vec3			tangent;


// No vNormal, because normal is always 0,0,1 in tangent space.
varying vec3			vEyeVector;
varying vec2			vTexCoord;
varying vec3			vLight1Vector;
varying vec3			vCubeTexCoords;


void main(void)
{
/* tangent hacks
vec3 tangent; 
vec3 binormal; 

vec3 normal = normalize( gl_Normal * gl_NormalMatrix );

vec3 c1 = cross( normal , vec3(0.0, 0.0, 1.0) ); 
vec3 c2 = cross( normal , vec3(0.0, 1.0, 0.0) ); 

if( length(c1)>length(c2) )
{
	tangent = c2;	
}
else
{
	tangent = c1;	
}

tangent = normalize(tangent);

binormal = cross(normal, tangent); 
binormal = normalize(binormal);
// end tangent hacks
*/
	// Build tangent basis.
	vec3 n = normalize(gl_NormalMatrix * gl_Normal);
	vec3 b = cross(n, gl_NormalMatrix * vec3(0, 1, 0));
	vec3 t = -cross(n, b);

	// Build tangent basis
//	vec3 n = normalize(gl_NormalMatrix * gl_Normal);
//	vec3 t = normalize(gl_NormalMatrix * tangent);
//	vec3 b = cross(n, t);
	
	mat3 TBN = mat3(t, b, n);
	
	vec3 eyeVector = -vec3(gl_ModelViewMatrix * gl_Vertex);
	vEyeVector = eyeVector * TBN;
	
	vec3 lightVector = gl_LightSource[1].position.xyz;
	vLight1Vector = lightVector * TBN;
	
	vTexCoord = gl_MultiTexCoord0.st;

	vCubeTexCoords = gl_Vertex.xyz;
	gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
