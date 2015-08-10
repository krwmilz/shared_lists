#import "ShlistServer.h"
#import "SharedList.h"

@interface ShlistServer ()

@property (strong, retain) NSMutableData *data;

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
			NSLog(@"info: read: processing bulk list update message");

			// split over double \0
			NSArray *list_types = [output componentsSeparatedByString:@"\0\0"];
			if ([list_types count] != 2) {
				NSLog(@"warn: more than one \\0\\0 found in response");
				break;
			}

			// split over \0
			NSString *direct_list_str = [list_types objectAtIndex:0];
			NSString *indirect_list_str = [list_types objectAtIndex:1];

			if ([direct_list_str length] != 0) {
				NSArray *direct_lists = [direct_list_str componentsSeparatedByString:@"\0"];
				[shlist_tvc.shared_lists removeAllObjects];

				for (id str in direct_lists) {
					// NSLog(@"info: got raw direct list %@", str);

					NSArray *broken_down_list = [str componentsSeparatedByString:@":"];

					SharedList *shared_list = [[SharedList alloc] init];
					shared_list.list_name = [broken_down_list objectAtIndex:0];
					shared_list.list_id = [broken_down_list objectAtIndex:1];
					shared_list.list_members = [broken_down_list objectAtIndex:2];

					NSLog(@"info: network: got direct list '%@'", shared_list.list_name);
					[shlist_tvc.shared_lists addObject:shared_list];

					// [direct_shared_lists addObject:shared_list];
				}

			}
			if ([indirect_list_str length] != 0) {
				NSArray *indirect_lists = [indirect_list_str componentsSeparatedByString:@"\0"];
				[shlist_tvc.indirect_lists removeAllObjects];

				for (id str in indirect_lists) {
					NSArray *broken_down_list = [str componentsSeparatedByString:@":"];

					SharedList *shared_list = [[SharedList alloc] init];
					shared_list.list_name = [broken_down_list objectAtIndex:0];
					shared_list.list_id = [broken_down_list objectAtIndex:1];
					shared_list.list_members = [broken_down_list objectAtIndex:2];

					NSLog(@"info: network: got indirect list '%@'", shared_list.list_name);
					[shlist_tvc.indirect_lists addObject:shared_list];
				}
			}
			[shlist_tvc.tableView reloadData];

			/*
			dispatch_async(dispatch_get_main_queue(), ^{
				shlist_tvc.shared_lists = direct_shared_lists;
				[shlist_tvc.tableView reloadData];
			});
			 */
			// [shlist_tvc update_shared_lists:direct_shared_lists :indirect_shared_lists];

			// NSLog(@"info: %i direct lists, %i indirect lists");
		}

		if (msg_type == 4) {
			NSLog(@"info: got response from join list request, '%@'", output);

			/*
			for (id list in shlist_tvc.indirect_lists) {
				if (list.list_name == output) {
					[shlist_tvc.indirect_lists removeObject:list];
					break;
				}
			}
			shlist_tvc.shared_lists
			[shlist_tvc.tableView reloadData];
			 */
		}

		if (msg_type == 5) {
			NSLog(@"info: got response from leave list request");
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
