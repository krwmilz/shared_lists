#import "SettingsTableViewController.h"

#import "Network.h"

@interface SettingsTableViewController () {
	Network *netconn;
}

@property (weak, nonatomic) IBOutlet UILabel *phone_number_label;
@property (weak, nonatomic) IBOutlet UILabel *device_id_label;
@property (weak, nonatomic) IBOutlet UILabel *network_label;

@end

@implementation SettingsTableViewController

- (void)viewDidLoad
{
	[super viewDidLoad];

	NSNotificationCenter *default_center = [NSNotificationCenter defaultCenter];
	// Listen for network connect/disconnect events and set the text field accordingly
	[default_center addObserver:self selector:@selector(set_network_text_connected)
			       name:@"NetworkConnectedNotification" object:nil];

	[default_center addObserver:self selector:@selector(set_network_text_disconnected)
			       name:@"NetworkDisconnectedNotification" object:nil];

	netconn = [Network shared_network_connection];
	NSString *device_id = [netconn get_device_id];

	// Just show the first 8 characters of the device id (aka device fingerprint)
	_device_id_label.text = [device_id substringToIndex:8];

	if ([netconn connected])
		[self set_network_text_connected];
	else
		[self set_network_text_disconnected];
}

- (void) set_network_text_connected
{
	_network_label.text = @"Connected";
}

- (void) set_network_text_disconnected
{
	_network_label.text = @"Disconnected";
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
