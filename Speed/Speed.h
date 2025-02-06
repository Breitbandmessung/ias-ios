/*
    Copyright (C) 2016-2025 zafaco GmbH

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License version 3
    as published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "ios_connector.h"

@import CocoaLumberjack;
@import Common;

FOUNDATION_EXPORT double SpeedVersionNumber;

FOUNDATION_EXPORT const unsigned char SpeedVersionString[];




@protocol SpeedDelegate <NSObject>




@required

-(void)measurementCallbackWithResponse:(NSDictionary*)response;
-(void)measurementDidCompleteWithResponse:(NSDictionary*)response withError:(NSError*)error;
-(void)measurementDidStop;

@end




@interface Speed : NSObject




+(NSString*)version;






@property (nonatomic, strong) id speedDelegate;

@property (nonatomic, strong) NSArray *targets;
@property (nonatomic, strong) NSString *targetPort;
@property (nonatomic, strong) NSString *targetPortRtt;
@property (nonatomic) NSInteger tls;

@property (nonatomic) bool performRttUdpMeasurement;
@property (nonatomic) bool performDownloadMeasurement;
@property (nonatomic) bool performUploadMeasurement;
@property (nonatomic) bool performRouteToClientLookup;
@property (nonatomic) bool performGeolocationLookup;

@property (nonatomic) NSInteger routeToClientTargetPort;

@property (nonatomic, strong) NSNumber *parallelStreamsDownload;
@property (nonatomic, strong) NSNumber *parallelStreamsUpload;






-(void)measurementStart;
-(void)measurementStop;

@end
