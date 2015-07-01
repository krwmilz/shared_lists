#import <UIKit/UIKit.h>

@interface ShlistServer : NSObject <NSStreamDelegate> {
    NSInputStream *inputShlistStream;
    NSOutputStream *outputShlistStream;
    int *bytesRead;
}

- (void) writeToServer:(const char *)data :(size_t)length;

@end