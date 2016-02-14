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
	NSString *device_id = [netconn get_device_id];
	_device_id_label.text = [device_id substringToIndex:8];

	if ([netconn connected])
		_network_label.text = @"Connected";
	else
		_network_label.text = @"Disconnected";
	netconn->settings_tvc = self;
}

- (void) update_network_text:(NSString *)new_text
{
	_network_label.text = new_text;
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
