#import "NewItemTableViewController.h"

@interface NewItemTableViewController ()

@end

@implementation NewItemTableViewController

// called when shared switch is toggled
- (IBAction)shared_switch:(id)sender
{
	// hide/unhide the shared status group
	[self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	// get the shared switch state to see if the shared properties should
	// be shown
	NSIndexPath *index_path = [NSIndexPath indexPathForRow:1 inSection:0];

	UITableViewCell *cell = [super tableView:tableView
			   cellForRowAtIndexPath:index_path];

	UISwitch *shared_switch = (UISwitch *)[cell viewWithTag:1];

	if (shared_switch.isOn) {
		return 2;
	} else {
		return 1;
	}
}

- (NSInteger)tableView:(UITableView *)tableView
	numberOfRowsInSection:(NSInteger)section
{

	// NSLog(@"info: reloading rows in table view");

	if (section == 0)
		return 3;
	else if (section == 1)
		return 2;

	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
	cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:<#@"reuseIdentifier"#> forIndexPath:indexPath];
    
    // Configure the cell...
    
    //return cell;

	UITableViewCell *cell = [super tableView:tableView
			   cellForRowAtIndexPath:indexPath];
	// cell.accessoryType = UITableViewCellAccessoryNone;

	// NSUInteger section = [indexPath section];
	// NSUInteger row = [indexPath row];

	/*
	switch (section)
	{
		case SECTION_SPEED:
			if (row == self.speed)
			{
				cell.accessoryType = UITableViewCellAccessoryCheckmark;
			}
			break;

		case SECTION_VOLUME:
			if (row == self.volume)
			{
				cell.accessoryType = UITableViewCellAccessoryCheckmark;
			}
			break;
	}
	 */
	return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

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
