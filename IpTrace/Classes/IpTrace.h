//
//  IpTrace.h
//  IpTrace
//
//  Created by apple on 2022/6/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IpTrace : NSObject

+ (instancetype)shared;

/// 启动
/// @param key 密钥
- (void)startWithKey:(NSString *)key;

/// 启动
/// @param key 密钥
/// @param channel 渠道
- (void)startWithKey:(NSString *)key withChannel:(NSString *)channel;

@end

NS_ASSUME_NONNULL_END
