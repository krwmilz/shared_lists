#import "ListTableViewController.h"
#import "DataStructures.h"
#import "ShlistServer.h"

@interface ListTableViewController ()

- (void)load_initial_data;
@property (strong, nonatomic) ShlistServer *server;

@end

@implementation ListTableViewController

- (void) load_initial_data
{
	// NSLog(@"ListDetailTableViewController::load_initial_data()");

	ListItem *item1 = [[ListItem alloc] init];
	item1.modifier = 1;
	item1.name = @"cheese";
	item1.quantity = 3;
	item1.owner = @"Kyle";
	item1.completed = 0;
	[self.list_items addObject:item1];

	ListItem *item2 = [[ListItem alloc] init];
	item2.modifier = 0;
	item2.name = @"camp stove";
	item2.quantity = 1;
	item2.owner = @"";
	item2.completed = 1;
	[self.list_items addObject:item2];

	ListItem *item3 = [[ListItem alloc] init];
	item3.modifier = 2;
	item3.name = @"ear plugs";
	item3.quantity = 1;
	item3.owner = @"";
	item3.completed = 0;
	[self.list_items addObject:item3];
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

	self.list_items = [[NSMutableArray alloc] init];
	[self load_initial_data];
}

- (void) didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (IBAction)unwindToList:(UIStoryboardSegue *)segue {

}

- (void) setMetadata:(SharedList *)metadata
{
	_list_metadata = metadata;
	self.title = _list_metadata.list_name;

}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [self.list_items count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == 0) {
		return @"shared items";
	}
	else if (section == 1) {
		return @"personal items";
	}
	return @"";
}

- (UITableViewCell *) tableView:(UITableView *)tableView
	  cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ListDetailPrototypeCell"
		forIndexPath:indexPath];

	NSUInteger section = [indexPath section];
    
	// NSLog(@"ListDetailTableViewController::cellForRowAtIndexPath()");
	// Tags:
	// 1) modifier -- ie $, info, etc
	// 2) item name
	// 3) quantity of item, in parenthesis
	// 4) owners name
	// 5) completion/packing of item

	UILabel *label;
	ListItem *item = [self.list_items objectAtIndex:indexPath.row];

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

	label = (UILabel *)[cell viewWithTag:2];
	label.text = item.name;

	label = (UILabel *)[cell viewWithTag:3];
	if (item.quantity > 1) {
		label.text = [NSString stringWithFormat:@"(x%d)", item.quantity];
	} else {
		label.text = @"";
	}

	label = (UILabel *)[cell viewWithTag:4];
	if (section == 0)
		// XXX: this should go to N/A when item doesn't have an owner
		label.text = item.owner;
	else
		label.hidden = true;

	label = (UILabel *)[cell viewWithTag:5];
	if (section == 0)
		;
	else
		label.hidden = true;

	return cell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}


// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end