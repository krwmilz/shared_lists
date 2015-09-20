#import <Foundation/Foundation.h>

#import "MainTableViewController.h"


@interface AddressBook : NSObject {
	@public volatile uint32_t ready;
}

@property (strong, retain) NSMutableArray *contacts;
@property unsigned long num_contacts;

// returns singleton instance
+ (id) shared_address_book;

@property (strong, nonatomic) MainTableViewController *main_tvc;

@end

@interface Contact : NSObject

@property NSString *first_name;
@property NSString *last_name;
@property NSMutableArray *phone_numbers;

@end