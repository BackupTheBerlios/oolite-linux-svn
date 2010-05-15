/*

OOJSSound.h

JavaScript sound object.

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

#import <Foundation/Foundation.h>
#import <jsapi.h>
@class OOSound;


void InitOOJSSound(JSContext *context, JSObject *global);


/*	SoundFromJSValue()
	
	Convert a JS value to a sound. The value may be either a Sound object or a
	string specifying a sound name.
 */
OOSound *SoundFromJSValue(JSContext *context, jsval value);
