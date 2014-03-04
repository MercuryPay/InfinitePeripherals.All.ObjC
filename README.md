Infinite Peripherals
===================
This is a sample Xcode iOS application demonstrating the capture of an encrypted credit card swipe from Infinite Peripheral device and processing transactions to the MercuyPay Web Services platform.
***
**PREREQUISITE:** Infinite Peripherals has a developer portal at http://ipcprint.com/developer/  There is an NDA registration procedure in place as a part of the Infinite Peripherals Development Portal Registration Process.  Once approved, you will have access to SDKs.  
***
##Steps to Capture Secure Card Data from <br>Infinite Peripherals Encrypted Swipers

###Step 1: Add Infinite Peripheral library (see prerequisite above)
Add `DTDevices.h` and `libtdev.a` to your project

###Step 2: Modify .plist file
`com.datecs.linea.pro.msr`
`com.datecs.linea.pro.bar`

```XML
<key>UISupportedExternalAccessoryProtocols</key>
	<array>
		<string>com.datecs.linea.pro.msr</string>
		<string>com.datecs.linea.pro.bar</string>
	</array>
```

###Step 3: Initilize a new `dtdev` instance

```Objective-C
self.dtdev = [DTDevices sharedDevice];
[self.dtdev addDelegate:self];
[self.dtdev connect];
```

###Step 4: Implement updateConnectionState:(int)state method

```Objective-C
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
            		//set the active encryption algorithm - Mercury, using DUKPT key 1
            		NSDictionary *params=[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:KEY_EH_DUKPT_MASTER1],@"keyID", nil];
            		[self.dtdev emsrSetEncryption:ALG_EH_MAGTEK params:params error:nil];
                        break;
        	}
        }
}
```

###Step 5: Implement magneticCardEncryptedData:(int)encryption tracks:(int)tracks data:(NSData *)data track1masked:(NSString *)track1masked track2masked:(NSString *)track2masked track3:(NSString *)track3

```Objective-C
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
		[dictionaryReq setObject:@"02" forKey:@"LaneID"];
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
```
----------------
######© 2013 Mercury Payment Systems, LLC - all rights reserved.
This software and all specifications and documentation contained herein or provided to you hereunder (the "Software") are provided free of charge strictly on an "AS IS" basis. No representations or warranties are expressed or implied, including, but not limited to, warranties of suitability, quality, merchantability, or fitness for a particular purpose (irrespective of any course of dealing, custom or usage of trade), and all such warranties are expressly and specifically disclaimed. Mercury Payment Systems shall have no liability or responsibility to you nor any other person or entity with respect to any liability, loss, or damage, including lost profits whether foreseeable or not, or other obligation for any cause whatsoever, caused or alleged to be caused directly or indirectly by the Software. Use of the Software signifies agreement with this disclaimer notice.

[![githalytics.com alpha](https://cruel-carlota.pagodabox.com/a6cfcb5aa2c7f6e6d393cb5eee014cd3 "githalytics.com")](http://githalytics.com/MercuryPay/InfinitePeriperals.ObjC)
