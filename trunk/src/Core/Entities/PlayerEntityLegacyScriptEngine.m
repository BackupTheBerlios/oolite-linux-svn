/*

PlayerEntityLegacyScriptEngine.m

Oolite
Copyright (C) 2004-2007 Giles C Williams and contributors

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

#import "PlayerEntityLegacyScriptEngine.h"
#import "PlayerEntityScriptMethods.h"
#import "GuiDisplayGen.h"
#import "Universe.h"
#import "ResourceManager.h"
#import "AI.h"
#import "ShipEntityAI.h"
#import "OOScript.h"
#import "OOSound.h"
#import "OOColor.h"
#import "OOStringParsing.h"
#import "OOConstToString.h"
#import "OOTexture.h"
#import "OOCollectionExtractors.h"

#import "PlanetEntity.h"
#import "ParticleEntity.h"
#import "StationEntity.h"

#ifdef GNUSTEP
#import "Comparison.h"
#endif

#define kOOLogUnconvertedNSLog @"unclassified.PlayerEntityLegacyScriptEngine"


enum
{
	COMPARISON_NO,
	COMPARISON_EQUAL,
	COMPARISON_NOTEQUAL,
	COMPARISON_LESSTHAN,
	COMPARISON_GREATERTHAN,
	COMPARISON_ONEOF,
	COMPARISON_UNDEFINED
};


static NSString * const kOOLogScriptAddShipsFailed			= @"script.addShips.failed";
static NSString * const kOOLogScriptMissionDescNoText		= @"script.missionDescription.noMissionText";
static NSString * const kOOLogScriptMissionDescNoKey		= @"script.missionDescription.noMissionKey";

static NSString * const kOOLogDebug							= @"script.debug";
static NSString * const kOOLogDebugOnMetaClass				= @"$scriptDebugOn";
	   NSString * const kOOLogDebugMessage					= @"script.debug.message";
static NSString * const kOOLogDebugOnOff					= @"script.debug.onOff";
static NSString * const kOOLogDebugTestConditionCheckingVariable = @"script.debug.testCondition.checkingVariable";
static NSString * const kOOLogDebugTestConditionValues		= @"script.debug.testCondition.testValues";
static NSString * const kOOLogDebugTestConditionOnOf		= @"script.debug.testCondition.oneOf";
static NSString * const kOOLogDebugAddPlanet				= @"script.debug.addPlanet";
static NSString * const kOOLogDebugReplaceVaraiblesInString	= @"script.debug.replaceVariablesInString";
static NSString * const kOOLogDebugProcessSceneStringAddScene = @"script.debug.processSceneString.addScene";
static NSString * const kOOLogDebugProcessSceneStringAddModel = @"script.debug.processSceneString.addModel";
static NSString * const kOOLogDebugProcessSceneStringAddLocalPlanet = @"script.debug.processSceneString.addLocalPlanet";
static NSString * const kOOLogDebugProcessSceneStringAddTargetPlanet = @"script.debug.processSceneString.addTargetPlanet";
static NSString * const kOOLogDebugProcessSceneStringAddBillboard = @"script.debug.processSceneString.addBillboard";
static NSString * const kOOLogDebugSetSunNovaIn				= @"script.debug.setSunNovaIn";

static NSString * const kOOLogNoteScriptAction				= @"script.debug.note.scriptAction";
static NSString * const kOOLogNoteTestCondition				= @"script.debug.note.testCondition";
static NSString * const kOOLogNoteAwardCargo				= @"script.debug.note.awardCargo";
static NSString * const kOOLogNoteRemoveAllCargo			= @"script.debug.note.removeAllCargo";
static NSString * const kOOLogNoteUseSpecialCargo			= @"script.debug.note.useSpecialCargo";
	   NSString * const kOOLogNoteAddShips					= @"script.debug.note.addShips";
static NSString * const kOOLogNoteSet						= @"script.debug.note.set";
static NSString * const kOOLogNoteShowShipModel				= @"script.debug.note.showShipModel";
static NSString * const kOOLogNoteFuelLeak					= @"script.debug.note.setFuelLeak";
static NSString * const kOOLogNoteAddPlanet					= @"script.debug.note.addPlanet";
static NSString * const kOOLogNoteProcessSceneString		= @"script.debug.note.processSceneString";

static NSString * const kOOLogSyntaxBadConditional			= @"script.debug.syntax.badConditional";
static NSString * const kOOLogSyntaxNoAction				= @"script.debug.syntax.action.noneSpecified";
static NSString * const kOOLogSyntaxBadAction				= @"script.debug.syntax.action.badSelector";
static NSString * const kOOLogSyntaxNoScriptCondition		= @"script.debug.syntax.scriptCondition.noneSpecified";
static NSString * const kOOLogSyntaxSetPlanetInfo			= @"script.debug.syntax.setPlanetInfo";
static NSString * const kOOLogSyntaxAwardCargo				= @"script.debug.syntax.awardCargo";
static NSString * const kOOLogSyntaxMessageShipAIs			= @"script.debug.syntax.messageShipAIs";
	   NSString * const kOOLogSyntaxAddShips				= @"script.debug.syntax.addShips";
static NSString * const kOOLogSyntaxSet						= @"script.debug.syntax.set";
static NSString * const kOOLogSyntaxReset					= @"script.debug.syntax.reset";

static NSString * const kOOLogRemoveAllCargoNotDocked		= @"script.error.removeAllCargo.notDocked";


@implementation PlayerEntity (Scripting)

static NSString * mission_string_value;
static NSString * mission_key;


- (void) checkScript
{
	NSEnumerator				*scriptEnum = nil;
	OOScript					*theScript = nil;
	
	[self setScriptTarget:self];
	
	OOLog(@"script.trace.runWorld", @"----- Running world script with state %@", [self status_string]);
	OOLogIndentIf(@"script.trace.runWorld");
	
	for (scriptEnum = [script objectEnumerator]; (theScript = [scriptEnum nextObject]); )
	{
		[theScript runWithTarget:self];
	}
	
	OOLogOutdentIf(@"script.trace.runWorld");
}


- (void)runScript:(NSArray*)scriptActions withName:(NSString *)scriptName forTarget:(ShipEntity *)target
{
	[self setScriptTarget:target];
	mission_key = scriptName;
	[self scriptActions:scriptActions forTarget:target];
}


- (void) scriptActions:(NSArray*) some_actions forTarget:(ShipEntity*) a_target
{
	unsigned i;
	
	for (i = 0; i < [some_actions count]; i++)
	{
		NSObject* action = [some_actions objectAtIndex:i];
		if ([action isKindOfClass:[NSDictionary class]])
			[self checkCouplet:(NSDictionary *)action onEntity: a_target];
		if ([action isKindOfClass:[NSString class]])
			[self scriptAction:(NSString *)action onEntity: a_target];
	}
}


- (BOOL) checkCouplet:(NSDictionary *) couplet onEntity:(Entity *) entity
{
	NSAutoreleasePool	*pool = nil;
	NSArray				*conditions = [couplet objectForKey:@"conditions"];	// No CollectionsExtractors here, because we provide more detailed info below.
	NSArray				*actions = [couplet objectForKey:@"do"];
	NSArray				*else_actions = [couplet objectForKey:@"else"];
	BOOL				success = YES;
	unsigned			i;
	
	if (conditions == nil)
	{
		OOLog(kOOLogSyntaxBadConditional, @"SCRIPT ERROR no 'conditions' in %@ - returning YES.", [couplet description]);
		return success;
	}
	if (![conditions isKindOfClass:[NSArray class]])
	{
		OOLog(kOOLogSyntaxBadConditional, @"SCRIPT ERROR \"conditions = %@\" is not an array - returning YES.", [conditions description]);
		return success;
	}
	
	pool = [[NSAutoreleasePool alloc] init];
	
	NS_DURING
		for (i = 0; (i < [conditions count])&&(success); i++)
			success &= [self scriptTestCondition:(NSString *)[conditions objectAtIndex:i]];
		if ((success) && (actions))
		{
			if (![actions isKindOfClass:[NSArray class]])
			{
				OOLog(kOOLogSyntaxBadConditional, @"SCRIPT ERROR \"actions = %@\" is not an array.", [actions description]);
			}
			else
			{
				for (i = 0; i < [actions count]; i++)
				{
					if ([[actions objectAtIndex:i] isKindOfClass:[NSDictionary class]])
						[self checkCouplet:(NSDictionary *)[actions objectAtIndex:i] onEntity:entity];
					if ([[actions objectAtIndex:i] isKindOfClass:[NSString class]])
						[self scriptAction:(NSString *)[actions objectAtIndex:i] onEntity:entity];
				}
			}
		}
		// now check if there's an 'else' to do if the couplet is false
		if ((!success) && (else_actions))
		{
			if (![else_actions isKindOfClass:[NSArray class]])
			{
				OOLog(kOOLogSyntaxBadConditional, @"SCRIPT ERROR \"else_actions = %@\" is not an array.", [else_actions description]);
			}
			else
			{
				for (i = 0; i < [else_actions count]; i++)
				{
					if ([[else_actions objectAtIndex:i] isKindOfClass:[NSDictionary class]])
						[self checkCouplet:(NSDictionary *)[else_actions objectAtIndex:i] onEntity:entity];
					if ([[else_actions objectAtIndex:i] isKindOfClass:[NSString class]])
						[self scriptAction:(NSString *)[else_actions objectAtIndex:i] onEntity:entity];
				}
			}
		}
	NS_HANDLER
		OOLog(kOOLogException, @"***** Exception %@ (%@) during plist script evaluation.", [localException name], [localException reason]);
		// Suppress
	NS_ENDHANDLER
	[pool release];
	
	return success;
}


- (void) scriptAction:(NSString *) scriptAction onEntity:(Entity *) entity
{
	/*
	a script action takes the form of an expression:

	action[: string_expression]

	where 'action' is a  selector for the entity or (failing that) PlayerEntity
	optionally taking a NSString object ('string_expression') as a variable

	The special action 'set: mission_variable string_expression'

	is used to set a mission variable to the given string_expression

	*/
	NSMutableArray*	tokens = ScanTokensFromString(scriptAction);
	NSMutableDictionary* locals = [local_variables objectForKey:mission_key];
	NSString*   selectorString = nil;
	NSString*	valueString = nil;
	SEL			_selector;

	OOLog(kOOLogNoteScriptAction, @"scriptAction: \"%@\"", scriptAction);

	if ([tokens count] < 1)
	{
		OOLog(kOOLogSyntaxNoAction, @"***** No scriptAction '%@'",scriptAction);
		return;
	}

	selectorString = (NSString *)[tokens objectAtIndex:0];

	if ([tokens count] > 1)
	{
		[tokens removeObjectAtIndex:0];
		valueString = [[tokens componentsJoinedByString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		valueString = ExpandDescriptionsWithLocalsForCurrentSystem(valueString, locals);
		OOLog(kOOLogNoteScriptAction, @"scriptAction after expansion: \"%@ %@\"", selectorString, valueString);
	}

	_selector = NSSelectorFromString(selectorString);

	if ((entity)&&([entity respondsToSelector:_selector]))
	{
		if ([selectorString hasSuffix:@":"])
			[entity performSelector:_selector withObject:valueString];
		else
			[entity performSelector:_selector];
		return;
	}

	if (![self respondsToSelector:_selector])
	{
		OOLog(kOOLogSyntaxBadAction, @"***** PlayerEntity DOES NOT RESPOND TO scriptAction: \"%@\"", scriptAction);
		return;
	}

	if ([selectorString hasSuffix:@":"])
		[self performSelector:_selector withObject:valueString];
	else
		[self performSelector:_selector];
}


- (BOOL) scriptTestCondition:(NSString *) scriptCondition
{
	/*
	a script condition takes the form of an expression:

	testable_variable lessthan|equals|greaterthan constant_expression

	where testable_variable is an accessor selector for PlayerEntity returning an object
	that can be compared with the constant expression. They are supposed to take the form:
		variablename_type where type can be 'string', 'bool', or 'number'

	or where testable_variable is prefixed with 'mission_' in which case it is a 'mission variable'
	which is a string used by the script as a means of setting flags or indicating state

	The special test:

	testable_variable undefined

	is used only with mission variables and is true when that mission variable has yet to be used

	v1.31+
	constant_expression can now also be an accessor selector recognised by having the suffix
	"_bool", "_number" or "_string".

	dajt: black ops
	a new comparison operator "oneof" can be used to test a numeric variable against a set of
	comma separated numeric constants (eg "planet_number oneof 1,5,9,12,14,234").

	*/
	NSArray*	tokens = ScanTokensFromString(scriptCondition);
	NSMutableDictionary* locals = [local_variables objectForKey:mission_key];
	NSString*   selectorString = nil;
	NSString*	comparisonString = nil;
	NSString*	valueString = nil;
	SEL			_selector;
	int			comparator = COMPARISON_NO;

	OOLog(kOOLogNoteTestCondition, @"scriptTestCondition: \"%@\"", scriptCondition);

	if ([tokens count] < 1)
	{
		OOLog(kOOLogSyntaxNoScriptCondition, @"***** No scriptCondition '%@'",scriptCondition);
		return NO;
	}
	selectorString = (NSString *)[tokens objectAtIndex:0];
	if ([selectorString hasPrefix:@"mission_"])
	{
		OOLog(kOOLogDebugTestConditionCheckingVariable, @"DEBUG ..... checking mission_variable '%@'",selectorString);
		mission_string_value = (NSString *)[mission_variables objectForKey:selectorString];
		selectorString = @"mission_string";
	}
	else if ([selectorString hasPrefix:@"local_"])
	{
		OOLog(kOOLogDebugTestConditionCheckingVariable, @"DEBUG ..... checking local variable '%@'",selectorString);
		mission_string_value = (NSString *)[locals objectForKey:selectorString];
		selectorString = @"mission_string";
	}

	if ([tokens count] > 1)
	{
		comparisonString = (NSString *)[tokens objectAtIndex:1];
		if ([comparisonString isEqual:@"equal"])
			comparator = COMPARISON_EQUAL;
		else if ([comparisonString isEqual:@"notequal"])
			comparator = COMPARISON_NOTEQUAL;
		else if ([comparisonString isEqual:@"lessthan"])
			comparator = COMPARISON_LESSTHAN;
		else if (([comparisonString isEqual:@"greaterthan"])||([comparisonString isEqual:@"morethan"]))
			comparator = COMPARISON_GREATERTHAN;
// +dajt: black ops
		else if ([comparisonString isEqual:@"oneof"])
			comparator = COMPARISON_ONEOF;
// -dajt: black ops
		else if ([comparisonString isEqual:@"undefined"])
			comparator = COMPARISON_UNDEFINED;
	}

	if ([tokens count] > 2)
	{
		NSMutableString* allValues = [NSMutableString stringWithCapacity:256];
		unsigned value_index = 2;
		while (value_index < [tokens count])
		{
			valueString = (NSString *)[tokens objectAtIndex:value_index++];
			if (([valueString hasSuffix:@"_number"])||([valueString hasSuffix:@"_bool"])||([valueString hasSuffix:@"_string"]))
			{
				SEL value_selector = NSSelectorFromString(valueString);
				if ([self respondsToSelector:value_selector])
				{
					// substitute into valueString the result of the call
					valueString = [NSString stringWithFormat:@"%@", [self performSelector:value_selector]];
				}
			}
			[allValues appendString:valueString];
			if (value_index < [tokens count])
				[allValues appendString:@" "];
		}
		valueString = allValues;
	}

	_selector = NSSelectorFromString(selectorString);
	if (![self respondsToSelector:_selector])
		return NO;

	// test string values (method returns NSString*)
	if ([selectorString hasSuffix:@"_string"])
	{
		NSString *result = [self performSelector:_selector];
		OOLog(kOOLogDebugTestConditionValues, @"..... comparing \"%@\" (%@) to \"%@\" (%@)", result, [result class], valueString, [valueString class]);
		switch (comparator)
		{
			case COMPARISON_UNDEFINED :
				return (result == nil);
			case COMPARISON_NO :
				return NO;
			case COMPARISON_EQUAL :
				return ([result isEqual:valueString]);
			case COMPARISON_NOTEQUAL :
				return (![result isEqual:valueString]);
			case COMPARISON_LESSTHAN :
				return ([result floatValue] < [valueString floatValue]);
			case COMPARISON_GREATERTHAN :
				return ([result floatValue] > [valueString floatValue]);
			case COMPARISON_ONEOF:
				{
					unsigned i;
					NSArray *valueStrings = [valueString componentsSeparatedByString:@","];
					OOLog(kOOLogDebugTestConditionOnOf, @"performing a ONEOF comparison: is %@ ONEOF %@ ?", result, valueStrings);
					NSString* r1 = [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
					for (i = 0; i < [valueStrings count]; i++)
					{
						if ([r1 isEqual:[(NSString*)[valueStrings objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]])
						{
							OOLog(kOOLogDebugTestConditionOnOf, @"found a match in ONEOF!");
							return YES;
						}
					}
				}
				return NO;
		}
	}
	// test number values (method returns NSNumber*)
	if ([selectorString hasSuffix:@"_number"])
	{
		NSNumber *result = [NSNumber numberWithDouble:[[self performSelector:_selector] doubleValue]];
// +dajt: black ops
		if (comparator == COMPARISON_ONEOF)
		{
			NSArray *valueStrings = [valueString componentsSeparatedByString:@","];
			OOLog(kOOLogDebugTestConditionOnOf, @"performing a ONEOF comparison with %d elements: is %@ ONEOF %@", [valueStrings count], result, valueStrings);
			unsigned i;
			for (i = 0; i < [valueStrings count]; i++)
			{
				NSNumber *value = [NSNumber numberWithDouble:[[valueStrings objectAtIndex: i] doubleValue]];
				if ([result isEqual:value])
				{
					OOLog(kOOLogDebugTestConditionOnOf, @"found a match in ONEOF!");
					return YES;
				}
			}
			OOLog(kOOLogDebugTestConditionOnOf, @"No match in ONEOF");
			return NO;
		}
		else
		{
			NSNumber *value = [NSNumber numberWithDouble:[valueString doubleValue]];

			OOLog(kOOLogDebugTestConditionValues, @"..... comparing \"%@\" (%@) to \"%@\" (%@)", result, [result class], value, [value class]);

			switch (comparator)
			{
				case COMPARISON_UNDEFINED :
				case COMPARISON_NO :
					return NO;
				case COMPARISON_EQUAL :
					return ([result isEqual:value]);
				case COMPARISON_NOTEQUAL :
					return (![result isEqual:value]);
				case COMPARISON_LESSTHAN :
					return ([result isLessThan:value]);
				case COMPARISON_GREATERTHAN :
					return ([result isGreaterThan:value]);
			}
		}
// -dajt: black ops
	}
	// test boolean values (method returns @"YES" or @"NO")
	if ([selectorString hasSuffix:@"_bool"])
	{
		BOOL result = ([[self performSelector:_selector] isEqual:@"YES"]);
		BOOL value = [valueString isEqual:@"YES"];
		switch (comparator)
		{
			case COMPARISON_GREATERTHAN:
			case COMPARISON_LESSTHAN:
			case COMPARISON_UNDEFINED:
			case COMPARISON_NO:
				return NO;
			case COMPARISON_EQUAL:
				return (result == value);
			case COMPARISON_NOTEQUAL:
				return (result != value);
		}
	}
	// default!
	return NO;
}


- (NSDictionary*) mission_variables
{
	return mission_variables;
}


- (NSString *)missionVariableForKey:(NSString *)key
{
	NSString *result = nil;
	if (key != nil) result = [mission_variables objectForKey:key];
	return result;
}


- (void)setMissionVariable:(NSString *)value forKey:(NSString *)key
{
	if (key != nil)
	{
		if (value != nil) [mission_variables setObject:value forKey:key];
		else [mission_variables removeObjectForKey:key];
	}
}

/*-----------------------------------------------------*/

- (NSArray*) missionsList
{
	NSEnumerator			*scriptEnum = nil;
	NSString				*scriptName = nil;
	NSString				*vars = nil;
	NSMutableArray			*result = nil;
	
	result = [NSMutableArray array];
	
	for (scriptEnum = [script keyEnumerator]; (scriptName = [scriptEnum nextObject]); )
	{
		vars = [mission_variables objectForKey:scriptName];
		
		if (vars != nil)
		{
			[result addObject:[NSString stringWithFormat:@"\t%@", vars]];
		}
	}
	return result;
}


- (void) setMissionDescription:(NSString *)textKey
{
	NSString		*text = (NSString *)[[UNIVERSE missiontext] objectForKey:textKey];
	if (!text)
	{
		OOLog(kOOLogScriptMissionDescNoText, @"SCRIPT ERROR ***** no missiontext set for key '%@' [UNIVERSE missiontext] is:\n%@ ", textKey, [UNIVERSE missiontext]);
		return;
	}
	if (!mission_key)
	{
		OOLog(kOOLogScriptMissionDescNoKey, @"SCRIPT ERROR ***** mission_key not set");
		return;
	}
	text = ExpandDescriptionForCurrentSystem(text);
	text = [self replaceVariablesInString: text];

	[mission_variables setObject:text forKey:mission_key];
}


- (void) clearMissionDescription
{
	if (!mission_key)
	{
		OOLog(kOOLogScriptMissionDescNoText, @"SCRIPT ERROR ***** mission_key not set");
		return;
	}
	if (![mission_variables objectForKey:mission_key])
		return;
	[mission_variables removeObjectForKey:mission_key];
}


- (void) setMissionDescription:(NSString *)textKey forMission:(NSString *)key
{
	NSString *old_mission_key = mission_key;
	mission_key = key;
	[self setMissionDescription:textKey];
	mission_key = old_mission_key;
}


- (void) clearMissionDescriptionForMission:(NSString *)key
{
	NSString *old_mission_key = mission_key;
	mission_key = key;
	[self clearMissionDescription];
	mission_key = old_mission_key;
}


- (NSString *) mission_string
{
	return mission_string_value;
}


- (NSString *) status_string
{
	return EntityStatusToString(status);
}


- (NSString *) gui_screen_string
{
	return GUIScreenIDToString(gui_screen);
}


- (NSNumber *) galaxy_number
{
	return [NSNumber numberWithInt:galaxy_number];
}


- (NSNumber *) planet_number
{
	if (![UNIVERSE sun])
		return [NSNumber numberWithInt:-1];
	return [NSNumber numberWithInt:[UNIVERSE findSystemNumberAtCoords:galaxy_coordinates withGalaxySeed:galaxy_seed]];
}


- (NSNumber *) score_number
{
	return [NSNumber numberWithInt:ship_kills];
}


- (NSNumber *) credits_number
{
	return [NSNumber numberWithFloat: 0.1 * credits];
}


- (NSNumber *) scriptTimer_number
{
	return [NSNumber numberWithDouble:script_time];
}


static int shipsFound;
- (NSNumber *) shipsFound_number
{
	return [NSNumber numberWithInt:shipsFound];
}


- (NSNumber *) legalStatus_number
{
	return [NSNumber numberWithInt:legalStatus];
}


static int scriptRandomSeed = -1;	// ensure proper random function
- (NSNumber *) d100_number
{
	if (scriptRandomSeed == -1)	scriptRandomSeed = floor(1301 * ship_clock);	// stop predictable sequences
	ranrot_srand(scriptRandomSeed);
	scriptRandomSeed = ranrot_rand();
	int d100 = ranrot_rand() % 100;
	return [NSNumber numberWithInt:d100];
}


- (NSNumber *) pseudoFixedD100_number
{
	// set the system seed for random number generation
	seed_RNG_only_for_planet_description(system_seed);
	int d100 = (gen_rnd_number() * 256 + gen_rnd_number()) % 100;
	return [NSNumber numberWithInt:d100];
}


- (NSNumber *) d256_number
{
	if (scriptRandomSeed == -1)	scriptRandomSeed = floor(1301 * ship_clock);	// stop predictable sequences
	ranrot_srand(scriptRandomSeed);
	scriptRandomSeed = ranrot_rand();
	int d256 = ranrot_rand() % 256;
	return [NSNumber numberWithInt:d256];
}


- (NSNumber *) pseudoFixedD256_number
{
	// set the system seed for random number generation
	seed_RNG_only_for_planet_description(system_seed);
	int d256 = gen_rnd_number();
	return [NSNumber numberWithInt:d256];
}


- (NSNumber *) clock_number				// returns the game time in seconds
{
	return [NSNumber numberWithDouble:ship_clock];
}


- (NSNumber *) clock_secs_number		// returns the game time in seconds
{
	return [NSNumber numberWithInt:floor(ship_clock)];
}


- (NSNumber *) clock_mins_number		// returns the game time in minutes
{
	return [NSNumber numberWithInt:floor(ship_clock / 60.0)];
}


- (NSNumber *) clock_hours_number		// returns the game time in hours
{
	return [NSNumber numberWithInt:floor(ship_clock / 3600.0)];
}


- (NSNumber *) clock_days_number		// returns the game time in days
{
	return [NSNumber numberWithInt:floor(ship_clock / 86400.0)];
}


- (NSNumber *) fuel_level_number		// returns the fuel level in LY
{
	return [NSNumber numberWithFloat:floor(0.1 * fuel)];
}


- (NSString *) dockedAtMainStation_bool
{
	if ((status == STATUS_DOCKED)&&(docked_station == [UNIVERSE station]))
		return @"YES";
	else
		return @"NO";
}


- (NSString *) foundEquipment_bool
{
	return (found_equipment)? @"YES" : @"NO";
}


- (NSString *) sunWillGoNova_bool		// returns whether the sun is going to go nova
{
	return ([[UNIVERSE sun] willGoNova])? @"YES" : @"NO";
}


- (NSString *) sunGoneNova_bool		// returns whether the sun has gone nova
{
	return ([[UNIVERSE sun] goneNova])? @"YES" : @"NO";
}


- (NSString *) missionChoice_string		// returns nil or the key for the chosen option
{
	return missionChoice;
}


- (NSString *) dockedStationName_string	// returns 'NONE' if the player isn't docked, [station name] if it is, 'UNKNOWN' otherwise
{
	if (status != STATUS_DOCKED)
		return @"NONE";
	if (docked_station)
		return [docked_station name];
	return @"UNKNOWN";
}


- (NSString *) systemGovernment_string
{
	int government = [[self systemGovernment_number] intValue]; // 0 .. 7 (0 anarchic .. 7 most stable)
	NSString *result = GovernmentToString(government);
	if (result == nil) result = @"UNKNOWN";
	
	return result;
}


- (NSNumber *) systemGovernment_number
{
	NSDictionary *systeminfo = [UNIVERSE generateSystemData:system_seed];
	return [systeminfo objectForKey:KEY_GOVERNMENT];
}


- (NSString *) systemEconomy_string
{
	int economy = [[self systemEconomy_number] intValue]; // 0 .. 7 (0 rich industrial .. 7 poor agricultural)
	NSString *result = EconomyToString(economy);
	if (result == nil) result = @"UNKNOWN";
	
	return result;
}


- (NSNumber *) systemEconomy_number
{
	NSDictionary *systeminfo = [UNIVERSE generateSystemData:system_seed];
	return [systeminfo objectForKey:KEY_ECONOMY];
}


- (NSNumber *) systemTechLevel_number
{
	NSDictionary *systeminfo = [UNIVERSE generateSystemData:system_seed];
	return [systeminfo objectForKey:KEY_TECHLEVEL];
}


- (NSNumber *) systemPopulation_number
{
	NSDictionary *systeminfo = [UNIVERSE generateSystemData:system_seed];
	return [systeminfo objectForKey:KEY_POPULATION];
}


- (NSNumber *) systemProductivity_number
{
	NSDictionary *systeminfo = [UNIVERSE generateSystemData:system_seed];
	return [systeminfo objectForKey:KEY_PRODUCTIVITY];
}


- (NSString *) commanderName_string
{
	return [NSString stringWithString: player_name];
}


- (NSString *) commanderRank_string
{
	return KillCountToRatingString(ship_kills);
}


- (NSString *) commanderShip_string
{
	return [self name];
}


- (NSString *) commanderLegalStatus_string
{
	return LegalStatusToString(legalStatus);
}


- (NSNumber *) commanderLegalStatus_number
{
	return [NSNumber numberWithInt: legalStatus];
}

/*-----------------------------------------------------*/

- (void) commsMessage:(NSString *)valueString
{
	Random_Seed very_random_seed;
	very_random_seed.a = rand() & 255;
	very_random_seed.b = rand() & 255;
	very_random_seed.c = rand() & 255;
	very_random_seed.d = rand() & 255;
	very_random_seed.e = rand() & 255;
	very_random_seed.f = rand() & 255;
	seed_RNG_only_for_planet_description(very_random_seed);
	NSString* expandedMessage = ExpandDescriptionForCurrentSystem(valueString);
	expandedMessage = [self replaceVariablesInString: expandedMessage];

	[UNIVERSE addCommsMessage:expandedMessage forCount:4.5];
}


- (void) consoleMessage3s:(NSString *)valueString
{
	Random_Seed very_random_seed;
	very_random_seed.a = rand() & 255;
	very_random_seed.b = rand() & 255;
	very_random_seed.c = rand() & 255;
	very_random_seed.d = rand() & 255;
	very_random_seed.e = rand() & 255;
	very_random_seed.f = rand() & 255;
	seed_RNG_only_for_planet_description(very_random_seed);
	NSString* expandedMessage = ExpandDescriptionForCurrentSystem(valueString);
	expandedMessage = [self replaceVariablesInString: expandedMessage];

	[UNIVERSE addMessage: expandedMessage forCount: 3];
}


- (void) consoleMessage6s:(NSString *)valueString
{
	Random_Seed very_random_seed;
	very_random_seed.a = rand() & 255;
	very_random_seed.b = rand() & 255;
	very_random_seed.c = rand() & 255;
	very_random_seed.d = rand() & 255;
	very_random_seed.e = rand() & 255;
	very_random_seed.f = rand() & 255;
	seed_RNG_only_for_planet_description(very_random_seed);
	NSString* expandedMessage = ExpandDescriptionForCurrentSystem(valueString);
	expandedMessage = [self replaceVariablesInString: expandedMessage];

	[UNIVERSE addMessage: expandedMessage forCount: 6];
}


- (void) setLegalStatus:(NSString *)valueString
{
	legalStatus = [valueString intValue];
}


- (void) awardCredits:(NSString *)valueString
{
	if (script_target != self)  return;
	
	int award = 10 * [valueString intValue];
	if (award < 0 && credits < (unsigned)-award)  credits = 0;
	else  credits += award;
}


- (void) awardShipKills:(NSString *)valueString
{
	if (script_target != self)  return;
	
	int value = [valueString intValue];
	if (0 < value)  ship_kills += value;
}


- (void) awardEquipment:(NSString *)equipString  //eg. EQ_NAVAL_ENERGY_UNIT
{
	NSString*   eq_type		= equipString;

	if (script_target != self)  return;

	if ([eq_type isEqual:@"EQ_FUEL"])
	{
		fuel = PLAYER_MAX_FUEL;
		return;
	}

	if ([eq_type hasSuffix:@"MISSILE"]||[eq_type hasSuffix:@"MINE"])
	{
		if ([self mountMissile:[[UNIVERSE newShipWithRole:eq_type] autorelease]])
			missiles++;
		return;
	}

	if (![self hasExtraEquipment:eq_type])
	{
		[self addExtraEquipment:eq_type];
	}

}


- (void) removeEquipment:(NSString *)equipString  //eg. EQ_NAVAL_ENERGY_UNIT
{
	NSString*   eq_type		= equipString;

	if (script_target != self)  return;

	if ([eq_type isEqual:@"EQ_FUEL"])
	{
		fuel = 0;
		return;
	}

	if ([self hasExtraEquipment:eq_type])
	{
		[self removeExtraEquipment:eq_type];
	}

}


- (void) setPlanetinfo:(NSString *)key_valueString	// uses key=value format
{
	NSArray*	tokens = [[key_valueString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@"="];
	NSString*   keyString = nil;
	NSString*	valueString = nil;

	if ([tokens count] != 2)
	{
		OOLog(kOOLogSyntaxSetPlanetInfo, @"***** CANNOT setPlanetinfo: '%@' (bad parameter count)", key_valueString);
		return;
	}

	keyString = [(NSString*)[tokens objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	valueString = [(NSString*)[tokens objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

	[UNIVERSE setSystemDataKey:keyString value:valueString];

}


- (void) setSpecificPlanetInfo:(NSString *)key_valueString  // uses galaxy#=planet#=key=value
{
	NSArray*	tokens = [[key_valueString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@"="];
	NSString*   keyString = nil;
	NSString*	valueString = nil;
	int gnum, pnum;

	if ([tokens count] != 4)
	{
		OOLog(kOOLogSyntaxSetPlanetInfo, @"***** CANNOT setSpecificPlanetInfo: '%@' (bad parameter count)", key_valueString);
		return;
	}

	gnum = [(NSString*)[tokens objectAtIndex:0] intValue];
	pnum = [(NSString*)[tokens objectAtIndex:1] intValue];
	keyString = [(NSString*)[tokens objectAtIndex:2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	valueString = [(NSString*)[tokens objectAtIndex:3] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

	[UNIVERSE setSystemDataForGalaxy:gnum planet:pnum key:keyString value:valueString];
}


- (void) awardCargo:(NSString *)amount_typeString
{
	if (script_target != self)  return;

	NSArray					*tokens = ScanTokensFromString(amount_typeString);
	NSString				*typeString = nil;
	OOCargoQuantityDelta	amount;
	OOCargoType				type;
	OOMassUnit				unit;
	NSArray					*commodityArray = nil;
	NSString				*cargoString = nil;

	if ([tokens count] != 2)
	{
		OOLog(kOOLogSyntaxAwardCargo, @"***** CANNOT awardCargo: '%@' (%@)",amount_typeString, @"bad parameter count");
		return;
	}
	
	typeString = [tokens objectAtIndex:1];
	type = [UNIVERSE commodityForName:typeString];
	if (type == NSNotFound)  type = [typeString intValue];
	
	commodityArray = [UNIVERSE commidityDataForType:type];
	
	if (commodityArray == nil)
	{
		OOLog(kOOLogSyntaxAwardCargo, @"***** CANNOT awardCargo: '%@' (%@)", amount_typeString, @"unknown type");
		return;
	}
	
	amount = [tokens intAtIndex:0];
	if (amount < 0)
	{
		OOLog(kOOLogSyntaxAwardCargo, @"***** CANNOT awardCargo: '%@' (%@)", amount_typeString, @"negative quantity");
		return;
	}
	
	cargoString = [commodityArray objectAtIndex:MARKET_NAME];

	OOLog(kOOLogNoteAwardCargo, @"Going to award cargo: %d x '%@'", amount, cargoString);

	unit = [commodityArray intAtIndex:MARKET_UNITS];
	
	if (status != STATUS_DOCKED)
	{	// in-flight
		while (amount)
		{
			if (unit != UNITS_TONS)
			{
				int amount_per_container = (unit == UNITS_KILOGRAMS)? 1000 : 1000000;
				while (amount > 0)
				{
					int smaller_quantity = 1 + ((amount - 1) % amount_per_container);
					if ([cargo count] < max_cargo)
					{
						ShipEntity* container = [UNIVERSE newShipWithRole:@"cargopod"];
						if (container)
						{
							// Shouldn't there be a [UNIVERSE addEntity:] here? -- Ahruman
							[container wasAddedToUniverse];
							[container setScanClass: CLASS_CARGO];
							[container setCommodity:type andAmount:smaller_quantity];
							[cargo addObject:container];
							[container release];
						}
					}
					amount -= smaller_quantity;
				}
			}
			else
			{
				// put each ton in a separate container
				while (amount)
				{
					if ([cargo count] < max_cargo)
					{
						ShipEntity* container = [UNIVERSE newShipWithRole:@"cargopod"];
						if (container)
						{
							// Shouldn't there be a [UNIVERSE addEntity:] here? -- Ahruman
							[container wasAddedToUniverse];
							[container setScanClass: CLASS_CARGO];
							[container setStatus:STATUS_IN_HOLD];
							[container setCommodity:type andAmount:1];
							[cargo addObject:container];
							[container release];
						}
					}
					amount--;
				}
			}
		}
	}
	else
	{	// docked
		// like purchasing a commodity
		NSMutableArray* manifest =  [NSMutableArray arrayWithArray:shipCommodityData];
		NSMutableArray* manifest_commodity =	[NSMutableArray arrayWithArray:(NSArray *)[manifest objectAtIndex:type]];
		int manifest_quantity = [(NSNumber *)[manifest_commodity objectAtIndex:MARKET_QUANTITY] intValue];
		while ((amount)&&(current_cargo < max_cargo))
		{
			manifest_quantity++;
			amount--;
			if (unit == UNITS_TONS)
				current_cargo++;
		}
		[manifest_commodity replaceObjectAtIndex:MARKET_QUANTITY withObject:[NSNumber numberWithInt:manifest_quantity]];
		[manifest replaceObjectAtIndex:type withObject:[NSArray arrayWithArray:manifest_commodity]];
		[shipCommodityData release];
		shipCommodityData = [[NSArray arrayWithArray:manifest] retain];
	}
}


- (void) removeAllCargo
{
	OOCargoType				type;
	OOMassUnit				unit;
	
	if (script_target != self)  return;
	if (status != STATUS_DOCKED)
	{
		OOLog(kOOLogRemoveAllCargoNotDocked, @"***** Error: removeAllCargo only works when docked.");
		return;
	}
	
	OOLog(kOOLogNoteRemoveAllCargo, @"Going to removeAllCargo");
	
	NSMutableArray *manifest = [NSMutableArray arrayWithArray:shipCommodityData];
	for (type = 0; type < (OOCargoType)[manifest count]; type++)
	{
		NSMutableArray *manifest_commodity = [NSMutableArray arrayWithArray:[manifest arrayAtIndex:type]];
		unit = [manifest_commodity intAtIndex:MARKET_UNITS];
		if (unit == UNITS_TONS)
		{
			[manifest_commodity replaceObjectAtIndex:MARKET_QUANTITY withObject:[NSNumber numberWithInt:0]];
			[manifest replaceObjectAtIndex:type withObject:[NSArray arrayWithArray:manifest_commodity]];
		}
	}
	
	[shipCommodityData release];
	shipCommodityData = [manifest mutableCopy];
	
	[specialCargo release];
	specialCargo = nil;
}


- (void) useSpecialCargo:(NSString *)descriptionString;
{

	if (script_target != self)  return;

	[self removeAllCargo];
	specialCargo = [ExpandDescriptionForCurrentSystem(descriptionString) retain];
	//
	OOLog(kOOLogNoteUseSpecialCargo, @"Going to useSpecialCargo:'%@'", specialCargo);
}


- (void) testForEquipment:(NSString *)equipString	//eg. EQ_NAVAL_ENERGY_UNIT
{
	found_equipment = [self hasExtraEquipment:equipString];
}


- (void) awardFuel:(NSString *)valueString	// add to fuel up to 7.0 LY
{
	int delta  = 10 * [valueString floatValue];
	if (delta < 0 && fuel < (unsigned)-delta)  fuel = 0;
	else
	{
		fuel += delta;
		if (fuel > PLAYER_MAX_FUEL)  fuel = PLAYER_MAX_FUEL;
	}
}


- (void) messageShipAIs:(NSString *)roles_message
{
	NSMutableArray*	tokens = ScanTokensFromString(roles_message);
	NSString*   roleString = nil;
	NSString*	messageString = nil;

	if ([tokens count] < 2)
	{
		OOLog(kOOLogSyntaxMessageShipAIs, @"***** CANNOT messageShipAIs: '%@' (bad parameter count)",roles_message);
		return;
	}

	roleString = (NSString *)[tokens objectAtIndex:0];
	[tokens removeObjectAtIndex:0];
	messageString = [tokens componentsJoinedByString:@" "];

	[UNIVERSE sendShipsWithRole:roleString messageToAI:messageString];
}


- (void) ejectItem:(NSString *)item_key
{
	ShipEntity* item = [UNIVERSE newShipWithName:item_key];
	if (script_target == nil)
		script_target = self;
	if (item)
		[script_target dumpItem:item];
}


- (void) addShips:(NSString *)roles_number
{
	NSMutableArray*	tokens = ScanTokensFromString(roles_number);
	NSString*   roleString = nil;
	NSString*	numberString = nil;

	if ([tokens count] != 2)
	{
		OOLog(kOOLogSyntaxAddShips, @"***** CANNOT addShips: '%@' - MUST BE '<role> <number>'",roles_number);
		return;
	}

	roleString = (NSString *)[tokens objectAtIndex:0];
	numberString = (NSString *)[tokens objectAtIndex:1];

	int number = [numberString intValue];
	if (number < 0)
	{
		OOLog(kOOLogSyntaxAddShips, @"***** Can't add %u ships -- that's less than zero, y'know.", number);
		return;
	}
	
	OOLog(kOOLogNoteAddShips, @"DEBUG ..... Going to add %d ships with role '%@'", number, roleString);

	while (number--)
		[UNIVERSE witchspaceShipWithRole:roleString];
}


- (void) addSystemShips:(NSString *)roles_number_position
{
	NSMutableArray*	tokens = ScanTokensFromString(roles_number_position);
	NSString*   roleString = nil;
	NSString*	numberString = nil;
	NSString*	positionString = nil;

	if ([tokens count] != 3)
	{
		OOLog(kOOLogSyntaxAddShips, @"***** CANNOT addSystemShips: '%@' (bad parameter count)",roles_number_position);
		return;
	}

	roleString = (NSString *)[tokens objectAtIndex:0];
	numberString = (NSString *)[tokens objectAtIndex:1];
	positionString = (NSString *)[tokens objectAtIndex:2];

	int number = [numberString intValue];
	double posn = [positionString doubleValue];
	if (number < 0)
	{
		OOLog(kOOLogSyntaxAddShips, @"***** Can't add %u ships -- that's less than zero, y'know.", number);
		return;
	}

	OOLog(kOOLogNoteAddShips, @"DEBUG Going to add %d ships with role '%@' at a point %.3f along route1", number, roleString, posn);

	while (number--)
		[UNIVERSE addShipWithRole:roleString nearRouteOneAt:posn];
}


- (void) addShipsAt:(NSString *)roles_number_system_x_y_z
{
	NSMutableArray*	tokens = ScanTokensFromString(roles_number_system_x_y_z);

	NSString*   roleString = nil;
	NSString*	numberString = nil;
	NSString*	systemString = nil;
	NSString*	xString = nil;
	NSString*	yString = nil;
	NSString*	zString = nil;

	if ([tokens count] != 6)
	{
		OOLog(kOOLogSyntaxAddShips, @"***** CANNOT addShipsAt: '%@' (bad parameter count)", roles_number_system_x_y_z);
		return;
	}

	roleString = [tokens objectAtIndex:0];
	numberString = [tokens objectAtIndex:1];
	systemString = [tokens objectAtIndex:2];
	xString = [tokens objectAtIndex:3];
	yString = [tokens objectAtIndex:4];
	zString = [tokens objectAtIndex:5];

	Vector posn = make_vector( [xString floatValue], [yString floatValue], [zString floatValue]);

	int number = [numberString intValue];
	if (number < 0)
	{
		OOLog(kOOLogSyntaxAddShips, @"***** Can't add %u ships -- that's less than zero, y'know.", number);
		return;
	}

	OOLog(kOOLogNoteAddShips, @"DEBUG Going to add %d ship(s) with role '%@' at point (%.3f, %.3f, %.3f) using system %@", number, roleString, posn.x, posn.y, posn.z, systemString);

	if (![UNIVERSE addShips: number withRole:roleString nearPosition: posn withCoordinateSystem: systemString])
	{
		OOLog(kOOLogScriptAddShipsFailed, @"***** CANNOT addShipsAt: '%@' (should be addShipsAt: role number coordinate_system x y z)",roles_number_system_x_y_z);
	}
}


- (void) addShipsAtPrecisely:(NSString *)roles_number_system_x_y_z
{
	NSMutableArray*	tokens = ScanTokensFromString(roles_number_system_x_y_z);

	NSString*   roleString = nil;
	NSString*	numberString = nil;
	NSString*	systemString = nil;
	NSString*	xString = nil;
	NSString*	yString = nil;
	NSString*	zString = nil;

	if ([tokens count] != 6)
	{
		OOLog(kOOLogSyntaxAddShips, @"***** CANNOT addShipsAtPrecisely: '%@' (bad parameter count)",roles_number_system_x_y_z);
		return;
	}

	roleString = (NSString *)[tokens objectAtIndex:0];
	numberString = (NSString *)[tokens objectAtIndex:1];
	systemString = (NSString *)[tokens objectAtIndex:2];
	xString = (NSString *)[tokens objectAtIndex:3];
	yString = (NSString *)[tokens objectAtIndex:4];
	zString = (NSString *)[tokens objectAtIndex:5];

	Vector posn = make_vector( [xString floatValue], [yString floatValue], [zString floatValue]);

	int number = [numberString intValue];
	if (number < 0)
	{
		OOLog(kOOLogSyntaxAddShips, @"***** Can't add %u ships -- that's less than zero, y'know.", number);
		return;
	}

	OOLog(kOOLogNoteAddShips, @"DEBUG Going to add %d ship(s) with role '%@' precisely at point (%.3f, %.3f, %.3f) using system %@", number, roleString, posn.x, posn.y, posn.z, systemString);

	if (![UNIVERSE addShips: number withRole:roleString atPosition: posn withCoordinateSystem: systemString])
	{
		OOLog(kOOLogScriptAddShipsFailed, @"***** CANNOT addShipsAtPrecisely: '%@' (should be addShipsAt: role number coordinate_system x y z)",roles_number_system_x_y_z);
	}
}


- (void) addShipsWithinRadius:(NSString *)roles_number_system_x_y_z_r
{
	NSMutableArray*	tokens = ScanTokensFromString(roles_number_system_x_y_z_r);

	if ([tokens count] != 7)
	{
		OOLog(kOOLogSyntaxAddShips, @"***** CANNOT 'addShipsWithinRadius: %@' (should be 'addShipsWithinRadius: role number coordinate_system x y z r')",roles_number_system_x_y_z_r);
		return;
	}

	NSString* roleString = (NSString *)[tokens objectAtIndex:0];
	int number = [[tokens objectAtIndex:1] intValue];
	NSString* systemString = (NSString *)[tokens objectAtIndex:2];
	GLfloat x = [[tokens objectAtIndex:3] floatValue];
	GLfloat y = [[tokens objectAtIndex:4] floatValue];
	GLfloat z = [[tokens objectAtIndex:5] floatValue];
	GLfloat r = [[tokens objectAtIndex:6] floatValue];
	Vector posn = make_vector( x, y, z);

	if (number < 0)
	{
		OOLog(kOOLogSyntaxAddShips, @"***** Can't add %u ships -- that's less than zero, y'know.", number);
		return;
	}

	OOLog(kOOLogNoteAddShips, @"DEBUG Going to add %d ship(s) with role '%@' within %.2f radius about point (%.3f, %.3f, %.3f) using system %@", number, roleString, r, x, y, z, systemString);

	if (![UNIVERSE addShips:number withRole: roleString nearPosition: posn withCoordinateSystem: systemString withinRadius: r])
	{
		OOLog(kOOLogScriptAddShipsFailed, @"***** CANNOT 'addShipsWithinRadius: %@' (should be 'addShipsWithinRadius: role number coordinate_system x y z r')",roles_number_system_x_y_z_r);
	}
}


- (void) spawnShip:(NSString *)ship_key
{
	if ([UNIVERSE spawnShip:ship_key])
	{
		OOLog(kOOLogNoteAddShips, @"DEBUG Spawned ship with shipdata key '%@'.", ship_key);
	}
	else
	{
		OOLog(kOOLogScriptAddShipsFailed, @"***** Could not spawn ship with shipdata key '%@'.", ship_key);
	}
}


- (void) set:(NSString *)missionvariable_value
{
	NSMutableArray*	tokens = ScanTokensFromString(missionvariable_value);
	NSMutableDictionary* locals = [local_variables objectForKey:mission_key];
	NSString*   missionVariableString = nil;
	NSString*	valueString = nil;
	BOOL hasMissionPrefix, hasLocalPrefix;

	if ([tokens count] < 2)
	{
		OOLog(kOOLogSyntaxSet, @"***** CANNOT SET: '%@'", missionvariable_value);
		return;
	}

	missionVariableString = (NSString *)[tokens objectAtIndex:0];
	[tokens removeObjectAtIndex:0];
	valueString = [tokens componentsJoinedByString:@" "];

	hasMissionPrefix = [missionVariableString hasPrefix:@"mission_"];
	hasLocalPrefix = [missionVariableString hasPrefix:@"local_"];

	if (hasMissionPrefix != YES && hasLocalPrefix != YES)
	{
		OOLog(kOOLogSyntaxSet, @"***** IDENTIFIER '%@' DOES NOT BEGIN WITH 'mission_' or 'local_'", missionVariableString);
		return;
	}

	OOLog(kOOLogNoteSet, @"SCRIPT %@ is set to %@", missionVariableString, valueString);
	
	if (hasMissionPrefix)
		[mission_variables setObject:valueString forKey:missionVariableString];
	else
		[locals setObject:valueString forKey:missionVariableString];
}


- (void) reset:(NSString *)missionvariable
{
	NSString*   missionVariableString = [missionvariable stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	BOOL hasMissionPrefix, hasLocalPrefix;

	hasMissionPrefix = [missionVariableString hasPrefix:@"mission_"];
	hasLocalPrefix = [missionVariableString hasPrefix:@"local_"];

	if (hasMissionPrefix)
	{
		[mission_variables removeObjectForKey:missionVariableString];
	}
	else if (hasLocalPrefix)
	{
		NSMutableDictionary* locals = [local_variables objectForKey:mission_key];
		[locals removeObjectForKey:missionVariableString];
	}
	else
	{
		OOLog(kOOLogSyntaxReset, @"***** IDENTIFIER '%@' DOES NOT BEGIN WITH 'mission_' or 'local_'", missionVariableString);
	}
}


- (void) increment:(NSString *)missionVariableString
{
	BOOL hasMissionPrefix, hasLocalPrefix;
	int value = 0;

	hasMissionPrefix = [missionVariableString hasPrefix:@"mission_"];
	hasLocalPrefix = [missionVariableString hasPrefix:@"local_"];

	if (hasMissionPrefix)
	{
		if ([mission_variables objectForKey:missionVariableString])
			value = [(NSString *)[mission_variables objectForKey:missionVariableString] intValue];
		value++;
		[mission_variables setObject:[NSString stringWithFormat:@"%d", value] forKey:missionVariableString];
	}
	else if (hasLocalPrefix)
	{
		NSMutableDictionary* locals = [local_variables objectForKey:mission_key];
		if ([locals objectForKey:missionVariableString])
			value = [(NSString *)[locals objectForKey:missionVariableString] intValue];
		value++;
		[locals setObject:[NSString stringWithFormat:@"%d", value] forKey:missionVariableString];
	}
}


- (void) decrement:(NSString *)missionVariableString
{
	BOOL hasMissionPrefix, hasLocalPrefix;
	int value = 0;

	hasMissionPrefix = [missionVariableString hasPrefix:@"mission_"];
	hasLocalPrefix = [missionVariableString hasPrefix:@"local_"];

	if (hasMissionPrefix)
	{
		if ([mission_variables objectForKey:missionVariableString])
			value = [(NSString *)[mission_variables objectForKey:missionVariableString] intValue];
		value--;
		[mission_variables setObject:[NSString stringWithFormat:@"%d", value] forKey:missionVariableString];
	}
	else if (hasLocalPrefix)
	{
		NSMutableDictionary* locals = [local_variables objectForKey:mission_key];
		if ([locals objectForKey:missionVariableString])
			value = [(NSString *)[locals objectForKey:missionVariableString] intValue];
		value--;
		[locals setObject:[NSString stringWithFormat:@"%d", value] forKey:missionVariableString];
	}
}


- (void) add:(NSString *)missionVariableString_value
{
	NSString*   missionVariableString = nil;
	NSString*   valueString;
	double	value;
	NSMutableArray*	tokens = ScanTokensFromString(missionVariableString_value);
	NSMutableDictionary* locals = [local_variables objectForKey:mission_key];
	BOOL hasMissionPrefix, hasLocalPrefix;

	if ([tokens count] < 2)
	{
		NSLog(@"***** CANNOT ADD: '%@'",missionVariableString_value);
		return;
	}

	missionVariableString = (NSString *)[tokens objectAtIndex:0];
	[tokens removeObjectAtIndex:0];
	valueString = [tokens componentsJoinedByString:@" "];

	hasMissionPrefix = [missionVariableString hasPrefix:@"mission_"];
	hasLocalPrefix = [missionVariableString hasPrefix:@"local_"];

	if (hasMissionPrefix)
	{
		value = [[mission_variables objectForKey:missionVariableString] doubleValue];
		value += [valueString doubleValue];

		[mission_variables setObject:[NSString stringWithFormat:@"%f", value] forKey:missionVariableString];
	}
	else if (hasLocalPrefix)
	{
		value = [[locals objectForKey:missionVariableString] doubleValue];
		value += [valueString doubleValue];

		[locals setObject:[NSString stringWithFormat:@"%f", value] forKey:missionVariableString];
	}
	else
	{
		NSLog(@"***** CANNOT ADD: '%@'",missionVariableString_value);
		NSLog(@"***** IDENTIFIER '%@' DOES NOT BEGIN WITH 'mission_' or 'local_'",missionVariableString);
	}
}


- (void) subtract:(NSString *)missionVariableString_value
{
	NSString*   missionVariableString = nil;
	NSString*   valueString;
	double	value;
	NSMutableArray*	tokens = ScanTokensFromString(missionVariableString_value);
	NSMutableDictionary* locals = [local_variables objectForKey:mission_key];
	BOOL hasMissionPrefix, hasLocalPrefix;

	if ([tokens count] < 2)
	{
		NSLog(@"***** CANNOT SUBTRACT: '%@'",missionVariableString_value);
		return;
	}

	missionVariableString = (NSString *)[tokens objectAtIndex:0];
	[tokens removeObjectAtIndex:0];
	valueString = [tokens componentsJoinedByString:@" "];

	hasMissionPrefix = [missionVariableString hasPrefix:@"mission_"];
	hasLocalPrefix = [missionVariableString hasPrefix:@"local_"];

	if (hasMissionPrefix)
	{
		value = [[mission_variables objectForKey:missionVariableString] doubleValue];
		value -= [valueString doubleValue];

		[mission_variables setObject:[NSString stringWithFormat:@"%f", value] forKey:missionVariableString];
	}
	else if (hasLocalPrefix)
	{
		value = [[locals objectForKey:missionVariableString] doubleValue];
		value -= [valueString doubleValue];

		[locals setObject:[NSString stringWithFormat:@"%f", value] forKey:missionVariableString];
	}
	else
	{
		NSLog(@"***** CANNOT SUBTRACT: '%@'",missionVariableString_value);
		NSLog(@"***** IDENTIFIER '%@' DOES NOT BEGIN WITH 'mission_' or 'local_'",missionVariableString);
	}
}


- (void) checkForShips: (NSString *)roleString
{
	shipsFound = [UNIVERSE countShipsWithRole:roleString];
}


- (void) resetScriptTimer
{
	script_time = 0.0;
	script_time_check = SCRIPT_TIMER_INTERVAL;
	script_time_interval = SCRIPT_TIMER_INTERVAL;
}


- (void) addMissionText: (NSString *)textKey
{
	if ([textKey isEqual:lastTextKey])
		return; // don't repeatedly add the same text
	//
	GuiDisplayGen   *gui =  [UNIVERSE gui];
	NSString		*text = (NSString *)[[UNIVERSE missiontext] objectForKey:textKey];
	text = ExpandDescriptionForCurrentSystem(text);
	text = [self replaceVariablesInString: text];
	
	NSArray			*paras = [text componentsSeparatedByString:@"\\n"];
	if (text)
	{
		unsigned i;
		for (i = 0; i < [paras count]; i++)
			missionTextRow = [gui addLongText:[self replaceVariablesInString:(NSString *)[paras objectAtIndex:i]] startingAtRow:missionTextRow align:GUI_ALIGN_LEFT];
	}
	if (lastTextKey)
		[lastTextKey release];
	lastTextKey = [[NSString stringWithString:textKey] retain];  //
}


- (void) setMissionChoices:(NSString *)choicesKey	// choicesKey is a key for a dictionary of
{													// choices/choice phrases in missiontext.plist and also..
	GuiDisplayGen* gui = [UNIVERSE gui];
	// TODO: MORE STUFF HERE
	// must find list of choices in missiontext.plist
	// add them to gui setting the key for each line to the key in the dict of choices
	// and the text of the line to the value in the dict of choices
	// and also set the selectable range
	// ++ change the mission screen's response to wait for a choice
	// and only if the selectable range is not present ask:
	// Press Space Commander...
	//
	NSDictionary* choices_dict = (NSDictionary *)[[UNIVERSE missiontext] objectForKey:choicesKey];
	if ((choices_dict == nil)||([choices_dict count] == 0))
		return;
	//
	NSArray* choice_keys = [choices_dict allKeys];
	//
	[gui setText:@"" forRow:21];			// clears out the 'Press spacebar' message
	[gui setKey:@"" forRow:21];				// clears the key to enable pollDemoControls to check for a selection
	[gui setSelectableRange:NSMakeRange(0,0)];	// clears the selectable range
	//
	int					choices_row = 22 - [choice_keys count];
	NSEnumerator		*choiceEnum = nil;
	NSString			*choiceKey = nil;
	NSString			*choiceText = nil;
	
	for (choiceEnum = [choice_keys objectEnumerator]; (choiceKey = [choiceEnum nextObject]); )
	{
		choiceText = [NSString stringWithFormat:@" %@ ",[choices_dict objectForKey:choiceKey]];
		choiceText = ExpandDescriptionForCurrentSystem(choiceText);
		choiceText = [self replaceVariablesInString:choiceText];
		[gui setText:choiceText forRow:choices_row align: GUI_ALIGN_CENTER];
		[gui setKey:choiceKey forRow:choices_row];
		[gui setColor:[OOColor yellowColor] forRow:choices_row];
		choices_row++;
	}
	//
	[gui setSelectableRange:NSMakeRange( 22 - [choice_keys count], [choice_keys count])];
	[gui setSelectedRow: 22 - [choice_keys count]];
	//
	[self resetMissionChoice];						// resets MissionChoice to nil
}


- (void) resetMissionChoice							// resets MissionChoice to nil
{
	if (missionChoice)
		[missionChoice release];
	missionChoice = nil;
}


- (void) addMissionDestination:(NSString *)destinations
{
	unsigned i, j;
	NSNumber *pnump;
	int pnum, dest;
	NSMutableArray*	tokens = ScanTokensFromString(destinations);
	BOOL addDestination;

	for (j = 0; j < [tokens count]; j++)
	{
		dest = [(NSString *)[tokens objectAtIndex:j] intValue];
		if (dest < 0 || dest > 255)
			continue;

		addDestination = YES;
		for (i = 0; i < [missionDestinations count]; i++)
		{
			pnump = (NSNumber *)[missionDestinations objectAtIndex:i];
			pnum = [pnump intValue];
			if (pnum == dest)
			{
				addDestination = NO;
				break;
			}
		}

		if (addDestination == YES)
			[missionDestinations addObject:[NSNumber numberWithUnsignedInt:dest]];
	}
}


- (void) removeMissionDestination:(NSString *)destinations
{
	unsigned			i, j;
	NSNumber			*pnump = nil;
	int					pnum, dest;
	NSMutableArray		*tokens = ScanTokensFromString(destinations);
	BOOL				removeDestination;

	for (j = 0; j < [tokens count]; j++)
	{
		dest = [(NSString *)[tokens objectAtIndex:j] intValue];
		if (dest < 0 || dest > 255)
			continue;

		removeDestination = NO;
		for (i = 0; i < [missionDestinations count]; i++)
		{
			pnump = (NSNumber *)[missionDestinations objectAtIndex:i];
			pnum = [pnump intValue];
			if (pnum == dest)
			{
				removeDestination = YES;
				break;
			}
		}

		if (removeDestination == YES)
			[missionDestinations removeObjectAtIndex:i];
	}
}


- (void) showShipModel: (NSString *)shipKey
{
	ShipEntity		*ship;

	if (!docked_station)
		return;

	[UNIVERSE removeDemoShips];	// get rid of any pre-existing models on display

	Quaternion		q2 = { (GLfloat)0.707, (GLfloat)0.707, (GLfloat)0.0, (GLfloat)0.0};

	ship = [UNIVERSE newShipWithRole: shipKey];   // retain count = 1
	if (ship)
	{
		double cr = ship->collision_radius;
		OOLog(kOOLogNoteShowShipModel, @"::::: showShipModel:'%@' (%@) (%@)", shipKey, ship, [ship name]);
		[ship setOrientation: q2];
		[ship setStatus: STATUS_COCKPIT_DISPLAY];
		[ship setPositionX:0.0f y:0.0f z:3.6f * cr];
		[ship setScanClass: CLASS_NO_DRAW];
		[ship setRoll: M_PI/5.0];
		[ship setPitch: M_PI/10.0];
		[UNIVERSE addEntity: ship];
		[[ship getAI] setStateMachine: @"nullAI.plist"];

		[ship release];
	}
	//
}


- (void) setMissionMusic: (NSString *)value
{
	[missionMusic release];
	if (NSOrderedSame == [value caseInsensitiveCompare:@"none"])
	{
		missionMusic = nil;
	}
	else
	{
		missionMusic =  [[ResourceManager ooMusicNamed:value inFolder:@"Music"] retain];
	}
}


- (void) setMissionImage: (NSString *)value
{
	[missionBackgroundTexture release];
	missionBackgroundTexture = nil;
	
	if (![[value lowercaseString] isEqual:@"none"])
 	{
		missionBackgroundTexture = [OOTexture textureWithName:value inFolder:@"Images"];
		[missionBackgroundTexture retain];
 	}
}


- (void) setFuelLeak: (NSString *)value
{
	fuel_leak_rate = [value doubleValue];
	if (fuel_leak_rate > 0)
	{
		if (![UNIVERSE playCustomSound:@"[fuel-leak]"])
			[self warnAboutHostiles];
		[UNIVERSE addMessage:@"Danger! Fuel leak!" forCount:6];
		OOLog(kOOLogNoteFuelLeak, @"FUEL LEAK activated!");
	}
}


- (NSNumber *) fuel_leak_rate_number
{
    return [NSNumber numberWithFloat:fuel_leak_rate];
}


- (void) setSunNovaIn: (NSString *)time_value
{
	double time_until_nova = [time_value doubleValue];
	[[UNIVERSE sun] setGoingNova:YES inTime: time_until_nova];
	OOLog(kOOLogDebugSetSunNovaIn, @"NOVA activated! time until Nova : %.1f s", time_until_nova);
}


- (void) launchFromStation
{
	[self leaveDock:docked_station];
	[UNIVERSE setDisplayCursor:NO];
	[breakPatternSound play];
}


- (void) blowUpStation
{
	[[UNIVERSE station] takeEnergyDamage:500000000.0 from:nil becauseOf:nil];	// 500 million should do it!
}


- (void) sendAllShipsAway
{
	if (!UNIVERSE)
		return;
	int			ent_count =		UNIVERSE->n_entities;
	Entity**	uni_entities =	UNIVERSE->sortedEntities;	// grab the public sorted list
	Entity*		my_entities[ent_count];
	int i;
	for (i = 0; i < ent_count; i++)
		my_entities[i] = [uni_entities[i] retain];		//	retained

	for (i = 1; i < ent_count; i++)
	{
		Entity* e1 = my_entities[i];
		if (e1->isShip)
		{
			ShipEntity* se1 = (ShipEntity*)e1;
			int e_class = e1->scanClass;
			if ((e_class == CLASS_NEUTRAL)||(e_class == CLASS_POLICE)||(e_class == CLASS_MILITARY)||(e_class == CLASS_THARGOID))
			{
				AI*	se1AI = [se1 getAI];
				[se1 setFuel: PLAYER_MAX_FUEL];
				[se1AI setStateMachine:@"exitingTraderAI.plist"];
				[se1AI setState:@"EXIT_SYSTEM"];
				[se1AI reactToMessage:[NSString stringWithFormat:@"pauseAI: %d", 3 + (ranrot_rand() & 15)]];
				[se1 setRoles:@"none"];	// prevents new ship from appearing at witchpoint when this one leaves!
			}
		}
	}
	for (i = 0; i < ent_count; i++)
		[my_entities[i] release];		//	released
}


- (void) addPlanet: (NSString *)planetKey
{
	OOLog(kOOLogNoteAddPlanet, @"addPlanet: %@", planetKey);

	if (!UNIVERSE)
		return;
	NSDictionary* dict = (NSDictionary*)[[UNIVERSE planetinfo] objectForKey:planetKey];
	if (!dict)
	{
		NSLog(@"ERROR - could not find an entry in planetinfo.plist for '%@'", planetKey);
		return;
	}

	/*- add planet -*/
	OOLog(kOOLogDebugAddPlanet, @"DEBUG initPlanetFromDictionary: %@", dict);
	PlanetEntity*	planet = [[[PlanetEntity alloc] initPlanetFromDictionary:dict] autorelease];
	[planet setStatus:STATUS_ACTIVE];
	
	Quaternion planetOrientation;
	if (ScanQuaternionFromString([dict objectForKey:@"orientation"], &planetOrientation))
	{
		[planet setOrientation:planetOrientation];
	}

	if (![dict objectForKey:@"position"])
	{
		NSLog(@"ERROR - you must specify a position for scripted planet '%@' before it can be created", planetKey);
		return;
	}
	
	NSString *positionString = [dict objectForKey:@"position"];
	Vector posn = [UNIVERSE coordinatesFromCoordinateSystemString:positionString];
	if (posn.x || posn.y || posn.z)
	{
		OOLog(kOOLogDebugAddPlanet, @"planet position (%.2f %.2f %.2f) derived from %@", posn.x, posn.y, posn.z, positionString);
	}
	else
	{
		ScanVectorFromString(positionString, &posn);
		OOLog(kOOLogDebugAddPlanet, @"planet position (%.2f %.2f %.2f) derived from %@", posn.x, posn.y, posn.z, positionString);
	}
	[planet setPosition: posn];
	
	[UNIVERSE addEntity:planet];
}


- (void) addMoon: (NSString *)moonKey
{
	OOLog(kOOLogNoteAddPlanet, @"DEBUG addMoon: %@", moonKey);

	if (!UNIVERSE)
		return;
	NSDictionary* dict = (NSDictionary*)[[UNIVERSE planetinfo] objectForKey:moonKey];
	if (!dict)
	{
		NSLog(@"ERROR - could not find an entry in planetinfo.plist for '%@'", moonKey);
		return;
	}

	OOLog(kOOLogDebugAddPlanet, @"DEBUG initMoonFromDictionary: %@", dict);
	PlanetEntity*	planet = [[[PlanetEntity alloc] initMoonFromDictionary:dict] autorelease];
	[planet setStatus:STATUS_ACTIVE];
	
	Quaternion planetOrientation;
	if (ScanQuaternionFromString([dict objectForKey:@"orientation"], &planetOrientation))
	{
		[planet setOrientation:planetOrientation];
	}

	if (![dict objectForKey:@"position"])
	{
		NSLog(@"ERROR - you must specify a position for scripted moon '%@' before it can be created", moonKey);
		return;
	}
	
	NSString *positionString = [dict objectForKey:@"position"];
	Vector posn = [UNIVERSE coordinatesFromCoordinateSystemString:positionString];
	if (posn.x || posn.y || posn.z)
	{
		OOLog(kOOLogDebugAddPlanet, @"moon position (%.2f %.2f %.2f) derived from %@", posn.x, posn.y, posn.z, positionString);
	}
	else
	{
		ScanVectorFromString(positionString, &posn);
		OOLog(kOOLogDebugAddPlanet, @"moon position (%.2f %.2f %.2f) derived from %@", posn.x, posn.y, posn.z, positionString);
	}
	[planet setPosition: posn];
	
	[UNIVERSE addEntity:planet];
}


- (void) debugOn
{
	OOLogSetDisplayMessagesInClass(kOOLogDebugOnMetaClass, YES);
	OOLog(kOOLogDebugOnOff, @"SCRIPT debug messages ON");
}


- (void) debugOff
{
	OOLog(kOOLogDebugOnOff, @"SCRIPT debug messages OFF");
	OOLogSetDisplayMessagesInClass(kOOLogDebugOnMetaClass, NO);
}


- (void) debugMessage:(NSString *)args
{
	OOLog(kOOLogDebugMessage, @"SCRIPT debugMessage: %@", args);
}


- (NSString*) replaceVariablesInString:(NSString*) args
{
	NSMutableDictionary	*locals = [local_variables objectForKey:mission_key];
	NSMutableString		*resultString = [NSMutableString stringWithString: args];
	NSString			*valueString;
	unsigned			i;
	NSMutableArray		*tokens = ScanTokensFromString(args);

	for (i = 0; i < [tokens  count]; i++)
	{
		valueString = (NSString *)[tokens objectAtIndex:i];

		if ([mission_variables objectForKey:valueString])
		{
			[resultString replaceOccurrencesOfString:valueString withString:[mission_variables objectForKey:valueString] options:NSLiteralSearch range:NSMakeRange(0, [resultString length])];
		}
		else if ([locals objectForKey:valueString])
		{
			[resultString replaceOccurrencesOfString:valueString withString:[locals objectForKey:valueString] options:NSLiteralSearch range:NSMakeRange(0, [resultString length])];
		}
		else if (([valueString hasSuffix:@"_number"])||([valueString hasSuffix:@"_bool"])||([valueString hasSuffix:@"_string"]))
		{
			SEL value_selector = NSSelectorFromString(valueString);
			if ([self respondsToSelector:value_selector])
			{
				[resultString replaceOccurrencesOfString:valueString withString:[NSString stringWithFormat:@"%@", [self performSelector:value_selector]] options:NSLiteralSearch range:NSMakeRange(0, [resultString length])];
			}
		}
		else if ([valueString hasPrefix:@"["]&&[valueString hasSuffix:@"]"])
		{
			NSString* replaceString = ExpandDescriptionForCurrentSystem(valueString);
			[resultString replaceOccurrencesOfString:valueString withString:replaceString options:NSLiteralSearch range:NSMakeRange(0, [resultString length])];
		}
	}

	OOLog(kOOLogDebugReplaceVaraiblesInString, @"EXPANSION: \"%@\" becomes \"%@\"", args, resultString);

	return [NSString stringWithString: resultString];
}


- (void) playSound:(NSString *) soundName
{
	OOSound *sound = [ResourceManager ooSoundNamed:soundName inFolder:@"Sounds"];
	if (sound != nil)
		[sound play];
}

/*-----------------------------------------------------*/



- (void) setGuiToMissionScreen
{
	GuiDisplayGen* gui = [UNIVERSE gui];

	// GUI stuff
	{
		[gui clear];
		[gui setTitle:@"Mission Information"];
		//
		[gui setText:@"Press Space Commander" forRow:21 align:GUI_ALIGN_CENTER];
		[gui setColor:[OOColor yellowColor] forRow:21];
		[gui setKey:@"spacebar" forRow:21];
		//
		[gui setSelectableRange:NSMakeRange(0,0)];
		[gui setBackgroundTexture:missionBackgroundTexture];

		[gui setShowTextCursor:NO];
	}
	/* ends */

	missionTextRow = 1;

	if (gui)
		gui_screen = GUI_SCREEN_MISSION;

	if (lastTextKey)
	{
		[lastTextKey release];
		lastTextKey = nil;
	}

#ifdef GNUSTEP
//TODO: 3.???? 4. Profit!
#else
	if ((missionMusic)&&(!ootunes_on))
	{
		[missionMusic play];
	}
#endif

	// the following are necessary...
	[UNIVERSE setDisplayText:YES];
	[UNIVERSE setViewDirection:VIEW_GUI_DISPLAY];
}


- (void) setBackgroundFromDescriptionsKey:(NSString*) d_key
{
	NSArray* items = (NSArray*)[[UNIVERSE descriptions] objectForKey:d_key];
	//
	if (!items)
		return;
	//
	[self addScene: items atOffset: kZeroVector];
	//
	[self setShowDemoShips: YES];
}


- (void) addScene:(NSArray *)items atOffset:(Vector)off
{
	unsigned				i;
	
	if (items == nil)  return;
	
	for (i = 0; i < [items count]; i++)
	{
		NSObject* item = [items objectAtIndex:i];
		if ([item isKindOfClass:[NSString class]])
			[self processSceneString: (NSString*)item atOffset: off];
		if ([item isKindOfClass:[NSArray class]])
			[self addScene: (NSArray*)item atOffset: off];
		if ([item isKindOfClass:[NSDictionary class]])
			[self processSceneDictionary: (NSDictionary*) item atOffset: off];
	}
}


- (BOOL) processSceneDictionary:(NSDictionary *) couplet atOffset:(Vector) off
{
	NSArray *conditions = (NSArray *)[couplet objectForKey:@"conditions"];
	NSArray *actions = nil;
	if ([couplet objectForKey:@"do"])
		actions = [NSArray arrayWithObject: [couplet objectForKey:@"do"]];
	NSArray *else_actions = nil;
	if ([couplet objectForKey:@"else"])
		else_actions = [NSArray arrayWithObject: [couplet objectForKey:@"else"]];
	BOOL success = YES;
	unsigned i;
	if (conditions == nil)
	{
		NSLog(@"SCENE ERROR no 'conditions' in %@ - returning YES and performing 'do' actions.", [couplet description]);
	}
	else
	{
		if (![conditions isKindOfClass:[NSArray class]])
		{
			NSLog(@"SCENE ERROR \"conditions = %@\" is not an array - returning NO.", [conditions description]);
			return NO;
		}
	}

	// check conditions..
	for (i = 0; (i < [conditions count])&&(success); i++)
		success &= [self scriptTestCondition:(NSString *)[conditions objectAtIndex:i]];

	// perform successful actions...
	if ((success) && (actions) && [actions count])
		[self addScene: actions atOffset: off];

	// perform unsuccessful actions
	if ((!success) && (else_actions) && [else_actions count])
		[self addScene: else_actions atOffset: off];

	return success;
}


- (BOOL) processSceneString:(NSString*) item atOffset:(Vector) off
{
	Vector	model_p0;
	Quaternion	model_q;
	
	if (!item)
		return NO;
	NSArray* i_info = ScanTokensFromString(item);
	if (!i_info)
		return NO;
	NSString* i_key = [(NSString*)[i_info objectAtIndex:0] lowercaseString];

	OOLog(kOOLogNoteProcessSceneString, @"..... processing %@ (%@)", i_info, i_key);

	//
	// recursively add further scenes:
	//
	if ([i_key isEqual:@"scene"])
	{
		if ([i_info count] != 5)	// must be scene_key_x_y_z
			return NO;				//		   0.... 1.. 2 3 4
		NSString* scene_key = (NSString*)[i_info objectAtIndex: 1];
		Vector	scene_offset = {0};
		ScanVectorFromString([[i_info subarrayWithRange:NSMakeRange(2, 3)] componentsJoinedByString:@" "], &scene_offset);
		scene_offset.x += off.x;	scene_offset.y += off.y;	scene_offset.z += off.z;
		NSArray* scene_items = (NSArray*)[[UNIVERSE descriptions] objectForKey:scene_key];
		OOLog(kOOLogDebugProcessSceneStringAddScene, @"::::: adding scene: '%@'", scene_key);
		//
		if (scene_items)
		{
			[self addScene: scene_items atOffset: scene_offset];
			return YES;
		}
		else
			return NO;
	}
	//
	// Add ship models:
	//
	if ([i_key isEqual:@"ship"]||[i_key isEqual:@"model"]||[i_key isEqual:@"role"])
	{
		if ([i_info count] != 10)	// must be item_name_x_y_z_W_X_Y_Z_align
			return NO;				//		   0... 1... 2 3 4 5 6 7 8 9....
		ShipEntity* ship = nil;
		if ([i_key isEqual:@"ship"]||[i_key isEqual:@"model"])
			ship = [UNIVERSE newShipWithName:(NSString*)[i_info objectAtIndex: 1]];
		if ([i_key isEqual:@"role"])
			ship = [UNIVERSE newShipWithRole:(NSString*)[i_info objectAtIndex: 1]];
		if (!ship)
			return NO;

		ScanVectorAndQuaternionFromString([[i_info subarrayWithRange:NSMakeRange(2, 7)] componentsJoinedByString:@" "], &model_p0, &model_q);
		
		Vector	model_offset = positionOffsetForShipInRotationToAlignment(ship, model_q, (NSString*)[i_info objectAtIndex:9]);
		model_p0.x += off.x - model_offset.x;
		model_p0.y += off.y - model_offset.y;
		model_p0.z += off.z - model_offset.z;

		OOLog(kOOLogDebugProcessSceneStringAddModel, @"::::: adding model to scene:'%@'", ship);
		[ship setOrientation: model_q];
		[ship setPosition: model_p0];
		[ship setStatus: STATUS_COCKPIT_DISPLAY];
		[ship setScanClass: CLASS_NO_DRAW];
		[UNIVERSE addEntity: ship];
		[[ship getAI] setStateMachine: @"nullAI.plist"];
		[ship setRoll: 0.0];
		[ship setPitch: 0.0];
		[ship setVelocity: kZeroVector];
		[ship setBehaviour: BEHAVIOUR_STOP_STILL];

		[ship release];
		return YES;
	}
	//
	// Add player ship model:
	//
	if ([i_key isEqual:@"player"])
	{
		if ([i_info count] != 9)	// must be player_x_y_z_W_X_Y_Z_align
			return NO;				//		   0..... 1 2 3 4 5 6 7 8....

		ShipEntity* doppelganger = [UNIVERSE newShipWithName: ship_desc];   // retain count = 1
		if (!doppelganger)
			return NO;
		
		ScanVectorAndQuaternionFromString([[i_info subarrayWithRange:NSMakeRange( 1, 7)] componentsJoinedByString:@" "], &model_p0, &model_q);
		
		Vector	model_offset = positionOffsetForShipInRotationToAlignment( doppelganger, model_q, (NSString*)[i_info objectAtIndex:8]);
		model_p0.x += off.x - model_offset.x;
		model_p0.y += off.y - model_offset.y;
		model_p0.z += off.z - model_offset.z;

		OOLog(kOOLogDebugProcessSceneStringAddModel, @"::::: adding model to scene:'%@'", doppelganger);
		[doppelganger setOrientation: model_q];
		[doppelganger setPosition: model_p0];
		[doppelganger setStatus: STATUS_COCKPIT_DISPLAY];
		[doppelganger setScanClass: CLASS_NO_DRAW];
		[UNIVERSE addEntity: doppelganger];
		[[doppelganger getAI] setStateMachine: @"nullAI.plist"];
		[doppelganger setRoll: 0.0];
		[doppelganger setPitch: 0.0];
		[doppelganger setVelocity: kZeroVector];
		[doppelganger setBehaviour: BEHAVIOUR_STOP_STILL];

		[doppelganger release];
		return YES;
	}
	//
	// Add local planet model:
	//
	if ([i_key isEqual:@"local-planet"])
	{
		if ([i_info count] != 4)	// must be local-planet_x_y_z
			return NO;				//		   0........... 1 2 3

		PlanetEntity* doppelganger = [[PlanetEntity alloc] initMiniatureFromPlanet:[UNIVERSE planet]];   // retain count = 1
		if (!doppelganger)  return NO;
		
		ScanVectorFromString([[i_info subarrayWithRange:NSMakeRange(1, 3)] componentsJoinedByString:@" "], &model_p0);
		Quaternion model_q = { 0.707, 0.707, 0.0, 0.0 };
		model_p0.x += off.x;
		model_p0.y += off.y;
		model_p0.z += off.z;

		OOLog(kOOLogDebugProcessSceneStringAddLocalPlanet, @"::::: adding local-planet to scene:'%@'", doppelganger);
		[doppelganger setOrientation: model_q];
		[doppelganger setPosition: model_p0];
		[UNIVERSE addEntity: doppelganger];

		[doppelganger release];
		return YES;
	}
	//
	// Add target planet model:
	//
	if ([i_key isEqual:@"target-planet"])
	{
		if ([i_info count] != 4)	// must be local-planet_x_y_z
			return NO;				//		   0........... 1 2 3

		PlanetEntity* targetplanet = [[[PlanetEntity alloc] initWithSeed:target_system_seed] autorelease];

		PlanetEntity* doppelganger = [[PlanetEntity alloc] initMiniatureFromPlanet:targetplanet];   // retain count = 1
		if (!doppelganger)
			return NO;

		ScanVectorFromString([[i_info subarrayWithRange:NSMakeRange(1, 3)] componentsJoinedByString:@" "], &model_p0);
		Quaternion model_q = { 0.707, 0.707, 0.0, 0.0 };
		model_p0.x += off.x;
		model_p0.y += off.y;
		model_p0.z += off.z;

		OOLog(kOOLogDebugProcessSceneStringAddTargetPlanet, @"::::: adding target-planet to scene:'%@'", doppelganger);
		[doppelganger setOrientation: model_q];
		[doppelganger setPosition: model_p0];
		[UNIVERSE addEntity: doppelganger];

		[doppelganger release];
		return YES;
	}
	//
	// Add billboard model:
	//
	if ([i_key isEqual:@"billboard"])
	{
		if ([i_info count] != 6)	// must be billboard_imagefile_x_y_w_h
			return NO;				//		   0........ 1........ 2 3 4 5

		NSString* texturefile = (NSString*)[i_info objectAtIndex:1];
		NSSize billSize = NSMakeSize([[i_info objectAtIndex:4] floatValue], [[i_info objectAtIndex:5] floatValue]);
		Vector	model_p0;
		model_p0.x = [[i_info objectAtIndex:2] floatValue] + off.x;
		model_p0.y = [[i_info objectAtIndex:3] floatValue] + off.y;
		model_p0.z = off.z;

		ParticleEntity* billboard = [[ParticleEntity alloc] initBillboard:billSize withTexture:texturefile];
		if (!billboard)
			return NO;
			
		billboard->position.x += model_p0.x;
		billboard->position.y += model_p0.y;
		billboard->position.z += model_p0.z;
			
		[billboard setStatus: STATUS_COCKPIT_DISPLAY];
		
		OOLog(kOOLogDebugProcessSceneStringAddBillboard, @"::::: adding billboard:'%@' to scene.", billboard);

		[UNIVERSE addEntity: billboard];

		[billboard release];
		return YES;
	}
	//
	// fall through..
	return NO;
}


- (BOOL) mapKey:(NSString *)keycode toOXP:(OOScript *)oxp
{
	OOScript *s = [oxpKeys objectForKey:keycode];
	if (s == nil)
	{
		if (oxpKeys == nil)  oxpKeys = [[NSMutableDictionary alloc] init];
		
		[oxpKeys setObject:oxp forKey:keycode];
		return YES;
	}
	
	return NO;
}


- (void) targetNearestHostile
{
	[self scanForHostiles];
	if (found_target != NO_TARGET)
	{
		Entity *ent = [UNIVERSE entityForUniversalID:found_target];
		if (ent != 0x00)
		{
			ident_engaged = YES;
			missile_status = MISSILE_STATUS_TARGET_LOCKED;
			[self addTarget:ent];
		}
	}
}

@end
