//
//  ViewController.m
//  InfinitePeripherals.ObjC
//
//  Created by Mercury Developer Integrations on 12/5/13.
//  Copyright (c) 2013 MercuryPay. All rights reserved.
//

#import "ViewController.h"

#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>

@interface ViewController ()

@property (nonatomic, assign) BOOL isProcessingTransaction;

@end

@implementation ViewController

#pragma mark Actions

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self initializeControls];
    [self initializeDTDevice];
}

- (void)viewDidAppear:(BOOL)animated {
    
    [self setTransactionValues];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}

- (IBAction)changeOfPlatform:(id)sender {
    
    [self setTransactionValues];
    
}

- (IBAction)sendMail:(id)sender {
    // From within your active view controller
    if([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *mailCont = [[MFMailComposeViewController alloc] init];
        mailCont.mailComposeDelegate = self;
        
        [mailCont setSubject:@"Infinite Peripherals Encryption Testing"];
        [mailCont setToRecipients:[NSArray arrayWithObjects:@"", nil]];
        
        NSMutableString *message = [NSMutableString new];
        [message appendFormat:@"%@\n\n", self.lblDeviceState.text];
        [message appendFormat:@"Platform: %@\n", self.lblPlatform.text];
        [message appendFormat:@"\n"];
        [message appendFormat:@"Request:\n"];
        [message appendFormat:@"%@", self.txtRequestBox.text];
        [message appendFormat:@"\n"];
        [message appendFormat:@"Response:\n"];
        [message appendFormat:@"%@", self.txtResponseBox.text];
        
        [mailCont setMessageBody:message isHTML:NO];
        
        [self presentModalViewController:mailCont animated:YES];
    }
}

// Then implement the delegate method
- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark Mercury Helper

- (void)transactionDidFailWithError:(NSError *)error {
    
    [self handleTransactionError:error];
    
}

- (void)transactionDidFinish:(NSDictionary *)result {
    
    [self handleTransactionResult:result];
    
}

#pragma mark Infinite Peripheral Events

//linea connection state
- (void)connectionState:(int)state {
    
    [self updateConnectionState:state];
}

//notification when card is read
- (void)magneticCardEncryptedData:(int)encryption tracks:(int)tracks data:(NSData *)data track1masked:(NSString *)track1masked track2masked:(NSString *)track2masked track3:(NSString *)track3 {
    NSMutableString *status=[NSMutableString string];
    
    self.txtRequestBox.text = @"";
    self.txtResponseBox.text = @"";
    
    if(tracks!=0)
    {
        //you can check here which tracks are read and discard the data if the requred ones are missing
        // for example:
        
        if(!(tracks&2)) {
            UIAlertView *alert = [[UIAlertView alloc]initWithTitle: @"Bad Swipe"
                                                           message: @"No Track2 Data Read"
                                                          delegate: self
                                                 cancelButtonTitle: nil
                                                 otherButtonTitles:@"OK",nil];
            
            [alert show];
            
            return;
        }
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle: @"Bad Swipe"
                                                       message: @"No Track Data Read"
                                                      delegate: self
                                             cancelButtonTitle: nil
                                             otherButtonTitles:@"OK",nil];
        
        [alert show];
        
        return;
    }
	
    if(encryption==ALG_EH_MAGTEK)
    {
        //find the tracks, turn to ascii hex the data
        int index=0;
        uint8_t *bytes=(uint8_t *)[data bytes];
        
        index++; //card encoding typeB
        index++; //track status
        int t1Len=bytes[index++]; //track 1 unencrypted length
        int t2Len=bytes[index++]; //track 2 unencrypted length
        int t3Len=bytes[index++]; //track 3 unencrypted length
        NSString *t1masked=[[NSString alloc] initWithBytes:&bytes[index] length:t1Len encoding:NSASCIIStringEncoding];
        index+=t1Len; //track 1 masked
        NSString *t2masked=[[NSString alloc] initWithBytes:&bytes[index] length:t2Len encoding:NSASCIIStringEncoding];
        index+=t2Len; //track 2 masked
        NSString *t3masked=[[NSString alloc] initWithBytes:&bytes[index] length:t3Len encoding:NSASCIIStringEncoding];
        index+=t3Len; //track 3 masked
        uint8_t *t1Encrypted=&bytes[index]; //encrypted track 1
        int t1EncLen=((t1Len+7)/8)*8; //calculated encrypted track length as unencrypted one padded to 8 bytes
        index+=t1EncLen;
        uint8_t *t2Encrypted=&bytes[index]; //encrypted track 2
        int t2EncLen=((t2Len+7)/8)*8; //calculated encrypted track length as unencrypted one padded to 8 bytes
        index+=t2EncLen;
        
        index+=20; //track1 sha1
        index+=20; //track2 sha1
        uint8_t *ksn=&bytes[index]; //dukpt serial number
        
        [status appendFormat:@"MAGTEK card format\n"];
        [status appendFormat:@"Track1: %@\n",t1masked];
        [status appendFormat:@"Track2: %@\n",t2masked];
        [status appendFormat:@"Track3: %@\n",t3masked];
        
        if(t2Len>0) {
            
            if ([self.dtdev msProcessFinancialCard:t1masked track2:t2masked]) {
                //if the card is a financial card, try sending to a processor for verification
                NSMutableDictionary *dictionaryReq = [NSMutableDictionary new];
                [dictionaryReq setObject:@"118725340908147" forKey:@"MerchantID"];
                [dictionaryReq setObject:@"Credit" forKey:@"TranType"];
                [dictionaryReq setObject:@"Sale" forKey:@"TranCode"];
                [dictionaryReq setObject:@"54322" forKey:@"InvoiceNo"];
                [dictionaryReq setObject:@"54322" forKey:@"RefNo"];
                [dictionaryReq setObject:@"Mercury InfinitePeripherals TestApp v0.1" forKey:@"Memo"];
                // EncryptedFormat is always set to MagneSafe
                [dictionaryReq setObject:@"MagneSafe" forKey:@"EncryptedFormat"];
                // AccountSource set to Swiped if read from MSR
                [dictionaryReq setObject:@"Swiped" forKey:@"AccountSource"];
                // EncryptedBlock is the encrypted payload in 3DES DUKPT format
                [dictionaryReq setObject:[self toHexString:t2Encrypted length:t2EncLen space:false] forKey:@"EncryptedBlock"];
                // EncryptedKey is the Key Serial Number (KSN)
                [dictionaryReq setObject:[self toHexString:ksn length:10 space:false] forKey:@"EncryptedKey"];
                [dictionaryReq setObject:@"4.35" forKey:@"Purchase"];
                [dictionaryReq setObject:@"test" forKey:@"OperatorID"];
                [dictionaryReq setObject:@"OneTime" forKey:@"Frequency"];
                [dictionaryReq setObject:@"RecordNumberRequested" forKey:@"RecordNo"];
                [dictionaryReq setObject:@"Allow" forKey:@"PartialAuth"];
                
                NSMutableString *message = [NSMutableString new];
                
                for (NSString *key in [dictionaryReq allKeys])
                {
                    [message appendFormat:@"%@: %@;\n", key, [dictionaryReq objectForKey:key]];
                }
                
                self.txtRequestBox.text = message;
                
                MercuryHelper *mgh = [MercuryHelper new];
                mgh.delegate = self;
                mgh.platform = [NSMutableString stringWithString: self.lblPlatform.text];
                [mgh transctionFromDictionary:dictionaryReq andPassword:@"xyz"];
                
                _isProcessingTransaction = YES;
                self.activityIndicator.hidden = NO;
                [self.activityIndicator startAnimating];
            }
        }
        
    }
    
}

#pragma mark Custom Methods

- (void)initializeControls {
    
    self.activityIndicator.hidden = YES;
    
    self.txtRequestBox.editable = NO;
    self.txtRequestBox.text = @"";
    self.txtRequestBox.textColor = [UIColor whiteColor];
    self.txtRequestBox.backgroundColor = [UIColor blackColor];
    
    self.txtResponseBox.editable = NO;
    self.txtResponseBox.text = @"";
    self.txtResponseBox.backgroundColor = [UIColor blackColor];
    
    self.btnEmailResults.enabled = NO;
}

- (void)initializeDTDevice {
    self.dtdev = [DTDevices sharedDevice];
    [self.dtdev addDelegate:self];
    [self.dtdev connect];
}

- (void)updateConnectionState:(int)state {
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateStyle:NSDateFormatterLongStyle];
    
	switch (state) {
		case CONN_DISCONNECTED:
		case CONN_CONNECTING:
            self.lblDeviceState.text = @"(x) - device not connected";
            break;
		case CONN_CONNECTED:
        {
            self.lblDeviceState.text =[NSString stringWithFormat:@"Firmware: %@; DeviceName: %@;" ,self.dtdev.firmwareRevision, self.dtdev.deviceName];
            
            //set the active encryption algorithm - MAGTEK, using DUKPT key 1
            NSDictionary *params=[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:KEY_EH_DUKPT_MASTER1],@"keyID", nil];
            [self.dtdev emsrSetEncryption:ALG_EH_MAGTEK params:params error:nil];
			break;
        }
	}
}

- (void)setTransactionValues {
    
        // Development (Testing) Platform for Mercury 
    
        self.merchantID = [NSMutableString stringWithString:@"118725340908147"];
        self.webServicePW = [NSMutableString stringWithString:@"xyz"];
    }

- (NSString *)toHexString:(void *)data length:(int)length space:(bool)space {
	const char HEX[]="0123456789ABCDEF";
	char s[2000];
	
	int len=0;
	for(int i=0;i<length;i++)
	{
		s[len++]=HEX[((uint8_t *)data)[i]>>4];
		s[len++]=HEX[((uint8_t *)data)[i]&0x0f];
        if(space)
            s[len++]=' ';
	}
	s[len]=0;
	return [NSString stringWithCString:s encoding:NSASCIIStringEncoding];
}

- (void)handleTransactionError:(NSError *)error {
    UIAlertView *alert = [[UIAlertView alloc]initWithTitle: @"Error"
                                                   message: error.localizedDescription
                                                  delegate: self
                                         cancelButtonTitle: nil
                                         otherButtonTitles:@"OK",nil];
    
    [alert show];
    
    self.activityIndicator.hidden = YES;
}

- (void)handleTransactionResult:(NSDictionary *)result {
    NSMutableString *message = [NSMutableString new];
    
    for (NSString *key in [result allKeys])
    {
        [message appendFormat:@"%@: %@;\n", key, [result objectForKey:key]];
    }
    
    self.txtResponseBox.text = message;
    
    if ([[result valueForKey:@"CmdStatus"] isEqualToString:@"Approved"]) {
        self.txtResponseBox.textColor = [UIColor greenColor];
        
    }
    else {
        self.txtResponseBox.textColor = [UIColor redColor];
    }
    
    self.activityIndicator.hidden = YES;
    self.btnEmailResults.enabled = YES;
}

@end
