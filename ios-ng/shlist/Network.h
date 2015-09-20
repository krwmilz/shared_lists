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

- (void) connect;
- (void) disconnect;

// only networking really cares about the device id
- (bool) load_device_id:(NSData*)phone_number;
- (bool) send_message:(uint16_t)msg_type contents:(NSData *)data;

// returns singleton instance
+ (id) shared_network_connection;

@end