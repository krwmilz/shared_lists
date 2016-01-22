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

	netconn = [Network shared_network_connection];
	NSString *device_id = [[NSString alloc] initWithData:[netconn get_device_id] encoding:NSASCIIStringEncoding];
	_device_id_label.text = [device_id substringToIndex:8];
}

- (void) viewWillAppear:(BOOL)animated
{
	// check every time this view is selected
	_network_label.text = @"Checking...";
	netconn->settings_tvc = self;
	[netconn send_message:8 contents:nil];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (void) finish_ok_request
{
	_network_label.text = @"All good";
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
