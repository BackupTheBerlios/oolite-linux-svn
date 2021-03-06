/*

	Oolite

	Geometry.m
	
	Created by Giles Williams on 30/01/2006.


Copyright (c) 2005, Giles C Williams
All rights reserved.

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike License.
To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/2.0/
or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

You are free:

•	to copy, distribute, display, and perform the work
•	to make derivative works

Under the following conditions:

•	Attribution. You must give the original author credit.

•	Noncommercial. You may not use this work for commercial purposes.

•	Share Alike. If you alter, transform, or build upon this work,
you may distribute the resulting work only under a license identical to this one.

For any reuse or distribution, you must make clear to others the license terms of this work.

Any of these conditions can be waived if you get permission from the copyright holder.

Your fair use and other rights are in no way affected by the above.

*/

#import "Geometry.h"

#import "vector.h"
#import "Octree.h"
#import "ShipEntity.h"


@implementation Geometry

- (NSString*) description
{
	NSString* result = [[NSString alloc] initWithFormat:@"<Geometry with %d triangles currently %@.>", n_triangles, [self testIsConvex]? @"Convex":@"not convex"];
	return [result autorelease];
}

- (id) initWithCapacity:(int) amount
{
	if (amount < 1)
		return nil;
	self = [super init];
	
	max_triangles = amount;
	triangles = (Triangle*) malloc( max_triangles * sizeof(Triangle));	// allocate the required space
	n_triangles = 0;
	isConvex = NO;
	
	return self;
}

- (void) dealloc
{
	free((void *)triangles);	// free up the allocated space
	[super dealloc];
}

- (BOOL) isConvex
{
	return isConvex;
}

- (void) setConvex:(BOOL) value
{
	isConvex = value;
}

- (void) addTriangle:(Triangle) tri
{
	// check for degenerate triangles
	if ((tri.v[0].x == tri.v[1].x)&&(tri.v[0].y == tri.v[1].y)&&(tri.v[0].z == tri.v[1].z))	// v0 == v1 -> return
		return;
	if ((tri.v[1].x == tri.v[2].x)&&(tri.v[1].y == tri.v[2].y)&&(tri.v[1].z == tri.v[2].z))	// v1 == v2 -> return
		return;
	if ((tri.v[2].x == tri.v[0].x)&&(tri.v[2].y == tri.v[0].y)&&(tri.v[2].z == tri.v[0].z))	// v2 == v0 -> return
		return;
	// clear!
	//
	// check for no-more-room
	if (n_triangles == max_triangles)
	{
		// create more space by doubling the capacity of this geometry...
		int i;
		max_triangles = 1 + max_triangles * 2;
		Triangle* old_triangles = triangles;
		Triangle* new_triangles = (Triangle *) malloc( max_triangles * sizeof(Triangle));
		
		if (!new_triangles)	// couldn't allocate space
		{
			NSLog(@" --- ran out of memory to allocate more geometry!");
			exit(-1);
		}
		
		for (i = 0; i < n_triangles; i++)
			new_triangles[i] = old_triangles[i];	// copy old->new
		triangles = new_triangles;
		free((void *) old_triangles);	// free up previous memory
	}
	triangles[n_triangles++] = tri;
}

- (BOOL) testHasGeometry
{
	return (n_triangles > 0);
}

- (BOOL) testIsConvex
{
	// enumerate over triangles
	// calculate normal for each one
	// then enumerate over vertices relative to a vertex on the triangle
	// and check if they are on the forwardside or coplanar with the triangle
	// if a vertex is on the backside of any triangle then return NO;
	int i, j;
	for (i = 0; i < n_triangles; i++)
	{
		Vector v0 = triangles[i].v[0];
		Vector vn = calculateNormalForTriangle(&triangles[i]);
		//
		for (j = 0; j < n_triangles; j++)
		{
			if (j != i)
			{
				if ((dot_product( vector_between( v0, triangles[j].v[0]), vn) < -0.001)||
					(dot_product( vector_between( v0, triangles[j].v[1]), vn) < -0.001)||
					(dot_product( vector_between( v0, triangles[j].v[2]), vn) < -0.001))	// within 1mm tolerance
				{
					isConvex = NO;
					return NO;
				}
			}
		}
	}
	isConvex = YES;
	return YES;
}

- (BOOL) testCornersWithinGeometry:(GLfloat) corner;
{
	// enumerate over triangles
	// calculate normal for each one
	// then enumerate over corners relative to a vertex on the triangle
	// and check if they are on the forwardside or coplanar with the triangle
	// if a corner is on the backside of any triangle then return NO;
	int i, x, y, z;
	for (i = 0; i < n_triangles; i++)
	{
		Vector v0 = triangles[i].v[0];
		Vector vn = calculateNormalForTriangle(&triangles[i]);
		//
		for (z = -1; z < 2; z += 2) for (y = -1; y < 2; y += 2) for (x = -1; x < 2; x += 2)
		{
			Vector vc = make_vector( corner * x, corner * y, corner * z);
			if (dot_product( vector_between( v0, vc), vn) < -0.001)
				return NO;
		}
	}
	return YES;
}

- (GLfloat) findMaxDimensionFromOrigin
{
	// enumerate over triangles
	GLfloat result = 0;
	int i, j;
	for (i = 0; i < n_triangles; i++) for (j = 0; j < 3; j++)
	{
		Vector v = triangles[i].v[j];
		if (fabs(v.x) > result)
			result = fabs(v.x);
		if (fabs(v.y) > result)
			result = fabs(v.y);
		if (fabs(v.z) > result)
			result = fabs(v.z);
	}
	return result;
}

static int leafcount;
static float volumecount;
- (Octree*) findOctreeToDepth: (int) depth
{
	//
	leafcount = 0;
	volumecount = 0.0;
	//
	GLfloat foundRadius = 0.5 + [self findMaxDimensionFromOrigin];	// pad out from geometry by a half meter
	//	
	NSObject* foundOctree = [self octreeWithinRadius:foundRadius toDepth:depth];
	//
//	NSLog(@"octree found has %d leafs - object has volume %.2f mass %.2f", leafcount, volumecount, volumecount * 8.0);
	//
	Octree*	octreeRepresentation = [[Octree alloc] initWithRepresentationOfOctree:foundRadius :foundOctree :leafcount];
	//
	return [octreeRepresentation autorelease];
}

- (NSObject*) octreeWithinRadius:(GLfloat) octreeRadius toDepth: (int) depth;
{
	//
	GLfloat offset = 0.5 * octreeRadius;
	//
	if (![self testHasGeometry])
	{
		leafcount++;	// nil or zero or 0
		return [NSNumber numberWithBool:NO];	// empty octree
	}
	// there is geometry!
	//
	if ((octreeRadius <= OCTREE_MIN_RADIUS)||(depth <= 0))	// maximum resolution
	{
		leafcount++;	// partially full or -1
		volumecount += octreeRadius * octreeRadius * octreeRadius * 0.5;
		return [NSNumber numberWithBool:YES];	// at least partially full octree
	}
	//
	if (!isConvex)
		[self testIsConvex]; // check!
	//
	if (isConvex)	// we're convex!
	{
		if ([self testCornersWithinGeometry: octreeRadius])	// all eight corners inside or on!
		{
			leafcount++;	// full or -1
			volumecount += octreeRadius * octreeRadius * octreeRadius;
			return [NSNumber numberWithBool:YES];	// full octree
		}
	}
	//
	Geometry* g_000 = [[Geometry alloc] initWithCapacity:n_triangles];
	Geometry* g_001 = [[Geometry alloc] initWithCapacity:n_triangles];
	Geometry* g_010 = [[Geometry alloc] initWithCapacity:n_triangles];
	Geometry* g_011 = [[Geometry alloc] initWithCapacity:n_triangles];
	Geometry* g_100 = [[Geometry alloc] initWithCapacity:n_triangles];
	Geometry* g_101 = [[Geometry alloc] initWithCapacity:n_triangles];
	Geometry* g_110 = [[Geometry alloc] initWithCapacity:n_triangles];
	Geometry* g_111 = [[Geometry alloc] initWithCapacity:n_triangles];
	//
	Geometry* g_xx1 =	[[Geometry alloc] initWithCapacity:n_triangles];
	Geometry* g_xx0 =	[[Geometry alloc] initWithCapacity:n_triangles];
	//
	[self z_axisSplitBetween:g_xx1 :g_xx0 : offset];
	if ([g_xx0 testHasGeometry])
	{
		Geometry* g_x00 =	[[Geometry alloc] initWithCapacity:n_triangles];
		Geometry* g_x10 =	[[Geometry alloc] initWithCapacity:n_triangles];
		//
		[g_xx0 y_axisSplitBetween: g_x10 : g_x00 : offset];
		if ([g_x00 testHasGeometry])
		{
			[g_x00 x_axisSplitBetween:g_100 :g_000 : offset];
			[g_000 setConvex: isConvex];
			[g_100 setConvex: isConvex];
		}
		if ([g_x10 testHasGeometry])
		{
			[g_x10 x_axisSplitBetween:g_110 :g_010 : offset];
			[g_010 setConvex: isConvex];
			[g_110 setConvex: isConvex];
		}
		[g_x00 release];
		[g_x10 release];
	}
	if ([g_xx1 testHasGeometry])
	{
		Geometry* g_x01 =	[[Geometry alloc] initWithCapacity:n_triangles];
		Geometry* g_x11 =	[[Geometry alloc] initWithCapacity:n_triangles];
		//
		[g_xx1 y_axisSplitBetween: g_x11 : g_x01 :offset];
		if ([g_x01 testHasGeometry])
		{
			[g_x01 x_axisSplitBetween:g_101 :g_001 :offset];
			[g_001 setConvex: isConvex];
			[g_101 setConvex: isConvex];
		}
		if ([g_x11 testHasGeometry])
		{
			[g_x11 x_axisSplitBetween:g_111 :g_011 :offset];
			[g_011 setConvex: isConvex];
			[g_111 setConvex: isConvex];
		}
		[g_x01 release];
		[g_x11 release];
	}
	[g_xx0 release];
	[g_xx1 release];
	
	leafcount++;	// pointer to array
	NSObject* result = [NSArray arrayWithObjects:
		[g_000 octreeWithinRadius: offset toDepth:depth - 1],
		[g_001 octreeWithinRadius: offset toDepth:depth - 1],
		[g_010 octreeWithinRadius: offset toDepth:depth - 1],
		[g_011 octreeWithinRadius: offset toDepth:depth - 1],
		[g_100 octreeWithinRadius: offset toDepth:depth - 1],
		[g_101 octreeWithinRadius: offset toDepth:depth - 1],
		[g_110 octreeWithinRadius: offset toDepth:depth - 1],
		[g_111 octreeWithinRadius: offset toDepth:depth - 1],
		nil];
	[g_000 release];
	[g_001 release];
	[g_010 release];
	[g_011 release];
	[g_100 release];
	[g_101 release];
	[g_110 release];
	[g_111 release];
	//
	return result;
}

- (void) translate:(Vector) offset
{
	int i;
	for (i = 0; i < n_triangles; i++)
	{
		triangles[i].v[0].x += offset.x;
		triangles[i].v[1].x += offset.x;
		triangles[i].v[2].x += offset.x;
		
		triangles[i].v[0].y += offset.y;
		triangles[i].v[1].y += offset.y;
		triangles[i].v[2].y += offset.y;
		
		triangles[i].v[0].z += offset.z;
		triangles[i].v[1].z += offset.z;
		triangles[i].v[2].z += offset.z;
	}
}

- (void) scale:(GLfloat) scalar
{
	int i;
	for (i = 0; i < n_triangles; i++)
	{
		triangles[i].v[0].x *= scalar;
		triangles[i].v[1].x *= scalar;
		triangles[i].v[2].x *= scalar;
		triangles[i].v[0].y *= scalar;
		triangles[i].v[1].y *= scalar;
		triangles[i].v[2].y *= scalar;
		triangles[i].v[0].z *= scalar;
		triangles[i].v[1].z *= scalar;
		triangles[i].v[2].z *= scalar;
	}
}

- (void) x_axisSplitBetween:(Geometry*) g_plus :(Geometry*) g_minus :(GLfloat) x;
{
	// test each triangle splitting against x == 0.0
	//
	int i;
	for (i = 0; i < n_triangles; i++)
	{
		BOOL done_tri = NO;
		Vector v0 = triangles[i].v[0];
		Vector v1 = triangles[i].v[1];
		Vector v2 = triangles[i].v[2];
		
		if ((v0.x >= 0.0)&&(v1.x >= 0.0)&&(v2.x >= 0.0))
		{
			[g_plus addTriangle: triangles[i]];
			done_tri = YES;
		}
		if ((v0.x <= 0.0)&&(v1.x <= 0.0)&&(v2.x <= 0.0))
		{
			[g_minus addTriangle: triangles[i]];
			done_tri = YES;
		}
		if (!done_tri)	// triangle must cross y == 0.0
		{
			GLfloat i01, i12, i20;
			if (v0.x == v1.x)
				i01 = -1.0;
			else
				i01 = v0.x / (v0.x - v1.x);
			if (v1.x == v2.x)
				i12 = -1.0;
			else
				i12 = v1.x / (v1.x - v2.x);
			if (v2.x == v0.x)
				i20 = -1.0;
			else
				i20 = v2.x / (v2.x - v0.x);
			Vector v01 = make_vector( 0.0, i01 * (v1.y - v0.y) + v0.y, i01 * (v1.z - v0.z) + v0.z);
			Vector v12 = make_vector( 0.0, i12 * (v2.y - v1.y) + v1.y, i12 * (v2.z - v1.z) + v1.z);
			Vector v20 = make_vector( 0.0, i20 * (v0.y - v2.y) + v2.y, i20 * (v0.z - v2.z) + v2.z);
		
			// cases where a vertex is on the split..
			if (v0.x == 0.0)
			{
				if (v1.x > 0)
				{
					[g_plus addTriangle:make_triangle(v0, v1, v12)];
					[g_minus addTriangle:make_triangle(v0, v12, v2)];
				}
				else
				{
					[g_minus addTriangle:make_triangle(v0, v1, v12)];
					[g_plus addTriangle:make_triangle(v0, v12, v2)];
				}
			}
			if (v1.x == 0.0)
			{
				if (v2.x > 0)
				{
					[g_plus addTriangle:make_triangle(v1, v2, v20)];
					[g_minus addTriangle:make_triangle(v1, v20, v0)];
				}
				else
				{
					[g_minus addTriangle:make_triangle(v1, v2, v20)];
					[g_plus addTriangle:make_triangle(v1, v20, v0)];
				}
			}
			if (v2.x == 0.0)
			{
				if (v0.x > 0)
				{
					[g_plus addTriangle:make_triangle(v2, v0, v01)];
					[g_minus addTriangle:make_triangle(v2, v01, v1)];
				}
				else
				{
					[g_minus addTriangle:make_triangle(v2, v0, v01)];
					[g_plus addTriangle:make_triangle(v2, v01, v1)];
				}
			}
			
			if ((v0.x > 0.0)&&(v1.x > 0.0)&&(v2.x < 0.0))
			{
				[g_plus addTriangle:make_triangle( v0, v12, v20)];
				[g_plus addTriangle:make_triangle( v0, v1, v12)];
				[g_minus addTriangle:make_triangle( v20, v12, v2)];
			}
			
			if ((v0.x > 0.0)&&(v1.x < 0.0)&&(v2.x > 0.0))
			{
				[g_plus addTriangle:make_triangle( v2, v01, v12)];
				[g_plus addTriangle:make_triangle( v2, v0, v01)];
				[g_minus addTriangle:make_triangle( v12, v01, v1)];
			}
			
			if ((v0.x > 0.0)&&(v1.x < 0.0)&&(v2.x < 0.0))
			{
				[g_plus addTriangle:make_triangle( v20, v0, v01)];
				[g_minus addTriangle:make_triangle( v2, v20, v1)];
				[g_minus addTriangle:make_triangle( v20, v01, v1)];
			}
			
			if ((v0.x < 0.0)&&(v1.x > 0.0)&&(v2.x > 0.0))
			{
				[g_minus addTriangle:make_triangle( v01, v20, v0)];
				[g_plus addTriangle:make_triangle( v1, v20, v01)];
				[g_plus addTriangle:make_triangle( v1, v2, v20)];
			}
			
			if ((v0.x < 0.0)&&(v1.x > 0.0)&&(v2.x < 0.0))
			{
				[g_plus addTriangle:make_triangle( v01, v1, v12)];
				[g_minus addTriangle:make_triangle( v0, v01, v2)];
				[g_minus addTriangle:make_triangle( v01, v12, v2)];
			}
			
			if ((v0.x < 0.0)&&(v1.x < 0.0)&&(v2.x > 0.0))
			{
				[g_plus addTriangle:make_triangle( v12, v2, v20)];
				[g_minus addTriangle:make_triangle( v1, v12, v0)];
				[g_minus addTriangle:make_triangle( v12, v20, v0)];
			}			

		}
	}
	[g_plus translate: make_vector( -x, 0.0, 0.0)];
	[g_minus translate: make_vector( x, 0.0, 0.0)];
}

- (void) y_axisSplitBetween:(Geometry*) g_plus :(Geometry*) g_minus :(GLfloat) y;
{
	// test each triangle splitting against y == 0.0
	//
	int i;
	for (i = 0; i < n_triangles; i++)
	{
		BOOL done_tri = NO;
		Vector v0 = triangles[i].v[0];
		Vector v1 = triangles[i].v[1];
		Vector v2 = triangles[i].v[2];

		if ((v0.y >= 0.0)&&(v1.y >= 0.0)&&(v2.y >= 0.0))
		{
			[g_plus addTriangle: triangles[i]];
			done_tri = YES;
		}
		if ((v0.y <= 0.0)&&(v1.y <= 0.0)&&(v2.y <= 0.0))
		{
			[g_minus addTriangle: triangles[i]];
			done_tri = YES;
		}
		if (!done_tri)	// triangle must cross y == 0.0
		{
			GLfloat i01, i12, i20;
			if (v0.y == v1.y)
				i01 = -1.0;
			else
				i01 = v0.y / (v0.y - v1.y);
			if (v1.y == v2.y)
				i12 = -1.0;
			else
				i12 = v1.y / (v1.y - v2.y);
			if (v2.y == v0.y)
				i20 = -1.0;
			else
				i20 = v2.y / (v2.y - v0.y);
			Vector v01 = make_vector( i01 * (v1.x - v0.x) + v0.x, 0.0, i01 * (v1.z - v0.z) + v0.z);
			Vector v12 = make_vector( i12 * (v2.x - v1.x) + v1.x, 0.0, i12 * (v2.z - v1.z) + v1.z);
			Vector v20 = make_vector( i20 * (v0.x - v2.x) + v2.x, 0.0, i20 * (v0.z - v2.z) + v2.z);
			
			// cases where a vertex is on the split..
			if (v0.y == 0.0)
			{
				if (v1.y > 0)
				{
					[g_plus addTriangle:make_triangle(v0, v1, v12)];
					[g_minus addTriangle:make_triangle(v0, v12, v2)];
				}
				else
				{
					[g_minus addTriangle:make_triangle(v0, v1, v12)];
					[g_plus addTriangle:make_triangle(v0, v12, v2)];
				}
			}
			if (v1.y == 0.0)
			{
				if (v2.y > 0)
				{
					[g_plus addTriangle:make_triangle(v1, v2, v20)];
					[g_minus addTriangle:make_triangle(v1, v20, v0)];
				}
				else
				{
					[g_minus addTriangle:make_triangle(v1, v2, v20)];
					[g_plus addTriangle:make_triangle(v1, v20, v0)];
				}
			}
			if (v2.y == 0.0)
			{
				if (v0.y > 0)
				{
					[g_plus addTriangle:make_triangle(v2, v0, v01)];
					[g_minus addTriangle:make_triangle(v2, v01, v1)];
				}
				else
				{
					[g_minus addTriangle:make_triangle(v2, v0, v01)];
					[g_plus addTriangle:make_triangle(v2, v01, v1)];
				}
			}
			
			if ((v0.y > 0.0)&&(v1.y > 0.0)&&(v2.y < 0.0))
			{
				[g_plus addTriangle:make_triangle( v0, v12, v20)];
				[g_plus addTriangle:make_triangle( v0, v1, v12)];
				[g_minus addTriangle:make_triangle( v20, v12, v2)];
			}
			
			if ((v0.y > 0.0)&&(v1.y < 0.0)&&(v2.y > 0.0))
			{
				[g_plus addTriangle:make_triangle( v2, v01, v12)];
				[g_plus addTriangle:make_triangle( v2, v0, v01)];
				[g_minus addTriangle:make_triangle( v12, v01, v1)];
			}
			
			if ((v0.y > 0.0)&&(v1.y < 0.0)&&(v2.y < 0.0))
			{
				[g_plus addTriangle:make_triangle( v20, v0, v01)];
				[g_minus addTriangle:make_triangle( v2, v20, v1)];
				[g_minus addTriangle:make_triangle( v20, v01, v1)];
			}
			
			if ((v0.y < 0.0)&&(v1.y > 0.0)&&(v2.y > 0.0))
			{
				[g_minus addTriangle:make_triangle( v01, v20, v0)];
				[g_plus addTriangle:make_triangle( v1, v20, v01)];
				[g_plus addTriangle:make_triangle( v1, v2, v20)];
			}
			
			if ((v0.y < 0.0)&&(v1.y > 0.0)&&(v2.y < 0.0))
			{
				[g_plus addTriangle:make_triangle( v01, v1, v12)];
				[g_minus addTriangle:make_triangle( v0, v01, v2)];
				[g_minus addTriangle:make_triangle( v01, v12, v2)];
			}
			
			if ((v0.y < 0.0)&&(v1.y < 0.0)&&(v2.y > 0.0))
			{
				[g_plus addTriangle:make_triangle( v12, v2, v20)];
				[g_minus addTriangle:make_triangle( v1, v12, v0)];
				[g_minus addTriangle:make_triangle( v12, v20, v0)];
			}			
		}
	}
	[g_plus translate: make_vector( 0.0, -y, 0.0)];
	[g_minus translate: make_vector( 0.0, y, 0.0)];
}

- (void) z_axisSplitBetween:(Geometry*) g_plus :(Geometry*) g_minus :(GLfloat) z
{
	// test each triangle splitting against z == 0.0
	//
	int i;
	for (i = 0; i < n_triangles; i++)
	{
		BOOL done_tri = NO;
		Vector v0 = triangles[i].v[0];
		Vector v1 = triangles[i].v[1];
		Vector v2 = triangles[i].v[2];
		
		if ((v0.z >= 0.0)&&(v1.z >= 0.0)&&(v2.z >= 0.0))
		{
			[g_plus addTriangle: triangles[i]];
			done_tri = YES;
		}
		if ((v0.z <= 0.0)&&(v1.z <= 0.0)&&(v2.z <= 0.0))
		{
			[g_minus addTriangle: triangles[i]];
			done_tri = YES;
		}
		if (!done_tri)	// triangle must cross y == 0.0
		{
			GLfloat i01, i12, i20;
			if (v0.z == v1.z)
				i01 = -1.0;
			else
				i01 = v0.z / (v0.z - v1.z);
			if (v1.z == v2.z)
				i12 = -1.0;
			else
				i12 = v1.z / (v1.z - v2.z);
			if (v2.z == v0.z)
				i20 = -1.0;
			else
				i20 = v2.z / (v2.z - v0.z);
			Vector v01 = make_vector( i01 * (v1.x - v0.x) + v0.x, i01 * (v1.y - v0.y) + v0.y, 0.0);
			Vector v12 = make_vector( i12 * (v2.x - v1.x) + v1.x, i12 * (v2.y - v1.y) + v1.y, 0.0);
			Vector v20 = make_vector( i20 * (v0.x - v2.x) + v2.x, i20 * (v0.y - v2.y) + v2.y, 0.0);
		
			// cases where a vertex is on the split..
			if (v0.z == 0.0)
			{
				if (v1.z > 0)
				{
					[g_plus addTriangle:make_triangle(v0, v1, v12)];
					[g_minus addTriangle:make_triangle(v0, v12, v2)];
				}
				else
				{
					[g_minus addTriangle:make_triangle(v0, v1, v12)];
					[g_plus addTriangle:make_triangle(v0, v12, v2)];
				}
			}
			if (v1.z == 0.0)
			{
				if (v2.z > 0)
				{
					[g_plus addTriangle:make_triangle(v1, v2, v20)];
					[g_minus addTriangle:make_triangle(v1, v20, v0)];
				}
				else
				{
					[g_minus addTriangle:make_triangle(v1, v2, v20)];
					[g_plus addTriangle:make_triangle(v1, v20, v0)];
				}
			}
			if (v2.z == 0.0)
			{
				if (v0.z > 0)
				{
					[g_plus addTriangle:make_triangle(v2, v0, v01)];
					[g_minus addTriangle:make_triangle(v2, v01, v1)];
				}
				else
				{
					[g_minus addTriangle:make_triangle(v2, v0, v01)];
					[g_plus addTriangle:make_triangle(v2, v01, v1)];
				}
			}
			
			if ((v0.z > 0.0)&&(v1.z > 0.0)&&(v2.z < 0.0))
			{
				[g_plus addTriangle:make_triangle( v0, v12, v20)];
				[g_plus addTriangle:make_triangle( v0, v1, v12)];
				[g_minus addTriangle:make_triangle( v20, v12, v2)];
			}
			
			if ((v0.z > 0.0)&&(v1.z < 0.0)&&(v2.z > 0.0))
			{
				[g_plus addTriangle:make_triangle( v2, v01, v12)];
				[g_plus addTriangle:make_triangle( v2, v0, v01)];
				[g_minus addTriangle:make_triangle( v12, v01, v1)];
			}
			
			if ((v0.z > 0.0)&&(v1.z < 0.0)&&(v2.z < 0.0))
			{
				[g_plus addTriangle:make_triangle( v20, v0, v01)];
				[g_minus addTriangle:make_triangle( v2, v20, v1)];
				[g_minus addTriangle:make_triangle( v20, v01, v1)];
			}
			
			if ((v0.z < 0.0)&&(v1.z > 0.0)&&(v2.z > 0.0))
			{
				[g_minus addTriangle:make_triangle( v01, v20, v0)];
				[g_plus addTriangle:make_triangle( v1, v20, v01)];
				[g_plus addTriangle:make_triangle( v1, v2, v20)];
			}
			
			if ((v0.z < 0.0)&&(v1.z > 0.0)&&(v2.z < 0.0))
			{
				[g_plus addTriangle:make_triangle( v01, v1, v12)];
				[g_minus addTriangle:make_triangle( v0, v01, v2)];
				[g_minus addTriangle:make_triangle( v01, v12, v2)];
			}
			
			if ((v0.z < 0.0)&&(v1.z < 0.0)&&(v2.z > 0.0))
			{
				[g_plus addTriangle:make_triangle( v12, v2, v20)];
				[g_minus addTriangle:make_triangle( v1, v12, v0)];
				[g_minus addTriangle:make_triangle( v12, v20, v0)];
			}			

		}
	}
	[g_plus translate: make_vector( 0.0, 0.0, -z)];
	[g_minus translate: make_vector( 0.0, 0.0, z)];
}

@end
