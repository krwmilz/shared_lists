#import "Network.h"
#import "DataStructures.h"

@interface Network () {
	NSData *msg_data;
	NSString *msg_string;
	uint8_t msg_buffer[1024];
	unsigned int msg_buf_position;

	uint8_t msg_total_bytes_tmp[2];
	unsigned short msg_total_bytes;
	unsigned int msg_total_bytes_pos;

	uint8_t msg_type_tmp[2];
	unsigned short msg_type;
	unsigned int msg_type_pos;

	int connected;
}

// @property (strong, retain) NSMutableData *data;
@property (strong, nonatomic) NSData *device_id;

@end

@implementation Network

- (id) init
{
	if (self = [super init]) {
		connected = 0;
		msg_buf_position = 0;

		msg_total_bytes = 0;
		msg_total_bytes_pos = 0;

		msg_type = 0;
		msg_type_pos = 0;
	}

	return self;
}

- (void) connect
{
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

	NSLog(@"info: network: finished connecting to absentmindedproductions.ca");
}

- (bool) prepare
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];

	NSString *device_id_file = [documentsDirectory stringByAppendingPathComponent:@"shlist_key"];

	// NSError *error = nil;
	// [[NSFileManager defaultManager] removeItemAtPath:destinationPath error:&error];

	// TODO: also check the length of the file
	if (![[NSFileManager defaultManager] fileExistsAtPath:device_id_file]) {
		// no device id file found, send a registration message
		NSMutableData *msg = [NSMutableData data];

		// message type 0
		[msg appendBytes:"\x00\x00" length:2];

		// phone number length is 10
		uint16_t length_network = htons(10);
		[msg appendBytes:&length_network length:2];

		// actual phone number
		const char *phone_number = "4037082094";
		[msg appendBytes:phone_number length:10];

		if (connected == 0)
			[self connect];
		[outputShlistStream write:[msg bytes] maxLength:[msg length]];
		NSLog(@"info: sent registration message");

		// we don't have a device id so we can't do anything yet
		return false;
	}

	// read device id from filesystem into memory
	_device_id = [NSData dataWithContentsOfFile:device_id_file];

	return true;
}

- (void) send_message:(uint16_t)send_msg_type contents:(NSData *)payload
{
	NSMutableData *msg = [NSMutableData data];

	uint16_t msg_type_network = htons(send_msg_type);
	[msg appendBytes:&msg_type_network length:2];

	int payload_length = 0;
	if (payload)
		// include null separator in this length
		payload_length = [payload length] + 1;

	uint16_t msg_len_network = htons([_device_id length] + payload_length);
	[msg appendBytes:&msg_len_network length:2];

	[msg appendData:_device_id];

	if (payload) {
		[msg appendBytes:"\0" length:1];
		[msg appendData:payload];
	}

	if (connected == 0) {
		NSLog(@"info: network: not connected in send_message, reconnecting...");
		[self connect];
	}
	if ([outputShlistStream write:[msg bytes] maxLength:[msg length]] == -1)
		NSLog(@"warn: network: write error occurred");
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
		break;
	case NSStreamEventOpenCompleted:
		NSLog(@"info: network: %@ stream opened", stream_name);
		connected = 1;
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
		NSLog(@"info: network: stream error occurred");
		    // I saw this case when trying to connect to a down server
		break;
	case NSStreamEventEndEncountered:

		// close both sides of the connection on end
		NSLog(@"ShlistServer::NSStreamEventEndEncountered");
		[inputShlistStream close];
		[outputShlistStream close];

		[inputShlistStream removeFromRunLoop:[NSRunLoop currentRunLoop]
			forMode:NSDefaultRunLoopMode];
		[outputShlistStream removeFromRunLoop:[NSRunLoop currentRunLoop]
			forMode:NSDefaultRunLoopMode];
		// [inputShlistStream release];
		// [outputShlistStream release];

		inputShlistStream = nil; // stream is ivar, so reinit it
		outputShlistStream = nil; // stream is ivar, so reinit it
			connected = 0;

		break;
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

			[self handle_message];

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

- (void) handle_message
{
	// assert msg_type_pos == 2 and msg_total_bytes_pos == 2 and msg_buf_position == msg_total_bytes

	if (msg_type == 0) {
		// write key to file
		NSLog(@"info: read: writing new keyfile to disk");

		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *documentsDirectory = [paths objectAtIndex:0];

		NSString *destinationPath = [documentsDirectory stringByAppendingPathComponent:@"shlist_key"];
		// if (![[NSFileManager defaultManager] fileExistsAtPath:destinationPath]) {
		[msg_data writeToFile:destinationPath atomically:YES];
		// }

		// set this so we're ready to send other message types
		_device_id = msg_data;

		// do a bulk list update
		[self send_message:3 contents:nil];
	}

	if (msg_type == 1) {
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

		NSLog(@"info: network: new list response for '%@'", shlist.name);
		[shlist_tvc finished_new_list_request:shlist];
	}

	if (msg_type == 3) {
		[self handle_bulk_list_update:msg_string];
	}

	if (msg_type == 4) {
		NSLog(@"info: join list response '%@'", msg_string);

		SharedList *shlist = [[SharedList alloc] init];
		shlist.id = msg_data;

		// XXX: these need to be sent from the server
		shlist.items_ready = 0;
		shlist.items_total = 99;
		// shlist.list_name = <network>;
		// shlist.members = <network>;

		[shlist_tvc finished_join_list_request:shlist];
	}

	if (msg_type == 5) {
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

		[shlist_tvc finished_leave_list_request:shlist];
	}
}

- (void) handle_bulk_list_update:(NSString *)raw_data
{
	NSLog(@"info: handling bulk list update message");

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

	[shlist_tvc.tableView reloadData];
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
	[inputShlistStream close];
	[outputShlistStream close];

	[inputShlistStream removeFromRunLoop:[NSRunLoop currentRunLoop]
				 forMode:NSDefaultRunLoopMode];
	[outputShlistStream removeFromRunLoop:[NSRunLoop currentRunLoop]
					 forMode:NSDefaultRunLoopMode];

	inputShlistStream = nil; // stream is ivar, so reinit it
	outputShlistStream = nil; // stream is ivar, so reinit it
}

@end
