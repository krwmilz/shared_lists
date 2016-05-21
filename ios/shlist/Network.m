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

- (bool) connected
{
	return connected;
}

- (NSString *) get_device_id
{
	return device_id;
}

- (void) connect
{
	CFReadStreamRef readStream;
	CFWriteStreamRef writeStream;

	CFStringRef host_name = CFSTR("absentmindedproductions.ca");
	CFStreamCreatePairWithSocketToHost(NULL, host_name, 5437, &readStream, &writeStream);

	input_stream = (__bridge NSInputStream *)readStream;
	output_stream = (__bridge NSOutputStream *)writeStream;

	[input_stream setDelegate:self];
	[output_stream setDelegate:self];

	[input_stream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[output_stream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

	// Enable SSL on both streams
	[input_stream setProperty:NSStreamSocketSecurityLevelTLSv1 forKey:NSStreamSocketSecurityLevelKey];
	[output_stream setProperty:NSStreamSocketSecurityLevelTLSv1 forKey:NSStreamSocketSecurityLevelKey];

	[input_stream open];
	[output_stream open];
}

- (void) disconnect
{
	NSLog(@"network: disconnect()");
	connected = 0;
	[[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkDisconnectedNotification" object:nil userInfo:nil];

	[input_stream close];
	[output_stream close];

	[input_stream removeFromRunLoop:[NSRunLoop currentRunLoop]
				     forMode:NSDefaultRunLoopMode];
	[output_stream removeFromRunLoop:[NSRunLoop currentRunLoop]
				      forMode:NSDefaultRunLoopMode];

	input_stream = nil; // stream is ivar, so reinit it
	output_stream = nil; // stream is ivar, so reinit it
}

- (bool) load_device_id:(NSString *)phone_number;
{
	if ([[NSFileManager defaultManager] fileExistsAtPath:device_id_file]) {
		// TODO: also check the length of the file
		// read device id from filesystem into memory
		NSError *error = nil;
		device_id = [NSString stringWithContentsOfFile:device_id_file encoding:NSUTF8StringEncoding error:&error];
		if (error != nil) {
			NSLog(@"%@", [error userInfo]);
			return false;
		}

		NSLog(@"network: device id loaded");
		return true;
	}

	// no device id file found, send a registration message
	NSMutableDictionary *request = [NSMutableDictionary dictionaryWithObjectsAndKeys:
				 phone_number, @"phone_number",
				 @"ios", @"os",
				 nil];
	[self send_message:device_add contents:request];

	return false;
}

- (bool) send_message:(uint16_t)send_msg_type contents:(NSObject *)data
{
	NSMutableDictionary *request = [[NSMutableDictionary alloc] init];
	[request setObject:data forKey:@"data"];

	if (send_msg_type != device_add) {
		// Append 'device_id' to all message types except device_add
		[request setObject:device_id forKey:@"device_id"];
	}

	NSError *error = nil;
	// Try to serialize request, bail if errors
	NSData *json = [NSJSONSerialization dataWithJSONObject:request options:0 error:&error];
	if (error != nil) {
		NSLog(@"%@", [error userInfo]);
		return false;
	}

	// Convert header values into network byte order
	uint16_t version = htons(0);
	uint16_t msg_type_network = htons(send_msg_type);
	uint16_t length = htons([json length]);

	// Construct message header by concatenating network byte order fields
	NSMutableData *msg = [NSMutableData data];
	[msg appendBytes:&version length:2];
	[msg appendBytes:&msg_type_network length:2];
	[msg appendBytes:&length length:2];
	[msg appendData:json];

	NSLog(@"network: send_message: type %i, %lu bytes",
		send_msg_type, (unsigned long)[msg length]);

	[output_stream write:[msg bytes] maxLength:[msg length]];

	// sent successfully
	return true;
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
	NSString *stream_name;
	if (stream == input_stream)
		stream_name = @"input stream";
	else if (stream == output_stream)
		stream_name = @"output stream";

	switch (eventCode) {
	case NSStreamEventNone: {
		NSLog(@"network: NSStreamEventNone occurred");
		break;
	}
	case NSStreamEventOpenCompleted: {
		NSLog(@"network: %@ opened", stream_name);

		connected = 1;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkConnectedNotification" object:nil userInfo:nil];
		break;
	}
	case NSStreamEventHasBytesAvailable: {
		// NSLog(@"network: %@ has bytes available", stream_name);

		if (stream != input_stream) {
			break;
		}

		// Read an entire message, header + payload
		[self read_ready];

		break;
	}
	case NSStreamEventHasSpaceAvailable: {
		// NSLog(@"network: %@ has space available", stream_name);
		break;
	}
	case NSStreamEventErrorOccurred: {
		// happens when trying to connect to a down server
		NSStream *error_stream;
		if (stream == input_stream)
			error_stream = input_stream;
		else if (stream == output_stream)
			error_stream = output_stream;
		else
			// don't try to do operations on null stream
			break;

		NSError *theError = [error_stream streamError];
		NSLog(@"network: %@", [NSString stringWithFormat:@"%@ error %li: %@",
				stream_name, (long)[theError code], [theError localizedDescription]]);

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

// Try to read and parse an entire message. If the messsage type isn't device_add,
// then send a notification to the classes responsible
- (void) read_ready
{
	// Read header
	uint16_t header[3];
	[self read_all:(uint8_t *)header size:6];

	// Unpack header
	uint16_t version = ntohs(header[0]);
	uint16_t msg_type = ntohs(header[1]);
	uint16_t payload_size = ntohs(header[2]);

	// Verify header
	if (version != 0) {
		NSLog(@"read: invalid version %i", version);
		return;
	}
	if (msg_type > 11) {
		NSLog(@"read: invalid message type %i", msg_type);
		return;
	}

	// Read payload, accept up to 64KB of data
	uint8_t *payload = malloc(payload_size);
	[self read_all:payload size:payload_size];
	NSLog(@"read: payload is %i bytes", payload_size);

	// Create new NSData wrapper around the payload bytes
	NSData *data = [NSData dataWithBytesNoCopy:payload length:payload_size];

	NSError *error = nil;
	// Try to parse the payload as JSON, check for errors
	NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
		options:0 error:&error];
	if (error) {
		NSLog(@"%@", [error userInfo]);
		return;
	}

	// Make sure server sent 'status' key in response
	NSString *status = response[@"status"];
	if (status == nil) {
		NSLog(@"read: response did not contain 'status' key");
		return;
	}
	// Make sure 'status' key is not 'err'
	if ([status compare:@"err"] == 0) {
		NSLog(@"read: response error, reason = '%@'", response[@"reason"]);
		return;
	}

	// 'data' key is always sent back when "status" is "ok"
	NSObject *response_data = response[@"data"];
	if (response_data == nil) {
		NSLog(@"read: response did not contain 'data' key");
		return;
	}

	if (msg_type == device_add) {
		// device_add responses don't trigger any gui updates
		device_id = (NSString *)response_data;

		NSLog(@"device_add: writing new key '%@' to file", device_id);
		NSError *error = nil;
		[device_id writeToFile:device_id_file atomically:YES encoding:NSUTF8StringEncoding error:&error];

		if (error != nil)
			NSLog(@"%@", [error userInfo]);
		return;
	}

	// Send out a notification that a response was received. The responsible
	// parties should already be listening for these by the time they come in.
	NSString *notification_name = [NSString stringWithFormat:@"NetworkResponseFor_%s", msg_strings[msg_type]];
	[[NSNotificationCenter defaultCenter] postNotificationName:notification_name object:nil userInfo:response];
}

// Read a fixed amount of bytes
- (NSInteger) read_all:(uint8_t *)data size:(unsigned int)size
{
	NSInteger buffer_len = [input_stream read:data maxLength:size];
	if (buffer_len != size) {
		NSLog(@"read_all: read %ld instead of %d bytes", (long)buffer_len, size);
		return buffer_len;
	}

	return buffer_len;
}

- (void) dealloc
{
	[self disconnect];
}

@end
