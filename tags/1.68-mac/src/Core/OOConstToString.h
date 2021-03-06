/*

OOConstToString.h

Oolite
Copyright (C) 2004-2007 Giles C Williams and contributors

Convert various sets of integer constants to strings.
To consider: replacing the integer constants with string constants.

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
#import "OOFunctionAttributes.h"


// STATUS_ACTIVE, STATUS_DOCKING and so forth
NSString *EntityStatusToString(int status) PURE_FUNC;

// CLASS_STATION, CLASS_MISSILE and so forth
NSString *ScanClassToString(int scanClass) PURE_FUNC;


NSString *GovernmentToString(unsigned government);
NSString *EconomyToString(unsigned economy);
