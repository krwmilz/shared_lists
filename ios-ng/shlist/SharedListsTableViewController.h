#import <UIKit/UIKit.h>

@interface SharedListsTableViewController : UITableViewController

@property NSMutableArray *shared_lists;

- (IBAction)unwindToList:(UIStoryboardSegue *)segue;

@end
