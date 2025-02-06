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
#import "Tool.h"

@import CocoaLumberjack;




@protocol HttpRequestDelegate <NSObject>



@required
-(void)httpRequestToUrl:(NSURL *)url response:(NSURLResponse *)response data:(NSData *)data didCompleteWithError:(NSError *)error;
@end




@interface Http : NSObject






@property (nonatomic) NSTimeInterval httpRequestTimeout;
@property (nonatomic, strong) id httpRequestDelegate;






-(void)httpRequestToUrl:(NSURL*)url type:(NSString*)type header:(NSDictionary*)header body:(NSString*)body;


@end
