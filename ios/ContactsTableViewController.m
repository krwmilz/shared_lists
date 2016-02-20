#import "ContactsTableViewController.h"
#import "AddressBook.h"
#import "Network.h"

@interface ContactsTableViewController () {
	Network *network_connection;
}

@property (strong, retain) AddressBook *address_book;
@property (strong, retain) NSMutableArray *cells;
@property (strong, retain) NSArray *section_to_letter;

@end

@implementation ContactsTableViewController

- (void)viewDidLoad
{
	[super viewDidLoad];

	// Uncomment the following line to preserve selection between presentations.
	// self.clearsSelectionOnViewWillAppear = NO;

	// get a copy of the address book singleton
	_address_book = [AddressBook shared_address_book];

	// we'll always have 26 or less letters in this dictionary
	NSMutableDictionary *letter_to_contact_map = [NSMutableDictionary dictionaryWithCapacity:26];

	for (Contact *contact in _address_book.contacts) {
		NSString *letter;
		if (contact.last_name)
			letter = [[contact.last_name uppercaseString] substringToIndex:1];
		else if (contact.first_name)
			letter = [[contact.first_name uppercaseString] substringToIndex:1];
		else
			// not sure if this can happen or not
			continue;

		if (letter_to_contact_map[letter] != nil)
			[[letter_to_contact_map objectForKey:letter] addObject:contact];
		else {
			NSMutableArray *tmp = [NSMutableArray arrayWithObject:contact];
			[letter_to_contact_map setObject:tmp forKey:letter];
		}
	}

	// get an array of first letters sorted lexicographically
	_section_to_letter = [[letter_to_contact_map allKeys]
		sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
	_cells = [[NSMutableArray alloc] init];

	for (NSString *letter in _section_to_letter)
		[_cells addObject:[letter_to_contact_map objectForKey:letter]];

	network_connection = [Network shared_network_connection];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [_cells count];
}

- (NSInteger)tableView:(UITableView *)tableView
	numberOfRowsInSection:(NSInteger)section
{
	return [[_cells objectAtIndex:section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
	 cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSInteger section = [indexPath section];
	NSInteger row = [indexPath row];
	Contact *contact = [[_cells objectAtIndex:section] objectAtIndex:row];

	UITableViewCell *cell;
	if (contact.first_name && contact.last_name)
		cell = [tableView dequeueReusableCellWithIdentifier:@"contact_cell_two_name" forIndexPath:indexPath];
	else
		cell = [tableView dequeueReusableCellWithIdentifier:@"contact_cell_one_name" forIndexPath:indexPath];

	if (contact.first_name && contact.last_name) {
		UILabel *first = (UILabel *)[cell viewWithTag:1];
		UILabel *second_bold = (UILabel *)[cell viewWithTag:2];

		first.text = contact.first_name;
		second_bold.text = contact.last_name;
	}
	else if (contact.first_name) {
		// no last name
		UILabel *first = (UILabel *)[cell viewWithTag:1];
		first.text = contact.first_name;
	}
	else if (contact.last_name) {
		// no first name
		UILabel *first = (UILabel *)[cell viewWithTag:1];
		first.text = contact.last_name;
	}
	else {
		UILabel *first = (UILabel *)[cell viewWithTag:1];
		// neither first nor last names exist
		// show first phone number if we have no other info
		first.text = [contact.phone_numbers objectAtIndex:0];
	}

	return cell;
}

// row was selected, toggle the accessory checkmark and call network functions
- (void)tableView:(UITableView *)tableView
	didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSInteger section = [indexPath section];
	NSInteger row = [indexPath row];

	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	Contact *contact = [[_cells objectAtIndex:section] objectAtIndex:row];

	NSMutableDictionary *request = [[NSMutableDictionary alloc] init];
	if ([cell accessoryType] == UITableViewCellAccessoryNone) {
		// Toggling the contact on, add friend

		[request setObject:[contact.phone_numbers objectAtIndex:0] forKey:@"friend_phnum"];
		[network_connection send_message:friend_add contents:request];

		[cell setAccessoryType:UITableViewCellAccessoryCheckmark];
	}
	else {
		// Toggling contact off, delete friend
		[request setObject:[contact.phone_numbers objectAtIndex:0] forKey:@"friend_phnum"];
		[network_connection send_message:friend_delete contents:request];

		[cell setAccessoryType:UITableViewCellAccessoryNone];
	}

	NSLog(@"info: selected %@ %@ who has %lu phone numbers",
	      contact.first_name, contact.last_name, (unsigned long)[contact.phone_numbers count]);
}

// programatically assign section headers, in this case they're letters
- (NSString *)tableView:(UITableView *)tableView
	titleForHeaderInSection:(NSInteger)section
{
	return [_section_to_letter objectAtIndex:section];
}

// needed to make the section header font bigger
- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view
       forSection:(NSInteger)section
{
	UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;

	header.textLabel.font = [UIFont boldSystemFontOfSize:18];
}


// these two delegates below put the "quick index" ribbon on the right side
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
	return [[UILocalizedIndexedCollation currentCollation] sectionIndexTitles];
}

- (NSInteger)tableView:(UITableView *)tableView
	sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
	return [[UILocalizedIndexedCollation currentCollation] sectionForSectionIndexTitleAtIndex:index];
}

@end