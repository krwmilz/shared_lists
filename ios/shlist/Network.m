#import "Network.h"
#import "DataStructures.h"


// #import <NSAlert.h>

@interface Network () {
	NSString	*device_id;
	NSString	*device_id_file;
	bool		 connected;
}

@end

@implementation Network

+ (id) shared_network_connection
{
	static Network *network_connection = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		network_connection = [[self alloc] init];
	});
	return network_connection;
}

- (id) init
{
	if (self = [super init]) {
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *documentsDirectory = [paths objectAtIndex:0];
		device_id_file = [documentsDirectory stringByAppendingPathComponent:@"shlist_key"];
		device_id = nil;

		connected = 0;
		[self connect];
	}

	return self;
}

- (NSString *) get_device_id
{
	return device_id;
}

- (void) connect
{
	NSLog(@"network: connect()");
	connected = 1;

	CFReadStreamRef readStream;
	CFWriteStreamRef writeStream;

	CFStringRef host_name = CFSTR("absentmindedproductions.ca");

	CFStreamCreatePairWithSocketToHost(NULL, host_name, 9999, &readStream, &writeStream);
	inputShlistStream = (__bridge NSInputStream *)readStream;
	outputShlistStream = (__bridge NSOutputStream *)writeStream;

	[inputShlistStream setDelegate:self];
	[outputShlistStream setDelegate:self];

	[inputShlistStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[outputShlistStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

	// Enable SSL on both streams
	[inputShlistStream setProperty:NSStreamSocketSecurityLevelTLSv1 forKey:NSStreamSocketSecurityLevelKey];
	[outputShlistStream setProperty:NSStreamSocketSecurityLevelTLSv1 forKey:NSStreamSocketSecurityLevelKey];

	[inputShlistStream open];
	[outputShlistStream open];
}

- (void) disconnect
{
	NSLog(@"network: disconnect()");
	connected = 0;

	[inputShlistStream close];
	[outputShlistStream close];

	[inputShlistStream removeFromRunLoop:[NSRunLoop currentRunLoop]
				     forMode:NSDefaultRunLoopMode];
	[outputShlistStream removeFromRunLoop:[NSRunLoop currentRunLoop]
				      forMode:NSDefaultRunLoopMode];

	inputShlistStream = nil; // stream is ivar, so reinit it
	outputShlistStream = nil; // stream is ivar, so reinit it
}

- (bool) load_device_id:(NSString *)phone_number;
{
	if ([[NSFileManager defaultManager] fileExistsAtPath:device_id_file]) {
		// TODO: also check the length of the file
		// read device id from filesystem into memory
		NSError *error = nil;
		device_id = [NSString stringWithContentsOfFile:device_id_file encoding:NSUTF8StringEncoding error:&error];
		if (error != nil)
			NSLog(@"%@", [error userInfo]);

		NSLog(@"network: device id loaded");

		return true;
	}

	// no device id file found, send a registration message
	NSMutableData *msg = [NSMutableData data];

	NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
				 phone_number, @"phone_number",
				 @"ios", @"os",
				 nil];

	NSError *error = nil;
	NSData *json = [NSJSONSerialization dataWithJSONObject:request options:NSJSONWritingPrettyPrinted error:&error];
	if (error != nil) {
		NSLog(@"%@", [error userInfo]);
		return false;
	}

	uint16_t version = htons(0);
	uint16_t msg_type = htons(device_add);
	uint16_t length = htons([json length]);
	[msg appendBytes:&version length:2];
	[msg appendBytes:&msg_type length:2];
	[msg appendBytes:&length length:2];

	// Append JSON payload
	[msg appendData:json];

	[outputShlistStream write:[msg bytes] maxLength:[msg length]];
	NSLog(@"register: sent request");

	// we don't have a device id so we can't do anything yet
	return false;
}

- (bool) send_message:(uint16_t)send_msg_type contents:(NSMutableDictionary *)request
{
	if (!connected)
		[self connect];

	[request setObject:device_id forKey:@"device_id"];

	NSError *error = nil;
	NSData *json = [NSJSONSerialization dataWithJSONObject:request options:NSJSONWritingPrettyPrinted error:&error];
	if (error != nil) {
		NSLog(@"%@", [error userInfo]);
		return false;
	}

	uint16_t version = htons(0);
	uint16_t msg_type_network = htons(send_msg_type);
	uint16_t length = htons([json length]);

	NSMutableData *msg = [NSMutableData data];
	[msg appendBytes:&version length:2];
	[msg appendBytes:&msg_type_network length:2];
	[msg appendBytes:&length length:2];
	[msg appendData:json];

	NSLog(@"network: send_message: type %i, %i bytes",
		send_msg_type, [msg length]);

	if ([outputShlistStream write:[msg bytes] maxLength:[msg length]] == -1) {
		NSLog(@"network: write error occurred, trying reconnect");
		if (connected)
			[self disconnect];
		[self connect];

		if ([outputShlistStream write:[msg bytes] maxLength:[msg length]] == -1) {
			NSLog(@"network: resend failed after reconnect, giving up");
			return false;
		}
	}

	// sent successfully
	return true;
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
	NSString *stream_name;
	if (stream == inputShlistStream)
		stream_name = @"input";
	else if (stream == outputShlistStream)
		stream_name = @"output";

	switch (eventCode) {
	case NSStreamEventNone: {
		NSLog(@"network: NSStreamEventNone occurred");
		break;
	}
	case NSStreamEventOpenCompleted: {
		NSLog(@"network: %@ opened", stream_name);
		break;
	}
	case NSStreamEventHasBytesAvailable: {
		NSLog(@"network: %@ has bytes available", stream_name);

		if (stream == inputShlistStream) {
			if (![inputShlistStream hasBytesAvailable]) {
				NSLog(@"read: input stream had no bytes available");
				break;
			}

			[self read_ready];
		}
		break;
	}
	case NSStreamEventHasSpaceAvailable: {
		NSLog(@"network: %@ has space available", stream_name);
		break;
	}
	case NSStreamEventErrorOccurred: {
		// happens when trying to connect to a down server
		NSStream *error_stream;
		if (stream == inputShlistStream)
			error_stream = inputShlistStream;
		else if (stream == outputShlistStream)
			error_stream = outputShlistStream;
		else
			// don't try to do operations on null stream
			break;

		NSError *theError = [error_stream streamError];
		NSLog(@"network: %@", [NSString stringWithFormat:@"%@ error %i: %@",
				stream_name, [theError code], [theError localizedDescription]]);

		[self disconnect];

		break;
	}
	case NSStreamEventEndEncountered: {
		NSLog(@"network: %@ end encountered", stream_name);
		[self disconnect];

		break;
	}
	default:
		break;
	}
}

- (void) read_ready
{
	NSInteger buffer_len;
	uint16_t header[3];

	buffer_len = [inputShlistStream read:(uint8_t *)header maxLength:6];
	if (buffer_len != 6) {
		NSLog(@"read: didn't return 6 bytes");
	}

	uint16_t version = ntohs(header[0]);
	uint16_t msg_type = ntohs(header[1]);
	uint16_t payload_size = ntohs(header[2]);

	if (version != 0) {
		NSLog(@"read: invalid version %i", version);
		return;
	}
	if (msg_type > 11) {
		NSLog(@"read: invalid message type %i", msg_type);
		return;
	}

	uint8_t *payload = malloc(payload_size);

	// Accept up to 64KB of data, the maximum size of payload_size
	buffer_len = [inputShlistStream read:payload maxLength:payload_size];
	if (buffer_len != payload_size) {
		NSLog(@"read: expected %i byte payload but got %i", payload_size, buffer_len);
		return;
	}
	NSLog(@"read: payload is %i bytes", buffer_len);

	NSData *data = [NSData dataWithBytesNoCopy:payload length:payload_size];

	NSError *error = nil;
	NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
		options:0 error:&error];
	if (error) {
		NSLog(@"%@", [error userInfo]);
		return;
	}

	NSString *status = response[@"status"];
	if (status == nil) {
		NSLog(@"read: response did not contain 'status' key");
		return;
	}
	if ([status compare:@"err"] == 0) {
		NSLog(@"read: response error, reason = '%@'", response[@"reason"]);
		return;
	}

	if (msg_type == device_add) {
		[self device_add:response];
	} else if (msg_type == list_add) {
		[self list_add:response];
	} else if (msg_type == lists_get) {
		[self lists_get:response];
	} else if (msg_type == list_join) {
		[self list_join:response];
	} else if (msg_type == list_leave) {
		[self list_leave:response];
	} else if (msg_type == lists_get_other) {
		[self lists_get_other:response];
	}
}

- (void) device_add:(NSDictionary *)response
{
	device_id = [response objectForKey:@"device_id"];

	NSLog(@"device_add: writing new key '%@' to file", device_id);
	NSError *error = nil;
	[device_id writeToFile:device_id_file atomically:YES encoding:NSUTF8StringEncoding error:&error];

	if (error != nil)
		NSLog(@"%@", [error userInfo]);
}

- (void) list_add:(NSDictionary *)response
{
	NSDictionary *list = [response objectForKey:@"list"];

	SharedList *shlist = [[SharedList alloc] init];
	shlist.num = [list objectForKey:@"num"];
	shlist.name = [list objectForKey:@"name"];

	NSArray *members = [list objectForKey:@"members"];
	shlist.members_phone_nums = members;
	shlist.items_ready = [list objectForKey:@"items_complete"];
	shlist.items_total = [list objectForKey:@"items_total"];

	if ([self check_tvc:shlist_tvc])
		[shlist_tvc finished_new_list_request:shlist];

	NSLog(@"list_add: successfully added new list '%@'", shlist.name);
}

- (void) lists_get:(NSDictionary *)response
{
	NSArray *lists = [response objectForKey:@"lists"];
	NSLog(@"lists_get: got %i lists from server", [lists count]);

	// Don't attempt to update a view controller that isn't there yet
	if (![self check_tvc:shlist_tvc])
		return;

	if (shlist_tvc)
		[shlist_tvc lists_get_finished:lists];
}

- (void) lists_get_other:(NSDictionary *)response
{
	NSArray *other_lists = [response objectForKey:@"other_lists"];
	NSLog(@"lists_get_other: got %i other lists from server", [other_lists count]);

	// Don't attempt to update a view controller that isn't there yet
	if (![self check_tvc:shlist_tvc])
		return;

	if (shlist_tvc)
		[shlist_tvc lists_get_other_finished:other_lists];
}

- (void) list_join:(NSDictionary *)response
{
	NSDictionary *list = response[@"list"];
	NSLog(@"network: joined list %@", list[@"num"]);

	if ([self check_tvc:shlist_tvc])
		[shlist_tvc finished_join_list_request:list];
}

- (void) list_leave:(NSDictionary *)response
{
	NSNumber *list_num = response[@"list_num"];
	NSLog(@"network: left list %@", list_num);

	if ([self check_tvc:shlist_tvc])
		[shlist_tvc finished_leave_list_request:response];
}

- (bool) check_tvc:(MainTableViewController *) tvc
{
	if (tvc)
		return true;
	NSLog(@"network: trying to update main_tvc before it's ready, ignoring!");
	return false;
}

- (void) dealloc
{
	[self disconnect];
}

@end
