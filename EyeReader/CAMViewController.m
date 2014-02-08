//
//  CAMViewController.m
//  EyeReader
//
//  Created by Chris Meehan on 2/7/14.
//  Copyright (c) 2014 Chris Meehan. All rights reserved.
//

#import "CAMViewController.h"
#import "CFMagicEvents.h"

@interface CAMViewController (){
    CFMagicEvents* cFME;
}
@property (weak, nonatomic) IBOutlet UIImageView *uIImageOutlet;
- (IBAction)pic1:(id)sender;
- (IBAction)pic2:(id)sender;
- (IBAction)lastDelta:(id)sender;
- (IBAction)blinkGo:(id)sender;
- (IBAction)showBlinkTally:(id)sender;
@property (weak, nonatomic) IBOutlet UILabel *theLabel;
    @property(nonatomic)NSOperationQueue* nSOQ;
@end

@implementation CAMViewController

- (void)viewDidLoad{
    [super viewDidLoad];

    
    self.nSOQ = [[NSOperationQueue alloc]init];
    NSBlockOperation* nSBO = [NSBlockOperation blockOperationWithBlock:^{
        cFME = [[CFMagicEvents alloc]init];
        while(1==1){
            [cFME startCapture];
            [cFME getTotalBrightness];
        }
    }];
    [self.nSOQ addOperation:nSBO];
    
    
}



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)pic1:(id)sender {
    [cFME setFirstArray];
}

- (IBAction)pic2:(id)sender {
    [cFME setSecondArray];
}



// This is now the generic "SHOW BUTTON"
- (IBAction)lastDelta:(id)sender {
  //  NSLog(@"fo sjop");
 //   self.theLabel.text = [cFME getLastDelta];
    [self.uIImageOutlet setImage:[cFME getBlinkTallyUIImage]];
}

- (IBAction)blinkGo:(id)sender {
    sleep(1);
   // NSLog(@"kuu");
    [cFME turnOnBlinkTest];
    // Keep an array tallying up how many times that square went positive from the last.
    
    
    
    
}

- (IBAction)showBlinkTally:(id)sender {
    
 //   NSLog(@"roog");
  //  self.theLabel.text = [cFME getHighestBlinkTally];
    [self.uIImageOutlet setImage:[cFME getBlinkTallyUIImage]];
    
    
}

-(int)calculateBrightness:(int*)theArray{
 //   NSLog(@"herro");
    int brightnessTally = 0;
    for(int count = 0 ; count<27648 ;  count++){
        brightnessTally = brightnessTally+theArray[count];
    }
    return brightnessTally;
}





@end
