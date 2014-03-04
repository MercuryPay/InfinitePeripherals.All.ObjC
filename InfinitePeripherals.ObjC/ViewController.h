//
//  ViewController.h
//  InfinitePeripherals.ObjC
//
//  Created by Mercury Developer Integrations on 12/5/13.
//  Copyright (c) 2013 MercuryPay. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MercuryHelper.h"
#import "DTDevices.h"

@interface ViewController : UIViewController <MercuryHelperDelegate>

// Battery State
@property (strong, nonatomic) IBOutlet UIButton *batteryButton;

//Infinite Peripherals
@property (strong, nonatomic) DTDevices *dtdev;

//Platform Switch
@property (strong, nonatomic) IBOutlet UILabel *lblPlatform;

//Processing
@property (strong, nonatomic) NSMutableString *merchantID;
@property (strong, nonatomic) NSMutableString *webServicePW;

@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

//Output
@property (strong, nonatomic) IBOutlet UITextView *txtRequestBox;
@property (strong, nonatomic) IBOutlet UITextView *txtResponseBox;


//Email Transaction Results
@property (strong, nonatomic) IBOutlet UIButton *btnEmailResults;

//Device is connected or not
@property (strong, nonatomic) IBOutlet UILabel *lblDeviceState;

//Actions
- (IBAction)changeOfPlatform:(id)sender;
- (IBAction)sendMail:(id)sender;
- (IBAction)onBattery:(id)sender;


@end
