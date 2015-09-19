#import <UIKit/UIKit.h>
#import "MainTableViewController.h"
#import "ListTableViewController.h"

@interface Network : NSObject <NSStreamDelegate> {
	NSInputStream *inputShlistStream;
	NSOutputStream *outputShlistStream;
	int *bytesRead;

	@public
	MainTableViewController *shlist_tvc;
	ListTableViewController *shlist_ldvc;

}

- (bool) prepare;
- (void) send_message:(uint16_t)msg_type contents:(NSData *)data;

@end