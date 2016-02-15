#import <UIKit/UIKit.h>

#import "MsgTypes.h"

@interface Network : NSObject <NSStreamDelegate> {
	NSInputStream *inputShlistStream;
	NSOutputStream *outputShlistStream;
}

- (void) connect;
- (void) disconnect;

// only networking really cares about the device id
- (bool) load_device_id:(NSString *)phone_number;
- (NSString *) get_device_id;
- (bool) connected;
- (bool) send_message:(uint16_t)msg_type contents:(NSMutableDictionary *)data;

// returns singleton instance
+ (id) shared_network_connection;

@end