//
//  KCComponentsTests.m
//  KCComponentsTests
//
//  Created by Wang Hui on 19/07/2011.
//  Copyright 2011 Wang Hui. All rights reserved.
//

#import "KCComponentsTests.h"
#import "KCHttpRequest.h"

@implementation KCComponentsTests

- (void)setUp{
    [super setUp];
}

- (void)tearDown{
    [super tearDown];
}

- (void)testPostRequestSync{
    
    KCHttpRequest *kcRequest = [[KCHttpRequest alloc] initWithURLString:@"http://www.nuomi.com/api/dailydeal?version=v1&city=beijing"];
    [kcRequest addRequestValue:@"v1" forKey:@"version"];
    [kcRequest addRequestValue:@"beijing" forKey:@"city"];
    
    NSString *res = [kcRequest sendRequestSync];
    NSLog(@"res: %@", res);
    [kcRequest release];
    STAssertNotNil(res, @"Something wrong");
}

- (void)testPostRequestAsyc{
    
    KCHttpRequest *kcRequest = [[KCHttpRequest alloc] initWithURLString:@"http://www.nuomi.com/api/dailydeal?version=v1&city=beijing"];
    
    [kcRequest addRequestValue:@"v1" forKey:@"version"];
    [kcRequest addRequestValue:@"beijing" forKey:@"city"];
    
    NSString *res = [kcRequest sendRequestSync];
    NSLog(@"res: %@", res);
    [kcRequest release];
    STAssertNotNil(res, @"Something wrong");
}

@end
