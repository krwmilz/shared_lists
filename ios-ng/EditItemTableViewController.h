#import <UIKit/UIKit.h>
#import "DataStructures.h"

@interface EditItemTableViewController : UITableViewController

@property SharedList *list;
@property ListItem *item;

- (void) set_item:(ListItem *)item for_list:(SharedList *)list;
- (void) set_edit_or_new:(NSString *)edit_or_new;

@end
