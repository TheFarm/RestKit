//
//  RKObjectManagerTest.m
//  RestKit
//
//  Created by Blake Watters on 1/14/10.
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

#import "RKTestEnvironment.h"
#import "RKObjectManager.h"
#import "RKHuman.h"
#import "RKCat.h"
#import "RKTestUser.h"
#import "RKObjectMapperTestModel.h"
#import "RKDynamicMapping.h"
#import "RKTestAddress.h"
#import "RKPost.h"
#import "RKObjectRequestOperation.h"
#import "RKManagedObjectRequestOperation.h"

@interface RKSubclassedTestModel : RKObjectMapperTestModel
@end

@implementation RKSubclassedTestModel
@end

@interface RKTestAFHTTPClient : AFRKHTTPClient
@end

@implementation RKTestAFHTTPClient

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method
                                      path:(NSString *)path
                                parameters:(NSDictionary *)parameters
{
    NSMutableURLRequest *request = [super requestWithMethod:method path:path parameters:parameters];
    [request setAllHTTPHeaderFields:@{@"test": @"value", @"Accept": @"text/html"}];
    return request;
}

@end

@interface RKTestHTTPRequestOperation : RKHTTPRequestOperation
@end
@implementation RKTestHTTPRequestOperation : RKHTTPRequestOperation
@end

@interface RKTestObjectRequestOperation : RKObjectRequestOperation
@end

@implementation RKTestObjectRequestOperation

+ (BOOL)canProcessRequest:(NSURLRequest *)request
{
    return [[request.URL relativePath] isEqualToString:@"/match"];
}

@end


@interface RKObjectManagerTest : RKTestCase

@property (nonatomic, strong) RKObjectManager *objectManager;
@property (nonatomic, strong) RKRoute *humanGETRoute;
@property (nonatomic, strong) RKRoute *humanPOSTRoute;
@property (nonatomic, strong) RKRoute *humanDELETERoute;
@property (nonatomic, strong) RKRoute *humanCatsRoute;
@property (nonatomic, strong) RKRoute *humansCollectionRoute;

@end

@implementation RKObjectManagerTest

- (void)setUp
{
    [RKTestFactory setUp];
    
    self.objectManager = [RKTestFactory objectManager];
    [RKObjectManager setSharedManager:self.objectManager];
    
    RKObjectMapping *humanSerialization = [RKObjectMapping requestMapping];
    [humanSerialization addPropertyMapping:[RKAttributeMapping attributeMappingFromKeyPath:@"name" toKeyPath:@"name"]];
    [self.objectManager addRequestDescriptor:[RKRequestDescriptor requestDescriptorWithMapping:humanSerialization objectClass:[RKHuman class] rootKeyPath:@"human" method:RKRequestMethodAny]];

    self.humanPOSTRoute = [RKRoute routeWithClass:[RKHuman class] pathPattern:@"/humans" method:RKRequestMethodPOST];
    self.humanGETRoute = [RKRoute routeWithClass:[RKHuman class] pathPattern:@"/humans/:railsID" method:RKRequestMethodGET];
    self.humanDELETERoute = [RKRoute routeWithClass:[RKHuman class] pathPattern:@"/humans/:railsID" method:RKRequestMethodDELETE];
    self.humanCatsRoute = [RKRoute routeWithRelationshipName:@"cats" objectClass:[RKHuman class] pathPattern:@"/humans/:railsID/cats" method:RKRequestMethodGET];
    self.humansCollectionRoute = [RKRoute routeWithName:@"humans" pathPattern:@"/humans" method:RKRequestMethodGET];

    [self.objectManager.router.routeSet addRoute:self.humanPOSTRoute];
    [self.objectManager.router.routeSet addRoute:self.humanGETRoute];
    [self.objectManager.router.routeSet addRoute:self.humanDELETERoute];
    [self.objectManager.router.routeSet addRoute:self.humanCatsRoute];
    [self.objectManager.router.routeSet addRoute:self.humansCollectionRoute];
}

- (void)tearDown
{
    [RKTestFactory tearDown];
}

- (void)testInitializationWithBaseURLSetsDefaultAcceptHeaderValueToJSON
{
    RKObjectManager *manager = [RKObjectManager managerWithBaseURL:[NSURL URLWithString:@"http://restkit.org"]];
    expect([manager defaultHeaders][@"Accept"]).to.equal(RKMIMETypeJSON);
}

- (void)testInitializationWithBaseURLSetsRequestSerializationMIMETypeToFormURLEncoded
{
    RKObjectManager *manager = [RKObjectManager managerWithBaseURL:[NSURL URLWithString:@"http://restkit.org"]];
    expect(manager.requestSerializationMIMEType).to.equal(RKMIMETypeFormURLEncoded);
}

- (void)testInitializationWithAFHTTPClientSetsNilAcceptHeaderValue
{
    AFRKHTTPClient *client = [AFRKHTTPClient clientWithBaseURL:[NSURL URLWithString:@"http://restkit.org"]];
    [client setDefaultHeader:@"Accept" value:@"this/that"];
    RKObjectManager *manager = [[RKObjectManager alloc] initWithHTTPClient:client];
    expect([manager defaultHeaders][@"Accept"]).to.equal(@"this/that");
}

- (void)testDefersToAFHTTPClientParameterEncodingWhenInitializedWithAFHTTPClient
{
    AFRKHTTPClient *client = [AFRKHTTPClient clientWithBaseURL:[NSURL URLWithString:@"http://restkit.org"]];
    client.parameterEncoding = AFRKJSONParameterEncoding;
    RKObjectManager *manager = [[RKObjectManager alloc] initWithHTTPClient:client];
    expect([manager requestSerializationMIMEType]).to.equal(RKMIMETypeJSON);
}

- (void)testDefaultsToFormURLEncodingForUnsupportedParameterEncodings
{
    AFRKHTTPClient *client = [AFRKHTTPClient clientWithBaseURL:[NSURL URLWithString:@"http://restkit.org"]];
    client.parameterEncoding = AFRKPropertyListParameterEncoding;
    RKObjectManager *manager = [[RKObjectManager alloc] initWithHTTPClient:client];
    expect([manager requestSerializationMIMEType]).to.equal(RKMIMETypeFormURLEncoded);
}

- (void)testCancellationByExactMethodAndPath
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"/object_manager/cancel" relativeToURL:self.objectManager.HTTPClient.baseURL]];
    RKObjectRequestOperation *operation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:self.objectManager.responseDescriptors];
    [_objectManager enqueueObjectRequestOperation:operation];
    [_objectManager cancelAllObjectRequestOperationsWithMethod:RKRequestMethodGET matchingPathPattern:@"/object_manager/cancel"];
    expect([operation isCancelled]).to.equal(YES);
}

- (void)testCancellationByPathMatch
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"/object_manager/1234/cancel" relativeToURL:self.objectManager.HTTPClient.baseURL]];
    RKObjectRequestOperation *operation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:self.objectManager.responseDescriptors];
    [_objectManager enqueueObjectRequestOperation:operation];
    [_objectManager cancelAllObjectRequestOperationsWithMethod:RKRequestMethodGET matchingPathPattern:@"/object_manager/:objectID/cancel"];
    expect([operation isCancelled]).to.equal(YES);
}

- (void)testCancellationFailsForMismatchedMethod
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"/object_manager/cancel" relativeToURL:self.objectManager.HTTPClient.baseURL]];
    RKObjectRequestOperation *operation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:self.objectManager.responseDescriptors];
    [_objectManager enqueueObjectRequestOperation:operation];
    [_objectManager cancelAllObjectRequestOperationsWithMethod:RKRequestMethodPOST matchingPathPattern:@"/object_manager/cancel"];
    expect([operation isCancelled]).to.equal(NO);
}

- (void)testCancellationFailsForMismatchedPath
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"/object_manager/cancel" relativeToURL:self.objectManager.HTTPClient.baseURL]];
    RKObjectRequestOperation *operation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:self.objectManager.responseDescriptors];
    [_objectManager enqueueObjectRequestOperation:operation];
    [_objectManager cancelAllObjectRequestOperationsWithMethod:RKRequestMethodGET matchingPathPattern:@"/wrong"];
    expect([operation isCancelled]).to.equal(NO);
}

- (void)testCancellationByPathMatchForBaseURLWithPath
{
    self.objectManager = [RKObjectManager managerWithBaseURL:[NSURL URLWithString:@"http://localhost:4567/object_manager/"]];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:4567/object_manager/1234/cancel"]];
    RKObjectRequestOperation *operation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:self.objectManager.responseDescriptors];
    [_objectManager enqueueObjectRequestOperation:operation];
    [_objectManager cancelAllObjectRequestOperationsWithMethod:RKRequestMethodGET matchingPathPattern:@":objectID/cancel"];
    expect([operation isCancelled]).to.equal(YES);
}

- (void)testCancellationOfMultipartRequestByPath
{
    self.objectManager = [RKObjectManager managerWithBaseURL:[NSURL URLWithString:@"http://localhost:4567/object_manager/"]];
    RKTestUser *testUser = [RKTestUser new];
    NSMutableURLRequest *request = [self.objectManager multipartFormRequestWithObject:testUser method:RKRequestMethodPOST path:@"path" parameters:nil constructingBodyWithBlock:^(id<AFRKMultipartFormData> formData) {
        [formData appendPartWithFormData:[@"testing" dataUsingEncoding:NSUTF8StringEncoding] name:@"part"];
    }];
    RKObjectRequestOperation *operation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:self.objectManager.responseDescriptors];
    [_objectManager enqueueObjectRequestOperation:operation];
    [_objectManager cancelAllObjectRequestOperationsWithMethod:RKRequestMethodPOST matchingPathPattern:@"path"];
    expect([operation isCancelled]).to.equal(YES);
}

- (void)testEnqueuedObjectRequestOperationByExactMethodAndPath
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"/object_manager/cancel" relativeToURL:self.objectManager.HTTPClient.baseURL]];
    RKObjectRequestOperation *operation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:self.objectManager.responseDescriptors];
    [_objectManager enqueueObjectRequestOperation:operation];
    expect([[_objectManager enqueuedObjectRequestOperationsWithMethod:RKRequestMethodGET matchingPathPattern:@"/object_manager/cancel"] count]).to.equal(1);
}

- (void)testEnqueuedObjectRequestOperationByMultipleExactMethodAndPath
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"/object_manager/cancel" relativeToURL:self.objectManager.HTTPClient.baseURL]];
    RKObjectRequestOperation *operation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:self.objectManager.responseDescriptors];
    RKObjectRequestOperation *secondOperation = [operation copy];
    RKObjectRequestOperation *thirdOperation = [operation copy];
    [_objectManager enqueueObjectRequestOperation:operation];
    [_objectManager enqueueObjectRequestOperation:secondOperation];
    [_objectManager enqueueObjectRequestOperation:thirdOperation];
    expect([[_objectManager enqueuedObjectRequestOperationsWithMethod:RKRequestMethodGET matchingPathPattern:@"/object_manager/cancel"] count]).to.equal(3);
}

- (void)testEnqueuedObjectRequestOperationByPathMatch
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"/object_manager/1234/cancel" relativeToURL:self.objectManager.HTTPClient.baseURL]];
    RKObjectRequestOperation *operation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:self.objectManager.responseDescriptors];
    [_objectManager enqueueObjectRequestOperation:operation];
    expect([[_objectManager enqueuedObjectRequestOperationsWithMethod:RKRequestMethodGET matchingPathPattern:@"/object_manager/:objectID/cancel"] count]).to.equal(1);
}

- (void)testEnqueuedObjectRequestOperationFailsForMismatchedMethod
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"/object_manager/cancel" relativeToURL:self.objectManager.HTTPClient.baseURL]];
    RKObjectRequestOperation *operation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:self.objectManager.responseDescriptors];
    [_objectManager enqueueObjectRequestOperation:operation];
    expect([[_objectManager enqueuedObjectRequestOperationsWithMethod:RKRequestMethodGET matchingPathPattern:@"/wrong"] count]).to.equal(0);
}

- (void)testEnqueuedObjectRequestOperationFailsForMismatchedPath
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"/object_manager/cancel" relativeToURL:self.objectManager.HTTPClient.baseURL]];
    RKObjectRequestOperation *operation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:self.objectManager.responseDescriptors];
    [_objectManager enqueueObjectRequestOperation:operation];
    expect([[_objectManager enqueuedObjectRequestOperationsWithMethod:RKRequestMethodGET matchingPathPattern:@"/wrong"] count]).to.equal(0);
}

- (void)testEnqueuedObjectRequestOperationByPathMatchForBaseURLWithPath
{
    self.objectManager = [RKObjectManager managerWithBaseURL:[NSURL URLWithString:@"http://localhost:4567/object_manager/"]];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:4567/object_manager/1234/cancel"]];
    RKObjectRequestOperation *operation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:self.objectManager.responseDescriptors];
    [_objectManager enqueueObjectRequestOperation:operation];
    expect([[_objectManager enqueuedObjectRequestOperationsWithMethod:RKRequestMethodGET matchingPathPattern:@":objectID/cancel"] count]).to.equal(1);
}

- (void)testEnqueuedObjectRequestOperationByMultipleBitmaskMethodAndPath
{
    NSURLRequest *request1 = [NSURLRequest requestWithURL:[NSURL URLWithString:@"/object_manager/cancel" relativeToURL:self.objectManager.HTTPClient.baseURL]];
    NSMutableURLRequest *request2 = [request1 mutableCopy];
    request2.HTTPMethod = @"POST";
    NSMutableURLRequest *request3 = [request1 mutableCopy];
    request3.HTTPMethod = @"DELETE";
    RKObjectRequestOperation *operation = [[RKObjectRequestOperation alloc] initWithRequest:request1 responseDescriptors:self.objectManager.responseDescriptors];
    
    RKObjectRequestOperation *secondOperation = [[RKObjectRequestOperation alloc] initWithRequest:request2 responseDescriptors:self.objectManager.responseDescriptors];
    RKObjectRequestOperation *thirdOperation = [[RKObjectRequestOperation alloc] initWithRequest:request3 responseDescriptors:self.objectManager.responseDescriptors];
    [_objectManager enqueueObjectRequestOperation:operation];
    [_objectManager enqueueObjectRequestOperation:secondOperation];
    [_objectManager enqueueObjectRequestOperation:thirdOperation];
    NSArray *operations = [_objectManager enqueuedObjectRequestOperationsWithMethod:RKRequestMethodGET | RKRequestMethodPOST matchingPathPattern:@"/object_manager/cancel"];
    expect(operations).to.haveCountOf(2);
    expect(operations).to.contain(operation);
    expect(operations).to.contain(secondOperation);
}

- (void)testRegistrationOfHTTPRequestOperationClass
{
    RKObjectManager *manager = [RKObjectManager managerWithBaseURL:[NSURL URLWithString:@"http://restkit.org"]];
    [manager registerRequestOperationClass:[RKTestHTTPRequestOperation class]];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"/test" relativeToURL:manager.baseURL]];
    RKObjectRequestOperation *operation = [manager objectRequestOperationWithRequest:request success:nil failure:nil];
    expect(operation.HTTPRequestOperation).to.beKindOf([RKTestHTTPRequestOperation class]);
}

- (void)testSettingNilHTTPRequestOperationClassRestoresDefaultHTTPOperationClass
{
    RKObjectManager *manager = [RKObjectManager managerWithBaseURL:[NSURL URLWithString:@"http://restkit.org"]];
    [manager registerRequestOperationClass:[RKTestHTTPRequestOperation class]];
    [manager unregisterRequestOperationClass:[RKTestHTTPRequestOperation class]];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"/test" relativeToURL:manager.baseURL]];
    RKObjectRequestOperation *operation = [manager objectRequestOperationWithRequest:request success:nil failure:nil];
    expect(operation.HTTPRequestOperation).to.beKindOf([RKHTTPRequestOperation class]);
}

- (void)testShouldLoadAHuman
{
    __block RKObjectRequestOperation *requestOperation = nil;
    [self.objectManager getObjectsAtPath:@"/JSON/humans/1.json" parameters:nil success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
        requestOperation = operation;
    } failure:nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        expect(requestOperation.error).to.beNil();
        expect([requestOperation.mappingResult array]).notTo.beEmpty();
        RKHuman *blake = (RKHuman *)[requestOperation.mappingResult array][0];
        expect(blake.name).to.equal(@"Blake Watters");
    });
}

- (void)testShouldLoadAllHumans
{
    __block RKObjectRequestOperation *requestOperation = nil;
    [_objectManager getObjectsAtPath:@"/JSON/humans/all.json" parameters:nil success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
        requestOperation = operation;
    } failure:nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *humans = [requestOperation.mappingResult array];
        expect(humans).to.haveCountOf(2);
        expect(humans[0]).to.beInstanceOf([RKHuman class]);
    });
}

- (void)testThatAttemptingToAddARequestDescriptorThatOverlapsAnExistingEntryGeneratesAnError
{
    RKObjectMapping *mapping = [RKObjectMapping requestMapping];
    RKRequestDescriptor *requestDesriptor1 = [RKRequestDescriptor requestDescriptorWithMapping:mapping objectClass:[RKCat class] rootKeyPath:nil method:RKRequestMethodAny];
    RKRequestDescriptor *requestDesriptor2 = [RKRequestDescriptor requestDescriptorWithMapping:mapping objectClass:[RKCat class] rootKeyPath:@"cat" method:RKRequestMethodAny];
    RKObjectManager *objectManager = [RKTestFactory objectManager];
    [objectManager addRequestDescriptor:requestDesriptor1];
    
    NSException *caughtException = nil;
    @try {
        [objectManager addRequestDescriptor:requestDesriptor2];
    }
    @catch (NSException *exception) {
        caughtException = exception;
    }
    @finally {
        expect(caughtException).notTo.beNil();
    }
}

- (void)testThatRegisteringARequestDescriptorForASubclassSecondWillMatchAppropriately
{
    RKObjectMapping *mapping1 = [RKObjectMapping requestMapping];
    [mapping1 addAttributeMappingsFromArray:@[ @"name" ]];
    RKObjectMapping *mapping2 = [RKObjectMapping requestMapping];
    [mapping2 addAttributeMappingsFromArray:@[ @"age" ]];
    
    RKRequestDescriptor *requestDesriptor1 = [RKRequestDescriptor requestDescriptorWithMapping:mapping1 objectClass:[RKObjectMapperTestModel class] rootKeyPath:nil method:RKRequestMethodAny];
    RKRequestDescriptor *requestDesriptor2 = [RKRequestDescriptor requestDescriptorWithMapping:mapping2 objectClass:[RKSubclassedTestModel class] rootKeyPath:@"subclassed" method:RKRequestMethodAny];
    RKObjectManager *objectManager = [RKTestFactory objectManager];
    objectManager.requestSerializationMIMEType = RKMIMETypeJSON;
    [objectManager addRequestDescriptor:requestDesriptor1];
    [objectManager addRequestDescriptor:requestDesriptor2];
    
    RKSubclassedTestModel *model = [RKSubclassedTestModel new];
    model.name = @"Blake";
    model.age = @30;
    NSURLRequest *request = [objectManager requestWithObject:model method:RKRequestMethodPOST path:@"/path" parameters:nil];
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil];
    expect(dictionary).to.equal(@{ @"subclassed": @{ @"age": @(30) } });
}

- (void)testChangingHTTPClient
{
    RKObjectManager *manager = [RKObjectManager managerWithBaseURL:[NSURL URLWithString:@"http://restkit.org"]];
    manager.HTTPClient = [AFRKHTTPClient clientWithBaseURL:[NSURL URLWithString:@"http://google.com/"]];
    expect([manager.baseURL absoluteString]).to.equal(@"http://google.com/");
}

- (void)testPostingOneObjectAndGettingResponseMatchingAnotherClass
{
    RKObjectManager *manager = [RKObjectManager managerWithBaseURL:[RKTestFactory baseURL]];
    RKObjectMapping *userMapping = [RKObjectMapping mappingForClass:[RKTestUser class]];
    [userMapping addAttributeMappingsFromDictionary:@{ @"fullname": @"name" }];
    RKObjectMapping *metaMapping = [RKObjectMapping mappingForClass:[NSMutableDictionary class]];
    [metaMapping addAttributeMappingsFromArray:@[ @"status", @"version" ]];
    RKResponseDescriptor *metaResponseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:metaMapping method:RKRequestMethodAny pathPattern:nil keyPath:@"meta" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    
    [manager addResponseDescriptorsFromArray:@[ metaResponseDescriptor ]];
    RKTestUser *user = [RKTestUser new];
    RKObjectRequestOperation *requestOperation = [manager appropriateObjectRequestOperationWithObject:user method:RKRequestMethodPOST path:@"/ComplexUser" parameters:nil];
    [requestOperation start];
    [requestOperation waitUntilFinished];
    
    expect(requestOperation.error).to.beNil();
    expect(requestOperation.mappingResult).notTo.beNil();
    expect([requestOperation.mappingResult array]).to.haveCountOf(1);
    NSDictionary *expectedObject = @{ @"status": @"ok", @"version": @"0.3" };
    expect([requestOperation.mappingResult firstObject]).to.equal(expectedObject);
}

- (void)testPostingOneObjectAndGettingResponseMatchingMultipleDescriptors
{
    RKObjectManager *manager = [RKObjectManager managerWithBaseURL:[RKTestFactory baseURL]];
    RKObjectMapping *userMapping = [RKObjectMapping mappingForClass:[RKTestUser class]];
    [userMapping addAttributeMappingsFromDictionary:@{ @"fullname": @"name" }];
    RKResponseDescriptor *userResponseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:userMapping method:RKRequestMethodAny pathPattern:nil keyPath:@"data.STUser" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    RKObjectMapping *metaMapping = [RKObjectMapping mappingForClass:[NSMutableDictionary class]];
    [metaMapping addAttributeMappingsFromArray:@[ @"status", @"version" ]];    
    RKResponseDescriptor *metaResponseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:metaMapping method:RKRequestMethodAny pathPattern:nil keyPath:@"meta" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    
    [manager addResponseDescriptorsFromArray:@[ userResponseDescriptor, metaResponseDescriptor ]];
    RKTestUser *user = [RKTestUser new];
    RKObjectRequestOperation *requestOperation = [manager appropriateObjectRequestOperationWithObject:user method:RKRequestMethodPOST path:@"/ComplexUser" parameters:nil];
    [requestOperation start];
    [requestOperation waitUntilFinished];
    
    expect(requestOperation.mappingResult).notTo.beNil();
    expect([requestOperation.mappingResult array]).to.haveCountOf(2);
}

- (void)testCreatingAnObjectRequestWithoutARequestDescriptorButWithParametersSetsTheRequestBody
{
    RKTestUser *user = [RKTestUser new];
    user.name = @"Blake";
    user.emailAddress = @"blake@restkit.org";
    
    RKObjectManager *objectManager = [RKTestFactory objectManager];
    objectManager.requestSerializationMIMEType = RKMIMETypeJSON;
    
    NSURLRequest *request = [objectManager requestWithObject:user method:RKRequestMethodPOST path:@"/path" parameters:@{ @"this": @"that" }];
    id body = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil];
    NSDictionary *expected = @{ @"this": @"that" };
    expect(body).to.equal(expected);
}

- (void)testPostingAnArrayOfObjectsWhereNoneHaveARootKeyPath
{
    RKObjectMapping *firstRequestMapping = [RKObjectMapping requestMapping];
    [firstRequestMapping addAttributeMappingsFromArray:@[ @"name", @"emailAddress" ]];
    RKObjectMapping *secondRequestMapping = [RKObjectMapping requestMapping];
    [secondRequestMapping addAttributeMappingsFromArray:@[ @"city", @"state" ]];

    RKRequestDescriptor *firstRequestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:firstRequestMapping objectClass:[RKTestUser class] rootKeyPath:nil method:RKRequestMethodAny];
    RKRequestDescriptor *secondRequestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:secondRequestMapping objectClass:[RKTestAddress class] rootKeyPath:nil method:RKRequestMethodAny];

    RKTestUser *user = [RKTestUser new];
    user.name = @"Blake";
    user.emailAddress = @"blake@restkit.org";

    RKTestAddress *address = [RKTestAddress new];
    address.city = @"New York City";
    address.state = @"New York";

    RKObjectManager *objectManager = [RKTestFactory objectManager];
    objectManager.requestSerializationMIMEType = RKMIMETypeJSON;
    [objectManager addRequestDescriptor:firstRequestDescriptor];
    [objectManager addRequestDescriptor:secondRequestDescriptor];

    NSArray *arrayOfObjects = @[ user, address ];
    NSURLRequest *request = [objectManager requestWithObject:arrayOfObjects method:RKRequestMethodPOST path:@"/path" parameters:nil];
    NSArray *array = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil];
    NSArray *expected = @[ @{ @"name": @"Blake", @"emailAddress": @"blake@restkit.org" }, @{ @"city": @"New York City", @"state": @"New York" } ];
    expect(array).to.equal(expected);
}

- (void)testPostingAnArrayOfObjectsWhereAllObjectsHaveAnOverlappingRootKeyPath
{
    RKObjectMapping *firstRequestMapping = [RKObjectMapping requestMapping];
    [firstRequestMapping addAttributeMappingsFromArray:@[ @"name", @"emailAddress" ]];
    RKObjectMapping *secondRequestMapping = [RKObjectMapping requestMapping];
    [secondRequestMapping addAttributeMappingsFromArray:@[ @"city", @"state" ]];

    RKRequestDescriptor *firstRequestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:firstRequestMapping objectClass:[RKTestUser class] rootKeyPath:@"whatever" method:RKRequestMethodAny];
    RKRequestDescriptor *secondRequestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:secondRequestMapping objectClass:[RKTestAddress class] rootKeyPath:@"whatever" method:RKRequestMethodAny];

    RKTestUser *user = [RKTestUser new];
    user.name = @"Blake";
    user.emailAddress = @"blake@restkit.org";

    RKTestAddress *address = [RKTestAddress new];
    address.city = @"New York City";
    address.state = @"New York";

    RKObjectManager *objectManager = [RKTestFactory objectManager];
    objectManager.requestSerializationMIMEType = RKMIMETypeJSON;
    [objectManager addRequestDescriptor:firstRequestDescriptor];
    [objectManager addRequestDescriptor:secondRequestDescriptor];

    NSArray *arrayOfObjects = @[ user, address ];
    NSURLRequest *request = [objectManager requestWithObject:arrayOfObjects method:RKRequestMethodPOST path:@"/path" parameters:nil];
    NSArray *array = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil];
    NSDictionary *expected = @{ @"whatever": @[ @{ @"name": @"Blake", @"emailAddress": @"blake@restkit.org" }, @{ @"city": @"New York City", @"state": @"New York" } ] };
    expect(array).to.equal(expected);
}

- (void)testPostingAnArrayOfObjectsWithMixedRootKeyPath
{
    RKObjectMapping *firstRequestMapping = [RKObjectMapping requestMapping];
    [firstRequestMapping addAttributeMappingsFromArray:@[ @"name", @"emailAddress" ]];
    RKObjectMapping *secondRequestMapping = [RKObjectMapping requestMapping];
    [secondRequestMapping addAttributeMappingsFromArray:@[ @"city", @"state" ]];

    RKRequestDescriptor *firstRequestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:firstRequestMapping objectClass:[RKTestUser class] rootKeyPath:@"this" method:RKRequestMethodAny];
    RKRequestDescriptor *secondRequestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:secondRequestMapping objectClass:[RKTestAddress class] rootKeyPath:@"that" method:RKRequestMethodAny];

    RKTestUser *user = [RKTestUser new];
    user.name = @"Blake";
    user.emailAddress = @"blake@restkit.org";

    RKTestAddress *address = [RKTestAddress new];
    address.city = @"New York City";
    address.state = @"New York";

    RKObjectManager *objectManager = [RKTestFactory objectManager];
    objectManager.requestSerializationMIMEType = RKMIMETypeJSON;
    [objectManager addRequestDescriptor:firstRequestDescriptor];
    [objectManager addRequestDescriptor:secondRequestDescriptor];

    NSArray *arrayOfObjects = @[ user, address ];
    NSURLRequest *request = [objectManager requestWithObject:arrayOfObjects method:RKRequestMethodPOST path:@"/path" parameters:nil];
    NSArray *array = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil];
    NSDictionary *expected = @{ @"this": @{ @"name": @"Blake", @"emailAddress": @"blake@restkit.org" }, @"that": @{ @"city": @"New York City", @"state": @"New York" } };
    expect(array).to.equal(expected);
}

- (void)testPostingAnArrayOfObjectsWithNonNilRootKeyPathAndExtraParameters
{
    RKObjectMapping *firstRequestMapping = [RKObjectMapping requestMapping];
    [firstRequestMapping addAttributeMappingsFromArray:@[ @"name", @"emailAddress" ]];
    RKObjectMapping *secondRequestMapping = [RKObjectMapping requestMapping];
    [secondRequestMapping addAttributeMappingsFromArray:@[ @"city", @"state" ]];

    RKRequestDescriptor *firstRequestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:firstRequestMapping objectClass:[RKTestUser class] rootKeyPath:@"this" method:RKRequestMethodAny];
    RKRequestDescriptor *secondRequestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:secondRequestMapping objectClass:[RKTestAddress class] rootKeyPath:@"that" method:RKRequestMethodAny];

    RKTestUser *user = [RKTestUser new];
    user.name = @"Blake";
    user.emailAddress = @"blake@restkit.org";

    RKTestAddress *address = [RKTestAddress new];
    address.city = @"New York City";
    address.state = @"New York";

    RKObjectManager *objectManager = [RKTestFactory objectManager];
    objectManager.requestSerializationMIMEType = RKMIMETypeJSON;
    [objectManager addRequestDescriptor:firstRequestDescriptor];
    [objectManager addRequestDescriptor:secondRequestDescriptor];

    NSArray *arrayOfObjects = @[ user, address ];
    NSURLRequest *request = [objectManager requestWithObject:arrayOfObjects method:RKRequestMethodPOST path:@"/path" parameters:@{ @"extra": @"info" }];
    NSArray *array = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil];
    NSDictionary *expected = @{ @"this": @{ @"name": @"Blake", @"emailAddress": @"blake@restkit.org" }, @"that": @{ @"city": @"New York City", @"state": @"New York" }, @"extra": @"info" };
    expect(array).to.equal(expected);
}

- (void)testPostingAnArrayWithSingleObjectGeneratesAnArray
{
    RKObjectMapping *firstRequestMapping = [RKObjectMapping requestMapping];
    [firstRequestMapping addAttributeMappingsFromArray:@[ @"name", @"emailAddress" ]];
    
    RKRequestDescriptor *firstRequestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:firstRequestMapping objectClass:[RKTestUser class] rootKeyPath:@"whatever" method:RKRequestMethodAny];
    
    RKTestUser *user = [RKTestUser new];
    user.name = @"Blake";
    user.emailAddress = @"blake@restkit.org";
    
    RKObjectManager *objectManager = [RKTestFactory objectManager];
    objectManager.requestSerializationMIMEType = RKMIMETypeJSON;
    [objectManager addRequestDescriptor:firstRequestDescriptor];
    
    NSArray *arrayOfObjects = @[ user ];
    NSURLRequest *request = [objectManager requestWithObject:arrayOfObjects method:RKRequestMethodPOST path:@"/path" parameters:nil];
    NSArray *array = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil];
    NSDictionary *expected = @{ @"whatever": @[ @{ @"name": @"Blake", @"emailAddress": @"blake@restkit.org" } ] };
    expect(array).to.equal(expected);
}

- (void)testPostingNilObjectWithExtraParameters
{
    RKObjectMapping *firstRequestMapping = [RKObjectMapping requestMapping];
    [firstRequestMapping addAttributeMappingsFromArray:@[ @"name", @"emailAddress" ]];
    RKObjectMapping *secondRequestMapping = [RKObjectMapping requestMapping];
    [secondRequestMapping addAttributeMappingsFromArray:@[ @"city", @"state" ]];

    RKRequestDescriptor *firstRequestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:firstRequestMapping objectClass:[RKTestUser class] rootKeyPath:@"this" method:RKRequestMethodAny];
    RKRequestDescriptor *secondRequestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:secondRequestMapping objectClass:[RKTestAddress class] rootKeyPath:@"that" method:RKRequestMethodAny];

    RKObjectManager *objectManager = [RKTestFactory objectManager];
    objectManager.requestSerializationMIMEType = RKMIMETypeJSON;
    [objectManager addRequestDescriptor:firstRequestDescriptor];
    [objectManager addRequestDescriptor:secondRequestDescriptor];

    NSDictionary *parameters = @{ @"this": @"that" };
    NSURLRequest *request = [objectManager requestWithObject:nil method:RKRequestMethodPOST path:@"/path" parameters:parameters];
    NSArray *array = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil];
    expect(array).to.equal(parameters);
}

- (void)testAttemptingToPostAnArrayOfObjectsWithMixtureOfNilAndNonNilRootKeyPathsRaisesError
{
    RKObjectMapping *firstRequestMapping = [RKObjectMapping requestMapping];
    [firstRequestMapping addAttributeMappingsFromArray:@[ @"name", @"emailAddress" ]];
    RKObjectMapping *secondRequestMapping = [RKObjectMapping requestMapping];
    [secondRequestMapping addAttributeMappingsFromArray:@[ @"city", @"state" ]];

    RKRequestDescriptor *firstRequestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:firstRequestMapping objectClass:[RKTestUser class] rootKeyPath:nil method:RKRequestMethodAny];
    RKRequestDescriptor *secondRequestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:secondRequestMapping objectClass:[RKTestAddress class] rootKeyPath:nil method:RKRequestMethodAny];

    RKTestUser *user = [RKTestUser new];
    user.name = @"Blake";
    user.emailAddress = @"blake@restkit.org";

    RKTestAddress *address = [RKTestAddress new];
    address.city = @"New York City";
    address.state = @"New York";

    RKObjectManager *objectManager = [RKTestFactory objectManager];
    objectManager.requestSerializationMIMEType = RKMIMETypeJSON;
    [objectManager addRequestDescriptor:firstRequestDescriptor];
    [objectManager addRequestDescriptor:secondRequestDescriptor];

    NSArray *arrayOfObjects = @[ user, address ];
    NSException *caughtException = nil;
    @try {
        NSURLRequest __unused *request = [objectManager requestWithObject:arrayOfObjects method:RKRequestMethodPOST path:@"/path" parameters:@{ @"name": @"Foo" }];
    }
    @catch (NSException *exception) {
        caughtException = exception;
        expect([exception name]).to.equal(NSInvalidArgumentException);
        expect([exception reason]).to.equal(@"Cannot merge parameters with array of object representations serialized with a nil root key path.");
    }
    expect(caughtException).notTo.beNil();
}

- (void)testThatAttemptingToPostObjectsWithAMixtureOfNilAndNonNilRootKeyPathsRaisesError
{
    RKObjectMapping *firstRequestMapping = [RKObjectMapping requestMapping];
    [firstRequestMapping addAttributeMappingsFromArray:@[ @"name", @"emailAddress" ]];
    RKObjectMapping *secondRequestMapping = [RKObjectMapping requestMapping];
    [secondRequestMapping addAttributeMappingsFromArray:@[ @"city", @"state" ]];

    RKRequestDescriptor *firstRequestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:firstRequestMapping objectClass:[RKTestUser class] rootKeyPath:@"bang" method:RKRequestMethodAny];
    RKRequestDescriptor *secondRequestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:secondRequestMapping objectClass:[RKTestAddress class] rootKeyPath:nil method:RKRequestMethodAny];

    RKTestUser *user = [RKTestUser new];
    user.name = @"Blake";
    user.emailAddress = @"blake@restkit.org";

    RKTestAddress *address = [RKTestAddress new];
    address.city = @"New York City";
    address.state = @"New York";

    RKObjectManager *objectManager = [RKTestFactory objectManager];
    objectManager.requestSerializationMIMEType = RKMIMETypeJSON;
    [objectManager addRequestDescriptor:firstRequestDescriptor];
    [objectManager addRequestDescriptor:secondRequestDescriptor];

    NSArray *arrayOfObjects = @[ user, address ];
    NSException *caughtException = nil;
    @try {
        NSURLRequest __unused *request = [objectManager requestWithObject:arrayOfObjects method:RKRequestMethodPOST path:@"/path" parameters:nil];
    }
    @catch (NSException *exception) {
        caughtException = exception;
        expect([exception name]).to.equal(NSInvalidArgumentException);
        expect([exception reason]).to.equal(@"Invalid request descriptor configuration: The request descriptors specify that multiple objects be serialized at incompatible key paths. Cannot serialize objects at the `nil` root key path in the same request as objects with a non-nil root key path. Please check your request descriptors and try again.");
    }
    expect(caughtException).notTo.beNil();
}

#pragma mark - Object Request Operation Registration

- (void)testRegistrationOfObjectRequestOperationClass
{
    RKObjectManager *manager = [RKObjectManager managerWithBaseURL:[NSURL URLWithString:@"http://restkit.org"]];
    [manager registerRequestOperationClass:[RKTestObjectRequestOperation class]];
    NSURL *URL = [NSURL URLWithString:@"/match" relativeToURL:manager.baseURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    RKObjectRequestOperation *operation = [manager objectRequestOperationWithRequest:request success:nil failure:nil];
    expect(operation).to.beInstanceOf([RKTestObjectRequestOperation class]);
}

- (void)testRegistrationOfObjectRequestOperationClassRespectsSubclassDecisionToProcessRequest
{
    RKObjectManager *manager = [RKObjectManager managerWithBaseURL:[NSURL URLWithString:@"http://restkit.org"]];
    [manager registerRequestOperationClass:[RKTestObjectRequestOperation class]];
    NSURL *URL = [NSURL URLWithString:@"/mismatch" relativeToURL:manager.baseURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    RKObjectRequestOperation *operation = [manager objectRequestOperationWithRequest:request success:nil failure:nil];
    expect(operation).notTo.beInstanceOf([RKTestObjectRequestOperation class]);
    expect(operation).to.beInstanceOf([RKObjectRequestOperation class]);
}

- (void)testPathMatchingForMultipartRequest
{
    RKObjectManager *objectManager = [RKTestFactory objectManager];
    NSString *path = @"/api/upload/";
    
    NSData *blakePng = [RKTestFixture dataWithContentsOfFixture:@"blake.png"];
    NSMutableURLRequest *request = [objectManager multipartFormRequestWithObject:nil method:RKRequestMethodPOST path:path parameters:nil constructingBodyWithBlock:^(id<AFRKMultipartFormData> formData) {
        [formData appendPartWithFileData:blakePng
                                    name:@"file"
                                fileName:@"blake.png"
                                mimeType:@"image/png"];
    }];
    
    RKObjectMapping *mapping = [RKObjectMapping mappingForClass:[RKTestUser class]];
    [mapping addAttributeMappingsFromArray:@[ @"name" ]];
    RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:mapping method:RKRequestMethodAny pathPattern:path keyPath:nil statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    [objectManager addResponseDescriptor:responseDescriptor];
    
    RKObjectRequestOperation * operation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:@[ responseDescriptor ]];
    [[RKObjectManager sharedManager] enqueueObjectRequestOperation:operation];
    
    expect([operation isFinished]).will.equal(YES);
    expect(operation.error).to.beNil();
    RKTestUser *user = [operation.mappingResult firstObject];
    expect(user.name).to.equal(@"Blake");
}

- (void)testMappingErrorsFromFiveHundredStatusCodeRange
{
    RKObjectManager *objectManager = [RKObjectManager managerWithBaseURL:[RKTestFactory baseURL]];    
    NSIndexSet *statusCodes = RKStatusCodeIndexSetForClass(RKStatusCodeClassServerError);
    RKObjectMapping *errorResponseMapping = [RKObjectMapping mappingForClass:[RKErrorMessage class]];
    [errorResponseMapping addPropertyMapping:[RKAttributeMapping attributeMappingFromKeyPath:nil toKeyPath:@"errorMessage"]];
    [objectManager addResponseDescriptor:[RKResponseDescriptor responseDescriptorWithMapping:errorResponseMapping method:RKRequestMethodAny pathPattern:nil keyPath:@"errors" statusCodes:statusCodes]];
    
    __block NSError *error = nil;
    [objectManager getObjectsAtPath:@"/fail" parameters:nil success:nil failure:^(RKObjectRequestOperation *operation, NSError *blockError) {
        error = blockError;
    }];
    
    expect(error).willNot.beNil();
    expect([error localizedDescription]).to.equal(@"error1, error2");
}

- (void)testMappingMetadataParameterForNamedRoute
{
    RKObjectManager *objectManager = [RKObjectManager managerWithBaseURL:[RKTestFactory baseURL]];
    RKObjectMapping *userMapping = [RKObjectMapping mappingForClass:[RKTestUser class]];
    [userMapping addAttributeMappingsFromDictionary:@{ @"name": @"name", @"@metadata.routing.parameters.userID": @"position" }];    
    [objectManager.router.routeSet addRoute:[RKRoute routeWithName:@"load_human" pathPattern:@"/JSON/humans/:userID\\.json" method:RKRequestMethodGET]];
    RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:userMapping method:RKRequestMethodAny pathPattern:@"/JSON/humans/:userID\\.json" keyPath:@"human" statusCodes:[NSIndexSet indexSetWithIndex:200]];
    [objectManager addResponseDescriptor:responseDescriptor];
    
    RKTestUser *user = [RKTestUser new];
    user.userID = @1;
    __block RKMappingResult *mappingResult = nil;
    [objectManager getObjectsAtPathForRouteNamed:@"load_human" object:user parameters:nil success:^(RKObjectRequestOperation *operation, RKMappingResult *blockMappingResult) {
        mappingResult = blockMappingResult;
    } failure:nil];
    
    expect(mappingResult).willNot.beNil();
    RKTestUser *anotherUser = [mappingResult firstObject];
    expect(anotherUser).notTo.equal(user);
    expect(anotherUser.name).to.equal(@"Blake Watters");
    expect(anotherUser.position).to.equal(@1);
}

- (void)testMappingMetadataQueryParametersByPath
{
    RKObjectManager *objectManager = [RKObjectManager managerWithBaseURL:[RKTestFactory baseURL]];
    RKObjectMapping *userMapping = [RKObjectMapping mappingForClass:[RKTestUser class]];
    [userMapping addAttributeMappingsFromDictionary:@{ @"name": @"name", @"@metadata.query.parameters.userID": @"position" }];
    RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:userMapping method:RKRequestMethodAny pathPattern:@"/JSON/humans/:userID\\.json" keyPath:@"human" statusCodes:[NSIndexSet indexSetWithIndex:200]];
    [objectManager addResponseDescriptor:responseDescriptor];
    
    __block RKMappingResult *mappingResult = nil;
    [objectManager getObjectsAtPath:@"/JSON/humans/1.json" parameters:@{ @"userID" : @"12" } success:^(RKObjectRequestOperation *operation, RKMappingResult *blockMappingResult) {
        mappingResult = blockMappingResult;
    } failure:nil];
    
    expect(mappingResult).willNot.beNil();
    RKTestUser *user = [mappingResult firstObject];
    expect(user.name).to.equal(@"Blake Watters");
    expect(user.position).to.equal(@12);
}

- (void)testMappingMetadataByPathNoneSupplied
{
    RKObjectManager *objectManager = [RKObjectManager managerWithBaseURL:[RKTestFactory baseURL]];
    RKObjectMapping *userMapping = [RKObjectMapping mappingForClass:[RKTestUser class]];
    [userMapping addAttributeMappingsFromDictionary:@{ @"name": @"name", @"@metadata.query.parameters.userID": @"position" }];
    RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:userMapping method:RKRequestMethodAny pathPattern:@"/JSON/humans/:userID\\.json" keyPath:@"human" statusCodes:[NSIndexSet indexSetWithIndex:200]];
    [objectManager addResponseDescriptor:responseDescriptor];
    
    __block RKMappingResult *mappingResult = nil;
    [objectManager getObjectsAtPath:@"/JSON/humans/1.json" parameters:nil success:^(RKObjectRequestOperation *operation, RKMappingResult *blockMappingResult) {
        mappingResult = blockMappingResult;
    } failure:nil];
    
    expect(mappingResult).willNot.beNil();
    RKTestUser *user = [mappingResult firstObject];
    expect(user.name).to.equal(@"Blake Watters");
    expect(user.position).to.beNil;
}

- (void)testMappingMetadataQueryParametersByRoute
{
    RKObjectManager *objectManager = [RKObjectManager managerWithBaseURL:[RKTestFactory baseURL]];
    RKObjectMapping *userMapping = [RKObjectMapping mappingForClass:[RKTestUser class]];
    [userMapping addAttributeMappingsFromDictionary:@{ @"name": @"name", @"@metadata.query.parameters.userID": @"position" }];
    [objectManager.router.routeSet addRoute:[RKRoute routeWithName:@"load_human" pathPattern:@"/JSON/humans/:userID\\.json" method:RKRequestMethodGET]];
    RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:userMapping method:RKRequestMethodAny pathPattern:@"/JSON/humans/:userID\\.json" keyPath:@"human" statusCodes:[NSIndexSet indexSetWithIndex:200]];
    [objectManager addResponseDescriptor:responseDescriptor];
    
    RKTestUser *user = [RKTestUser new];
    user.userID = @1;
    __block RKMappingResult *mappingResult = nil;
    [objectManager getObjectsAtPathForRouteNamed:@"load_human" object:user parameters:@{ @"userID" : @"12" } success:^(RKObjectRequestOperation *operation, RKMappingResult *blockMappingResult) {
        mappingResult = blockMappingResult;
    } failure:nil];
    
    expect(mappingResult).willNot.beNil();
    RKTestUser *anotherUser = [mappingResult firstObject];
    expect(anotherUser).notTo.equal(user);
    expect(anotherUser.name).to.equal(@"Blake Watters");
    expect(anotherUser.position).to.equal(@12);
}

- (void)testMappingMetadataQueryParametersByRouteNoneSupplied
{
    RKObjectManager *objectManager = [RKObjectManager managerWithBaseURL:[RKTestFactory baseURL]];
    RKObjectMapping *userMapping = [RKObjectMapping mappingForClass:[RKTestUser class]];
    [userMapping addAttributeMappingsFromDictionary:@{ @"name": @"name", @"@metadata.query.parameters.userID": @"position" }];
    [objectManager.router.routeSet addRoute:[RKRoute routeWithName:@"load_human" pathPattern:@"/JSON/humans/:userID\\.json" method:RKRequestMethodGET]];
    RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:userMapping method:RKRequestMethodAny pathPattern:@"/JSON/humans/:userID\\.json" keyPath:@"human" statusCodes:[NSIndexSet indexSetWithIndex:200]];
    [objectManager addResponseDescriptor:responseDescriptor];
    
    RKTestUser *user = [RKTestUser new];
    user.userID = @1;
    __block RKMappingResult *mappingResult = nil;
    [objectManager getObjectsAtPathForRouteNamed:@"load_human" object:user parameters:nil success:^(RKObjectRequestOperation *operation, RKMappingResult *blockMappingResult) {
        mappingResult = blockMappingResult;
    } failure:nil];
    
    expect(mappingResult).willNot.beNil();
    RKTestUser *anotherUser = [mappingResult firstObject];
    expect(anotherUser).notTo.equal(user);
    expect(anotherUser.name).to.equal(@"Blake Watters");
    expect(anotherUser.position).to.beNil;
}

- (void)testThatNoCrashOccursWhenLoadingNamedRouteWithNilObject
{
    RKObjectManager *objectManager = [RKObjectManager managerWithBaseURL:[RKTestFactory baseURL]];
    RKObjectMapping *userMapping = [RKObjectMapping mappingForClass:[RKTestUser class]];
    [objectManager.router.routeSet addRoute:[RKRoute routeWithName:@"named_route" pathPattern:@"/JSON/humans/1.json" method:RKRequestMethodGET]];
    RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:userMapping method:RKRequestMethodAny pathPattern:nil keyPath:@"human" statusCodes:[NSIndexSet indexSetWithIndex:200]];
    [objectManager addResponseDescriptor:responseDescriptor];
    
    __block RKMappingResult *mappingResult = nil;
    [objectManager getObjectsAtPathForRouteNamed:@"named_route" object:nil parameters:nil success:^(RKObjectRequestOperation *operation, RKMappingResult *blockMappingResult) {
        mappingResult = blockMappingResult;
    } failure:nil];
    
    expect(mappingResult).willNot.beNil();
}

- (void)testManagerUsesResponseDescriptorForMethod
{
    RKObjectMapping *mapping1 = [RKObjectMapping mappingForClass:[RKTestUser class]];
    [mapping1 addAttributeMappingsFromArray:@[ @"name" ]];
    RKObjectMapping *mapping2 = [RKObjectMapping mappingForClass:[RKTestUser class]];
    [mapping2 addAttributeMappingsFromArray:@[ @"weight" ]];
    
    RKResponseDescriptor *responseDescriptor1 = [RKResponseDescriptor responseDescriptorWithMapping:mapping1 method:RKRequestMethodPOST pathPattern:@"/user" keyPath:nil statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    RKResponseDescriptor *responseDescriptor2 = [RKResponseDescriptor responseDescriptorWithMapping:mapping2 method:RKRequestMethodGET pathPattern:@"/user" keyPath:nil statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    RKObjectManager *objectManager = [RKTestFactory objectManager];
    objectManager.requestSerializationMIMEType = RKMIMETypeJSON;
    [objectManager addResponseDescriptorsFromArray:@[responseDescriptor1, responseDescriptor2]];
    
    __block RKTestUser *human;
    [[RKTestFactory objectManager] getObject:nil path:@"/user" parameters:nil success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
        human = mappingResult.firstObject;
    } failure:^(RKObjectRequestOperation *operation, NSError *error) {
        
    }];
    expect(human.name).will.beNil();
    expect(human.weight).will.equal(@131.3);
}

- (void)testThatRequestDescriptorExactMethodMatchFavoredOverRKRequestMethodAny
{
    RKObjectMapping *mapping1 = [RKObjectMapping requestMapping];
    [mapping1 addAttributeMappingsFromArray:@[ @"name" ]];
    RKObjectMapping *mapping2 = [RKObjectMapping requestMapping];
    [mapping2 addAttributeMappingsFromArray:@[ @"age" ]];
    
    RKRequestDescriptor *requestDesriptor1 = [RKRequestDescriptor requestDescriptorWithMapping:mapping1 objectClass:[RKObjectMapperTestModel class] rootKeyPath:nil method:RKRequestMethodAny];
    RKRequestDescriptor *requestDesriptor2 = [RKRequestDescriptor requestDescriptorWithMapping:mapping2 objectClass:[RKObjectMapperTestModel class] rootKeyPath:nil method:RKRequestMethodPOST];
    RKObjectManager *objectManager = [RKTestFactory objectManager];
    objectManager.requestSerializationMIMEType = RKMIMETypeJSON;
    [objectManager addRequestDescriptor:requestDesriptor1];
    [objectManager addRequestDescriptor:requestDesriptor2];
    
    RKObjectMapperTestModel *model = [RKObjectMapperTestModel new];
    model.name = @"Blake";
    model.age = @30;
    NSURLRequest *request = [objectManager requestWithObject:model method:RKRequestMethodPOST path:@"/path" parameters:nil];
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil];
    expect(dictionary).to.equal(@{ @"age": @(30) });
}

- (void)testThatResponseDescriptorExactMethodMatchFavoredOverRKRequestMethodAny
{
    RKObjectMapping *mapping1 = [RKObjectMapping mappingForClass:[RKTestUser class]];
    [mapping1 addAttributeMappingsFromArray:@[ @"name" ]];
    RKObjectMapping *mapping2 = [RKObjectMapping mappingForClass:[RKTestUser class]];
    [mapping2 addAttributeMappingsFromArray:@[ @"weight" ]];
    
    RKResponseDescriptor *responseDescriptor2 = [RKResponseDescriptor responseDescriptorWithMapping:mapping2 method:RKRequestMethodGET pathPattern:@"/user" keyPath:nil statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    RKResponseDescriptor *responseDescriptor1 = [RKResponseDescriptor responseDescriptorWithMapping:mapping1 method:RKRequestMethodAny pathPattern:@"/user" keyPath:nil statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    RKObjectManager *objectManager = [RKTestFactory objectManager];
    objectManager.requestSerializationMIMEType = RKMIMETypeJSON;
    [objectManager addResponseDescriptorsFromArray:@[responseDescriptor1, responseDescriptor2]];
    
    __block RKTestUser *human;
    [[RKTestFactory objectManager] getObject:nil path:@"/user" parameters:nil success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
        human = mappingResult.firstObject;
    } failure:^(RKObjectRequestOperation *operation, NSError *error) {
        
    }];
    expect(human.name).will.beNil();
    expect(human.weight).will.equal(@131.3);
}

@end

@interface RKObjectManagerNonCoreDataTest: RKTestCase
@property (nonatomic, strong) RKObjectManager *objectManager;

@property (nonatomic, strong) RKResponseDescriptor *addressResponseDescriptor;
@property (nonatomic, strong) RKResponseDescriptor *coordinateResponseDescriptor;

@end

@implementation RKObjectManagerNonCoreDataTest

-(void)setUp{
    [RKTestFactory setUp];
    self.objectManager = [RKTestFactory objectManager];
    [RKObjectManager setSharedManager:self.objectManager];
    
    RKObjectMapping *addressMapping = [RKObjectMapping mappingForClass:[RKTestAddress class]];
    [addressMapping addAttributeMappingsFromArray:@[@"addressID", @"city", @"state", @"country"]];
    
    RKObjectMapping *coordinateMapping = [RKObjectMapping mappingForClass:[RKTestCoordinate class]];
    [coordinateMapping addAttributeMappingsFromArray:@[@""]];
    
    self.addressResponseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:addressMapping method:RKRequestMethodGET pathPattern:@"address" keyPath:@"address" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    self.coordinateResponseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:coordinateMapping method:RKRequestMethodPOST pathPattern:@"coordinate" keyPath:nil statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
 
    [self.objectManager.router.routeSet addRoute:[RKRoute routeWithClass:[RKTestCoordinate class] pathPattern:@"coordinate" method:RKRequestMethodPOST]];
    [self.objectManager addResponseDescriptorsFromArray:@[self.addressResponseDescriptor, self.coordinateResponseDescriptor]];
}

-(void)tearDown{
    [RKTestFactory tearDown];
}

-(void)testThatAppropriateObjectRequestOperationOnlyContainsResponseDescriptorsThatMatchObjectAndMethod{
    RKTestCoordinate *coordinate = [RKTestCoordinate new];
    RKObjectRequestOperation *operation = [self.objectManager appropriateObjectRequestOperationWithObject:coordinate method:RKRequestMethodPOST path:@"coordinate" parameters:nil];
    expect(operation.responseDescriptors.count).to.equal(1);
    expect(operation.responseDescriptors[0]).to.equal(self.coordinateResponseDescriptor);
}

-(void)testThatAppropriateObjectRequestOperationOnlyContainsResponseDescriptorsThatMatchPahtAndMethod{
    RKObjectRequestOperation *operation = [self.objectManager appropriateObjectRequestOperationWithObject:nil method:RKRequestMethodGET path:@"address" parameters:nil];
    expect(operation.responseDescriptors.count).to.equal(1);
    expect(operation.responseDescriptors[0]).to.equal(self.addressResponseDescriptor);
}


@end

RKRequestDescriptor *RKRequestDescriptorFromArrayMatchingObjectAndRequestMethod(NSArray *requestDescriptors, id object, RKRequestMethod requestMethod);

@interface RKRequestDescriptorFromArrayMatchingObjectAndRequestMethodTest : RKTestCase

@property (nonatomic, strong) RKRequestDescriptor *exactClassAndExactMethodDescriptor;
@property (nonatomic, strong) RKRequestDescriptor *exactClassAndBitwiseMethodDescriptor;
@property (nonatomic, strong) RKRequestDescriptor *superclassAndExactMethodDescriptor;
@property (nonatomic, strong) RKRequestDescriptor *superclassAndBitwiseMethodDescriptor;
@property (nonatomic, strong) RKRequestDescriptor *nonMatchingClassAndExactMethodDescriptor;
@end

@implementation RKRequestDescriptorFromArrayMatchingObjectAndRequestMethodTest

- (void)setUp
{
    RKObjectMapping *requestMapping = [RKObjectMapping requestMapping];
    
    // Exact
    _exactClassAndExactMethodDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:requestMapping objectClass:[RKSubclassedTestModel class] rootKeyPath:nil method:RKRequestMethodPOST];
    _exactClassAndBitwiseMethodDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:requestMapping objectClass:[RKSubclassedTestModel class] rootKeyPath:nil method:RKRequestMethodPOST | RKRequestMethodPUT];
    
    // Superclass
    _superclassAndExactMethodDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:requestMapping objectClass:[RKObjectMapperTestModel class] rootKeyPath:@"superclass" method:RKRequestMethodPOST];
    _superclassAndBitwiseMethodDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:requestMapping objectClass:[RKObjectMapperTestModel class] rootKeyPath:@"superclass" method:RKRequestMethodPOST | RKRequestMethodPUT];
    
    // Non-matching
    _nonMatchingClassAndExactMethodDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:requestMapping objectClass:[RKTestUser class] rootKeyPath:@"subclassed" method:RKRequestMethodPOST];
}

- (void)testExactClassAndExactMethodMatchHasHighestPrecedence
{    
    RKSubclassedTestModel *object = [RKSubclassedTestModel new];
    NSArray *descriptors = @[ _exactClassAndExactMethodDescriptor, _exactClassAndBitwiseMethodDescriptor, _superclassAndExactMethodDescriptor, _superclassAndBitwiseMethodDescriptor,  _nonMatchingClassAndExactMethodDescriptor ];
    RKRequestDescriptor *requestDescriptor = RKRequestDescriptorFromArrayMatchingObjectAndRequestMethod(descriptors, object, RKRequestMethodPOST);
    expect(requestDescriptor).to.equal(_exactClassAndExactMethodDescriptor);
}

- (void)testExactClassAndBitwiseMethodMatchHasSecondHighestPrecedence
{
    RKSubclassedTestModel *object = [RKSubclassedTestModel new];
    NSArray *descriptors = @[ _exactClassAndBitwiseMethodDescriptor, _superclassAndExactMethodDescriptor, _superclassAndBitwiseMethodDescriptor,  _nonMatchingClassAndExactMethodDescriptor ];
    RKRequestDescriptor *requestDescriptor = RKRequestDescriptorFromArrayMatchingObjectAndRequestMethod(descriptors, object, RKRequestMethodPOST);
    expect(requestDescriptor).to.equal(_exactClassAndBitwiseMethodDescriptor);
}

- (void)testSuperclassAndExactMethodMatchHasThirdHighestPrecedence
{
    RKSubclassedTestModel *object = [RKSubclassedTestModel new];
    NSArray *descriptors = @[ _superclassAndExactMethodDescriptor, _superclassAndBitwiseMethodDescriptor,  _nonMatchingClassAndExactMethodDescriptor ];
    RKRequestDescriptor *requestDescriptor = RKRequestDescriptorFromArrayMatchingObjectAndRequestMethod(descriptors, object, RKRequestMethodPOST);
    expect(requestDescriptor).to.equal(_superclassAndExactMethodDescriptor);
}

- (void)testSuperclassAndBitwiseMethodMatchHasThirdHighestPrecedence
{
    RKSubclassedTestModel *object = [RKSubclassedTestModel new];
    NSArray *descriptors = @[ _superclassAndBitwiseMethodDescriptor,  _nonMatchingClassAndExactMethodDescriptor ];
    RKRequestDescriptor *requestDescriptor = RKRequestDescriptorFromArrayMatchingObjectAndRequestMethod(descriptors, object, RKRequestMethodPOST);
    expect(requestDescriptor).to.equal(_superclassAndBitwiseMethodDescriptor);
}

- (void)testThatNonmatchingClassesReturnNil
{
    RKSubclassedTestModel *object = [RKSubclassedTestModel new];
    NSArray *descriptors = @[ _nonMatchingClassAndExactMethodDescriptor ];
    RKRequestDescriptor *requestDescriptor = RKRequestDescriptorFromArrayMatchingObjectAndRequestMethod(descriptors, object, RKRequestMethodPOST);
    expect(requestDescriptor).to.beNil();
}

@end
