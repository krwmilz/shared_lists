#import "RootViewController.h"

@implementation RootViewController

NSInputStream *inputStream;
NSOutputStream *outputStream;

- (void)loadView {
	self.view = [[[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]] autorelease];
	self.view.backgroundColor = [UIColor redColor];

	[self initNetworkCommunication];
}

- (void)initNetworkCommunication
{
	CFReadStreamRef readStream;
	CFWriteStreamRef writeStream;

	CFStreamCreatePairWithSocketToHost(NULL, (CFStringRef)@"absentmindedproductions.ca", 5437, &readStream, &writeStream);
	inputStream = (NSInputStream *)readStream;
	outputStream = (NSOutputStream *)writeStream;

	[inputStream setDelegate:self];
	[outputStream setDelegate:self];

	[inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

	[inputStream open];
	[outputStream open];
}
@end
