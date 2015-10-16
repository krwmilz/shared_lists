#import <UIKit/UIKit.h>

#import "DataStructures.h"

@interface MainTableViewController : UITableViewController

@property NSMutableArray *shared_lists;
@property NSMutableArray *indirect_lists;

- (void) update_address_book;

- (void) finished_new_list_request:(SharedList *) shlist;
- (void) finished_join_list_request:(SharedList *) shlist;
- (void) finished_leave_list_request:(SharedList *) shlist;

- (IBAction)unwindToList:(UIStoryboardSegue *)segue;

@end