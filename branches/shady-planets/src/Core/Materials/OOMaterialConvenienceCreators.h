/*

OOMaterialConvenienceCreators.h

Methods for easy creation of materials.

 
Copyright (C) 2007-2012 Jens Ayton

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

#import "OOMaterial.h"

@class OOColor;


@interface OOMaterial (OOConvenienceCreators)

/*	Get a material based on configuration. The result will be an
	OOBasicMaterial, OOSingleTextureMaterial or OOShaderMaterial (the latter
	only if shaders are available). cacheKey is used for caching of synthesized
	shader materials; nil may be passed for no caching.
*/
+ (OOMaterial *) materialWithName:(NSString *)name
						 cacheKey:(NSString *)cacheKey
					configuration:(NSDictionary *)configuration
						   macros:(NSDictionary *)macros
					bindingTarget:(id<OOWeakReferenceSupport>)object
				  forSmoothedMesh:(BOOL)smooth;

/*	Select an appropriate material description (based on availability of
	shaders and content of dictionaries, which may be nil) and call
	+materialWithName:forModelNamed:configuration:macros:bindTarget:forSmoothedMesh:.
*/
+ (OOMaterial *) materialWithName:(NSString *)name
						 cacheKey:(NSString *)cacheKey
			   materialDictionary:(NSDictionary *)materialDict
				shadersDictionary:(NSDictionary *)shadersDict
						   macros:(NSDictionary *)macros
					bindingTarget:(id<OOWeakReferenceSupport>)object
				  forSmoothedMesh:(BOOL)smooth;

@end
