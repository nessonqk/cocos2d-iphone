/*
 * cocos2d for iPhone: http://www.cocos2d-iphone.org
 *
 * Copyright (c) 2008-2010 Ricardo Quesada
 * Copyright (c) 2009 Jason Booth
 * Copyright (c) 2009 Robert J Payne
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

/*
 * To create sprite frames and texture atlas, use this tool:
 * http://zwoptex.zwopple.com/
 */

#import "ccMacros.h"
#import "CCTextureCache.h"
#import "CCSpriteFrameCache.h"
#import "CCSpriteFrame.h"
#import "CCSprite.h"
#import "Support/CCFileUtils.h"


@implementation CCSpriteFrameCache

#pragma mark CCSpriteFrameCache - Alloc, Init & Dealloc

static CCSpriteFrameCache *sharedSpriteFrameCache_=nil;

+ (CCSpriteFrameCache *)sharedSpriteFrameCache
{
	if (!sharedSpriteFrameCache_)
		sharedSpriteFrameCache_ = [[CCSpriteFrameCache alloc] init];
		
	return sharedSpriteFrameCache_;
}

+(id)alloc
{
	NSAssert(sharedSpriteFrameCache_ == nil, @"Attempted to allocate a second instance of a singleton.");
	return [super alloc];
}

+(void)purgeSharedSpriteFrameCache
{
	[sharedSpriteFrameCache_ release];
	sharedSpriteFrameCache_ = nil;
}

-(id) init
{
	if( (self=[super init]) ) {
		spriteFrames_ = [[NSMutableDictionary alloc] initWithCapacity: 100];
		spriteFramesAliases_ = [[NSMutableDictionary alloc] initWithCapacity:10];
	}
	
	return self;
}

- (NSString*) description
{
	return [NSString stringWithFormat:@"<%@ = %08X | num of sprite frames =  %i>", [self class], self, [spriteFrames_ count]];
}

-(void) dealloc
{
	CCLOGINFO(@"cocos2d: deallocing %@", self);
	
	[spriteFrames_ release];
	[spriteFramesAliases_ release];
	[super dealloc];
}

#pragma mark CCSpriteFrameCache - loading sprite frames

-(void) addSpriteFramesWithDictionary:(NSDictionary*)dictionary texture:(CCTexture2D*)texture
{
	/*
	Supported Zwoptex Formats:
		enum {
			ZWTCoordinatesListXMLFormat_Legacy = 0 // flash version
			ZWTCoordinatesListXMLFormat_v1_0 = 1, // desktop version
			ZWTCoordinatesListXMLFormat_v1_1 = 2, // desktop version - adds rotated support
			ZWTCoordinatesListXMLFormat_v1_2 = 3, // desktop version - adds name aliasing support
		};
	*/
	NSDictionary *metadataDict = [dictionary objectForKey:@"metadata"];
	NSDictionary *framesDict = [dictionary objectForKey:@"frames"];

	int format = 0;
	
	// get the format
	if(metadataDict != nil) {
		format = [[metadataDict objectForKey:@"format"] intValue];
	}
	
	// check the format
	NSAssert( format >= 0 && format <= 3, @"cocos2d: WARNING: format is not supported for CCSpriteFrameCache addSpriteFramesWithDictionary:texture:");
	
	
	// add real frames
	for(NSString *frameDictKey in framesDict) {
		NSDictionary *frameDict = [framesDict objectForKey:frameDictKey];
		CCSpriteFrame *spriteFrame;
		if(format == 0) {
			float x = [[frameDict objectForKey:@"x"] floatValue];
			float y = [[frameDict objectForKey:@"y"] floatValue];
			float w = [[frameDict objectForKey:@"width"] floatValue];
			float h = [[frameDict objectForKey:@"height"] floatValue];
			float ox = [[frameDict objectForKey:@"offsetX"] floatValue];
			float oy = [[frameDict objectForKey:@"offsetY"] floatValue];
			int ow = [[frameDict objectForKey:@"originalWidth"] intValue];
			int oh = [[frameDict objectForKey:@"originalHeight"] intValue];
			// check ow/oh
			if(!ow || !oh) {
				CCLOG(@"cocos2d: WARNING: originalWidth/Height not found on the CCSpriteFrame. AnchorPoint won't work as expected. Regenerate the .plist");
			}
			// abs ow/oh
			ow = abs(ow);
			oh = abs(oh);
			// create frame
			spriteFrame = [CCSpriteFrame frameWithTexture:texture rect:CGRectMake(x, y, w, h) rotated:NO offset:CGPointMake(ox, oy) originalSize:CGSizeMake(ow, oh)];
		} else if(format == 1 || format == 2 || format == 3) {
			CGRect frame = CGRectFromString([frameDict objectForKey:@"frame"]);
			BOOL rotated = NO;
			
			// rotation
			if(format == 2 || format == 3)
				rotated = [[frameDict objectForKey:@"rotated"] boolValue];
			
			// name aliases
			if(format == 3) {
				NSArray *aliases = [frameDict objectForKey:@"aliases"];
				for(NSString *alias in aliases) {
					if( [spriteFramesAliases_ objectForKey:alias] )
						CCLOG(@"cocos2d: WARNING: an alias with name %@ already exists",alias);
					
					[spriteFramesAliases_ setObject:frameDictKey forKey:alias];
				}
			}
			
			CGPoint offset = CGPointFromString([frameDict objectForKey:@"offset"]);
			CGSize sourceSize = CGSizeFromString([frameDict objectForKey:@"sourceSize"]);
			
			// create frame
			spriteFrame = [CCSpriteFrame frameWithTexture:texture rect:frame rotated:rotated offset:offset originalSize:sourceSize];
		}

		// add sprite frame
		[spriteFrames_ setObject:spriteFrame forKey:frameDictKey];
	}
}

-(void) addSpriteFramesWithFile:(NSString*)plist texture:(CCTexture2D*)texture
{
	NSString *path = [CCFileUtils fullPathFromRelativePath:plist];
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];

	return [self addSpriteFramesWithDictionary:dict texture:texture];
}

-(void) addSpriteFramesWithFile:(NSString*)plist
{
	NSString *path = [CCFileUtils fullPathFromRelativePath:plist];
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
	
	NSString *texturePath = [NSString stringWithString:plist];
	texturePath = [texturePath stringByDeletingPathExtension];
	texturePath = [texturePath stringByAppendingPathExtension:@"png"];
	
	CCTexture2D *texture = [[CCTextureCache sharedTextureCache] addImage:texturePath];
	
	return [self addSpriteFramesWithDictionary:dict texture:texture];
}

-(void) addSpriteFrame:(CCSpriteFrame*)frame name:(NSString*)frameName
{
	[spriteFrames_ setObject:frame forKey:frameName];
}

#pragma mark CCSpriteFrameCache - removing

-(void) removeSpriteFrames
{
	[spriteFrames_ removeAllObjects];
	[spriteFramesAliases_ removeAllObjects];
}

-(void) removeUnusedSpriteFrames
{
	NSArray *keys = [spriteFrames_ allKeys];
	for( id key in keys ) {
		id value = [spriteFrames_ objectForKey:key];		
		if( [value retainCount] == 1 ) {
			CCLOG(@"cocos2d: CCSpriteFrameCache: removing unused frame: %@", key);
			[spriteFrames_ removeObjectForKey:key];
		}
	}	
}

-(void) removeSpriteFrameByName:(NSString*)name
{
	// explicit nil handling
	if( ! name )
		return;
	
	// Is this an alias ?
	NSString *key = [spriteFramesAliases_ objectForKey:name];
	
	if( key ) {
		[spriteFrames_ removeObjectForKey:key];
		[spriteFramesAliases_ removeObjectForKey:name];

	} else
		[spriteFrames_ removeObjectForKey:name];
}

#pragma mark CCSpriteFrameCache - getting

-(CCSpriteFrame*) spriteFrameByName:(NSString*)name
{
	CCSpriteFrame *frame = [spriteFrames_ objectForKey:name];
	if( ! frame ) {
		// try alias dictionary
		NSString *key = [spriteFramesAliases_ objectForKey:name];
		frame = [spriteFrames_ objectForKey:key];
		
		if( ! frame )
			CCLOG(@"cocos2d: CCSpriteFrameCache: Frame '%@' not found", name);
	}
	
	return frame;
}

#pragma mark CCSpriteFrameCache - sprite creation

-(CCSprite*) createSpriteWithFrameName:(NSString*)name
{
	CCSpriteFrame *frame = [spriteFrames_ objectForKey:name];
	return [CCSprite spriteWithSpriteFrame:frame];
}
@end
