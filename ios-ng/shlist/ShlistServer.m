#import "ShlistServer.h"
#import "SharedList.h"
#import "AddressBook.h"

@interface ShlistServer ()

@property (strong, retain) NSMutableData *data;
@property (strong, retain) AddressBook *address_book;
@property NSMutableDictionary *phnum_to_name_map;


@property (strong, nonatomic) NSString *phone_number;
@property (strong, nonatomic) NSData *device_id;

@end

@implementation ShlistServer

- (id) init
{
	if (self = [super init]) {
		/*
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
		*/

		// get instance and wait for privacy window to clear
		_address_book = [AddressBook shared_address_book];
		[_address_book wait_for_ready];

		// the capacity here assumes one phone number per person
		_phnum_to_name_map = [NSMutableDictionary
				      dictionaryWithCapacity:_address_book.num_contacts];

		for (Contact *contact in _address_book.contacts) {
			NSString *disp_name;
			// show first name and last initial if possible, otherwise
			// just show the first name or the last name or the phone number
			if (contact.first_name && contact.last_name)
				disp_name = [NSString stringWithFormat:@"%@ %@",
					     contact.first_name, [contact.last_name substringToIndex:1]];
			else if (contact.first_name)
				disp_name = contact.first_name;
			else if (contact.last_name)
				disp_name = contact.last_name;
			else if ([contact.phone_numbers count])
				disp_name = [contact.phone_numbers objectAtIndex:0];
			else
				disp_name = @"No Name";

			// map the persons known phone number to their massaged name
			for (NSString *phone_number in contact.phone_numbers)
				[_phnum_to_name_map setObject:disp_name forKey:phone_number];
		}
	}

	return self;
}

- (bool) prepare
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];

	// NSString *phone_num_file = [documentsDirectory stringByAppendingPathComponent:@"phone_num"];
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
		_phone_number = @"4037082094";
		[msg appendBytes:phone_number length:10];

		[self writeToServer:msg];
		NSLog(@"info: sent registration message");

		// we don't have a device id so we can't do anything yet
		return false;
	}

	// read device id from filesystem into memory
	_device_id = [NSData dataWithContentsOfFile:device_id_file];

	return true;
}

- (void) send_message:(uint16_t)msg_type contents:(NSData *)payload
{
	NSMutableData *msg = [NSMutableData data];

	uint16_t msg_type_network = htons(msg_type);
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

	[self writeToServer:msg];
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
	case NSStreamEventNone:
		break;
	case NSStreamEventOpenCompleted:
	if (stream == inputShlistStream) {
		NSLog(@"info: input stream opened");
	}
	else if (stream == outputShlistStream) {
		NSLog(@"info: output stream opened");
	}
	break;
	case NSStreamEventHasBytesAvailable:
	if (stream == inputShlistStream) {
		/*
		if (![inputShlistStream hasBytesAvailable]) {
			break;
		}
		*/

		NSInteger len;
		uint16_t msg_metadata[2];

		len = [inputShlistStream read:(uint8_t *)&msg_metadata maxLength:4];
		if (len != 4) {
			NSLog(@"warn: read: msg metadata was %li bytes, expected 4",
					(long)len);
			break;
		}

		uint16_t msg_type = ntohs(msg_metadata[0]);
		uint16_t msg_length = ntohs(msg_metadata[1]);
		if (msg_type > 6) {
			NSLog(@"warn: read: out of range msg type %i", msg_type);
			break;
		}

		NSLog(@"info: read: received message type %i", msg_type);

		if (msg_length > 1024) {
			NSLog(@"warn: read: message too large: %i bytes", msg_length);
			break;
		}
		NSLog(@"info: read: message size is %i bytes", msg_length);

		uint8_t *buffer = malloc(msg_length);
		if (buffer == nil) {
			NSLog(@"warn: read: couldn't allocate receiving buffer size %i",
			      msg_length);
			break;
		}

		len = [inputShlistStream read:buffer maxLength:msg_length];
		if (len != msg_length) {
			NSLog(@"warn: read: main message read byte mismatch: %li vs %i",
				(long)len, msg_length);
			break;
		}
		NSString *output = [[NSString alloc] initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];
		NSData *data = [[NSData alloc] initWithBytes:buffer length:msg_length];

		if (output == nil) {
			NSLog(@"warn: read: couldn't allocate output string");
			break;
		}
		// NSLog(@"info: read: message is %@", output);
		
		if (msg_type == 0) {
			// write key to file
			NSLog(@"info: read: writing new keyfile to disk");
			
			NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
			NSString *documentsDirectory = [paths objectAtIndex:0];
			
			NSString *destinationPath = [documentsDirectory stringByAppendingPathComponent:@"shlist_key"];
			// if (![[NSFileManager defaultManager] fileExistsAtPath:destinationPath]) {
				[data writeToFile:destinationPath atomically:YES];
			// }

			// set this so we're ready to send other message types
			_device_id = data;

			// do a bulk list update
			[self send_message:3 contents:nil];
		}

		if (msg_type == 1) {
			NSLog(@"info: got new list response, not doing anything with it");
		}

		if (msg_type == 3) {
			[self handle_bulk_list_update:output];
		}

		if (msg_type == 4) {
			NSLog(@"info: got response from join list request, '%@'", output);

			SharedList *shlist = [[SharedList alloc] init];
			shlist.list_id = data;

			// XXX: these need to be sent from the server
			shlist.items_ready = 0;
			shlist.items_total = 99;
			// shlist.list_name = <network>;
			// shlist.members = <network>;

			[shlist_tvc finished_join_list_request:shlist];
		}

		if (msg_type == 5) {
			NSLog(@"info: leave list response '%@'", output);

			// [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];

			/*
			for (SharedList *list in shlist_tvc.shared_lists) {
				if (list.list_name == output) {
					[shlist_tvc.indirect_lists addObject:list];
					[shlist_tvc.shared_lists removeObject:list];

					break;
				}
			}
			[shlist_tvc.tableView reloadData];
			 */
		}
	}
	break;
	case NSStreamEventHasSpaceAvailable:
		[self _writeData];
		break;
	case NSStreamEventErrorOccurred:
		NSLog(@"ShlistServer::NSStreamEventErrorOccurred");
		    // I saw this case when trying to connect to a down server
		break;
	case NSStreamEventEndEncountered:
	{
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

	    break;
	}
	default:
		break;
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

		NSMutableArray *members = [[NSMutableArray alloc] init];
		int others = 0;

		// anything past the second field are list members
		NSArray *phone_numbers = [list_fields subarrayWithRange:NSMakeRange(2, field_count - 2)];
		for (id phone_number in phone_numbers) {

			// try to find the list member in our address book
			NSString *name = _phnum_to_name_map[phone_number];

			if (name)
				[members addObject:name];
			else if ([phone_number compare:_phone_number])
				[members addObject:@"You"];
			else
				// didn't find it, you don't know this person
				others++;
		}

		NSMutableString *members_str =
			[[members componentsJoinedByString:@", "] mutableCopy];

		if (others) {
			char *plural;
			if (others == 1)
				plural = "other";
			else
				plural = "others";

			NSString *buf = [NSString stringWithFormat:@" + %i %s",
					 others, plural];
			[members_str appendString:buf];
		}

		// we've got everything we need
		SharedList *shared_list = [[SharedList alloc] init];

		shared_list.list_name = [list_fields objectAtIndex:0];
		shared_list.list_id = [[list_fields objectAtIndex:1] dataUsingEncoding:NSUTF8StringEncoding];
		shared_list.list_members = members_str;

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

- (void) _readData
{
}

- (void) _writeData
{
    NSLog(@"_writeData");
}

- (void) writeToServer:(NSData *)data
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

	// const char bytes[] = "\x00\x00\xff\0x00";
	//string literals have implicit trailing '\0'
	// size_t length = (sizeof bytes) - 1;
	
	// NSData *data = [NSData dataWithBytes:bytes length:length];
	NSLog(@"writeToServer()");
	[outputShlistStream write:[data bytes] maxLength:[data length]];
}

// - (void) readFromServer:


@end
