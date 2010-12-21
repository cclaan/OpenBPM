/*

File: Texture2D.m
Abstract: Creates OpenGL 2D textures from images or text.

Version: 1.7

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple Inc.
("Apple") in consideration of your agreement to the following terms, and your
use, installation, modification or redistribution of this Apple software
constitutes acceptance of these terms.  If you do not agree with these terms,
please do not use, install, modify or redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and subject
to these terms, Apple grants you a personal, non-exclusive license, under
Apple's copyrights in this original Apple software (the "Apple Software"), to
use, reproduce, modify and redistribute the Apple Software, with or without
modifications, in source and/or binary forms; provided that if you redistribute
the Apple Software in its entirety and without modifications, you must retain
this notice and the following text and disclaimers in all such redistributions
of the Apple Software.
Neither the name, trademarks, service marks or logos of Apple Inc. may be used
to endorse or promote products derived from the Apple Software without specific
prior written permission from Apple.  Except as expressly stated in this notice,
no other rights or licenses, express or implied, are granted by Apple herein,
including but not limited to any patent rights that may be infringed by your
derivative works or by other works in which the Apple Software may be
incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR
DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF
CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF
APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Copyright (C) 2008 Apple Inc. All Rights Reserved.

*/

#import <OpenGLES/ES1/glext.h>

#import "Texture2D.h"


//CONSTANTS:

#define kMaxTextureSize	 1024

//CLASS IMPLEMENTATIONS:

@implementation Texture2D

@synthesize contentSize=_size, pixelFormat=_format, pixelsWide=_width, pixelsHigh=_height, name=_name, maxS=_maxS, maxT=_maxT;


- (id) initBGRAWithPixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height {
	
	
	if((self = [super init])) {
		
		int w = width;
		int h = height;
		
		int dataSize = w * h * 4;
		uint8_t* textureData = (uint8_t*)malloc(dataSize);
		
		if(textureData == NULL)
			return 0;
		
		memset(textureData, 128, dataSize);
		
		GLint saveName;
		//GLuint handle;
		glGenTextures(1, &_name);
		glGetIntegerv(GL_TEXTURE_BINDING_2D, &saveName);
		glBindTexture(GL_TEXTURE_2D, _name);
		glTexParameterf(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_FALSE);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_BGRA_EXT, 
					 GL_UNSIGNED_BYTE, textureData);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glBindTexture(GL_TEXTURE_2D, 0);
		free(textureData);
		
		glBindTexture(GL_TEXTURE_2D, saveName);
		
		/*
		_size = size;
		_width = width;
		_height = height;
		_format = pixelFormat;
		_maxS = size.width / (float)width;
		_maxT = size.height / (float)height;
		*/
		
		_size = CGSizeMake(width, height);
		_width = width;
		_height = height;
		_format = kTexture2DPixelFormat_BGRA_EXT;
		
		_maxS = _size.width / (float)width;
		_maxT = _size.height / (float)height;
		
	}	
	
	return self;

	
}

- (id) initWithPixelFormat:(Texture2DPixelFormat)pixelFormat pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height {
	
	int squareWidth , squareHeight;
	BOOL					sizeToFit = NO;
	uint i;
	
	squareWidth = width;
	
	if((squareWidth != 1) && (squareWidth & (squareWidth - 1))) {
		i = 1;
		while((sizeToFit ? 2 * i : i) < squareWidth)
			i *= 2;
		squareWidth = i;
	}
	
	squareHeight = height;
	
	if((squareHeight != 1) && (squareHeight & (squareHeight - 1))) {
		i = 1;
		while((sizeToFit ? 2 * i : i) < squareHeight)
			i *= 2;
		squareHeight = i;
	}
	
	
	
	while((squareWidth > kMaxTextureSize) || (squareHeight > kMaxTextureSize)) {
		squareHeight /= 2;
		squareWidth /= 2;
		//transform = CGAffineTransformScale(transform, 0.5, 0.5);
		//imageSize.width *= 0.5;
		//imageSize.height *= 0.5;
	}
	
	squareWidth = width;
	squareHeight = height;
	
	NSLog(@"final sizes: %i , %i , content: %i x %i " , squareWidth , squareHeight , width , height );
	
	switch(pixelFormat) {		
		case kTexture2DPixelFormat_RGBA8888:
			pixel_data = malloc(squareWidth*squareHeight*4);
			break;
		case kTexture2DPixelFormat_RGB565:
			pixel_data = malloc(squareWidth*squareHeight*2);
			break;
			
		case kTexture2DPixelFormat_A8:
			pixel_data = malloc(squareWidth*squareHeight);
			break;				
		default:
			[NSException raise:NSInternalInconsistencyException format:@"Invalid pixel format"];
	}
	
	return [self initWithData:pixel_data pixelFormat:pixelFormat pixelsWide:squareWidth pixelsHigh:squareHeight contentSize:CGSizeMake(width, height)];
	
}

- (id) initWithData:(const void*)data pixelFormat:(Texture2DPixelFormat)pixelFormat pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height contentSize:(CGSize)size
{
	GLint					saveName;
	if((self = [super init])) {
		glGenTextures(1, &_name);
		glGetIntegerv(GL_TEXTURE_BINDING_2D, &saveName);
		glBindTexture(GL_TEXTURE_2D, _name);
		
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		
		//glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		//glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		
		
		switch(pixelFormat) {
			
			case kTexture2DPixelFormat_RGBA8888:
			{
				//NSLog(@"8888");
				glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
				break;
			}
			case kTexture2DPixelFormat_RGB565:
			{
				glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, data);
				break;
			}
			case kTexture2DPixelFormat_A8:
				//NSLog(@"Gltextimage: %i  %i " , width , height	);
				//glTexImage2D(GL_TEXTURE_2D, 0, GL_ALPHA, width, height, 0, GL_ALPHA, GL_UNSIGNED_BYTE, data);
				glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, width, height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, data);
				break;
			default:
				[NSException raise:NSInternalInconsistencyException format:@""];
			
		}
		glBindTexture(GL_TEXTURE_2D, saveName);
	
		_size = size;
		_width = width;
		_height = height;
		_format = pixelFormat;
		_maxS = size.width / (float)width;
		_maxT = size.height / (float)height;
	}					
	return self;
}

- (void) dealloc
{
	if(_name)
	 glDeleteTextures(1, &_name);
	
	[super dealloc];
}

- (NSString*) description
{
	return [NSString stringWithFormat:@"<%@ = %08X | Name = %i | Dimensions = %ix%i | Coordinates = (%.2f, %.2f)>", [self class], self, _name, _width, _height, _maxS, _maxT];
}

@end

@implementation Texture2D (Image)
	
- (id) initWithImage:(UIImage *)uiImage
{
	NSUInteger				width,
							height,
							i;
	CGContextRef			context = nil;
	void*					data = nil;;
	CGColorSpaceRef			colorSpace;
	void*					tempData;
	unsigned int*			inPixel32;
	unsigned short*			outPixel16;
	BOOL					hasAlpha;
	CGImageAlphaInfo		info;
	CGAffineTransform		transform;
	CGSize					imageSize;
	Texture2DPixelFormat    pixelFormat;
	CGImageRef				image;
	UIImageOrientation		orientation;
	BOOL					sizeToFit = NO;
	
	
	image = [uiImage CGImage];
	orientation = [uiImage imageOrientation]; 
	
	if(image == NULL) {
		[self release];
		NSLog(@"Image is Null");
		return nil;
	}
	

	info = CGImageGetAlphaInfo(image);
	hasAlpha = ((info == kCGImageAlphaPremultipliedLast) || (info == kCGImageAlphaPremultipliedFirst) || (info == kCGImageAlphaLast) || (info == kCGImageAlphaFirst) ? YES : NO);
	if(CGImageGetColorSpace(image)) {
		if(hasAlpha)
			pixelFormat = kTexture2DPixelFormat_RGBA8888;
		else
			pixelFormat = kTexture2DPixelFormat_RGB565;
	} else  //NOTE: No colorspace means a mask image
		pixelFormat = kTexture2DPixelFormat_A8;
	
	
	imageSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
	transform = CGAffineTransformIdentity;

	width = imageSize.width;
	
	if((width != 1) && (width & (width - 1))) {
		i = 1;
		while((sizeToFit ? 2 * i : i) < width)
			i *= 2;
		width = i;
	}
	height = imageSize.height;
	if((height != 1) && (height & (height - 1))) {
		i = 1;
		while((sizeToFit ? 2 * i : i) < height)
			i *= 2;
		height = i;
	}
	while((width > kMaxTextureSize) || (height > kMaxTextureSize)) {
		width /= 2;
		height /= 2;
		transform = CGAffineTransformScale(transform, 0.5, 0.5);
		imageSize.width *= 0.5;
		imageSize.height *= 0.5;
	}
	
	switch(pixelFormat) {		
		case kTexture2DPixelFormat_RGBA8888:
			colorSpace = CGColorSpaceCreateDeviceRGB();
			data = malloc(height * width * 4);
			context = CGBitmapContextCreate(data, width, height, 8, 4 * width, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
			CGColorSpaceRelease(colorSpace);
			break;
		case kTexture2DPixelFormat_RGB565:
			colorSpace = CGColorSpaceCreateDeviceRGB();
			data = malloc(height * width * 4);
			context = CGBitmapContextCreate(data, width, height, 8, 4 * width, colorSpace, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big);
			CGColorSpaceRelease(colorSpace);
			break;
			
		case kTexture2DPixelFormat_A8:
			data = malloc(height * width);
			context = CGBitmapContextCreate(data, width, height, 8, width, NULL, kCGImageAlphaOnly);
			break;				
		default:
			[NSException raise:NSInternalInconsistencyException format:@"Invalid pixel format"];
	}
 

	CGContextClearRect(context, CGRectMake(0, 0, width, height));
	CGContextTranslateCTM(context, 0, height - imageSize.height);
	
	if(!CGAffineTransformIsIdentity(transform))
		CGContextConcatCTM(context, transform);
	CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);
	//Convert "RRRRRRRRRGGGGGGGGBBBBBBBBAAAAAAAA" to "RRRRRGGGGGGBBBBB"
	if(pixelFormat == kTexture2DPixelFormat_RGB565) {
		tempData = malloc(height * width * 2);
		inPixel32 = (unsigned int*)data;
		outPixel16 = (unsigned short*)tempData;
		for(i = 0; i < width * height; ++i, ++inPixel32)
			*outPixel16++ = ((((*inPixel32 >> 0) & 0xFF) >> 3) << 11) | ((((*inPixel32 >> 8) & 0xFF) >> 2) << 5) | ((((*inPixel32 >> 16) & 0xFF) >> 3) << 0);
		free(data);
		data = tempData;
		
	}
	self = [self initWithData:data pixelFormat:pixelFormat pixelsWide:width pixelsHigh:height contentSize:imageSize];
	
	CGContextRelease(context);
	free(data);
	
	return self;
}

@end

@implementation Texture2D (Text)

- (id) initWithString:(NSString*)string dimensions:(CGSize)dimensions alignment:(UITextAlignment)alignment fontName:(NSString*)name fontSize:(CGFloat)size
{
	NSUInteger				width,
							height,
							i;
	CGContextRef			context;
	void*					data;
	CGColorSpaceRef			colorSpace;
	UIFont *				font;
	
	font = [UIFont fontWithName:name size:size];
	
	width = dimensions.width;
	if((width != 1) && (width & (width - 1))) {
		i = 1;
		while(i < width)
		i *= 2;
		width = i;
	}
	height = dimensions.height;
	if((height != 1) && (height & (height - 1))) {
		i = 1;
		while(i < height)
		i *= 2;
		height = i;
	}
	
	colorSpace = CGColorSpaceCreateDeviceGray();
	data = calloc(height, width);
	context = CGBitmapContextCreate(data, width, height, 8, width, colorSpace, kCGImageAlphaNone);
	CGColorSpaceRelease(colorSpace);
	
	
	CGContextSetGrayFillColor(context, 1.0, 1.0);
	CGContextTranslateCTM(context, 0.0, height);
	CGContextScaleCTM(context, 1.0, -1.0); //NOTE: NSString draws in UIKit referential i.e. renders upside-down compared to CGBitmapContext referential
	UIGraphicsPushContext(context);
		[string drawInRect:CGRectMake(0, 0, dimensions.width, dimensions.height) withFont:font lineBreakMode:UILineBreakModeWordWrap alignment:alignment];
	UIGraphicsPopContext();
	
	self = [self initWithData:data pixelFormat:kTexture2DPixelFormat_A8 pixelsWide:width pixelsHigh:height contentSize:dimensions];
	
	CGContextRelease(context);
	free(data);
	
	return self;
}

@end

@implementation Texture2D (Drawing)

/*
 WARNING: if you dont see anything being drawn and are pulling your hair out.. i was initializing this object before doing other stuff
 and it never drew anything.. .then i created it afterwards and it worked.
 
 */

- (void) drawAtPoint:(CGPoint)point 
{
	GLfloat		coordinates[] = { 0,	_maxT,
								_maxS,	_maxT,
								0,		0,
								_maxS,	0 };
	GLfloat		width = (GLfloat)_width * _maxS,
				height = (GLfloat)_height * _maxT;
	GLfloat		vertices[] = {	-width / 2 + point.x,	-height / 2 + point.y,	0.0,
								width / 2 + point.x,	-height / 2 + point.y,	0.0,
								-width / 2 + point.x,	height / 2 + point.y,	0.0,
								width / 2 + point.x,	height / 2 + point.y,	0.0 };
	
	
	glBindTexture(GL_TEXTURE_2D, _name);
	glVertexPointer(3, GL_FLOAT, 0, vertices);
	glTexCoordPointer(2, GL_FLOAT, 0, coordinates);
	
	//glPushMatrix();
	//glRotatef(-90, 0, 0, 1);
	//glTranslatef(-width, 0, 0);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	//glPopMatrix();
	
}

- (void) drawAtPoint:(CGPoint)point withScale:(CGFloat)scale
{
	GLfloat		coordinates[] = { 0,	_maxT,
		_maxS,	_maxT,
		0,		0,
		_maxS,	0 };
	GLfloat		width = (GLfloat)_width * _maxS * scale,
	height = (GLfloat)_height * _maxT * scale;
	GLfloat		vertices[] = {	-width / 2 + point.x,	-height / 2 + point.y,	0.0,
		width / 2 + point.x,	-height / 2 + point.y,	0.0,
		-width / 2 + point.x,	height / 2 + point.y,	0.0,
		width / 2 + point.x,	height / 2 + point.y,	0.0 };
	
	
	glBindTexture(GL_TEXTURE_2D, _name);
	glVertexPointer(3, GL_FLOAT, 0, vertices);
	glTexCoordPointer(2, GL_FLOAT, 0, coordinates);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}


- (void) drawAtPoint:(CGPoint)point withScale:(CGFloat)scale andRotation:(GLfloat)angle
{
	GLfloat		coordinates[] = { 0,	_maxT,
		_maxS,	_maxT,
		0,		0,
		_maxS,	0 };
	GLfloat		width = (GLfloat)_width * _maxS * scale,
	height = (GLfloat)_height * _maxT * scale;
	GLfloat		vertices[] = 
	{	-width / 2 ,	-height / 2 ,	0.0,
		width / 2  ,	-height / 2 ,	0.0,
		-width / 2 ,	height / 2  ,	0.0,
		width / 2  ,	height / 2  ,	0.0 };
	
	// rotate:
	float theta = angle * (M_PI/180.);
	int x,y;
	
	x = vertices[0];
	y = vertices[1];
	vertices[0] = cosf(theta) * x - sinf(theta) * y;
	vertices[1] = sinf(theta) * x + cosf(theta) * y;
	
	x = vertices[3];
	y = vertices[4];
	vertices[3] = cosf(theta) * x - sinf(theta) * y;
	vertices[4] = sinf(theta) * x + cosf(theta) * y;
	
	x = vertices[6];
	y = vertices[7];
	vertices[6] = cosf(theta) * x - sinf(theta) * y;
	vertices[7] = sinf(theta) * x + cosf(theta) * y;
	
	x = vertices[9];
	y = vertices[10];
	vertices[9] = cosf(theta) * x - sinf(theta) * y;
	vertices[10] = sinf(theta) * x + cosf(theta) * y;
	
	
	
	
	// translate:
	vertices[0]+=point.x;
	vertices[3]+=point.x;
	vertices[6]+=point.x;
	vertices[9]+=point.x;
	
	vertices[1]+=point.y;
	vertices[4]+=point.y;
	vertices[7]+=point.y;
	vertices[10]+=point.y;
	
	glEnable(GL_BLEND);
	glEnable(GL_TEXTURE_2D);
	glDisableClientState(GL_COLOR_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	
	glBindTexture(GL_TEXTURE_2D, _name);
	glVertexPointer(3, GL_FLOAT, 0, vertices);
	glTexCoordPointer(2, GL_FLOAT, 0, coordinates);
		
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	
}


- (void) drawInRect:(CGRect)rect
{
	GLfloat	 coordinates[] = {  0,		_maxT,
								_maxS,	_maxT,
								0,		0,
								_maxS,	0  };
	// CC Swapped y vertices cuz i its showing upside down?
	GLfloat	vertices[] = {	rect.origin.x,							rect.origin.y + rect.size.height,							0.0,
							rect.origin.x + rect.size.width,		rect.origin.y + rect.size.height,							0.0,
							rect.origin.x,							rect.origin.y ,		0.0,
							rect.origin.x + rect.size.width,		rect.origin.y ,		0.0 };
	
	
	
	
	
	
	
	
	glBindTexture(GL_TEXTURE_2D, _name);
	glVertexPointer(3, GL_FLOAT, 0, vertices);
	glTexCoordPointer(2, GL_FLOAT, 0, coordinates);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}
@end




@implementation Texture2D (Laans)

-(void) updatePixels:(uint8_t*)pixels inRect:(CGRect) rect {
	
	/* WARNING, SIZES MUST BE A MULTIPLE OF FOUR IN CALLS TO GLTEXSUBIMAGE2D 
	 ONLY RAN INTO THIS ON ALPHA TEXTURES SO MAYBE ITS OK FOR RGBA
	 */
	
	glBindTexture(GL_TEXTURE_2D, _name);

	switch(_format) {		
		case kTexture2DPixelFormat_RGBA8888: 
		{
			glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, _size.width, _size.height, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
			break;
		}
		case kTexture2DPixelFormat_BGRA_EXT: 
		{
			glTexSubImage2D(GL_TEXTURE_2D, 0, rect.origin.x, rect.origin.y, rect.size.width, rect.size.height, GL_BGRA_EXT, GL_UNSIGNED_BYTE, pixels);
			break;
		}	
		case kTexture2DPixelFormat_RGB565:
			glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0,  _size.width, _size.height, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, pixels);
			break;
		case kTexture2DPixelFormat_A8:
		{
			glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, ((int)_size.width), ((int)_size.height), GL_LUMINANCE, GL_UNSIGNED_BYTE, pixels);
			if ( glGetError() != GL_NO_ERROR ) {
				NSLog(@"there was an error!");
			}
			
			break;				
		}
		default:
			[NSException raise:NSInternalInconsistencyException format:@"Invalid pixel format"];
	}
	
}


-(void) updatePixels:(uint8_t*)pixels {
	
	/* WARNING, SIZES MUST BE A MULTIPLE OF FOUR IN CALLS TO GLTEXSUBIMAGE2D 
		ONLY RAN INTO THIS ON ALPHA TEXTURES SO MAYBE ITS OK FOR RGBA
	*/
	
	glBindTexture(GL_TEXTURE_2D, _name);
	
	switch(_format) {		
		case kTexture2DPixelFormat_RGBA8888: 
		{
			
			glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, _size.width, _size.height, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
			break;
		}
		case kTexture2DPixelFormat_BGRA_EXT: 
		{
			//glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, _size.width, _size.height, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
			glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, _size.width, _size.height, GL_BGRA_EXT, GL_UNSIGNED_BYTE, pixels);
			break;
		}	
		case kTexture2DPixelFormat_RGB565:
			glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0,  _size.width, _size.height, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, pixels);
			break;
		case kTexture2DPixelFormat_A8:
		{
			glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, ((int)_size.width), ((int)_size.height), GL_LUMINANCE, GL_UNSIGNED_BYTE, pixels);
			if ( glGetError() != GL_NO_ERROR ) {
				NSLog(@"there was an error!");
			}
			
			break;				
		}
		default:
			[NSException raise:NSInternalInconsistencyException format:@"Invalid pixel format"];
	}
	
	
	
	
}

-(void) drawAtPointWith90Rotation:(CGPoint)pt   {
	
	//if ( textureId == -1 ) return;
	
	glLoadIdentity();
	glOrthof(0, 320, 0, 480, -1.0f, 1.0f);
	
	// 480/512 = 0.93
	// 360/512 = 0.703
	
	GLfloat textCoords[] = {
		0.0,0.703,
		0.0,0.0,
		0.9375,0.703,
		0.9375,0.0,
    };
	textCoords[1] = (_size.width / _width );
	
	textCoords[4] = (_size.height / _height );
	textCoords[5] = (_size.width / _width );
	textCoords[6] = (_size.height / _height );
	
	GLshort vertCoords[] = {
		0,480,  
		320,480,	
		0,0,
		320,0,	
	};
	
	vertCoords[0] = pt.y;
	vertCoords[1] = pt.y + _size.height;
	vertCoords[2] = pt.x + _size.width;
	vertCoords[3] = pt.y + _size.height;
	vertCoords[4] = pt.x;
	vertCoords[5] = pt.y;
	vertCoords[6] = pt.x + _size.width;
	vertCoords[7] = pt.y;
	
	glEnable(GL_BLEND);
	glEnable(GL_TEXTURE_2D);
	glDisableClientState(GL_COLOR_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glBindTexture(GL_TEXTURE_2D, _name);
	glVertexPointer(2, GL_SHORT, 0, vertCoords);
	glTexCoordPointer(2, GL_FLOAT, 0, textCoords);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	
}

-(void) drawFrom3GSCamera {
	
	//if ( textureId == -1 ) return;
	
	glLoadIdentity();
	glOrthof(0, 320, 0, 480, -1.0f, 1.0f);
	
	static const GLfloat textCoords[] = {
		0.0,0.703,
		0.0,0.0,
		0.9375,0.703,
		0.9375,0.0,
    };
	
	static const GLshort vertCoords[] = {
		0,480,  
		320,480,	
		0,0,
		320,0,	
	};
	
	glEnable(GL_BLEND);
	glEnable(GL_TEXTURE_2D);
	glDisableClientState(GL_COLOR_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	
	//if ( !setupGL ) {
	glBindTexture(GL_TEXTURE_2D, _name);
	//glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	glVertexPointer(2, GL_SHORT, 0, vertCoords);
	glTexCoordPointer(2, GL_FLOAT, 0, textCoords);
	//setupGL = YES;
	//}
	
	
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	
}

@end








