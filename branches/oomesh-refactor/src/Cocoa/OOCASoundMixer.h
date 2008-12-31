/*

OOCASoundMixer.h

Class responsible for managing and mixing sound channels. This class is an
implementation detail. Do not use it directly; use an OOSoundSource to play an
OOSound.

OOCASound - Core Audio sound implementation for Oolite.
Copyright (C) 2005-2008 Jens Ayton

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

Copyright (C) 2006 Jens Ayton

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

#import <Foundation/Foundation.h>
#import <mach/port.h>
#import <AudioToolbox/AudioToolbox.h>

@class OOMusic, OOSoundChannel, OOSoundSource;


enum
{
	kMixerGeneralChannels		= 32
};


#define SUPPORT_SOUND_INSPECTOR		0


@interface OOSoundMixer: NSObject
{
	OOSoundChannel				*_channels[kMixerGeneralChannels];
	OOSoundChannel				*_freeList;
	NSLock						*_listLock;
	
	AUGraph						_graph;
	AUNode						_mixerNode;
	AUNode						_outputNode;
	AudioUnit					_mixerUnit;
	
	uint32_t					_activeChannels;
	uint32_t					_maxChannels;
	uint32_t					_playMask;
	
#if SUPPORT_SOUND_INSPECTOR
	IBOutlet NSMatrix			*checkBoxes;
	IBOutlet NSTextField		*currentField;
	IBOutlet NSTextField		*maxField;
	IBOutlet NSTextField		*loadField;
	IBOutlet NSProgressIndicator *loadBar;
#endif
}

// Singleton accessor
+ (id) sharedMixer;

- (void) update;

- (void) setMasterVolume:(float)inVolume;

- (OOSoundChannel *) popChannel;
- (void) pushChannel:(OOSoundChannel *)inChannel;

@end
