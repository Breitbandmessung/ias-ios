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

#import "CoverageViewController.h"







#ifdef DEBUG
    static const DDLogLevel ddLogLevel = DDLogLevelDebug;
#else
    static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif




@interface CoverageViewController () <CoverageDelegate>




@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UITextView *kpisTextView;
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;






@property (nonatomic, strong) Coverage *coverage;
@property (nonatomic, strong) Tool *tool;
@property (nonatomic, strong) NSString *coverageLog;
@property (nonatomic, strong) NSMutableArray *coverageMeasurementPoints;
@property (nonatomic, strong) NSMutableArray *coverageMeasurementPointsIDs;
@property (nonatomic) long long unknownStartTime;
@property (nonatomic) bool unknownDetected;
@property (nonatomic) bool unknownToAirplaneDetected;

@end




@implementation CoverageViewController






- (IBAction)startButtonTouched:(id)sender
{
    self.startButton.enabled    = false;
    self.stopButton.enabled     = true;
    
    [self clearUI];
    
    [self startCoverage];
}

- (IBAction)stopButtonTouched:(id)sender
{
    [self stopCoverage];
}






-(void)startCoverage
{
    self.statusLabel.text = @"Coverage Detection running";
    self.kpisTextView.text = @"";
    self.coverageLog = @"";
    
    self.unknownStartTime = 0;
    self.unknownDetected = false;
    self.unknownToAirplaneDetected = false;
    
    self.coverage.distanceFilter = 0.01f;
    
    [self.coverage coverageStartWithDesiredAccuracy:kCLLocationAccuracyBest minAccuracy:10000.0 networkThreshold:@"5G"];
}

-(void)stopCoverage
{
    self.startButton.enabled    = true;
    self.stopButton.enabled     = false;
    
    self.statusLabel.text = @"Coverage completed";
    
    [self.coverage coverageStop];
}






-(void)coverageDidUpdate:(NSDictionary*)coverage withWarning:(NSError*)warning
{
    [UIApplication sharedApplication].idleTimerDisabled = true;
    
    NSString *log = @"";
    if (warning)
    {
        log = [NSString stringWithFormat:@"Warning: %@", warning.localizedDescription];
    }
    else
    {
        log = @"No warning";
    }
    
    if (coverage)
    {
        NSString *logCoverage = @"";
        logCoverage = [NSString stringWithFormat:@"%@", [NSString stringWithFormat:@"Coverage Update:\nNetwork: %@ Location: lat: %@ long: %@ acc: %@ alt: %@, velocity: %@, call_state: %@, %@", [coverage objectForKey:@"app_access"], [coverage objectForKey:@"app_latitude"],[coverage objectForKey:@"app_longitude"], [coverage objectForKey:@"app_accuracy"], [coverage objectForKey:@"app_altitude"], [coverage objectForKey:@"app_velocity"], [coverage objectForKey:@"app_call_state"], log]];
        [self logStringToCoverageLog:logCoverage];
        DDLogDebug(@"%@", logCoverage);
    }
}






- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [DDLog removeAllLoggers];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [DDTTYLogger sharedInstance].logFormatter = [LogFormatter new];

    self.tool                       = [Tool new];

    self.coverage                   = [Coverage new];
    self.coverage.coverageDelegate  = self;

    self.stopButton.enabled         = false;
}

-(void)clearUI
{
    self.statusLabel.text   = @"-";
    self.kpisTextView.text  = @"";
}

-(void)logStringToCoverageLog:(NSString*)string
{
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"HH:mm:ss:SSS"];
    self.coverageLog = [NSString stringWithFormat:@"%@: %@\n\n%@", [dateFormat stringFromDate:[NSDate date]], string, self.coverageLog];
    self.kpisTextView.text = self.coverageLog;
}

@end
