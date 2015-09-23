#import "EditItemTableViewController.h"
#import "Network.h"

@interface EditItemTableViewController () {
	Network *network_connection;
}

@property (weak, nonatomic) IBOutlet UIBarButtonItem *save_button;

@property (weak, nonatomic) IBOutlet UILabel *item_name;
@property (weak, nonatomic) IBOutlet UILabel *quantity_label;
@property (weak, nonatomic) IBOutlet UISwitch *shared_sw;

@property (weak, nonatomic) IBOutlet UILabel *owner_label;
@property (weak, nonatomic) IBOutlet UILabel *price_label;


@end

@implementation EditItemTableViewController

// called when shared switch is toggled
- (IBAction)shared_switch:(id)sender
{
	NSIndexSet *index_set = [NSIndexSet indexSetWithIndex:1];

	if (_item.shared) {
		_item.shared = false;
		// XXX: send network request with list id, item id, and this device id
		[self.tableView deleteSections:index_set withRowAnimation:UITableViewRowAnimationMiddle];
	} else {
		_item.shared = true;
		// XXX: send item commit network request with list id, item id, and this device id
		[self.tableView insertSections:index_set withRowAnimation:UITableViewRowAnimationMiddle];
	}
}

- (void) set_item:(ListItem *)item for_list:(SharedList *)list;
{
	_list = list;
	_item = item;
}

- (void) set_edit_or_new:(NSString *)edit_or_new;
{
	self.title = edit_or_new;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	network_connection = [Network shared_network_connection];

	[_shared_sw setOn:_item.shared animated:YES];
	[_item_name setText:_item.name];
	[_quantity_label setText:[NSString stringWithFormat:@"%i", _item.quantity]];

	if (_item.committed)
		_owner_label.text = _item.owner;
	else
		_owner_label.text = @"";

	[_price_label setText:@"$26.99"];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	if (_item.shared)
		return 2;
	else
		return 1;
}

// fill in the static table view cells with information
- (UITableViewCell *)tableView:(UITableView *)tableView
	 cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];

	if ([indexPath section] == 1) {
		/*
		if ([indexPath row] == 0) {
			UILabel *owner = (UILabel *)[cell viewWithTag:1];

			if (_item.committed)
				owner.text = _item.owner;
			else
				owner.text = @"";
		}
		 */
	}

	return cell;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if (sender != self.save_button)
		return;

	// save item, item_id could be incrementing unique integer
	// device_id:list_id:item_id:name:quantity:owner:committed:complete
	NSMutableArray *string_array = [[NSMutableArray alloc] init];
	[string_array addObject:_item.name];
	[string_array addObject:[NSString stringWithFormat:@"%i", _item.quantity]];

	if (_item.shared)
		[string_array addObject:_item.owner];
	else
		[string_array addObject:@""];

	[string_array addObject:[NSString stringWithFormat:@"%i", _item.committed]];
	[string_array addObject:[NSString stringWithFormat:@"%i", _item.completed]];

	NSMutableData *buffer = [[NSMutableData alloc] init];
	[buffer appendData:_list.id];
	[buffer appendData:[[string_array componentsJoinedByString:@":"] dataUsingEncoding:NSUTF8StringEncoding]];

	// the list item that was just edited will be updated when a response comes
	[network_connection send_message:7 contents:buffer];

	NSLog(@"debug: %@: %@: saving", _list.name, _item.name);
}

@end
