#import <UIKit/UIKit.h>
#import "SharedListsTableViewController.h"
#import "ListDetailTableViewController.h"

@interface ShlistServer : NSObject <NSStreamDelegate> {
	NSInputStream *inputShlistStream;
	NSOutputStream *outputShlistStream;
	int *bytesRead;

	@public
	SharedListsTableViewController *shlist_tvc;
	ListDetailTableViewController *shlist_ldvc;

}

- (bool) prepare;
- (void) send_message:(uint16_t)msg_type contents:(NSData *)data;

@end