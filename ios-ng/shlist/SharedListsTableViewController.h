#import <UIKit/UIKit.h>

@interface SharedListsTableViewController : UITableViewController

@property NSMutableArray *shared_lists;
@property NSMutableArray *indirect_lists;


- (IBAction)unwindToList:(UIStoryboardSegue *)segue;

@end