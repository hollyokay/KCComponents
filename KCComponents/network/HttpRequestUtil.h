//
//  HttpRequestUtil.h
//  Jindoyun
//
//  Created by smartcloud on 17/03/2011.
//  Copyright 2011 SmartCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JDYFile.h"
enum{
    HttpMethodTypeCommonForm,
    HttpMethodTypeFileForm,
    HttpMethodTypeGet
};

typedef NSUInteger HttpMethodType;

@class JDYFile;
@interface HttpRequestUtil : NSObject {
    NSMutableDictionary *requestHeaders;
    NSMutableArray *postDatas;
    NSMutableArray *postFiles;      //Contains kinds of NSDictionary
    NSMutableData *postBody;
    
    NSString *requestURLString;
    HttpMethodType httpMethod;
    NSString *authorizationInfo;
    id delegate;
    NSURLConnection *asynURLConnection;
    NSMutableURLRequest *urlRequest;
}

@property (nonatomic, retain) NSMutableDictionary *requestHeaders;
@property (nonatomic, retain) NSMutableArray *postDatas;
@property (nonatomic, retain) NSMutableArray *postFiles;
@property (nonatomic, retain) NSMutableData *postBody;
@property (nonatomic, retain) NSString *requestURLString;
@property (nonatomic, assign) HttpMethodType httpMethod;
@property (nonatomic, assign) id delegate;
@property (nonatomic, retain) NSURLConnection *asynURLConnection;
@property (nonatomic, retain) NSMutableURLRequest *urlRequest;

- (id)initWithRequestURL:(NSString *)urlString; //Default Form Type is common form not file form
- (id)initWithRequestURL:(NSString *)urlString delegate:(id)_delegate;
- (id)initWithRequestURL:(NSString *)urlString method:(HttpMethodType)type;
- (id)initWithRequestURL:(NSString *)urlString delegate:(id)_delegate method:(HttpMethodType)type;
+ (id)requestUtilWithURL:(NSString *)urlString;

- (void)setAuthorizationInfo:(NSString *)authInfo;

- (void)addValueToHeader:(NSString *)value forName:(NSString *)name;
- (void)addValueToPostDatas:(NSString *)value forName:(NSString *)name;

//- (void)addFileName:(NSString *)fileName data:(NSData *)data fileType:(JDYFileType)fileType;

- (NSString *)sendRequest;  //send http request synchronously
- (void)sendRequestAsyn;
- (void)cancelAsynRequest;

@end
