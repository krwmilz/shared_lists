#import "ContactsViewController.h"

@interface ContactsViewController ()

@end

@implementation ContactsViewController

- (void) viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
	
	picker = [[ABPeoplePickerNavigationController alloc] init];
	picker.peoplePickerDelegate = self;
 
	// [self presentModalViewController:picker animated:YES];

	picker.view.frame = self.view.bounds;
	[self.view addSubview:picker.view];
}

- (void) didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL) peoplePickerNavigationController:
(ABPeoplePickerNavigationController *)peoplePicker
      shouldContinueAfterSelectingPerson:(ABRecordRef)person {
 
	NSLog(@"%s", person);
	// [self displayPerson:person];
	// [self dismissModalViewControllerAnimated:YES];
 
	return NO;
}

- (BOOL) peoplePickerNavigationController:
(ABPeoplePickerNavigationController *)peoplePicker
      shouldContinueAfterSelectingPerson:(ABRecordRef)person
				property:(ABPropertyID)property
			      identifier:(ABMultiValueIdentifier)identifier
{
	return NO;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end