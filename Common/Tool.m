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

#import "Tool.h"
#include <CommonCrypto/CommonDigest.h>






#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelDebug;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif




@interface Tool () <CLLocationManagerDelegate>




@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) NSMutableArray<CLLocation *> *locations;
@property (nonatomic, retain) UIView *activityIndicatorView;
@property (nonatomic, retain) UIActivityIndicatorView *activityIndicator;

@end




@implementation Tool




-(Tool*)init
{
    [DDLog removeAllLoggers];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [DDTTYLogger sharedInstance].logFormatter = [LogFormatter new];
    
    return self;
}

-(bool)networkReachable
{
    if ([[self networkStatus] isEqualToString:@"-"])
    {
        return false;
    }
    
    return true;
}

-(NSString*)networkStatus
{
    NetworkStatus networkStatus = [[Reachability_objc reachabilityForInternetConnection] currentReachabilityStatus];
    
    if (networkStatus == ReachableViaWiFi)
    {
        return @"WIFI";
    }
    else if (networkStatus == ReachableViaWWAN)
    {
        return @"WWAN";
    }
    

    return @"-";
}

-(NSError*)getError:(long)errorCode description:(NSString*)errorDescription domain:(NSString*)errorDomain
{
    NSDictionary *errorDict = @{NSLocalizedDescriptionKey: errorDescription};
    
    return [[NSError alloc] initWithDomain:errorDomain code:errorCode userInfo:errorDict];
}

-(NSError*)getNetworkReachableErrorWithDomain:(NSString*)domain
{
    return [self getError:1 description:@"Network unreachable" domain:domain];
}

-(NSError*)getHttpErrorWithStatusCode:(long)statusCode domain:(NSString*)domain
{
    return [self getError:statusCode description:[NSString stringWithFormat:@"HTTP Response %li", statusCode] domain:domain];
}

-(NSError*)getHttpErrorWithMalformedUrl:(NSURL*)url domain:(NSString*)domain
{
    return [self getError:2 description:[NSString stringWithFormat:@"Malformed URL: %@", [url absoluteString]] domain:domain];
}

-(NSError *)getScriptingErrorWithDescription:(NSString*)errorDescription domain:(NSString*)errorDomain
{
    return [self getError:30 description:[NSString stringWithFormat:@"Scripting: %@", errorDescription] domain:errorDomain];
}

-(NSString*)formatNumberToCommaSeperatedString:(NSNumber*)number withMinDecimalPlaces:(int)min withMaxDecimalPlace:(int)max
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle= NSNumberFormatterDecimalStyle;
    formatter.locale = [NSLocale currentLocale];
    [formatter setMinimumFractionDigits:min];
    [formatter setMaximumFractionDigits:max];
    
    return [NSString stringWithFormat:@"%@", [formatter stringForObjectValue:number]];
}

-(NSDictionary*)getDeviceData
{
    NSMutableDictionary *deviceData = [NSMutableDictionary new];
    
    [deviceData setObject:@"Apple" forKey:@"app_manufacturer"];
    [deviceData setObject:[self getCurrentDeviceModelName] forKey:@"app_manufacturer_version"];
    
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    [deviceData setObject:[NSNumber numberWithInt:([UIDevice currentDevice].batteryLevel * 100)] forKey:@"app_battery_level"];
    [UIDevice currentDevice].batteryMonitoringEnabled = NO;
    
    return (NSDictionary*)deviceData;
}

-(NSDictionary*)getAirplaneModeAndGsmOnlyStatusWithNetworkData:(NSDictionary*)networkData andCallState:(NSDictionary*)callState andSCNetworkReachabilityFlags:(NSDictionary*)sCNetworkReachabilityFlags
{


    

    

    
    NSMutableDictionary *airplaneModeAndGsmOnlyStatus = [NSMutableDictionary new];
    [airplaneModeAndGsmOnlyStatus setObject:[NSNumber numberWithBool:false] forKey:@"airplaneModeOrGsmOnlyActive"];
    [airplaneModeAndGsmOnlyStatus setObject:[NSNumber numberWithBool:false] forKey:@"gsmCallActive"];
    
    if ([[sCNetworkReachabilityFlags objectForKey:@"SCNetworkReachabilityFlagsStatus"] boolValue] && [[sCNetworkReachabilityFlags objectForKey:@"SCNetworkReachabilityFlags"] longLongValue] == 0)
    {
        [airplaneModeAndGsmOnlyStatus setObject:[NSNumber numberWithBool:true] forKey:@"airplaneModeOrGsmOnlyActive"];
        DDLogDebug(@"getAirplaneModeAndGsmOnlyStatus: !reachability, Airplane Mode active or GSM-only connection");
    }
    
    if ([[callState objectForKey:@"app_call_state"] intValue] == 1 && [[networkData objectForKey:@"app_access_id"] intValue] == 0)
    {
        [airplaneModeAndGsmOnlyStatus setObject:[NSNumber numberWithBool:true] forKey:@"gsmCallActive"];
        DDLogDebug(@"getAirplaneModeAndGsmOnlyStatus: ActiveCall on GSM-only connection");
    }
    
    return airplaneModeAndGsmOnlyStatus;
}

-(NSDictionary*)getSCNetworkReachabilityFlags
{
    SCNetworkReachabilityRef reachabilityRef = SCNetworkReachabilityCreateWithName(NULL, [@"example.com" UTF8String]);
    SCNetworkReachabilityFlags flags;
    bool SCNetworkReachabilityFlagsStatus = false;
    SCNetworkReachabilityFlagsStatus = SCNetworkReachabilityGetFlags(reachabilityRef, &flags);
    CFRelease(reachabilityRef);
    
    NSMutableDictionary* sCNetworkReachabilityFlags = [NSMutableDictionary new];
    [sCNetworkReachabilityFlags setObject:[NSNumber numberWithBool:SCNetworkReachabilityFlagsStatus] forKey:@"SCNetworkReachabilityFlagsStatus"];
    [sCNetworkReachabilityFlags setObject:[NSNumber numberWithLongLong:flags] forKey:@"SCNetworkReachabilityFlags"];
    NSLog(@"%i", flags);
    return sCNetworkReachabilityFlags;
}



-(NSDictionary*)getCarrierData
{
    NSMutableDictionary *carrierData = [NSMutableDictionary new];
    CTTelephonyNetworkInfo *telephonyNetworkInfo = [CTTelephonyNetworkInfo new];
    int simsActive = 0;
    

    NSMutableArray *aSimArray = [NSMutableArray new];
    

    
    for (NSString *key in telephonyNetworkInfo.serviceSubscriberCellularProviders)
    {
        NSMutableDictionary *aSim = [NSMutableDictionary new];
        [aSim setObject:key forKey:@"serviceSubscriberCellularProvidersKey"];
        

        if ([telephonyNetworkInfo.dataServiceIdentifier isEqualToString:key])
        {
            [aSim setObject:[NSNumber numberWithBool:true] forKey:@"data_active"];
        } else
        {
            [aSim setObject:[NSNumber numberWithBool:false] forKey:@"data_active"];
        }
        

        for (NSString *currentRadioKey in telephonyNetworkInfo.serviceCurrentRadioAccessTechnology)
        {

            if ([currentRadioKey isEqualToString:key])
            {
                simsActive++;
                [aSimArray addObject:aSim];
            }
        }
    }
    [carrierData setObject:aSimArray forKey:@"sims_available"];
    [carrierData setObject:[NSNumber numberWithInt:simsActive] forKey:@"sims_active"];
    
    return (NSDictionary*)carrierData;
}

-(NSDictionary*)getNetworkData
{
    NSMutableDictionary *networkData = [NSMutableDictionary new];
    
    [networkData setObject:[self networkStatus] forKey:@"app_mode"];
    [networkData setObject:[self getCarrierData] forKey:@"carrier"];
    NSDictionary *activeSim;
    NSArray *aSimArray = [[networkData objectForKey:@"carrier"] objectForKey:@"sims_available"];
    
    for (NSDictionary *aSim in aSimArray)
    {
        if ([[aSim objectForKey:@"data_active"] boolValue] )
        {
            activeSim = aSim;
            break;
        }
    }


    NSString *serviceSubscriberCellularProvidersKey = [activeSim objectForKey:@"serviceSubscriberCellularProvidersKey"];
    
    NSDictionary *currentRadioAccessTechnology = [self getCurrentRadioAccessTechnologyWithServiceSubscriberCellularProvidersKey:serviceSubscriberCellularProvidersKey];
    [networkData setObject:[currentRadioAccessTechnology objectForKey:@"app_access"] forKey:@"app_access"];
    [networkData setObject:[currentRadioAccessTechnology objectForKey:@"app_access_id"] forKey:@"app_access_id"];
    [networkData setObject:[currentRadioAccessTechnology objectForKey:@"app_access_category"] forKey:@"app_access_category"];
    
    return networkData;
}

-(NSDictionary*)getCurrentRadioAccessTechnologyWithServiceSubscriberCellularProvidersKey:(NSString*)serviceSubscriberCellularProvidersKey;
{
    CTTelephonyNetworkInfo *telephonyNetworkInfo = [CTTelephonyNetworkInfo new];
    NSMutableDictionary *currentRadioAccessTechnology = [NSMutableDictionary new];
    [currentRadioAccessTechnology setObject:[NSNumber numberWithInteger:0] forKey:@"app_access_id"];
    [currentRadioAccessTechnology setObject:@"unknown" forKey:@"app_access"];
    [currentRadioAccessTechnology setObject:@"unknown" forKey:@"app_access_category"];
    NSString *currentRadioAccessTechnologyString = [telephonyNetworkInfo.serviceCurrentRadioAccessTechnology objectForKey:serviceSubscriberCellularProvidersKey];

    

    if ([telephonyNetworkInfo.dataServiceIdentifier isEqualToString:serviceSubscriberCellularProvidersKey]) {
        [currentRadioAccessTechnology setObject:[NSNumber numberWithInteger:1] forKey:@"app_access_data"];
    } else {
        [currentRadioAccessTechnology setObject:[NSNumber numberWithInteger:0] forKey:@"app_access_data"];
    }
    

    if ([currentRadioAccessTechnologyString isEqualToString:@"CTRadioAccessTechnologyGPRS"])
    {
        [currentRadioAccessTechnology setObject:[NSNumber numberWithInteger:1] forKey:@"app_access_id"];
        [currentRadioAccessTechnology setObject:@"GPRS" forKey:@"app_access"];
        [currentRadioAccessTechnology setObject:@"2G" forKey:@"app_access_category"];
    }
    else if ([currentRadioAccessTechnologyString isEqualToString:@"CTRadioAccessTechnologyEdge"])
    {
        [currentRadioAccessTechnology setObject:[NSNumber numberWithInteger:2] forKey:@"app_access_id"];
        [currentRadioAccessTechnology setObject:@"EDGE" forKey:@"app_access"];
        [currentRadioAccessTechnology setObject:@"2G" forKey:@"app_access_category"];
    }
    else if ([currentRadioAccessTechnologyString isEqualToString:@"CTRadioAccessTechnologyCDMA1x"])
    {
        [currentRadioAccessTechnology setObject:[NSNumber numberWithInteger:4] forKey:@"app_access_id"];
        [currentRadioAccessTechnology setObject:@"CDMA" forKey:@"app_access"];
        [currentRadioAccessTechnology setObject:@"2G" forKey:@"app_access_category"];
    }
    

    else if ([currentRadioAccessTechnologyString isEqualToString:@"CTRadioAccessTechnologyWCDMA"])
    {
        [currentRadioAccessTechnology setObject:[NSNumber numberWithInteger:5] forKey:@"app_access_id"];
        [currentRadioAccessTechnology setObject:@"EVDO revision 0" forKey:@"app_access"];
        [currentRadioAccessTechnology setObject:@"3G" forKey:@"app_access_category"];
    }
    else if ([currentRadioAccessTechnologyString isEqualToString:@"CTRadioAccessTechnologyCDMAEVDORev0"])
    {
        [currentRadioAccessTechnology setObject:[NSNumber numberWithInteger:5] forKey:@"app_access_id"];
        [currentRadioAccessTechnology setObject:@"EVDO revision 0" forKey:@"app_access"];
        [currentRadioAccessTechnology setObject:@"3G" forKey:@"app_access_category"];
    }
    else if ([currentRadioAccessTechnologyString isEqualToString:@"CTRadioAccessTechnologyCDMAEVDORevA"])
    {
        [currentRadioAccessTechnology setObject:[NSNumber numberWithInteger:6] forKey:@"app_access_id"];
        [currentRadioAccessTechnology setObject:@"EVDO revision A" forKey:@"app_access"];
        [currentRadioAccessTechnology setObject:@"3G" forKey:@"app_access_category"];
    }
    else if ([currentRadioAccessTechnologyString isEqualToString:@"CTRadioAccessTechnologyCDMAEVDORevB"])
    {
        [currentRadioAccessTechnology setObject:[NSNumber numberWithInteger:12] forKey:@"app_access_id"];
        [currentRadioAccessTechnology setObject:@"EVDO revision B" forKey:@"app_access"];
        [currentRadioAccessTechnology setObject:@"3G" forKey:@"app_access_category"];
    }
    else if ([currentRadioAccessTechnologyString isEqualToString:@"CTRadioAccessTechnologyHSUPA"])
    {
        [currentRadioAccessTechnology setObject:[NSNumber numberWithInteger:9] forKey:@"app_access_id"];
        [currentRadioAccessTechnology setObject:@"HSUPA" forKey:@"app_access"];
        [currentRadioAccessTechnology setObject:@"3G" forKey:@"app_access_category"];
    }
    else if ([currentRadioAccessTechnologyString isEqualToString:@"CTRadioAccessTechnologyHSDPA"])
    {
        [currentRadioAccessTechnology setObject:[NSNumber numberWithInteger:8] forKey:@"app_access_id"];
        [currentRadioAccessTechnology setObject:@"HSDPA" forKey:@"app_access"];
        [currentRadioAccessTechnology setObject:@"3G" forKey:@"app_access_category"];
    }
    else if ([currentRadioAccessTechnologyString isEqualToString:@"CTRadioAccessTechnologyeHRPD"])
    {
        [currentRadioAccessTechnology setObject:[NSNumber numberWithInteger:14] forKey:@"app_access_id"];
        [currentRadioAccessTechnology setObject:@"eHRPD" forKey:@"app_access"];
        [currentRadioAccessTechnology setObject:@"3G" forKey:@"app_access_category"];
    }
    

    else if ([currentRadioAccessTechnologyString isEqualToString:@"CTRadioAccessTechnologyLTE"])
    {
        [currentRadioAccessTechnology setObject:[NSNumber numberWithInteger:13] forKey:@"app_access_id"];
        [currentRadioAccessTechnology setObject:@"LTE" forKey:@"app_access"];
        [currentRadioAccessTechnology setObject:@"4G" forKey:@"app_access_category"];
    }
    

    else if ([currentRadioAccessTechnologyString isEqualToString:@"CTRadioAccessTechnologyNRNSA"])
    {
        [currentRadioAccessTechnology setObject:[NSNumber numberWithInteger:19] forKey:@"app_access_id"];
        [currentRadioAccessTechnology setObject:@"NRNSA" forKey:@"app_access"];
        [currentRadioAccessTechnology setObject:@"5G" forKey:@"app_access_category"];
    }
    else if ([currentRadioAccessTechnologyString isEqualToString:@"CTRadioAccessTechnologyNR"])
    {
        [currentRadioAccessTechnology setObject:[NSNumber numberWithInteger:20] forKey:@"app_access_id"];
        [currentRadioAccessTechnology setObject:@"NR" forKey:@"app_access"];
        [currentRadioAccessTechnology setObject:@"5G" forKey:@"app_access_category"];
    }
    
    return (NSDictionary*)currentRadioAccessTechnology;
}

-(void)startActivityIndicatorOnView:(id)view withFrame:(CGRect)frame withBackgroundColor:(UIColor*)color withActivityIndicatorStyle:(UIActivityIndicatorViewStyle)style
{
    self.activityIndicatorView = [[UIView alloc] initWithFrame:frame];
    self.activityIndicatorView.backgroundColor = color;


    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:style];
    self.activityIndicator.center = self.activityIndicatorView.center;
    [self.activityIndicatorView addSubview:self.activityIndicator];
    [self.activityIndicator startAnimating];
    [view addSubview:self.activityIndicatorView];
}

-(void)stopActivityIndicatorOnView:(id)view
{
    [self.activityIndicator stopAnimating];
    [self.activityIndicatorView removeFromSuperview];
    
    self.activityIndicator      = nil;
    self.activityIndicatorView  = nil;
}

-(long long)getCurrentTimestampInMicroseconds
{
    return [[NSDate date] timeIntervalSince1970] * 1000 * 1000;
}

-(id)getCurrentTimestampAsString:(bool)string inMs:(bool)ms
{
    double timestamp = [[NSDate date] timeIntervalSince1970];
    
    if (ms)
    {
        timestamp *= 1000;
    }
    long long timestampLongLong = timestamp;
    
    if (string)
    {
        return [NSString stringWithFormat:@"%lli", timestampLongLong];
    }
    
    if (!string)
    {
        return [NSNumber numberWithLongLong:timestampLongLong];
    }
    
    return @"-";
}

-(NSString*)getCurrentTimestampAsFormattedDateString
{
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    
    return [dateFormat stringFromDate:[NSDate date]];
}

-(id)getCurrentTimezoneAsString:(bool)string
{
    NSDate *currentDate = [NSDate date];
    NSTimeZone *systemTimeZone = [NSTimeZone systemTimeZone];
    NSInteger currentTimezone = [systemTimeZone secondsFromGMTForDate:currentDate];
    
    if (string)
    {
        return [NSString stringWithFormat:@"%li", currentTimezone];
    }
    
    if (!string)
    {
        return [NSNumber numberWithInteger:currentTimezone];
    }
    
    return @"-";
}

-(NSDictionary*)getClientOS
{
    UIDevice *currentDevice = [UIDevice currentDevice];
    
    return @{
        @"client_os": [currentDevice systemName],
        @"client_os_version": [currentDevice systemVersion]
    };
}

-(NSNumber*)formatNumberToKb:(NSNumber*)number unit:(NSString *)unit
{
    long factor = 1;
    

    if ([unit caseInsensitiveCompare:@"mbit/s"] == NSOrderedSame)
    {
        factor = 1000;
    }
    

    else
        if ([unit caseInsensitiveCompare:@"kb"] == NSOrderedSame)
        {
            factor = 1;
        }
        else
            if ([unit caseInsensitiveCompare:@"mb"] == NSOrderedSame)
            {
                factor = 1000;
            }
            else
                if ([unit caseInsensitiveCompare:@"gb"] == NSOrderedSame)
                {
                    factor = 1000000;
                }
    
    return [NSNumber numberWithDouble:([number doubleValue] * factor)];
}

-(NSString*)generateRandomStringWithSize:(NSUInteger)size
{
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    
    NSMutableString *randomString = [NSMutableString stringWithCapacity:size];
    
    for (int i = 0; i < size; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: (long)arc4random_uniform((uint32_t)[letters length])]];
    }
    
    return randomString;
}

-(NSNumber*)getPowerSaveState
{
    if ([[NSProcessInfo processInfo] isLowPowerModeEnabled])
    {
        return [NSNumber numberWithInt:1];
    }
    
    return [NSNumber numberWithInt:0];
}

-(NSNumber*)getThermalState
{
    NSProcessInfoThermalState thermalState = [NSProcessInfo processInfo].thermalState;
    
    if (thermalState == NSProcessInfoThermalStateNominal || thermalState == NSProcessInfoThermalStateFair)
    {
        return [NSNumber numberWithInt:0];
    }
    
    return [NSNumber numberWithInt:1];
}

-(NSDictionary*)getCallState
{
    NSMutableDictionary *callState = [NSMutableDictionary new];
    [callState setObject:[NSNumber numberWithBool:false] forKey:@"call"];
    [callState setObject:[NSNumber numberWithBool:false] forKey:@"hasEnded"];
    [callState setObject:[NSNumber numberWithBool:false] forKey:@"hasConnected"];
    [callState setObject:[NSNumber numberWithBool:false] forKey:@"isOutgoing"];
    [callState setObject:@"-" forKey:@"state"];
    [callState setObject:[NSNumber numberWithInt:0] forKey:@"app_call_state"];
    
    CXCallObserver *callObserver = [CXCallObserver new];
    
    if ([[callObserver calls] count] > 0)
    {
        CXCall *call = [[callObserver calls] objectAtIndex:0];
        
        if (call)
        {
            [callState setObject:[NSNumber numberWithBool:true] forKey:@"call"];
        }
        if (call.hasEnded)
        {
            [callState setObject:[NSNumber numberWithBool:true] forKey:@"hasEnded"];
        }
        if (call.hasConnected)
        {
            [callState setObject:[NSNumber numberWithBool:true] forKey:@"hasConnected"];
        }
        if (call.isOutgoing)
        {
            [callState setObject:[NSNumber numberWithBool:true] forKey:@"isOutgoing"];
        }
        
        if (call == nil || call.hasEnded == YES)
        {
            [callState setObject:@"disconnected" forKey:@"state"];
            [callState setObject:[NSNumber numberWithInt:0] forKey:@"app_call_state"];
            DDLogDebug(@"CXCallState : Disconnected");
        }
        if (call.isOutgoing == YES && call.hasConnected == NO)
        {
            [callState setObject:@"dialing" forKey:@"state"];
            [callState setObject:[NSNumber numberWithInt:1] forKey:@"app_call_state"];
            DDLogDebug(@"CXCallState : Dialing");
        }
        if (call.isOutgoing == NO  && call.hasConnected == NO && call.hasEnded == NO && call != nil)
        {
            [callState setObject:@"incoming" forKey:@"state"];
            [callState setObject:[NSNumber numberWithInt:1] forKey:@"app_call_state"];
            DDLogDebug(@"CXCallState : Incoming");
        }
        if (call.hasConnected == YES && call.hasEnded == NO)
        {
            [callState setObject:@"connected" forKey:@"state"];
            [callState setObject:[NSNumber numberWithInt:1] forKey:@"app_call_state"];
            DDLogDebug(@"CXCallState : Connected");
        }
    }
    
    return callState;
}


-(NSNumber*)getPreciseLocationPermissionState
{
    if (self.locationManager == nil)
    {
        self.locationManager = [CLLocationManager new];
    }
    if([self.locationManager authorizationStatus] == kCLAuthorizationStatusDenied )
    {
        return nil;
    }
    if (self.locationManager.accuracyAuthorization == CLAccuracyAuthorizationReducedAccuracy)
    {
        return [NSNumber numberWithBool:false];
        
    } else
    {
        return [NSNumber numberWithBool:true];
    }

    return nil;
}

-(NSDictionary*)mapKPIs:(NSDictionary*)kpis
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"mapping_ias" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSDictionary *mappingIas = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
    

    NSMutableDictionary *mappedKPIs = [kpis mutableCopy];
    [mappedKPIs removeObjectsForKeys:[NSArray arrayWithObjects:@"peer_info", @"ip_info", @"time_info", @"rtt_udp_info", @"download_info", @"download_raw_data", @"upload_info", @"upload_raw_data", nil]];

    for (NSString *topLevelKey in mappingIas)
    {
        if ([[[mappingIas objectForKey:topLevelKey] objectForKey:@"type"] isEqualToString:@"object"])
        {
            for (NSDictionary *secondLevelKey in [[mappingIas objectForKey:topLevelKey] objectForKey:@"mappings"])
            {
                id object = nil;
                
                if ([[kpis objectForKey:topLevelKey] objectForKey:[secondLevelKey objectForKey:@"old_key"]])
                {
                    object = [[kpis objectForKey:topLevelKey] objectForKey:[secondLevelKey objectForKey:@"old_key"]];
                }

                if (object != nil && [secondLevelKey objectForKey:@"convert"])
                {
                    object = [NSNumber numberWithDouble:[object doubleValue] / [[secondLevelKey objectForKey:@"convert"] doubleValue]];
                }
                
                if (object != nil)
                {
                    [mappedKPIs setObject:object forKey:[secondLevelKey objectForKey:@"new_key"]];
                    
                }
            }
        }
        else if ([[[mappingIas objectForKey:topLevelKey] objectForKey:@"type"] isEqualToString:@"array"])
        {
            for (NSDictionary *secondLevelKey in [[mappingIas objectForKey:topLevelKey] objectForKey:@"mappings"])
            {
                id object = nil;
                
                if ([[secondLevelKey objectForKey:@"type"] isEqualToString:@"last"])
                {
                    if ([[[kpis objectForKey:topLevelKey] lastObject] objectForKey:[secondLevelKey objectForKey:@"old_key"]])
                    {
                        object = [[[kpis objectForKey:topLevelKey] lastObject] objectForKey:[secondLevelKey objectForKey:@"old_key"]];
                    }
                    
                    if (object != nil && [secondLevelKey objectForKey:@"convert"])
                    {
                        object = [NSNumber numberWithDouble:[object doubleValue] / [[secondLevelKey objectForKey:@"convert"] doubleValue]];
                    }
                    
                    if (object != nil)
                    {
                        [mappedKPIs setObject:object forKey:[secondLevelKey objectForKey:@"new_key"]];
                    }
                }
                else if ([[secondLevelKey objectForKey:@"type"] isEqualToString:@"min"])
                {
                    double min = MAXFLOAT;
                    
                    for (NSDictionary* iterator in [kpis objectForKey:topLevelKey])
                    {
                        if ([[iterator objectForKey:[secondLevelKey objectForKey:@"old_key_divider"]] doubleValue] != 0)
                        {
                            double throughput = ([[iterator objectForKey:[secondLevelKey objectForKey:@"old_key"]] doubleValue] * [[secondLevelKey objectForKey:@"convert_multiplier"] doubleValue]) / ([[iterator objectForKey:[secondLevelKey objectForKey:@"old_key_divider"]] doubleValue] / [[secondLevelKey objectForKey:@"convert"] doubleValue]);
                            
                            if (throughput < min)
                            {
                                min = throughput;
                            }
                        }
                    }
                    
                    if ([[kpis objectForKey:topLevelKey] count] > 0 && min != MAXFLOAT)
                    {
                        [mappedKPIs setObject:[NSNumber numberWithDouble:min] forKey:[secondLevelKey objectForKey:@"new_key"]];
                    }
                }
                else if ([[secondLevelKey objectForKey:@"type"] isEqualToString:@"max"])
                {
                    double max = -1;
                    
                    for (NSDictionary* iterator in [kpis objectForKey:topLevelKey])
                    {
                        if ([[iterator objectForKey:[secondLevelKey objectForKey:@"old_key_divider"]] doubleValue] != 0)
                        {
                            double throughput = ([[iterator objectForKey:[secondLevelKey objectForKey:@"old_key"]] doubleValue] * [[secondLevelKey objectForKey:@"convert_multiplier"] doubleValue]) / ([[iterator objectForKey:[secondLevelKey objectForKey:@"old_key_divider"]] doubleValue] / [[secondLevelKey objectForKey:@"convert"] doubleValue]);
                            
                            if (throughput > max)
                            {
                                max = throughput;
                            }
                        }
                    }
                    
                    if ([[kpis objectForKey:topLevelKey] count] > 0 && max != -1)
                    {
                        [mappedKPIs setObject:[NSNumber numberWithDouble:max] forKey:[secondLevelKey objectForKey:@"new_key"]];
                    }
                }
                else if ([[secondLevelKey objectForKey:@"type"] isEqualToString:@"array"])
                {
                    NSMutableArray *mappedArray = [NSMutableArray new];
                    
                    int i = 1;
                    
                    for (NSDictionary* element in [kpis objectForKey:topLevelKey])
                    {
                        NSMutableDictionary *mappedDict = [NSMutableDictionary new];
                        
                        for (NSDictionary* thirdLevelKey in [secondLevelKey objectForKey:@"mappings"])
                        {
                            if ([element objectForKey:[thirdLevelKey objectForKey:@"old_key"]])
                            {
                                [mappedDict setValue:[element objectForKey:[thirdLevelKey objectForKey:@"old_key"]] forKey:[thirdLevelKey objectForKey:@"new_key"]];
                            }
                            
                            if ([mappedDict objectForKey:[thirdLevelKey objectForKey:@"new_key"]] != nil && [thirdLevelKey objectForKey:@"convert"])
                            {
                                [mappedDict setValue:[NSNumber numberWithDouble:[[mappedDict objectForKey:[thirdLevelKey objectForKey:@"new_key"]] doubleValue] / [[thirdLevelKey objectForKey:@"convert"] doubleValue]] forKey:[thirdLevelKey objectForKey:@"new_key"]];
                            }
                            
                            if ([thirdLevelKey objectForKey:@"new_key"] != nil && [[thirdLevelKey objectForKey:@"type"] isEqualToString:@"index"])
                            {
                                [mappedDict setValue:[NSNumber numberWithInt:i] forKey:[thirdLevelKey objectForKey:@"new_key"]];
                            }
                        }
                        
                        [mappedArray addObject:mappedDict];
                        i++;
                    }
                    
                    if (mappedArray.count > 0)
                    {
                        [mappedKPIs setObject:[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:mappedArray options:0 error:nil] encoding:NSUTF8StringEncoding] forKey:[secondLevelKey objectForKey:@"new_key"]];
                    }
                }
            }
        }
    }
    return mappedKPIs;
}






-(void)startUpdatingLocationWithAccuracy:(CLLocationAccuracy)accuracy distanceFilter:(CLLocationDistance)distanceFilter allowsBackgroundLocationUpdates:(bool)allowsBackgroundLocationUpdates
{
    self.locationManager    = [CLLocationManager new];
    self.locations          = [NSMutableArray new];
    
    if ([self.locationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined)
    {
        [self.locationManager requestWhenInUseAuthorization];
        [self.locationManager requestAlwaysAuthorization];
    }
    self.locationManager.delegate           = self;
    self.locationManager.distanceFilter     = distanceFilter;
    self.locationManager.desiredAccuracy    = accuracy;
    if (allowsBackgroundLocationUpdates)
    {
        self.locationManager.allowsBackgroundLocationUpdates = true;
        self.locationManager.pausesLocationUpdatesAutomatically = false;
    }
    
    [self.locationManager startUpdatingLocation];

}

-(void)setDistanceFilter:(CLLocationDistance)distanceFilter
{
    self.locationManager.distanceFilter = distanceFilter;
}

-(void)stopUpdatingLocation
{
    [self.locationManager stopUpdatingLocation];

    
    self.locationManager = nil;
}






-(void)locationDelegateDidUpdate:(NSArray<CLLocation *> *)locations
{
    dispatch_async(dispatch_get_main_queue(), ^
                   {
        if (self.locationDelegate)
        {
            [self.locationDelegate locationDelegateDidUpdate:locations];
        }
    });
}






-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    [self.locations addObject:locations.lastObject];
    
    [self locationDelegateDidUpdate:self.locations];
}






-(NSString*)getCurrentDeviceModelName
{
    struct utsname systemInfo;
    uname(&systemInfo);
    
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

@end
