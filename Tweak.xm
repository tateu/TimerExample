//#define NSLog(fmt, ...)

@interface SBClockDataProvider : NSObject
+ (id)sharedInstance;
@end

@interface PCPersistentTimer : NSObject
@property BOOL disableSystemWaking;
@property(readonly) double fireTime;
@property double minimumEarlyFireProportion;
- (double)_earlyFireTime;
- (BOOL)disableSystemWaking;
- (double)fireTime;
- (id)initWithFireDate:(id)arg1 serviceIdentifier:(id)arg2 target:(id)arg3 selector:(SEL)arg4 userInfo:(id)arg5;
- (id)initWithTimeInterval:(double)arg1 serviceIdentifier:(id)arg2 target:(id)arg3 selector:(SEL)arg4 userInfo:(id)arg5;
- (void)invalidate;
- (BOOL)isValid;
- (double)minimumEarlyFireProportion;
- (void)scheduleInRunLoop:(id)arg1;
- (void)setMinimumEarlyFireProportion:(double)arg1;
- (id)userInfo;
@end

@interface MFMessage : NSObject <NSCopying>
- (id)messageIDHeader;
- (id)subject;
@end

@interface MFMailMessage : MFMessage
@end

@interface MailboxContentSelectionModel : NSObject
-(id)selectedMessages;
@end

@interface MailboxContentViewCell : UITableViewCell
- (MFMailMessage *)message;
@end

@interface MailboxContentViewController : UIViewController
//@property (nonatomic,retain) UITableView * tableView;
-(id)currentTableView;
@end

#define timerExamplePList @"/private/var/mobile/Library/Preferences/net.tateu.timerexample.plist"
#define timerExampleBundleID @"net.tateu.timerexample"
#define timerExampleNotification "net.tateu.timerexample/starttimer"
static PCPersistentTimer *timerExample = nil;
static UIAlertView *timerExampleAlert = nil;

static void TimerExampleLoadTimer();

%group MAIL
%hook MailboxContentViewController
%new
-(void)longPressEmailET:(UILongPressGestureRecognizer *)gestureRecognizer
{
	if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
		CGPoint p = [gestureRecognizer locationInView:[self currentTableView]];

		NSIndexPath *indexPath = [[self currentTableView] indexPathForRowAtPoint:p];
        if (indexPath == nil) {
		} else {
			NSString *title = @"ERROR";
			NSString *msg = nil;

			MailboxContentViewCell *cell = (MailboxContentViewCell *)[[self currentTableView] cellForRowAtIndexPath:indexPath];
			if (cell) {
				float fireDateOffsetSeconds = 0;
				if ((p.x - cell.frame.origin.x) < (cell.frame.size.width / 2.0)) {
					fireDateOffsetSeconds = 120;
				} else {
					fireDateOffsetSeconds = 240;
				}

				// Failed attempt to use userInfo passed from a sandboxed process to SpringBoard
				//
				//
////				CFDictionaryKeyCallBacks keyCallbacks = {0, NULL, NULL, CFCopyDescription, CFEqual, NULL};
////				CFDictionaryValueCallBacks valueCallbacks  = {0, NULL, NULL, CFCopyDescription, CFEqual};
////				CFMutableDictionaryRef dictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &keyCallbacks, &valueCallbacks);
//				CFMutableDictionaryRef dictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
//
//				CFNumberRef fireDateOffsetSecondsNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberFloatType, &fireDateOffsetSeconds);
//				CFDictionaryAddValue(dictionary, CFSTR("fireDateOffsetSeconds"), fireDateOffsetSecondsNum);
//
//				if ([[cell message] messageIDHeader]) {
//					NSString *deepLink = [NSString stringWithFormat:@"message://%@", [[[cell message] messageIDHeader] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
//					CFDictionaryAddValue(dictionary, CFSTR("deepLink"), (__bridge CFStringRef)deepLink);
//				}
//		
//				if ([[cell message] subject]) {
//					CFDictionaryAddValue(dictionary, CFSTR("subject"), (__bridge CFStringRef)[[cell message] subject]);
//				}
//
//				CFNotificationCenterPostNotificationWithOptions(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(timerExampleNotification), NULL, dictionary, TRUE);
//				CFRelease(dictionary);
				//
				//
				// Failed attempt to use userInfo passed from a sandboxed process to SpringBoard

				NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
				NSDate *fireDate = [NSDate dateWithTimeInterval:fireDateOffsetSeconds sinceDate:[NSDate date]];
				[data setObject:fireDate forKey:@"fireDate"];

				if ([[cell message] messageIDHeader]) {
					NSString *deepLink = [NSString stringWithFormat:@"message://%@", [[[cell message] messageIDHeader] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
					[data setObject:deepLink forKey:@"deepLink"];
				}

				if ([[cell message] subject]) {
					[data setObject:[[cell message] subject] forKey:@"subject"];
				}

				[data writeToFile:timerExamplePList atomically:YES];
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
					NSLog(@"[TimerExample] sending CFNotificationCenterPostNotification");
					CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(timerExampleNotification), NULL, NULL, TRUE);
				});
			} else {
				msg = @"Unable to locate email cell. Maybe you did not tap and hold directly on an email!";
			}

			if (msg) {
				UIAlertView *alert = [[UIAlertView alloc]
									  initWithTitle:title
									  message:msg
									  delegate:self
									  cancelButtonTitle:@"Cancel"
									  otherButtonTitles:nil];
				[alert show];
			}
		}
	}
}

-(void)viewWillAppear:(BOOL)animated
{
	%orig;

	UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressEmailET:)];
	gesture.minimumPressDuration = 1.0; //seconds
	[[self currentTableView] addGestureRecognizer:gesture];
}
%end //hook MailboxContentViewController
%end //group MAIL

%group SPRINGBOARD
%hook SpringBoard
-(void)applicationDidFinishLaunching:(id)application
{
	%orig;

	NSLog(@"[TimerExample] SpringBoard applicationDidFinishLaunching");
	TimerExampleLoadTimer();
}
%end

%hook SBClockDataProvider
%new
- (void)TimerExampleOpenURL:(id)sender
{
	UIButton *button = (UIButton *)sender;
	[[UIApplication sharedApplication] openURL:[[NSURL alloc] initWithString:button.currentTitle]];

	if (timerExampleAlert) {
		[timerExampleAlert dismissWithClickedButtonIndex:0 animated:YES];
		timerExampleAlert = nil;
	}
}

%new
- (void)TimerExampleFired
{
	NSLog(@"[TimerExample] TimerExampleFired");

	NSDictionary *userInfo = [timerExample userInfo];
	NSString *title = @"Example Timer Fired";
	NSString *msg = @"No Subject";
	UIView *buttonView = nil;
	
	if (userInfo) {
		if ([userInfo objectForKey:@"subject"]) {
			msg = [userInfo objectForKey:@"subject"];
		}

		if ([userInfo objectForKey:@"deepLink"]) {
			buttonView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 44)];
			[buttonView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
			buttonView.backgroundColor = [UIColor clearColor];

			UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
			button.frame = CGRectMake(0, 0, 100, 44);
			[button setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
			button.backgroundColor = [UIColor colorWithRed:0.8 green: 0.0 blue:0.0 alpha:1.0];
			[button setTitle:[userInfo objectForKey:@"deepLink"] forState:UIControlStateNormal];
			[button addTarget:self action:@selector(TimerExampleOpenURL:) forControlEvents:UIControlEventTouchUpInside];
			[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

			[buttonView addSubview:button];
		}
	}

	timerExampleAlert = [[UIAlertView alloc]
						 initWithTitle:title
						 message:msg
						 delegate:self
						 cancelButtonTitle:@"Cancel"
						 otherButtonTitles:nil];
	timerExampleAlert.tag = 4615;

	if (buttonView) {
		[timerExampleAlert setValue:buttonView forKey:@"accessoryView"];
	}

	[timerExampleAlert show];

	if (timerExample) {
		[timerExample invalidate];
		timerExample = nil;
	}
}
%end //hook SBClockDataProvider
%end //group SPRINGBOARD

static void TimerExampleLoadTimer()
{
	NSDictionary *userInfoDictionary = nil;
	NSString *deepLink = nil;
	NSString *subject = nil;

	userInfoDictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:timerExamplePList];

	if (!userInfoDictionary) {
		return;
	}

	deepLink = [userInfoDictionary objectForKey:@"deepLink"];
	subject = [userInfoDictionary objectForKey:@"subject"];
	NSDate *fireDate = [userInfoDictionary objectForKey:@"fireDate"];

	if (!fireDate || [[NSDate date] compare:fireDate] == NSOrderedDescending) {
		NSLog(@"[TimerExample] TimerExampleLoadTimer - invalid or in the past");
		return;
	}

	NSMutableDictionary *data = [[NSMutableDictionary alloc] init];

	if (deepLink) {
		[data setObject:deepLink forKey:@"deepLink"];;
	}

	if (subject) {
		[data setObject:subject forKey:@"subject"];
	}

	[timerExample setMinimumEarlyFireProportion:86400];
	timerExample = [[%c(PCPersistentTimer) alloc] initWithFireDate:fireDate serviceIdentifier:timerExampleBundleID target:[%c(SBClockDataProvider) sharedInstance] selector:@selector(TimerExampleFired) userInfo:data];

	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
	[formatter setTimeZone:[NSTimeZone defaultTimeZone]];
	NSLog(@"[TimerExample] Added Timer %@", [formatter stringFromDate:fireDate]);

	if ([NSThread isMainThread]) {
		[timerExample scheduleInRunLoop:[NSRunLoop mainRunLoop]];
	} else {
		dispatch_async(dispatch_get_main_queue(), ^ {
			[timerExample scheduleInRunLoop:[NSRunLoop mainRunLoop]];
		});
	}
}

static void TimerExampleNotified(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	// Failed attempt to use userInfo passed from a sandboxed process to SpringBoard
	//
	//
//	NSDictionary *userInfoDictionary = nil;
//	float fireDateOffsetSeconds = 5;
//	NSString *deepLink = nil;
//	NSString *subject = nil;
	//
	//
	// Failed attempt to use userInfo passed from a sandboxed process to SpringBoard

	NSLog(@"[TimerExample] received CFNotificationCenterPostNotification");

	// kill old timer
	if (timerExample) {
		[timerExample invalidate];
		timerExample = nil;
	}

	TimerExampleLoadTimer();

	// Failed attempt to use userInfo passed from a sandboxed process to SpringBoard
	//
	//
////	if (userInfo) {
////		CFNumberRef fireDateOffsetSecondsNum = (CFNumberRef)CFDictionaryGetValue(userInfo, CFSTR("fireDateOffsetSeconds"));
////		if (fireDateOffsetSecondsNum) {
////			CFNumberGetValue(fireDateOffsetSecondsNum, kCFNumberFloatType, &fireDateOffsetSeconds);
////		}
////
////		CFNumberRef fireDateOffsetSecondsNum = (CFNumberRef)CFDictionaryGetValue(userInfo, CFSTR("fireDateOffsetSeconds"));
////		if (fireDateOffsetSecondsNum) {
////			CFNumberGetValue(fireDateOffsetSecondsNum, kCFNumberFloatType, &fireDateOffsetSeconds);
////		}
////	}
//	userInfoDictionary = (__bridge NSDictionary *)dictionary;
//
//	if (!userInfoDictionary) {
//		return;
//	}
//
//	deepLink = [userInfoDictionary objectForKey:@"deepLink"];
//	subject = [userInfoDictionary objectForKey:@"subject"];
//	fireDateOffsetSeconds = [userInfoDictionary objectForKey:@"fireDateOffsetSeconds"] ? [[userInfoDictionary objectForKey:@"fireDateOffsetSeconds"] floatValue] : fireDateOffsetSeconds;
//
//	NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
//
//	if (deepLink) {
//		[data setObject:deepLink forKey:@"deepLink"];;
//	}
//
//	if (subject) {
//		[data setObject:subject forKey:@"subject"];
//	}
//
//	NSDate *fireDate = [NSDate dateWithTimeInterval:fireDateOffsetSeconds sinceDate:[NSDate date]];
//	[timerExample setMinimumEarlyFireProportion:86400];
//	timerExample = [[%c(PCPersistentTimer) alloc] initWithFireDate:fireDate serviceIdentifier:TimerExampleBundleID target:[%c(SBClockDataProvider) sharedInstance] selector:@selector(TimerExampleFired) userInfo:data];
//
//	if ([NSThread isMainThread]) {
//		[timerExample scheduleInRunLoop:[NSRunLoop mainRunLoop]];
//	} else {
//		dispatch_async(dispatch_get_main_queue(), ^ {
//			[timerExample scheduleInRunLoop:[NSRunLoop mainRunLoop]];
//		});
//	}
	//
	//
	// Failed attempt to use userInfo passed from a sandboxed process to SpringBoard
}

%ctor
{
	@autoreleasepool {
		if (%c(SpringBoard)) {
			CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, TimerExampleNotified, CFSTR(timerExampleNotification), NULL, CFNotificationSuspensionBehaviorCoalesce);
			%init(SPRINGBOARD);
		} else {
			%init(MAIL);
		}
	}
}
