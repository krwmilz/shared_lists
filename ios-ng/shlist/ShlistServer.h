#import <UIKit/UIKit.h>
#import "MainTableViewController.h"
#import "ListDetailTableViewController.h"

@interface ShlistServer : NSObject <NSStreamDelegate> {
	NSInputStream *inputShlistStream;
	NSOutputStream *outputShlistStream;
	int *bytesRead;

	@public
	MainTableViewController *shlist_tvc;
	ListDetailTableViewController *shlist_ldvc;

}

- (bool) prepare;
- (void) send_message:(uint16_t)msg_type contents:(NSData *)data;

@end