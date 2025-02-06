/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Basic demonstration of how to use the SystemConfiguration Reachablity APIs.
 */

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>


typedef enum : NSInteger {
	NotReachable = 0,
	ReachableViaWiFi,
	ReachableViaWWAN
} NetworkStatus;

#pragma mark IPv6 Support



extern NSString *kReachabilityChangedNotification;


@interface Reachability_objc : NSObject


+ (instancetype)reachabilityWithHostName:(NSString *)hostName;


+ (instancetype)reachabilityWithAddress:(const struct sockaddr *)hostAddress;


+ (instancetype)reachabilityForInternetConnection;


#pragma mark reachabilityForLocalWiFi




- (BOOL)startNotifier;
- (void)stopNotifier;

- (NetworkStatus)currentReachabilityStatus;


- (BOOL)connectionRequired;

@end


