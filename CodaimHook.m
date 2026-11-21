#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>

// ------------------------------------------------------------------ Config
#define AIM_STICKINESS 0.85      // 0.0 to 1.0 (higher = stickier)
#define ANTI_BAN_INTERVAL 30     // seconds between ban checks
#define MAX_BAN_ATTEMPTS 5       // soft ban threshold

// ------------------------------------------------------------------ State
static BOOL g_aim_enabled = YES;
static CGPoint g_crosshair = CGPointZero;
static CGFloat g_stickiness = AIM_STICKINESS;
static int g_ban_attempts = 0;
static NSTimeInterval g_last_ban_check = 0;

// ------------------------------------------------------------------ Anti-Ban Logic
static void check_ban_status() {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - g_last_ban_check < ANTI_BAN_INTERVAL) return;
    
    g_last_ban_check = now;
    
    // Simulate ban check (replace with actual API call if needed)
    /*
    NSURL *url = [NSURL URLWithString:@"https://your-api.com/check-ban"];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url 
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!error && data) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([json[@"banned"] boolValue]) {
                    g_aim_enabled = NO;
                    g_ban_attempts++;
                    if (g_ban_attempts >= MAX_BAN_ATTEMPTS) {
                        exit(0);
                    }
                } else {
                    g_ban_attempts = 0;
                }
            }
        }];
    [task resume];
    */
}

// ------------------------------------------------------------------ Aim Assist Core
static CGPoint calculate_aim_target(CGPoint screenCenter, CGPoint enemyPos) {
    CGFloat offsetX = enemyPos.x - screenCenter.x;
    CGFloat offsetY = enemyPos.y - screenCenter.y;
    
    offsetX *= g_stickiness;
    offsetY *= g_stickiness;
    
    offsetX = fmaxf(-50.0, fminf(50.0, offsetX));
    offsetY = fmaxf(-50.0, fminf(50.0, offsetY));
    
    return CGPointMake(screenCenter.x + offsetX, screenCenter.y + offsetY);
}

// ------------------------------------------------------------------ UI Overlay
static UIView *g_aim_overlay = nil;
static UILabel *g_status_label = nil;

static void setup_aim_overlay() {
    if (g_aim_overlay) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        g_aim_overlay = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 40)];
        g_aim_overlay.backgroundColor = [UIColor clearColor];
        g_aim_overlay.alpha = 0.8;
        
        g_status_label = [[UILabel alloc] initWithFrame:g_aim_overlay.bounds];
        g_status_label.text = @"AIM: ON";
        g_status_label.textColor = [UIColor greenColor];
        g_status_label.font = [UIFont systemFontOfSize:12];
        g_status_label.textAlignment = NSTextAlignmentCenter;
        
        [g_aim_overlay addSubview:g_status_label];
        
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (keyWindow) {
            [keyWindow addSubview:g_aim_overlay];
            g_aim_overlay.hidden = NO;
        }
    });
}

// ------------------------------------------------------------------ Main Hook Entry
__attribute__((constructor))
static void codaim_init() {
    NSLog(@"[Codaim] Initializing...");
    
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(0, 0));
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, ANTI_BAN_INTERVAL * NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(timer, ^{
        check_ban_status();
    });
    dispatch_resume(timer);
    
    setup_aim_overlay();
    NSLog(@"[Codaim] Ready!");
}

// ------------------------------------------------------------------ Public API
void set_aim_enabled(BOOL enabled) {
    g_aim_enabled = enabled;
    dispatch_async(dispatch_get_main_queue(), ^{
        g_status_label.text = enabled ? @"AIM: ON" : @"AIM: OFF";
        g_status_label.textColor = enabled ? [UIColor greenColor] : [UIColor redColor];
    });
}

void set_stickiness(CGFloat value) {
    g_stickiness = fmaxf(0.0, fminf(1.0, value));
}

CGPoint get_aim_target(CGPoint screenCenter, CGPoint enemyPos) {
    if (!g_aim_enabled) return CGPointZero;
    return calculate_aim_target(screenCenter, enemyPos);
}
