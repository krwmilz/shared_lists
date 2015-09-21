#import "Network.h"
#import "DataStructures.h"

// #import <NSAlert.h>

@interface Network () {
	NSData		*msg_data;
	NSString	*msg_string;
	uint8_t		 msg_buffer[1024];
	unsigned int	 msg_buf_position;

	uint8_t		 msg_total_bytes_tmp[2];
	unsigned short	 msg_total_bytes;
	unsigned int	 msg_total_bytes_pos;

	uint8_t		 msg_type_tmp[2];
	unsigned short	 msg_type;
	unsigned int	 msg_type_pos;

	NSData		*device_id;
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

		msg_buf_position = 0;

		msg_total_bytes = 0;
		msg_total_bytes_pos = 0;

		msg_type = 0;
		msg_type_pos = 0;
		connected = 0;
		[self connect];
	}

	return self;
}

- (void) connect
{
	[self info:@"network: connect()"];
	connected = 1;

	CFReadStreamRef readStream;
	CFWriteStreamRef writeStream;

	CFStringRef host_name = CFSTR("absentmindedproductions.ca");

	CFStreamCreatePairWithSocketToHost(NULL, host_name, 5437, &readStream, &writeStream);
	inputShlistStream = (__bridge NSInputStream *)readStream;
	outputShlistStream = (__bridge NSOutputStream *)writeStream;

	[inputShlistStream setDelegate:self];
	[outputShlistStream setDelegate:self];

	[inputShlistStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[outputShlistStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

	[inputShlistStream open];
	[outputShlistStream open];
}

- (void) disconnect
{
	[self info:@"network: disconnect()"];
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

- (bool) load_device_id:(NSData *)phone_number;
{
	if ([[NSFileManager defaultManager] fileExistsAtPath:device_id_file]) {
		// TODO: also check the length of the file
		// read device id from filesystem into memory
		device_id = [NSData dataWithContentsOfFile:device_id_file];
		[self debug:@"network: device id loaded"];

		return true;
	}

	// no device id file found, send a registration message
	NSMutableData *msg = [NSMutableData data];

	// message type 0
	uint16_t msg_type_network = htons(0);
	[msg appendBytes:&msg_type_network length:2];

	// phone number length is 10
	uint16_t length_network = htons(10);
	[msg appendBytes:&length_network length:2];

	// append phone number
	[msg appendData:phone_number];

	[outputShlistStream write:[msg bytes] maxLength:[msg length]];
	[self info:@"register: sent request"];

	// we don't have a device id so we can't do anything yet
	return false;
}

- (bool) send_message:(uint16_t)send_msg_type contents:(NSData *)payload
{
	if (!connected)
		[self connect];

	NSMutableData *msg = [NSMutableData data];
	[self info:@"network: send_message: msg type %i, %i bytes payload",
		send_msg_type, [payload length]];

	uint16_t msg_type_network = htons(send_msg_type);
	[msg appendBytes:&msg_type_network length:2];

	int payload_length = 0;
	if (payload)
		// include null separator in this length
		payload_length = [payload length] + 1;

	uint16_t msg_len_network = htons([device_id length] + payload_length);
	[msg appendBytes:&msg_len_network length:2];

	if (device_id == nil) {
		[self warn:@"network: send_message: called before device_id was ready"];
		return false;
	}
	[msg appendData:device_id];

	if (payload) {
		[msg appendBytes:"\0" length:1];
		[msg appendData:payload];
	}

	if ([outputShlistStream write:[msg bytes] maxLength:[msg length]] == -1) {
		[self warn:@"network: write error occurred, trying reconnect"];
		if (connected)
			[self disconnect];
		[self connect];

		if ([outputShlistStream write:[msg bytes] maxLength:[msg length]] == -1) {
			[self warn:@"network: resend failed after reconnect, giving up"];
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
		[self debug:@"network: NSStreamEventNone occurred"];
		break;
	}
	case NSStreamEventOpenCompleted: {
		[self debug:@"network: %@ opened", stream_name];
		break;
	}
	case NSStreamEventHasBytesAvailable: {
		[self debug:@"network: %@ has bytes available", stream_name];

		if (stream == inputShlistStream) {
			if (![inputShlistStream hasBytesAvailable]) {
				[self warn:@"network: input stream had no bytes available"];
				break;
			}

			// advance the message state machine by at least one byte
			[self process_response_bytes];
		}
		break;
	}
	case NSStreamEventHasSpaceAvailable: {
		[self debug:@"network: %@ has space available", stream_name];
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
		[self info:@"network: %@", [NSString stringWithFormat:@"%@ error %i: %@",
				stream_name, [theError code], [theError localizedDescription]]];

		[self disconnect];

		break;
	}
	case NSStreamEventEndEncountered: {
		[self debug:@"network: %@ end encountered", stream_name];
		[self disconnect];

		break;
	}
	default:
		break;
	}
}

- (void) process_response_bytes
{
	uint8_t *buffer = malloc(1024);
	while ([inputShlistStream hasBytesAvailable]) {

		unsigned int buffer_pos = 0;
		NSInteger buffer_length;

		buffer_length = [inputShlistStream read:buffer maxLength:1024];
		if (buffer_length < 0) {
			[self info:@"network: read returned < 0: %i", buffer_length];
			// XXX: should this be break instead?
			continue;
		}

		if (buffer_length == 0) {
			[self info:@"network: buffer length was zero!"];
			// maybe break here instead?
			continue;
		}
		[self debug:@"network: processing %i bytes", buffer_length];

		// start receiving a new message
		if (msg_type_pos == 0) {
			msg_type_tmp[0] = buffer[buffer_pos];
			msg_type_pos = 1;
			buffer_pos++;

			if (buffer_length == 1)
				// we've exhausted the buffer
				continue;
		}

		// if we got here buffer_length > 1
		if (msg_type_pos == 1) {
			msg_type_pos = 2;
			msg_type_tmp[1] = buffer[buffer_pos];

			// we read a single byte from the buffer
			buffer_pos++;

			// both bytes are available for reading
			msg_type = ntohs(*(uint16_t *)msg_type_tmp);
			if (msg_type > 7) {
				[self warn:@"network: out of range msg type %i", msg_type];

				// bad message type, reset message buffer
				msg_type_pos = 0;
				msg_buf_position = 0;
				msg_total_bytes_pos = 0;
				continue;
			}
			[self debug:@"network: parsed message type %i", msg_type];

			if (buffer_pos == buffer_length)
				// we've run out of bytes to process
				continue;
		}

		// if we got here buffer_pos < buffer_length
		if (msg_total_bytes_pos == 0) {
			msg_total_bytes_pos = 1;
			msg_total_bytes_tmp[0] = buffer[buffer_pos];
			buffer_pos++;

			if (buffer_pos == buffer_length)
				// no more bytes to process
				continue;
		}

		if (msg_total_bytes_pos == 1) {
			msg_total_bytes_pos = 2;
			msg_total_bytes_tmp[1] = buffer[buffer_pos];
			buffer_pos++;

			msg_total_bytes = ntohs(*(uint16_t *)msg_total_bytes_tmp);
			if (msg_total_bytes > 1024 || msg_total_bytes == 0) {
				[self warn:@"network: out of range message length: 0 < %i < 1024",
				      msg_total_bytes];

				// bad message type, reset message buffer
				msg_type_pos = 0;
				msg_buf_position = 0;
				msg_total_bytes_pos = 0;
				continue;
			}
			[self debug:@"network: message length is %i bytes", msg_total_bytes];

			if (buffer_pos == buffer_length)
				// no more bytes to process
				continue;
		}

		unsigned int remaining_bytes = buffer_length - buffer_pos;

		if (msg_buf_position + remaining_bytes >= msg_total_bytes) {
			[self info:@"network: buffer length has enough space to read complete message"];

			unsigned int bytes_for_complete_message = msg_total_bytes - msg_buf_position;
			memcpy(msg_buffer + msg_buf_position, &buffer[buffer_pos], bytes_for_complete_message);
			msg_buf_position += bytes_for_complete_message;

			msg_data = [[NSData alloc] initWithBytes:msg_buffer length:msg_total_bytes];
			msg_string = [[NSString alloc] initWithBytes:msg_buffer length:msg_total_bytes encoding:NSASCIIStringEncoding];

			[self handle_complete_message];

			// reset parsing fields, leave buffer position fields alone though
			msg_buf_position = 0;
			msg_type_pos = 0;
			msg_total_bytes_pos = 0;

			// lop off anything else that's remaining in the read buffer
			continue;
		}

		// copy any remaining data into msg buffer
		memcpy(msg_buffer + msg_buf_position, &buffer[buffer_pos], remaining_bytes);
		msg_buf_position += remaining_bytes;
	}

	// free temporary buffer, not msg_buffer
	free(buffer);
}

- (void) handle_complete_message
{
	// assert msg_type_pos == 2 and msg_total_bytes_pos == 2 and msg_buf_position == msg_total_bytes

	if (msg_type == 0) {
		// registration response message
		if ([[NSFileManager defaultManager] fileExistsAtPath:device_id_file]) {
			// it would be strange if we got back a registration
			// message type when we already have a key file
			[self error:@"network: register: not overwriting key file with '%@'", msg_string];
			return;
		}

		[self info:@"network: register: writing new key '%@' to disk", msg_string];
		[msg_data writeToFile:device_id_file atomically:YES];

		// set this so we're ready to send other message types
		device_id = msg_data;

		// do a bulk list update
		[self send_message:3 contents:nil];
	}

	else if (msg_type == 1) {
		NSArray *fields = [msg_string componentsSeparatedByString:@"\0"];
		if ([fields count] != 3) {
			[self warn:@"network: new list response has invalid number of fields %i",
			      [fields count]];
			return;
		}

		SharedList *shlist = [[SharedList alloc] init];
		shlist.id = [[fields objectAtIndex:0] dataUsingEncoding:NSUTF8StringEncoding];
		shlist.name = [fields objectAtIndex:1];
		shlist.members_phone_nums = [NSArray arrayWithObjects:[fields objectAtIndex:2], nil];
		shlist.items_ready = 0;
		shlist.items_total = 0;

		if ([self check_tvc:shlist_tvc])
			[shlist_tvc finished_new_list_request:shlist];

		[self info:@"network: response for new list '%@' has %i fields",
		 shlist.name, [fields count]];
	}

	else if (msg_type == 3) {
		[self handle_bulk_list_update:msg_string];

		if ([self check_tvc:shlist_tvc])
			[shlist_tvc.tableView reloadData];
	}

	else if (msg_type == 4) {
		SharedList *shlist = [[SharedList alloc] init];
		// XXX: sanitize msg_data, should be base64 and 43 bytes long
		shlist.id = msg_data;

		// XXX: these need to be sent from the server
		shlist.items_ready = 0;
		shlist.items_total = 99;
		// shlist.list_name = <network>;
		// shlist.members = <network>;

		if ([self check_tvc:shlist_tvc])
			[shlist_tvc finished_join_list_request:shlist];
		[self info:@"join list: response '%@' acknowledgedd", msg_string];
	}

	else if (msg_type == 5) {

		NSArray *fields = [msg_string componentsSeparatedByString:@"\0"];
		if ([fields count] != 2) {
			[self warn:@"leave list: response had wrong number (%i) of fields",
			      [fields count]];
			return;
		}

		SharedList *shlist = [[SharedList alloc] init];
		shlist.id = [[fields objectAtIndex:0] dataUsingEncoding:NSUTF8StringEncoding];

		// XXX: these need to be sent from the server
		// shlist.list_name = <network>;
		// shlist.members = <network>;

		if ([self check_tvc:shlist_tvc])
			[shlist_tvc finished_leave_list_request:shlist];
		[self info:@"leave list: response '%@' acknowledgedd", msg_string];
	}
}

- (bool) check_tvc:(MainTableViewController *) tvc
{
	if (tvc)
		return true;
	[self warn:@"network: trying to update main_tvc before it's ready, ignoring!"];
	return false;
}

- (void) handle_bulk_list_update:(NSString *)raw_data
{

	if (![self check_tvc:shlist_tvc])
		return;

	// split over double \0
	NSArray *list_types = [raw_data componentsSeparatedByString:@"\0\0"];
	if ([list_types count] != 2) {
		[self warn:@"bulk list update: wrong number if \\0\\0 found: %i",
			[list_types count]];
		return;
	}

	NSString *my_lists = [list_types objectAtIndex:0];
	NSString *my_friends_lists = [list_types objectAtIndex:1];

	[shlist_tvc.shared_lists removeAllObjects];
	[shlist_tvc.indirect_lists removeAllObjects];

	if ([my_lists length] != 0) {
		NSArray *my_lists_parsed = [self parse_lists:my_lists];
		[shlist_tvc.shared_lists addObjectsFromArray:my_lists_parsed];
	}
	if ([my_friends_lists length] != 0) {
		NSArray *indirect_lists = [self parse_lists:my_friends_lists];
		[shlist_tvc.indirect_lists addObjectsFromArray:indirect_lists];
	}

	[self info:@"bulk list update: %i/%i your lists/other lists",
		[shlist_tvc.shared_lists count], [shlist_tvc.indirect_lists count]];
}

- (NSArray *) parse_lists:(NSString *)raw_lists
{
	// each raw list is separated by a \0
	NSArray *lists = [raw_lists componentsSeparatedByString:@"\0"];
	NSMutableArray *output = [[NSMutableArray alloc] init];

	for (id str in lists) {
		NSArray *list_fields = [str componentsSeparatedByString:@":"];
		int field_count = [list_fields count];

		if (field_count < 3) {
			[self warn:@"parse list: less than 3 fields found: %i", field_count];

			// can't do anything with this list
			continue;
		}
		[self debug:@"parse_list: '%@' has %i fields",
			[list_fields objectAtIndex:0], field_count];

		// we've got everything we need
		SharedList *shared_list = [[SharedList alloc] init];

		shared_list.name = [list_fields objectAtIndex:0];
		shared_list.id = [[list_fields objectAtIndex:1] dataUsingEncoding:NSUTF8StringEncoding];
		shared_list.members_phone_nums = [list_fields subarrayWithRange:NSMakeRange(2, field_count - 2)];

		// we don't currently get this information back
		// XXX: lists your not in will not return this information
		sranddev();
		shared_list.items_ready = rand() % 7;
		shared_list.items_total = 7;

		[output addObject:shared_list];
	}

	return output;
}

#define LOG_LEVEL_ERROR	0
#define LOG_LEVEL_WARN	1
#define LOG_LEVEL_INFO	2
#define LOG_LEVEL_DEBUG	3

#define LOG_LEVEL LOG_LEVEL_INFO

- (void) debug:(NSString *)fmt, ...
{
	va_list va;
	va_start(va, fmt);
	NSString *string = [[NSString alloc] initWithFormat:fmt
						  arguments:va];
	va_end(va);
	if (LOG_LEVEL < LOG_LEVEL_DEBUG)
		return;
	NSLog(@"debug: %@", string);
}

- (void) info:(NSString *)fmt, ...
{
	va_list va;
	va_start(va, fmt);
	NSString *string = [[NSString alloc] initWithFormat:fmt
						  arguments:va];
	va_end(va);
	if (LOG_LEVEL < LOG_LEVEL_INFO)
		return;
	NSLog(@"info: %@", string);
}

- (void) warn:(NSString *)fmt, ...
{
	va_list va;
	va_start(va, fmt);
	NSString *string = [[NSString alloc] initWithFormat:fmt
						  arguments:va];
	va_end(va);
	if (LOG_LEVEL < LOG_LEVEL_WARN)
		return;
	NSLog(@"warn: %@", string);
}

- (void) error:(NSString *)fmt, ...
{
	va_list va;
	va_start(va, fmt);
	NSString *string = [[NSString alloc] initWithFormat:fmt
						  arguments:va];
	va_end(va);
	if (LOG_LEVEL < LOG_LEVEL_ERROR)
		return;
	NSLog(@"error: %@", string);
}

- (void) dealloc
{
	[self disconnect];
}

@end
