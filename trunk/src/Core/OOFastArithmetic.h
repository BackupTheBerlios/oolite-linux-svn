/*

OOFastArithmetic.h

Mathematical framework for Oolite.

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


#ifndef INCLUDED_OOMATHS_h
	#error Do not include OOFastArithmetic.h directly; include OOMaths.h.
#else


#ifdef WIN32
	#define FASTINVSQRT_ENABLED	0	/* Doesn't work on Windows (why?) */
#else
	#define FASTINVSQRT_ENABLED	0	/* Disabled due to precision problems. */
#endif


/* (test > 0) ? a : b. Extra fast on PowerPC. */
OOINLINE double OOSelect_d(double test, double a, double b) INLINE_CONST_FUNC;
OOINLINE float OOSelect_f(float test, float a, float b) INLINE_CONST_FUNC;

/* Floating point reciprocal estimate, approximation of 1.0f / x. Precise within 1/256th of exact value. */
OOINLINE float OOReciprocalEstimate(float value) INLINE_CONST_FUNC;

/* Inverse square root and approximation of same. */
OOINLINE float OOInvSqrtf(float x) INLINE_CONST_FUNC;
OOINLINE float OOFastInvSqrtf(float x) INLINE_CONST_FUNC;

/* Round integer up to nearest power of 2. */
OOINLINE uint32_t OORoundUpToPowerOf2(uint32_t x) INLINE_CONST_FUNC;

OOINLINE float OOMin_f(float a, float b) INLINE_CONST_FUNC;
OOINLINE double OOMin_d(double a, double b) INLINE_CONST_FUNC;
OOINLINE float OOMax_f(float a, float b) INLINE_CONST_FUNC;
OOINLINE double OOMax_d(double a, double b) INLINE_CONST_FUNC;

/* Clamp to range. */
OOINLINE float OOClamp_0_1_f(float value) INLINE_CONST_FUNC;
OOINLINE double OOClamp_0_1_d(double value) INLINE_CONST_FUNC;
OOINLINE float OOClamp_0_max_f(float value, float max) INLINE_CONST_FUNC;
OOINLINE double OOClamp_0_max_d(double value, double max) INLINE_CONST_FUNC;

/* Linear interpolation. */
OOINLINE float OOLerp(float v0, float v1, float fraction) INLINE_CONST_FUNC;


OOINLINE double OOSelect_d(double test, double a, double b)
{
	return (test > 0) ? a : b;
}


OOINLINE float OOSelect_f(float test, float a, float b)
{
	return (test > 0) ? a : b;
}


OOINLINE float OOReciprocalEstimate(float value)
{
	return 1.0f / value;
}


OOINLINE float OOInvSqrtf(float x)
{
	return 1.0f/sqrtf(x);
}


OOINLINE float OOFastInvSqrtf(float x)
{
/*	This appears to have been responsible for a lack of laser accuracy, as
	well as not working at all under Windows. Disabled for now.
*/
#if FASTINVSQRT_ENABLED
	float xhalf = 0.5f * x;
	int i = *(int*)&x;
	i = 0x5f375a86 - (i>>1);
	x = *(float*)&i;
	x = x * (1.5f - xhalf * x * x);
	return x;
#else
	return OOReciprocalEstimate(sqrt(x));
#endif
}


#ifdef __GNUC__
	OOINLINE uint32_t OORoundUpToPowerOf2(uint32_t value)
	{
		return 0x80000000 >> (__builtin_clz(value - 1) - 1);
	}
#else
	OOINLINE uint32_t OORoundUpToPowerOf2(uint32_t value)
	{
		value -= 1;
		value |= (value >> 1);
		value |= (value >> 2);
		value |= (value >> 4);
		value |= (value >> 8);
		value |= (value >> 16);
		return value + 1;
	}
#endif


OOINLINE float OOMin_f(float a, float b)
{
	return fminf(a, b);
}

OOINLINE double OOMin_d(double a, double b)
{
	return fmin(a, b);
}

OOINLINE float OOMax_f(float a, float b)
{
	return fmaxf(a, b);
}

OOINLINE double OOMax_d(double a, double b)
{
	return fmax(a, b);
}

OOINLINE float OOClamp_0_1_f(float value)
{
	return fmaxf(0.0f, fminf(value, 1.0f));
}

OOINLINE double OOClamp_0_1_d(double value)
{
	return fmax(0.0f, fmin(value, 1.0f));
}

OOINLINE float OOClamp_0_max_f(float value, float max)
{
	return fmaxf(0.0f, fminf(value, max));
}

OOINLINE double OOClamp_0_max_d(double value, double max)
{
	return fmax(0.0, fmin(value, max));
}


OOINLINE float OOLerp(float v0, float v1, float fraction)
{
	// Linear interpolation - equivalent to v0 * (1.0f - fraction) + v1 * fraction.
	return v0 + fraction * (v1 - v0);
}


#endif	/* INCLUDED_OOMATHS_h */
