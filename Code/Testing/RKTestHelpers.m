//
//  RKTestHelpers.m
//  RestKit
//
//  Created by Blake Watters on 10/2/12.
//  Copyright (c) 2012 RestKit. All rights reserved.
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

#import "RKTestHelpers.h"
#import "RKObjectManager.h"
#import "RKRoute.h"
#import "RKPathUtilities.h"
#import "RKLog.h"
#import <SOCKit/SOCKit.h>
#import "RKRouteSet.h"

@implementation RKTestHelpers

+ (RKRoute *)stubRouteForClass:(Class)objectClass method:(RKRequestMethod)method withPathPattern:(NSString *)pathPattern onObjectManager:(RKObjectManager *)nilOrObjectManager
{
    RKObjectManager *objectManager = nilOrObjectManager ?: [RKObjectManager sharedManager];
    RKRoute *route = [objectManager.router.routeSet routeForClass:objectClass method:method];
    NSAssert(route, @"Expected to retrieve a route, but got nil");
    [objectManager.router.routeSet removeRoute:route];
    RKRoute *stubbedRoute = [RKRoute routeWithClass:objectClass pathPattern:pathPattern method:method];
    [objectManager.router.routeSet addRoute:stubbedRoute];
    return stubbedRoute;
}

+ (RKRoute *)stubRouteNamed:(NSString *)routeName withPathPattern:(NSString *)pathPattern onObjectManager:(RKObjectManager *)nilOrObjectManager
{
    RKObjectManager *objectManager = nilOrObjectManager ?: [RKObjectManager sharedManager];
    RKRoute *route = [objectManager.router.routeSet routeForName:routeName];
    NSAssert(route, @"Expected to retrieve a route, but got nil");
    [objectManager.router.routeSet removeRoute:route];
    RKRoute *stubbedRoute = [RKRoute routeWithName:routeName pathPattern:pathPattern method:route.method];
    [objectManager.router.routeSet addRoute:stubbedRoute];
    return stubbedRoute;
}

+ (RKRoute *)stubRouteForRelationship:(NSString *)relationshipName ofClass:(Class)objectClass method:(RKRequestMethod)method pathPattern:(NSString *)pathPattern onObjectManager:(RKObjectManager *)nilOrObjectManager
{
    RKObjectManager *objectManager = nilOrObjectManager ?: [RKObjectManager sharedManager];
    RKRoute *route = [objectManager.router.routeSet routeForRelationship:relationshipName ofClass:objectClass method:method];
    NSAssert(route, @"Expected to retrieve a route, but got nil");
    [objectManager.router.routeSet removeRoute:route];
    RKRoute *stubbedRoute = [RKRoute routeWithRelationshipName:relationshipName objectClass:objectClass pathPattern:pathPattern method:method];
    [objectManager.router.routeSet addRoute:stubbedRoute];
    return stubbedRoute;
}

+ (void)disableCaching
{
    NSURLCache *sharedCache = [[NSURLCache alloc] initWithMemoryCapacity:0 diskCapacity:0 diskPath:nil];
    [NSURLCache setSharedURLCache:sharedCache];
}

+ (NSCachedURLResponse *)cacheResponseForRequest:(NSURLRequest *)request withResponseData:(NSData *)responseData
{
    NSParameterAssert(request);
    NSParameterAssert(responseData);

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[request URL] statusCode:200 HTTPVersion:@"1.1" headerFields:nil];
    NSAssert(response, @"Failed to build cached response");
    NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:responseData];
    [[NSURLCache sharedURLCache] storeCachedResponse:cachedResponse forRequest:request];

    // Verify that we can get the cached response back
    NSCachedURLResponse *__unused storedResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:request];
    NSAssert(storedResponse, @"Expected to retrieve cached response for request '%@', instead got nil.", request);

    return cachedResponse;
}

+ (NSCachedURLResponse *)cacheResponseForURL:(NSURL *)URL HTTPMethod:(NSString *)HTTPMethod headers:(NSDictionary *)requestHeaders withData:(NSData *)responseData
{
    NSParameterAssert(URL);
    NSParameterAssert(HTTPMethod);
    NSParameterAssert(responseData);

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = HTTPMethod;
    [request setAllHTTPHeaderFields:requestHeaders];
    return [self cacheResponseForRequest:request withResponseData:responseData];
}

@end
