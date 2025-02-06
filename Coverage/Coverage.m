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

#import "Coverage.h"






#ifdef DEBUG
    static const DDLogLevel ddLogLevel = DDLogLevelDebug;
#else
    static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif




static const float defaultStartupTime                               = 1.0f;
static const float ambiguousAppAccessCategoryUnknownTimerInterval   = 0.5f;
static const long long ambiguousAppAccessCategoryUnknownThreshold   = 40000;




@interface Coverage () <LocationDelegate>



@property (nonatomic, strong) Tool *tool;
@property (nonatomic, strong) NSString *errorDomain;

@property (nonatomic, strong) NSMutableDictionary *libraryKPIs;

@property (nonatomic) double minAccuracy;
@property (nonatomic) bool minAccuracyNotReached;
@property (nonatomic, strong) NSString *networkThreshold;
@property (nonatomic) bool startupStatus;
@property (nonatomic, strong) NSMutableArray *startupLocations;
@property (nonatomic, strong) NSTimer* ambiguousAppAccessCategoryUnknownTimer;
@property (nonatomic) bool appAccessCategoryUnknown;
@property (nonatomic) bool ambiguousAppAccessCategoryUnknown;
@property (nonatomic) long long appAccessCategoryUnknownStartTime;
@property (nonatomic) CLLocation *lastCoverageLocationWithoutWarning;



@end




@implementation Coverage






+(NSString*)version
{
    return [NSBundle bundleWithIdentifier:@"com.zafaco.Coverage"].infoDictionary[@"CFBundleShortVersionString"];
}






-(Coverage*)init
{
    [DDLog removeAllLoggers];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [DDTTYLogger sharedInstance].logFormatter = [LogFormatter new];
    
    self.tool                                       = [Tool new];
    self.errorDomain                                = @"Coverage";
    

    self.startupTime                                = defaultStartupTime;
    
    self.libraryKPIs                                = [NSMutableDictionary new];
    
    NSMutableDictionary *versions = [NSMutableDictionary new];
    [versions setObject:[Coverage version] forKey:@"coverage"];
    [versions setObject:[Common version] forKey:@"common"];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:versions options:0 error:nil];
    
    [self.libraryKPIs setObject:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] forKey:@"app_library_version"];

    DDLogInfo(@"Coverage: Versions: %@", [versions description]);
    
    return self;
}






-(void)coverageStartWithDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy minAccuracy:(double)minAccuracy networkThreshold:(NSString*)networkThreshold
{
    self.startupLocations = [NSMutableArray new];
    self.startupStatus = true;
    [self performSelector:@selector(checkStartup) withObject:nil afterDelay:self.startupTime];

    self.minAccuracy                    = minAccuracy;
    self.minAccuracyNotReached          = true;
    self.networkThreshold               = networkThreshold;
    
    self.tool.locationDelegate  = self;

    [self.tool startUpdatingLocationWithAccuracy:desiredAccuracy distanceFilter:1.0f allowsBackgroundLocationUpdates:true];
    
    self.appAccessCategoryUnknown = false;
    self.ambiguousAppAccessCategoryUnknown = false;
    self.ambiguousAppAccessCategoryUnknownTimer = [NSTimer scheduledTimerWithTimeInterval:ambiguousAppAccessCategoryUnknownTimerInterval target:self selector:@selector(checkAmbiguousAppAccessCategoryUnknown) userInfo:nil repeats:true];
    self.lastCoverageLocationWithoutWarning = nil;

    DDLogInfo(@"Coverage: started with threshold: %@", networkThreshold);
}

-(void)coverageStop
{
    [self stopUpdatingKpis];
    
    DDLogInfo(@"Coverage: stopped");
}






-(NSError*)getWarningWithNetworkData:(NSDictionary*)networkData andAirplaneModeAndGsmOnlyStatus:(NSDictionary*)airplaneModeAndGsmOnlyStatus
{
    NSError *error;
    int errorCode = 0;
    NSString *errorCase = @"";
    
    if ([networkData objectForKey:@"carrier"] && [[[networkData objectForKey:@"carrier"] objectForKey:@"sims_active"] intValue] > 1)
    {
        if (errorCode == 0)
        {
            errorCode = 20;
        }
        errorCase = [NSString stringWithFormat:@"%@|multipleSimCardsActive|", errorCase];
    }


    
    if ([[networkData objectForKey:@"app_mode"] isEqualToString:@"WIFI"])
    {
        if (errorCode == 0)
        {
            errorCode = 22;
        }
        errorCase = [NSString stringWithFormat:@"%@|wifiActive|", errorCase];
    }
    
    if (self.ambiguousAppAccessCategoryUnknown)
    {
        if (errorCode == 0)
        {
            errorCode = 23;
        }
        errorCase = [NSString stringWithFormat:@"%@|ambiguousAppAccessCategoryUnknownOrAirplaneModeOrGsmOnlyActive|", errorCase];
    }
    
    if ([[airplaneModeAndGsmOnlyStatus objectForKey:@"airplaneModeOrGsmOnlyActive"] boolValue] == true && [[airplaneModeAndGsmOnlyStatus objectForKey:@"gsmCallActive"] boolValue] == false)
    {
        if (errorCode == 0)
        {
            errorCode = 24;
        }
        errorCase = [NSString stringWithFormat:@"%@|airplaneModeOrGsmOnlyActive|", errorCase];
    }

    if ([self minAccuracyNotReached])
    {
        if (errorCode == 0)
        {
            errorCode = 25;
        }
        errorCase = [NSString stringWithFormat:@"%@|minAccuracyNotReached|", errorCase];
    }

    
    if (errorCode != 0)
    {
        error = [self.tool getError:errorCode description:[NSString stringWithFormat:@"%@", errorCase] domain:self.errorDomain];
        
        DDLogWarn(@"Coverage: warning: %@", [error.userInfo objectForKey:@"NSLocalizedDescription"]);
    }
    
    return error;
}

-(void)checkStartup
{
    DDLogDebug(@"Coverage: startup completed, got %lu locations", (unsigned long)self.startupLocations.count);
    
    self.startupStatus = false;
    
    if (self.startupLocations.count != 0)
    {

        if (![[self.startupLocations lastObject] objectForKey:@"warning"])
        {

            [[[self.startupLocations lastObject] objectForKey:@"coverage"] setObject:[NSNumber numberWithDouble:0.0] forKey:@"app_distance"];

            self.lastCoverageLocationWithoutWarning = [[self.startupLocations lastObject] objectForKey:@"location"];
        }
        
        [self logCoverage:[[self.startupLocations lastObject] objectForKey:@"coverage"] withWarning:[[self.startupLocations lastObject] objectForKey:@"warning"]];
        [self coverageDidUpdate:[[self.startupLocations lastObject] objectForKey:@"coverage"] withWarning:[[self.startupLocations lastObject] objectForKey:@"warning"]];
    }
}

-(void)logCoverage:(NSDictionary*)coverage withWarning:(NSError*)warning
{
    DDLogDebug(@"Coverage: detected coverage with network: %@ - %@ on Location: lat: %f long: %f acc: %f alt: %f, velocity: %f, call state: %@, warning: %@", [coverage objectForKey:@"app_access_category"], [coverage objectForKey:@"app_access"], [[coverage objectForKey:@"app_latitude"] doubleValue], [[coverage objectForKey:@"app_longitude"] doubleValue], [[coverage objectForKey:@"app_accuracy"] doubleValue], [[coverage objectForKey:@"app_altitude"] doubleValue], [[coverage objectForKey:@"app_velocity"] doubleValue], [coverage objectForKey:@"app_call_state"], [warning.userInfo objectForKey:@"NSLocalizedDescription"]);
}

-(void)stopUpdatingKpis
{
    [self.tool stopUpdatingLocation];
    self.tool.locationDelegate = nil;
    
    [self.ambiguousAppAccessCategoryUnknownTimer invalidate];
    self.ambiguousAppAccessCategoryUnknownTimer = nil;
}

-(void)checkAmbiguousAppAccessCategoryUnknown
{
    NSDictionary *networkData                   = [self.tool getNetworkData];
    NSDictionary *callState                     = [self.tool getCallState];
    NSDictionary *sCNetworkReachabilityFlags    = [self.tool getSCNetworkReachabilityFlags];
    
    if (([[networkData objectForKey:@"app_access_category"] isEqualToString:@"unknown"]) && [[callState objectForKey:@"app_call_state"] intValue] == 0)
    {
        if (self.appAccessCategoryUnknown && !self.ambiguousAppAccessCategoryUnknown && [[sCNetworkReachabilityFlags objectForKey:@"SCNetworkReachabilityFlags"] longValue] == 0 && self.appAccessCategoryUnknownStartTime > 0 && ([[self.tool getCurrentTimestampAsString:false inMs:true] longLongValue]-self.appAccessCategoryUnknownStartTime > ambiguousAppAccessCategoryUnknownThreshold))
        {
            DDLogDebug(@"checkAmbiguousAppAccessCategory: Ambiguous No Net detected");
            self.ambiguousAppAccessCategoryUnknown = true;
        }
        else
        {
            if (self.appAccessCategoryUnknownStartTime == 0)
            {
                self.appAccessCategoryUnknownStartTime = [[self.tool getCurrentTimestampAsString:false inMs:true] longLongValue];
            }
            
            self.appAccessCategoryUnknown = true;
            DDLogDebug(@"checkAmbiguousAppAccessCategory: No Net detected. Time in no net: %lli", [[self.tool getCurrentTimestampAsString:false inMs:true] longLongValue]-self.appAccessCategoryUnknownStartTime);
        }
    }
    else
    {
        self.appAccessCategoryUnknownStartTime = 0;
        self.appAccessCategoryUnknown = false;
        self.ambiguousAppAccessCategoryUnknown = false;
        DDLogDebug(@"checkAmbiguousAppAccessCategory: Net detected");
    }
}






-(void)locationDelegateDidUpdate:(NSArray<CLLocation *> *)locations
{
    if (locations.lastObject.horizontalAccuracy <= self.minAccuracy)
    {
        self.minAccuracyNotReached = false;
        
        NSMutableDictionary *networkData            = (NSMutableDictionary*)[self.tool getNetworkData];
        NSDictionary *callState                     = [self.tool getCallState];
        NSDictionary *sCNetworkReachabilityFlags    = [self.tool getSCNetworkReachabilityFlags];
        NSDictionary *airplaneModeAndGsmOnlyStatus  = [self.tool getAirplaneModeAndGsmOnlyStatusWithNetworkData:networkData andCallState:callState andSCNetworkReachabilityFlags:sCNetworkReachabilityFlags];
        
        NSError *warning                            = [self getWarningWithNetworkData:networkData andAirplaneModeAndGsmOnlyStatus:airplaneModeAndGsmOnlyStatus];
        

        if ([[airplaneModeAndGsmOnlyStatus objectForKey:@"gsmCallActive"] boolValue] == true)
        {
            [networkData setObject:@"2G" forKey:@"app_access"];
            [networkData setObject:[NSNumber numberWithInteger:4] forKey:@"app_access_id"];
            [networkData setObject:@"2G" forKey:@"app_access_category"];
        }
        

        if (
            ([self.networkThreshold containsString:@"unknown"] && ([[networkData objectForKey:@"app_access_category"] isEqualToString:@"unknown"]))
            ||
            ([self.networkThreshold containsString:@"2G"] && ([[networkData objectForKey:@"app_access_category"] isEqualToString:@"unknown"] || [[networkData objectForKey:@"app_access_category"] containsString:@"2G"]))
            ||
            ([self.networkThreshold containsString:@"3G"] && ([[networkData objectForKey:@"app_access_category"] isEqualToString:@"unknown"] || [[networkData objectForKey:@"app_access_category"] containsString:@"2G"] || [[networkData objectForKey:@"app_access_category"] containsString:@"3G"]))
            ||
            ([self.networkThreshold containsString:@"4G"] && ([[networkData objectForKey:@"app_access_category"] isEqualToString:@"unknown"] || [[networkData objectForKey:@"app_access_category"] containsString:@"2G"] || [[networkData objectForKey:@"app_access_category"] containsString:@"3G"] || [[networkData objectForKey:@"app_access_category"] containsString:@"4G"]))
            ||
            ([self.networkThreshold containsString:@"5G"] && ([[networkData objectForKey:@"app_access_category"] isEqualToString:@"unknown"] || [[networkData objectForKey:@"app_access_category"] containsString:@"2G"] || [[networkData objectForKey:@"app_access_category"] containsString:@"3G"] || [[networkData objectForKey:@"app_access_category"] containsString:@"4G"] || [[networkData objectForKey:@"app_access_category"] containsString:@"5G"]))
            )
        {

            DDLogDebug(@"Coverage: Threshold matching Coverage with Network: %@ - %@, accuracy: %f, distanceFromLastCoverageLocationWithoutWarning: %.2f", [networkData objectForKey:@"app_access_category"], [networkData objectForKey:@"app_access"], locations.lastObject.horizontalAccuracy, [locations.lastObject distanceFromLocation:self.lastCoverageLocationWithoutWarning]);
            
            NSMutableDictionary *coverage = [NSMutableDictionary new];
            

            if (!self.lastCoverageLocationWithoutWarning || [locations.lastObject distanceFromLocation:self.lastCoverageLocationWithoutWarning] > self.distanceFilter)
            {
                if (self.lastCoverageLocationWithoutWarning)
                {
                    [coverage setObject:[NSNumber numberWithDouble:[locations.lastObject distanceFromLocation:self.lastCoverageLocationWithoutWarning]] forKey:@"app_distance"];
                }
                else
                {
                    [coverage setObject:[NSNumber numberWithDouble:0.0] forKey:@"app_distance"];
                }
            }
            else
            {
                DDLogWarn(@"Coverage: distance to lastCoverageLocationWithoutWarning: %.2f, distanceFilter: %.2f, discarded", [locations.lastObject distanceFromLocation:self.lastCoverageLocationWithoutWarning], self.distanceFilter);
                return;
            }
            
            if (!warning)
            {
                self.lastCoverageLocationWithoutWarning = locations.lastObject;
            }
            
            [coverage addEntriesFromDictionary:[self.tool getClientOS]];
            [coverage setObject:[self.tool getCurrentTimestampAsString:true inMs:true] forKey:@"app_geo_timestamp"];
            [coverage setObject:[self.tool getCurrentTimezoneAsString:true] forKey:@"app_geo_timezone"];
            
            [coverage addEntriesFromDictionary:self.libraryKPIs];
            
            if ([networkData objectForKey:@"app_mode"])
            {
                [coverage setObject:[networkData objectForKey:@"app_mode"] forKey:@"app_mode"];
            }
            

            if ([[networkData objectForKey:@"app_access"] isEqualToString:@"2G"])
            {
                [coverage setObject:@"WWAN" forKey:@"app_mode"];
            }
            
            [coverage setObject:[networkData objectForKey:@"app_access"] forKey:@"app_access"];
            [coverage setObject:[networkData objectForKey:@"app_access_id"] forKey:@"app_access_id"];
            [coverage setObject:[networkData objectForKey:@"app_access_category"] forKey:@"app_access_category"];
            
            NSMutableDictionary *deviceData = (NSMutableDictionary*)[self.tool getDeviceData];
            [coverage addEntriesFromDictionary:deviceData];
            
            [coverage setObject:[NSNumber numberWithDouble:locations.lastObject.coordinate.latitude]   forKey:@"app_latitude"];
            [coverage setObject:[NSNumber numberWithDouble:locations.lastObject.coordinate.longitude]  forKey:@"app_longitude"];
            [coverage setObject:[NSNumber numberWithDouble:locations.lastObject.horizontalAccuracy]    forKey:@"app_accuracy"];
            [coverage setObject:[NSNumber numberWithDouble:locations.lastObject.altitude]              forKey:@"app_altitude"];
            [coverage setObject:[NSNumber numberWithDouble:locations.lastObject.speed]                 forKey:@"app_velocity"];
            
            [coverage setObject:[callState objectForKey:@"app_call_state"] forKey:@"app_call_state"];
            
            if (locations.lastObject.speed < 0)
            {
                [coverage setObject:[NSNumber numberWithDouble:0] forKey:@"app_velocity"];
            }
            else
            {
                [coverage setObject:[NSNumber numberWithDouble:locations.lastObject.speed] forKey:@"app_velocity"];
            }
            
            [coverage setObject:[networkData objectForKey:@"app_mode"] forKey:@"reachable"];
            [coverage setObject:[networkData objectForKey:@"app_access_id"] forKey:@"radio"];
            [coverage setObject:[NSNumber numberWithLongLong:[[sCNetworkReachabilityFlags objectForKey:@"SCNetworkReachabilityFlags"] longLongValue]] forKey:@"flags"];


            if (self.startupStatus)
            {
                NSMutableDictionary *startupLocation = [NSMutableDictionary new];
                [startupLocation setObject:coverage forKey:@"coverage"];
                
                if (warning)
                {
                    [startupLocation setObject:warning forKey:@"warning"];
                }
                
                [startupLocation setObject:locations.lastObject forKey:@"location"];
                
                [self.startupLocations addObject:startupLocation];
                
                return;
            }
            
            [self logCoverage:coverage withWarning:warning];
            
            [self coverageDidUpdate:coverage withWarning:warning];
        }
        else
        {

            DDLogDebug(@"Coverage: Threshold not matched");
        }
    }
    else
    {
        self.minAccuracyNotReached = true;
    }
}






-(void)coverageDidUpdate:(NSDictionary*)coverage withWarning:(NSError*)warning
{
    dispatch_async(dispatch_get_main_queue(), ^
                   {
                       if (self.coverageDelegate && [self.coverageDelegate respondsToSelector:@selector(coverageDidUpdate:withWarning:)])
                       {
                           [self.coverageDelegate coverageDidUpdate:coverage withWarning:warning];
                       }
                   });
}


@end
