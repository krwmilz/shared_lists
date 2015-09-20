#import "AddressBook.h"

#include <AddressBook/AddressBook.h>
#import <UIKit/UIKit.h>

#include "libkern/OSAtomic.h"

@interface AddressBook ()

@end

// empty implementation
@implementation Contact
@end

@implementation AddressBook

+ (id)shared_address_book
{
	static AddressBook *address_book = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		address_book = [[self alloc] init];
	});
	return address_book;
}

- (id)init
{
	self = [super init];
	if (self)
	{
		_contacts = [[NSMutableArray alloc] init];
		ready = 0;
		[self get_contacts_or_fail];
	}
	return self;
}

- (void) get_contacts_or_fail
{
	ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();

	if (status == kABAuthorizationStatusDenied || status == kABAuthorizationStatusRestricted) {
		// if you got here, user had previously denied/revoked permission for your
		// app to access the contacts, and all you can do is handle this gracefully,
		// perhaps telling the user that they have to go to settings to grant access
		// to contacts

		[[[UIAlertView alloc] initWithTitle:nil message:@"This app requires access to your contacts to function properly. Please visit to the \"Privacy\" section in the iPhone Settings app." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
		return;
	}

	CFErrorRef error = NULL;
	ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &error);

	if (!addressBook) {
		NSLog(@"ABAddressBookCreateWithOptions error: %@", CFBridgingRelease(error));
		return;
	}

	// ABAddressBookRegisterExternalChangeCallback(<#ABAddressBookRef addressBook#>, <#ABExternalChangeCallback callback#>, <#void *context#>)

	ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
		if (error) {
			NSLog(@"ABAddressBookRequestAccessWithCompletion error: %@", CFBridgingRelease(error));
		}

		if (granted) {
			// if they gave you permission, then just carry on
			[self listPeopleInAddressBook:addressBook];
			if (_main_tvc)
				[_main_tvc update_address_book];
			else
				NSLog(@"warn: address book: address book ready before main_tvc assigned!");

			// atomically set the ready flag; this completion handler
			// can be run on an arbitrary thread
			OSAtomicIncrement32((volatile int32_t *)&ready);
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


- (void)listPeopleInAddressBook:(ABAddressBookRef)addressBook
{
	NSArray *allPeople = CFBridgingRelease(ABAddressBookCopyArrayOfAllPeople(addressBook));

	NSCharacterSet *want =[[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet];

	for (NSInteger i = 0; i < [allPeople count]; i++) {
		ABRecordRef person = (__bridge ABRecordRef)allPeople[i];
		Contact *contact = [[Contact alloc] init];

		// don't enforce these existing
		contact.first_name = CFBridgingRelease(ABRecordCopyValue(person, kABPersonFirstNameProperty));
		contact.last_name  = CFBridgingRelease(ABRecordCopyValue(person, kABPersonLastNameProperty));
		contact.phone_numbers = [[NSMutableArray alloc] init];

		ABMultiValueRef phoneNumbers = ABRecordCopyValue(person, kABPersonPhoneProperty);
		CFIndex numberOfPhoneNumbers = ABMultiValueGetCount(phoneNumbers);
		for (CFIndex i = 0; i < numberOfPhoneNumbers; i++) {
			NSString *pn = CFBridgingRelease(ABMultiValueCopyValueAtIndex(phoneNumbers, i));

			if (pn == nil)
				continue;

			NSString *cleaned = [[pn componentsSeparatedByCharactersInSet: want] componentsJoinedByString:@""];

			[contact.phone_numbers addObject:cleaned];
		}
		CFRelease(phoneNumbers);

		[_contacts addObject:contact];
	}

	_num_contacts = [_contacts count];
	NSLog(@"info: address book: %lu contacts found", _num_contacts);
}

@end