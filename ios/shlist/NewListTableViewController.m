#import "NewListTableViewController.h"
#import "EditTableViewController.h"
#import "Network.h"

@interface NewListTableViewController () {
	Network *network_connection;
}

@property (weak, nonatomic) IBOutlet UIBarButtonItem	*saveButton;
@property (weak, nonatomic) IBOutlet UISwitch		*deadline_switch;
@property (weak, nonatomic) IBOutlet UILabel		*list_name;

// @property (weak, nonatomic) IBOutlet UITextField	*textField;
@property (weak, nonatomic) IBOutlet UIDatePicker	*datePicker;

@end

@implementation NewListTableViewController

- (IBAction)deadline_toggle:(id)sender {

	// UISwitch *dl_switch = (UISwitch *)sender;
	NSIndexSet *index_set = [NSIndexSet indexSetWithIndex:1];

	if ([self.tableView numberOfSections] == 1)
		[self.tableView insertSections:index_set withRowAnimation:UITableViewRowAnimationMiddle];
	else
		[self.tableView deleteSections:index_set withRowAnimation:UITableViewRowAnimationMiddle];
}

- (IBAction) unwindToAddList:(UIStoryboardSegue *)segue
{
	NSLog(@"unwound");
}

- (void) viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view.

	_list_name.text = @"New List";
	network_connection = [Network shared_network_connection];
}

- (void) didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
	if (_deadline_switch.isOn)
		return 2;
	else
		return 1;
	return 0;
}

// preparation before navigation
- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if ([[segue identifier] isEqualToString:@"edit name segue"]) {
		// segue forwards to name editor
		NSLog(@"debug: %@: editing name", _list_name.text);

		// EditTableViewController *edit = [segue destinationViewController];
		// edit.list_name.text = @"New List";
		return;
	}

	// jump backwards to previous view controller
	if (sender != self.saveButton)
		return;

	SharedList *shared_list = [[SharedList alloc] init];

	// saving, copy form fields into shared list object
	shared_list.name = _list_name.text;
	shared_list.deadline = _deadline_switch.isOn;
	// _shared_list.filters = ???

	NSLog(@"new_list: sending list_add request...");

	NSMutableDictionary *list = [[NSMutableDictionary alloc] init];
	[list setObject:[NSNumber numberWithInt:0] forKey:@"num"];
	[list setObject:shared_list.name forKey:@"name"];
	[list setObject:[NSNumber numberWithInt:0] forKey:@"date"];

	NSMutableDictionary *request = [[NSMutableDictionary alloc] init];
	[request setObject:list forKey:@"list"];

	[network_connection send_message:list_add contents:request];
}

@end