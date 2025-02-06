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

#import "SpeedViewController.h"







#ifdef DEBUG
    static const DDLogLevel ddLogLevel = DDLogLevelDebug;
#else
    static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif



@interface SpeedViewController () <SpeedDelegate>




@property (weak, nonatomic) IBOutlet UIButton *stopButton;
@property (weak, nonatomic) IBOutlet UIButton *clearButton;
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UIButton *startRttButton;
@property (weak, nonatomic) IBOutlet UIButton *startDownloadButton;
@property (weak, nonatomic) IBOutlet UIButton *startUploadButton;

@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UILabel *rttLabel;
@property (weak, nonatomic) IBOutlet UILabel *downloadLabel;
@property (weak, nonatomic) IBOutlet UILabel *uploadLabel;

@property (weak, nonatomic) IBOutlet UITextView *kpisTextView;






@property (nonatomic, strong) Speed *speed;
@property (nonatomic, strong) Tool *tool;
@property (nonatomic, strong) CLLocationManager *locationManager;

@end




@implementation SpeedViewController






- (IBAction)stopButtonTouched:(id)sender
{
    self.stopButton.enabled = false;
    [self measurementStop];
}

- (IBAction)clearButtonTouched:(id)sender
{
    self.stopButton.enabled                     = false;
    self.clearButton.enabled                    = false;
    self.startButton.enabled                    = true;
    self.startRttButton.enabled                 = true;
    self.startDownloadButton.enabled            = true;
    self.startUploadButton.enabled              = true;
    
    [self clearUI];
}

- (IBAction)startButtonTouched:(id)sender
{
    [self measurementStartWithTestCaseRtt:true withTestCaseDownload:true withTestCaseUpload:true];
}

- (IBAction)startRttButtonTouched:(id)sender
{
    [self measurementStartWithTestCaseRtt:true withTestCaseDownload:false withTestCaseUpload:false];
}

- (IBAction)startDownloadButtonTouched:(id)sender
{
    [self measurementStartWithTestCaseRtt:false withTestCaseDownload:true withTestCaseUpload:false];
}

- (IBAction)startUploadButtonTouched:(id)sender
{
    [self measurementStartWithTestCaseRtt:false withTestCaseDownload:false withTestCaseUpload:true];
}

-(void)showKpisFromResponse:(NSDictionary*)response
{
    if (response)
    {
        NSString *kpis = response.description;
        
        NSDictionary *mappedKPIs = [self.tool mapKPIs:response];
        kpis = mappedKPIs.description;
        
        kpis = [kpis stringByReplacingOccurrencesOfString:@";" withString:@""];
        self.kpisTextView.text = kpis;
        
        NSString *cmd = [response objectForKey:@"cmd"];
        
        if ([cmd isEqualToString:@"info"] || [cmd isEqualToString:@"finish"] || [cmd isEqualToString:@"completed"])
        {
            self.statusLabel.text = [NSString stringWithFormat:@"%@: %@", [response objectForKey:@"test_case"], [response objectForKey:@"msg"]];
        }
        
        if ([cmd isEqualToString:@"report"] || [cmd isEqualToString:@"finish"] || [cmd isEqualToString:@"completed"])
        {
            if ([[response objectForKey:@"test_case"] isEqualToString:@"rtt_udp"])
            {
                self.rttLabel.text = [NSString stringWithFormat:@"%.3f ms", [[[response objectForKey:@"rtt_udp_info"] objectForKey:@"average_ns"] doubleValue] / 1e6];
            }
            if ([[response objectForKey:@"test_case"] isEqualToString:@"download"])
            {
                self.downloadLabel.text = [NSString stringWithFormat:@"%@ Mbit/s", [self.tool formatNumberToCommaSeperatedString:[NSNumber numberWithDouble:([[[[response objectForKey:@"download_info"] lastObject] objectForKey:@"throughput_avg_bps"] doubleValue] / 1e6)] withMinDecimalPlaces:2 withMaxDecimalPlace:2]];
            }
            if ([[response objectForKey:@"test_case"] isEqualToString:@"upload"])
            {
                self.uploadLabel.text = [NSString stringWithFormat:@"%@ Mbit/s", [self.tool formatNumberToCommaSeperatedString:[NSNumber numberWithDouble:([[[[response objectForKey:@"upload_info"] lastObject] objectForKey:@"throughput_avg_bps"] doubleValue] / 1e6)] withMinDecimalPlaces:2 withMaxDecimalPlace:2]];
            }
        }
    }
}






-(void)measurementStartWithTestCaseRtt:(bool)rtt withTestCaseDownload:(bool)download withTestCaseUpload:(bool)upload
{
    self.speed                              = nil;
    self.speed                              = [Speed new];

    self.speed.speedDelegate                = self;
    
    self.tool                               = nil;
    self.tool                               = [Tool new];
    
    self.stopButton.enabled                 = true;
    
    [self clearUI];
    
    DDLogInfo(@"Measurement started");
    self.statusLabel.text = @"Measurement started";
    


    self.speed.targets = [NSArray arrayWithObjects:@"peer.example.com", nil];
    
    self.speed.performRttUdpMeasurement     = rtt;
    self.speed.performDownloadMeasurement   = download;
    self.speed.performUploadMeasurement     = upload;
    self.speed.performRouteToClientLookup   = true;
    self.speed.performGeolocationLookup     = true;
    

    
    self.stopButton.enabled                     = true;
    self.clearButton.enabled                    = false;
    self.startButton.enabled                    = false;
    self.startRttButton.enabled                 = false;
    self.startDownloadButton.enabled            = false;
    self.startUploadButton.enabled              = false;
    
    [self.speed measurementStart];
}

-(void)measurementStop
{
    [self.speed measurementStop];
}






-(void)measurementCallbackWithResponse:(NSDictionary *)response
{
    [self showKpisFromResponse:response];
}

-(void)measurementDidCompleteWithResponse:(NSDictionary *)response withError:(NSError *)error
{
    [self showKpisFromResponse:response];
    
    if (error)
    {
        DDLogError(@"Measurement failed with Error: %@", [error.userInfo objectForKey:@"NSLocalizedDescription"]);
        self.statusLabel.text = [error.userInfo objectForKey:@"NSLocalizedDescription"];
    }
    else
    {
        DDLogInfo(@"Measurement successful");
        self.statusLabel.text = @"Measurement successful";
    }

    self.stopButton.enabled         = false;
    self.clearButton.enabled        = true;
}

-(void)measurementDidStop
{
    DDLogInfo(@"Measurement stopped");
    self.statusLabel.text = @"Measurement stopped";
    

    self.stopButton.enabled         = false;
    self.clearButton.enabled        = true;
}






- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [DDLog removeAllLoggers];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [DDTTYLogger sharedInstance].logFormatter = [LogFormatter new];
    
    self.locationManager = [CLLocationManager new];
    if ([self.locationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined || [self.locationManager authorizationStatus] == kCLAuthorizationStatusDenied || [self.locationManager authorizationStatus] == kCLAuthorizationStatusRestricted)
    {
        [self.locationManager requestWhenInUseAuthorization];
    }
    
    DDLogInfo(@"Demo: Version %@", [NSString stringWithFormat:@"%@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]]);
    
    self.stopButton.enabled                     = false;
    self.clearButton.enabled                    = false;
    self.startButton.enabled                    = true;
    self.startRttButton.enabled                 = true;
    self.startDownloadButton.enabled            = true;
    self.startUploadButton.enabled              = true;
    
    [self clearUI];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

-(void)clearUI
{
    self.statusLabel.text       = @"-";
    self.rttLabel.text          = @"-";
    self.downloadLabel.text     = @"-";
    self.uploadLabel.text       = @"-";
    
    self.kpisTextView.text      = @"";
}

@end
