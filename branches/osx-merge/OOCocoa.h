// Import OpenStep main headers and define some Macisms and other compatibility stuff.

#ifndef GNUSTEP

#import <math.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#define Boolean unsigned char
#define Byte unsigned char
#define true 1
#define false 0

#define kCGDisplayWidth (@"Width")
#define kCGDisplayHeight (@"Height")
#define kCGDisplayRefreshRate (@"RefreshRate")

#define IBOutlet /**/
#define IBAction void

typedef int32_t CGMouseDelta;

#else

#import <Cocoa/Cocoa.h>

#endif
