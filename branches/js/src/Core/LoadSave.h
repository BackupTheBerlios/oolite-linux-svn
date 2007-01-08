
//
// LoadSave.h
//
// Created for the Oolite-Linux project (but is portable)
//
// Dylan Smith, 2005-06-21
//
// LoadSave has been separated out into a separate category because
// PlayerEntity.m has gotten far too big and is in danger of becoming
// the whole general mish mash.
//
// oolite: (c) 2004 Giles C Williams.
// This work is licensed under the Creative Commons Attribution NonCommercial
// ShareAlike license.
//
#import "PlayerEntity.h"
#import "GuiDisplayGen.h"
#import "MyOpenGLView.h"
#import "Universe.h"

#define LABELROW 1
#define BACKROW 2 
#define STARTROW 3
#define ENDROW 16
#define MOREROW 16
#define NUMROWS 13
#define COLUMNS 2
#define INPUTROW 20
#define CDRDESCROW 18
#define SAVE_OVERWRITE_WARN_ROW	5
#define SAVE_OVERWRITE_YES_ROW	8
#define SAVE_OVERWRITE_NO_ROW	9

@interface PlayerEntity (LoadSave)

- (void) setGuiToLoadCommanderScreen;
- (void) setGuiToSaveCommanderScreen: (NSString *)cdrName;
- (void) setGuiToOverwriteScreen: (NSString *)cdrName;
- (void) lsCommanders: (GuiDisplayGen *)gui directory: (NSString*)directory pageNumber: (int)page highlightName: (NSString *)highlightName;
- (NSString *) commanderSelector: (GuiDisplayGen *)gui : (MyOpenGLView *)gameView;
- (void) saveCommanderInputHandler: (GuiDisplayGen *)gui : (MyOpenGLView *)gameView;
- (void) overwriteCommanderInputHandler: (GuiDisplayGen *)gui : (MyOpenGLView *)gameView;
- (void) nativeSavePlayer: (NSString *)cdrName;
- (BOOL) existingNativeSave: (NSString *)cdrName;
- (void) showCommanderShip: (int)cdrArrayIndex;
- (int) findIndexOfCommander: (NSString *)cdrName;

@end

