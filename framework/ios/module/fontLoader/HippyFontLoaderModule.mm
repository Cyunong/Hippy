/*!
* iOS SDK
*
* Tencent is pleased to support the open source community by making
* Hippy available.
*
* Copyright (C) 2019 THL A29 Limited, a Tencent company.
* All rights reserved.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*   http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

#import <UIKit/UIKit.h>
#import "HippyFontLoaderModule.h"
#import <CoreText/CoreText.h>
#import "HippyBridge+Private.h"
#import "HippyBridge+VFSLoader.h"
#import "HippyLog.h"
#import "VFSUriLoader.h"
#import "HippyUIManager.h"


NSString *const HippyLoadFontNotification = @"HippyLoadFontNotification";
static NSString *const kFontLoaderModuleErrorDomain = @"kFontLoaderModuleErrorDomain";
static NSUInteger const FontLoaderErrorUrlError = 1;
static NSUInteger const FontLoaderErrorDirectoryError = 2;
static NSUInteger const FontLoaderErrorRequestError = 3;
static NSUInteger const FontLoaderErrorRegisterError = 4;
NSString *const HippyFontDirName = @"HippyFonts";
NSString *const HippyFontUrlCacheName = @"urlToFile.plist";
NSString *const HippyFontFamilyCacheName = @"fontFaimilyToFiles.plist";

static NSMutableDictionary *urlToFile;
static NSMutableDictionary *fontFamilyToFiles;
static NSString *fontDirPath;
static NSString *fontUrlCachePath;
static NSString *fontFamilyCachePath;
static NSMutableArray *fontRegistered = [NSMutableArray array];

@implementation HippyFontLoaderModule

HIPPY_EXPORT_MODULE(FontLoaderModule)

@synthesize bridge = _bridge;

- (instancetype)init {
    if ((self = [super init])) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
            [notificationCenter addObserver:self selector:@selector(loadFont:) name:HippyLoadFontNotification object:nil];
            
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            NSString *cachesDirectory = [paths objectAtIndex:0];
            fontDirPath = [cachesDirectory stringByAppendingPathComponent:HippyFontDirName];
            fontUrlCachePath = [fontDirPath stringByAppendingPathComponent:HippyFontUrlCacheName];
            fontFamilyCachePath = [fontDirPath stringByAppendingPathComponent:HippyFontFamilyCacheName];
        });
    }
    return self;
}

+ (void) initDictIfNeeded {
    if (fontFamilyToFiles == nil) {
        fontFamilyToFiles = [NSMutableDictionary dictionaryWithContentsOfFile:fontFamilyCachePath];
        if (fontFamilyToFiles == nil) {
            fontFamilyToFiles =  [NSMutableDictionary dictionary];
        }
    }
    if (urlToFile == nil) {
        urlToFile = [NSMutableDictionary dictionaryWithContentsOfFile:fontUrlCachePath];
        if (urlToFile == nil) {
            urlToFile =  [NSMutableDictionary dictionary];
        }
    }
}

- (void)loadFont:(NSNotification *)notification {
    NSString *urlString = [notification.userInfo objectForKey:@"fontUrl"];
    NSString *fontFamily = [notification.userInfo objectForKey:@"fontFamily"];
    [self load:fontFamily from:urlString resolver:nil rejecter:nil];
}

+ (NSString *)getFontPath:(NSString *)url {
    [self initDictIfNeeded];
    NSString *fontFile = urlToFile[url];
    if (!fontFile) {
        return nil;
    }
    NSString *fontPath = [fontDirPath stringByAppendingPathComponent:fontFile];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:fontPath]) {
        return nil;
    }
    return fontPath;
}

+ (void)registerFontIfNeeded:(NSString *)fontFamily {
    [self initDictIfNeeded];
    NSMutableArray *fontFiles = [fontFamilyToFiles objectForKey:fontFamily];
    BOOL isFontRegistered = NO;
    if (fontFiles) {
        NSMutableArray *fileNotExist = [NSMutableArray array];
        for (NSString *fontFile in fontFiles) {
            if (![fontRegistered containsObject:fontFile]) {
                NSString *fontFilePath = [fontDirPath stringByAppendingPathComponent:fontFile];
                NSError *error = nil;
                if ([self registerFontFromURL:fontFilePath error:&error]) {
                    [fontRegistered addObject:fontFile];
                    isFontRegistered = YES;
                    HippyLogInfo(@"register font \"%@\" success!", fontFile);
                }
                else {
                    if (error.domain == kFontLoaderModuleErrorDomain && error.code == FontLoaderErrorRegisterError) {
                        [fileNotExist addObject:fontFile];
                    }
                    HippyLogWarn(@"register font \"%@\" fail!", fontFile);
                }
            }
        }
        [fontFiles removeObjectsInArray:fileNotExist];
        if (isFontRegistered) {
            [[NSNotificationCenter defaultCenter] postNotificationName:HippyFontChangeTriggerNotification object:nil];
        }
    }
}


+ (BOOL)registerFontFromURL:(NSString *)urlString error:(NSError **)error {
    NSURL *url = [NSURL fileURLWithPath:urlString];
    CGDataProviderRef fontDataProvider = CGDataProviderCreateWithURL((CFURLRef)url);
    CGFontRef font = CGFontCreateWithDataProvider(fontDataProvider);
    CGDataProviderRelease(fontDataProvider);
    if (!font) {
        *error = [NSError errorWithDomain:kFontLoaderModuleErrorDomain
                                    code:FontLoaderErrorRegisterError userInfo:@{@"reason": @"font dosen't exist"}];
        return NO;
    }
    CFErrorRef cfError;
    BOOL success = CTFontManagerRegisterGraphicsFont(font, &cfError);
    CFRelease(font);
    if (!success) {
        *error = CFBridgingRelease(cfError);
        return NO;
    }
    return YES;
}

- (void)cacheFontfamily:(NSString *)fontFamily url:(NSString *)url fileName:(NSString *)fileName {
    [HippyFontLoaderModule initDictIfNeeded];
    [urlToFile setObject:fileName forKey:url];
    NSMutableArray *fontFiles = [fontFamilyToFiles objectForKey:fontFamily];
    if (!fontFiles) {
        fontFiles = [NSMutableArray arrayWithObject:fileName];
        [fontFamilyToFiles setObject:fontFiles forKey:fontFamily];
    }
    else {
        [fontFiles addObject:fileName];
    }
    [urlToFile writeToFile:fontUrlCachePath atomically:YES];
    [fontFamilyToFiles writeToFile:fontFamilyCachePath atomically:YES];
}


HIPPY_EXPORT_METHOD(load:(NSString *)fontFamily from:(NSString *)urlString resolver:(HippyPromiseResolveBlock)resolve rejecter:(HippyPromiseRejectBlock)reject) {
    if (!urlString) {
        NSError *error = [NSError errorWithDomain:kFontLoaderModuleErrorDomain
                                             code:FontLoaderErrorUrlError userInfo:@{@"reason": @"url is empty"}];
        NSString *errorKey = [NSString stringWithFormat:@"%lu", FontLoaderErrorUrlError];
        if (reject) {
            reject(errorKey, @"url is empty", error);
        }
        return;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:fontDirPath]) {
        NSError *error;
        [fileManager createDirectoryAtPath:fontDirPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSString *errorKey = [NSString stringWithFormat:@"%lu", FontLoaderErrorDirectoryError];
            if (reject) {
                reject(errorKey, @"directory create error", error);
            }
            return;
        }
    }
    
    __weak __typeof(self) weakSelf = self;
    [self.bridge loadContentsAsynchronouslyFromUrl:urlString
                                            method:@"Get"
                                            params:nil
                                              body:nil
                                             queue:nil
                                          progress:nil
                                 completionHandler:^(NSData *data, NSDictionary *userInfo, NSURLResponse *response, NSError *error) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (error) {
            NSString *errorKey = [NSString stringWithFormat:@"%lu", FontLoaderErrorRequestError];
            if (reject) {
                reject(errorKey, @"font request error", error);
            }
            return;
        }
        NSString *fileName = [fontFamily stringByAppendingFormat:@".%@", [response.suggestedFilename pathExtension]];
        NSString *fontFilePath = [fontDirPath stringByAppendingPathComponent:fileName];
        [data writeToFile:fontFilePath atomically:YES];
        [strongSelf cacheFontfamily:fontFamily url:urlString fileName:fileName];
        [[NSNotificationCenter defaultCenter] postNotificationName:HippyFontChangeTriggerNotification object:nil];
        if (resolve) {
            HippyLogInfo(@"download font file \"%@\" success!", fileName);
            resolve(nil);
        }
    }];
}

@end
