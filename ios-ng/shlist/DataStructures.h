#import <UIKit/UIKit.h>

@interface SharedList : NSObject

// @property (weak, nonatomic) IBOutlet;
// UILabel *names;

@property NSString *list_name;
@property NSData *list_id;
@property NSString *list_members;
@property NSDate *list_date;
@property UITableViewCell *cell;

@property int items_ready;
@property int items_total;

@end

@interface ListItem : NSObject

@property int modifier;
@property NSString *name;
@property int quantity;
@property NSString *owner;
@property int completed;

@end