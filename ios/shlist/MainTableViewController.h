#import <UIKit/UIKit.h>

#import "DataStructures.h"

@interface MainTableViewController : UITableViewController

- (void) update_address_book;

- (void) lists_get_finished:(NSArray *)lists;
- (void) lists_get_other_finished:(NSArray *)other_lists;
- (void) finished_new_list_request:(SharedList *) shlist;
- (void) finished_join_list_request:(NSDictionary *) shlist;
- (void) finished_leave_list_request:(NSDictionary *) shlist;

- (IBAction)unwindToList:(UIStoryboardSegue *)segue;

@end