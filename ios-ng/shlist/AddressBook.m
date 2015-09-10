#import "AddressBook.h"
#include <AddressBook/AddressBook.h>
#import <UIKit/UIKit.h>


@implementation AddressBook

- (id)init
{
	self = [super init];
	if (self)
	{
		ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();

		if (status == kABAuthorizationStatusDenied || status == kABAuthorizationStatusRestricted) {
			// if you got here, user had previously denied/revoked permission for your
			// app to access the contacts, and all you can do is handle this gracefully,
			// perhaps telling the user that they have to go to settings to grant access
			// to contacts

			[[[UIAlertView alloc] initWithTitle:nil message:@"This app requires access to your contacts to function properly. Please visit to the \"Privacy\" section in the iPhone Settings app." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
			return self;
		}

		CFErrorRef error = NULL;
		ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &error);

		if (!addressBook) {
			NSLog(@"ABAddressBookCreateWithOptions error: %@", CFBridgingRelease(error));
			return self;
		}

		ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
			if (error) {
				NSLog(@"ABAddressBookRequestAccessWithCompletion error: %@", CFBridgingRelease(error));
			}

			if (granted) {
				// if they gave you permission, then just carry on

				[self listPeopleInAddressBook:addressBook];
			} else {
				// however, if they didn't give you permission, handle it gracefully, for example...

				dispatch_async(dispatch_get_main_queue(), ^{
					// BTW, this is not on the main thread, so dispatch UI updates back to the main queue

					[[[UIAlertView alloc] initWithTitle:nil message:@"This app requires access to your contacts to function properly. Please visit to the \"Privacy\" section in the iPhone Settings app." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
				});
			}
			
			CFRelease(addressBook);
		});
	}
	return self;
}

- (void)listPeopleInAddressBook:(ABAddressBookRef)addressBook
{
	NSArray *allPeople = CFBridgingRelease(ABAddressBookCopyArrayOfAllPeople(addressBook));
	NSInteger numberOfPeople = [allPeople count];

	_name_map = [NSMutableDictionary dictionaryWithCapacity:numberOfPeople];

	for (NSInteger i = 0; i < numberOfPeople; i++) {
		ABRecordRef person = (__bridge ABRecordRef)allPeople[i];

		NSString *firstName = CFBridgingRelease(ABRecordCopyValue(person, kABPersonFirstNameProperty));
		// NSString *lastName  = CFBridgingRelease(ABRecordCopyValue(person, kABPersonLastNameProperty));
		// NSLog(@"Name:%@ %@", firstName, lastName);

		ABMultiValueRef phoneNumbers = ABRecordCopyValue(person, kABPersonPhoneProperty);

		if (firstName == nil) {
			// if we don't have a first name then we can't display it
			continue;
		}

		CFIndex numberOfPhoneNumbers = ABMultiValueGetCount(phoneNumbers);
		for (CFIndex i = 0; i < numberOfPhoneNumbers; i++) {
			NSString *phoneNumber = CFBridgingRelease(ABMultiValueCopyValueAtIndex(phoneNumbers, i));

			if (phoneNumber == nil) {
				// if we have a name but no phone number, there's
				// nothing we can do
				continue;
			}

			phoneNumber = [phoneNumber stringByReplacingOccurrencesOfString:@" " withString:@""];
			phoneNumber = [phoneNumber stringByReplacingOccurrencesOfString:@"(" withString:@""];
			phoneNumber = [phoneNumber stringByReplacingOccurrencesOfString:@")" withString:@""];
			phoneNumber = [phoneNumber stringByReplacingOccurrencesOfString:@"-" withString:@""];

			[_name_map setObject:firstName forKey:phoneNumber];

			// NSLog(@"  phone:%@", phoneNumber);
		}

		CFRelease(phoneNumbers);

		// NSLog(@"=============================================");
	}
}

@end