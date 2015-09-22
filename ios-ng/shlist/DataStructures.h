#import <UIKit/UIKit.h>


// This object contains a lists meta information
@interface SharedList : NSObject

// @property (weak, nonatomic) IBOutlet;
// UILabel *names;

@property NSString	*name;
@property NSData	*id;
@property NSArray	*members_phone_nums;
@property NSDate	*date;
@property int		 items_ready;
@property int		 items_total;
@property UITableViewCell *cell;

@end


// This object is an individual item in a list
@interface ListItem : NSObject

@property int		 modifier;
@property NSString	*name;
@property int		 quantity;
@property NSString	*owner;
@property bool		 committed;
@property int		 completed;

@end