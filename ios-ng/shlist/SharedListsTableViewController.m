#import "SharedListsTableViewController.h"
#import "SharedList.h"
#import "NewListViewController.h"
#import "ShlistServer.h"
#import "ListDetailTableViewController.h"

#import <AddressBook/AddressBook.h>

@interface SharedListsTableViewController ()

@property (strong, nonatomic) ShlistServer *server;
@property (strong, nonatomic) NSData *device_id;

@end

@implementation SharedListsTableViewController

- (void) load_initial_data
{
	// register if we've never registered before
	// load local shared list data from db
	// sync with server and check if there's any updates

	// initialize connection
	_server = [[ShlistServer alloc] init];
	_server->shlist_tvc = self;
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSString *destinationPath = [documentsDirectory stringByAppendingPathComponent:@"shlist_key"];

	// NSError *error = nil;
	// [[NSFileManager defaultManager] removeItemAtPath:destinationPath error:&error];

	if (![[NSFileManager defaultManager] fileExistsAtPath:destinationPath]) {
		// do a fake registration
		NSData *msg_register = [NSData dataWithBytes:"\x00\x00\x00\x0a" "4037082094" length:15];
		[_server writeToServer:msg_register];
		NSLog(@"Sent registration");
	}

	// send bulk shared list update
	NSMutableData *msg = [NSMutableData data];
	[msg appendBytes:"\x00\x03" length:2];

	// read device id from filesystem into memory
	_device_id = [NSData dataWithContentsOfFile:destinationPath];

	// write length of device id as uint16
	uint16_t dev_id_len_network = htons([_device_id length]);
	[msg appendBytes:&dev_id_len_network length:2];
	
	// append device id itself
	[msg appendData:_device_id];

	// NSLog(@"SharedListsTableViewController::load_initial_data() device id lenth = %i", device_id_length);

	// NSString *num = [[NSUserDefaults standardUserDefaults] stringForKey:@"SBFormattedPhoneNumber"];
	// NSLog(@"%@\n", num);

	// ShlistServer *server = [[ShlistServer alloc] init];
	[_server writeToServer:msg];
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

	// new list message
	NSMutableData *msg = [NSMutableData data];
	[msg appendBytes:"\x00\x01" length:2];

	// length = device id + list name + null separator
	uint16_t length_network_endian = htons([_device_id length] + [list.list_name length] + 1);
	[msg appendBytes:&length_network_endian length:2];

	// append device id
	[msg appendData:_device_id];

	// append null separator
	[msg appendBytes:"\0" length:1];

	// append new list name
	[msg appendData:[list.list_name dataUsingEncoding:NSUTF8StringEncoding]];

	// send message
	[_server writeToServer:msg];

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
	if (section == 0) {
		return [self.shared_lists count];
	}
	else if (section == 1) {
		return [self.indirect_lists count];
	}

	return 0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSLog(@"did cell selection");
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell;

	// NSLog(@"SharedListsTableViewController::cellForRowAtIndexPath()");

	NSInteger section_number = [indexPath section];
	if (section_number == 0) {
		cell = [tableView dequeueReusableCellWithIdentifier:@"SharedListPrototypeCell" forIndexPath:indexPath];
		// UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SharedListPrototypeCell"];

		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"SharedListPrototypeCell"];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}

		SharedList *shared_list = [self.shared_lists objectAtIndex:indexPath.row];
		cell.textLabel.text = shared_list.list_name;
		cell.detailTextLabel.text = shared_list.list_members;
	}
	else if (section_number == 1) {
		cell = [tableView dequeueReusableCellWithIdentifier:@"IndirectListPrototypeCell" forIndexPath:indexPath];
		// UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SharedListPrototypeCell"];

		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"IndirectListPrototypeCell"];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}

		SharedList *shared_list = [self.indirect_lists objectAtIndex:indexPath.row];
		cell.textLabel.text = shared_list.list_name;
		cell.detailTextLabel.text = shared_list.list_members;
	}

	return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == 0) {
		if ([self.shared_lists count] == 0) {
			return @"you're not in any lists";
		}
		else if ([self.shared_lists count] == 1) {
			return @"list you are in";
		}
		return @"lists you are in";
	}
	else if (section == 1) {
		if ([self.indirect_lists count] == 0) {
			return @"your friends don't have any lists";
		}
		else if ([self.indirect_lists count] == 1) {
			return @"list your friends are in";
		}
		return @"lists your friends are in";
	}
	return @"";
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
	   editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if ([indexPath section] == 0) {
		return UITableViewCellEditingStyleDelete;
	}
	return UITableViewCellEditingStyleInsert;
}

// Override to support conditional editing of the table view.
- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	// if ([indexPath section] == 0) {
		// editable
		return YES;
	// }

	// return NO;
}

// Override to support editing the table view.
- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		// Delete the row from the data source
		// [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];

		NSIndexPath *path = [self.tableView indexPathForSelectedRow];
		SharedList *selected_list = [self.shared_lists objectAtIndex:[path row]];

		NSLog(@"info: leaving list '%@'", selected_list.list_name);

		// delete list message
		NSMutableData *msg = [NSMutableData data];
		[msg appendBytes:"\x00\x05" length:2];

		// length = device id + null separator + list id
		uint16_t length_network_endian = htons([_device_id length] + [selected_list.list_id length] + 1);
		[msg appendBytes:&length_network_endian length:2];

		// append device id
		[msg appendData:_device_id];

		// append null separator
		[msg appendBytes:"\0" length:1];

		// append new list name
		[msg appendData:[selected_list.list_id dataUsingEncoding:NSUTF8StringEncoding]];

		// send message
		[_server writeToServer:msg];

		// [self.shared_lists removeObjectAtIndex:[indexPath row]];
	} else if (editingStyle == UITableViewCellEditingStyleInsert) {
		// Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view

		NSIndexPath *path = [self.tableView indexPathForSelectedRow];
		SharedList *selected_list = [self.indirect_lists objectAtIndex:[path row]];

		NSLog(@"info: joining list '%@'", selected_list.list_name);

		// join list message
		NSMutableData *msg = [NSMutableData data];
		[msg appendBytes:"\x00\x04" length:2];

		// length = device id + null separator + list id
		uint16_t length_network_endian = htons([_device_id length] + [selected_list.list_id length] + 1);
		[msg appendBytes:&length_network_endian length:2];

		// append device id
		[msg appendData:_device_id];

		// append null separator
		[msg appendBytes:"\0" length:1];

		// append new list name
		[msg appendData:[selected_list.list_id dataUsingEncoding:NSUTF8StringEncoding]];

		// send message
		[_server writeToServer:msg];
	}
}

/*
// Override to support rearranging the table view.
- (void) tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL) tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.

	if ([[segue identifier] isEqualToString:@"show list segue"]) {

		NSIndexPath *path = [self.tableView indexPathForSelectedRow];
		SharedList *list = [self.shared_lists objectAtIndex:[path row]];

		// only list detail table view controller has this method
		[segue.destinationViewController setMetadata:list];

		// has to be done before issuing network request
		_server->shlist_ldvc = segue.destinationViewController;

		// update list items message type
		NSMutableData *msg = [NSMutableData data];
		[msg appendBytes:"\x00\x06" length:2];

		// length = device id + list name + null separator
		uint16_t length_network_endian = htons([_device_id length] + [list.list_id length] + 1);
		[msg appendBytes:&length_network_endian length:2];

		// append device id
		[msg appendData:_device_id];

		// append null separator
		[msg appendBytes:"\0" length:1];

		// append new list name
		[msg appendData:[list.list_id dataUsingEncoding:NSUTF8StringEncoding]];

		// send message
		[_server writeToServer:msg];
	}
	// DetailObject *detail = [self detailForIndexPath:path];


	// ListDetailTableViewController *list_detail_tvc = [segue destinationViewController];
	// list_detail_tvc.navigationItem.title = @"Test Title";

	NSLog(@"preparing for segue");
}

@end
