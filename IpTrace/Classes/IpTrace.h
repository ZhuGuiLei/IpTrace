//
//  IpTrace.h
//  IpTrace
//
//  Created by apple on 2022/6/10.
//

#import <Foundation/Foundation.h>

typedef void(^SuccessBlock)(NSDictionary * _Nullable resultDic);
typedef void(^FailBlock)(NSError * _Nullable error);

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

/// 注册sdk套餐专属KEY
/// @param sdkKey 购买sdk套餐专属KEY
/// @param channel 渠道
- (void)registersdkKey:(NSString *)sdkKey withChannel:(NSString *)channel;

/// 注册sdk套餐专属KEY
/// @param sdkKey 购买sdk套餐专属KEY
/// @param key 密钥
/// @param channel  渠道
- (void)registersdkKey:(NSString *)sdkKey withKey:(NSString *)key withChannel:(NSString *)channel;

/// 查询
/// @param searchIP 查询ip
- (void)searchWithIP:(NSString *)searchIP success:(SuccessBlock)successBlock fail:(FailBlock)failBlock;

@end

NS_ASSUME_NONNULL_END
