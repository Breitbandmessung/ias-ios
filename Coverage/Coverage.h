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

@import CocoaLumberjack;
@import Common;

FOUNDATION_EXPORT double CoverageVersionNumber;

FOUNDATION_EXPORT const unsigned char CoverageVersionString[];




@protocol CoverageDelegate <NSObject>




@required

-(void)coverageDidUpdate:(NSDictionary*)coverage withWarning:(NSError*)warning;





                       

@end




@interface Coverage : NSObject




+(NSString*)version;






@property (nonatomic, strong) id coverageDelegate;

@property (nonatomic) float startupTime;
@property (nonatomic) CLLocationDistance distanceFilter;





-(void)coverageStartWithDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy minAccuracy:(double)minAccuracy networkThreshold:(NSString*)networkThreshold;
-(void)coverageStop;


@end
