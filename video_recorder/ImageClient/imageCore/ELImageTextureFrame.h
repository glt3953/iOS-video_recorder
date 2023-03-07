//
//  GPUTextureFrame.h
//  liveDemo
//
//  Created by apple on 16/3/1.
//  Copyright © 2016年 changba. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <CoreGraphics/CGGeometry.h>


typedef struct GPUTextureFrameOptions {
    GLenum minFilter;
    GLenum magFilter;
    GLenum wrapS;
    GLenum wrapT;
    GLenum internalFormat;
    GLenum format;
    GLenum type;
} GPUTextureFrameOptions;

//将纹理对象和帧缓存对象的创建、绑定、销毁等操作，以面向对象的方式封装起来
@interface ELImageTextureFrame : NSObject

- (id)initWithSize:(CGSize)framebufferSize;

- (id)initWithSize:(CGSize)framebufferSize textureOptions:(GPUTextureFrameOptions)fboTextureOptions;

- (void)activateFramebuffer;

- (GLuint) texture;

- (GLubyte *)byteBuffer;

- (int) width;
- (int) height;
@end
