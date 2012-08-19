/*
OOJSVisualEffect.m

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

#import "OOVisualEffectEntity.h"
#import "OOJSVisualEffect.h"
#import "OOJSEntity.h"
#import "OOJavaScriptEngine.h"
#import "OOMesh.h"
#import "OOCollectionExtractors.h"
#import "ResourceManager.h"

static JSObject		*sVisualEffectPrototype;

static BOOL JSVisualEffectGetVisualEffectEntity(JSContext *context, JSObject *stationObj, OOVisualEffectEntity **outEntity);


static JSBool VisualEffectGetProperty(JSContext *context, JSObject *this, jsid propID, jsval *value);
static JSBool VisualEffectSetProperty(JSContext *context, JSObject *this, jsid propID, JSBool strict, jsval *value);

static JSBool VisualEffectRemove(JSContext *context, uintN argc, jsval *vp);

static JSBool VisualEffectGetShaders(JSContext *context, uintN argc, jsval *vp);
static JSBool VisualEffectSetShaders(JSContext *context, uintN argc, jsval *vp);
static JSBool VisualEffectGetMaterials(JSContext *context, uintN argc, jsval *vp);
static JSBool VisualEffectSetMaterials(JSContext *context, uintN argc, jsval *vp);


static JSBool VisualEffectSetMaterialsInternal(JSContext *context, uintN argc, jsval *vp, OOVisualEffectEntity *thisEnt, BOOL fromShaders);


static JSClass sVisualEffectClass =
{
	"VisualEffect",
	JSCLASS_HAS_PRIVATE,
	
	JS_PropertyStub,		// addProperty
	JS_PropertyStub,		// delProperty
	VisualEffectGetProperty,		// getProperty
	VisualEffectSetProperty,		// setProperty
	JS_EnumerateStub,		// enumerate
	JS_ResolveStub,			// resolve
	JS_ConvertStub,			// convert
	OOJSObjectWrapperFinalize,// finalize
	JSCLASS_NO_OPTIONAL_MEMBERS
};


enum
{
	// Property IDs
	kVisualEffect_isBreakPattern
};


static JSPropertySpec sVisualEffectProperties[] =
{
	// JS name						ID									flags
	{ "isBreakPatterns",	kVisualEffect_isBreakPattern,	OOJS_PROP_READWRITE_CB },
	{ 0 }
};


static JSFunctionSpec sVisualEffectMethods[] =
{
	// JS name					Function						min args
	{ "remove",         VisualEffectRemove,    0 },
	{ "getMaterials",   VisualEffectGetMaterials,    0 },
	{ "getShaders",     VisualEffectGetShaders,    0 },
	{ "setMaterials",     VisualEffectSetMaterials,    1 },
	{ "setShaders",     VisualEffectSetShaders,    2 },

	{ 0 }
};


void InitOOJSVisualEffect(JSContext *context, JSObject *global)
{
	sVisualEffectPrototype = JS_InitClass(context, global, JSEntityPrototype(), &sVisualEffectClass, OOJSUnconstructableConstruct, 0, sVisualEffectProperties, sVisualEffectMethods, NULL, NULL);
	OOJSRegisterObjectConverter(&sVisualEffectClass, OOJSBasicPrivateObjectConverter);
	OOJSRegisterSubclass(&sVisualEffectClass, JSEntityClass());
}


static BOOL JSVisualEffectGetVisualEffectEntity(JSContext *context, JSObject *visualEffectObj, OOVisualEffectEntity **outEntity)
{
	OOJS_PROFILE_ENTER
	
	BOOL						result;
	Entity						*entity = nil;
	
	if (outEntity == NULL)  return NO;
	*outEntity = nil;
	
	result = OOJSEntityGetEntity(context, visualEffectObj, &entity);
	if (!result)  return NO;
	
	if (![entity isKindOfClass:[OOVisualEffectEntity class]])  return NO;
	
	*outEntity = (OOVisualEffectEntity *)entity;
	return YES;
	
	OOJS_PROFILE_EXIT
}


@implementation OOVisualEffectEntity (OOJavaScriptExtensions)

- (void)getJSClass:(JSClass **)outClass andPrototype:(JSObject **)outPrototype
{
	*outClass = &sVisualEffectClass;
	*outPrototype = sVisualEffectPrototype;
}


- (NSString *) oo_jsClassName
{
	return @"VisualEffect";
}

@end


static JSBool VisualEffectGetProperty(JSContext *context, JSObject *this, jsid propID, jsval *value)
{
	if (!JSID_IS_INT(propID))  return YES;
	
	OOJS_NATIVE_ENTER(context)
	
	OOVisualEffectEntity				*entity = nil;
	
	if (!JSVisualEffectGetVisualEffectEntity(context, this, &entity))  return NO;
	if (entity == nil)  { *value = JSVAL_VOID; return YES; }
	
	switch (JSID_TO_INT(propID))
	{
		case kVisualEffect_isBreakPattern:
			*value = OOJSValueFromBOOL([entity isBreakPattern]);

			return YES;
		default:
			OOJSReportBadPropertySelector(context, this, propID, sVisualEffectProperties);
			return NO;
	}
	
	OOJS_NATIVE_EXIT
}


static JSBool VisualEffectSetProperty(JSContext *context, JSObject *this, jsid propID, JSBool strict, jsval *value)
{
	if (!JSID_IS_INT(propID))  return YES;
	
	OOJS_NATIVE_ENTER(context)
	
	OOVisualEffectEntity				*entity = nil;
	JSBool						bValue;
//	int32						iValue;
	
	if (!JSVisualEffectGetVisualEffectEntity(context, this, &entity)) return NO;
	if (entity == nil)  return YES;
	
	switch (JSID_TO_INT(propID))
	{
		case kVisualEffect_isBreakPattern:
			if (JS_ValueToBoolean(context, *value, &bValue))
			{
				[entity setIsBreakPattern:bValue];
				return YES;
			}
			break;

		default:
			OOJSReportBadPropertySelector(context, this, propID, sVisualEffectProperties);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, this, propID, sVisualEffectProperties, *value);
	return NO;
	
	OOJS_NATIVE_EXIT
}


// *** Methods ***

#define GET_THIS_EFFECT(THISENT) do { \
	if (EXPECT_NOT(!JSVisualEffectGetVisualEffectEntity(context, OOJS_THIS, &THISENT)))  return NO; /* Exception */ \
	if (OOIsStaleEntity(THISENT))  OOJS_RETURN_VOID; \
} while (0)


static JSBool VisualEffectRemove(JSContext *context, uintN argc, jsval *vp)
{
	OOJS_NATIVE_ENTER(context)
	
	OOVisualEffectEntity				*thisEnt = nil;
	GET_THIS_EFFECT(thisEnt);
	
	[UNIVERSE removeEntity:(Entity*)thisEnt];

	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}



//getMaterials()
static JSBool VisualEffectGetMaterials(JSContext *context, uintN argc, jsval *vp)
{
	OOJS_PROFILE_ENTER

	NSObject			*result = nil;
	OOVisualEffectEntity				*thisEnt = nil;

	GET_THIS_EFFECT(thisEnt);
	
	result = [[thisEnt mesh] materials];
	if (result == nil)  result = [NSDictionary dictionary];
	OOJS_RETURN_OBJECT(result);
	
	OOJS_PROFILE_EXIT
}

//getShaders()
static JSBool VisualEffectGetShaders(JSContext *context, uintN argc, jsval *vp)
{
	OOJS_PROFILE_ENTER
	
	NSObject			*result = nil;
	OOVisualEffectEntity				*thisEnt = nil;

	GET_THIS_EFFECT(thisEnt);
	
	result = [[thisEnt mesh] shaders];
	if (result == nil)  result = [NSDictionary dictionary];
	OOJS_RETURN_OBJECT(result);
	
	OOJS_PROFILE_EXIT
}


// setMaterials(params: dict, [shaders: dict])  // sets materials dictionary. Optional parameter sets the shaders dictionary too.
static JSBool VisualEffectSetMaterials(JSContext *context, uintN argc, jsval *vp)
{
	OOJS_NATIVE_ENTER(context)
	
	OOVisualEffectEntity				*thisEnt = nil;
	
	if (argc < 1)
	{
		OOJSReportBadArguments(context, @"VisualEffect", @"setMaterials", 0, OOJS_ARGV, nil, @"parameter object");
		return NO;
	}
	
	GET_THIS_EFFECT(thisEnt);
	
	return VisualEffectSetMaterialsInternal(context, argc, vp, thisEnt, NO);
	
	OOJS_NATIVE_EXIT
}


// setShaders(params: dict) 
static JSBool VisualEffectSetShaders(JSContext *context, uintN argc, jsval *vp)
{
	OOJS_NATIVE_ENTER(context)
	
	OOVisualEffectEntity				*thisEnt = nil;
	
	GET_THIS_EFFECT(thisEnt);
	
	if (argc < 1)
	{
		OOJSReportBadArguments(context, @"VisualEffect", @"setShaders", 0, OOJS_ARGV, nil, @"parameter object");
		return NO;
	}
	
	if (JSVAL_IS_NULL(OOJS_ARGV[0]) || (!JSVAL_IS_NULL(OOJS_ARGV[0]) && !JSVAL_IS_OBJECT(OOJS_ARGV[0])))
	{
		// EMMSTRAN: JS_ValueToObject() and normal error handling here.
		OOJSReportWarning(context, @"VisualEffect.%@: expected %@ instead of '%@'.", @"setShaders", @"object", [NSString stringWithJavaScriptValue:OOJS_ARGV[0] inContext:context]);
		OOJS_RETURN_BOOL(NO);
	}
	
	OOJS_ARGV[1] = OOJS_ARGV[0];
	return VisualEffectSetMaterialsInternal(context, argc, vp, thisEnt, YES);
	
	OOJS_NATIVE_EXIT
}





/* **  helper functions ** */

static JSBool VisualEffectSetMaterialsInternal(JSContext *context, uintN argc, jsval *vp, OOVisualEffectEntity *thisEnt, BOOL fromShaders)
{
	OOJS_PROFILE_ENTER
	
	JSObject				*params = NULL;
	NSDictionary			*materials;
	NSDictionary			*shaders;
	BOOL					withShaders = NO;
	BOOL					success = NO;
	
	GET_THIS_EFFECT(thisEnt);
	
	if (JSVAL_IS_NULL(OOJS_ARGV[0]) || (!JSVAL_IS_NULL(OOJS_ARGV[0]) && !JSVAL_IS_OBJECT(OOJS_ARGV[0])))
	{
		OOJSReportWarning(context, @"VisualEffect.%@: expected %@ instead of '%@'.", @"setMaterials", @"object", [NSString stringWithJavaScriptValue:OOJS_ARGV[0] inContext:context]);
		OOJS_RETURN_BOOL(NO);
	}
	
	if (argc > 1)
	{
		withShaders = YES;
		if (JSVAL_IS_NULL(OOJS_ARGV[1]) || (!JSVAL_IS_NULL(OOJS_ARGV[1]) && !JSVAL_IS_OBJECT(OOJS_ARGV[1])))
		{
			OOJSReportWarning(context, @"VisualEffect.%@: expected %@ instead of '%@'.",  @"setMaterials", @"object as second parameter", [NSString stringWithJavaScriptValue:OOJS_ARGV[1] inContext:context]);
			withShaders = NO;
		}
	}
	
	if (fromShaders)
	{
		materials = [[thisEnt mesh] materials];
		params = JSVAL_TO_OBJECT(OOJS_ARGV[0]);
		shaders = OOJSNativeObjectFromJSObject(context, params);
	}
	else
	{
		params = JSVAL_TO_OBJECT(OOJS_ARGV[0]);
		materials = OOJSNativeObjectFromJSObject(context, params);
		if (withShaders)
		{
			params = JSVAL_TO_OBJECT(OOJS_ARGV[1]);
			shaders = OOJSNativeObjectFromJSObject(context, params);
		}
		else
		{
			shaders = [[thisEnt mesh] shaders];
		}
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	NSDictionary 			*effectDict = [thisEnt effectInfoDictionary];
	
	// First we test to see if we can create the mesh.
	OOMesh *mesh = [OOMesh meshWithName:[effectDict oo_stringForKey:@"model"]
							   cacheKey:nil
					 materialDictionary:materials
					  shadersDictionary:shaders
								 smooth:[effectDict oo_boolForKey:@"smooth" defaultValue:NO]
						   shaderMacros:[[ResourceManager materialDefaults] oo_dictionaryForKey:@"ship-prefix-macros"]
					shaderBindingTarget:thisEnt];
	
	if (mesh != nil)
	{
		[thisEnt setMesh:mesh];
		success = YES;
	}
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_BOOL(success);
	
	OOJS_PROFILE_EXIT
}
