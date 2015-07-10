#import <UIKit/UIKit.h>
#import "SharedListsTableViewController.h"

@interface ShlistServer : NSObject <NSStreamDelegate> {
	NSInputStream *inputShlistStream;
	NSOutputStream *outputShlistStream;
	int *bytesRead;

	@public
	SharedListsTableViewController *shlist_tvc;
}


- (void) writeToServer:(NSData *)data;

@end