#import <UIKit/UIKit.h>
#import "DataStructures.h"

@interface ListTableViewController : UITableViewController

@property SharedList *list_metadata;

@property NSMutableArray *list_items;
@property NSMutableArray *private_items;

- (IBAction)unwindToList:(UIStoryboardSegue *)segue;
- (void) setMetadata:(SharedList *)metadata;


@end
