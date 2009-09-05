/*

OOShaderProgram.m

Oolite
Copyright (C) 2004-2008 Giles C Williams and contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
MA 02110-1301, USA.


This file may also be distributed under the MIT/X11 license:

Copyright (C) 2007 Jens Ayton

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

#ifndef NO_SHADERS

#import "OOShaderProgram.h"
#import "OOFunctionAttributes.h"
#import "OOStringParsing.h"
#import "ResourceManager.h"
#import "OOOpenGLExtensionManager.h"
#import "OOMacroOpenGL.h"
#import "OOCollectionExtractors.h"


static NSMutableDictionary		*sShaderCache = nil;
static OOShaderProgram			*sActiveProgram = nil;


static BOOL GetShaderSource(NSString *fileName, NSString *shaderType, NSString *prefix, NSString **outResult);
static NSString *GetGLSLInfoLog(GLhandleARB shaderObject);


@interface OOShaderProgram (OOPrivate)

- (id)initWithVertexShaderSource:(NSString *)vertexSource
			fragmentShaderSource:(NSString *)fragmentSource
					prefixString:(NSString *)prefixString
					  vertexName:(NSString *)vertexName
					fragmentName:(NSString *)fragmentName
			   attributeBindings:(NSDictionary *)attributeBindings
							 key:(NSString *)key;

- (void) bindAttributes:(NSDictionary *)attributeBindings;

@end


@implementation OOShaderProgram

+ (id)shaderProgramWithVertexShaderName:(NSString *)vertexShaderName
					 fragmentShaderName:(NSString *)fragmentShaderName
								 prefix:(NSString *)prefixString
					  attributeBindings:(NSDictionary *)attributeBindings
{
	NSString				*cacheKey = nil;
	OOShaderProgram			*result = nil;
	NSString				*vertexSource = nil;
	NSString				*fragmentSource = nil;
	
	if ([prefixString length] == 0)  prefixString = nil;
	
	// Use cache to avoid creating duplicate shader programs -- saves on GPU resources and potentially state changes.
	// FIXME: probably needs to respond to graphics resets.
	cacheKey = [NSString stringWithFormat:@"vertex:%@\nfragment:%@\n----\n%@", vertexShaderName, fragmentShaderName, prefixString ?: (NSString *)@""];
	result = [[sShaderCache objectForKey:cacheKey] pointerValue];
	
	if (result == nil)
	{
		// No cached program; create one...
		if (!GetShaderSource(vertexShaderName, @"vertex", prefixString, &vertexSource))  return nil;
		if (!GetShaderSource(fragmentShaderName, @"fragment", prefixString, &fragmentSource))  return nil;
		result = [[OOShaderProgram alloc] initWithVertexShaderSource:vertexSource
												fragmentShaderSource:fragmentSource
														prefixString:prefixString
														  vertexName:vertexShaderName
														fragmentName:fragmentShaderName
												   attributeBindings:attributeBindings
																 key:cacheKey];
		
		if (result != nil)
		{
			// ...and add it to the cache
			[result autorelease];
			if (sShaderCache == nil)  sShaderCache = [[NSMutableDictionary alloc] init];
			[sShaderCache setObject:[NSValue valueWithPointer:result] forKey:cacheKey];	// Use NSValue so dictionary doesn't retain program
		}
	}
	
	return result;
}


- (void)dealloc
{
	OO_ENTER_OPENGL();
	
#ifndef NDEBUG
	if (EXPECT_NOT(sActiveProgram == self))
	{
		OOLog(@"shader.dealloc.imbalance", @"***** OOShaderProgram deallocated while active, indicating a retain/release imbalance. Expect imminent crash.");
		[OOShaderProgram applyNone];
	}
#endif
	
	if (key != nil)
	{
		[sShaderCache removeObjectForKey:key];
		[key release];
	}
	
	glDeleteObjectARB(program);
	
	[super dealloc];
}


- (void)apply
{
	OO_ENTER_OPENGL();
	
	if (sActiveProgram != self)
	{
		[sActiveProgram release];
		sActiveProgram = [self retain];
		glUseProgramObjectARB(program);
	}
}


+ (void)applyNone
{
	OO_ENTER_OPENGL();
	
	if (sActiveProgram != nil)
	{
		[sActiveProgram release];
		sActiveProgram = nil;
		glUseProgramObjectARB(NULL_SHADER);
	}
}


- (GLhandleARB)program
{
	return program;
}

@end


@implementation OOShaderProgram (OOPrivate)

- (id)initWithVertexShaderSource:(NSString *)vertexSource
			fragmentShaderSource:(NSString *)fragmentSource
					prefixString:(NSString *)prefixString
					  vertexName:(NSString *)vertexName
					fragmentName:(NSString *)fragmentName
			   attributeBindings:(NSDictionary *)attributeBindings
							 key:(NSString *)inKey
{
	BOOL					OK = YES;
	const GLcharARB			*sourceStrings[2] = { "", NULL };
	GLint					compileStatus;
	GLhandleARB				vertexShader = NULL_SHADER;
	GLhandleARB				fragmentShader = NULL_SHADER;
	
	OO_ENTER_OPENGL();
	
	self = [super init];
	if (self == nil)  OK = NO;
	
	if (OK && vertexSource == nil && fragmentSource == nil)  OK = NO;	// Must have at least one shader!
	
	if (OK && prefixString != nil)
	{
		sourceStrings[0] = [prefixString UTF8String];
	}
	
	if (OK && vertexSource != nil)
	{
		// Compile vertex shader.
		vertexShader = glCreateShaderObjectARB(GL_VERTEX_SHADER_ARB);
		if (vertexShader != NULL_SHADER)
		{
			sourceStrings[1] = [vertexSource UTF8String];
			glShaderSourceARB(vertexShader, 2, sourceStrings, NULL);
			glCompileShaderARB(vertexShader);
			
			glGetObjectParameterivARB(vertexShader, GL_OBJECT_COMPILE_STATUS_ARB, &compileStatus);
			if (compileStatus != GL_TRUE)
			{
				OOLog(@"shader.compile.vertex.failure", @"***** GLSL %s shader compilation failed for %@:\n>>>>> GLSL log:\n%@\n", "vertex", vertexName, GetGLSLInfoLog(vertexShader));
				OK = NO;
			}
		}
		else  OK = NO;
	}
	
	if (OK && fragmentSource != nil)
	{
		// Compile fragment shader.
		fragmentShader = glCreateShaderObjectARB(GL_FRAGMENT_SHADER_ARB);
		if (fragmentShader != NULL_SHADER)
		{
			sourceStrings[1] = [fragmentSource UTF8String];
			glShaderSourceARB(fragmentShader, 2, sourceStrings, NULL);
			glCompileShaderARB(fragmentShader);
			
			glGetObjectParameterivARB(fragmentShader, GL_OBJECT_COMPILE_STATUS_ARB, &compileStatus);
			if (compileStatus != GL_TRUE)
			{
				OOLog(@"shader.compile.fragment.failure", @"***** GLSL %s shader compilation failed for %@:\n>>>>> GLSL log:\n%@\n", "fragment", fragmentName, GetGLSLInfoLog(fragmentShader));
				OK = NO;
			}
		}
		else  OK = NO;
	}
	
	if (OK)
	{
		// Link shader.
		program = glCreateProgramObjectARB();
		if (program != NULL_SHADER)
		{
			if (vertexShader != NULL_SHADER)  glAttachObjectARB(program, vertexShader);
			if (fragmentShader != NULL_SHADER)  glAttachObjectARB(program, fragmentShader);
			[self bindAttributes:attributeBindings];
			glLinkProgramARB(program);
			
			glGetObjectParameterivARB(program, GL_OBJECT_LINK_STATUS_ARB, &compileStatus);
			if (compileStatus != GL_TRUE)
			{
				OOLog(@"shader.link.failure", @"***** GLSL shader linking failed:\n>>>>> GLSL log:\n%@\n", GetGLSLInfoLog(program));
				OK = NO;
			}
		}
		else  OK = NO;
	}
	
	if (OK)
	{
		key = [inKey copy];
	}
	
	if (vertexShader != NULL_SHADER)  glDeleteObjectARB(vertexShader);
	if (fragmentShader != NULL_SHADER)  glDeleteObjectARB(fragmentShader);
	
	if (!OK)
	{
		if (program != NULL_SHADER)  glDeleteObjectARB(program);
		
		[self release];
		self = nil;
	}
	return self;
}


- (void) bindAttributes:(NSDictionary *)attributeBindings
{
	OO_ENTER_OPENGL();
	
	NSString				*attrKey = nil;
	NSEnumerator			*keyEnum = nil;
	
	for (keyEnum = [attributeBindings keyEnumerator]; (attrKey = [keyEnum nextObject]); )
	{
		glBindAttribLocationARB(program, [attributeBindings unsignedIntForKey:attrKey], [attrKey UTF8String]);	
	}
}

@end


/*	Attempt to load fragment or vertex shader source from a file.
	Returns YES if source was loaded or no shader was specified, and NO if an
	external shader was specified but could not be found.
*/
static BOOL GetShaderSource(NSString *fileName, NSString *shaderType, NSString *prefix, NSString **outResult)
{
	NSString				*result = nil;
	NSArray					*extensions = nil;
	NSEnumerator			*extEnum = nil;
	NSString				*extension = nil;
	NSString				*nameWithExtension = nil;
	
	if (fileName == nil)  return YES;	// It's OK for one or the other of the shaders to be undefined.
	
	result = [ResourceManager stringFromFilesNamed:fileName inFolder:@"Shaders"];
	if (result == nil)
	{
		extensions = [NSArray arrayWithObjects:shaderType, [shaderType substringToIndex:4], nil];	// vertex and vert, or fragment and frag
		
		// Futureproofing -- in future, we may wish to support automatic selection between supported shader languages.
		if (![fileName pathHasExtensionInArray:extensions])
		{
			for (extEnum = [extensions objectEnumerator]; (extension = [extEnum nextObject]); )
			{
				nameWithExtension = [fileName stringByAppendingPathExtension:extension];
				result = [ResourceManager stringFromFilesNamed:nameWithExtension
													  inFolder:@"Shaders"];
				if (result != nil) break;
			}
		}
		if (result == nil)
		{
			OOLog(kOOLogFileNotFound, @"GLSL ERROR: failed to find fragment program %@.", fileName);
			return NO;
		}
	}
	/*	
	if (result != nil && prefix != nil)
	{
		result = [prefix stringByAppendingString:result];
	}
	*/
	if (outResult != NULL) *outResult = result;
	return YES;
}


static NSString *GetGLSLInfoLog(GLhandleARB shaderObject)
{
	GLint					length;
	GLcharARB				*log = NULL;
	NSString				*result = nil;
	
	OO_ENTER_OPENGL();
	
	if (EXPECT_NOT(shaderObject == NULL_SHADER))  return nil;
	
	glGetObjectParameterivARB(shaderObject, GL_OBJECT_INFO_LOG_LENGTH_ARB, &length);
	log = malloc(length);
	if (log == NULL)
	{
		length = 1024;
		log = malloc(length);
		if (log == NULL)  return @"<out of memory>";
	}
	glGetInfoLogARB(shaderObject, length, NULL, log);
	
	result = [NSString stringWithUTF8String:log];
	if (result == nil)  result = [[[NSString alloc] initWithBytes:log length:length - 1 encoding:NSISOLatin1StringEncoding] autorelease];
	return result;
}

#endif // NO_SHADERS