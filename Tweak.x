#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <CoreFoundation/CoreFoundation.h>

// ─── Настройки (читаются из plist, можно менять через Настройки iPhone) ───

static BOOL enabled = YES;
static CGFloat scaleX = 0.65;  // ширина цифр (0.3 – 1.2, по умолчанию 0.65)
static CGFloat scaleY = 2.00;  // высота цифр (1.0 – 4.0, по умолчанию 2.0)

static void loadPrefs() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:
        @"/var/mobile/Library/Preferences/com.harsed.stretchedclock.plist"];
    if (prefs) {
        if (prefs[@"enabled"])  enabled = [prefs[@"enabled"] boolValue];
        if (prefs[@"scaleX"])   scaleX  = [prefs[@"scaleX"] floatValue];
        if (prefs[@"scaleY"])   scaleY  = [prefs[@"scaleY"] floatValue];
    }
}

// ─── Интерфейсы приватных классов ───

@interface SBUILegibilityLabel : UIView
@property (nonatomic, strong) UIImage *textImage;
@end

@interface SBFLockScreenDateView : UIView
@property (nonatomic, strong) SBUILegibilityLabel *timeLabel;
@end

// ─── Хук экрана блокировки ───

%hook SBFLockScreenDateView

- (void)layoutSubviews {
    %orig;

    if (!enabled) return;

    // Получаем вью с временем (SBUILegibilityLabel)
    UIView *timeLabel = nil;
    @try {
        timeLabel = [self valueForKey:@"_timeLabel"];
    } @catch (NSException *e) {
        return;
    }
    if (!timeLabel) return;

    // Применяем масштабирование.
    // CGAffineTransformMakeScale масштабирует вокруг центра вью,
    // поэтому позиция не съезжает и не нужно двигать центр вручную.
    timeLabel.transform = CGAffineTransformMakeScale(scaleX, scaleY);

    // Отключаем обрезку, чтобы вытянутые цифры не обрезались
    self.clipsToBounds = NO;
    timeLabel.clipsToBounds = NO;
}

%end

// ─── Инициализация ───

%ctor {
    loadPrefs();

    // Слушаем уведомление от PreferenceLoader при изменении настроек
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        (CFNotificationCallback)loadPrefs,
        CFSTR("com.harsed.stretchedclock/prefsChanged"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
}
