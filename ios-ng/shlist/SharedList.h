#ifndef shlist_List_h
#define shlist_List_h

@interface SharedList : NSObject

// @property (weak, nonatomic) IBOutlet;
// UILabel *names;

@property NSString *list_name;
@property NSData *list_id;
@property NSString *list_members;
@property NSDate *list_date;

@end

#endif
