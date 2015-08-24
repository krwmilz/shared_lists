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


- (void) writeToServer:(NSData *)data;

@end