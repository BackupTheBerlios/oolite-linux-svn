/*

OOVector.m

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

#import "OOMaths.h"
#import "OOLogging.h"


const Vector			kZeroVector = { 0.0f, 0.0f, 0.0f };
const Vector			kBasisXVector = { 1.0f, 0.0f, 0.0f };
const Vector			kBasisYVector = { 0.0f, 1.0f, 0.0f };
const Vector			kBasisZVector = { 0.0f, 0.0f, 1.0f };
const BoundingBox		kZeroBoundingBox = {{ 0.0f, 0.0f, 0.0f }, { 0.0f, 0.0f, 0.0f }};


NSString *VectorDescription(Vector vector)
{
	return [NSString stringWithFormat:@"(%g, %g, %g)", vector.x, vector.y, vector.z];
}


/*	This generates random vectors distrubuted evenly over the surface of the
	unit sphere. It does this the simple way, by generating vectors in the
	half-unit cube and rejecting those outside the half-unit sphere (and the
	zero vector), then normalizing the result. (Half-unit measures are used
	to avoid unnecessary multiplications of randf() values.)
	
	In principle, using three normally-distributed co-ordinates (and again
	normalizing the result) would provide the right result without looping, but
	I don't trust bellf() so I'll go with the simple approach for now.
*/
Vector OORandomUnitVector(void)
{
	Vector				v;
	float				m;
	
	do
	{
		v = make_vector(randf() - 0.5f, randf() - 0.5f, randf() - 0.5f);
		m = magnitude2(v);
	}
	while (m > 0.25f || m == 0.0f);	// We're confining to a sphere of radius 0.5 using the sqared magnitude; 0.5 squared is 0.25.
	
	return vector_normal(v);
}


Vector OOVectorRandomSpatial(GLfloat maxLength)
{
	Vector				v;
	float				m;
	
	do
	{
		v = make_vector(randf() - 0.5f, randf() - 0.5f, randf() - 0.5f);
		m = magnitude2(v);
	}
	while (m > 0.25f);	// We're confining to a sphere of radius 0.5 using the sqared magnitude; 0.5 squared is 0.25.
	
	return vector_multiply_scalar(v, maxLength * 2.0f);	// 2.0 is to compensate for the 0.5-radius sphere.
}


Vector OOVectorRandomRadial(GLfloat maxLength)
{
	return vector_multiply_scalar(OORandomUnitVector(), randf() * maxLength);
}
