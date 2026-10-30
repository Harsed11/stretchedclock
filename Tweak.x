#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

@interface SBFLockScreenDateView : UIView
@property (nonatomic, retain) UIView *timeLabel;
@end

%hook SBFLockScreenDateView

- (void)layoutSubviews {
    %orig;

    // Снимаем ограничение обрезки (clipsToBounds) у себя и родительских вью,
    // чтобы длинные цифры не обрезались по краям контейнера
    UIView *parent = self;
    for (int i = 0; i < 4 && parent != nil; i++) {
        parent.clipsToBounds = NO;
        parent = parent.superview;
    }

    UIView *label = nil;
    if ([self respondsToSelector:@selector(timeLabel)]) {
        label = [self timeLabel];
    }
    if (!label) {
        @try {
            label = [self valueForKey:@"_timeLabel"];
        } @catch (NSException *e) {}
    }

    if (label) {
        label.clipsToBounds = NO;

        // Сбрасываем предыдущую трансформацию для точного замера исходного положения
        label.transform = CGAffineTransformIdentity;
        CGRect origFrame = label.frame;

        // Коэффициенты трансформации:
        // scaleX = 0.80 (делаем цифры более узкими/condensed)
        // scaleY = 2.50 (вытягиваем по высоте в 2.5 раза)
        CGFloat scaleX = 0.80;
        CGFloat scaleY = 2.50;

        label.transform = CGAffineTransformMakeScale(scaleX, scaleY);

        // При масштабировании центр вью остается на месте, из-за чего верх улетел бы вверх.
        // Смещаем центр вниз так, чтобы верхний край цифр оставался строго под строкой даты:
        CGPoint newCenter = label.center;
        newCenter.y = origFrame.origin.y + (origFrame.size.height * scaleY) / 2.0;
        label.center = newCenter;
    }
}

%end
