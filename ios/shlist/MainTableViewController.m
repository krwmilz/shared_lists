#import "AddressBook.h"
#import "MainTableViewController.h"
#import "NewListTableViewController.h"
#import "Network.h"
#import "ListTableViewController.h"
#import "MsgTypes.h"

#import <AddressBook/AddressBook.h>
#include "libkern/OSAtomic.h"

@interface MainTableViewController () {
	NSString *phone_number;
	Network *network_connection;
	NSString *phone_num_file;
}

// main data structure, [0] holds lists you're in, [1] is other lists
@property NSMutableArray *lists;

@property NSMutableDictionary *phnum_to_name_map;
@property (strong, retain) AddressBook *address_book;

@end

@implementation MainTableViewController

- (void) viewDidLoad
{
	[super viewDidLoad];

	// display an Edit button in the navigation bar for this view controller
	self.navigationItem.leftBarButtonItem = self.editButtonItem;

	// there's a race here when assigning self
	network_connection = [Network shared_network_connection];
	network_connection->shlist_tvc = self;

	_lists = [[NSMutableArray alloc] init];
	[_lists addObject:[[NSMutableArray alloc] init]];
	[_lists addObject:[[NSMutableArray alloc] init]];

	// store the path to the phone number file
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	phone_num_file = [documentsDirectory stringByAppendingPathComponent:@"phone_num"];

	phone_number = nil;
	if ([self load_phone_number]) {
		// phone number loaded, try loading device id
		if ([network_connection load_device_id:phone_number]) {

			// Send lists_get request, no arguments required here
			NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
			[network_connection send_message:lists_get contents:dict];

			// Send lists_get_other request, no arguments here either
			[dict removeAllObjects];
			[network_connection send_message:lists_get_other contents:dict];
		}
		// else, device id request sent
	}
	// else, phone number entry is on screen

	_phnum_to_name_map = [[NSMutableDictionary alloc] init];

	// get instance and wait for privacy window to clear
	_address_book = [AddressBook shared_address_book];
	_address_book.main_tvc = self;
}

- (bool) load_phone_number
{
	if ([[NSFileManager defaultManager] fileExistsAtPath:phone_num_file]) {
		// file exists, read what it has
		// XXX: validate length of file too
		phone_number = [NSString stringWithContentsOfFile:phone_num_file];
		return true;
	}

	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Important"
		message:@"Your phone number is needed for us to calculate your mutual contacts. Expect severe functionality loss."
		delegate:self cancelButtonTitle:@"Nope" otherButtonTitles:@"Ok", nil];

	alert.alertViewStyle = UIAlertViewStylePlainTextInput;

	// it's a phone number, so only show the number pad
	UITextField * alertTextField = [alert textFieldAtIndex:0];
	alertTextField.keyboardType = UIKeyboardTypeNumberPad;
	alertTextField.placeholder = @"Enter your phone number";

	[alert show];
	return false;
}

- (void)alertView:(UIAlertView *)alertView
clickedButtonAtIndex:(NSInteger)buttonIndex
{
	NSString *entered_phone_num = [[alertView textFieldAtIndex:0] text];
	NSLog(@"warn: main: writing phone num '%@' to disk", entered_phone_num);
	NSError *error;
	[entered_phone_num writeToFile:phone_num_file atomically:YES encoding:NSASCIIStringEncoding error:&error];

	if (error)
		NSLog(@"warn: main: writing phone number file: %@", error);

	if ([entered_phone_num compare:@""] == NSOrderedSame) {
		NSLog(@"warn: load phone number: entered emtpy phone number");
	}

	phone_number = entered_phone_num;

	if ([network_connection load_device_id:phone_number]) {
		NSLog(@"info: network: connection ready");
		// bulk update, doesn't take a payload
		[network_connection send_message:3 contents:nil];
	}
	// else, device id request sent
}

- (void) update_address_book
{
	[_phnum_to_name_map removeAllObjects];
	// XXX: it'd be nice to resize phnum_to_name_map to num_contacts here

	for (Contact *contact in _address_book.contacts) {
		NSString *disp_name;
		// show first name and last initial if possible, otherwise
		// just show the first name or the last name or the phone number
		if (contact.first_name && contact.last_name)
			disp_name = [NSString stringWithFormat:@"%@ %@",
				     contact.first_name, [contact.last_name substringToIndex:1]];
		else if (contact.first_name)
			disp_name = contact.first_name;
		else if (contact.last_name)
			disp_name = contact.last_name;
		else if ([contact.phone_numbers count])
			disp_name = [contact.phone_numbers objectAtIndex:0];
		else
			disp_name = @"No Name";

		// map the persons known phone number to their massaged name
		for (NSString *tmp_phone_number in contact.phone_numbers)
			[_phnum_to_name_map setObject:disp_name forKey:tmp_phone_number];
	}
}

- (void) didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
	// "lists you're in" and "other lists"
	return 2;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section > 1)
		// should never happen
		return 0;

	return [[_lists objectAtIndex:section] count];
}

// new list dialogue has been saved
- (IBAction) unwindToList:(UIStoryboardSegue *)segue
{
}

- (void) lists_get_finished:(NSArray *)json_lists;
{
	NSMutableArray *lists = [_lists objectAtIndex:0];
	[lists removeAllObjects];

	for (NSDictionary *list in json_lists) {
		SharedList *tmp = [[SharedList alloc] init];
		tmp.num = list[@"num"];

		NSData *name_data = [list[@"name"] dataUsingEncoding:NSISOLatin1StringEncoding];
		tmp.name = [[NSString alloc] initWithData:name_data encoding:NSUTF8StringEncoding];

		NSNumber *date = list[@"date"];
		tmp.date = [NSDate dateWithTimeIntervalSince1970:[date floatValue]];
		tmp.members_phone_nums = list[@"members"];
		tmp.items_ready = list[@"items_complete"];
		tmp.items_total = list[@"items_total"];
		[lists addObject:tmp];

		NSLog(@"adding list '%@', num '%@'", tmp.name, tmp.num);
	}

	[self.tableView reloadData];
}

- (void) lists_get_other_finished:(NSArray *)other_json_lists;
{
	NSMutableArray *other_lists = [_lists objectAtIndex:1];
	[other_lists removeAllObjects];

	for (NSDictionary *list in other_json_lists) {
		SharedList *tmp = [[SharedList alloc] init];
		tmp.num = list[@"num"];

		NSData *name_data = [list[@"name"] dataUsingEncoding:NSISOLatin1StringEncoding];
		tmp.name = [[NSString alloc] initWithData:name_data encoding:NSUTF8StringEncoding];

		tmp.members_phone_nums = list[@"members"];
		[other_lists addObject:tmp];

		NSLog(@"adding other list '%@', num '%@'", tmp.name, tmp.num);
	}

	[self.tableView reloadData];
}

- (void) finished_new_list_request:(SharedList *) shlist
{
	[[_lists objectAtIndex:0] addObject:shlist];
	// [self.shared_lists addObject:shlist];

	// response looks good, insert the new list
	int section_0_rows = [[_lists objectAtIndex:0] count];
	NSIndexPath *index_path = [NSIndexPath indexPathForRow:section_0_rows - 1 inSection:0];
	[self.tableView insertRowsAtIndexPaths:@[index_path] withRowAnimation:UITableViewRowAnimationFade];
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
	SharedList *list = [[_lists objectAtIndex:1] objectAtIndex:[indexPath row]];
	NSLog(@"info: joining list '%@'", list.name);

	// the response for this does all of the heavy row moving work
	NSMutableDictionary *request = [[NSMutableDictionary alloc] init];
	[request setObject:list.num forKey:@"num"];
	[network_connection send_message:list_join contents:request];
}

- (void) finished_join_list_request:(SharedList *) shlist
{
	SharedList *needle = nil;
	for (SharedList *temp in [_lists objectAtIndex:1]) {
		if (temp.num == shlist.num) {
			needle = temp;
			break;
		}
	}

	// if we received an update from a list id we don't know about, do nothing
	if (needle == nil)
		return;

	// this has to be done before row moving
	[[_lists objectAtIndex:0] addObject:needle];
	[[_lists objectAtIndex:1] removeObject:needle];

	// [_shared_lists addObject:needle];
	// [_indirect_lists removeObject:needle];

	// get the original cells index path from the matched cell
	NSIndexPath *orig_index_path = [self.tableView indexPathForCell:needle.cell];

	// compute new position and start moving row as soon as possible
	// XXX: sorting
	int section_0_rows = [[_lists objectAtIndex:0] count];
	NSIndexPath *new_index_path = [NSIndexPath indexPathForRow:section_0_rows - 1 inSection:0];

	[self.tableView moveRowAtIndexPath:orig_index_path toIndexPath:new_index_path];

	// add > accessory indicator, fill in and show completion fraction
	needle.cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	UILabel *fraction = (UILabel *)[needle.cell viewWithTag:4];
	fraction.text = [self fraction:shlist.items_ready denominator:shlist.items_total];
	fraction.hidden = NO;
}

- (void) finished_leave_list_request:(SharedList *) shlist
{
	SharedList *list = nil;
	for (SharedList *temp in [_lists objectAtIndex:0]) {
		if (temp.num == shlist.num) {
			list = temp;
			break;
		}
	}

	if (list == nil)
		return;

	// insert the new object at the beginning to match gui moving below
	[[_lists objectAtIndex:1] insertObject:list atIndex:0];
	[[_lists objectAtIndex:0] removeObject:list];

	// perform row move, the destination is the top of "other lists"
	NSIndexPath *old_path = [self.tableView indexPathForCell:list.cell];
	NSIndexPath *new_path = [NSIndexPath indexPathForRow:0 inSection:1];
	[self.tableView moveRowAtIndexPath:old_path toIndexPath:new_path];

	// remove > accessory and hide the completion fraction
	list.cell.accessoryType = UITableViewCellAccessoryNone;
	UILabel *fraction = (UILabel *)[list.cell viewWithTag:4];
	fraction.hidden = YES;

	// reset editing state back to the default
	[self.tableView setEditing:FALSE animated:TRUE];
}


- (UITableViewCell *) tableView:(UITableView *)tableView
	  cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell;
	cell = [tableView dequeueReusableCellWithIdentifier:@"SharedListPrototypeCell" forIndexPath:indexPath];

	int section = [indexPath section];
	int row = [indexPath row];
	SharedList *shared_list = [[_lists objectAtIndex:section] objectAtIndex:row];

	UILabel *deadline_label = (UILabel *)[cell viewWithTag:3];
	UILabel *fraction_label = (UILabel *)[cell viewWithTag:4];

	if ([indexPath section] == 0) {
		// "lists you're in" section

		// XXX: needs to be stored on/sent from the server
		deadline_label.text = @"in 3 days";

		// float frac = shared_list.items_ready  / shared_list.items_total;
		float frac = 0.0f;
		if (frac > 0.80f)
			fraction_label.textColor = [UIColor greenColor];

		fraction_label.hidden = NO;
		fraction_label.text = [self fraction:shared_list.items_ready
					      denominator:shared_list.items_total];

		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

	}
	else if ([indexPath section] == 1) {
		// "other lists" section

		// no deadline
		deadline_label.text = @"";

		// remove the > accessory and the completion fraction
		cell.accessoryType = UITableViewCellAccessoryNone;
		fraction_label.hidden = YES;
	}

	UILabel *main_label = (UILabel *)[cell viewWithTag:1];
	UILabel *members_label = (UILabel *)[cell viewWithTag:2];

	// show name and members
	main_label.text = shared_list.name;
	members_label.text = [self process_members_array:shared_list.members_phone_nums];

	// hang on to a reference, this is needed in the networking gui callbacks
	shared_list.cell = cell;
	return cell;
}

- (NSString *) process_members_array:(NSArray *)phnum_array
{
	if (!OSAtomicAnd32(0xffff, &_address_book->ready)) {
		// not ready
		NSMutableString *output = [[NSMutableString alloc] init];
		for (id tmp_phone_number in phnum_array) {
			if ([tmp_phone_number compare:phone_number] == NSOrderedSame) {
				[output appendString:@"You"];
				continue;
			}

			[output appendFormat:@", %@", tmp_phone_number];
		}
		return output;
	}

	// we can do phone number to name mappings
	NSMutableArray *members = [[NSMutableArray alloc] init];
	int others = 0;

	// anything past the second field are list members
	for (id tmp_phone_number in phnum_array) {

		// try to find the list member in our address book
		NSString *name = _phnum_to_name_map[tmp_phone_number];

		if (name)
			[members addObject:name];
		else if (phone_number && ([phone_number compare:tmp_phone_number] == NSOrderedSame))
			[members addObject:@"You"];
		else
			// didn't find it, you don't know this person
			others++;
	}

	NSMutableString *members_str =
	[[members componentsJoinedByString:@", "] mutableCopy];

	if (others) {
		char *plural;
		if (others == 1)
			plural = "other";
		else
			plural = "others";

		NSString *buf = [NSString stringWithFormat:@" + %i %s",
				 others, plural];
		[members_str appendString:buf];
	}
	return members_str;
}

// section header titles
- (NSString *)tableView:(UITableView *)tableView
	titleForHeaderInSection:(NSInteger)section
{
	if (section > 1)
		// should not happen
		return @"";

	NSUInteger total = [[_lists objectAtIndex:section] count];
	if (section == 0)
		return [NSString stringWithFormat:@"Lists you're in (%lu)", (unsigned long)total];
	else if (section == 1)
		return [NSString stringWithFormat:@"Other lists (%lu)", (unsigned long)total];
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
	SharedList *list = [[_lists objectAtIndex:0] objectAtIndex:[indexPath row]];
	NSLog(@"info: leaving '%@' list num '%@'", list.name, list.num);

	// send leave list message, response will do all heavy lifting
	NSMutableDictionary *request = [[NSMutableDictionary alloc] init];
	[request setObject:list.num forKey:@"num"];
	[network_connection send_message:list_leave contents:request];
}

// customize deletion label text
- (NSString *)tableView:(UITableView *)tableView
	titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return @"Leave";
}

// tell incoming controllers about their environment
- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if ([[segue identifier] isEqualToString:@"show list segue"]) {
		// a shared list was selected, transfer into detailed view

		NSIndexPath *path = [self.tableView indexPathForSelectedRow];
		SharedList *list = [[_lists objectAtIndex:0] objectAtIndex:[path row]];

		// make sure incoming view controller knows about itself
		[segue.destinationViewController setMetadata:list];

		// send update list items message
		network_connection->shlist_ldvc = segue.destinationViewController;
		//[network_connection send_message:6 contents:list.id];
	}

	// DetailObject *detail = [self detailForIndexPath:path];
	NSLog(@"info: main: preparing for segue");
}

// prevent segues from occurring when non member lists are selected
- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
	NSIndexPath *path = [self.tableView indexPathForSelectedRow];

	if ([path section] == 0)
		return YES;
	return NO;
}

// taken from http://stackoverflow.com/questions/30859359/display-fraction-number-in-uilabel
-(NSString *)fraction:(NSNumber *)numerator denominator:(NSNumber *)denominator
{

	NSMutableString *result = [NSMutableString string];

	NSString *one = [numerator stringValue];
	for (int i = 0; i < one.length; i++) {
		[result appendString:[self superscript:[[one substringWithRange:NSMakeRange(i, 1)] intValue]]];
	}

	[result appendString:@"/"];

	NSString *two = [denominator stringValue];
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
