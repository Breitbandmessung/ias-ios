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

#import "Speed.h"






#ifdef DEBUG
    static const DDLogLevel ddLogLevel = DDLogLevelDebug;
#else
    static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif




static NSString *const defaultTargetPort                    = @"443";
static NSString *const defaultTargetPortRtt                 = @"80";
static NSInteger const defaultTls                           = 1;

static const bool defaultPerformRttUdpMeasurement           = true;
static const bool defaultPerformDownloadMeasuement          = true;
static const bool defaultPerformUploadMeasurement           = true;
static const bool defaultPerformRouteToClientLookup         = false;
static const bool defaultPerformGeolocationLookup           = true;

static const NSInteger defaultRouteToClientTargetPort       = 8443;




@interface Speed () <LocationDelegate, HttpRequestDelegate>




@property (nonatomic, strong) Tool *tool;
@property (nonatomic, strong) NSString *errorDomain;

@property (nonatomic, strong) NSMutableDictionary *deviceKPIs;
@property (nonatomic, strong) NSMutableDictionary *locationKPIs;
@property (nonatomic, strong) NSMutableDictionary *libraryKPIs;
@property (nonatomic, strong) NSMutableDictionary *radioKPIs;

@property (nonatomic) bool downloadRunning;
@property (nonatomic) bool uploadRunning;
@property (nonatomic) bool measurementSuccessful;

@property (nonatomic, strong) Http *httpRequest;

@property (nonatomic) bool performedRouteToClientLookup;
@property (nonatomic, strong) NSURL *routeToClientLookupUrl;

@property (nonatomic, strong) NSMutableDictionary *rttParameters;
@property (nonatomic, strong) NSMutableDictionary *downloadParameters;
@property (nonatomic, strong) NSMutableDictionary *uploadParameters;

@property (nonatomic, strong) NSTimer *appVelocityAvgUpdateTimer;
@property (nonatomic) float appVelocityAvgUpdateInterval;
@property (nonatomic) float appVelocityAvgUpdateInitialDelay;
@property (nonatomic, strong) NSMutableArray *appVelocityAvgArray;
@property (nonatomic, strong) NSNumber* appVelocityCurrent;

@property (nonatomic, strong) IosConnector *iosConnector;

@end




@implementation Speed






+(NSString*)version
{
    return [NSBundle bundleWithIdentifier:@"com.zafaco.Speed"].infoDictionary[@"CFBundleShortVersionString"];
}






-(Speed*)init
{
    [DDLog removeAllLoggers];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [DDTTYLogger sharedInstance].logFormatter = [LogFormatter new];
    
    self.tool                                       = [Tool new];
    self.errorDomain                                = @"Speed";

    self.httpRequest                                = [Http new];
    self.httpRequest.httpRequestDelegate            = self;
    

    self.targets                                    = [NSArray arrayWithObjects:@"peer.example.com", nil];
    self.targetPort                                 = defaultTargetPort;
    self.targetPortRtt                              = defaultTargetPortRtt;
    self.tls                                        = defaultTls;
    
    self.performRttUdpMeasurement                   = defaultPerformRttUdpMeasurement;
    self.performDownloadMeasurement                 = defaultPerformDownloadMeasuement;
    self.performUploadMeasurement                   = defaultPerformUploadMeasurement;
    self.performRouteToClientLookup                 = defaultPerformRouteToClientLookup;
    self.performGeolocationLookup                   = defaultPerformGeolocationLookup;
    self.routeToClientTargetPort                    = defaultRouteToClientTargetPort;
    
    self.deviceKPIs                                 = [NSMutableDictionary new];
    self.locationKPIs                               = [NSMutableDictionary new];
    self.libraryKPIs                                = [NSMutableDictionary new];
    self.radioKPIs                                  = [NSMutableDictionary new];
    
    self.downloadRunning                            = false;
    self.uploadRunning                              = false;
    self.measurementSuccessful                      = false;
    
    self.rttParameters                              = [NSMutableDictionary new];
    self.downloadParameters                         = [NSMutableDictionary new];
    self.uploadParameters                           = [NSMutableDictionary new];
    
    NSMutableDictionary *versions = [NSMutableDictionary new];
    [versions setObject:[Speed version] forKey:@"speed"];
    [versions setObject:[Common version] forKey:@"common"];
    
    [self removeObserver];
    
    DDLogInfo(@"Speed: Versions: %@", [versions description]);
    
    return self;
}






-(void)measurementStart
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication sharedApplication].idleTimerDisabled = true;
    });
    
    if (!self.tool.networkReachable)
    {
        NSError *error = [self.tool getNetworkReachableErrorWithDomain:self.errorDomain];
        DDLogError(@"MeasurementStart failed with Error: %@", [error.userInfo objectForKey:@"NSLocalizedDescription"]);
        
        [self measurementDidCompleteWithResponse:nil withError:error];
        
        return;
    }
    
    DDLogInfo(@"Measurement started");
    
    [self.libraryKPIs setObject:[self.tool getCurrentTimestampAsFormattedDateString] forKey:@"date"];
    [self.libraryKPIs addEntriesFromDictionary:[self.tool getClientOS]];
  
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    if (self.performGeolocationLookup)
    {
        self.tool.locationDelegate = self;
        [self.tool startUpdatingLocationWithAccuracy:kCLLocationAccuracyBest distanceFilter:kCLDistanceFilterNone allowsBackgroundLocationUpdates:false];
        
        self.appVelocityAvgArray = [NSMutableArray new];
        self.appVelocityAvgUpdateTimer = [NSTimer new];
        self.appVelocityAvgUpdateInterval = 1.0;
        self.appVelocityAvgUpdateInitialDelay = 10.0;
        
        self.appVelocityAvgUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:self.appVelocityAvgUpdateInitialDelay
                                                                       target:self
                                                                     selector:@selector(startAppVelocityAvgUpdate)
                                                                     userInfo:nil
                                                                      repeats:false];
    }
    
    [self.deviceKPIs addEntriesFromDictionary:[self.tool getDeviceData]];
    [self.radioKPIs addEntriesFromDictionary:[self.tool getNetworkData]];
    [self.radioKPIs removeObjectForKey:@"carrier"];
    
    NSMutableDictionary *measurementParametersDict  = [NSMutableDictionary new];
    
    [measurementParametersDict setObject:self.targets                           forKey:@"wsTargets"];
    [measurementParametersDict setObject:self.targetPort                        forKey:@"wsTargetPort"];
    [measurementParametersDict setObject:self.targetPortRtt                     forKey:@"wsTargetPortRtt"];
    [measurementParametersDict setObject:[NSNumber numberWithInteger:self.tls]  forKey:@"wsWss"];
    
    [self.rttParameters setObject:[NSNumber numberWithBool:self.performRttUdpMeasurement] forKey:@"performMeasurement"];
    [self.downloadParameters setObject:[NSNumber numberWithBool:self.performDownloadMeasurement] forKey:@"performMeasurement"];
    [self.uploadParameters setObject:[NSNumber numberWithBool:self.performUploadMeasurement] forKey:@"performMeasurement"];

    if (self.parallelStreamsDownload)
    {
        [self.downloadParameters setObject:self.parallelStreamsDownload forKey:@"streams"];
    }
    if (self.parallelStreamsUpload)
    {
        [self.uploadParameters setObject:self.parallelStreamsUpload forKey:@"streams"];
    }
    
    [measurementParametersDict setObject:self.rttParameters forKey:@"rtt"];
    [measurementParametersDict setObject:self.downloadParameters forKey:@"download"];
    [measurementParametersDict setObject:self.uploadParameters forKey:@"upload"];
    
    self.iosConnector = [IosConnector new];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void)
    {
        [self.iosConnector start:(NSDictionary*)measurementParametersDict callback:^(NSDictionary<NSString *,id> * _Nonnull json) {
            
            NSMutableDictionary *report = [json mutableCopy];
            
            NSString *cmd = [report objectForKey:@"cmd"];
            
            NSDictionary *networkData = [self.tool getNetworkData];
            

            if (self.performDownloadMeasurement && [[report objectForKey:@"test_case"] isEqualToString:@"download"] && [[report objectForKey:@"msg"] isEqualToString:@"starting measurement"])
            {
                self.downloadRunning = true;
            }
            if (self.performUploadMeasurement && [[report objectForKey:@"test_case"] isEqualToString:@"upload"] && [[report objectForKey:@"msg"] isEqualToString:@"starting measurement"])
            {
                self.uploadRunning = true;
            }
            

            


            if (self.performRttUdpMeasurement && [[report objectForKey:@"test_case"] isEqualToString:@"rtt_udp"] && [[report objectForKey:@"msg"] isEqualToString:@"starting measurement"])
            {
                [self.radioKPIs setObject:[networkData objectForKey:@"app_access_id"] forKey:@"app_access_id_rtt_udp_start"];
                [self.radioKPIs setObject:[self.tool networkStatus] forKey:@"app_mode_rtt_udp_start"];
            }

            if (self.performDownloadMeasurement && [[report objectForKey:@"test_case"] isEqualToString:@"download"] && [[report objectForKey:@"msg"] isEqualToString:@"starting measurement"])
            {
                [self.radioKPIs setObject:[networkData objectForKey:@"app_access_id"] forKey:@"app_access_id_download_start"];
                [self.radioKPIs setObject:[self.tool networkStatus] forKey:@"app_mode_download_start"];
            }

            if (self.performUploadMeasurement && [[report objectForKey:@"test_case"] isEqualToString:@"upload"] && [[report objectForKey:@"msg"] isEqualToString:@"starting measurement"])
            {
                [self.radioKPIs setObject:[networkData objectForKey:@"app_access_id"] forKey:@"app_access_id_upload_start"];
                [self.radioKPIs setObject:[self.tool networkStatus] forKey:@"app_mode_upload_start"];
            }
            
            


            if (![self.radioKPIs objectForKey:@"app_access_id_rtt_udp_changed"] && self.performRttUdpMeasurement && [[report objectForKey:@"test_case"] isEqualToString:@"rtt_udp"] && ([cmd isEqualToString:@"report"] || [cmd isEqualToString:@"finish"]))
            {
                if ((long)[self.radioKPIs objectForKey:@"app_access_id_rtt_udp_start"] != (long)[networkData objectForKey:@"app_access_id"])
                {
                    [self.radioKPIs setObject:[NSNumber numberWithInt:1] forKey:@"app_access_id_rtt_udp_changed"];
                }
            }

            if (![self.radioKPIs objectForKey:@"app_mode_rtt_udp_changed"] && self.performRttUdpMeasurement && [[report objectForKey:@"test_case"] isEqualToString:@"rtt_udp"] && ([cmd isEqualToString:@"report"] || [cmd isEqualToString:@"finish"]))
            {
                if (![[self.radioKPIs objectForKey:@"app_mode_rtt_udp_start"] isEqualToString:[self.tool networkStatus]])
                {
                    [self.radioKPIs setObject:[NSNumber numberWithInt:1] forKey:@"app_mode_rtt_udp_changed"];
                }
            }

            if (![self.radioKPIs objectForKey:@"app_access_id_download_changed"] && self.performDownloadMeasurement && [[report objectForKey:@"test_case"] isEqualToString:@"download"] && ([cmd isEqualToString:@"report"] || [cmd isEqualToString:@"finish"]))
            {
                if ((long)[self.radioKPIs objectForKey:@"app_access_id_download_start"] != (long)[networkData objectForKey:@"app_access_id"])
                {
                    [self.radioKPIs setObject:[NSNumber numberWithInt:1] forKey:@"app_access_id_download_changed"];
                }
            }

            if (![self.radioKPIs objectForKey:@"app_mode_download_changed"] && self.performDownloadMeasurement && [[report objectForKey:@"test_case"] isEqualToString:@"download"] && ([cmd isEqualToString:@"report"] || [cmd isEqualToString:@"finish"]))
            {
                if (![[self.radioKPIs objectForKey:@"app_mode_download_start"] isEqualToString:[self.tool networkStatus]])
                {
                    [self.radioKPIs setObject:[NSNumber numberWithInt:1] forKey:@"app_mode_download_changed"];
                }
            }

            if (![self.radioKPIs objectForKey:@"app_access_id_upload_changed"] && self.performUploadMeasurement && [[report objectForKey:@"test_case"] isEqualToString:@"upload"] && ([cmd isEqualToString:@"report"] || [cmd isEqualToString:@"finish"]))
            {
                if ((long)[self.radioKPIs objectForKey:@"app_access_id_upload_start"] != (long)[networkData objectForKey:@"app_access_id"])
                {
                    [self.radioKPIs setObject:[NSNumber numberWithInt:1] forKey:@"app_access_id_upload_changed"];
                }
            }

            if (![self.radioKPIs objectForKey:@"app_mode_upload_changed"] && self.performUploadMeasurement && [[report objectForKey:@"test_case"] isEqualToString:@"upload"] && ([cmd isEqualToString:@"report"] || [cmd isEqualToString:@"finish"]))
            {
                if (![[self.radioKPIs objectForKey:@"app_mode_upload_start"] isEqualToString:[self.tool networkStatus]])
                {
                    [self.radioKPIs setObject:[NSNumber numberWithInt:1] forKey:@"app_mode_upload_changed"];
                }
            }
            
            
            [self.radioKPIs setObject:[networkData objectForKey:@"app_access"] forKey:@"app_access"];
            [self.radioKPIs setObject:[networkData objectForKey:@"app_access_id"] forKey:@"app_access_id"];
            
            if ([networkData objectForKey:@"app_mode"])
            {
                [self.radioKPIs setObject:[networkData objectForKey:@"app_mode"] forKey:@"app_mode"];
            }
            
            

            if (self.performDownloadMeasurement && [[report objectForKey:@"test_case"] isEqualToString:@"download"] && [[report objectForKey:@"msg"] isEqualToString:@"starting measurement"])
            {
                if (self.performRouteToClientLookup && !self.performedRouteToClientLookup)
                {
                    [self routeToClientLookupWithReport:(NSDictionary*)report];
                }
            }
            else if (!self.performDownloadMeasurement && self.performUploadMeasurement && [[report objectForKey:@"test_case"] isEqualToString:@"upload"] && [[report objectForKey:@"msg"] isEqualToString:@"starting measurement"])
            {
                if (self.performRouteToClientLookup && !self.performedRouteToClientLookup)
                {
                    [self routeToClientLookupWithReport:(NSDictionary*)report];
                }
            }
            
            if ([[networkData objectForKey:@"carrier"] objectForKey:@"sims_active"])
            {
                [self.radioKPIs setObject:[NSNumber numberWithInt:[[[networkData objectForKey:@"carrier"] objectForKey:@"sims_active"] intValue]] forKey:@"app_sims_active"];
            }


            if (![self.radioKPIs objectForKey:@"app_call_state"])
            {
                [self.radioKPIs setObject:[[self.tool getCallState] objectForKey:@"app_call_state"] forKey:@"app_call_state"];
            }

            if ([[[self.tool getCallState] objectForKey:@"app_call_state"] intValue] == 1)
            {
                [self.radioKPIs setObject:[[self.tool getCallState] objectForKey:@"app_call_state"] forKey:@"app_call_state"];
            }
            

            if (![self.deviceKPIs objectForKey:@"app_thermal_state"])
            {
                [self.deviceKPIs setObject:[self.tool getThermalState] forKey:@"app_thermal_state"];
            }

            if ([[self.tool getThermalState] intValue] == 1)
            {
                [self.deviceKPIs setObject:[NSNumber numberWithInt:1] forKey:@"app_thermal_state"];
            }
            

            if (![self.deviceKPIs objectForKey:@"app_power_save_state"])
            {
                [self.deviceKPIs setObject:[self.tool getPowerSaveState] forKey:@"app_power_save_state"];
            }

            if ([[self.tool getPowerSaveState] intValue] == 1)
            {
                [self.deviceKPIs setObject:[NSNumber numberWithInt:1] forKey:@"app_power_save_state"];
            }
            
            NSDictionary *locationKPIsCopy = [NSDictionary dictionaryWithDictionary:[self.locationKPIs copy]];
            
            [report addEntriesFromDictionary:self.deviceKPIs];
            [report addEntriesFromDictionary:locationKPIsCopy];
            [report addEntriesFromDictionary:self.libraryKPIs];
            [report addEntriesFromDictionary:self.radioKPIs];
            
            if ([cmd isEqualToString:@"completed"] || [cmd isEqualToString:@"error"])
            {
                NSError *error = nil;
                
                if ([cmd isEqualToString:@"error"])
                {
                    error = [self.tool getError:[[report objectForKey:@"error_code"] longValue] description:[NSString stringWithFormat:@"%@: %@", [report objectForKey:@"test_case"], [report objectForKey:@"msg"]] domain:self.errorDomain];
                    
                    DDLogError(@"Measurement failed with Error: %@", [error.userInfo objectForKey:@"NSLocalizedDescription"]);
                }
                else
                {
                    self.measurementSuccessful = true;
                    DDLogInfo(@"Measurement successful");
                }
                
                [self measurementDidCompleteWithResponse:(NSDictionary*)report withError:error];
            }
            else
            {

                [self measurementCallbackWithResponse:(NSDictionary*)report];
            }
        }];
    });
}

-(void)measurementStop
{
    [self.iosConnector stop];
    
    DDLogInfo(@"Measurement stopped");
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void)
    {
        [self measurementDidStop];
    });
}






-(void)startAppVelocityAvgUpdate
{
    [self appVelocityAvgUpdate];
    
    [self.appVelocityAvgUpdateTimer invalidate];
    self.appVelocityAvgUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:self.appVelocityAvgUpdateInterval
                                                                   target:self
                                                                 selector:@selector(appVelocityAvgUpdate)
                                                                 userInfo:nil
                                                                  repeats:true];
}

-(void)appVelocityAvgUpdate
{
    if (self.appVelocityCurrent != nil)
    {
        [self.appVelocityAvgArray addObject:self.appVelocityCurrent];
        
        double appVelocitySum = 0.0;
        
        for (NSNumber* appVelocity in self.appVelocityAvgArray)
        {
            appVelocitySum += [appVelocity doubleValue];
        }
        
        double appVelocityAvg = appVelocitySum / [self.appVelocityAvgArray count];
        

        
        [self.locationKPIs setObject:[NSNumber numberWithDouble:appVelocityAvg] forKey:@"app_velocity_avg"];
    }
}

-(void)stopUpdatingKpis
{
    [self.tool stopUpdatingLocation];
    self.tool.locationDelegate = nil;
    
    [self.appVelocityAvgUpdateTimer invalidate];
    
    [self removeObserver];
}

-(void)removeObserver
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
}

-(void)routeToClientLookupWithReport:(NSDictionary*)report
{
    self.performedRouteToClientLookup = true;
    
    NSString *routeToClientLookupUrl = [NSString new];
    
    if ([[report objectForKey:@"peer_info"] objectForKey:@"url"])
    {
        NSString *http = @"https";
        if (!self.tls)
        {
            self.routeToClientTargetPort = 8080;
            http = @"http";
        }
        
        routeToClientLookupUrl = [NSString stringWithFormat:@"%@://%@:%li/", http, [[report objectForKey:@"peer_info"] objectForKey:@"url"], self.routeToClientTargetPort];
        self.routeToClientLookupUrl = [NSURL URLWithString:routeToClientLookupUrl];
        
        NSMutableDictionary *routeToClientRequestData = [NSMutableDictionary dictionaryWithObject:@"traceroute" forKey:@"cmd"];
        
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:routeToClientRequestData options:kNilOptions error:nil];
        
        NSMutableDictionary *header = [NSMutableDictionary new];
        [header setObject:@"application/json" forKey:@"Content-Type"];
        [header setObject:@"" forKey:@"Origin"];
        
        self.httpRequest = [Http new];
        self.httpRequest.httpRequestDelegate = self;
        self.httpRequest.httpRequestTimeout = 15.0f;
        
        [self.httpRequest httpRequestToUrl:self.routeToClientLookupUrl type:@"POST" header:header body:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]];
    }
}

- (void)applicationDidEnterBackground
{
    [self.libraryKPIs setObject:[NSNumber numberWithInt:1] forKey:@"app_suspended"];
}






-(void)httpRequestToUrl:(NSURL *)url response:(NSURLResponse *)response data:(NSData *)data didCompleteWithError:(NSError *)error
{
    if (url == self.routeToClientLookupUrl)
    {
        if (!error)
        {
            @try
            {
                NSDictionary *routeToClient = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                
                if ([routeToClient objectForKey:@"hops"])
                {
                    NSMutableArray *hops = [[routeToClient objectForKey:@"hops"] mutableCopy];
                    
                    if ([hops count] > 2)
                    {
                        [hops removeLastObject];
                        [hops removeLastObject];
                        
                        if ([hops lastObject] && [[hops lastObject] objectForKey:@"id"])
                        {
                            [self.libraryKPIs setObject:[[hops lastObject] objectForKey:@"id"] forKey:@"server_client_route_hops"];
                            [self.libraryKPIs setObject:[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:hops options:0 error:nil] encoding:NSUTF8StringEncoding] forKey:@"server_client_route"];
                        }
                    }
                }
            }
            @catch(NSException *exception)
            {
                
            }
        }
    }
}






-(void)locationDelegateDidUpdate:(NSArray<CLLocation *> *)locations
{

    if (locations.lastObject.speed < 0)
    {
        self.appVelocityCurrent = [NSNumber numberWithDouble:0];
    }
    else
    {
        self.appVelocityCurrent = [NSNumber numberWithDouble:locations.lastObject.speed];
    }
    

    if ((locations.lastObject.horizontalAccuracy <= [[self.locationKPIs objectForKey:@"app_accuracy"] doubleValue]) || [[self.locationKPIs objectForKey:@"app_accuracy"] doubleValue] == 0.0)
    {
        [self.locationKPIs setObject:[NSNumber numberWithDouble:locations.lastObject.coordinate.latitude]   forKey:@"app_latitude"];
        [self.locationKPIs setObject:[NSNumber numberWithDouble:locations.lastObject.coordinate.longitude]  forKey:@"app_longitude"];
        [self.locationKPIs setObject:[NSNumber numberWithDouble:locations.lastObject.horizontalAccuracy]    forKey:@"app_accuracy"];
        [self.locationKPIs setObject:[NSNumber numberWithDouble:locations.lastObject.altitude]              forKey:@"app_altitude"];
        
        if (locations.lastObject.speed < 0)
        {
            [self.locationKPIs setObject:[NSNumber numberWithDouble:0] forKey:@"app_velocity"];
        }
        else
        {
            [self.locationKPIs setObject:[NSNumber numberWithDouble:locations.lastObject.speed] forKey:@"app_velocity"];
        }
        if (self.tool.getPreciseLocationPermissionState != nil )
        {
            [self.locationKPIs setObject: self.tool.getPreciseLocationPermissionState forKey:@"app_precise_location_permission"];
        }
        

        if (![self.locationKPIs valueForKey:@"app_velocity_max"])
        {
            [self.locationKPIs setObject:[NSNumber numberWithDouble:0] forKey:@"app_velocity_max"];
        }
        if ([[self.locationKPIs valueForKey:@"app_velocity_max"] doubleValue] <= (double)locations.lastObject.speed)
        {
            [self.locationKPIs setObject:[NSNumber numberWithDouble:locations.lastObject.speed] forKey:@"app_velocity_max"];
        }
        

        if (![self.locationKPIs valueForKey:@"app_altitude_max"])
        {
            [self.locationKPIs setObject:[NSNumber numberWithDouble:0] forKey:@"app_altitude_max"];
        }
        if ([[self.locationKPIs valueForKey:@"app_altitude_max"] doubleValue] <= (double)locations.lastObject.altitude)
        {
            [self.locationKPIs setObject:[NSNumber numberWithDouble:locations.lastObject.altitude]  forKey:@"app_altitude_max"];
        }
    }
}






-(void)measurementCallbackWithResponse:(NSDictionary*)response
{
    dispatch_async(dispatch_get_main_queue(), ^
                   {
                       if (self.speedDelegate && [self.speedDelegate respondsToSelector:@selector(measurementCallbackWithResponse:)])
                       {
                           [self.speedDelegate measurementCallbackWithResponse:response];
                       }
                   });
}

-(void)measurementDidCompleteWithResponse:(NSDictionary*)response withError:(NSError*)error
{
    sleep(2.0);
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication sharedApplication].idleTimerDisabled = false;
    });
    
    [self stopUpdatingKpis];

    dispatch_async(dispatch_get_main_queue(), ^
                   {
                       if (self.speedDelegate && [self.speedDelegate respondsToSelector:@selector(measurementDidCompleteWithResponse:withError:)])
                       {
                           [self.speedDelegate measurementDidCompleteWithResponse:response withError:error];
                       }
                   });
}

-(void)measurementDidStop
{
    sleep(2.0);
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication sharedApplication].idleTimerDisabled = false;
    });
    
    [self stopUpdatingKpis];

    dispatch_async(dispatch_get_main_queue(), ^
                   {
                       if (self.speedDelegate && [self.speedDelegate respondsToSelector:@selector(measurementDidStop)])
                       {
                           [self.speedDelegate measurementDidStop];
                       }
                   });
}

@end
