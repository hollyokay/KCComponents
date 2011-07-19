//
//  HttpRequestUtil.m
//  Jindoyun
//
//  Created by smartcloud on 17/03/2011.
//  Copyright 2011 SmartCloud. All rights reserved.
//

#import "HttpRequestUtil.h"
#import "Util.h"
#import "Constants.h"

#define HttpKeyFileName @"filename"
#define HttpKeyContentType @"contentType"
#define HttpKeyName @"name"
#define HttpKeyValue @"value"
#define HttpKeyKey @"key"

@interface HttpRequestUtil (HttpRequestUtilPrivate)
- (void)buildMultiPartBody;
- (void)buildURLEncodeBody;
- (void)appendPostString:(NSString *)postString;
- (void)appendPostData:(NSData *)postData;
- (void)setupPostBody;
- (NSString*)encodeURL:(NSString *)string;
- (void)buildRequest;
- (NSURL *)buildRequestURL;
@end

@implementation HttpRequestUtil
@synthesize requestHeaders, postDatas, postFiles, httpMethod, requestURLString;
@synthesize postBody, delegate, asynURLConnection;
@synthesize urlRequest;

- (NSString*)encodeURL:(NSString *)string{
    NSString *newString = [(NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)string, NULL, CFSTR(":/?#[]@!$ &'()*+,;=\"<>%{}|\\^~`"), CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding)) autorelease];
    if (newString) {
        return newString;
    }
    return @"";
}

- (id)initWithRequestURL:(NSString *)urlString delegate:(id)_delegate method:(HttpMethodType)type{
    if ((self = [super init])) {
        self.requestURLString = urlString;
        self.httpMethod = type;
        self.delegate = _delegate;
        self.postBody = [NSMutableData data];
    }
    return self;
}
- (id)initWithRequestURL:(NSString *)urlString delegate:(id)_delegate{
    return [self initWithRequestURL:urlString delegate:_delegate method:HttpMethodTypeCommonForm];
}

- (id)initWithRequestURL:(NSString *)urlString{
    return [self initWithRequestURL:urlString delegate:nil method:HttpMethodTypeCommonForm];
}

- (id)initWithRequestURL:(NSString *)urlString method:(HttpMethodType)type{
    return [self initWithRequestURL:urlString delegate:nil method:type];
}

+ (id)requestUtilWithURL:(NSString *)urlString{
    return [[[HttpRequestUtil alloc] initWithRequestURL:urlString] autorelease];
}

- (void)setAuthorizationInfo:(NSString *)authInfo{
    //    authorizationInfo = [authInfo retain];
    [self addValueToHeader:authInfo forName:JDYHttpHeaderAuthorization];
}

- (void)addValueToHeader:(NSString *)value forName:(NSString *)name{
    if (!self.requestHeaders) {
        self.requestHeaders = [NSMutableDictionary dictionary];
    }
    
    [requestHeaders setObject:value forKey:name];
}
- (void)addValueToPostDatas:(NSString *)value forName:(NSString *)name{
    if (!self.postDatas) {
        self.postDatas = [NSMutableArray array];
    }
    
    [postDatas addObject:[NSDictionary dictionaryWithObjectsAndKeys: value, HttpKeyValue, name, HttpKeyKey, nil]];
}

//- (void)addFileName:(NSString *)fileName data:(NSData *)data fileType:(JDYFileType)fileType{
//    if (!self.postFiles) {
//        self.postFiles = [NSMutableArray array];
//    }
//    
//    if(data){
//        JDYFile *file = [[JDYFile alloc] initWithData:data fileName:fileName fileType:fileType];
//        [postFiles addObject:file];
//        [file release];
//    }
//}

- (void)setupPostBody{
    if (!self.postBody) {
        self.postBody = [NSMutableData data];
    }
}

- (void)appendPostString:(NSString *)postString{
    [self setupPostBody];
    [self.postBody appendData:[postString dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)appendPostData:(NSData *)postData{
    [self setupPostBody];
    if (postData.length != 0) {
        [self.postBody appendData:postData];
    }
}

- (void)buildMultiFormBody:(NSMutableURLRequest *) request{
    
    NSString *boundary = @"0xKhTmLbOuNdArYLSks";
    NSString *endItemBoundary = [NSString stringWithFormat:@"\r\n---%@\r\n", boundary];
    if ([self.postFiles count] < 1) {
        [request addValue:[NSString stringWithFormat:@"charset=%@; boundary=%@", HttpCharset, boundary] forHTTPHeaderField:@"Content-Type"];
    }else{
        [request addValue:[NSString stringWithFormat:@"multipart/form-data; charset=%@; boundary=%@", HttpCharset, boundary] forHTTPHeaderField:@"Content-Type"];        
    }
    
    //set relatived header infos
    [request addValue:@"image/gif, image/jpeg, image/pjpeg, image/pjpeg, application/x-shockwave-flash, application/xaml+xml, application/vnd.ms-xpsdocument, application/x-ms-xbap, application/x-ms-application, application/vnd.ms-excel, application/vnd.ms-powerpoint, application/msword, */" forHTTPHeaderField:@"Accept"];
    
    [self appendPostString:[NSString stringWithFormat:@"--%@\r\n",boundary]];
    
    int i = 0;
    for (NSDictionary *dict in postDatas) {
        [self appendPostString:[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n",[dict objectForKey:HttpKeyKey]]];
        [self appendPostString:[dict objectForKey:HttpKeyValue]];
        i++;
        if (i != [[self postDatas] count] || [[self postFiles] count] > 0) { //Only add the boundary if this is not the last item in the post body
            [self appendPostString:endItemBoundary];
        }
    }
    
    i = 0;
    for (JDYFile *tmpFile in self.postFiles) {
        [self appendPostString:[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", @"video", tmpFile.fileName]];
        [self appendPostString:[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", tmpFile.contentType]];
//        [self appendPostData:tmpFile.fileData];
        i++;
        // Only add the boundary if this is not the last item in the post body
        if (i != [[self postFiles] count]) { 
            [self appendPostString:endItemBoundary];
        }
    }
    
    [self appendPostString:[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary]];
    
}

- (void)buildURLEncodeBody:(NSMutableURLRequest *) request{
    [request setTimeoutInterval:2];
    [request addValue:[NSString stringWithFormat:@"application/x-www-form-urlencoded; charset=%@",HttpCharset] forHTTPHeaderField:@"Content-Type"];
    
    NSUInteger i=0;
    NSUInteger count = [[self postDatas] count]-1;
    for (NSDictionary *val in [self postDatas]) {
        NSString *data = [NSString stringWithFormat:@"%@=%@%@", [self encodeURL:[val objectForKey:HttpKeyKey]], [self encodeURL:[val objectForKey:HttpKeyValue]],(i<count ?  @"&" : @"")]; 
        
        [self appendPostString:data];
        i++;
    }
}

- (void)buildHeaders:(NSMutableURLRequest *) request{
    [request addValue:JDYHttpHeaderValueKeppAlive forHTTPHeaderField:JDYHttpHeaderConnection];
    if (self.requestHeaders) {
        for (NSString *name in [self.requestHeaders allKeys]) {
            [request setValue:[requestHeaders objectForKey:name] forHTTPHeaderField:name];
        }
    }
}

- (NSURL *)buildRequestURL{
    NSString *tmpString = self.requestURLString;
    if (httpMethod == HttpMethodTypeGet) {
        NSUInteger i = 0;
        NSUInteger count = [[self postDatas] count]-1;
        NSMutableString *data = [NSMutableString stringWithString:tmpString];
        [data appendString:@"?"];
        for (NSDictionary *val in [self postDatas]) {
            [data appendFormat:@"%@=%@%@", [self encodeURL:[val objectForKey:HttpKeyKey]], [self encodeURL:[val objectForKey:HttpKeyValue]],(i<count ?  @"&" : @"")];
            i++;
        }
        tmpString = data;
    }
    return [NSURL URLWithString:tmpString];
}

- (void)buildRequest{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self buildRequestURL]];
    
    [self buildHeaders:request];
    if (httpMethod == HttpMethodTypeGet) {
        [request setHTTPMethod:@"GET"];
    }else{
        [request setHTTPMethod:@"POST"];
        if (httpMethod == HttpMethodTypeCommonForm) {
            [self buildURLEncodeBody:request];
        }else {
            [self buildMultiFormBody:request];
        }
        
//        NSString *body = [[NSString alloc] initWithData:postBody encoding:NSUTF8StringEncoding];
//        [body release];
        [request setHTTPBody:self.postBody];
    }
    self.urlRequest = request;
    [request release];
}

- (NSString *)sendRequest{
    NSError *error = nil;
    NSURLResponse *response = nil;
    [self buildRequest];
    
    NSData *result = [NSURLConnection sendSynchronousRequest:self.urlRequest returningResponse:&response error:&error];
    NSString *resultString = nil;
    if (!error && [(NSHTTPURLResponse *)response statusCode] == 200 ) {
        resultString = [[[NSString alloc] initWithData:result encoding:NSASCIIStringEncoding] autorelease];
    }else{
        result = nil;
        NSLog(@"Request Failed, Status code : %d . Reasons: %@",[(NSHTTPURLResponse *)response statusCode], [error localizedDescription]);
        NSLog(@"Error info: %@", [error userInfo]);
    }
    
    if (resultString) {
        resultString = [resultString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];        
    }
    return resultString;
}

- (void)sendRequestAsyn{
    [self buildRequest];
    self.asynURLConnection = [[[NSURLConnection alloc] initWithRequest:self.urlRequest delegate:delegate startImmediately:YES] autorelease];
}

- (void)cancelAsynRequest{
    if (self.asynURLConnection) {
        [asynURLConnection cancel];
    }
}

- (void)dealloc{
    [urlRequest release];
    [asynURLConnection release];
    [authorizationInfo release];
    [requestURLString release];
    [requestHeaders release];
    [postBody release];
    [postDatas release];
    [postFiles release];
    [super dealloc];
}
@end
