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

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) viewDidLoad
{
	[super viewDidLoad];

	NSNotificationCenter *default_center = [NSNotificationCenter defaultCenter];
	NSString *notification_name;

	// Listen for push notifications
	[default_center addObserver:self selector:@selector(push_friend_added_list:)
			       name:@"PushNotification_friend_added_list" object:nil];

	/*
	[default_center addObserver:self selector:@selector(push_updated_list:)
			       name:@"PushNotification_updated_list" object:nil];
	 */

	const SEL selectors[] = {
		@selector(lists_get_finished:),
		@selector(lists_get_other_finished:),
		@selector(finished_new_list_request:),
		@selector(finished_join_list_request:),
		@selector(finished_leave_list_request:)
	};
	NSUInteger count = 0;

	// This object handles responses for these types of messages
	for (id str in @[@"lists_get", @"lists_get_other", @"list_add", @"list_join", @"list_leave"]) {
		notification_name = [NSString stringWithFormat:@"NetworkResponseFor_%@", str];
		[default_center addObserver:self selector:selectors[count] name:notification_name object:nil];
		count++;
	}

	// display an Edit button in the navigation bar for this view controller
	self.navigationItem.leftBarButtonItem = self.editButtonItem;

	network_connection = [Network shared_network_connection];

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

// Handle 'friend_added_list' message from notification service
- (void) push_friend_added_list:(NSNotification *) notification
{
	NSDictionary *json_list = notification.userInfo;

	// Server will only send back partial list information because this will
	// always be put in the other lists section
	SharedList *tmp = [self deserialize_light_list:json_list];

	NSMutableArray *other_lists = [_lists objectAtIndex:1];
	[other_lists addObject:tmp];

	NSLog(@"notify: new other list '%@', num '%@'", tmp.name, tmp.num);

	NSIndexPath *new_path = [NSIndexPath indexPathForRow:[other_lists count] - 1 inSection:1];
	[self.tableView insertRowsAtIndexPaths:@[new_path] withRowAnimation:UITableViewRowAnimationAutomatic];

	[self update_section_headers];
}

- (bool) load_phone_number
{
	if ([[NSFileManager defaultManager] fileExistsAtPath:phone_num_file]) {
		// file exists, read what it has
		// XXX: validate length of file too
		NSError *error = nil;
		phone_number = [NSString stringWithContentsOfFile:phone_num_file encoding:NSASCIIStringEncoding error:&error];
		return true;
	}

	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Important"
		message:@"We need this phone's number to find your mutual friends."
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

- (void) lists_get_finished:(NSNotification *)notification
{
	NSDictionary *response = notification.userInfo;

	NSArray *json_lists = [response objectForKey:@"lists"];
	NSLog(@"lists_get: got %lu lists from server", (unsigned long)[json_lists count]);

	NSMutableArray *lists = [_lists objectAtIndex:0];
	[lists removeAllObjects];

	for (NSDictionary *list in json_lists) {
		SharedList *tmp = [self deserialize_full_list:list];
		[lists addObject:tmp];

		NSLog(@"adding list '%@', num '%@'", tmp.name, tmp.num);
	}

	NSIndexSet *section = [NSIndexSet indexSetWithIndex:0];
	[self.tableView reloadSections:section withRowAnimation:UITableViewRowAnimationNone];
}

- (void) lists_get_other_finished:(NSNotification *)notification;
{
	NSDictionary *response = notification.userInfo;
	NSArray *other_json_lists = [response objectForKey:@"other_lists"];
	NSLog(@"lists_get_other: got %lu other lists from server", (unsigned long)[other_json_lists count]);

	NSMutableArray *other_lists = [_lists objectAtIndex:1];
	[other_lists removeAllObjects];

	for (NSDictionary *list in other_json_lists) {
		SharedList *tmp = [self deserialize_light_list:list];
		[other_lists addObject:tmp];

		NSLog(@"adding other list '%@', num '%@'", tmp.name, tmp.num);
	}

	NSIndexSet *section = [NSIndexSet indexSetWithIndex:1];
	[self.tableView reloadSections:section withRowAnimation:UITableViewRowAnimationNone];
}

- (void) finished_new_list_request:(NSNotification *) notification
{
	NSDictionary *response = notification.userInfo;
	NSDictionary *list = [response objectForKey:@"list"];

	SharedList *shlist = [self deserialize_full_list:list];

	NSMutableArray *lists = [_lists objectAtIndex:0];
	[lists addObject:shlist];

	// response looks good, insert the new list
	NSUInteger new_row_pos = [lists count] - 1;
	NSIndexPath *index_path = [NSIndexPath indexPathForRow:new_row_pos inSection:0];
	[self.tableView insertRowsAtIndexPaths:@[index_path] withRowAnimation:UITableViewRowAnimationFade];

	[self update_section_headers];
}

- (SharedList *) deserialize_full_list:(NSDictionary *)json_list
{
	SharedList *shlist = [[SharedList alloc] init];
	shlist.num = [json_list objectForKey:@"num"];

	// We need some careful decoding to get a usable Unicode string
	NSData *name_data = [json_list[@"name"] dataUsingEncoding:NSISOLatin1StringEncoding];
	shlist.name = [[NSString alloc] initWithData:name_data encoding:NSUTF8StringEncoding];

	NSNumber *date = json_list[@"date"];
	if ([date intValue] != 0) {
		shlist.date = [NSDate dateWithTimeIntervalSince1970:[date floatValue]];
	}
	else {
		shlist.date = nil;
	}

	shlist.members_phone_nums = [json_list objectForKey:@"members"];
	shlist.items_ready = [json_list objectForKey:@"items_complete"];
	shlist.items_total = [json_list objectForKey:@"items_total"];

	return shlist;
}

- (SharedList *) deserialize_light_list:(NSDictionary *)json_list
{
	SharedList *shlist = [[SharedList alloc] init];
	shlist.num = [json_list objectForKey:@"num"];

	// We need some careful decoding to get a usable Unicode string
	NSData *name_data = [json_list[@"name"] dataUsingEncoding:NSISOLatin1StringEncoding];
	shlist.name = [[NSString alloc] initWithData:name_data encoding:NSUTF8StringEncoding];

	shlist.members_phone_nums = [json_list objectForKey:@"members"];

	return shlist;
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
	[request setObject:list.num forKey:@"list_num"];
	[network_connection send_message:list_join contents:request];
}

- (void) finished_join_list_request:(NSNotification *) notification
{
	NSDictionary *response = notification.userInfo;
	NSDictionary *json_list = response[@"list"];
	NSLog(@"network: joined list %@", json_list[@"num"]);

	NSMutableArray *lists = [_lists objectAtIndex:0];
	NSMutableArray *other_lists = [_lists objectAtIndex:1];

	// Find the list number we received a response for
	SharedList *needle = nil;
	for (SharedList *temp in other_lists) {
		if (temp.num == json_list[@"num"]) {
			needle = temp;
			break;
		}
	}

	// If we received an update from a list id we don't know about, do nothing
	if (needle == nil)
		return;

	// The server sent us a full list object, make sure to copy cell reference
	SharedList *joined_list = [self deserialize_full_list:json_list];
	joined_list.cell = needle.cell;

	// Add completely new object to lists section and remove the old list
	[lists addObject:joined_list];
	[other_lists removeObject:needle];

	// Get the cell index path from the matched list cell
	NSIndexPath *orig_index_path = [self.tableView indexPathForCell:joined_list.cell];

	// Compute new position and start moving row as soon as possible
	// XXX: sorting
	NSUInteger new_row_pos = [lists count] - 1;
	NSIndexPath *new_index_path = [NSIndexPath indexPathForRow:new_row_pos inSection:0];
	[self.tableView moveRowAtIndexPath:orig_index_path toIndexPath:new_index_path];

	[self update_section_headers];

	// Update members in list row
	[self process_members_array:joined_list.members_phone_nums cell:joined_list.cell];

	// Add > accessory indicator
	joined_list.cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

	// Find fraction UILAbel, populate it and then show it
	UILabel *fraction = (UILabel *)[joined_list.cell viewWithTag:4];
	fraction.text = [self fraction:joined_list.items_ready denominator:joined_list.items_total];
	fraction.hidden = NO;

	// Show date label if date has been set to something
	if (joined_list.date != nil) {
		UILabel *deadline_label = (UILabel *)[joined_list.cell viewWithTag:3];
		deadline_label.hidden = NO;
	}
}


// section header titles
- (NSString *)tableView:(UITableView *)tableView
titleForHeaderInSection:(NSInteger)section
{
	if (section > 1)
		// should not happen
		return @"";

	unsigned long total = [[_lists objectAtIndex:section] count];
	if (section == 0)
		return [NSString stringWithFormat:@"Your Lists (%lu)", total];
	else if (section == 1)
		return [NSString stringWithFormat:@"Other Lists (%lu)", total];
	return @"";
}

- (void) update_section_headers
{
	NSMutableArray *lists = [_lists objectAtIndex:0];
	NSMutableArray *other_lists = [_lists objectAtIndex:1];

	UITableViewHeaderFooterView *sectionZeroHeader = [self.tableView headerViewForSection:0];
	UITableViewHeaderFooterView *sectionOneHeader = [self.tableView headerViewForSection:1];
	NSString *sectionZeroLabel = [NSString stringWithFormat:@"Your Lists (%lu)", (unsigned long)[lists count]];
	NSString *sectionOneLabel = [NSString stringWithFormat:@"Other Lists (%lu)", (unsigned long)[other_lists count]];

	[sectionZeroHeader.textLabel setText:sectionZeroLabel];
	[sectionZeroHeader setNeedsLayout];
	[sectionOneHeader.textLabel setText:sectionOneLabel];
	[sectionOneHeader setNeedsLayout];
}

- (void) finished_leave_list_request:(NSNotification *) notification
{
	NSDictionary *response = notification.userInfo;
	NSNumber *list_num = response[@"list_num"];
	NSLog(@"network: left list %@", list_num);

	NSMutableArray *lists = [_lists objectAtIndex:0];
	NSMutableArray *other_lists = [_lists objectAtIndex:1];

	SharedList *list = nil;
	for (SharedList *temp in lists) {
		if (temp.num == response[@"list_num"]) {
			list = temp;
			break;
		}
	}
	if (list == nil)
		return;

	NSNumber *list_empty = response[@"list_empty"];
	if ([list_empty intValue] == 1) {
		// List was empty, delete instead of moving it
		[lists removeObject:list];

		NSIndexPath *old_path = [self.tableView indexPathForCell:list.cell];
		[self.tableView deleteRowsAtIndexPaths:@[old_path] withRowAnimation:UITableViewRowAnimationAutomatic];

		[self update_section_headers];
		return;
	}

	// Insert the new object at the beginning to match gui moving below
	[other_lists insertObject:list atIndex:0];
	[lists removeObject:list];

	// Perform row move, the destination is the top of "other lists"
	NSIndexPath *old_path = [self.tableView indexPathForCell:list.cell];
	NSIndexPath *new_path = [NSIndexPath indexPathForRow:0 inSection:1];
	[self.tableView moveRowAtIndexPath:old_path toIndexPath:new_path];

	// Make sure section headers are accurate
	[self update_section_headers];

	// Remove yourself from the members array
	NSMutableArray *members = [list.members_phone_nums mutableCopy];
	NSUInteger index = [members indexOfObject:@"4037082094"];
	if (index != NSNotFound) {
		[members removeObjectAtIndex:index];
	}
	[self process_members_array:members cell:list.cell];

	// Remove > accessory
	list.cell.accessoryType = UITableViewCellAccessoryNone;

	// Hide completion fraction
	UILabel *fraction = (UILabel *)[list.cell viewWithTag:4];
	fraction.hidden = YES;

	// Hide date
	UILabel *deadline_label = (UILabel *)[list.cell viewWithTag:3];
	deadline_label.hidden = YES;

	// XXX: update members array to disclude yourself (maybe send it back in response?)
	// XXX: Maybe clear out list data that's no longer needed
	// XXX: give some visual feedback here what's happening
}


- (UITableViewCell *) tableView:(UITableView *)tableView
	  cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell;
	cell = [tableView dequeueReusableCellWithIdentifier:@"SharedListPrototypeCell" forIndexPath:indexPath];

	NSInteger section = [indexPath section];
	NSInteger row = [indexPath row];
	SharedList *shared_list = [[_lists objectAtIndex:section] objectAtIndex:row];

	UILabel *deadline_label = (UILabel *)[cell viewWithTag:3];
	UILabel *fraction_label = (UILabel *)[cell viewWithTag:4];

	if (section == 0) {
		// your lists section

		if (shared_list.date == nil) {
			deadline_label.hidden = YES;
		} else {
			// XXX: calculate how long until deadline
			// NSDate *date = shared_list.date;
			deadline_label.text = @"date";
		}

		float frac = [shared_list.items_ready floatValue]  / [shared_list.items_total floatValue];
		if (frac > 0.80f)
			fraction_label.textColor = [UIColor greenColor];
		fraction_label.hidden = NO;
		fraction_label.text = [self fraction:shared_list.items_ready
					      denominator:shared_list.items_total];

		// Add ">" accessory to indicate you can "enter" this list
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

	}
	else if (section == 1) {
		// "other lists" section

		// no deadline
		deadline_label.text = @"";

		// remove the > accessory and the completion fraction
		cell.accessoryType = UITableViewCellAccessoryNone;
		fraction_label.hidden = YES;
	}

	UILabel *main_label = (UILabel *)[cell viewWithTag:1];
	main_label.text = shared_list.name;

	[self process_members_array:shared_list.members_phone_nums cell:cell];

	// hang on to a reference, this is needed in the networking gui callbacks
	shared_list.cell = cell;
	return cell;
}

- (void) process_members_array:(NSArray *)phnum_array cell:(UITableViewCell *)cell
{
	UILabel *members_label = (UILabel *)[cell viewWithTag:2];

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
		members_label.text = output;
		return;
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

	members_label.text = members_str;
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

// This functions called when delete has been prompted and ok'd
- (void) tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
	forRowAtIndexPath:(NSIndexPath *)indexPath
{
	// we don't need to check for !section 0 because of canEditRowAtIndexPath
	SharedList *list = [[_lists objectAtIndex:0] objectAtIndex:[indexPath row]];
	NSLog(@"info: leaving '%@' list num '%@'", list.name, list.num);

	// Send leave list message, response will do all heavy lifting
	NSMutableDictionary *request = [[NSMutableDictionary alloc] init];
	[request setObject:list.num forKey:@"list_num"];
	[network_connection send_message:list_leave contents:request];

	// Reset editing state back to the default
	[self.tableView setEditing:FALSE animated:TRUE];
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
		// network_connection->shlist_ldvc = segue.destinationViewController;
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
