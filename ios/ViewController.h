#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <NSStreamDelegate>

-(IBAction)showMessage;

@end

NSInputStream *inputStream;
NSOutputStream *outputStream;
