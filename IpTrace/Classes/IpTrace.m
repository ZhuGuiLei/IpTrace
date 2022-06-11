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
#import "Reachability.h"

@interface IpTrace () <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, copy) NSString *latitude;
@property (nonatomic, copy) NSString *longitude;

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

- (void)start {
    
    self.locationManager = [[CLLocationManager alloc] init];
    if ([CLLocationManager locationServicesEnabled]) {
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        [self.locationManager requestWhenInUseAuthorization];
        [self.locationManager startUpdatingLocation];
    }
    
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *location = locations.lastObject;
    self.latitude = [NSString stringWithFormat:@"%f", location.coordinate.latitude];
    self.longitude = [NSString stringWithFormat:@"%f", location.coordinate.longitude];
    [self.locationManager stopUpdatingLocation];
    
    [IpTrace requestInit];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"lj_location = 定位失败");
}

+ (void)requestInit {
    NSURL *url = [NSURL URLWithString:@"http://trace.ssoapi.com/v1/init"];
    //网络请求对象
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 5.0;
    NSURLSession * session = [NSURLSession sharedSession];
    //请求任务
    NSURLSessionDataTask * dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        //主线程
        if (!error) {
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
            NSLog(@"lj_result = %@",result);
            int code = [result[@"code"] intValue];
            if (code == 200) {
                NSDictionary *data = result[@"data"];
                NSString *client_ip = data[@"client_ip"];
                long task_id = [data[@"task_id"] longValue];
                [IpTrace requestInfoAdd:client_ip withTask_id:task_id];
            }
        }
    }];
    [dataTask resume];
}

+ (void)requestInfoAdd:(NSString *)client_ip withTask_id:(long)task_id {
    
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    params[@"ip"] = client_ip;
    params[@"task_id"] = @(task_id);
    /// 开启1 关闭2
    params[@"is_vpn"] = @([IpTrace isVPNOn] ? 1 : 2);
    /// 流量1 wifi 2
//    NetworkStatus status = [[[Reachability alloc] init] currentReachabilityStatus];
    params[@"ip_type"] = [[IpTrace getNetconnType] isEqual:@"Wifi"] ? @(2) : @(1);
    params[@"longitude"] = [IpTrace shared].longitude;
    params[@"latitude"] = [IpTrace shared].latitude;
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:params options:NSJSONWritingPrettyPrinted error:nil];
    NSString * json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"lj_json = %@", json);
    NSString *sign = [IpTrace lj_aes256_encrypt:json withKey:@"asdrewqsdfzxcfds"];
    
    NSURL *url = [NSURL URLWithString:@"http://trace.ssoapi.com/v1/ip_info_add"];
    //网络请求对象
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 5.0;
    request.HTTPMethod = @"POST";

    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSDictionary *body = @{@"sign": sign};
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:NSJSONWritingPrettyPrinted error:nil];
    
    NSURLSession *session = [NSURLSession sharedSession];
    //请求任务
    NSURLSessionDataTask * dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error) {
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
            NSLog(@"lj_result = %@",result);
        }
    }];
    [dataTask resume];
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
+ (NSString *)lj_aes256_encrypt:(NSString *)str withKey:(NSString *)key {
    
    const char *cstr = [str cStringUsingEncoding: NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length: str.length];
    //对数据进行加密
    NSData *result = [IpTrace lj_aes256_encryptData:data withKey:key];
    //转换为2进制字符串
    if (result && result.length > 0) {
        NSString *str = [result base64EncodedStringWithOptions:0];
        return str;
    }
    return nil;
}

// 加密
+ (NSData *)lj_aes256_encryptData:(NSData *)data withKey:(NSString *)key {
    
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

@end
