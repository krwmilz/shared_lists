#import <UIKit/UIKit.h>
#import <AddressBookUI/AddressBookUI.h>

@interface ContactsViewController : UIViewController <ABPeoplePickerNavigationControllerDelegate> {
	ABPeoplePickerNavigationController *picker;
}


@end