//
//  ELImageOutput.h
//  liveDemo
//
//  Created by apple on 16/3/3.
//  Copyright © 2016年 changba. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ELImageTextureFrame.h"
#import "ELImageContext.h"

void runSyncOnVideoProcessingQueue(void (^block)(void));
void runAsyncOnVideoProcessingQueue(void (^block)(void));
void runSyncOnContextQueue(ELImageContext *context, void (^block)(void));
void runAsyncOnContextQueue(ELImageContext *context, void (^block)(void));

@interface ELImageOutput : NSObject
{
    
    ELImageTextureFrame *outputTexture; //渲染目标的纹理对象
    
    NSMutableArray *targets; //后级节点列表
}


- (void)setInputTextureForTarget:(id<ELImageInput>)target;

- (ELImageTextureFrame *)framebufferForOutput;

- (NSArray*)targets;

- (void)addTarget:(id<ELImageInput>)newTarget;

- (void)removeTarget:(id<ELImageInput>)targetToRemove;

- (void)removeAllTargets;

@end
