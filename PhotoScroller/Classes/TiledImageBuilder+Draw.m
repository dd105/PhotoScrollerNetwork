/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *
 * This file is part of PhotoScrollerNetwork -- An iOS project that smoothly and efficiently
 * renders large images in progressively smaller ones for display in a CATiledLayer backed view.
 * Images can either be local, or more interestingly, downloaded from the internet.
 * Images can be rendered by an iOS CGImageSource, libjpeg-turbo, or incrmentally by
 * libjpeg (the turbo version) - the latter gives the best speed.
 *
 * Parts taken with minor changes from Apple's PhotoScroller sample code, the
 * ConcurrentOp from my ConcurrentOperations github sample code, and TiledImageBuilder
 * was completely original source code developed by me.
 *
 * Copyright 2012 David Hoerl All Rights Reserved.
 *
 *
 * Redistribution and use in source and binary forms, with or without modification, are
 * permitted provided that the following conditions are met:
 *
 *    1. Redistributions of source code must retain the above copyright notice, this list of
 *       conditions and the following disclaimer.
 *
 *    2. Redistributions in binary form must reproduce the above copyright notice, this list
 *       of conditions and the following disclaimer in the documentation and/or other materials
 *       provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY David Hoerl ''AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 * FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL David Hoerl OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#import "TiledImageBuilder-Private.h"

#if 0
@interface TiledImageBuilder (Draw)

- (CGImageRef)newImageForScale:(CGFloat)scale location:(CGPoint)pt;
- (UIImage *)tileForScale:(CGFloat)scale location:(CGPoint)pt;
- (CGAffineTransform)transformForRect:(CGRect)box scale:(CGFloat)scale;

@end

#endif

static inline long offsetFromScale(CGFloat scale) { long s = lrintf(scale*1000.f); long idx = 0; while(s < 1000) s *= 2, ++idx; return idx; }

static size_t PhotoScrollerProviderGetBytesAtPosition (
    void *info,
    void *buffer,
    off_t position,
    size_t count
);
static void PhotoScrollerProviderReleaseInfoCallback (
    void *info
);

@implementation TiledImageBuilder (Draw)

- (UIImage *)tileForScale:(CGFloat)scale location:(CGPoint)pt
{
	CGImageRef image = [self newImageForScale:scale location:pt];
	UIImage *img = [UIImage imageWithCGImage:image];
	CGImageRelease(image);
	return img;
}

- (CGImageRef)newImageForScale:(CGFloat)scale location:(CGPoint)origPt
{
	if(self.failed) return nil;

	CGPoint pt = [self translateTileForScale:scale location:origPt];
	int col = lrintf(pt.x);
	int row = lrintf(pt.y);

	long idx = offsetFromScale(scale);
	imageMemory *im = (imageMemory *)malloc(sizeof(imageMemory));
	memcpy(im, &self.ims[idx], sizeof(imageMemory));
	im->col = col;
	im->row = row;

	BOOL newCol = NO;
	BOOL newRow = NO;
	
	switch(self.orientation) {
	default:
	case 0:
	case 1:
	case 5:
		break;
	case 2:
	case 8:
		newCol = YES;
		break;
	case 3:
	case 7:
		newCol = YES;
		newRow = YES;
		break;
	case 4:
	case 6:
		newRow = YES;
		break;
	}
	int ncol = newCol ? (self.ims[idx].cols - col - 1) : col;
	int nrow = newRow ? (self.ims[idx].rows - row - 1) : row;
	

#if 0
  1        2       3      4         5            6           7          8

888888  888888      88  88      8888888888  88                  88  8888888888
88          88      88  88      88  88      88  88          88  88      88  88
8888      8888    8888  8888    88          8888888888  8888888888          88
88          88      88  88
88          88  888888  888888
#endif
		
	size_t x = ncol * tileDimension;
	size_t y = nrow * tileDimension;

	im->tileWidth = MIN(im->map.width-x, tileDimension);
	im->tileHeight = MIN(im->map.height-y, tileDimension);

	size_t imgSize = tileBytesPerRow*im->tileHeight;
	struct CGDataProviderDirectCallbacks callBacks = { 0, 0, 0, PhotoScrollerProviderGetBytesAtPosition, PhotoScrollerProviderReleaseInfoCallback};
	CGDataProviderRef dataProvider = CGDataProviderCreateDirect(im, imgSize, &callBacks);
	
	CGImageRef image = CGImageCreate(
	   im->tileWidth,
	   im->tileHeight,
	   bitsPerComponent,
	   4*bitsPerComponent,
	   tileBytesPerRow,
	   [TiledImageBuilder colorSpace],
	   kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little,	// kCGImageAlphaPremultipliedFirst kCGImageAlphaPremultipliedLast        kCGBitmapByteOrder32Big kCGBitmapByteOrder32Little
	   dataProvider,
	   NULL,
	   false,
	   kCGRenderingIntentPerceptual
	);
	CGDataProviderRelease(dataProvider);
	return image;
}

#if 0
  1        2       3      4         5            6           7          8

888888  888888      88  88      8888888888  88                  88  8888888888
88          88      88  88      88  88      88  88          88  88      88  88
8888      8888    8888  8888    88          8888888888  8888888888          88
88          88      88  88
88          88  888888  888888
#endif

- (CGSize)imageSize
{
	switch(self.orientation) {
	case 5:
	case 6:
	case 7:
	case 8:
		return CGSizeMake(self.ims[0].map.height, self.ims[0].map.width);
	default:
		return CGSizeMake(self.ims[0].map.width, self.ims[0].map.height);
	}
}

#if 0
  1        2       3      4         5            6           7          8

888888  888888      88  88      8888888888  88                  88  8888888888
88          88      88  88      88  88      88  88          88  88      88  88
8888      8888    8888  8888    88          8888888888  8888888888          88
88          88      88  88
88          88  888888  888888
#endif

- (CGPoint)translateTileForScale:(CGFloat)scale location:(CGPoint)origPt
{
	NSUInteger idx = 0;
	NSUInteger tmp = 1;
	NSUInteger power = lrintf(1/scale);
	while(tmp != power) {
		++idx;
		tmp *= 2;
	}
	imageMemory *imP = &self.ims[idx];
	
	CGPoint newPt;
	switch(self.orientation) {
	default:
	case 1:
		newPt = origPt;
		break;
	case 2:
		newPt = CGPointMake(imP->cols - origPt.x - 1, origPt.y);
		break;
	case 3:
		newPt = CGPointMake(imP->cols - origPt.x - 1, imP->rows - origPt.y - 1);
		break;
	case 4:
		newPt = CGPointMake(origPt.x, imP->rows - origPt.y - 1);
		break;
	case 5:
		newPt = CGPointMake(origPt.y, origPt.x);
		break;
	case 6:
		newPt = CGPointMake(origPt.y, imP->cols - origPt.x - 1);
		break;
	case 7:
		newPt = CGPointMake(imP->rows - origPt.y - 1, imP->cols - origPt.x - 1);
		break;
	case 8:
		newPt = CGPointMake(imP->rows - origPt.y - 1, origPt.x);
		break;
	}
	//NSLog(@"OLDPT=%@ NEWPT=%@", NSStringFromCGPoint(origPt), NSStringFromCGPoint(newPt) );
	return newPt;
}

#if 0
  1        2       3      4         5            6           7          8

888888  888888      88  88      8888888888  88                  88  8888888888
88          88      88  88      88  88      88  88          88  88      88  88
8888      8888    8888  8888    88          8888888888  8888888888          88
88          88      88  88
88          88  888888  888888
#endif

- (CGAffineTransform)transformForRect:(CGRect)box scale:(CGFloat)scale
{
	// origin is a 0, 0
	CGAffineTransform transform = CGAffineTransformIdentity;
	
	BOOL flipH = NO;
	BOOL flipV = NO;
	CGFloat rotate = 0;

	switch(self.orientation) {
	default:
	case 1:
		break;
	case 2:
		flipH = YES;
		break;
	case 3:
		flipH = YES;
		flipV = YES;
		break;
	case 4:
		flipV = YES;
		break;
	case 5:
		flipH = YES;
		rotate = (CGFloat)(90*M_PI)/180;
		break;
	case 6:
		flipH = YES;
		rotate = (CGFloat)(90*M_PI)/180;
		break;
	case 7:
		flipH = YES;
		rotate = -(CGFloat)(90*M_PI)/180;
		break;
	case 8:
		flipH = YES;
		rotate = -(CGFloat)(90*M_PI)/180;
		break;
	}
	
	if(flipH) {
		CGFloat xOffset = box.size.width/2;
		transform = CGAffineTransformTranslate(transform, +xOffset, 0);
		transform = CGAffineTransformScale(transform, -1, 1);
		transform = CGAffineTransformTranslate(transform, -xOffset, 0);
	}
	if(flipV) {
		CGFloat yOffset = box.size.height/2;
		transform = CGAffineTransformTranslate(transform, 0, +yOffset);
		transform = CGAffineTransformScale(transform, 1, -1);
		transform = CGAffineTransformTranslate(transform, 0, -yOffset);
	}
	if(isnormal(rotate)) {
		// must rotate from box center, not image bits
		CGFloat x = box.origin.x + rintf(TILE_SIZE/scale)/2;
		CGFloat y = box.origin.y + rintf(TILE_SIZE/scale)/2;

		transform = CGAffineTransformTranslate(transform, +x, +y);
		transform = CGAffineTransformRotate(transform, rotate);
		transform = CGAffineTransformTranslate(transform, -x, -y);
	}

	return transform;
}

@end

static size_t PhotoScrollerProviderGetBytesAtPosition (
    void *info,
    void *buffer,
    off_t position,
    size_t origCount
) {
	imageMemory *im = (imageMemory *)info;

	size_t mapSize = tileDimension*tileBytesPerRow;
	size_t offset = (im->row*im->cols + im->col) * mapSize;

	BOOL applyColOffset = NO;
	BOOL applyRowOffset = NO;
	if(im->rotated) {
		if(!im->row) {
			applyColOffset = YES;
		}
		if(!im->col) {
			applyRowOffset = YES;
		}
	} else {
		if(!im->col) {
			applyColOffset = YES;
		}
		if(!im->row) {
			applyRowOffset = YES;
		}
	}
	if(applyRowOffset) {
		offset += im->map.row0offset * tileBytesPerRow;
	}
	if(applyColOffset) {
		offset += im->map.col0offset;
	}


#if MAPPING_IMAGES == 1	
	// Turning the NOCACHE flag off might up performance, but really clog the system
	// Note that the OS calls this on multiple threads. Thus, we cannot read directly from the file - we'd have to single thread those reads.
	// mmap lets us map as many areas as we need.
	unsigned char *startPtr = mmap(NULL, mapSize, PROT_READ, MAP_FILE | MAP_SHARED | MAP_NOCACHE, im->map.fd, offset);  /*| MAP_NOCACHE */
	if(startPtr == MAP_FAILED) {
		NSLog(@"errno4=%s", strerror(errno) );
		return 0;
	}

	memcpy(buffer, startPtr+position, origCount);	// blit the image, then return. How nice is that!
	munmap(startPtr, mapSize);
#else
	ssize_t readSize = pread(im->map.fd, buffer, origCount, offset + position);
	if((size_t)readSize != origCount) {
		NSLog(@"errno4=%s", strerror(errno) );
		return 0;
	}
#endif
	return origCount;
}

static void PhotoScrollerProviderReleaseInfoCallback (
    void *info
) {
	free(info);
}
