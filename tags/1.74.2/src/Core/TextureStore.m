/*

TextureStore.m

Oolite
Copyright (C) 2004-2010 Giles C Williams and contributors

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

*/

#import "TextureStore.h"
#if !NEW_PLANETS

#import "OOCocoa.h"
#import "OOOpenGL.h"

#import "ResourceManager.h"
#import "legacy_random.h"

#import "OOColor.h"
#import "OOMaths.h"
#import "OOTextureScaling.h"
#import "OOStringParsing.h"
#import "OOTexture.h"
#import "OOGraphicsResetManager.h"

#ifndef NDEBUG
#import "Universe.h"
#import "MyOpenGLView.h"
#endif

#import "OOCollectionExtractors.h"

#define DEBUG_DUMP			(	0	&& !defined(NDEBUG))

#define kOOLogUnconvertedNSLog @"unclassified.TextureStore"


static NSString * const kOOLogPlanetTextureGen			= @"texture.planet.generate";


@interface TextureStore (OOPrivate)

+ (GLuint) getTextureNameFor:(NSString *)fileName inFolder:(NSString *)folderName cubeMapped:(BOOL *)cubeMapped;

@end


#if ALLOW_PROCEDURAL_PLANETS

static void fillSquareImageDataWithCloudTexture(unsigned char * imageBuffer, int width, int nplanes, OOColor* cloudcolor, float impress, float bias);
static void fillSquareImageWithPlanetTex(unsigned char * imageBuffer, int width, int nplanes, float impress, float bias, OOColor* seaColor, OOColor* paleSeaColor, OOColor* landColor, OOColor* paleLandColor);

#endif


static NSMutableDictionary	*textureUniversalDictionary = nil;


@implementation TextureStore


+ (void)resetGraphicsState
{
	// The underlying OOTextures will take care of releasing themselves.
	[textureUniversalDictionary removeAllObjects];
}


+ (GLuint) getTextureNameFor:(NSString *)filename cubeMapped:(BOOL *)cubeMapped
{
	NSParameterAssert(cubeMapped != NULL);
	
	NSDictionary *cached = [textureUniversalDictionary oo_dictionaryForKey:filename];
	if (cached != nil)
	{
		*cubeMapped = [cached oo_boolForKey:@"cubeMap"];
		return [cached oo_intForKey:@"texName"];
	}
	return [TextureStore getTextureNameFor:filename inFolder:@"Textures" cubeMapped:cubeMapped];
}


+ (GLuint) getTextureNameFor:(NSString *)fileName inFolder:(NSString *)folderName cubeMapped:(BOOL *)cubeMapped
{
	OOTexture				*texture = nil;
	NSDictionary			*texProps = nil;
	GLint					texName;
	NSSize					dimensions;
	NSNumber				*texNameObj = nil;
	
	texture = [OOTexture textureWithName:fileName
								inFolder:folderName
								 options:kOOTextureDefaultOptions | kOOTextureAllowCubeMap
							  anisotropy:kOOTextureDefaultAnisotropy
								 lodBias:kOOTextureDefaultLODBias];
	texName = [texture glTextureName];
	if (texName != 0)
	{
		dimensions = [texture dimensions];
		texNameObj = [NSNumber numberWithInt:texName];
		*cubeMapped = [texture isCubeMap];
		
		texProps = [NSDictionary dictionaryWithObjectsAndKeys:
						texNameObj, @"texName",
						[NSNumber numberWithInt:dimensions.width], @"width",
						[NSNumber numberWithInt:dimensions.height], @"height",
						texture, @"OOTexture",
						[NSNumber numberWithBool:*cubeMapped], @"cubeMap",
						nil];
		
		if (textureUniversalDictionary == nil)
		{
			textureUniversalDictionary = [[NSMutableDictionary alloc] init];
			[[OOGraphicsResetManager sharedManager] registerClient:(id <OOGraphicsResetClient>)self];
		}
		
		[textureUniversalDictionary setObject:texProps forKey:fileName];
		[textureUniversalDictionary setObject:fileName forKey:texNameObj];
	}
	return texName;
}


+ (NSString*) getNameOfTextureWithGLuint:(GLuint) value
{
	return (NSString*)[textureUniversalDictionary objectForKey:[NSNumber numberWithInt:value]];
}


+ (NSSize) getSizeOfTexture:(NSString *)filename
{
	NSSize size = NSMakeSize(0.0, 0.0);	// zero size
	if ([textureUniversalDictionary objectForKey:filename])
	{
		size.width = [[(NSDictionary *)[textureUniversalDictionary objectForKey:filename] objectForKey:@"width"] intValue];
		size.height = [[(NSDictionary *)[textureUniversalDictionary objectForKey:filename] objectForKey:@"height"] intValue];
	}
	return size;
}


#if ALLOW_PROCEDURAL_PLANETS


#define PROC_TEXTURE_SIZE	512

+ (BOOL) getPlanetTextureNameFor:(NSDictionary *)planetInfo intoData:(unsigned char **)textureData width:(GLuint *)textureWidth height:(GLuint *)textureHeight
{
	int					texture_h = PROC_TEXTURE_SIZE;
	int					texture_w = PROC_TEXTURE_SIZE;

	int					tex_bytes = texture_w * texture_h * 4;
	
	NSParameterAssert(textureData != NULL && textureWidth != NULL && textureHeight != NULL);
	
	unsigned char *imageBuffer = malloc(tex_bytes);
	if (imageBuffer == NULL)  return NO;
	
	*textureData = imageBuffer;
	*textureWidth = texture_w;
	*textureHeight = texture_h;

	float land_fraction = [[planetInfo objectForKey:@"land_fraction"] floatValue];
	float sea_bias = land_fraction - 1.0;
	
	OOLog(kOOLogPlanetTextureGen, @"genning texture for land_fraction %.5f", land_fraction);
	
	OOColor* land_color = (OOColor*)[planetInfo objectForKey:@"land_color"];
	OOColor* sea_color = (OOColor*)[planetInfo objectForKey:@"sea_color"];
	OOColor* polar_land_color = (OOColor*)[planetInfo objectForKey:@"polar_land_color"];
	OOColor* polar_sea_color = (OOColor*)[planetInfo objectForKey:@"polar_sea_color"];

	// Pale sea colour gives a better transition between land and sea., Backported from the new planets code.
	OOColor* pale_sea_color = [polar_sea_color blendedColorWithFraction:0.45 ofColor:[sea_color blendedColorWithFraction:0.7 ofColor:land_color]];
	
	fillSquareImageWithPlanetTex(imageBuffer, texture_w, 4, 1.0, sea_bias,
		sea_color,
		pale_sea_color,
		land_color,
		polar_land_color);
	
	return YES;
}


+ (BOOL) getCloudTextureNameFor:(OOColor*) color: (GLfloat) impress: (GLfloat) bias intoData:(unsigned char **)textureData width:(GLuint *)textureWidth height:(GLuint *)textureHeight
{
	int					texture_h = PROC_TEXTURE_SIZE;
	int					texture_w = PROC_TEXTURE_SIZE;
	int					tex_bytes;
	
	tex_bytes = texture_w * texture_h * 4;
	
	NSParameterAssert(textureData != NULL && textureWidth != NULL && textureHeight != NULL);
	
	unsigned char *imageBuffer = malloc(tex_bytes);
	if (imageBuffer == NULL)  return NO;
	
	*textureData = imageBuffer;
	*textureWidth = texture_w;
	*textureHeight = texture_h;
	
	fillSquareImageDataWithCloudTexture( imageBuffer, texture_w, 4, color, impress, bias);
	
	return YES;
}

#endif

@end


#if ALLOW_PROCEDURAL_PLANETS

static RANROTSeed sNoiseSeed;
float ranNoiseBuffer[ 128 * 128];

void fillRanNoiseBuffer()
{
	sNoiseSeed = RANROTGetFullSeed();
	
	int i;
	for (i = 0; i < 16384; i++)
		ranNoiseBuffer[i] = randf();
}


static float my_lerp( float v0, float v1, float q)
{
	//float q1 = 0.5 * (1.0 + cosf((q + 1.0) * M_PI));
	//return  v0 * (1.0 - q1) + v1 * q1;
	return (v0 + q * (v1 - v0));
}

static void addNoise(float * buffer, int p, int n, float scale)
{
	int x, y;
	
	float r = (float)p / (float)n;
	for (y = 0; y < p; y++) for (x = 0; x < p; x++)
	{
		int ix = floor( (float)x / r);
		int jx = (ix + 1) % n;
		int iy = floor( (float)y / r);
		int jy = (iy + 1) % n;
		float qx = x / r - ix;
		float qy = y / r - iy;
		ix &= 127;
		iy &= 127;
		jx &= 127;
		jy &= 127;
		float rix = my_lerp( ranNoiseBuffer[iy * 128 + ix], ranNoiseBuffer[iy * 128 + jx], qx);
		float rjx = my_lerp( ranNoiseBuffer[jy * 128 + ix], ranNoiseBuffer[jy * 128 + jx], qx);
		float rfinal = scale * my_lerp( rix, rjx, qy);

		buffer[ y * p + x ] += rfinal;
	}
}


static float q_factor(float* accbuffer, int x, int y, int width, BOOL polar_y_smooth, float polar_y_value, BOOL polar_x_smooth, float polar_x_value, float impress, float bias)
{
	while ( x < 0 ) x+= width;
	while ( y < 0 ) y+= width;
	while ( x >= width ) x-= width;
	while ( y >= width ) y-= width;

	float q = accbuffer[ y * width + x];	// 0.0 -> 1.0

	q *= impress;	// impress
	q += bias;		// + bias

	float polar_y = (2.0f * y - width) / (float) width;
	float polar_x = (2.0f * x - width) / (float) width;
	
	polar_x *= polar_x;
	polar_y *= polar_y;
	
	if (polar_x_smooth)
		q = q * (1.0 - polar_x) + polar_x * polar_x_value;
	if (polar_y_smooth)
		q = q * (1.0 - polar_y) + polar_y * polar_y_value;

	if (q > 1.0)	q = 1.0;
	if (q < 0.0)	q = 0.0;
	
	return q;
}


static void fillSquareImageDataWithCloudTexture(unsigned char * imageBuffer, int width, int nplanes, OOColor* cloudcolor, float impress, float bias)
{
	float accbuffer[width * width];
	int x, y;
	y = width * width;
	for (x = 0; x < y; x++) accbuffer[x] = 0.0f;

	GLfloat rgba[4];
	rgba[0] = [cloudcolor redComponent];
	rgba[1] = [cloudcolor greenComponent];
	rgba[2] = [cloudcolor blueComponent];
	rgba[3] = [cloudcolor alphaComponent];

	int octave = 8;
	float scale = 0.5;
	while (octave < width)
	{
		addNoise( accbuffer, width, octave, scale);
		octave *= 2;
		scale *= 0.5;
	}
	
	float pole_value = (impress * accbuffer[0] - bias < 0.0)? 0.0: 1.0;
	
	for (y = 0; y < width; y++) for (x = 0; x < width; x++)
	{
		float q = q_factor( accbuffer, x, y, width, YES, pole_value, NO, 0.0, impress, bias);
				
		if (nplanes == 1)
			imageBuffer[ y * width + x ] = 255 * q;
		if (nplanes == 3)
		{
			imageBuffer[ 0 + 3 * (y * width + x) ] = 255 * rgba[0] * q;
			imageBuffer[ 1 + 3 * (y * width + x) ] = 255 * rgba[1] * q;
			imageBuffer[ 2 + 3 * (y * width + x) ] = 255 * rgba[2] * q;
		}
		if (nplanes == 4)
		{
			imageBuffer[ 0 + 4 * (y * width + x) ] = 255 * rgba[0];
			imageBuffer[ 1 + 4 * (y * width + x) ] = 255 * rgba[1];
			imageBuffer[ 2 + 4 * (y * width + x) ] = 255 * rgba[2];
			imageBuffer[ 3 + 4 * (y * width + x) ] = 255 * rgba[3] * q;
		}
	}
#if DEBUG_DUMP
	if (nplanes == 4)
	{
		NSString *name = [NSString stringWithFormat:@"atmosphere-%u-%u-old", sNoiseSeed.high, sNoiseSeed.low];
		OOLog(@"planetTex.temp", [NSString stringWithFormat:@"Saving generated texture to file %@.", name]);
		
		[[UNIVERSE gameView] dumpRGBAToFileNamed:name
										   bytes:imageBuffer
										   width:width
										  height:width
										rowBytes:width * 4];
	}
#endif
}

static void fillSquareImageWithPlanetTex(unsigned char * imageBuffer, int width, int nplanes, float impress, float bias,
	OOColor* seaColor,
	OOColor* paleSeaColor,
	OOColor* landColor,
	OOColor* paleLandColor)
{
	float accbuffer[width * width];
	int x, y;
	y = width * width;
	for (x = 0; x < y; x++) accbuffer[x] = 0.0f;

	int octave = 8;
	float scale = 0.5;
	while (octave < width)
	{
		addNoise( accbuffer, width, octave, scale);
		octave *= 2;
		scale *= 0.5;
	}
	
	float pole_value = (impress + bias > 0.5)? 0.5 * (impress + bias) : 0.0;
	
	for (y = 0; y < width; y++) for (x = 0; x < width; x++)
	{
		float q = q_factor( accbuffer, x, y, width, YES, pole_value, NO, 0.0, impress, bias);

		float yN = q_factor( accbuffer, x, y - 1, width, YES, pole_value, NO, 0.0, impress, bias);
		float yS = q_factor( accbuffer, x, y + 1, width, YES, pole_value, NO, 0.0, impress, bias);
		float yW = q_factor( accbuffer, x - 1, y, width, YES, pole_value, NO, 0.0, impress, bias);
		float yE = q_factor( accbuffer, x + 1, y, width, YES, pole_value, NO, 0.0, impress, bias);

		Vector norm = make_vector( 24.0 * (yW - yE), 24.0 * (yS - yN), 2.0);
		
		norm = vector_normal(norm);
		
		GLfloat shade = powf( norm.z, 3.2);
		
		OOColor* color = [OOColor planetTextureColor:q:impress:bias :seaColor :paleSeaColor :landColor :paleLandColor];
		
		float red = [color redComponent];
		float green = [color greenComponent];
		float blue = [color blueComponent];
		
		red *= shade;
		green *= shade;
		blue *= shade;
		
		if (nplanes == 1)
			imageBuffer[ y * width + x ] = 255 * q;
		if (nplanes == 3)
		{
			imageBuffer[ 0 + 3 * (y * width + x) ] = 255 * red;
			imageBuffer[ 1 + 3 * (y * width + x) ] = 255 * green;
			imageBuffer[ 2 + 3 * (y * width + x) ] = 255 * blue;
		}
		if (nplanes == 4)
		{
			imageBuffer[ 0 + 4 * (y * width + x) ] = 255 * red;
			imageBuffer[ 1 + 4 * (y * width + x) ] = 255 * green;
			imageBuffer[ 2 + 4 * (y * width + x) ] = 255 * blue;
			imageBuffer[ 3 + 4 * (y * width + x) ] = 255;
		}
	}
#if DEBUG_DUMP
	if (nplanes == 4)
	{
		OOLog(@"planetTex.temp", [NSString stringWithFormat:@"Saving generated texture to file planet-%u-%u-old.", sNoiseSeed.high, sNoiseSeed.low]);
		
		[[UNIVERSE gameView] dumpRGBAToFileNamed:[NSString stringWithFormat:@"planet-%u-%u-old", sNoiseSeed.high, sNoiseSeed.low]
										   bytes:imageBuffer
										   width:width
										  height:width
										rowBytes:width * 4];
	}
#endif
}

#endif

#endif	// !NEW_PLANETS