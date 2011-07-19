//
//  KCHttpRequest.m
//  KCComponents
//
//  Created by Wang Hui on 19/07/2011.
//  Copyright 2011 Wang Hui. All rights reserved.
//

#import "KCHttpRequest.h"

#define KCHttpCharset (NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding))
#define KC_POST_FILE_NAME           @"name"
#define KC_POST_FILE_CONTENT_TYPE   @"type"
#define KC_POST_FILE_FORM_NAME      @"fname"
#define KC_POST_FILE_DATA           @"data"

#define KC_HTTP_HEADER_CONTENT_TYPE @"Content-Type"

@interface KCHttpRequest ()

@property (nonatomic, retain) NSString              *responseStr;

@property (nonatomic, retain) NSMutableDictionary   *headers;
@property (nonatomic, retain) NSMutableDictionary   *requestParams;
@property (nonatomic, retain) NSMutableArray        *postFiles;

@property (nonatomic, retain) NSMutableData         *responseData;
@property (nonatomic, retain) NSMutableData         *requestBody;

@property (nonatomic, retain) NSLock                *accessLock;

- (NSString*)encodeURL:(NSString *)string;
- (void)setupRequestParams;
- (void)setupResponseData;
- (void)setupRequestBody;
- (void)setupHeaders;
- (void)setupPostFiles;

- (void)appendPostString:(NSString *)pStr;
- (void)appendPostData:(NSData *)pData;

- (void)setupHttpRequest;
- (void)startRequest;

- (void)handleNetworkEvent:(CFStreamEventType)type;
- (void)handleBytesAvailable;
- (void)handleStreamComplete;
- (void)handleStreamError;

- (void)handleRequestURL;
- (NSString *)buildRequestParamsForURL;

- (void)buildMultiPartBody;
- (void)buildURLEncodeBody;
- (void)buildRequestHeaders;

@end

static void ReadStreamClientCallBack(CFReadStreamRef readStream, CFStreamEventType type, void *clientCallBackInfo) {
    [((KCHttpRequest*)clientCallBackInfo) handleNetworkEvent: type];
}

static NSString *KCHTTPRequestRunLoopMode = @"KCHTTPRequestRunLoopMode";

@implementation KCHttpRequest
@synthesize requestURL      = _requestURL;
@synthesize responseStr     = _responseStr;
@synthesize headers         = _headers;
@synthesize requestParams   = _requestParams;
@synthesize postFiles       = _postFiles;
@synthesize responseData    = _responseData;
@synthesize requestBody     = _requestBody;
@synthesize accessLock      = _accessLock;
@synthesize requestMethod   = _requestMethod;
@synthesize delegate;

#pragma Init Methods
- (id)init{
    return [self initWithURLString:nil requestMethod:KCHttpRequestMethodPost];
}

//Default request method is KCHttpRequestMethodPost
- (id)initWithURLString:(NSString *)urlString{
    return [self initWithURLString:urlString requestMethod:KCHttpRequestMethodPost];
}
- (id)initWithURLString:(NSString *)urlString requestMethod:(KCHttpRequestMethod)requestMethod{
    if ((self = [super init])) {
        self.requestURL     = urlString;
        self.requestMethod  = requestMethod;
        NSLock *tmpLock     = [[NSLock alloc] init];
        self.accessLock     = tmpLock;
        [tmpLock release];
    }
    
    return self;   
}


#pragma GC
- (void)dealloc{
    if (_request) {
        CFRelease(_request);
    }
    if (_readStream) {
        CFRelease(_readStream);
    }
    
    [_requestBody   release];
    [_responseData  release];
    [_postFiles     release];
    [_headers       release];
    [_accessLock     release];
    [_responseStr   release];
    [_requestURL    release];
    [_requestParams release];
    [super          dealloc];
}


- (NSString*)encodeURL:(NSString *)string{
    NSString *newString = [(NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)string, NULL, CFSTR(":/?#[]@!$ &'()*+,;=\"<>%{}|\\^~`"), CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding)) autorelease];
    if (newString) {
        return newString;
    }
    return @"";
}

- (void)setupRequestParams{
    if (!self.requestParams) {
        self.requestParams = [NSMutableDictionary dictionary];        
    }
}

- (void)setupHeaders{
    if (!self.headers) {
        self.headers = [NSMutableDictionary dictionary];
    }
}

- (void)setupResponseData{
    if (!self.responseData) {
        self.responseData = [NSMutableData data];
    }
}

- (void)setupRequestBody{
    if (!self.requestBody) {
        self.requestBody = [NSMutableData data];
    }
}

- (void)setupPostFiles{
    if (!self.postFiles) {
        self.postFiles = [NSMutableArray array];
    }
}

- (void)addRequestValue:(NSString *)value forKey:(NSString *)paramName{
    if (value && paramName) {
        [self setupRequestParams];
        [self.requestParams setObject:value forKey:paramName];
    }
}

- (void)addHeader:(NSString *)headerValue forKey:(NSString *)headerKey{
    if (headerKey && headerValue) {
        [self setupHeaders];
        [self.headers setObject:headerValue forKey:headerKey];
    }
}

- (void)addFileData:(NSData *)fileData forKey:(NSString *)paramName{
    [self addFileData:fileData fileName:nil forKey:paramName];
}

- (void)addFileData:(NSData *)fileData fileName:(NSString *)fileName forKey:(NSString *)paramName{
    [self addFileData:fileData fileName:fileName contentType:nil forKey:paramName];
}

- (void)addFileData:(NSData *)fileData fileName:(NSString *)fileName contentType:(NSString *)contentType forKey:(NSString *)paramName{
    
    if (fileData && paramName) {
        [self setupPostFiles];
        
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setObject:fileData forKey:KC_POST_FILE_DATA];
        if (fileName) {
            [dict setObject:fileName forKey:KC_POST_FILE_NAME];
        }

        [dict setObject:paramName forKey:KC_POST_FILE_FORM_NAME];
        if (contentType) {
            [dict setObject:contentType forKey:KC_POST_FILE_CONTENT_TYPE];            
        }
        [self.postFiles addObject:dict];
    }
}

- (void)handleNetworkEvent:(CFStreamEventType)type{	
    NSLog(@"Type s: %lul", type);
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [_accessLock lock];    
    CFRetain(self);
    
    // Dispatch the stream events.
    switch (type) {
        case kCFStreamEventHasBytesAvailable:
            [self handleBytesAvailable];
            break;
            
        case kCFStreamEventEndEncountered:
            [self handleStreamComplete];
            break;
            
        case kCFStreamEventErrorOccurred:
            [self handleStreamError];
            break;
            
        default:
            _completed = YES;
            break;
    }
    
    CFRelease(self);
    [_accessLock unlock];    
    [pool release];
    
}

- (void)handleBytesAvailable{
    
    if (!self.responseStr) {
        self.responseStr = [[NSMutableString alloc] init];
    }
    
    if (CFReadStreamHasBytesAvailable(_readStream)) {
        CFIndex bufferLength = 1024;
        UInt8 buffer[bufferLength];
        
        CFIndex avaliableLength = 0;
        
        avaliableLength = CFReadStreamRead(_readStream, buffer, bufferLength);
        while(avaliableLength > 0){
            CFDataRef tmpData = CFDataCreate(kCFAllocatorDefault, buffer, avaliableLength);
            [self setupResponseData];
            [self.responseData appendData:(NSData *)tmpData];
            //            NSString *tmpString = [[NSString alloc] initWithData:(NSData *)tmpData encoding:NSUTF8StringEncoding];
            //            [self.responseStr appendString:tmpString];
            //            [tmpString release];
            CFRelease(tmpData);
            avaliableLength = CFReadStreamRead(_readStream, buffer, bufferLength);            
        };
    }else{
        _completed = YES;
    }
}
- (void)handleStreamComplete{
    self.responseStr = [[[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding] autorelease];

    if (!_isSync) {
        if (delegate && [delegate respondsToSelector:@selector(requestDidEnd:)]) {
            [delegate requestDidEnd:self];
        }
    }
    
    _completed = YES;
}
- (void)handleStreamError{
    
    NSError *streamError = (NSError *)CFReadStreamCopyError(_readStream);
    if (streamError) {
        self.responseStr = [streamError localizedDescription];
        NSLog(@"Error Domain: %@, Description: %@", [streamError domain], [streamError localizedDescription]);
    }
    
    if (!_isSync) {
        if (delegate && [delegate respondsToSelector:@selector(requestDidError:forRequest:)]) {
            [delegate requestDidError:[streamError autorelease] forRequest:self];
        }else{
            [streamError release];
        }    
    }else{
        [streamError release];
    }
    _completed = YES;
}

- (NSString *)buildRequestParamsForURL{
    NSMutableString *paramsStr = [NSMutableString stringWithString:@""];
    NSUInteger i=0;
    NSUInteger count = [[self requestParams] count]-1;
    for (NSString *key in [self.requestParams allKeys]) {
        NSString *data = [NSString stringWithFormat:@"%@=%@%@", [self encodeURL:key], [self encodeURL:[self.requestParams objectForKey:key]], (i < count ? @"&" : @"")];
        [paramsStr appendString:data];
        i++;
    }
    
    return paramsStr;
}

- (void)handleRequestURL{
    NSURL *url = [NSURL URLWithString:self.requestURL];
    NSAssert(url, @"Request URL format is not correct");
    
    if ([[url scheme] isEqualToString:@"https"]) {
        _isSecure = YES;
    }else{
        _isSecure = NO;
    }
    
    if (_requestMethod == KCHttpRequestMethodGet) {
        self.requestURL = [NSString stringWithFormat:@"%@?%@", self.requestURL, [self buildRequestParamsForURL]];
    }
}

- (void)buildRequestHeaders{
    NSAssert(_request, @"Http Request is null");
    
    if (_headers) {
        for (NSString *headerName in [_headers allKeys]) {
            NSString *headerValue = [_headers objectForKey:headerName];
            if (headerValue) {
                CFHTTPMessageSetHeaderFieldValue(_request, (CFStringRef)headerName, (CFStringRef)headerValue); 
            }
        }
    }
}

- (void)buildURLEncodeBody{    
    NSAssert(_request, @"Http Request is null");
    
    CFHTTPMessageSetHeaderFieldValue(_request, (CFStringRef)KC_HTTP_HEADER_CONTENT_TYPE, (CFStringRef)[NSString stringWithFormat:@"application/x-www-form-urlencoded; charset=%@",KCHttpCharset]);
    
    NSString *rBody = [self buildRequestParamsForURL];
    
    NSData *reqBody = [rBody dataUsingEncoding:NSUTF8StringEncoding];
    CFHTTPMessageSetBody(_request, (CFDataRef)reqBody);
}

- (void)appendPostString:(NSString *)pStr{
    if (pStr) {
        [self appendPostData:[pStr dataUsingEncoding:NSUTF8StringEncoding]];
    }
}

- (void)appendPostData:(NSData *)pData{
    if (pData) {
        [self setupRequestBody];
        [self.requestBody appendData:pData];        
    }
}

- (void)buildMultiPartBody{
    NSAssert(_request, @"Http Request is null");
    
    NSString *boundary = @"0xKhTmLbOuNdArYLSks";
    NSString *endItemBoundary = [NSString stringWithFormat:@"\r\n---%@\r\n", boundary];
    NSString *headerValue = [NSString stringWithFormat:@"multipart/form-data; charset=%@; boundary=%@", KCHttpCharset, boundary];
    CFHTTPMessageSetHeaderFieldValue(_request, (CFStringRef)KC_HTTP_HEADER_CONTENT_TYPE, (CFStringRef)headerValue);
    CFHTTPMessageSetHeaderFieldValue(_request, (CFStringRef)@"Accept", (CFStringRef)@"*/*");
    [self appendPostString:[NSString stringWithFormat:@"--%@\r\n",boundary]];
    
    int i = 0;
    
    int paramsCount = [self.requestParams count];
    if (self.requestParams) {
        for (NSString *key in [self.requestParams allKeys]) {
            [self appendPostString:[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key]];
            [self appendPostString:[self.requestParams objectForKey:key]];
            i++;
            if (i != paramsCount || [[self postFiles] count] > 0) { //Only add the boundary if this is not the last item in the post body
                [self appendPostString:endItemBoundary];
            }
        }
    }
    
    i = 0;
    if (self.postFiles) {
        int fileCount = [self.postFiles count];
        for (NSDictionary *tmpFile in self.postFiles) {

            NSData   *fileData = [tmpFile objectForKey:KC_POST_FILE_DATA];            
            i++;            
            if (fileData) {
                NSString *fileName = [tmpFile objectForKey:KC_POST_FILE_NAME];
                if (!fileName) {
                    fileName = @"file";
                }
                NSString *formName = [tmpFile objectForKey:KC_POST_FILE_FORM_NAME];
                NSString *contentType = [tmpFile objectForKey:KC_POST_FILE_CONTENT_TYPE];
                if (!contentType) {
                    contentType = @"application/octet-stream";
                }

                [self appendPostString:[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", formName, fileName]];
                [self appendPostString:[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", contentType]];
                [self appendPostData:fileData];    

                if (i != fileCount) { 
                    [self appendPostString:endItemBoundary];
                }
            }
        }    
    }
    
    
    [self appendPostString:[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary]];
    
    CFHTTPMessageSetBody(_request, (CFDataRef)self.requestBody);
}


- (void)setupHttpRequest{
    _completed = NO;
    NSAssert(self.requestURL, @"Request URL can not be null");
    NSString *rMethod = @"POST";
    if (_requestMethod == KCHttpRequestMethodGet) {
        rMethod = @"GET";
    }
    [self handleRequestURL];
    
    _request = CFHTTPMessageCreateRequest(kCFAllocatorDefault, (CFStringRef)rMethod, (CFURLRef)[NSURL URLWithString:self.requestURL], kCFHTTPVersion1_1);
    [self buildRequestHeaders];
    
    if (_requestMethod == KCHttpRequestMethodPost) {
        [self buildURLEncodeBody];
    }else if(_requestMethod == KCHttpRequestMethodMultiForm){
        [self buildMultiPartBody];
    }
}

- (void)startRequest{
    
    if (!_isSync && delegate && [delegate respondsToSelector:@selector(requestDidStart:)]) {
        [delegate requestDidStart:self];
    }
    
    [self setupHttpRequest];
    _readStream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, _request);
    if (_isSecure) {
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:(NSString *)kCFBooleanFalse, (NSString *)kCFStreamSSLValidatesCertificateChain, nil];
        CFReadStreamSetProperty(_readStream, kCFStreamPropertySSLSettings, (CFDictionaryRef)dict);        
    }
    
    BOOL isOpen = NO;
    CFStreamClientContext ctxt = {0, self, NULL, NULL, NULL};
    CFOptionFlags kEventFlags = kCFStreamEventHasBytesAvailable | kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred;
    if (CFReadStreamSetClient(_readStream, kEventFlags, ReadStreamClientCallBack, &ctxt)) {
        if (CFReadStreamOpen(_readStream)) {
            isOpen = YES;
        }
    }
    
    if (isOpen) {
        CFReadStreamScheduleWithRunLoop(_readStream, CFRunLoopGetCurrent(), (CFStringRef)KCHTTPRequestRunLoopMode);
        if (_isSync) {
            while (!_completed) {
                [[NSRunLoop currentRunLoop] runMode:KCHTTPRequestRunLoopMode beforeDate:[NSDate distantFuture]];
            }    
        }
    }else{
        NSLog(@"Error Info: Stream not opened");
    }
}

- (NSString *)sendRequestSync{
    _isSync = YES;
    [self startRequest];
    return self.responseStr;
}

- (void)sendRequestAsyn{
    _isSync = NO;
    [self startRequest];
}

@end

