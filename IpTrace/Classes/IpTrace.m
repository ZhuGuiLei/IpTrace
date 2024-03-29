//
//  IpTrace.m
//  IpTrace
//
//  Created by apple on 2022/6/10.
//

#import "IpTrace.h"
#import <CommonCrypto/CommonCrypto.h>
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreLocation/CoreLocation.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <AdSupport/AdSupport.h>
#import "Reachability.h"
#import "Traceroute.h"

static NSString *IpTraceIdfa = @"IpTraceIdfa";
static NSString *IpTraceSecond = @"IpTraceSecond";
static NSString *IpTraceLastTime = @"IpTraceLastTime";

static NSString *IpTraceUUID = @"IpTraceUUID";

static NSString *IpTraceAPI = @"http://trace.ssoapi.com/";
static NSString *IPSearchAPI = @"https://app.ipdatacloud.com/";
//static NSString *IpTraceAPI = @"http://10.3.3.177:17001/";
//static NSString *IpTraceAPI = @"http://58.218.214.197:17001/";

@interface IpTrace () <CLLocationManagerDelegate>

/// 密钥
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *channel;

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLGeocoder *geocoder;

/// 地理位置
@property (nonatomic, copy) NSString *latitude;
@property (nonatomic, copy) NSString *longitude;
@property (nonatomic, copy) NSString *area;

@property (nonatomic, strong) NSDictionary *initdic;
@property (nonatomic, strong) NSArray *tracerouteArr;

/// sdkkey
@property (nonatomic, copy) NSString *sdkkey;

@end

@implementation IpTrace

+ (instancetype)shared {
    static IpTrace *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[IpTrace alloc] init];
    });
    return shared;
}

- (void)startWithKey:(NSString *)key {
    [self startWithKey:key withChannel:@"appstore"];
}

- (void)startWithKey:(NSString *)key withChannel:(NSString *)channel {
    self.key = key;
    self.channel = channel;
    
    /// 防止短时间内多次请求
    double lastTime = [[NSUserDefaults standardUserDefaults] doubleForKey:IpTraceLastTime];
    double interval = [[NSDate date] timeIntervalSince1970] - lastTime;
    NSInteger second = [[NSUserDefaults standardUserDefaults] integerForKey:IpTraceSecond];
    if (second > interval) {
        return;
    }
    
    /// 定位
    self.locationManager = [[CLLocationManager alloc] init];
    if ([CLLocationManager locationServicesEnabled]) {
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        [self.locationManager requestWhenInUseAuthorization];
        [self.locationManager startUpdatingLocation];
        self.geocoder = [[CLGeocoder alloc] init];
    } else {
        [self requestInit];
    }
}
/// 注册sdk套餐专属KEY
- (void)registersdkKey:(NSString *)sdkKey withChannel:(NSString *)channel{
    [self registersdkKey:sdkKey withKey:@"asdrewqsdfzxcfds" withChannel:channel];
}

/// 注册sdk套餐专属KEY
- (void)registersdkKey:(NSString *)sdkKey withKey:(nonnull NSString *)key withChannel:(NSString *)channel {
    self.sdkkey = sdkKey;
    self.channel = channel;
    self.key = key;
    [self startWithKey:key withChannel:channel];
}

/// 查询
/// @param searchIP 查询ip
- (void)searchWithIP:(NSString *)searchIP success:(nonnull SuccessBlock)successBlock fail:(nonnull FailBlock)failBlock{
  
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    params[@"ip"] = searchIP;
    params[@"key"] = self.sdkkey;

    NSData *data = [NSJSONSerialization dataWithJSONObject:params options:NSJSONWritingPrettyPrinted error:nil];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"it_json = %@", json);
    NSString *sign = [IpTrace aes256_encrypt:json withKey:self.key];
    
    NSString *path = [NSString stringWithFormat:@"%@%@", IPSearchAPI, @"v1/query_ip_zone_app"];
    NSURL *url = [NSURL URLWithString:path];
    //网络请求对象
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 15.0;
    request.HTTPMethod = @"POST";
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [self setRequestHeader:request];
    
    NSDictionary *body = @{@"sign": sign};
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:NSJSONWritingPrettyPrinted error:nil];
    
    NSURLSession *session = [NSURLSession sharedSession];
    //请求任务
    NSURLSessionDataTask * dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error) {
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
            NSLog(@"it_result = %@",result);
            successBlock(result);
//            int code = [result[@"code"] intValue];
//            if (code == 200) {
//                successBlock(result);
////                self.initdic = result[@"data"];
//            }else{
//                NSError *errorcode = [[NSError alloc]initWithDomain:result[@"msg"] code:code userInfo:nil];
//                failBlock(errorcode);
//            }
//            NSString *second = self.initdic[@"second"];
//            [[NSUserDefaults standardUserDefaults] setInteger:second.intValue forKey:IpTraceSecond];
//            [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSince1970] forKey:IpTraceLastTime];
        }else{
            failBlock(error);
        }
    }];
    [dataTask resume];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *location = locations.lastObject;
    self.latitude = [NSString stringWithFormat:@"%f", location.coordinate.latitude];
    self.longitude = [NSString stringWithFormat:@"%f", location.coordinate.longitude];
    
    [self.geocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        if (placemarks.count > 0) {
            CLPlacemark *placemark = placemarks.firstObject;
            NSArray *list = placemark.addressDictionary[@"FormattedAddressLines"];
            self.area = list.firstObject;
            [self requestInit];
        }
    }];
    
    [self.locationManager stopUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"it_location = 定位失败");
    [self requestInit];
}

- (void)requestInit {
    NSString *path = [NSString stringWithFormat:@"%@%@", IpTraceAPI, @"v1/init"];
    NSURL *url = [NSURL URLWithString:path];
    //网络请求对象
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 5.0;
    
    [self setRequestHeader:request];
    
    NSURLSession * session = [NSURLSession sharedSession];
    //请求任务
    NSURLSessionDataTask * dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        //主线程
        if (!error) {
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
            NSLog(@"it_result = %@",result);
            int code = [result[@"code"] intValue];
            if (code == 200) {
                self.initdic = result[@"data"];
                
                [self requestInfoAdd:@""];
                
                [self traceroutePressed:0];
            }
        }
    }];
    [dataTask resume];
}


- (void)traceroutePressed:(NSInteger)item {
    
    NSString *server_ip_list = self.initdic[@"server_ip_list"];
    NSArray *targetIpArr = [server_ip_list componentsSeparatedByString:@","];
    if (item >= targetIpArr.count) {
        return;
    }
    NSString *targetIp = targetIpArr[item];
//    if (![targetIp containsString:@":"]) {
//        [self traceroutePressed:item + 1];
//        return;
//    }
    [Traceroute startTracerouteWithHost:targetIp
                                  queue:dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)
                           stepCallback:^(TracerouteRecord *record) {
        
    } finish:^(NSArray<TracerouteRecord *> *results, BOOL succeed) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (succeed) {
                NSMutableArray *tmp = [[NSMutableArray alloc] init];
                for (NSInteger i=0; i<results.count; i++) {
                    TracerouteRecord *iItem = results[i];
                    BOOL flag = YES;
                    for (NSInteger j=0; j<tmp.count; j++) {
                        NSString *jItem = tmp[j];
                        if ([iItem.ip isEqualToString:jItem]) {
                            flag = NO;
                            break;
                        }
                    }
                    if (flag && (iItem.ip != nil) && ![iItem.ip isEqualToString:targetIp]) {
                        id first = iItem.recvDurations.firstObject;
                        float time = 0;
                        if ([first isKindOfClass:[NSNumber class]]) {
                            time = [(NSNumber *)first floatValue] * 1000;
                        }
                        NSString *ip = [NSString stringWithFormat:@"%@|%.2f", iItem.ip, time];
                        [tmp addObject:ip];
                    }
                }
                self.tracerouteArr = [NSArray arrayWithArray:tmp];
                NSLog(@"it_%@", self.tracerouteArr);
                
                [self requestInfoAdd:targetIp];
                
            } else {
                NSLog(@"it_error:%@", targetIp);
            }
            [self traceroutePressed:item + 1];
        });
    }];
}


- (void)requestInfoAdd:(NSString *)target_ip {
    
    NSString *client_ip = self.initdic[@"client_ip"];
    long task_id = [self.initdic[@"task_id"] longValue];
    
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    params[@"ip"] = client_ip;
    params[@"task_id"] = @(task_id);
    /// 开启1 关闭2
    params[@"is_vpn"] = @([IpTrace isVPNOn] ? 1 : 2);
    /// 流量1 wifi 2
    params[@"ip_type"] = [[IpTrace getNetconnType] isEqualToString:@"Wifi"] ? @(2) : @(1);
    params[@"longitude"] = [IpTrace shared].longitude;
    params[@"latitude"] = [IpTrace shared].latitude;
    NSString *area = [[IpTrace shared].area stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    params[@"area"] = area;
    
    if (target_ip.length > 0) {
        NSMutableArray *dicArr = [[NSMutableArray alloc] init];
        for (int i = 1; i <= self.tracerouteArr.count; i++) {
            NSString *trace_ip = self.tracerouteArr[i-1];
            NSDictionary *dic = @{@"task_id": @(task_id),
                                  @"original_ip": client_ip,
                                  @"target_ip": target_ip,
                                  @"trace_ip": trace_ip};
            [dicArr addObject:dic];
        }
        
        NSData *dicdata = [NSJSONSerialization dataWithJSONObject:dicArr options:NSJSONWritingPrettyPrinted error:nil];
        NSString *traceroute = [[NSString alloc] initWithData:dicdata encoding:NSUTF8StringEncoding];
        params[@"trace"] = traceroute;
    }

    NSData *data = [NSJSONSerialization dataWithJSONObject:params options:NSJSONWritingPrettyPrinted error:nil];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"it_json = %@", json);
    NSString *sign = [IpTrace aes256_encrypt:json withKey:self.key];
    
    NSString *path = [NSString stringWithFormat:@"%@%@", IpTraceAPI, @"v1/ip_info_add"];
    NSURL *url = [NSURL URLWithString:path];
    //网络请求对象
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 15.0;
    request.HTTPMethod = @"POST";
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [self setRequestHeader:request];
    
    NSDictionary *body = @{@"sign": sign};
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:NSJSONWritingPrettyPrinted error:nil];
    
    NSURLSession *session = [NSURLSession sharedSession];
    //请求任务
    NSURLSessionDataTask * dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error) {
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
            NSLog(@"it_result = %@",result);
            
            NSString *second = self.initdic[@"second"];
            [[NSUserDefaults standardUserDefaults] setInteger:second.intValue forKey:IpTraceSecond];
            [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSince1970] forKey:IpTraceLastTime];
        }
    }];
    [dataTask resume];
}

- (void)setRequestHeader:(NSMutableURLRequest *)request {
    [request setValue:@"ios" forHTTPHeaderField:@"plat"];
    [request setValue:[IpTrace getDeviceId] forHTTPHeaderField:@"device_id"];
    [request setValue:[IpTrace idfa] forHTTPHeaderField:@"idfa"];
    [request setValue:self.channel forHTTPHeaderField:@"channel"];
    double interval = [[NSDate date] timeIntervalSince1970];
    NSString *time = [NSString stringWithFormat:@"%.0f", interval];
    [request setValue:time forHTTPHeaderField:@"time"];
    NSDictionary *infoDic = [[NSBundle mainBundle] infoDictionary];
    NSString *version = infoDic[@"CFBundleShortVersionString"];
    version = [version stringByReplacingOccurrencesOfString:@"." withString:@""];
    [request setValue:version forHTTPHeaderField:@"version"];
}

+ (NSString *)getDeviceId
{
//    NSUUID * currentDeviceUUID = [UIDevice currentDevice].identifierForVendor;
//    NSString * UUIDStr = currentDeviceUUID.UUIDString;
//    return UUIDStr;
    
    NSString *uuid = [[NSUserDefaults standardUserDefaults] objectForKey:IpTraceUUID];
    if (uuid == nil || [uuid isEqualToString:@""]) {
        NSUUID * currentDeviceUUID = [UIDevice currentDevice].identifierForVendor;
        uuid = currentDeviceUUID.UUIDString;
        uuid = [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];
        uuid = [uuid lowercaseString];
        [[NSUserDefaults standardUserDefaults] setObject:uuid forKey:IpTraceUUID];
    }
    return uuid;
}

/// 广告标识
+ (NSString *)idfa {
    NSString *idfa = [[NSUserDefaults standardUserDefaults] stringForKey:IpTraceIdfa];
    if (idfa.length == 0 || [idfa hasSuffix:@"00000000"]) {
        if (@available(iOS 14, *)) {
            [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
                if (status == ATTrackingManagerAuthorizationStatusAuthorized) {
                    NSString *idfa = [[ASIdentifierManager sharedManager] advertisingIdentifier].UUIDString;
                    [[NSUserDefaults standardUserDefaults] setObject:idfa forKey:IpTraceIdfa];
                }
            }];
        } else {
            if ([[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled]) {
                idfa = [[ASIdentifierManager sharedManager] advertisingIdentifier].UUIDString;
                [[NSUserDefaults standardUserDefaults] setObject:idfa forKey:IpTraceIdfa];
                return idfa;
            } else {
                NSLog(@"it_请在设置-隐私-广告中打开广告跟踪功能");
            }
        }
    }
    idfa = [idfa stringByReplacingOccurrencesOfString:@"-" withString:@""];
    return idfa;
}


+ (BOOL)isVPNOn
{
    BOOL flag = NO;
    // need two ways to judge this.
    NSDictionary *dict = CFBridgingRelease(CFNetworkCopySystemProxySettings());
    NSArray *keys = [dict[@"__SCOPED__"] allKeys];
    for (NSString *key in keys) {
        if ([key rangeOfString:@"tap"].location != NSNotFound ||
            [key rangeOfString:@"tun"].location != NSNotFound ||
            [key rangeOfString:@"ipsec"].location != NSNotFound ||
            [key rangeOfString:@"ppp"].location != NSNotFound){
            flag = YES;
            break;
        }
    }
    return flag;
}

+ (NSString *)getNetconnType {

    NSString *netconnType = @"";

    Reachability *reach = [Reachability reachabilityWithHostName:@"www.baidu.com"];

    switch ([reach currentReachabilityStatus]) {
        case NotReachable:// 没有网络
        {
            netconnType = @"no network";
        }
            break;
            
        case ReachableViaWiFi:// Wifi
        {
            netconnType = @"Wifi";
        }
            break;
            
        case ReachableViaWWAN:// 手机自带网络
        {
            netconnType = @"WWAN";
        }
            break;
            
        default:
            break;
    }

    return netconnType;
}


// 加密
+ (NSString *)aes256_encrypt:(NSString *)str withKey:(NSString *)key {
    
    const char *cstr = [str cStringUsingEncoding: NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length: str.length];
    //对数据进行加密
    NSData *result = [IpTrace aes256_encryptData:data withKey:key];
    //转换为2进制字符串
    if (result && result.length > 0) {
        NSString *str = [result base64EncodedStringWithOptions:0];
        return str;
    }
    return nil;
}

// 加密
+ (NSData *)aes256_encryptData:(NSData *)data withKey:(NSString *)key {
    
    char keyPtr[kCCKeySizeAES256 + 1];
    bzero(keyPtr, sizeof(keyPtr));
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    
    NSUInteger dataLength = [data length];
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    size_t numBytesEncrypted = 0;
    
    // IV
    char ivPtr[kCCBlockSizeAES128 + 1];
    bzero(ivPtr, sizeof(ivPtr));
    [key getCString:ivPtr maxLength:sizeof(ivPtr) encoding:NSUTF8StringEncoding];
    
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128,
                                          kCCOptionPKCS7Padding,
                                          keyPtr, kCCBlockSizeAES128, ivPtr,
                                          [data bytes], dataLength,
                                          buffer, bufferSize,
                                          &numBytesEncrypted);
    
    if (cryptStatus == kCCSuccess) {
        NSData *data = [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
        return data;
    }
    
    free(buffer);
    return nil;
}

// 解密
+ (NSString *)aes256_decrypt:(NSString *)str withKey:(NSString *)key {
    NSData *data = [[NSData alloc] initWithBase64EncodedString:str options:0];
    //对数据进行解密
    NSData* result = [IpTrace aes256_decryptData:data withKey:key];
    if (result && result.length > 0) {
        NSString *str = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
        return str;
    }
    return nil;
}

// 解密
+ (NSData *)aes256_decryptData:(NSData *)data withKey:(NSString *)key {
    
    char keyPtr[kCCKeySizeAES256+1];
    bzero(keyPtr, sizeof(keyPtr));
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    
    NSUInteger dataLength = [data length];
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    size_t numBytesDecrypted = 0;
    
    // IV
    char ivPtr[kCCBlockSizeAES128 + 1];
    bzero(ivPtr, sizeof(ivPtr));
    [key getCString:ivPtr maxLength:sizeof(ivPtr) encoding:NSUTF8StringEncoding];
    
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128,
                                          kCCOptionPKCS7Padding,
                                          keyPtr, kCCBlockSizeAES128,
                                          ivPtr,
                                          [data bytes], dataLength,
                                          buffer, bufferSize,
                                          &numBytesDecrypted);
    if (cryptStatus == kCCSuccess) {
        NSData *data = [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
        return data;
    }
    free(buffer);
    return nil;
}

@end
