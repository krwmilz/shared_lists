#import "EditItemTableViewController.h"
#import "ListTableViewController.h"

#import "DataStructures.h"
#import "Network.h"

@interface ListTableViewController () {
	Network *network_connection;
}

- (void)load_initial_data;

@end

@implementation ListTableViewController

- (void) load_initial_data
{
	ListItem *item = [[ListItem alloc] init];
	item.name = @"Cheese Pizza";
	item.owner = @"Dave";
	item.committed = 1;
	item.shared = 1;
	[self.list_items addObject:item];

	item = [[ListItem alloc] init];
	item.modifier = 0;
	item.name = @"Camp stove";
	item.owner = @"Steve";
	item.committed = 1;
	item.shared = 1;
	[self.list_items addObject:item];

	item = [[ListItem alloc] init];
	item.name = @"Ear Plugs";
	item.quantity = 10;
	item.owner = @"";
	item.committed = 0;
	item.shared = 1;
	[self.list_items addObject:item];

	item = [[ListItem alloc] init];
	item.name = @"Fruit by the Foot";
	item.quantity = 1;
	item.owner = @"You";
	item.committed = 1;
	item.shared = 1;
	[self.list_items addObject:item];

	item = [[ListItem alloc] init];
	item.name = @"Well used matress";
	item.quantity = 1;
	item.owner = @"";
	item.committed = 0;
	item.shared = 1;
	[self.list_items addObject:item];

	item = [[ListItem alloc] init];
	item.name = @"Rifle and Ammo";
	item.quantity = 1;
	item.owner = @"Greg";
	item.committed = 1;
	item.shared = 1;
	[self.list_items addObject:item];


	item = [[ListItem alloc] init];
	item.name = @"Deoderant";
	item.shared = 0;
	[self.private_items addObject:item];

	item = [[ListItem alloc] init];
	item.name = @"Toothbrush";
	item.shared = 0;
	[self.private_items addObject:item];

	item = [[ListItem alloc] init];
	item.name = @"Pillow";
	[self.private_items addObject:item];

	item = [[ListItem alloc] init];
	item.name = @"Brass knuckles";
	[self.private_items addObject:item];

	item = [[ListItem alloc] init];
	item.name = @"Soldering Iron";
	[self.private_items addObject:item];

	item = [[ListItem alloc] init];
	item.name = @"8mm wrench";
	[self.private_items addObject:item];

	item = [[ListItem alloc] init];
	item.name = @"Fuzzy Dice";
	[self.private_items addObject:item];

	item = [[ListItem alloc] init];
	item.name = @"Jerry Can";
	[self.private_items addObject:item];
}

- (void) viewDidLoad
{
	[super viewDidLoad];

	// Uncomment the following line to preserve selection between
	// presentations.
	// self.clearsSelectionOnViewWillAppear = NO;

	// Uncomment the following line to display an Edit button in the
	// navigation bar for this view controller.
	// self.navigationItem.leftBarButtonItem = self.editButtonItem;

	_list_items = [[NSMutableArray alloc] init];
	_private_items = [[NSMutableArray alloc] init];

	network_connection = [Network shared_network_connection];
	[self load_initial_data];
}

- (void) didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (IBAction)commit_toggled:(id)sender
{
	NSIndexPath *path = [self.tableView indexPathForCell:sender];

	NSLog(@"debug: toggled commit at %@", path);
}

// called when previous segue's are unwinding
- (IBAction)unwindToList:(UIStoryboardSegue *)segue
{
}

- (void) setMetadata:(SharedList *)metadata
{
	_list_metadata = metadata;
	self.title = _list_metadata.name;
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section == 0)
		return [_list_items count];
	else if (section == 1)
		return [_private_items count];
	return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == 0)
		return [NSString stringWithFormat:@"Shared Items (%i)", [_list_items count]];
	else if (section == 1)
		return [NSString stringWithFormat:@"Private Items (%i)", [_private_items count]];
	return @"";
}

- (UITableViewCell *) tableView:(UITableView *)tableView
	  cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ListDetailPrototypeCell"
		forIndexPath:indexPath];

	// Tags:
	// 1) modifier -- ie $, info, etc
	// 2) item name
	// 3) quantity of item, in parenthesis
	// 4) owners name
	// 5) completion/packing of item

	UILabel *item_name = (UILabel *)[cell viewWithTag:2];
	UILabel *quantity = (UILabel *)[cell viewWithTag:3];
	UILabel *owner = (UILabel *)[cell viewWithTag:4];
	UISwitch *commit_switch = (UISwitch *)[cell viewWithTag:5];

	/*
	if (item.modifier == 1) {
		UIImageView *image_view;
		image_view = (UIImageView *)[cell viewWithTag:1];
		image_view.image = [UIImage imageNamed: @"dollar103-2.png"];
	 }
	 else if (item.modifier == 2) {
		UIImageView *image_view;
		image_view = (UIImageView *)[cell viewWithTag:1];
		image_view.image = [UIImage imageNamed: @"information15-3.png"];
	 }
	 */

	ListItem *item;
	if ([indexPath section] == 0) {
		// "shared items" section
		item = [self.list_items objectAtIndex:indexPath.row];

		owner.text = @"";
		[commit_switch setOn:item.committed animated:YES];

		if (item.committed) {
			if ([item.owner compare:@"You"] == NSOrderedSame)
				owner.text = @"";
			else {
				owner.text = item.owner;
				[commit_switch setEnabled:NO];
			}
		}
		
		commit_switch.hidden = false;
		owner.hidden = false;
	}
	else if ([indexPath section] == 1) {
		// "private items" section
		item = [self.private_items objectAtIndex:indexPath.row];

		// no owner or commit fields here
		owner.hidden = true;
		commit_switch.hidden = true;
	}
	else
		return nil;

	item_name.text = item.name;

	if (item.quantity > 1)
		quantity.text = [NSString stringWithFormat:@"x%d", item.quantity];
	else
		quantity.text = @"";

	return cell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}


// Override to support editing the table view.
- (void) tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
	forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	// This guys answer here saved my ass once
	// http://stackoverflow.com/questions/9727549/unrecognized-selector-sent-to-instance-using-storyboards

	// I like the two line version from above but it gives warnings :(
	EditItemTableViewController *tvc = (EditItemTableViewController *)[[segue destinationViewController] topViewController];

	if ([[segue identifier] isEqualToString:@"edit item segue"]) {
		// NSIndexPath *path = [self.tableView indexPathForSelectedRow];
		
		NSIndexPath *path = [self.tableView indexPathForCell:sender];
		ListItem *item;
		if ([path section] == 0)
			item = [self.list_items objectAtIndex:[path row]];
		else if ([path section] == 1)
			item = [self.private_items objectAtIndex:[path row]];
		else
			// segue from unknown section
			return;

		// make sure incoming view controller knows about itself
		[tvc set_item:item for_list:_list_metadata];
		[tvc set_edit_or_new:@"Edit Item"];

		NSLog(@"debug: %@: edit item segue", _list_metadata.name);
	}
	else if ([[segue identifier] isEqualToString:@"add item segue"]) {
		[tvc set_edit_or_new:@"Add Item"];
		NSLog(@"debug: %@: add item segue", _list_metadata.name);
	}
}

@end