//
//  CameraPreviewRenderer.m
//  liveDemo
//
//  Created by apple on 16/2/29.
//  Copyright © 2016年 changba. All rights reserved.
//

#import "ELImageCameraRenderer.h"
#import "ELImageContext.h"
#import "ELImageProgram.h"
#import "ELImageOutput.h"

NSString *const vertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
 }
 );

NSString *const fragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate; //纹理坐标
 
 //从 CVPixelBuffer 里面上传到显存中的纹理对象
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 uniform mediump mat3 colorConversionMatrix; //根据像素格式，以及是否为 FullRange 选择的变换矩阵
 
 void main()
 {
     mediump vec3 yuv;
     lowp vec3 rgb;
     
    //由于 luminanceTexture 使用的是 GL_LUMINANCE 格式上传上来的纹理，所以这里使用 texture2D 函数拿出像素点之后，访问元素 r 就可以拿到 Y 通道的值了。
     yuv.x = texture2D(luminanceTexture, textureCoordinate).r;
    //UV 通道使用的是 GL_LUMINANCE_ALPHA 格式，通过 texture2D 取出像素点之后，访问元素 r 得到 U 的值，访问元素 a 得到 V 的值。但为什么 UV 值要减去 0.5（换算为 0-255 就是减去 127）？这是因为 UV 是色彩分量，当整张图片是黑白的时候，UV 分量是默认值 127，所以这里要先减去 127，然后再转换成 RGB，否则会出现色彩不匹配的错误。
     yuv.yz = texture2D(chrominanceTexture, textureCoordinate).ra - vec2(0.5, 0.5);
     rgb = colorConversionMatrix * yuv;
     
     gl_FragColor = vec4(rgb, 1);
 }
 );

NSString *const YUVVideoRangeConversionForLAFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 uniform mediump mat3 colorConversionMatrix;
 
 void main()
 {
     mediump vec3 yuv;
     lowp vec3 rgb;
     
     yuv.x = texture2D(luminanceTexture, textureCoordinate).r - (16.0/255.0);
     yuv.yz = texture2D(chrominanceTexture, textureCoordinate).ra - vec2(0.5, 0.5);
     rgb = colorConversionMatrix * yuv;
     
     gl_FragColor = vec4(rgb, 1);
 }
 );

@implementation ELImageCameraRenderer{
    ELImageProgram*     program;
    
    GLuint          luminanceTexture;
    GLuint          chrominanceTexture;
    
    GLint positionAttribute, textureCoordinateAttribute;
    GLint luminanceTextureUniform, chrominanceTextureUniform;
    GLint matrixUniform;
}

- (BOOL) prepareRender:(BOOL) isFullYUVRange;
{
    BOOL ret = FALSE;
    if(isFullYUVRange){
        program = [[ELImageProgram alloc] initWithVertexShaderString:vertexShaderString fragmentShaderString:fragmentShaderString];
    } else{
        program = [[ELImageProgram alloc] initWithVertexShaderString:vertexShaderString fragmentShaderString:YUVVideoRangeConversionForLAFragmentShaderString];
    }
    if(program){
        [program addAttribute:@"position"];
        [program addAttribute:@"inputTextureCoordinate"];
        if([program link]){
            positionAttribute = [program attributeIndex:@"position"];
            textureCoordinateAttribute = [program attributeIndex:@"inputTextureCoordinate"];
            luminanceTextureUniform = [program uniformIndex:@"luminanceTexture"];
            chrominanceTextureUniform = [program uniformIndex:@"chrominanceTexture"];
            matrixUniform = [program uniformIndex:@"colorConversionMatrix"];
            
            [program use];
            glEnableVertexAttribArray(positionAttribute);
            glEnableVertexAttribArray(textureCoordinateAttribute);
            
            ret = TRUE;
        }
    }
    return ret;
}

- (void) renderWithSampleBuffer:(CMSampleBufferRef) sampleBuffer aspectRatio:(float)aspectRatio preferredConversion:(const GLfloat *)preferredConversion imageRotation:(ELImageRotationMode) inputTexRotation;
{
//    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
    int bufferWidth = (int) CVPixelBufferGetWidth(cameraFrame);
    int bufferHeight = (int) CVPixelBufferGetHeight(cameraFrame);
//    CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
    [program use];
    //由于 CVPixelBuffer 内部数据是 YUV 数据格式的，所以可分配以下两个纹理对象分别存储 Y 和 UV 的数据
    CVOpenGLESTextureRef luminanceTextureRef = NULL;
    CVOpenGLESTextureRef chrominanceTextureRef = NULL;
    
    CVPixelBufferLockBaseAddress(cameraFrame, 0);
    CVReturn err;

    // Y-plane
    glActiveTexture(GL_TEXTURE4);
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[ELImageContext sharedImageProcessingContext] coreVideoTextureCache], cameraFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
    if (err)
    {
        NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
        
    //使用 Y 通道的数据内容创建出来的纹理对象可以通过 CVOpenGLESTextureGetName 来获取出纹理 ID
    luminanceTexture = CVOpenGLESTextureGetName(luminanceTextureRef);
    glBindTexture(GL_TEXTURE_2D, luminanceTexture);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
    // UV-plane，可以把 UV 通道部分上传到 chrominanceTextureRef 里
    glActiveTexture(GL_TEXTURE5);
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[ELImageContext sharedImageProcessingContext] coreVideoTextureCache], cameraFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
    if (err)
    {
        NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
    chrominanceTexture = CVOpenGLESTextureGetName(chrominanceTextureRef);
    glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    [self convertYUVToRGBOutputWithWidth:bufferWidth height:bufferHeight aspectRatio:aspectRatio preferredConversion:preferredConversion inputTexRotation:inputTexRotation];

    CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
    CFRelease(luminanceTextureRef);
    CFRelease(chrominanceTextureRef);
}

- (void)convertYUVToRGBOutputWithWidth:(int) bufferWidth height:(int) bufferHeight aspectRatio:(float)aspectRatio preferredConversion:(const GLfloat *)preferredConversion inputTexRotation:(ELImageRotationMode) inputTexRotation;
{
    int targetWidth = bufferHeight / aspectRatio;
    int targetHeight = bufferHeight;
    float fromX = (float)((bufferWidth - targetWidth) / 2) / (float) bufferWidth;
    float toX = 1.0f - fromX;
    glViewport(0, 0, targetWidth, targetHeight);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    GLfloat rotate180TextureCoordinates[] = {
        fromX, 1.0f,
        toX, 1.0f,
        fromX, 0.0f,
        toX, 0.0f,
    };
    if(inputTexRotation == kELImageFlipHorizontal){
        rotate180TextureCoordinates[0] = toX;
        rotate180TextureCoordinates[2] = fromX;
        rotate180TextureCoordinates[4] = toX;
        rotate180TextureCoordinates[6] = fromX;
    }
    
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, luminanceTexture);
    glUniform1i(luminanceTextureUniform, 4);
    
    glActiveTexture(GL_TEXTURE5);
    glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
    glUniform1i(chrominanceTextureUniform, 5);
    
    glUniformMatrix3fv(matrixUniform, 1, GL_FALSE, preferredConversion);
    
    glVertexAttribPointer(positionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
    glEnableVertexAttribArray(positionAttribute);
    glVertexAttribPointer(textureCoordinateAttribute, 2, GL_FLOAT, 0, 0, rotate180TextureCoordinates);
    glEnableVertexAttribArray(textureCoordinateAttribute);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

@end
