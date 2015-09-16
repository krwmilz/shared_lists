#import <Foundation/Foundation.h>

@interface AddressBook : NSObject

@property (strong, retain) NSMutableArray *contacts;
@property unsigned long num_contacts;

// returns singleton instance
+ (id) shared_address_book;

- (void) wait_for_ready;

@property volatile uint32_t ready;

@end

@interface Contact : NSObject

@property NSString *first_name;
@property NSString *last_name;
@property NSMutableArray *phone_numbers;

@end