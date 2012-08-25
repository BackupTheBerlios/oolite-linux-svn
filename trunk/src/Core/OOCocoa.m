/*

OOCocoa.m

Runtime-like methods.


Copyright (C) 2008-2012 Jens Ayton

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

#import "OOCocoa.h"
#import "OOFunctionAttributes.h"


@implementation NSObject (OODescriptionComponents)

- (NSString *)descriptionComponents
{
	return nil;
}


- (NSString *)description
{
	NSString				*components = nil;
	
	components = [self descriptionComponents];
	if (components != nil)
	{
		return [NSString stringWithFormat:@"<%@ %p>{%@}", [self class], self, components];
	}
	else
	{
		return [NSString stringWithFormat:@"<%@ %p>", [self class], self];
	}
}


- (NSString *) shortDescription
{
	NSString				*components = nil;
	
	components = [self shortDescriptionComponents];
	if (components != nil)
	{
		return [NSString stringWithFormat:@"<%@ %p>{%@}", [self class], self, components];
	}
	else
	{
		return [NSString stringWithFormat:@"<%@ %p>", [self class], self];
	}
}


- (NSString *) shortDescriptionComponents
{
	return nil;
}

@end


#ifndef NDEBUG
id OOConsumeReference(id OO_NS_CONSUMED value)
{
	return value;
}
#endif



#if OOLITE_GNUSTEP && !OOLITE_GNUSTEP_1_20
/*
	I'm informed that we're using GNUstep 1.20.1 for Linux and Windows builds.
	I'll leave this here for a while to see if anyone is hit before cleaning
	up pre-1.20 cases. -- Ahruman 2012-08-25
*/
#error Oolite for non-Mac targets requires GNUstep 1.20.
#endif
