#import "Network.h"
#import "DataStructures.h"

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
		[self connect];
	}

	return self;
}

- (void) connect
{
	NSLog(@"info: network: connecting");

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
	NSLog(@"info: network: disconnecting");

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
	NSLog(@"info: sent registration message");

	// we don't have a device id so we can't do anything yet
	return false;
}

- (void) send_message:(uint16_t)send_msg_type contents:(NSData *)payload
{
	NSMutableData *msg = [NSMutableData data];
	NSLog(@"info: network: send_message: msg type %i", send_msg_type);

	uint16_t msg_type_network = htons(send_msg_type);
	[msg appendBytes:&msg_type_network length:2];

	int payload_length = 0;
	if (payload)
		// include null separator in this length
		payload_length = [payload length] + 1;

	uint16_t msg_len_network = htons([device_id length] + payload_length);
	[msg appendBytes:&msg_len_network length:2];

	if (device_id == nil) {
		NSLog(@"warn: network: send_message called before device_id was ready");
		return;
	}
	[msg appendData:device_id];

	if (payload) {
		[msg appendBytes:"\0" length:1];
		[msg appendData:payload];
	}

	if ([outputShlistStream write:[msg bytes] maxLength:[msg length]] == -1) {
		NSLog(@"warn: network: write error occurred, reconnecting");
		[self disconnect];
		[self connect];

		if ([outputShlistStream write:[msg bytes] maxLength:[msg length]] == -1) {
			NSLog(@"warn: network: resend failed after reconnect, giving up");
		}
	}
	NSLog(@"info: network: send_message: msg type %i done", send_msg_type);
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
	NSString *stream_name;
	if (stream == inputShlistStream)
		stream_name = @"input";
	else if (stream == outputShlistStream)
		stream_name = @"output";

	switch (eventCode) {
	case NSStreamEventNone:
		NSLog(@"NSStreamEventNone");
		break;
	case NSStreamEventOpenCompleted:
		NSLog(@"info: network: %@ stream opened", stream_name);
	break;
	case NSStreamEventHasBytesAvailable:
	if (stream == inputShlistStream) {
		if (![inputShlistStream hasBytesAvailable]) {
			NSLog(@"warn: network: input stream had no bytes available");
			break;
		}

		// advance the message state machine by at least one byte
		[self process_response_bytes];
	}
	break;
	case NSStreamEventHasSpaceAvailable:
		NSLog(@"info: network: stream has space available");
		break;
	case NSStreamEventErrorOccurred:
		// I saw this case when trying to connect to a down server

		NSLog(@"info: network: stream error occurred");
		[self disconnect];

		// fall through on purpose
	case NSStreamEventEndEncountered:

		// close both sides of the connection on end
		NSLog(@"ShlistServer::NSStreamEventEndEncountered");
		[self disconnect];

		break;
	default:
		NSLog(@"handleEvent: default case");
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
			NSLog(@"warn: network: read returned < 0: %i", buffer_length);
			// XXX: should this be break instead?
			continue;
		}

		if (buffer_length == 0) {
			NSLog(@"warn: network: buffer length was zero!");
			// maybe break here instead?
			continue;
		}
		NSLog(@"info: network: processing %i bytes", buffer_length);

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
				NSLog(@"warn: network: out of range msg type %i", buffer[0]);

				// bad message type, reset message buffer
				msg_type_pos = 0;
				msg_buf_position = 0;
				msg_total_bytes_pos = 0;
				continue;
			}
			NSLog(@"info: network: got message type %i", msg_type);

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
				NSLog(@"warn: network: out of range message length: 0 < %i < 1024",
				      msg_total_bytes);

				// bad message type, reset message buffer
				msg_type_pos = 0;
				msg_buf_position = 0;
				msg_total_bytes_pos = 0;
				continue;
			}
			NSLog(@"info: network: message length is %i bytes", msg_total_bytes);

			if (buffer_pos == buffer_length)
				// no more bytes to process
				continue;
		}

		unsigned int remaining_bytes = buffer_length - buffer_pos;

		if (msg_buf_position + remaining_bytes >= msg_total_bytes) {
			NSLog(@"info: network: buffer length has enough space to read complete message");

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
			NSLog(@"error: network: register: not overwriting key file with '%@'", msg_string);
			return;
		}

		NSLog(@"info: network: register: writing new key '%@' to disk", msg_string);
		[msg_data writeToFile:device_id_file atomically:YES];

		// set this so we're ready to send other message types
		device_id = msg_data;

		// do a bulk list update
		[self send_message:3 contents:nil];
	}

	else if (msg_type == 1) {
		NSArray *fields = [msg_string componentsSeparatedByString:@"\0"];

		if ([fields count] != 3) {
			NSLog(@"warn: network: new list response has invalid number of fields %i",
			      [fields count]);
			return;
		}

		SharedList *shlist = [[SharedList alloc] init];
		shlist.id = [[fields objectAtIndex:0] dataUsingEncoding:NSUTF8StringEncoding];
		shlist.name = [fields objectAtIndex:1];
		shlist.members_phone_nums = [NSArray arrayWithObjects:[fields objectAtIndex:2], nil];
		shlist.items_ready = 0;
		shlist.items_total = 0;

		NSLog(@"info: network: response for new list '%@' has %i fields",
		      shlist.name, [fields count]);
		if ([self check_tvc:shlist_tvc])
			[shlist_tvc finished_new_list_request:shlist];
	}

	else if (msg_type == 3) {
		[self handle_bulk_list_update:msg_string];

		if ([self check_tvc:shlist_tvc])
			[shlist_tvc.tableView reloadData];
	}

	else if (msg_type == 4) {
		NSLog(@"info: join list response '%@'", msg_string);

		SharedList *shlist = [[SharedList alloc] init];
		shlist.id = msg_data;

		// XXX: these need to be sent from the server
		shlist.items_ready = 0;
		shlist.items_total = 99;
		// shlist.list_name = <network>;
		// shlist.members = <network>;

		if ([self check_tvc:shlist_tvc])
			[shlist_tvc finished_join_list_request:shlist];
	}

	else if (msg_type == 5) {
		NSLog(@"info: leave list response '%@'", msg_string);

		NSArray *fields = [msg_string componentsSeparatedByString:@"\0"];

		if ([fields count] != 2) {
			NSLog(@"warn: leave list response had wrong number (%i) of fields",
			      [fields count]);
			return;
		}

		SharedList *shlist = [[SharedList alloc] init];
		shlist.id = [[fields objectAtIndex:0] dataUsingEncoding:NSUTF8StringEncoding];

		// XXX: these need to be sent from the server
		// shlist.list_name = <network>;
		// shlist.members = <network>;

		if ([self check_tvc:shlist_tvc])
			[shlist_tvc finished_leave_list_request:shlist];
	}
}

- (bool) check_tvc:(MainTableViewController *) tvc
{
	if (tvc)
		return true;
	NSLog(@"warn: network: trying to update main_tvc before it's ready, ignoring!");
	return false;
}

- (void) handle_bulk_list_update:(NSString *)raw_data
{
	NSLog(@"info: handling bulk list update message");

	if (![self check_tvc:shlist_tvc])
		return;

	// split over double \0
	NSArray *list_types = [raw_data componentsSeparatedByString:@"\0\0"];
	if ([list_types count] != 2) {
		NSLog(@"warn: wrong number if \\0\\0 found: %i", [list_types count]);
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
			NSLog(@"warn: less than 3 fields found: %i", field_count);

			// can't do anything with this list
			continue;
		}
		NSLog(@"info: parse_list: '%@' has %i fields",
		      [list_fields objectAtIndex:0], field_count);

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

- (void) dealloc
{
	[self disconnect];
}

@end
