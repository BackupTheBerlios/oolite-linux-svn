/*

GameController.h

Main application controller class.

Oolite
Copyright (C) 2004-2012 Giles C Williams and contributors

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


#import "OOCocoa.h"
#import "OOFunctionAttributes.h"
#import "OOFullScreenController.h"


#if OOLITE_HAVE_APPKIT
#import <Quartz/Quartz.h>	// For PDFKit.
#endif

#if OOLITE_MAC_OS_X && !OOLITE_64_BIT
#define OOLITE_MAC_LEGACY_FULLSCREEN	1
#endif


#define MODE_WINDOWED			100
#define MODE_FULL_SCREEN		200

#define DISPLAY_MIN_COLOURS		32
#define DISPLAY_MIN_WIDTH		640
#define DISPLAY_MIN_HEIGHT		480

#ifndef GNUSTEP
/*	OS X apps are permitted to assume 800x600 screens. Under OS X, we always
	start up in windowed mode. Therefore, the default size fits an 800x600
	screen and leaves space for the menu bar and title bar.
*/
#define DISPLAY_DEFAULT_WIDTH	800
#define DISPLAY_DEFAULT_HEIGHT	540
#define DISPLAY_DEFAULT_REFRESH	75
#endif

#define DISPLAY_MAX_WIDTH		5040		// to cope with DaddyHoggy's 3840x1024 & up to 3 x 1680x1050 displays...
#define DISPLAY_MAX_HEIGHT		1800

#define MINIMUM_GAME_TICK		0.25
// * reduced from 0.5s for tgape * //


@class MyOpenGLView, OOFullScreenController;


// TEMP: whether to use separate OOFullScreenController object, will hopefully be used for all builds soon.
#define OO_USE_FULLSCREEN_CONTROLLER	OOLITE_MAC_OS_X


#if OOLITE_MAC_OS_X
#define kOODisplayWidth			((NSString *)kCGDisplayWidth)
#define kOODisplayHeight		((NSString *)kCGDisplayHeight)
#define kOODisplayRefreshRate	((NSString *)kCGDisplayRefreshRate)
#define kOODisplayBitsPerPixel	((NSString *)kCGDisplayBitsPerPixel)
#define kOODisplayIOFlags		((NSString *)kCGDisplayIOFlags)
#else
#define kOODisplayWidth			(@"Width")
#define kOODisplayHeight		(@"Height")
#define kOODisplayRefreshRate	(@"RefreshRate")
#endif


@interface GameController: NSObject
{
#if OOLITE_HAVE_APPKIT
	IBOutlet NSTextField	*splashProgressTextField;
	IBOutlet NSView			*splashView;
	IBOutlet NSWindow		*gameWindow;
	IBOutlet PDFView		*helpView;
	IBOutlet NSMenu			*dockMenu;
#endif
	
	IBOutlet MyOpenGLView	*gameView;
	
	NSTimeInterval			last_timeInterval;
	double					delta_t;
	
	int						my_mouse_x, my_mouse_y;

	NSString				*playerFileDirectory;
	NSString				*playerFileToLoad;
	NSMutableArray			*expansionPathsToInclude;
	
	NSTimer					*timer;
	
	NSDate					*_splashStart;
	
	SEL						pauseSelector;
	NSObject				*pauseTarget;
	
	BOOL					gameIsPaused;
	
// Fullscreen mode stuff.
#if OO_USE_FULLSCREEN_CONTROLLER
	OOFullScreenController	*_fullScreenController;
#elif OOLITE_SDL
	NSRect					fsGeometry;
	MyOpenGLView			*switchView;
	
	NSMutableArray			*displayModes;
	
	unsigned int			width, height;
	unsigned int			refresh;
	BOOL					fullscreen;
	NSDictionary			*originalDisplayMode;
	NSDictionary			*fullscreenDisplayMode;
	
	BOOL					stayInFullScreenMode;
#endif
}

+ (id)sharedController;

- (void) applicationDidFinishLaunching:(NSNotification *)notification;
- (BOOL) isGamePaused;
- (void) pauseGame;
- (void) unpauseGame;

- (void) performGameTick:(id)sender;

#if OOLITE_HAVE_APPKIT
- (IBAction) showLogAction:(id)sender;
- (IBAction) showLogFolderAction:(id)sender;
- (IBAction) showSnapshotsAction:(id)sender;
- (IBAction) showAddOnsAction:(id)sender;
- (void) recenterVirtualJoystick;
#endif

- (void) exitAppWithContext:(NSString *)context;
- (void) exitAppCommandQ;

- (NSString *) playerFileToLoad;
- (void) setPlayerFileToLoad:(NSString *)filename;

- (NSString *) playerFileDirectory;
- (void) setPlayerFileDirectory:(NSString *)filename;

- (void) loadPlayerIfRequired;

- (void) beginSplashScreen;
- (void) logProgress:(NSString *)message;
#if OO_DEBUG
- (void) debugLogProgress:(NSString *)format, ...  OO_TAKES_FORMAT_STRING(1, 2);
- (void) debugLogProgress:(NSString *)format arguments:(va_list)arguments  OO_TAKES_FORMAT_STRING(1, 0);
- (void) debugPushProgressMessage:(NSString *)format, ...  OO_TAKES_FORMAT_STRING(1, 2);
- (void) debugPopProgressMessage;
#endif
- (void) endSplashScreen;

- (void) startAnimationTimer;
- (void) stopAnimationTimer;

- (MyOpenGLView *) gameView;
- (void) setGameView:(MyOpenGLView *)view;

- (void)windowDidResize:(NSNotification *)aNotification;

- (void)setUpBasicOpenGLStateWithSize:(NSSize)viewSize;

- (NSURL *) snapshotsURLCreatingIfNeeded:(BOOL)create;

@end


@interface GameController (FullScreen)

#if OO_USE_FULLSCREEN_CONTROLLER
#if OOLITE_MAC_OS_X
- (IBAction) toggleFullScreenAction:(id)sender;
#endif

- (void) changeFullScreenResolution;

/*	NOTE: on 32-bit Mac OS X (OOLITE_MAC_LEGACY_FULLSCREEN),
	setFullScreenMode:YES takes over the event loop and doesn't return until
	exiting full screen mode.
*/
- (void) setFullScreenMode:(BOOL)value;
#endif

- (void) exitFullScreenMode;	// FIXME: should be setFullScreenMode:NO
- (BOOL) inFullScreenMode;

- (BOOL) setDisplayWidth:(unsigned int) d_width Height:(unsigned int)d_height Refresh:(unsigned int) d_refresh;
- (NSDictionary *) findDisplayModeForWidth:(unsigned int)d_width Height:(unsigned int) d_height Refresh:(unsigned int) d_refresh;
- (NSArray *) displayModes;
- (OOUInteger) indexOfCurrentDisplayMode;

- (void) pauseFullScreenModeToPerform:(SEL) selector onTarget:(id) target;


// Internal use only.
- (void) setUpDisplayModes;

@end


#if OO_DEBUG
#define OO_DEBUG_PROGRESS(...)		[[GameController sharedController] debugLogProgress:__VA_ARGS__]
#define OO_DEBUG_PUSH_PROGRESS(...)	[[GameController sharedController] debugPushProgressMessage:__VA_ARGS__]
#define OO_DEBUG_POP_PROGRESS()		[[GameController sharedController] debugPopProgressMessage]
#else
#define OO_DEBUG_PROGRESS(...)		do {} while (0)
#define OO_DEBUG_PUSH_PROGRESS(...)	do {} while (0)
#define OO_DEBUG_POP_PROGRESS()		do {} while (0)
#endif
