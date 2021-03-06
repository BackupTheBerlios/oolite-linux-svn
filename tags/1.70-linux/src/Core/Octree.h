/*

Octtree.h

Octtree class for collision detection.

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

#import "OOCocoa.h"
#import "OOOpenGL.h"
#import "OOMaths.h"

#define	OCTREE_MAX_DEPTH	5
#define	OCTREE_MIN_RADIUS	1.0


struct octree_struct
{
	GLfloat				radius;
	int*				octree;	
	unsigned char*		octree_collision;
};

typedef struct octree_struct Octree_details;

@interface Octree : NSObject
{
	GLfloat		radius;
	int			leafs;
	int*		octree;
	BOOL		hasCollision;
	
	unsigned char*		octree_collision;
}

- (GLfloat)	radius;
- (int)		leafs;
- (int*)	octree;
- (BOOL)	hasCollision;
- (void)	setHasCollision:(BOOL) value;
- (unsigned char*)	octree_collision;

- (Octree_details)	octreeDetails;

- (id) initWithRepresentationOfOctree:(GLfloat) octRadius :(NSObject*) octreeArray :(int) leafsize;
- (id) initWithDictionary:(NSDictionary*) dict;

- (Octree*) octreeScaledBy:(GLfloat) factor;

int copyRepresentationIntoOctree(NSObject* theRep, int* theBuffer, int atLocation, int nextFreeLocation);

Vector offsetForOctant(int oct, GLfloat r);

- (void) drawOctree;
- (void) drawOctreeFromLocation:(int) loc :(GLfloat) scale :(Vector) offset;

- (void) drawOctreeCollisions;
- (void) drawOctreeCollisionFromLocation:(int) loc :(GLfloat) scale :(Vector) offset;

BOOL	isHitByLine(int* octbuffer, unsigned char* collbuffer, int level, GLfloat rad, Vector v0, Vector v1, Vector off, int face_hit);
- (GLfloat) isHitByLine: (Vector) v0: (Vector) v1;

BOOL	isHitByOctree(	Octree_details axialDetails,
						Octree_details otherDetails, Vector delta, Triangle other_ijk);
- (BOOL) isHitByOctree:(Octree*) other withOrigin: (Vector) v0 andIJK: (Triangle) ijk;
- (BOOL) isHitByOctree:(Octree*) other withOrigin: (Vector) v0 andIJK: (Triangle) ijk andScales: (GLfloat) s1: (GLfloat) s2;

- (NSDictionary*) dict;

- (GLfloat) volume;
GLfloat volumeOfOctree(Octree_details octree_details);

Vector randomFullNodeFrom( Octree_details details, Vector offset);

@end
