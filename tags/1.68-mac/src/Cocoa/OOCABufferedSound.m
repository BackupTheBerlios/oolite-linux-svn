/*

OOCABufferedSound.m

OOCASound - Core Audio sound implementation for Oolite.
Copyright (C) 2005-2006 Jens Ayton

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

#import "OOCASoundInternal.h"
#import "OOCASoundDecoder.h"


@interface OOCABufferedSound (Private)

- (BOOL)bufferSound:(NSString *)inPath;

@end


@implementation OOCABufferedSound

#pragma mark NSObject

- (void)dealloc
{
	if (_bufferL) free(_bufferL);
	if (_stereo) _bufferR = NULL;
	else if (_bufferR) free(_bufferR);
	
	[super dealloc];
}


- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %p>{\"%@\", %s, %g Hz, %u bytes}", [self className], self, [self name], _stereo ? "stereo" : "mono", _sampleRate, _size * sizeof (float) * (_stereo ? 2 : 1)];
}


#pragma mark OOSound

- (NSString *)name
{
	return _name;
}


- (void)play
{
	[[OOCASoundMixer mixer] playSound:self];
}


- (BOOL)getAudioStreamBasicDescription:(AudioStreamBasicDescription *)outFormat
{
	assert(NULL != outFormat);
	
	outFormat->mSampleRate = _sampleRate;
	outFormat->mFormatID = kAudioFormatLinearPCM;
	outFormat->mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kLinearPCMFormatFlagIsNonInterleaved;
	outFormat->mBytesPerPacket = sizeof (float);
	outFormat->mFramesPerPacket = 1;
	outFormat->mBytesPerFrame = sizeof (float);
	outFormat->mChannelsPerFrame = 2;
	outFormat->mBitsPerChannel = sizeof (float) * 8;
	outFormat->mReserved = 0;
	
	return YES;
}


// Context is (offset << 1) | loop. Offset is initially 0.
- (BOOL)prepareToPlayWithContext:(OOCASoundRenderContext *)outContext looped:(BOOL)inLoop
{
	*outContext = inLoop ? 1 : 0;
	return YES;
}


- (OSStatus)renderWithFlags:(AudioUnitRenderActionFlags *)ioFlags frames:(UInt32)inNumFrames context:(OOCASoundRenderContext *)ioContext data:(AudioBufferList *)ioData
{
	size_t					toCopy, remaining, underflow, offset;
	BOOL					loop, done = NO;
	
	loop = (*ioContext) & 1;
	offset = (*ioContext) >> 1;
	assert (ioData->mNumberBuffers == 2);
	
	if (offset < _size)
	{
		remaining = _size - offset;
		if (remaining < inNumFrames)
		{
			toCopy = remaining;
			underflow = inNumFrames - remaining;
		}
		else
		{
			toCopy = inNumFrames;
			underflow = 0;
		}
		
		bcopy(_bufferL + offset, ioData->mBuffers[0].mData, toCopy * sizeof (float));
		bcopy(_bufferR + offset, ioData->mBuffers[1].mData, toCopy * sizeof (float));
		
		if (underflow && loop)
		{
			offset = toCopy;
			toCopy = inNumFrames - toCopy;
			if (_size < toCopy) toCopy = _size;
			
			bcopy(_bufferL, ((float *)ioData->mBuffers[0].mData) + offset, toCopy * sizeof (float));
			bcopy(_bufferR, ((float *)ioData->mBuffers[1].mData) + offset, toCopy * sizeof (float));
			
			underflow -= toCopy;
			offset = 0;
		}
		
		*ioContext = ((offset + toCopy) << 1) | loop;
	}
	else
	{
		toCopy = 0;
		underflow = inNumFrames;
		*ioFlags |= kAudioUnitRenderAction_OutputIsSilence;
		done = YES;
	}
	
	if (underflow)
	{
		bzero(ioData->mBuffers[0].mData + toCopy, underflow * sizeof (float));
		bzero(ioData->mBuffers[1].mData + toCopy, underflow * sizeof (float));
	}
	
	return done ? endOfDataReached : noErr;
}


#pragma mark OOCABufferedSound

- (id)initWithDecoder:(OOCASoundDecoder *)inDecoder
{
	BOOL					OK = YES;
	
	assert(gOOSoundSetUp);
	if (gOOSoundBroken || nil == inDecoder) OK = NO;
	
	if (OK)
	{
		self = [super init];
		if (nil == self) OK = NO;
	}
	
	if (OK)
	{
		_name = [[inDecoder name] copy];
		_sampleRate = [inDecoder sampleRate];
		if ([inDecoder isStereo])
		{
			OK = [inDecoder readStereoCreatingLeftBuffer:&_bufferL rightBuffer:&_bufferR withFrameCount:&_size];
			_stereo = YES;
		}
		else
		{
			OK = [inDecoder readMonoCreatingBuffer:&_bufferL withFrameCount:&_size];
			_bufferR = _bufferL;
		}
	}
	
	if (!OK)
	{
		[self release];
		self = nil;
	}
	return self;
}

@end
