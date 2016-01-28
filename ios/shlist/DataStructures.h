#import <UIKit/UIKit.h>


// This object contains a lists meta information
@interface SharedList : NSObject

// @property (weak, nonatomic) IBOutlet;
// UILabel *names;

@property NSString	*name;
@property NSNumber	*num;
@property NSNumber	*items_total;
@property NSArray	*members_phone_nums;
@property NSNumber	*num_members;
@property bool		 deadline;
@property NSDate	*date;
@property NSNumber	*items_ready;

@property UITableViewCell *cell;

@end

// This object is an individual item in a list
@interface ListItem : NSObject

@property int		 modifier;
@property NSString	*name;
@property int		 quantity;
@property bool		 shared;
@property NSString	*owner;
@property bool		 committed;
@property bool		 completed;

@end