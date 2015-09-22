#import "NewListTableViewController.h"
#import "EditTableViewController.h"

@interface NewListTableViewController () {
	int num_sections;
}

@property (weak, nonatomic) IBOutlet UIBarButtonItem	*saveButton;
@property (weak, nonatomic) IBOutlet UISwitch		*deadline_switch;
@property (weak, nonatomic) IBOutlet UILabel		*list_name;

@property (weak, nonatomic) IBOutlet UITextField	*textField;
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

	num_sections = 1;
}

- (void) didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
	if (_deadline_switch.isOn) {
		return 2;
	} else {
		return 1;
	}
	// default with deadline turned off
	return num_sections;
}

#pragma mark - Navigation

// preparation before navigation
- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if ([[segue identifier] isEqualToString:@"edit name segue"]) {
		NSLog(@"info: new list: edit name segue");

		// EditTableViewController *edit = [segue destinationViewController];
		// edit.list_name.text = @"New List";
		return;
	}

	if (sender != self.saveButton)
		return;

	// if (self.textField.text.length > 0) {
		self.shared_list = [[SharedList alloc] init];
		self.shared_list.name = self.list_name.text;
		// self.shared_list.list_date = self.datePicker.date;
		// self.shared_list.members = @"You";

		NSLog(@"NewListViewController::prepareForSegue(): %@", self.textField.text);
	// }
}

@end