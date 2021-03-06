/*   FSGenericPointer.h Copyright (c) 2004-2006 Philippe Mougin.   */
/*   This software is open source. See the license.    */  

#import "FSPointer.h"

@interface FSGenericPointer : FSPointer 
{
  BOOL freeWhenDone;
  BOOL freed;
  char *type;
  char fsEncodedType;
}  
 
- (id) at:(id)i;
- (id) at:(id)i put:(id)elem; 
- (void) free;
- (void) setFreeWhenDone:(BOOL)fr;
- (void) setType:(NSString *)theType;

@end
