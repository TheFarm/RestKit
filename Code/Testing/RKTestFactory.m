//
//  RKTestFactory.m
//  RestKit
//
//  Created by Blake Watters on 2/16/12.
//  Copyright (c) 2009-2012 RestKit. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "AFRKHTTPClient.h"
#import "RKTestFactory.h"
#import "RKLog.h"
#import "RKObjectManager.h"
#import "RKPathUtilities.h"
#import "RKMIMETypeSerialization.h"
#import "RKObjectRequestOperation.h"

// Expose MIME Type singleton and initialization routine
@interface RKMIMETypeSerialization ()
+ (RKMIMETypeSerialization *)sharedSerialization;
- (void)addRegistrationsForKnownSerializations;
@end

@interface RKTestFactory ()

@property (nonatomic, strong) NSURL *baseURL;
@property (nonatomic, strong) NSMutableDictionary *factoryBlocks;
@property (nonatomic, strong) NSMutableDictionary *sharedObjectsByFactoryName;
@property (nonatomic, copy) void (^setUpBlock)(void);
@property (nonatomic, copy) void (^tearDownBlock)(void);

+ (RKTestFactory *)sharedFactory;
- (void)defineFactory:(NSString *)factoryName withBlock:(id (^)(void))block;
- (id)objectFromFactory:(NSString *)factoryName properties:(NSDictionary *)properties;
- (void)defineDefaultFactories;

@end

@implementation RKTestFactory

+ (void)initialize
{
    // Ensure the shared factory is initialized
    [self sharedFactory];
}

+ (RKTestFactory *)sharedFactory
{
    static RKTestFactory *sharedFactory = nil;
    if (!sharedFactory) {
        sharedFactory = [RKTestFactory new];
    }

    return sharedFactory;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.baseURL = [NSURL URLWithString:@"http://localhost:4567"];
        self.factoryBlocks = [NSMutableDictionary new];
        self.sharedObjectsByFactoryName = [NSMutableDictionary new];
        [self defineDefaultFactories];
    }

    return self;
}

- (void)defineFactory:(NSString *)factoryName withBlock:(id (^)(void))block
{
    (self.factoryBlocks)[factoryName] = [block copy];
}

- (id)objectFromFactory:(NSString *)factoryName properties:(NSDictionary *)properties
{
    id (^block)(void) = (self.factoryBlocks)[factoryName];
    NSAssert(block, @"No factory is defined with the name '%@'", factoryName);

    id object = block();
    [object setValuesForKeysWithDictionary:properties];
    return object;
}

- (id)sharedObjectFromFactory:(NSString *)factoryName
{
    id sharedObject = (self.sharedObjectsByFactoryName)[factoryName];
    if (!sharedObject) {
        sharedObject = [self objectFromFactory:factoryName properties:nil];
        (self.sharedObjectsByFactoryName)[factoryName] = sharedObject;
    }
    return sharedObject;
}

- (void)defineDefaultFactories
{
    [self defineFactory:RKTestFactoryDefaultNamesClient withBlock:^id {
        __block AFRKHTTPClient *client;
        RKLogSilenceComponentWhileExecutingBlock(RKlcl_cRestKitSupport, ^{
            client = [AFRKHTTPClient clientWithBaseURL:self.baseURL];
        });

        return client;
    }];

    [self defineFactory:RKTestFactoryDefaultNamesObjectManager withBlock:^id {
        __block RKObjectManager *objectManager;
        RKLogSilenceComponentWhileExecutingBlock(RKlcl_cRestKitSupport, ^{
            objectManager = [RKObjectManager managerWithBaseURL:self.baseURL];
        });

        return objectManager;
    }];
}

#pragma mark - Public Static Interface

+ (NSURL *)baseURL
{
    return [RKTestFactory sharedFactory].baseURL;
}

+ (void)setBaseURL:(NSURL *)URL
{
    [RKTestFactory sharedFactory].baseURL = URL;
}

+ (void)defineFactory:(NSString *)factoryName withBlock:(id (^)(void))block
{
    [[RKTestFactory sharedFactory] defineFactory:factoryName withBlock:block];
}

+ (id)objectFromFactory:(NSString *)factoryName properties:(NSDictionary *)properties
{
    return [[RKTestFactory sharedFactory] objectFromFactory:factoryName properties:properties];
}

+ (id)objectFromFactory:(NSString *)factoryName
{
    return [[RKTestFactory sharedFactory] objectFromFactory:factoryName properties:nil];
}

+ (id)sharedObjectFromFactory:(NSString *)factoryName
{
    return [[RKTestFactory sharedFactory] sharedObjectFromFactory:factoryName];
}

+ (NSSet *)factoryNames
{
    return [NSSet setWithArray:[[RKTestFactory sharedFactory].factoryBlocks allKeys]];
}

+ (id)client
{
    return [self sharedObjectFromFactory:RKTestFactoryDefaultNamesClient];
}

+ (id)objectManager
{
    return [self sharedObjectFromFactory:RKTestFactoryDefaultNamesObjectManager];
}

+ (void)setSetupBlock:(void (^)(void))block
{
    [RKTestFactory sharedFactory].setUpBlock = block;
}

+ (void)setTearDownBlock:(void (^)(void))block
{
    [RKTestFactory sharedFactory].tearDownBlock = block;
}

+ (void)setUp
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // On initial set up, perform a tear down to clear any state from the application launch
        [self tearDown];
    });

    [[RKTestFactory sharedFactory].sharedObjectsByFactoryName removeAllObjects];
    [RKObjectManager setSharedManager:nil];

    // Restore the default MIME Type Serializations in case a test has manipulated the registry
    [[RKMIMETypeSerialization sharedSerialization] addRegistrationsForKnownSerializations];

    // Delete the store if it exists
    NSString *path = [RKApplicationDataDirectory() stringByAppendingPathComponent:RKTestFactoryDefaultStoreFilename];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    // Check for and remove -shm and -wal files
    for (NSString *suffix in @[ @"-shm", @"-wal" ]) {
        NSString *supportFilePath = [path stringByAppendingString:suffix];
        if ([[NSFileManager defaultManager] fileExistsAtPath:supportFilePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:supportFilePath error:nil];
        }
    }

    if ([RKTestFactory sharedFactory].setUpBlock) [RKTestFactory sharedFactory].setUpBlock();
}

+ (void)tearDown
{
    if ([RKTestFactory sharedFactory].tearDownBlock) [RKTestFactory sharedFactory].tearDownBlock();

    // Cancel any network operations and clear the cache
    [[RKObjectManager sharedManager].operationQueue cancelAllOperations];

    // Cancel any object mapping in the response mapping queue
    [[RKObjectRequestOperation responseMappingQueue] cancelAllOperations];

    [[RKTestFactory sharedFactory].sharedObjectsByFactoryName removeAllObjects];
    [RKObjectManager setSharedManager:nil];
}

@end
