//
//  KCHttpRequest.h
//  KCComponents
//
//  Created by Wang Hui on 19/07/2011.
//  Copyright 2011 Wang Hui. All rights reserved.
//

//support http and no certification https request 

#import <Foundation/Foundation.h>
#import <CFNetwork/CFNetwork.h> 

typedef enum{
    KCHttpRequestMethodGet,
    KCHttpRequestMethodPost,
    KCHttpRequestMethodMultiForm
}KCHttpRequestMethod;

@protocol KCHttpRequestDelegate;
@interface KCHttpRequest : NSObject {
    
@private    
    NSString                *_requestURL;
    NSString                *_responseStr;
    
    NSMutableDictionary     *_headers;
    NSMutableDictionary     *_requestParams;
    NSMutableArray          *_postFiles;
    
    NSMutableData           *_responseData;
    NSMutableData           *_requestBody;
    
    CFReadStreamRef          _readStream;
    CFHTTPMessageRef         _request;
    
    NSLock                  *_accessLock;
    BOOL                     _completed;
    BOOL                     _isSecure;
    BOOL                     _isSync;
    KCHttpRequestMethod      _requestMethod;
    
    id<KCHttpRequestDelegate> delegate;
}

@property (nonatomic, assign) KCHttpRequestMethod requestMethod;
@property (nonatomic, retain) NSString           *requestURL;
@property (nonatomic, assign) id<KCHttpRequestDelegate> delegate;

//Init Methods
- (id)initWithURLString:(NSString *)urlString;                  //Default request method is KCHttpRequestMethodPost
- (id)initWithURLString:(NSString *)urlString requestMethod:(KCHttpRequestMethod)requestMethod;


- (void)addRequestValue:(NSString *)value forKey:(NSString *)paramName;
- (void)addHeader:(NSString *)headerValue forKey:(NSString *)headerKey;

- (void)addFileData:(NSData *)fileData forKey:(NSString *)paramName;
- (void)addFileData:(NSData *)fileData fileName:(NSString *)fileName forKey:(NSString *)paramName;
- (void)addFileData:(NSData *)fileData fileName:(NSString *)fileName contentType:(NSString *)contentType forKey:(NSString *)paramName;

- (NSString *)sendRequestSync;
- (void)sendRequestAsyn;

@end

@protocol KCHttpRequestDelegate <NSObject>
@optional
- (void)requestDidStart:(KCHttpRequest *)httpRequest;
- (void)requestDidEnd:(KCHttpRequest *)httpRequest;
- (void)requestDidError:(NSError *)error forRequest:(KCHttpRequest *)httpRequest;
@end
