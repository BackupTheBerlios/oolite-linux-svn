/*

DockEntity.m

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

#import "DockEntity.h"
#import "StationEntity.h"
#import "ShipEntityAI.h"
#import "OOCollectionExtractors.h"
#import "OOStringParsing.h"

#import "Universe.h"
#import "HeadUpDisplay.h"

#import "PlayerEntityLegacyScriptEngine.h"
#import "OOLegacyScriptWhitelist.h"
#import "OOPlanetEntity.h"
#import "OOShipGroup.h"
#import "OOQuiriumCascadeEntity.h"

#import "AI.h"
#import "OOCharacter.h"

#import "OOJSScript.h"
#import "OODebugGLDrawing.h"
#import "OODebugFlags.h"

#define kOOLogUnconvertedNSLog @"unclassified.StationEntity"


static NSDictionary* instructions(int station_id, Vector coords, float speed, float range, NSString* ai_message, NSString* comms_message, BOOL match_rotation);

@interface DockEntity (private)


@end

#ifndef NDEBUG
@interface DockEntity (mwDebug)

@end
#endif

@implementation DockEntity

- (unsigned) sanityCheckShipsOnApproach
{
	unsigned i;
	NSArray*	ships = [shipsOnApproach allKeys];
	
	// Remove dead entities.
	// No enumerator because we mutate the dictionary.
	for (i = 0; i < [ships count]; i++)
	{
		int sid = [[ships objectAtIndex:i] intValue];
		if ((sid == NO_TARGET)||(![UNIVERSE entityForUniversalID:sid]))
		{
			[shipsOnApproach removeObjectForKey:[ships objectAtIndex:i]];
		}
	}
	
	if ([shipsOnApproach count] == 0)
	{
		if (last_launch_time < [UNIVERSE getTime])
		{
			last_launch_time = [UNIVERSE getTime];
		}
		approach_spacing = 0.0;
	}

	return [shipsOnApproach count];
}


- (void) abortAllDockings
{
	unsigned i;
	NSArray*	ships = [shipsOnApproach allKeys];
	double		playerExtraTime = 0;
	no_docking_while_launching = YES;

	for (i = 0; i < [ships count]; i++)
	{
		int sid = [[ships objectAtIndex:i] intValue];
		if ([UNIVERSE entityForUniversalID:sid])
			[[[UNIVERSE entityForUniversalID:sid] getAI] message:@"DOCKING_ABORTED"];
	}
	[shipsOnApproach removeAllObjects];

	PlayerEntity *player = PLAYER;
	BOOL isDockingStation = ([self parentEntity] == [player getTargetDockStation]);
	if (isDockingStation && [player status] == STATUS_IN_FLIGHT &&
			[player getDockingClearanceStatus] >= DOCKING_CLEARANCE_STATUS_REQUESTED)
	{
		if (magnitude2(vector_subtract([player position], [self absolutePositionForSubentity])) > 2250000) // within 1500m of the dock
		{
			[self sendExpandedMessage:DESC(@"station-docking-clearance-abort-cancelled") toShip:player];
			[player setDockingClearanceStatus:DOCKING_CLEARANCE_STATUS_NONE];
		}
		else
		{
			playerExtraTime = 10; // when very close to the port, give the player a few seconds to react on the abort message.
			[self sendExpandedMessage:[NSString stringWithFormat:DESC(@"station-docking-clearance-abort-cancelled-in-f"), playerExtraTime ] toShip:player];
			[player setDockingClearanceStatus:DOCKING_CLEARANCE_STATUS_TIMING_OUT];
		}

	}
	
	last_launch_time = [UNIVERSE getTime] + playerExtraTime;
	approach_spacing = 0.0;
}

- (void) autoDockShipsInQueue:(NSMutableDictionary *)queue
{
	NSArray		*ships = [queue allKeys];
	unsigned	i, count = [ships count];
	
	for (i = 0; i < count; i++)
	{
		ShipEntity *ship = [UNIVERSE entityForUniversalID:[ships oo_unsignedIntAtIndex:i]];
		if ([ship isShip])
		{
			[self pullInShipIfPermitted:ship];
		}
	}
	
	[queue removeAllObjects];
}


- (void) autoDockShipsOnApproach
{
	[self autoDockShipsInQueue:shipsOnApproach];
}

static NSDictionary* instructions(int station_id, Vector coords, float speed, float range, NSString* ai_message, NSString* comms_message, BOOL match_rotation)
{
	NSMutableDictionary* acc = [NSMutableDictionary dictionaryWithCapacity:8];
	[acc setObject:[NSString stringWithFormat:@"%.2f %.2f %.2f", coords.x, coords.y, coords.z] forKey:@"destination"];
	[acc setObject:[NSNumber numberWithFloat:speed] forKey:@"speed"];
	[acc setObject:[NSNumber numberWithFloat:range] forKey:@"range"];
	[acc setObject:[NSNumber numberWithInt:station_id] forKey:@"station_id"];
	[acc setObject:[NSNumber numberWithBool:match_rotation] forKey:@"match_rotation"];
	if (ai_message)
		[acc setObject:ai_message forKey:@"ai_message"];
	if (comms_message)
		[acc setObject:comms_message forKey:@"comms_message"];
	//
	return [NSDictionary dictionaryWithDictionary:acc];
}


- (BOOL) allowsDocking
{
	return allow_docking;
}


- (NSString*) canAcceptShipForDocking:(ShipEntity *) ship
{
	if (!allow_docking)
	{
		return @"TRY_AGAIN_LATER";
	}
	if (no_docking_while_launching)
	{
		return @"TRY_AGAIN_LATER";
	}
	BoundingBox bb = [ship totalBoundingBox];
	if ((port_dimensions.x < (bb.max.x - bb.min.x) || port_dimensions.y < (bb.max.y - bb.min.y)) && 
		(port_dimensions.y < (bb.max.x - bb.min.x) || port_dimensions.x < (bb.max.y - bb.min.y)))
	{
		return @"TOO_BIG_TO_DOCK";
	}
	
	// If the ship is not on its docking approach and the player has
	// requested or even been granted docking clearance, then tell the
	// ship to wait.
	PlayerEntity *player = PLAYER;
	BOOL isDockingStation = [self parentEntity] == [player getTargetDockStation];

	OOUniversalID	ship_id = [ship universalID];
	NSNumber		*shipID = [NSNumber numberWithUnsignedShort:ship_id];

	if (isDockingStation && ![shipsOnApproach objectForKey:shipID] &&
			player && [player status] == STATUS_IN_FLIGHT &&
			[player getDockingClearanceStatus] >= DOCKING_CLEARANCE_STATUS_REQUESTED)
	{
		return @"TRY_AGAIN_LATER";
	}

	return @"DOCKING_POSSIBLE";
}


- (BOOL) isOffCentre
{
	if (fabs(position.x) + fabs(position.y) > 0.1f)
	{
		return YES;
	}
	Vector dir = vector_forward_from_quaternion(orientation);
	if (fabs(dir.x) + fabs(dir.y) > 0.1f)
	{
		return YES;
	}
	return NO;
}


- (NSDictionary *) dockingInstructionsForShip:(ShipEntity *) ship
{	
	Vector		coords;
	
	int			ship_id = [ship universalID];
	NSNumber	*shipID = [NSNumber numberWithUnsignedShort:ship_id];

	Vector launchVector = vector_forward_from_quaternion(quaternion_multiply(orientation, [[self parentEntity] orientation]));
	Vector temp = (fabsf(launchVector.x) < 0.8)? make_vector(1,0,0) : make_vector(0,1,0);
	temp = cross_product(launchVector, temp);	// 90 deg to launchVector & temp
	Vector vi = cross_product(launchVector, temp);
	Vector vj = cross_product(launchVector, vi);
	Vector vk = launchVector;
	
	if (!ship)
		return nil;
	
	// check if this is a new ship on approach
	//
	if (![shipsOnApproach objectForKey:shipID])
	{
		Vector	delta = vector_subtract([ship position], [self absolutePositionForSubentity]);
		float	ship_distance = magnitude(delta);

		if (ship_distance > SCANNER_MAX_RANGE)	// too far away - don't claim a docking slot by not putting on approachlist for now.
			return instructions([[self parentEntity] universalID], [self absolutePositionForSubentity], 0, 10000, @"APPROACH", nil, NO);

		[self addShipToShipsOnApproach: ship];
		
		if (ship_distance < 1000.0 + [[self parentEntity] collisionRadius] + ship->collision_radius)	// too close - back off
			return instructions([[self parentEntity] universalID], [self absolutePositionForSubentity], 0, 5000, @"BACK_OFF", nil, NO);
		
		float dot = dot_product(launchVector, delta);
		if (dot < 0) // approaching from the wrong side of the station - construct a vector to the side of the station.
		{
			Vector approachVector = cross_product(vector_normal(delta), launchVector);
			approachVector = cross_product(launchVector, approachVector); // vector, 90 degr rotated from launchVector towards target.
			return instructions([[self parentEntity] universalID], OOVectorTowards([self absolutePositionForSubentity], approachVector, [[self parentEntity] collisionRadius] + 5000) , 0, 1000, @"APPROACH", nil, NO);
		}
		
		if (ship_distance > 12500.0)	// long way off - approach more closely
			return instructions([[self parentEntity] universalID], [self absolutePositionForSubentity], 0, 10000, @"APPROACH", nil, NO);
	}
	
	if (![shipsOnApproach objectForKey:shipID])
	{
		// some error has occurred - log it, and send the try-again message
		OOLogERR(@"station.issueDockingInstructions.failed", @"couldn't addShipToShipsOnApproach:%@ in %@, retrying later -- shipsOnApproach:\n%@", ship, self, shipsOnApproach);
		//
		return instructions([[self parentEntity] universalID], ship->position, 0, 100, @"TRY_AGAIN_LATER", nil, NO);
	}


	//	shipsOnApproach now has an entry for the ship.
	//
	NSMutableArray* coordinatesStack = [shipsOnApproach objectForKey:shipID];

	if ([coordinatesStack count] == 0)
	{
		OOLogERR(@"station.issueDockingInstructions.failed", @" -- coordinatesStack = %@", coordinatesStack);
		
		return instructions([[self parentEntity] universalID], ship->position, 0, 100, @"HOLD_POSITION", nil, NO);
	}
	
	// get the docking information from the instructions	
	NSMutableDictionary* nextCoords = (NSMutableDictionary *)[coordinatesStack objectAtIndex:0];
	int docking_stage = [nextCoords oo_intForKey:@"docking_stage"];
	float speedAdvised = [nextCoords oo_floatForKey:@"speed"];
	float rangeAdvised = [nextCoords oo_floatForKey:@"range"];
	
	// calculate world coordinates from relative coordinates
	Vector rel_coords;
	rel_coords.x = [(NSNumber *)[nextCoords objectForKey:@"rx"] floatValue];
	rel_coords.y = [(NSNumber *)[nextCoords objectForKey:@"ry"] floatValue];
	rel_coords.z = [(NSNumber *)[nextCoords objectForKey:@"rz"] floatValue];
	coords = [self absolutePositionForSubentity];
	coords.x += rel_coords.x * vi.x + rel_coords.y * vj.x + rel_coords.z * vk.x;
	coords.y += rel_coords.x * vi.y + rel_coords.y * vj.y + rel_coords.z * vk.y;
	coords.z += rel_coords.x * vi.z + rel_coords.y * vj.z + rel_coords.z * vk.z;
	
	// check if the ship is at the control point
	double max_allowed_range = 2.0 * rangeAdvised + ship->collision_radius;	// maximum distance permitted from control point - twice advised range
	Vector delta = ship->position;
	delta.x -= coords.x;	delta.y -= coords.y;	delta.z -= coords.z;

	if (magnitude2(delta) > max_allowed_range * max_allowed_range)	// too far from the coordinates - do not remove them from the stack!
	{
		if ((docking_stage == 1) &&(magnitude2(delta) < 1000000.0))	// 1km*1km
			speedAdvised *= 0.5;	// half speed
		
		return instructions([[self parentEntity] universalID], coords, speedAdvised, rangeAdvised, @"APPROACH_COORDINATES", nil, NO);
	}
	else
	{
		// reached the current coordinates okay..
	
		// get the NEXT coordinates
		nextCoords = (NSMutableDictionary *)[coordinatesStack oo_dictionaryAtIndex:1];
		if (nextCoords == nil)
		{
			return nil;
		}
		
		docking_stage = [nextCoords oo_intForKey:@"docking_stage"];
		speedAdvised = [nextCoords oo_floatForKey:@"speed"];
		rangeAdvised = [nextCoords oo_floatForKey:@"range"];
		BOOL match_rotation = [nextCoords oo_boolForKey:@"match_rotation"];
		NSString *comms_message = [nextCoords oo_stringForKey:@"comms_message"];
		
		if (comms_message)
		{
			[[self parentEntity] sendExpandedMessage: comms_message toShip: ship];
		}
				
		// calculate world coordinates from relative coordinates
		rel_coords.x = [(NSNumber *)[nextCoords objectForKey:@"rx"] floatValue];
		rel_coords.y = [(NSNumber *)[nextCoords objectForKey:@"ry"] floatValue];
		rel_coords.z = [(NSNumber *)[nextCoords objectForKey:@"rz"] floatValue];
		coords = [self absolutePositionForSubentity];
		coords.x += rel_coords.x * vi.x + rel_coords.y * vj.x + rel_coords.z * vk.x;
		coords.y += rel_coords.x * vi.y + rel_coords.y * vj.y + rel_coords.z * vk.y;
		coords.z += rel_coords.x * vi.z + rel_coords.y * vj.z + rel_coords.z * vk.z;
		
		if( ([id_lock[docking_stage] weakRefUnderlyingObject] == nil)
		   &&([id_lock[docking_stage + 1] weakRefUnderlyingObject] == nil)
		   &&([id_lock[docking_stage + 2] weakRefUnderlyingObject] == nil))	// check three stages ahead
		{
			// approach is clear - move to next position
			//
			
			// clear any previously owned docking stages
			[self clearIdLocks:ship];
					
			if (docking_stage > 1)	// don't claim first docking stage
			{
				[id_lock[docking_stage] release];
				id_lock[docking_stage] = [ship weakRetain];	// otherwise - claim this docking stage
			}
			
			//remove the previous stage from the stack
			[coordinatesStack removeObjectAtIndex:0];
			
			return instructions([[self parentEntity] universalID], coords, speedAdvised, rangeAdvised, @"APPROACH_COORDINATES", nil, match_rotation);
		}
		else
		{
			// approach isn't clear - hold position..
			//
			[[ship getAI] message:@"HOLD_POSITION"];
			
			if (![nextCoords objectForKey:@"hold_message_given"])
			{
				// COMM-CHATTER
				[UNIVERSE clearPreviousMessage];
				[self sendExpandedMessage: @"[station-hold-position]" toShip: ship];
				[nextCoords setObject:@"YES" forKey:@"hold_message_given"];
			}

			return instructions([[self parentEntity] universalID], ship->position, 0, 100, @"HOLD_POSITION", nil, NO);
		}
	}
	
	// we should never reach here.
	return instructions([[self parentEntity] universalID], coords, 50, 10, @"APPROACH_COORDINATES", nil, NO);
}


- (void) addShipToShipsOnApproach:(ShipEntity *) ship
{		
	int			corridor_distance[] =	{	-1,	1,	3,	5,	7,	9,	11,	12,	12};
	int			corridor_offset[] =		{	0,	0,	0,	0,	0,	0,	1,	3,	12};
	int			corridor_speed[] =		{	48,	48,	48,	48,	36,	48,	64,	128, 512};	// how fast to approach the next point
	int			corridor_range[] =		{	24,	12,	6,	4,	4,	6,	15,	38,	96};	// how close you have to get to the target point
	int			corridor_rotate[] =		{	1,	1,	1,	1,	0,	0,	0,	0,	0};		// whether to match the station rotation
	int			corridor_count = 9;
	int			corridor_final_approach = 3;
	
	NSNumber	*shipID = [NSNumber numberWithUnsignedShort:[ship universalID]];
	
	Vector launchVector = vector_forward_from_quaternion(quaternion_multiply(orientation, [[self parentEntity] orientation]));
	Vector temp = (fabsf(launchVector.x) < 0.8)? make_vector(1,0,0) : make_vector(0,1,0);
	temp = cross_product(launchVector, temp);	// 90 deg to launchVector & temp
	Vector rightVector = cross_product(launchVector, temp);
	Vector upVector = cross_product(launchVector, rightVector);
	
	// will select a direction for offset based on the entity personality (was ship ID)
	int offset_id = [ship entityPersonalityInt] & 0xf;	// 16  point compass
	double c = cos(offset_id * M_PI * ONE_EIGHTH);
	double s = sin(offset_id * M_PI * ONE_EIGHTH);
	
	// test if this points at the ship
	Vector point1 = [self absolutePositionForSubentity];
	point1.x += launchVector.x * corridor_offset[corridor_count - 1];
	point1.y += launchVector.x * corridor_offset[corridor_count - 1];
	point1.z += launchVector.x * corridor_offset[corridor_count - 1];
	Vector alt1 = point1;
	point1.x += c * upVector.x * corridor_offset[corridor_count - 1] + s * rightVector.x * corridor_offset[corridor_count - 1];
	point1.y += c * upVector.y * corridor_offset[corridor_count - 1] + s * rightVector.y * corridor_offset[corridor_count - 1];
	point1.z += c * upVector.z * corridor_offset[corridor_count - 1] + s * rightVector.z * corridor_offset[corridor_count - 1];
	alt1.x -= c * upVector.x * corridor_offset[corridor_count - 1] + s * rightVector.x * corridor_offset[corridor_count - 1];
	alt1.y -= c * upVector.y * corridor_offset[corridor_count - 1] + s * rightVector.y * corridor_offset[corridor_count - 1];
	alt1.z -= c * upVector.z * corridor_offset[corridor_count - 1] + s * rightVector.z * corridor_offset[corridor_count - 1];
	if (distance2(alt1, ship->position) < distance2(point1, ship->position))
	{
		s = -s;
		c = -c;	// turn 180 degrees
	}
	
	//
	NSMutableArray*		coordinatesStack =  [NSMutableArray arrayWithCapacity: MAX_DOCKING_STAGES];
	double port_depth = port_dimensions.z;	// 250m deep standard port.
	
	//
	int i;
	double corridor_length;
	for (i = corridor_count - 1; i >= 0; i--)
	{
		NSMutableDictionary*	nextCoords =	[NSMutableDictionary dictionaryWithCapacity:3];
		
		int offset = corridor_offset[i];
		
		// space out first coordinate further if there are many ships
		if ((i == corridor_count - 1) && offset)
			offset += approach_spacing / port_depth;
		
		[nextCoords setObject:[NSNumber numberWithInt: corridor_count - i] forKey:@"docking_stage"];

		[nextCoords setObject:[NSNumber numberWithFloat: s * port_depth * offset]	forKey:@"rx"];
		[nextCoords setObject:[NSNumber numberWithFloat: c * port_depth * offset]	forKey:@"ry"];
		corridor_length = port_depth * corridor_distance[i];
		 // add the lenght inside the station to the corridor, except for the final position, inside the dock.
		if (corridor_distance[i] > 0) corridor_length += port_corridor;
		[nextCoords setObject:[NSNumber numberWithFloat: corridor_length]	forKey:@"rz"];
		[nextCoords setObject:[NSNumber numberWithFloat: corridor_speed[i]] forKey:@"speed"];
		[nextCoords setObject:[NSNumber numberWithFloat: corridor_range[i]] forKey:@"range"];
		
		if (corridor_rotate[i])
			[nextCoords setObject:@"YES" forKey:@"match_rotation"];
		
		if (i == corridor_final_approach)
		{
			if ([self parentEntity] == [UNIVERSE station])
				[nextCoords setObject:@"[station-begin-final-aproach]" forKey:@"comms_message"];
			else
				[nextCoords setObject:@"[docking-begin-final-aproach]" forKey:@"comms_message"];
		}

		[coordinatesStack addObject:nextCoords];
	}
	
	[shipsOnApproach setObject:coordinatesStack forKey:shipID];
	
	approach_spacing += 500;  // space out incoming ships by 500m
	
	// FIXME: Eric 23-10-2011: Below is a quick fix to prevent the approach_spacing from blowing up
	// to high values because of bad AI's for docking ships that keep requesting and aborting docking.
	// Post 1.76 this probably should replace it with a proper list of holding slots so  that close by slots
	// can be used again once the ship has left the Approach queue. In the current fix, resetting can
	// result in two ships getting the same holding position.
	if (approach_spacing > 2 * SCANNER_MAX_RANGE && approach_spacing / 500 > 5 * [shipsOnApproach count]) approach_spacing = 0;
	
	// COMM-CHATTER
	if ([self parentEntity] == [UNIVERSE station])
		[[self parentEntity] sendExpandedMessage: @"[station-welcome]" toShip: ship];
	else
		[[self parentEntity] sendExpandedMessage: @"[docking-welcome]" toShip: ship];

}


- (void) noteDockingForShip:(ShipEntity *) ship
{
// safe to do this for now, as it just clears the ship from the docking queue
	[self abortDockingForShip:ship];

	PlayerEntity *player = PLAYER;
	BOOL isDockingStation = ([self parentEntity] == [player getTargetDockStation]);
	if (isDockingStation && [player status] == STATUS_IN_FLIGHT &&
			[player getDockingClearanceStatus] == DOCKING_CLEARANCE_STATUS_REQUESTED)
	{
		if ([shipsOnApproach count])
		{
			[[self parentEntity] sendExpandedMessage:[NSString stringWithFormat:
				DESC(@"station-docking-clearance-holding-d-ships-approaching"),
				[shipsOnApproach count]+1] toShip:player];
		}
		else if([launchQueue count])
		{
			[[self parentEntity] sendExpandedMessage:[NSString stringWithFormat:
				DESC(@"station-docking-clearance-holding-d-ships-departing"),
				[launchQueue count]+1] toShip:player];
		}
	}

}

- (void) abortDockingForShip:(ShipEntity *) ship
{
	OOUniversalID	ship_id = [ship universalID];
	NSNumber		*shipID = [NSNumber numberWithUnsignedShort:ship_id];

	if ([shipsOnApproach objectForKey:shipID])
	{
		[shipsOnApproach removeObjectForKey:shipID];
	}
		
	// clear any previously owned docking stages
	[self clearIdLocks:ship];
}


- (Vector) portUpVectorForShipsBoundingBox:(BoundingBox) bb
{
	BOOL twist = ((port_dimensions.x < port_dimensions.y) ^ (bb.max.x - bb.min.x < bb.max.y - bb.min.y));

	if (!twist)
	{
		return vector_up_from_quaternion(quaternion_multiply(orientation, [[self parentEntity] orientation]));
	}
	else
	{
		return vector_right_from_quaternion(quaternion_multiply(orientation, [[self parentEntity] orientation]));
	}
}


- (BOOL) shipIsInDockingQueue:(ShipEntity *)ship
{
	if (![ship isShip])  return NO;
	if ([ship isPlayer] && [ship status] == STATUS_DEAD)  return NO;
	OOUniversalID	ship_id = [ship universalID];
	NSNumber		*shipID = [NSNumber numberWithUnsignedShort:ship_id];

	if ([shipsOnApproach objectForKey:shipID])
	{
		return YES;
	}
	return NO;
}


- (unsigned) dockingQueueSize
{
	return [shipsOnApproach count];
}


- (int) launchQueueSize
{
	if (allow_launching)
	{
		return [launchQueue count];
	}
	return -1;
}


- (BOOL) shipIsInDockingCorridor:(ShipEntity *)ship
{
	if (![ship isShip])  return NO;
	if ([ship isPlayer] && [ship status] == STATUS_DEAD)  return NO;
	
	Quaternion q0 = quaternion_multiply(orientation, [[self parentEntity] orientation]);
	Vector vi = vector_right_from_quaternion(q0);
	Vector vj = vector_up_from_quaternion(q0);
	Vector vk = vector_forward_from_quaternion(q0);
	
	Vector port_pos = [self absolutePositionForSubentity];
	
	BoundingBox shipbb = [ship boundingBox];
	BoundingBox arbb = [ship findBoundingBoxRelativeToPosition: port_pos InVectors: vi : vj : vk];
	
	// port dimensions..
	GLfloat ww = port_dimensions.x;
	GLfloat hh = port_dimensions.y;
	GLfloat dd = port_dimensions.z;

	while (shipbb.max.x - shipbb.min.x > ww * 0.90)	ww *= 1.25;
	while (shipbb.max.y - shipbb.min.y > hh * 0.90)	hh *= 1.25;
	
	ww *= 0.5;
	hh *= 0.5;
	
#ifndef NDEBUG
	if ([ship isPlayer] && (gDebugFlags & DEBUG_DOCKING))
	{
		BOOL			inLane;
		float			range;
		unsigned		laneFlags = 0;
		
		if (arbb.max.x < ww)   laneFlags |= 1;
		if (arbb.min.x > -ww)  laneFlags |= 2;
		if (arbb.max.y < hh)   laneFlags |= 4;
		if (arbb.min.y > -hh)  laneFlags |= 8;
		inLane = laneFlags == 0xF;
		range = 0.90 * arbb.max.z + 0.10 * arbb.min.z;
		
		OOLog(@"docking.debug", @"Normalised port dimensions are %g x %g x %g.  Player bounding box is at %@-%@ -- %s (%X), range: %g",
			ww * 2.0, hh * 2.0, dd,
			VectorDescription(arbb.min), VectorDescription(arbb.max),
			inLane ? "in lane" : "out of lane", laneFlags,
			range);
	}
#endif

	if (arbb.max.z < -dd)
		return NO;

	if ((arbb.max.x < ww)&&(arbb.min.x > -ww)&&(arbb.max.y < hh)&&(arbb.min.y > -hh))
	{
		// in lane
		if (0.90 * arbb.max.z + 0.10 * arbb.min.z < 0.0)	// we're 90% in docking position!
		{
			[self pullInShipIfPermitted:ship];
		}
		return YES;
	}
	
	if ([ship status] == STATUS_LAUNCHING)
	{
		return YES;
	}
	
	// if close enough (within 50%) correct and add damage
	//
	if  ((arbb.min.x > -1.5 * ww)&&(arbb.max.x < 1.5 * ww)&&(arbb.min.y > -1.5 * hh)&&(arbb.max.y < 1.5 * hh))
	{
		if (arbb.min.z < 0.0)	// got our nose inside
		{
			GLfloat correction_factor = -arbb.min.z / (arbb.max.z - arbb.min.z);	// proportion of ship inside
		
			// damage the ship according to velocity - don't send collision messages to AIs to avoid problems.
			[ship takeScrapeDamage: 5 * [UNIVERSE getTimeDelta]*[ship flightSpeed] from:[self parentEntity]];
			[[self parentEntity] doScriptEvent:OOJSID("shipCollided") withArgument:ship]; // no COLLISION message to station AI, carriers would move away!
			[ship doScriptEvent:OOJSID("shipCollided") withArgument:[self parentEntity]]; // no COLLISION message to ship AI, dockingAI.plist would abort.
			
			Vector delta;
			delta.x = 0.5 * (arbb.max.x + arbb.min.x) * correction_factor;
			delta.y = 0.5 * (arbb.max.y + arbb.min.y) * correction_factor;
			
			if (arbb.max.x < ww && arbb.min.x > -ww)	// x is okay - no need to correct
				delta.x = 0;
			if (arbb.max.y > hh && arbb.min.x > -hh)	// y is okay - no need to correct
				delta.y = 0;
				
			// adjust the ship back to the center of the port
			Vector pos = ship->position;
			pos.x -= delta.y * vj.x + delta.x * vi.x;
			pos.y -= delta.y * vj.y + delta.x * vi.y;
			pos.z -= delta.y * vj.z + delta.x * vi.z;
			[ship setPosition:pos];
		}
		
		// if far enough in - dock
		if (0.90 * arbb.max.z + 0.10 * arbb.min.z < 0.0)
		{
			[self pullInShipIfPermitted:ship];
		}
		
		return YES;	// okay NOW we're in the docking corridor!
	}
	
	return NO;
}


- (void) pullInShipIfPermitted:(ShipEntity *)ship
{
	// FIXME: check if dock is launch-only, etc.
	[ship enterDock:(StationEntity*)[self parentEntity]];
}


- (void) addShipToLaunchQueue:(ShipEntity *) ship :(BOOL) priority
{
	[self sanityCheckShipsOnApproach];
	if (!launchQueue)
		launchQueue = [[NSMutableArray alloc] init]; // retained
	if (ship)
	{
		[ship setStatus: STATUS_DOCKED];
		if (priority)
			[launchQueue insertObject: ship atIndex: 0];
		else 
			[launchQueue addObject:ship];
	}
}


- (void) launchShip:(ShipEntity *) ship
{
	if (![ship isShip])  return;
	
	BoundingBox bb = [ship boundingBox];
	
	Vector launchPos = [self absolutePositionForSubentity];
	Vector launchVel = [[self parentEntity] velocity];
	double launchSpeed = 0.5 * [ship maxFlightSpeed];
	if ([[self parentEntity] maxFlightSpeed] > 0 && [[self parentEntity] flightSpeed] > 0) // is self a carrier in flight.
	{
		launchSpeed = 0.5 * [ship maxFlightSpeed] * (1.0 + [[self parentEntity] flightSpeed]/[[self parentEntity] maxFlightSpeed]);
	}
	Quaternion q1 = [[self parentEntity] orientation];
	q1 = quaternion_multiply(orientation, q1);
	Vector launchVector = vector_forward_from_quaternion(q1);
	
	// launch orientation
	if ((port_dimensions.x < port_dimensions.y) ^ (bb.max.x - bb.min.x < bb.max.y - bb.min.y))
	{
		quaternion_rotate_about_axis(&q1, launchVector, M_PI*0.5);  // to account for the slot being at 90 degrees to vertical
	}
	if ([ship isPlayer]) q1.w = -q1.w; // need this as a fix for the player and before shipWillLaunchFromStation.
	[ship setOrientation:q1];
	// launch position
	[ship setPosition:launchPos];
	if([ship pendingEscortCount] > 0) [ship setPendingEscortCount:0]; // Make sure no extra escorts are added after launch. (e.g. for miners etc.)
	if ([ship hasEscorts]) no_docking_while_launching = YES;
	// launch speed
	launchVel = vector_add(launchVel, vector_multiply_scalar(launchVector, launchSpeed));
	launchSpeed = magnitude(launchVel);
	[ship setSpeed:launchSpeed];
	[ship setVelocity:launchVel];
	// launch roll/pitch
	[ship setRoll:[[self parentEntity] flightRoll]];
	[ship setPitch:0.0];
	[UNIVERSE addEntity:ship];
	[ship setStatus: STATUS_LAUNCHING];
	[ship setDesiredSpeed:launchSpeed]; // must be set after initialising the AI to correct any speed set by AI
	last_launch_time = [UNIVERSE getTime];
	double delay = (port_corridor + 2 * port_dimensions.z)/launchSpeed; // pause until 2 portlengths outside of the station.
	[ship setLaunchDelay:delay];
	[[ship getAI] setNextThinkTime:last_launch_time + delay]; // pause while launching
	
	[ship resetExhaustPlumes];	// resets stuff for tracking/exhausts
	
	[ship doScriptEvent:OOJSID("shipWillLaunchFromStation") withArgument:[self parentEntity]];
	[[self parentEntity] doScriptEvent:OOJSID("stationLaunchedShip") withArgument:ship andReactToAIMessage: @"STATION_LAUNCHED_SHIP"];
}


- (unsigned) countShipsInLaunchQueueWithPrimaryRole:(NSString *)role
{
	unsigned i, count, result = 0;
	count = [launchQueue count];
	
	for (i = 0; i < count; i++)
	{
		if ([[launchQueue objectAtIndex:i] hasPrimaryRole:role])  result++;
	}
	return result;
}


- (BOOL) fitsInDock:(ShipEntity *) ship
{
	if (![ship isShip])  return NO;
	
	BoundingBox bb = [ship totalBoundingBox];
	if ((port_dimensions.x < (bb.max.x - bb.min.x) || port_dimensions.y < (bb.max.y - bb.min.y)) && 
		(port_dimensions.y < (bb.max.x - bb.min.x) || port_dimensions.x < (bb.max.y - bb.min.y)) && ![ship isPlayer])
	{
		return NO;
	}
	return YES;
}	


- (void) clear
{
	if (launchQueue)
		[launchQueue removeAllObjects];
	if (shipsOnApproach)
		[shipsOnApproach removeAllObjects];

}


- (BOOL) dockingCorridorIsEmpty
{
	if (!UNIVERSE)
		return NO;
	
	double unitime = [UNIVERSE getTime];
	
	if (unitime < last_launch_time + STATION_DELAY_BETWEEN_LAUNCHES)	// leave sufficient pause between launches
		return NO;
	
	// check against all ships
	BOOL		isEmpty = YES;
	int			ent_count =		UNIVERSE->n_entities;
	Entity**	uni_entities =	UNIVERSE->sortedEntities;	// grab the public sorted list
	Entity*		my_entities[ent_count];
	int i;
	int ship_count = 0;
	for (i = 0; i < ent_count; i++)
		//on red alert, launch even if the player is trying block the corridor. Ignore cargopods or other small debris.
		if ([uni_entities[i] isShip] && ([(StationEntity*)[self parentEntity] alertLevel] < STATION_ALERT_LEVEL_RED || ![uni_entities[i] isPlayer]) && [uni_entities[i] mass] > 1000)
			my_entities[ship_count++] = [uni_entities[i] retain];		//	retained

	for (i = 0; (i < ship_count)&&(isEmpty); i++)
	{
		ShipEntity*	ship = (ShipEntity*)my_entities[i];
		double		d2 = distance2([[self parentEntity] position], ship->position);
		if ((ship != [self parentEntity])&&(d2 < 25000000)&&([ship status] != STATUS_DOCKED))	// within 5km
		{
			Vector ppos = [self absolutePositionForSubentity];
			d2 = distance2(ppos, ship->position);
			if (d2 < 4000000)	// within 2km of the port entrance
			{
				Quaternion q1 = [[self parentEntity] orientation];
				q1 = quaternion_multiply(orientation, q1);
				//
				Vector v_out = vector_forward_from_quaternion(q1);
				Vector r_pos = make_vector(ship->position.x - ppos.x, ship->position.y - ppos.y, ship->position.z - ppos.z);
				if (r_pos.x||r_pos.y||r_pos.z)
					r_pos = vector_normal(r_pos);
				else
					r_pos.z = 1.0;
				//
				double vdp = dot_product(v_out, r_pos); //== cos of the angle between r_pos and v_out
				//
				if (vdp > 0.86)
				{
					isEmpty = NO;
					last_launch_time = unitime - STATION_DELAY_BETWEEN_LAUNCHES + STATION_LAUNCH_RETRY_INTERVAL;
				}
			}
		}
	}
	
	for (i = 0; i < ship_count; i++)
		[my_entities[i] release];		//released

	return isEmpty;
}


- (void) clearDockingCorridor
{
	// check against all ships
	BOOL		isClear = YES;
	int			ent_count =		UNIVERSE->n_entities;
	Entity**	uni_entities =	UNIVERSE->sortedEntities;	// grab the public sorted list
	Entity*		my_entities[ent_count];
	int i;
	int ship_count = 0;
	for (i = 0; i < ent_count; i++)
		if (uni_entities[i]->isShip)
			my_entities[ship_count++] = [uni_entities[i] retain];		//	retained

	for (i = 0; i < ship_count; i++)
	{
		ShipEntity*	ship = (ShipEntity*)my_entities[i];
		double		d2 = distance2([[self parentEntity] position], ship->position);
		if ((ship != [self parentEntity])&&(d2 < 25000000)&&([ship status] != STATUS_DOCKED))	// within 5km
		{
			Vector ppos = [self absolutePositionForSubentity];
			float time_out = -15.00;	// 15 secs
			do
			{
				isClear = YES;
				d2 = distance2(ppos, ship->position);
				if (d2 < 4000000)	// within 2km of the port entrance
				{
					Quaternion q1 = [[self parentEntity] orientation];
					q1 = quaternion_multiply(orientation, q1);
					//
					Vector v_out = vector_forward_from_quaternion(q1);
					Vector r_pos = make_vector(ship->position.x - ppos.x, ship->position.y - ppos.y, ship->position.z - ppos.z);
					if (r_pos.x||r_pos.y||r_pos.z)
						r_pos = vector_normal(r_pos);
					else
						r_pos.z = 1.0;
					//
					double vdp = dot_product(v_out, r_pos); //== cos of the angle between r_pos and v_out
					//
					if (vdp > 0.86)
					{
						isClear = NO;
						
						// okay it's in the way .. give it a wee nudge (0.25s)
						[ship update: 0.25];
						time_out += 0.25;
					}
					if (time_out > 0)
					{
						Vector v1 = vector_forward_from_quaternion(orientation);
						Vector spos = ship->position;
						spos.x += 3000.0 * v1.x;	spos.y += 3000.0 * v1.y;	spos.z += 3000.0 * v1.z; 
						[ship setPosition:spos]; // move 3km out of the way
					}
				}
			} while (!isClear);
		}
	}
	
	for (i = 0; i < ship_count; i++)
		[my_entities[i] release];		//released

}


- (void)setDimensionsAndCorridor
{

	BoundingBox bb = [self boundingBox];
	port_dimensions = make_vector(bb.max.x - bb.min.x, bb.max.y - bb.min.y, bb.max.z - bb.min.z);

	Vector vk = vector_forward_from_quaternion(orientation);

	BoundingBox stbb = [[self parentEntity] boundingBox];
	Vector start = position;
	while (	(start.x > stbb.min.x)&&(start.x < stbb.max.x)&&
		   (start.y > stbb.min.y)&&(start.y < stbb.max.y)&&
		   (start.z > stbb.min.z)&&(start.z < stbb.max.z) )
	{
		start = vector_add(start, vector_multiply_scalar(vk, port_dimensions.z));
	}
	port_corridor = start.z - position.z;

}



//////////////////////////////////////////////// from superclass

- (BOOL) isDock
{
	return YES;
}


- (id)initWithKey:(NSString *)key definition:(NSDictionary *)dict
{
	OOJS_PROFILE_ENTER
	
	self = [super initWithKey:key definition:dict];
	if (self != nil)
	{
		shipsOnApproach = [[NSMutableDictionary alloc] init];
		launchQueue = [[NSMutableArray alloc] init];
		allow_docking = YES;
		allow_launching = YES;
// TODO: do something with these variables
	}


	return self;
	
	OOJS_PROFILE_EXIT
}


- (void) dealloc
{
	DESTROY(shipsOnApproach);
	DESTROY(launchQueue);
	[self clearIdLocks:nil];
	
	[super dealloc];
}

- (void) clearIdLocks:(ShipEntity *)ship
{
	int i;
	for (i = 1; i < MAX_DOCKING_STAGES; i++)
	{
		if (ship == nil || ship == [id_lock[i] weakRefUnderlyingObject])
		{
			DESTROY(id_lock[i]);
		}
	}
}


- (BOOL) setUpShipFromDictionary:(NSDictionary *) dict
{
	OOJS_PROFILE_ENTER
	
	isShip = YES;
	isStation = NO;
	
	if (![super setUpShipFromDictionary:dict])  return NO;

	return YES;
	
	OOJS_PROFILE_EXIT
}


	
- (void) update:(OOTimeDelta) delta_t
{

	[super update:delta_t];

	if (([launchQueue count] > 0)&&([shipsOnApproach count] == 0)&&[self dockingCorridorIsEmpty])
	{
		ShipEntity *se=(ShipEntity *)[launchQueue objectAtIndex:0];
		[self launchShip:se];
		[launchQueue removeObjectAtIndex:0];
	}
	if (([launchQueue count] == 0)&&(no_docking_while_launching))
		no_docking_while_launching = NO;	// launching complete

	if (approach_spacing > 0.0)
	{
		approach_spacing -= delta_t * 10.0;	// reduce by 10 m/s
		if (approach_spacing < 0.0)   approach_spacing = 0.0;
	}


}




@end


