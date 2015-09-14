#import "SharedListsTableViewController.h"
#import "SharedList.h"
#import "NewListViewController.h"
#import "ShlistServer.h"
#import "ListDetailTableViewController.h"

#import <AddressBook/AddressBook.h>

@interface SharedListsTableViewController ()

@property (strong, nonatomic) ShlistServer *server;

@end

@implementation SharedListsTableViewController

- (void) load_initial_data
{
	// create one and only server instance, this gets passed around
	_server = [[ShlistServer alloc] init];
	_server->shlist_tvc = self;

	if ([_server prepare]) {
		NSLog(@"info: server connection prepared");
		// bulk update, doesn't take a payload
		[_server send_message:3 contents:nil];
	}
}

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
	NSData *payload = [list.list_name dataUsingEncoding:NSUTF8StringEncoding];
	[_server send_message:1 contents:payload];

	NSLog(@"unwindToList(): done");
}

- (void) viewDidLoad
{
	[super viewDidLoad];

	// Uncomment the following line to preserve selection between
	// presentations.
	// self.clearsSelectionOnViewWillAppear = NO;

	// display an Edit button in the navigation bar for this view controller
	self.navigationItem.leftBarButtonItem = self.editButtonItem;

	self.shared_lists = [[NSMutableArray alloc] init];
	self.indirect_lists = [[NSMutableArray alloc] init];

	[self load_initial_data];
}

- (void) didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSLog(@"did cell selection");
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (UITableViewCell *) tableView:(UITableView *)tableView
	  cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell;

	int row = [indexPath row];

	if ([indexPath section] == 0) {
		cell = [tableView dequeueReusableCellWithIdentifier:@"SharedListPrototypeCell" forIndexPath:indexPath];

		SharedList *shared_list = [self.shared_lists objectAtIndex:row];
		cell.textLabel.text = shared_list.list_name;
		cell.detailTextLabel.text = shared_list.list_members;

		// fill in the completion fraction
		UILabel *completion_fraction;
		completion_fraction = (UILabel *)[cell viewWithTag:1];

		// set color based on how complete the list is
		float frac = (float) shared_list.items_ready / shared_list.items_total;
		if (frac == 0.0f)
			completion_fraction.textColor = [UIColor blackColor];
		else if (frac < 0.5f)
			completion_fraction.textColor = [UIColor redColor];
		else if (frac < 0.75f)
			completion_fraction.textColor = [UIColor orangeColor];
		else
			completion_fraction.textColor = [UIColor greenColor];

		completion_fraction.text = [self fraction:shared_list.items_ready
					      denominator:shared_list.items_total];
	}
	else if ([indexPath section] == 1) {
		cell = [tableView dequeueReusableCellWithIdentifier:@"IndirectListPrototypeCell" forIndexPath:indexPath];

		SharedList *shared_list = [self.indirect_lists objectAtIndex:row];
		cell.textLabel.text = shared_list.list_name;
		cell.detailTextLabel.text = shared_list.list_members;
	}

	return cell;
}


// taken from http://stackoverflow.com/questions/30859359/display-fraction-number-in-uilabel
-(NSString *)fraction:(int)numerator denominator:(int)denominator {

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

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == 0) {
		if ([self.shared_lists count] == 0)
			return @"you're not in any lists";
		else if ([self.shared_lists count] == 1)
			return @"shared list";
		return @"shared lists";
	}
	else if (section == 1) {
		if ([self.indirect_lists count] == 0)
			return @"no other shared lists";
		else if ([self.indirect_lists count] == 1)
			return @"other shared list";
		return @"other shared lists";
	}
	return @"";
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
	   editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if ([indexPath section] == 0)
		return UITableViewCellEditingStyleDelete;

	return UITableViewCellEditingStyleInsert;
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	// all lists are editable
	return YES;
}

- (void) tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
	forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		// Delete the row from the data source
		// [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];

		//NSIndexPath *new_index_path = [NSIndexPath indexPathForRow:0 inSection:1];
		//[tableView moveRowAtIndexPath:indexPath toIndexPath:new_index_path];

		NSIndexPath *path = [self.tableView indexPathForSelectedRow];
		SharedList *selected_list = [self.shared_lists objectAtIndex:[path row]];

		NSLog(@"info: leaving list '%@'", selected_list.list_name);

		// send leave list message
		[_server send_message:5 contents:selected_list.list_id];

		// [self.shared_lists removeObjectAtIndex:[indexPath row]];
	} else if (editingStyle == UITableViewCellEditingStyleInsert) {
		// Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view

		NSIndexPath *path = [self.tableView indexPathForSelectedRow];
		SharedList *selected_list = [self.indirect_lists objectAtIndex:[path row]];

		NSLog(@"info: joining list '%@'", selected_list.list_name);

		// send join list message
		[_server send_message:4 contents:selected_list.list_id];
	}
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
		[_server send_message:6 contents:list.list_id];
	}
	// DetailObject *detail = [self detailForIndexPath:path];ß

	// ListDetailTableViewController *list_detail_tvc = [segue destinationViewController];
	// list_detail_tvc.navigationItem.title = @"Test Title";

	NSLog(@"preparing for segue");
}

@end
