#import "ShlistServer.h"

@interface ShlistServer ()

@property (strong, retain) NSMutableData *data;

@end

@implementation ShlistServer

- (id) init
{
	if (self = [super init]) {
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

	return self;
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
	case NSStreamEventNone:
		break;
	case NSStreamEventOpenCompleted:
		NSLog(@"Stream Opened");
		break;
	case NSStreamEventHasBytesAvailable:
	
	if (aStream == inputShlistStream) {
		NSInteger len;
		uint16_t msg_metadata[2];

		len = [inputShlistStream read:(uint8_t *)&msg_metadata maxLength:4];

		if (len != 4) {
			NSLog(@"warn: msg metadata was %li bytes, expected 4 bytes",
					(long)len);
			break;
		}
		if (msg_metadata[0] > 4) {
			NSLog(@"warn: out of range msg type %i", msg_metadata[0]);
			break;
		}

		NSLog(@"info: received message type %i", msg_metadata[0]);

		if (msg_metadata[1] > 1024) {
			NSLog(@"warn: message too large: %i bytes", msg_metadata[1]);
			break;
		}
		NSLog(@"info: message size is %i bytes", msg_metadata[1]);
			
		uint8_t *buffer = malloc(msg_metadata[1]);
		if (buffer == nil) {
			NSLog(@"warn: couldn't allocate receiving buffer size %i",
			      msg_metadata[1]);
			break;
		}
		
		len = [inputShlistStream read:buffer maxLength:msg_metadata[1]];
		if (len != msg_metadata[1]) {
			NSLog(@"warn: main message read byte mismatch: %li vs %i",
				(long)len, msg_metadata[1]);
			break;
		}
		NSString *output = [[NSString alloc] initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];

		if (output == nil) {
			NSLog(@"warn: couldn't allocate output string");
			break;
		}
		NSLog(@"info: message is %@", output);
	}
	break;
	case NSStreamEventHasSpaceAvailable:
		[self _writeData];
		break;
	case NSStreamEventErrorOccurred:
		NSLog(@"ShlistServer::NSStreamEventErrorOccurred");
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

- (void) writeToServer:(const char *)bytes :(size_t)length
{
	// const char bytes[] = "\x00\x00\xff\0x00";
	//string literals have implicit trailing '\0'
	// size_t length = (sizeof bytes) - 1;
	
	NSData *data = [NSData dataWithBytes:bytes length:length];
	[outputShlistStream write:[data bytes] maxLength:[data length]];
}

// - (void) readFromServer:


@end
