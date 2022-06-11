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
- (void)start;

@end

NS_ASSUME_NONNULL_END
