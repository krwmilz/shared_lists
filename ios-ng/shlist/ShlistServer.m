#import "ShlistServer.h"
#import "SharedList.h"
#import "AddressBook.h"

@interface ShlistServer ()

@property (strong, retain) NSMutableData *data;
@property (strong, retain) AddressBook *address_book;

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

		_address_book = [[AddressBook alloc] init];
	}

	return self;
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
		}

		if (msg_type == 1) {
			NSLog(@"info: got new list response, not doing anything with it");
		}

		if (msg_type == 3) {
			[self handle_bulk_list_update:output];
		}

		if (msg_type == 4) {
			NSLog(@"info: got response from join list request, '%@'", output);

			for (SharedList *list in shlist_tvc.indirect_lists) {
				if (list.list_name == output) {
					[shlist_tvc.shared_lists addObject:list];
					[shlist_tvc.indirect_lists removeObject:list];
					break;
				}
			}
			[shlist_tvc.tableView reloadData];
		}

		if (msg_type == 5) {
			NSLog(@"info: got response from leave list request");

			for (SharedList *list in shlist_tvc.shared_lists) {
				if (list.list_name == output) {
					[shlist_tvc.indirect_lists addObject:list];
					[shlist_tvc.shared_lists removeObject:list];
					break;
				}
			}
			[shlist_tvc.tableView reloadData];
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


		NSMutableArray *friends = [[NSMutableArray alloc] init];
		int others = 0;

		// anything past the second field are list members
		NSArray *phone_numbers = [list_fields subarrayWithRange:NSMakeRange(2, field_count - 2)];
		for (id phone_number in phone_numbers) {

			/* try to find the list member in our address book */
			NSString *name = _address_book.name_map[phone_number];

			if (name)
				[friends addObject:name];
			else
				/* didn't find it, you don't know this person */
				others++;
		}

		NSMutableString *members_str =
			[[friends componentsJoinedByString:@", "] mutableCopy];

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

		/* we've got everything we need */
		SharedList *shared_list = [[SharedList alloc] init];

		shared_list.list_name = [list_fields objectAtIndex:0];
		shared_list.list_id = [list_fields objectAtIndex:1];
		shared_list.list_members = members_str;

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
