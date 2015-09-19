#import "MainTableViewController.h"
#import "NewListViewController.h"
#import "ShlistServer.h"
#import "ListTableViewController.h"

#import <AddressBook/AddressBook.h>

@interface MainTableViewController ()

@property (strong, nonatomic) ShlistServer *server;

@end

@implementation MainTableViewController

- (IBAction) unwindToList:(UIStoryboardSegue *)segue
{
	NewListViewController *source = [segue sourceViewController];
	SharedList *list = source.shared_list;

	if (list == nil) {
		return;
	}

	[self.shared_lists addObject:list];
	[self.tableView reloadData];

	// send new list message with new list name as payload
	NSData *payload = [list.name dataUsingEncoding:NSUTF8StringEncoding];
	[_server send_message:1 contents:payload];

	NSLog(@"unwindToList(): done");
}

- (void) viewDidLoad
{
	[super viewDidLoad];

	// display an Edit button in the navigation bar for this view controller
	self.navigationItem.leftBarButtonItem = self.editButtonItem;

	self.shared_lists = [[NSMutableArray alloc] init];
	self.indirect_lists = [[NSMutableArray alloc] init];

	// create one and only server instance, this gets passed around
	_server = [[ShlistServer alloc] init];
	_server->shlist_tvc = self;

	if ([_server prepare]) {
		NSLog(@"info: server connection prepared");
		// bulk update, doesn't take a payload
		[_server send_message:3 contents:nil];
	}
}

- (void) didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
	// "lists you're in" and "other lists"
	return 2;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section == 0)
		return [self.shared_lists count];
	else if (section == 1)
		return [self.indirect_lists count];
	return 0;
}

// major thing here is join list requests
- (void)tableView:(UITableView *)tableView
	didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	// section 0 is going to segue to the list items screen
	if ([indexPath section] == 0)
		return;

	// we're in section 1 now, a tap down here means we're doing a join list request
	SharedList *list = [self.indirect_lists objectAtIndex:[indexPath row]];
	NSLog(@"info: joining list '%@'", list.name);

	// the response for this does all of the heavy row moving work
	[_server send_message:4 contents:list.id];
}

- (void) finished_join_list_request:(SharedList *) shlist
{
	SharedList *needle = nil;
	for (SharedList *temp in _indirect_lists) {
		if ([temp.id isEqualToData:shlist.id]) {
			needle = temp;
			break;
		}
	}

	// if we received an update from a list id we don't know about, do nothing
	if (needle == nil)
		return;

	// this has to be done before row moving
	[_shared_lists addObject:needle];
	[_indirect_lists removeObject:needle];

	// get the original cells index path from the matched cell
	NSIndexPath *orig_index_path = [self.tableView indexPathForCell:needle.cell];

	// compute new position and start moving row as soon as possible
	// XXX: sorting
	NSIndexPath *new_index_path = [NSIndexPath indexPathForRow:[_shared_lists count] - 1 inSection:0];

	[self.tableView moveRowAtIndexPath:orig_index_path toIndexPath:new_index_path];

	// add > accessory indicator, fill in and show completion fraction
	needle.cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	UILabel *fraction = (UILabel *)[needle.cell viewWithTag:1];
	fraction.text = [self fraction:shlist.items_ready denominator:shlist.items_total];
	fraction.hidden = NO;
}

- (void) finished_leave_list_request:(SharedList *) shlist
{
	SharedList *list = nil;
	for (SharedList *temp in _shared_lists) {
		if ([temp.id isEqualToData:shlist.id]) {
			list = temp;
			break;
		}
	}

	if (list == nil)
		return;

	// insert the new object at the beginning to match gui moving below
	[_indirect_lists insertObject:list atIndex:0];
	[_shared_lists removeObject:list];

	// perform row move, the destination is the top of "other lists"
	NSIndexPath *old_path = [self.tableView indexPathForCell:list.cell];
	NSIndexPath *new_path = [NSIndexPath indexPathForRow:0 inSection:1];
	[self.tableView moveRowAtIndexPath:old_path toIndexPath:new_path];

	// remove > accessory and hide the completion fraction
	list.cell.accessoryType = UITableViewCellAccessoryNone;
	UILabel *fraction = (UILabel *)[list.cell viewWithTag:1];
	fraction.hidden = YES;

	// reset editing state back to the default
	[self.tableView setEditing:FALSE animated:TRUE];
}

- (UITableViewCell *) tableView:(UITableView *)tableView
	  cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell;
	cell = [tableView dequeueReusableCellWithIdentifier:@"SharedListPrototypeCell" forIndexPath:indexPath];

	int row = [indexPath row];
	SharedList *shared_list;

	if ([indexPath section] == 0) {
		shared_list = [self.shared_lists objectAtIndex:row];
		cell.textLabel.text = shared_list.name;
		cell.detailTextLabel.text = shared_list.members;

		// fill in the completion fraction
		UILabel *completion_fraction;
		completion_fraction = (UILabel *)[cell viewWithTag:1];

		// set color based on how complete the list is
		/*
		float frac = (float) shared_list.items_ready / shared_list.items_total;
		if (frac == 0.0f)
			completion_fraction.textColor = [UIColor blackColor];
		else if (frac < 0.5f)
			completion_fraction.textColor = [UIColor redColor];
		else if (frac < 0.75f)
			completion_fraction.textColor = [UIColor orangeColor];
		else
			completion_fraction.textColor = [UIColor greenColor];
		 */

		completion_fraction.text = [self fraction:shared_list.items_ready
					      denominator:shared_list.items_total];
	}
	else if ([indexPath section] == 1) {
		shared_list = [self.indirect_lists objectAtIndex:row];
		cell.textLabel.text = shared_list.name;
		cell.detailTextLabel.text = shared_list.members;
		shared_list.cell = cell;

		// Modify the look of the off the shelf cell
		// Note, a separate prototype cell isn't used here because we
		// can potentially swap cells a large number of times, and moving
		// is more efficient than recreating.

		// remove the > accessory and the completion fraction
		cell.accessoryType = UITableViewCellAccessoryNone;
		UILabel *fraction = (UILabel *)[cell viewWithTag:1];
		fraction.hidden = YES;
	}

	// hang on to a reference, this is needed in the networking gui callbacks
	shared_list.cell = cell;
	return cell;
}



// section header titles
- (NSString *)tableView:(UITableView *)tableView
	titleForHeaderInSection:(NSInteger)section
{
	if (section == 0)
		return @"Lists you're in";
	else if (section == 1)
		return @"Other lists";
	return @"";
}

// only section 0 lists can be edited
- (BOOL) tableView:(UITableView *)tableView
	canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	if ([indexPath section] == 0)
		return YES;
	return NO;
}

// what editing style should be applied to this indexpath
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
	   editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	// don't have to check the section here because canEditRowAtIndexPath
	// already said the section can't be edited
	return UITableViewCellEditingStyleDelete;
}

// this functions called when delete has been prompted and ok'd
- (void) tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
	forRowAtIndexPath:(NSIndexPath *)indexPath
{
	// we don't need to check for !section 0 because of canEditRowAtIndexPath
	SharedList *list = [self.shared_lists objectAtIndex:[indexPath row]];
	NSLog(@"info: leaving '%@' id '%@'", list.name, list.id);

	// send leave list message, response will do all heavy lifting
	[_server send_message:5 contents:list.id];
}

- (NSString *)tableView:(UITableView *)tableView
	titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return @"Leave";
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	// Get the new view controller using [segue destinationViewController].
	// Pass the selected object to the new view controller.

	if ([[segue identifier] isEqualToString:@"show list segue"]) {

		NSIndexPath *path = [self.tableView indexPathForSelectedRow];

		SharedList *list = [self.shared_lists objectAtIndex:[path row]];

		// only list detail table view controller has this method
		[segue.destinationViewController setMetadata:list];

		// has to be done before issuing network request
		_server->shlist_ldvc = segue.destinationViewController;

		// send update list items message
		[_server send_message:6 contents:list.id];
	}
	// DetailObject *detail = [self detailForIndexPath:path];ß

	// ListDetailTableViewController *list_detail_tvc = [segue destinationViewController];
	// list_detail_tvc.navigationItem.title = @"Test Title";

	NSLog(@"preparing for segue");
}

// prevent segues from occurring when non member lists are selected
// this isn't needed if we use 2 different prototype cells
- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
	NSIndexPath *path = [self.tableView indexPathForSelectedRow];

	if ([path section] == 0)
		return YES;
	return NO;
}

// taken from http://stackoverflow.com/questions/30859359/display-fraction-number-in-uilabel
-(NSString *)fraction:(int)numerator denominator:(int)denominator
{

	NSMutableString *result = [NSMutableString string];

	NSString *one = [NSString stringWithFormat:@"%i", numerator];
	for (int i = 0; i < one.length; i++) {
		[result appendString:[self superscript:[[one substringWithRange:NSMakeRange(i, 1)] intValue]]];
	}
	[result appendString:@"/"];

	NSString *two = [NSString stringWithFormat:@"%i", denominator];
	for (int i = 0; i < two.length; i++) {
		[result appendString:[self subscript:[[two substringWithRange:NSMakeRange(i, 1)] intValue]]];
	}
	return result;
}

-(NSString *)superscript:(int)num
{
	NSDictionary *superscripts = @{@0: @"\u2070", @1: @"\u00B9", @2: @"\u00B2", @3: @"\u00B3", @4: @"\u2074", @5: @"\u2075", @6: @"\u2076", @7: @"\u2077", @8: @"\u2078", @9: @"\u2079"};
	return superscripts[@(num)];
}

-(NSString *)subscript:(int)num
{
	NSDictionary *subscripts = @{@0: @"\u2080", @1: @"\u2081", @2: @"\u2082", @3: @"\u2083", @4: @"\u2084", @5: @"\u2085", @6: @"\u2086", @7: @"\u2087", @8: @"\u2088", @9: @"\u2089"};
	return subscripts[@(num)];
}

@end