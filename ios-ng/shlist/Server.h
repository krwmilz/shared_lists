#import <UIKit/UIKit.h>

@interface Server : NSObject <NSStreamDelegate>

- (void)read;
- (void)write;

@end
