/*
 *  FPMPNG.c
 *  planettool
 *
 *  Created by Jens Ayton on 2009-09-30.
 *  Copyright 2009 Jens Ayton. All rights reserved.
 *
 */

#include "FPMPNG.h"
#include <assert.h>


#if FPM_EXTRA_VALIDATION
/*	FPM_INTERNAL_ASSERT()
	Used only to assert preconditions of internal, static functions
	(generally, pm != NULL). Plain assert() is used to check public
	functions where relevant.
*/
#define FPM_INTERNAL_ASSERT(x) assert(x)
#else
#define FPM_INTERNAL_ASSERT(x) do {} while (0)
#endif


static void PNGReadFile(png_structp png, png_bytep bytes, png_size_t size);
static void PNGWriteFile(png_structp png, png_bytep bytes, png_size_t size);
static void PNGError(png_structp png, png_const_charp message);
static void PNGWarning(png_structp png, png_const_charp message);
FloatPixMapRef ConvertPNGData(void *data, size_t width, size_t height, size_t rowBytes, uint8_t depth, uint8_t colorType);
static FloatPixMapRef ConvertPNGDataRGBA8(FloatPixMapRef pm, uint8_t *data, size_t width, size_t height, size_t rowBytes);
static FloatPixMapRef ConvertPNGDataRGBA16(FloatPixMapRef pm, uint8_t *data, size_t width, size_t height, size_t rowBytes);
static FloatPixMapRef ConvertPNGDataRGB16(FloatPixMapRef pm, uint8_t *data, size_t width, size_t height, size_t rowBytes);
typedef void (*RowTransformer)(void *data, size_t width);
static void TransformRow16(void *data, size_t width);
static void TransformRow8(void *data, size_t width);


FloatPixMapRef FPMCreateWithPNG(const char *path, FPMGammaFactor desiredGamma, FPMPNGErrorHandler errorHandler)
{
	if (path != NULL)
	{
		// Attempt to open file.
		FILE *file = fopen(path, "rb");
		if (file == NULL)
		{
			if (errorHandler != NULL)  errorHandler("file not found.", true);
			return NULL;
		}
		
		png_byte bytes[8];
		if (fread(bytes, 8, 1, file) < 1)
		{
			if (errorHandler != NULL)  errorHandler("could not read file.", true);
			return NULL;
		}
		if (png_sig_cmp(bytes, 0, 8) != 0)
		{
			if (errorHandler != NULL)  errorHandler("not a PNG.", true);
			return NULL;
		}
		
		if (fseek(file, 0, SEEK_SET) != 0)
		{
			if (errorHandler != NULL)  errorHandler("could not read file.", true);
			return NULL;
		}
		
		FloatPixMapRef result = FPMCreateWithPNGCustom(file, PNGReadFile, desiredGamma, errorHandler);
		fclose(file);
		return result;
	}
	else
	{
		return NULL;
	}
}


FloatPixMapRef FPMCreateWithPNGCustom(png_voidp ioPtr, png_rw_ptr readDataFn, FPMGammaFactor desiredGamma, FPMPNGErrorHandler errorHandler)
{
	png_structp			png = NULL;
	png_infop			pngInfo = NULL;
	png_infop			pngEndInfo = NULL;
	FloatPixMapRef		result = NULL;
	png_uint_32			i, width, height, rowBytes;
	int					depth, colorType;
	png_bytepp			rows = NULL;
	void				*data = NULL;
	
	png = png_create_read_struct(PNG_LIBPNG_VER_STRING, errorHandler, PNGError, PNGWarning);
	if (png == NULL)  goto FAIL;
	
	pngInfo = png_create_info_struct(png);
	if (pngInfo == NULL)  goto FAIL;
	
	pngEndInfo = png_create_info_struct(png);
	if (pngEndInfo == NULL)  goto FAIL;
	
	if (setjmp(png_jmpbuf(png)))
	{
		// libpng will jump here on error.
		goto FAIL;
	}
	
	png_set_read_fn(png, ioPtr, readDataFn);
	
	png_read_info(png, pngInfo);
	if (!png_get_IHDR(png, pngInfo, &width, &height, &depth, &colorType, NULL, NULL, NULL))  goto FAIL;
	
#if __LITTLE_ENDIAN__
	if (depth == 16)  png_set_swap(png);
#endif
	if (depth <= 8 && !(colorType & PNG_COLOR_MASK_ALPHA))
	{
		png_set_filler(png, 0xFF, PNG_FILLER_AFTER);
	}
	png_set_gray_to_rgb(png);
	if (depth < 8)
	{
		png_set_packing(png);
		png_set_expand(png);
	}
	
	png_read_update_info(png, pngInfo);
	rowBytes = png_get_rowbytes(png, pngInfo);
	
	rows = malloc(sizeof *rows * height);
	data = malloc(rowBytes * height);
	if (rows == NULL || data == NULL)  goto FAIL;
	
	// Set up row pointers.
	for (i = 0; i < height; i++)
	{
		rows[i] = (png_bytep)data + i * rowBytes;
	}
	
	png_read_image(png, rows);
	png_read_end(png, pngEndInfo);
	
	free(rows);
	
	result = ConvertPNGData(data, width, height, rowBytes, pngInfo->bit_depth, pngInfo->color_type);
	
	if (result != NULL)
	{
		double invGamma = 1.0/kFPMGammaSRGB;
		png_get_gAMA(png, pngInfo, &invGamma);
		FPMApplyGamma(result, 1.0/invGamma, desiredGamma, pngInfo->bit_depth == 16 ? 65536 : 256);
	}
	
	png_destroy_read_struct(&png, &pngInfo, &pngEndInfo);
	free(data);
	
	return result;
	
FAIL:
	FPMRelease(&result);
	if (png != NULL)  png_destroy_read_struct(&png, &pngInfo, &pngEndInfo);
	free(rows);
	free(data);
	
	return NULL;
}


bool FPMWritePNG(FloatPixMapRef pm, const char *path, FPMWritePNGFlags options, FPMGammaFactor sourceGamma, FPMGammaFactor fileGamma, FPMPNGErrorHandler errorHandler)
{
	if (pm != NULL && path != NULL)
	{
		// Attempt to open file.
		FILE *file = fopen(path, "wb");
		if (file == NULL)
		{
			if (errorHandler != NULL)  errorHandler("file not found.", true);
			return NULL;
		}
		
		bool result = FPMWritePNGCustom(pm, file, PNGWriteFile, NULL, options, sourceGamma, fileGamma, errorHandler);
		fclose(file);
		return result;
	}
	else
	{
		return false;
	}
}


bool FPMWritePNGCustom(FloatPixMapRef srcPM, png_voidp ioPtr, png_rw_ptr writeDataFn, png_flush_ptr flushDataFn, FPMWritePNGFlags options, FPMGammaFactor sourceGamma, FPMGammaFactor fileGamma, FPMPNGErrorHandler errorHandler)
{
	if (srcPM != NULL)
	{
		bool				success = false;
		png_structp			png = NULL;
		png_infop			pngInfo = NULL;
		FloatPixMapRef		pm = NULL;
		
		// Prepare data.
		FPMDimension width = FPMGetWidth(srcPM);
		FPMDimension height = FPMGetHeight(srcPM);
		if (width > UINT32_MAX || height > UINT32_MAX)
		{
			if (errorHandler != NULL)  errorHandler("image is too large for PNG format.", true);
			return false;
		}
		
		pm = FPMCopy(srcPM);
		if (pm == NULL)  return false;
		
		FPMApplyGamma(pm, sourceGamma, fileGamma, 65536);
		unsigned steps = (options & kFPMWritePNG16BPC) ? 0x10000 : 0x100;
		FPMQuantize(pm, 0.0f, 1.0f, 0.0f, steps - 1, steps, (options & kFPMQuantizeDither & kFPMQuantizeJitter) | kFMPQuantizeClip | kFMPQuantizeAlpha);
		
		png = png_create_write_struct(PNG_LIBPNG_VER_STRING, errorHandler, PNGError, PNGWarning);
		if (png == NULL)  goto FAIL;
		
		pngInfo = png_create_info_struct(png);
		if (pngInfo == NULL)  goto FAIL;
		
		if (setjmp(png_jmpbuf(png)))
		{
			// libpng will jump here on error.
			goto FAIL;
		}
		
		png_set_write_fn(png, ioPtr, writeDataFn, flushDataFn);
		
		png_set_IHDR(png, pngInfo, width, height, (options & kFPMWritePNG16BPC) ? 16 : 8,PNG_COLOR_TYPE_RGB_ALPHA, PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
		
		if (fileGamma == kFPMGammaSRGB)
		{
			png_set_sRGB_gAMA_and_cHRM(png, pngInfo, PNG_sRGB_INTENT_PERCEPTUAL);
		}
		else
		{
			png_set_gAMA(png, pngInfo, fileGamma);
		}
		
		/*	Select function used to transform a row of data to PNG-friendly
			format. NOTE: these work in place,and overwrite the data in pm,
			which is OK since we copied it.
		*/
		RowTransformer transformer = NULL;
		if (options & kFPMWritePNG16BPC)
		{
			transformer = TransformRow16;
		}
		else
		{
			transformer = TransformRow8;
		}
		
		png_write_info(png, pngInfo);
		
		size_t i;
		size_t rowOffset = FPMGetRowByteCount(pm);
		png_bytep row = (png_bytep)FPMGetBufferPointer(pm);
		for (i = 0; i < height; i++)
		{
			transformer(row, width);
			png_write_row(png, row);
			row += rowOffset;
		}
		png_write_end(png, pngInfo);
		success = true;
		
	FAIL:
		if (png != NULL)  png_destroy_write_struct(&png, &pngInfo);
		FPMRelease(&pm);
		
		return success;
	}
	else
	{
		return false;
	}
}


static void PNGReadFile(png_structp png, png_bytep bytes, png_size_t size)
{
	FILE *file = png_get_io_ptr(png);
	if (fread(bytes, size, 1, file) < 1)
	{
		png_error(png, "read failed.");
	}
}


static void PNGWriteFile(png_structp png, png_bytep bytes, png_size_t size)
{
	FILE *file = png_get_io_ptr(png);
	if (fwrite(bytes, size, 1, file) < 1)
	{
		png_error(png, "write failed.");
	}
}


static void PNGError(png_structp png, png_const_charp message)
{
	FPMPNGErrorHandler *errCB = png->error_ptr;
	if (errCB != NULL)  errCB(message, true);
}


static void PNGWarning(png_structp png, png_const_charp message)
{
	FPMPNGErrorHandler *errCB = png->error_ptr;
	if (errCB != NULL)  errCB(message, false);
}


FloatPixMapRef ConvertPNGData(void *data, size_t width, size_t height, size_t rowBytes, uint8_t depth, uint8_t colorType)
{
	FloatPixMapRef result = FPMCreateC(width, height);
	if (result == NULL)  return NULL;
	
	// Libpng transformations should have given us one of these formats.
	if (depth == 8 && (colorType == PNG_COLOR_TYPE_RGB_ALPHA || colorType == PNG_COLOR_TYPE_RGB))
	{
		return ConvertPNGDataRGBA8(result, data, width, height, rowBytes);
	}
	if (depth == 16 && colorType == PNG_COLOR_TYPE_RGB_ALPHA)
	{
		return ConvertPNGDataRGBA16(result, data, width, height, rowBytes);
	}
	if (depth == 16 && colorType == PNG_COLOR_TYPE_RGB)
	{
		return ConvertPNGDataRGB16(result, data, width, height, rowBytes);
	}
	
	fprintf(stderr, "Unexpected PNG depth/colorType combination: %u, 0x%X\n", depth, colorType);
	FPMRelease(&result);
	return NULL;
}


static FloatPixMapRef ConvertPNGDataRGBA8(FloatPixMapRef pm, uint8_t *data, size_t width, size_t height, size_t rowBytes)
{
	uint8_t				*src = NULL;
	float				*dst = NULL;
	size_t				x, y;
	
	for (y = 0; y < height; y++)
	{
		src = data + rowBytes * y;
		dst = (float *)FPMGetPixelPointerC(pm, 0, y);
		FPM_INTERNAL_ASSERT(src != NULL && dst != NULL);
		
		for (x = 0; x < width * 4; x++)
		{
			*dst++ = (float)*src++ * 1.0f/255.0f;
		}
	}
	
	return pm;
}


static FloatPixMapRef ConvertPNGDataRGBA16(FloatPixMapRef pm, uint8_t *data, size_t width, size_t height, size_t rowBytes)
{
	uint16_t			*src = NULL;
	float				*dst = NULL;
	size_t				x, y;
	
	for (y = 0; y < height; y++)
	{
		src = (uint16_t *)(data + rowBytes * y);
		dst = (float *)FPMGetPixelPointerC(pm, 0, y);
		FPM_INTERNAL_ASSERT(src != NULL && dst != NULL);
		
		for (x = 0; x < width * 4; x++)
		{
			*dst++ = (float)*src++ * 1.0f/65535.0f;
		}
	}
	
	return pm;
}


static FloatPixMapRef ConvertPNGDataRGB16(FloatPixMapRef pm, uint8_t *data, size_t width, size_t height, size_t rowBytes)
{
	uint16_t			*src = NULL;
	float				*dst = NULL;
	size_t				x, y;
	
	for (y = 0; y < height; y++)
	{
		src = (uint16_t *)(data + rowBytes * y);
		dst = (float *)FPMGetPixelPointerC(pm, 0, y);
		FPM_INTERNAL_ASSERT(src != NULL && dst != NULL);
		
		for (x = 0; x < width * 3; x++)
		{
			*dst++ = (float)*src++ * 1.0f/65535.0f;
		}
	}
	
	return pm;
}


static void TransformRow16(void *data, size_t width)
{
	assert(data != NULL);
	
	float *src = (float *)data;
#if __LITTLE_ENDIAN__
	uint8_t *dst = (uint8_t *)data;
#else
	uint16_t *dst = (uint16_t *)data;
#endif
	
	size_t count = width * 4;
	while (count--)
	{
		// value should already be scaled to appropriate range.
		uint16_t value = *src++;
		
#if __LITTLE_ENDIAN__
		*dst++ = value >> 8;
		*dst++ = value & 0xFF;
#else
		*dst++ = value;
#endif
	}
}


static void TransformRow8(void *data, size_t width)
{
	assert(data != NULL);
	
	float *src = (float *)data;
	uint8_t *dst = (uint8_t *)data;
	
	size_t count = width * 4;
	while (count--)
	{
		// value should already be scaled to appropriate range.
		uint8_t value = *src++;
		*dst++ = value;
	}
}