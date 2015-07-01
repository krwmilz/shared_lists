#import "SharedListsTableViewController.h"
#import "SharedList.h"
#import "NewListViewController.h"
#import "ShlistServer.h"

@interface SharedListsTableViewController ()

@property (strong, nonatomic) ShlistServer *server;

@end

@implementation SharedListsTableViewController

- (void) load_initial_data
{
	// register if we've never registered before
	// load local shared list data from db
	// sync with server and check if there's any updates

	// initialize connection
	_server = [[ShlistServer alloc] init];

	bool initialized = false;
	if (!initialized) {
		// new client
		[_server writeToServer:"\x00\x00\x00\x0a" "4037082094" :15];
		// [server readFromServer];
	}

	NSLog(@"SharedListsTableViewController::load_initial_data()");

	// NSString *num = [[NSUserDefaults standardUserDefaults] stringForKey:@"SBFormattedPhoneNumber"];
	// NSLog(@"%@\n", num);

	// ShlistServer *server = [[ShlistServer alloc] init];
	// [server writeToServer:"\x00\x00\xff\0x00"];

	SharedList *list1 = [[SharedList alloc] init];
	list1.list_name = @"Camping";
	list1.list_members = @"David, Kyle, Greg";
	[self.shared_lists addObject:list1];

	SharedList *list2 = [[SharedList alloc] init];
	list2.list_name = @"Wedding";
	list2.list_members = @"Kyle, Stephanie";
	[self.shared_lists addObject:list2];
}

- (IBAction) unwindToList:(UIStoryboardSegue *)segue
{
	NewListViewController *source = [segue sourceViewController];
	SharedList *list = source.shared_list;

	if (list != nil) {
		[self.shared_lists addObject:list];
		[self.tableView reloadData];
	}

	NSLog(@"unwindToList(): done");
}

- (void)viewDidLoad
{
	[super viewDidLoad];
    
	// Uncomment the following line to preserve selection between
	// presentations.
	// self.clearsSelectionOnViewWillAppear = NO;
    
	// display an Edit button in the navigation bar for this view controller
	self.navigationItem.leftBarButtonItem = self.editButtonItem;
    
	self.shared_lists = [[NSMutableArray alloc] init];
	[self load_initial_data];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [self.shared_lists count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell;
	cell = [tableView dequeueReusableCellWithIdentifier:@"SharedListPrototypeCell" forIndexPath:indexPath];
	// UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SharedListPrototypeCell"];
    
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"SharedListPrototypeCell"];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}

	NSLog(@"SharedListsTableViewController::cellForRowAtIndexPath()");

	// configure the cell
	SharedList *shared_list = [self.shared_lists objectAtIndex:indexPath.row];
	cell.textLabel.text = shared_list.list_name;
	cell.detailTextLabel.text = shared_list.list_members;

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
