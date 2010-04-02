/*

Entity.m

Oolite
Copyright (C) 2004-2008 Giles C Williams and contributors

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

#import "Entity.h"
#import "EntityOOJavaScriptExtensions.h"
#import "PlayerEntity.h"
#import "OOPlanetEntity.h"

#import "OOMaths.h"
#import "Geometry.h"
#import "Universe.h"
#import "GameController.h"
#import "ResourceManager.h"
#import "OOConstToString.h"

#import "CollisionRegion.h"

#import "NSScannerOOExtensions.h"

#define kOOLogUnconvertedNSLog @"unclassified.Entity"

#ifndef NDEBUG
uint32_t gLiveEntityCount = 0;
size_t gTotalEntityMemory = 0;
#if __OBJC2__
#import <objc/runtime.h>
#else
#if OOLITE_MAC_OS_X
#import <objc/objc-class.h>
#endif
OOINLINE size_t class_getInstanceSize(Class cls)
{
	return cls->instance_size;
}
#endif
#endif


static NSString * const kOOLogEntityAddToList				= @"entity.linkedList.add";
static NSString * const kOOLogEntityAddToListError			= @"entity.linkedList.add.error";
static NSString * const kOOLogEntityRemoveFromList			= @"entity.linkedList.remove";
static NSString * const kOOLogEntityRemoveFromListError		= @"entity.linkedList.remove.error";
	   NSString * const kOOLogEntityVerificationError		= @"entity.linkedList.verify.error";
static NSString * const kOOLogEntityUpdateError				= @"entity.linkedList.update.error";


@interface Entity (OOPrivate)

- (BOOL) checkLinkedLists;

@end


@implementation Entity

- (id) init
{
	self = [super init];
	
	orientation = kIdentityQuaternion;
	rotMatrix = kIdentityMatrix;
	position = kZeroVector;
	
	no_draw_distance = 100000.0;  //  10 km
	
	collidingEntities = [[NSMutableArray alloc] init];
	
	scanClass = CLASS_NOT_SET;
	[self setStatus:STATUS_COCKPIT_DISPLAY];
	
	spawnTime = [UNIVERSE getTime];
	
	isSunlit = YES;
	
#ifndef NDEBUG
	gLiveEntityCount++;
	gTotalEntityMemory += class_getInstanceSize([self class]);
#endif
	
	return self;
}


- (void) dealloc
{
	[UNIVERSE ensureEntityReallyRemoved:self];
	[collidingEntities release];
	[collisionRegion release];
	[self deleteJSSelf];
	[self setOwner:nil];
	
#ifndef NDEBUG
	gLiveEntityCount--;
	gTotalEntityMemory -= class_getInstanceSize([self class]);
#endif
	
	[super dealloc];
}


- (NSString *)descriptionComponents
{
	return [NSString stringWithFormat:@"ID: %u position: %@ scanClass: %@ status: %@", [self universalID], VectorDescription([self position]), ScanClassToString([self scanClass]), EntityStatusToString([self status])];
}


- (BOOL)isShip
{
	return isShip;
}


- (BOOL)isStation
{
	return isStation;
}


- (BOOL)isSubEntity
{
	return isSubEntity;
}


- (BOOL)isPlayer
{
	return isPlayer;
}


- (BOOL)isPlanet
{
	return NO;
}


- (BOOL)isSun
{
	return NO;
}


- (BOOL) isStellarObject
{
	return [self isPlanet] || [self isSun];
}


- (BOOL)isSky
{
	return isSky;
}

- (BOOL)isWormhole
{
	return isWormhole;
}


- (BOOL) validForAddToUniverse
{
	return YES;
}


- (void) addToLinkedLists
{
#ifndef NDEBUG
	if (gDebugFlags & DEBUG_LINKED_LISTS)
		OOLog(kOOLogEntityAddToList, @"DEBUG adding entity %@ to linked lists", self);
#endif
	//
	// insert at the start
	if (UNIVERSE)
	{
		x_previous = nil; x_next = UNIVERSE->x_list_start;
		// move UP the list
		while ((x_next)&&(x_next->position.x - x_next->collision_radius < position.x - collision_radius))
		{
			x_previous = x_next;
			x_next = x_next->x_next;
		}	
		if (x_next)		x_next->x_previous = self;
		if (x_previous) x_previous->x_next = self;
		else			UNIVERSE->x_list_start = self;
		
		y_previous = nil; y_next = UNIVERSE->y_list_start;
		// move UP the list
		while ((y_next)&&(y_next->position.y - y_next->collision_radius < position.y - collision_radius))
		{
			y_previous = y_next;
			y_next = y_next->y_next;
		}	
		if (y_next)		y_next->y_previous = self;
		if (y_previous) y_previous->y_next = self;
		else			UNIVERSE->y_list_start = self;

		z_previous = nil; z_next = UNIVERSE->z_list_start;
		// move UP the list
		while ((z_next)&&(z_next->position.z - z_next->collision_radius < position.z - collision_radius))
		{
			z_previous = z_next;
			z_next = z_next->z_next;
		}	
		if (z_next)		z_next->z_previous = self;
		if (z_previous) z_previous->z_next = self;
		else			UNIVERSE->z_list_start = self;
				
	}
	
#ifndef NDEBUG
	if (gDebugFlags & DEBUG_LINKED_LISTS)
	{
		if (![self checkLinkedLists])
		{
			OOLog(kOOLogEntityAddToListError, @"DEBUG LINKED LISTS - problem encountered while adding %@ to linked lists", self);
			[UNIVERSE obj_dump];
		
			exit(-1);
		}
	}
#endif
}


- (void) removeFromLinkedLists
{
#ifndef NDEBUG
	if (gDebugFlags & DEBUG_LINKED_LISTS)
		OOLog(kOOLogEntityRemoveFromList, @"DEBUG removing entity %@ from linked lists", self);
#endif
	
	if ((x_next == nil)&&(x_previous == nil))	// removed already!
		return;

	// make sure the starting point is still correct
	if (UNIVERSE)
	{
		if ((UNIVERSE->x_list_start == self)&&(x_next))
				UNIVERSE->x_list_start = x_next;
		if ((UNIVERSE->y_list_start == self)&&(y_next))
				UNIVERSE->y_list_start = y_next;
		if ((UNIVERSE->z_list_start == self)&&(z_next))
				UNIVERSE->z_list_start = z_next;
	}
	//
	if (x_previous)		x_previous->x_next = x_next;
	if (x_next)			x_next->x_previous = x_previous;
	//
	if (y_previous)		y_previous->y_next = y_next;
	if (y_next)			y_next->y_previous = y_previous;
	//
	if (z_previous)		z_previous->z_next = z_next;
	if (z_next)			z_next->z_previous = z_previous;
	//
	x_previous = nil;	x_next = nil;
	y_previous = nil;	y_next = nil;
	z_previous = nil;	z_next = nil;

#ifndef NDEBUG
	if (gDebugFlags & DEBUG_LINKED_LISTS)
	{
		if (![self checkLinkedLists])
		{
			OOLog(kOOLogEntityRemoveFromListError, @"DEBUG LINKED LISTS - problem encountered while removing %@ from linked lists", self);
			[UNIVERSE obj_dump];
		
			exit(-1);
		}
	}
#endif
}


- (BOOL) checkLinkedLists
{
	// DEBUG check for loops
	if (UNIVERSE->n_entities > 0)
	{
		int n;
		Entity	*check, *last;
		//
		last = nil;
		//
		n = UNIVERSE->n_entities;
		check = UNIVERSE->x_list_start;
		while ((n--)&&(check))
		{
			last = check;
			check = check->x_next;
		}
		if ((check)||(n > 0))
		{
			OOLog(kOOLogEntityVerificationError, @"Broken x_next %@ list (%d) ***", UNIVERSE->x_list_start, n);
			return NO;
		}
		//
		n = UNIVERSE->n_entities;
		check = last;
		while ((n--)&&(check))	check = check->x_previous;
		if ((check)||(n > 0))
		{
			OOLog(kOOLogEntityVerificationError, @"Broken x_previous %@ list (%d) ***", UNIVERSE->x_list_start, n);
			return NO;
		}
		//
		n = UNIVERSE->n_entities;
		check = UNIVERSE->y_list_start;
		while ((n--)&&(check))
		{
			last = check;
			check = check->y_next;
		}
		if ((check)||(n > 0))
		{
			OOLog(kOOLogEntityVerificationError, @"Broken y_next %@ list (%d) ***", UNIVERSE->y_list_start, n);
			return NO;
		}
		//
		n = UNIVERSE->n_entities;
		check = last;
		while ((n--)&&(check))	check = check->y_previous;
		if ((check)||(n > 0))
		{
			OOLog(kOOLogEntityVerificationError, @"Broken y_previous %@ list (%d) ***", UNIVERSE->y_list_start, n);
			return NO;
		}
		//
		n = UNIVERSE->n_entities;
		check = UNIVERSE->z_list_start;
		while ((n--)&&(check))
		{
			last = check;
			check = check->z_next;
		}
		if ((check)||(n > 0))
		{
			OOLog(kOOLogEntityVerificationError, @"Broken z_next %@ list (%d) ***", UNIVERSE->z_list_start, n);
			return NO;
		}
		//
		n = UNIVERSE->n_entities;
		check = last;
		while ((n--)&&(check))	check = check->z_previous;
		if ((check)||(n > 0))
		{
			OOLog(kOOLogEntityVerificationError, @"Broken z_previous %@ list (%d) ***", UNIVERSE->z_list_start, n);
			return NO;
		}
	}
	return YES;
}


- (void) updateLinkedLists
{
	if (!UNIVERSE)
		return;	// not in the UNIVERSE - don't do this!
	if ((x_next == nil)&&(x_previous == nil))
		return;	// not in the lists - don't do this!
	
#ifndef NDEBUG
	if (gDebugFlags & DEBUG_LINKED_LISTS)
	{
		if (![self checkLinkedLists])
		{
			OOLog(kOOLogEntityVerificationError, @"DEBUG LINKED LISTS problem encountered before updating linked lists for %@", self);
			[UNIVERSE obj_dump];
		
			exit(-1);
		}
	}
#endif
	
	// update position in linked list for position.x
	// take self out of list..
	if (x_previous)		x_previous->x_next = x_next;
	if (x_next)			x_next->x_previous = x_previous;
	// sink DOWN the list
	while ((x_previous)&&(x_previous->position.x - x_previous->collision_radius > position.x - collision_radius))
	{
		x_next = x_previous;
		x_previous = x_previous->x_previous;
	}
	// bubble UP the list
	while ((x_next)&&(x_next->position.x - x_next->collision_radius < position.x - collision_radius))
	{
		x_previous = x_next;
		x_next = x_next->x_next;
	}
	if (x_next)		// insert self into the list before x_next..
		x_next->x_previous = self;
	if (x_previous)	// insert self into the list after x_previous..
		x_previous->x_next = self;
	if ((x_previous == nil)&&(UNIVERSE))	// if we're the first then tell the UNIVERSE!
			UNIVERSE->x_list_start = self;
	
	// update position in linked list for position.y
	// take self out of list..
	if (y_previous)		y_previous->y_next = y_next;
	if (y_next)			y_next->y_previous = y_previous;
	// sink DOWN the list
	while ((y_previous)&&(y_previous->position.y - y_previous->collision_radius > position.y - collision_radius))
	{
		y_next = y_previous;
		y_previous = y_previous->y_previous;
	}
	// bubble UP the list
	while ((y_next)&&(y_next->position.y - y_next->collision_radius < position.y - collision_radius))
	{
		y_previous = y_next;
		y_next = y_next->y_next;
	}
	if (y_next)		// insert self into the list before y_next..
		y_next->y_previous = self;
	if (y_previous)	// insert self into the list after y_previous..
		y_previous->y_next = self;
	if ((y_previous == nil)&&(UNIVERSE))	// if we're the first then tell the UNIVERSE!
			UNIVERSE->y_list_start = self;
	
	// update position in linked list for position.z
	// take self out of list..
	if (z_previous)		z_previous->z_next = z_next;
	if (z_next)			z_next->z_previous = z_previous;
	// sink DOWN the list
	while ((z_previous)&&(z_previous->position.z - z_previous->collision_radius > position.z - collision_radius))
	{
		z_next = z_previous;
		z_previous = z_previous->z_previous;
	}
	// bubble UP the list
	while ((z_next)&&(z_next->position.z - z_next->collision_radius < position.z - collision_radius))
	{
		z_previous = z_next;
		z_next = z_next->z_next;
	}
	if (z_next)		// insert self into the list before z_next..
		z_next->z_previous = self;
	if (z_previous)	// insert self into the list after z_previous..
		z_previous->z_next = self;
	if ((z_previous == nil)&&(UNIVERSE))	// if we're the first then tell the UNIVERSE!
			UNIVERSE->z_list_start = self;
	
	// done
#ifndef NDEBUG
	if (gDebugFlags & DEBUG_LINKED_LISTS)
	{
		if (![self checkLinkedLists])
		{
			OOLog(kOOLogEntityUpdateError, @"DEBUG LINKED LISTS problem encountered after updating linked lists for %@", self);
			[UNIVERSE obj_dump];
		
			exit(-1);
		}
	}
#endif
}


- (void) wasAddedToUniverse
{
	// Do nothing
}


- (void) wasRemovedFromUniverse
{
	// Do nothing
}


- (void) warnAboutHostiles
{
	// do nothing for now, this can be expanded in sub classes
	OOLog(@"general.error.subclassResponsibility.Entity-warnAboutHostiles", @"***** Entity does nothing in warnAboutHostiles");
}


- (CollisionRegion*) collisionRegion
{
	return collisionRegion;
}


- (void) setCollisionRegion: (CollisionRegion*) region
{
	if (collisionRegion) [collisionRegion release];
	collisionRegion = [region retain];
}


- (void) setUniversalID:(OOUniversalID)uid
{
	universalID = uid;
}


- (OOUniversalID) universalID
{
	return universalID;
}


- (BOOL) throwingSparks
{
	return throw_sparks;
}


- (void) setThrowSparks:(BOOL) value
{
	throw_sparks = value;
}


- (void) throwSparks;
{
	// do nothing for now
}


- (void) setOwner:(Entity *)ent
{
	[_owner release];
	_owner = [ent weakRetain];
}


- (id) owner
{
	return [_owner weakRefUnderlyingObject];
}


- (ShipEntity *)parentEntity
{
	id owner = [self owner];
	if ([owner isShipWithSubEntityShip:self])  return owner;
	return nil;
}


- (id<OOWeakReferenceSupport>) superShaderBindingTarget
{
	return [self parentEntity];
}


- (ShipEntity *) rootShipEntity
{
	ShipEntity *parent = [self parentEntity];
	if (parent != nil)  return [parent rootShipEntity];
	if ([self isShip])  return (ShipEntity *)self;
	return nil;
}


- (void) setPosition:(Vector) posn
{
	position = posn;
}


- (void) setPositionX:(GLfloat)x y:(GLfloat)y z:(GLfloat)z
{
	position.x = x;
	position.y = y;
	position.z = z;
}


- (Vector) absolutePositionForSubentity
{
	return [self absolutePositionForSubentityOffset:kZeroVector];
}


- (Vector) absolutePositionForSubentityOffset:(Vector) offset
{
	Vector		abspos = vector_add(position, OOVectorMultiplyMatrix(offset, rotMatrix));
	Entity		*last = nil;
	Entity		*father = [self parentEntity];
	OOMatrix	r_mat;
	
	while ((father)&&(father != last)  && (father != NO_TARGET))
	{
		r_mat = [father drawRotationMatrix];
		abspos = vector_add(OOVectorMultiplyMatrix(abspos, r_mat), [father position]);
		last = father;
		if (![last isSubEntity]) break;
		father = [father owner];
	}
	return abspos;
}


- (double) zeroDistance
{
	return zero_distance;
}


- (Vector) relativePosition
{
	return relativePosition;
}


- (NSComparisonResult) compareZeroDistance:(Entity *)otherEntity;
{
	if ((otherEntity)&&(zero_distance > otherEntity->zero_distance))
		return NSOrderedAscending;
	else
		return NSOrderedDescending;
}


- (BoundingBox) boundingBox
{
	return boundingBox;
}


- (GLfloat) mass
{
	return mass;
}


- (void) setOrientation:(Quaternion) quat
{
	orientation = quat;
	[self orientationChanged];
}


- (Quaternion) orientation
{
	return orientation;
}


- (Quaternion) normalOrientation
{
	return [self orientation];
}


- (void) setNormalOrientation:(Quaternion) quat
{
	[self setOrientation:quat];
}


- (void) orientationChanged
{
	quaternion_normalize(&orientation);
	rotMatrix = OOMatrixForQuaternionRotation(orientation);
}


- (void) setVelocity:(Vector) vel
{
	velocity = vel;
}


- (Vector) velocity
{
	return velocity;
}


- (double) speed
{
	return magnitude2(velocity);
}


- (GLfloat) distanceTravelled
{
	return distanceTravelled;
}


- (void) setDistanceTravelled: (GLfloat) value
{
	distanceTravelled = value;
}


- (void) setStatus:(OOEntityStatus) stat
{
	_status = stat;
}


- (OOEntityStatus) status
{
	return _status;
}


- (void) setScanClass:(OOScanClass)sClass
{
	scanClass = sClass;
}


- (OOScanClass) scanClass
{
	return scanClass;
}


- (void) setEnergy:(GLfloat) amount
{
	energy = amount;
}


- (GLfloat) energy
{
	return energy;
}


- (void) setMaxEnergy:(GLfloat)amount
{
	maxEnergy = amount;
}


- (GLfloat) maxEnergy
{
	return maxEnergy;
}


- (void) applyRoll:(GLfloat) roll andClimb:(GLfloat) climb
{
	if ((roll == 0.0)&&(climb == 0.0)&&(!hasRotated))
		return;

	if (roll)
		quaternion_rotate_about_z(&orientation, -roll);
	if (climb)
		quaternion_rotate_about_x(&orientation, -climb);
	
	[self orientationChanged];
}


- (void) applyRoll:(GLfloat) roll climb:(GLfloat) climb andYaw:(GLfloat) yaw
{
	if ((roll == 0.0)&&(climb == 0.0)&&(yaw == 0.0)&&(!hasRotated))
		return;

	if (roll)
		quaternion_rotate_about_z(&orientation, -roll);
	if (climb)
		quaternion_rotate_about_x(&orientation, -climb);
	if (yaw)
		quaternion_rotate_about_y(&orientation, -yaw);

	[self orientationChanged];
}


- (void) moveForward:(double) amount
{
	Vector		forward = vector_forward_from_quaternion(orientation);
	distanceTravelled += amount;
	position.x += amount * forward.x;
	position.y += amount * forward.y;
	position.z += amount * forward.z;
}


- (OOMatrix) rotationMatrix
{
	return rotMatrix;
}


- (OOMatrix) drawRotationMatrix
{
	return rotMatrix;
}


- (OOMatrix) transformationMatrix
{
	OOMatrix result = rotMatrix;
	return OOMatrixTranslate(result, position);
}


- (OOMatrix) drawTransformationMatrix
{
	OOMatrix result = rotMatrix;
	return OOMatrixTranslate(result, position);
}


- (Vector) position
{
	return position;
}


- (BOOL) canCollide
{
	return YES;
}


- (GLfloat) collisionRadius
{
	return collision_radius;
}


- (void) setCollisionRadius:(GLfloat) amount
{
	collision_radius = amount;
}


- (NSMutableArray *) collisionArray
{
	return collidingEntities;
}


- (void) update:(OOTimeDelta) delta_t
{
	PlayerEntity *player = [PlayerEntity sharedPlayer];
	if (player)
	{
		if ([self status] != STATUS_COCKPIT_DISPLAY)
			relativePosition = vector_between(player->position, position);
		else
			relativePosition = position;
		//
		zero_distance = magnitude2(relativePosition);
	}
	else
		zero_distance = -1;

	hasMoved = !vector_equal(position, lastPosition);
	hasRotated = !quaternion_equal(orientation, lastOrientation);
	lastPosition = position;
	lastOrientation = orientation;
}


- (BOOL) checkCloseCollisionWith:(Entity *)other
{
	return other != nil;
}


- (double)findCollisionRadius
{
	OOLogGenericSubclassResponsibility();
	return 0;
}


- (Geometry *)geometry
{
	OOLogGenericSubclassResponsibility();
	return nil;
}


- (void) drawEntity:(BOOL)immediate :(BOOL)translucent
{
	OOLogGenericSubclassResponsibility();
}


- (void) takeEnergyDamage:(double) amount from:(Entity *) ent becauseOf:(Entity *) other
{
	
}


- (void)dumpState
{
	if (OOLogWillDisplayMessagesInClass(@"dumpState"))
	{
		OOLog(@"dumpState", @"State for %@:", self);
		OOLogPushIndent();
		OOLogIndent();
		NS_DURING
			[self dumpSelfState];
		NS_HANDLER
		NS_ENDHANDLER
		OOLogPopIndent();
	}
}


- (void)dumpSelfState
{
	NSMutableArray		*flags = nil;
	NSString			*flagsString = nil;
	Entity				*owner = [self owner];
	
	OOLog(@"dumpState.entity", @"Universal ID: %u", universalID);
	OOLog(@"dumpState.entity", @"Scan class: %@", ScanClassToString(scanClass));
	OOLog(@"dumpState.entity", @"Status: %@", EntityStatusToString([self status]));
	OOLog(@"dumpState.entity", @"Position: %@", VectorDescription(position));
	OOLog(@"dumpState.entity", @"Orientation: %@", QuaternionDescription(orientation));
	OOLog(@"dumpState.entity", @"Distance travelled: %g", distanceTravelled);
	OOLog(@"dumpState.entity", @"Energy: %g of %g", energy, maxEnergy);
	OOLog(@"dumpState.entity", @"Mass: %g", mass);
	if (owner != nil)  OOLog(@"dumpState.entity", @"Owner: %@", owner);
	
	flags = [NSMutableArray array];
	#define ADD_FLAG_IF_SET(x)		if (x) { [flags addObject:@#x]; }
	ADD_FLAG_IF_SET(isRing);
	ADD_FLAG_IF_SET(isShip);
	ADD_FLAG_IF_SET(isStation);
	ADD_FLAG_IF_SET(isPlayer);
	ADD_FLAG_IF_SET(isSky);
	ADD_FLAG_IF_SET(isWormhole);
	ADD_FLAG_IF_SET(isSubEntity);
	ADD_FLAG_IF_SET(hasMoved);
	ADD_FLAG_IF_SET(hasRotated);
	ADD_FLAG_IF_SET(isSunlit);
	ADD_FLAG_IF_SET(collisionTestFilter);
	ADD_FLAG_IF_SET(throw_sparks);
	flagsString = [flags count] ? [flags componentsJoinedByString:@", "] : (NSString *)@"none";
	OOLog(@"dumpState.entity", @"Flags: %@", flagsString);
}


- (void)subEntityReallyDied:(ShipEntity *)sub
{
	OOLog(@"entity.bug", @"%s called for non-ship entity %p by %p", __FUNCTION__, self, sub);
}


// For shader bindings.
- (GLfloat)universalTime
{
	return [UNIVERSE getTime];
}


- (GLfloat)spawnTime
{
	return spawnTime;
}


- (GLfloat)timeElapsedSinceSpawn
{
	return [UNIVERSE getTime] - spawnTime;
}

@end