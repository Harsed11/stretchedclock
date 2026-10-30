#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <spawn.h>

// ─── Переменные настроек ───

static BOOL enabled = YES;
static CGFloat scaleX = 0.65;  // Ширина (0.3 – 1.5)
static CGFloat scaleY = 2.00;  // Высота (1.0 – 4.0)

@interface SBFLockScreenDateView : UIView
@property (nonatomic, strong) UIView *timeLabel;
@end

static __weak SBFLockScreenDateView *currentDateView = nil;

// ─── Надежное чтение настроек через CFPreferences (работает в песочнице SpringBoard) ───

static void loadPrefs() {
    CFPreferencesAppSynchronize(CFSTR("com.harsed.stretchedclock"));

    Boolean exists = false;
    Boolean bVal = CFPreferencesGetAppBooleanValue(CFSTR("enabled"), CFSTR("com.harsed.stretchedclock"), &exists);
    if (exists) {
        enabled = bVal;
    } else {
        enabled = YES;
    }

    CFPropertyListRef xVal = CFPreferencesCopyAppValue(CFSTR("scaleX"), CFSTR("com.harsed.stretchedclock"));
    if (xVal) {
        if (CFGetTypeID(xVal) == CFNumberGetTypeID()) {
            scaleX = [(__bridge NSNumber *)xVal floatValue];
        }
        CFRelease(xVal);
    } else {
        scaleX = 0.65;
    }

    CFPropertyListRef yVal = CFPreferencesCopyAppValue(CFSTR("scaleY"), CFSTR("com.harsed.stretchedclock"));
    if (yVal) {
        if (CFGetTypeID(yVal) == CFNumberGetTypeID()) {
            scaleY = [(__bridge NSNumber *)yVal floatValue];
        }
        CFRelease(yVal);
    } else {
        scaleY = 2.00;
    }

    // Если вью сейчас на экране, немедленно перерисовываем
    if (currentDateView) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [currentDateView setNeedsLayout];
            [currentDateView layoutIfNeeded];
        });
    }
}

// ─── Обработка респринга ───

static void doRespring() {
    pid_t pid;
    const char *args[] = {"sbreload", NULL};
    posix_spawn(&pid, "/var/jb/usr/bin/sbreload", NULL, NULL, (char *const *)args, NULL);
}

static void handleRespringNotify(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    doRespring();
}

// ─── Хук часов экрана блокировки ───

%hook SBFLockScreenDateView

- (void)layoutSubviews {
    %orig;

    currentDateView = self;

    UIView *timeLabel = nil;
    UIView *dateView = nil;
    @try {
        timeLabel = [self valueForKey:@"_timeLabel"];
        dateView = [self valueForKey:@"_dateSubtitleView"];
    } @catch (NSException *e) {}

    if (!timeLabel) return;

    if (!enabled) {
        timeLabel.transform = CGAffineTransformIdentity;
        return;
    }

    // Снимаем ограничение обрезки у родительских контейнеров
    self.clipsToBounds = NO;
    timeLabel.clipsToBounds = NO;
    if (dateView) dateView.clipsToBounds = NO;

    UIView *parent = self.superview;
    for (int i = 0; i < 4 && parent != nil; i++) {
        parent.clipsToBounds = NO;
        parent = parent.superview;
    }

    // Сбрасываем трансформацию для точного расчёта исходного размера
    timeLabel.transform = CGAffineTransformIdentity;

    CGRect origTimeFrame = timeLabel.frame;
    CGRect origDateFrame = dateView ? dateView.frame : CGRectZero;

    // В стиле iOS 18:
    // Дата отображается СВЕРХУ над часами, а вытянутые цифры часов начинаются ПОД датой
    if (dateView) {
        CGRect newDateFrame = origDateFrame;
        newDateFrame.origin.y = 8.0;
        dateView.frame = newDateFrame;

        CGFloat dateBottom = CGRectGetMaxY(newDateFrame);
        CGFloat spacing = 4.0;

        timeLabel.transform = CGAffineTransformMakeScale(scaleX, scaleY);

        CGFloat scaledHeight = origTimeFrame.size.height * scaleY;
        CGPoint center = timeLabel.center;
        center.y = (dateBottom + spacing) + (scaledHeight / 2.0);
        timeLabel.center = center;
    } else {
        timeLabel.transform = CGAffineTransformMakeScale(scaleX, scaleY);

        CGFloat scaledHeight = origTimeFrame.size.height * scaleY;
        CGPoint center = timeLabel.center;
        center.y = origTimeFrame.origin.y + (scaledHeight / 2.0);
        timeLabel.center = center;
    }
}

%end

// ─── Хук Настроек (для кнопки Респринг) ───

@interface PSListController : UIViewController
@end

%hook PSListController

%new
- (void)respringAction {
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.harsed.stretchedclock/respring"),
        NULL,
        NULL,
        YES
    );
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        doRespring();
    });
}

%end

// ─── Конструктор ───

%ctor {
    loadPrefs();

    // Слушаем изменение настроек
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        (CFNotificationCallback)loadPrefs,
        CFSTR("com.harsed.stretchedclock/prefsChanged"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );

    // Слушаем запрос на респринг
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        (CFNotificationCallback)handleRespringNotify,
        CFSTR("com.harsed.stretchedclock/respring"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
}
