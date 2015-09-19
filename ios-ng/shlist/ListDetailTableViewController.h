#import <UIKit/UIKit.h>
#import "DataStructures.h"

@interface ListDetailTableViewController : UITableViewController

@property SharedList *list_metadata;
@property NSMutableArray *list_items;
- (IBAction)unwindToList:(UIStoryboardSegue *)segue;
- (void) setMetadata:(SharedList *)metadata;


@end
