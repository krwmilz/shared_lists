#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

	[self showMessage];
	[self initNetworkCommunication];
}

- (void)viewDidUnload
{
	[super viewDidUnload];
	// Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (IBAction)showMessage 
{
	UIAlertView *helloWorldAlert = [[UIAlertView alloc]
		initWithTitle:@"My First App" message:@"Hello, World!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];

	// Display the Hello World Message
	[helloWorldAlert show];
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
