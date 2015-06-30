#import "Server.h"

@interface Server ()

- (void)network_init;

@end

@implementation Server

NSInputStream *inputStream;
NSOutputStream *outputStream;

bool initialized = 0;

- (void)network_init
{
	CFReadStreamRef readStream;
	CFWriteStreamRef writeStream;

	CFStringRef host_name = CFSTR("absentmindedproductions.ca");

	CFStreamCreatePairWithSocketToHost(NULL, host_name, 5437, &readStream, &writeStream);
	inputStream = (__bridge NSInputStream *)readStream;
	outputStream = (__bridge NSOutputStream *)writeStream;

	[inputStream setDelegate:self];
	[outputStream setDelegate:self];

	[inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

	[inputStream open];
	[outputStream open];
}

- (void)read
{
	if (!initialized) {
		[self network_init];
	}
}

- (void)write
{
	if (!initialized) {
		[self network_init];
	}
}


@end
