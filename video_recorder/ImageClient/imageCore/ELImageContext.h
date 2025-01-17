//
//  ELImageContext.h
//  liveDemo
//
//  Created by apple on 16/3/3.
//  Copyright © 2016年 changba. All rights reserved.
//

#import <OpenGLES/EAGL.h>
#import <Foundation/Foundation.h>
#import "ELImageTextureFrame.h"
#import <CoreMedia/CoreMedia.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#define TEXTURE_FRAME_ASPECT_RATIO                                  16.0/9.0f

typedef enum { kELImageNoRotation, kELImageFlipHorizontal } ELImageRotationMode;

//封装 EAGLContext 和渲染线程
@interface ELImageContext : NSObject

@property(readonly, nonatomic) dispatch_queue_t contextQueue;
@property(readonly, retain, nonatomic) EAGLContext *context;
@property(readonly) CVOpenGLESTextureCacheRef coreVideoTextureCache;


+ (void *)contextKey;

+ (ELImageContext *)sharedImageProcessingContext;

+ (BOOL)supportsFastTextureUpload;

+ (dispatch_queue_t)sharedContextQueue;

+ (void)useImageProcessingContext;

- (CVOpenGLESTextureCacheRef)coreVideoTextureCache;

- (void)useSharegroup:(EAGLSharegroup *)sharegroup;

- (void)useAsCurrentContext;

@end

@protocol ELImageInput <NSObject>

//执行渲染操作
- (void)newFrameReadyAtTime:(CMTime)frameTime timimgInfo:(CMSampleTimingInfo)timimgInfo;

//设置输入的纹理对象
- (void)setInputTexture:(ELImageTextureFrame *)textureFrame;

@end
