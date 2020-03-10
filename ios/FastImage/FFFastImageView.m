#import "FFFastImageView.h"
#import <SDWebImage/UIImage+MultiFormat.h>
#import "objc/runtime.h"

@interface FFFastImageView()

@property (nonatomic, assign) BOOL hasSentOnLoadStart;
@property (nonatomic, assign) BOOL hasCompleted;
@property (nonatomic, assign) BOOL hasErrored;
// Whether the latest change of props requires the image to be reloaded
@property (nonatomic, assign) BOOL needsReload;

@property (nonatomic, strong) NSDictionary* onLoadEvent;

@end

@implementation FFFastImageView
- (id) init {
    self = [super init];
    self.resizeMode = RCTResizeModeCover;
    self.clipsToBounds = YES;
    return self;
}

- (void)setSd_imageIndicator:(id<SDWebImageIndicator>)sd_imageIndicator {
    // Remove the old indicator view
    id<SDWebImageIndicator> previousIndicator = self.sd_imageIndicator;
    [previousIndicator.indicatorView removeFromSuperview];

    objc_setAssociatedObject(self, @selector(sd_imageIndicator), sd_imageIndicator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Add the new indicator view
    UIView *view = sd_imageIndicator.indicatorView;
    if (CGRectEqualToRect(view.frame, CGRectZero)) {
        view.frame = self.bounds;
    }
    // Center the indicator view
#if SD_MAC
    [view setFrameOrigin:CGPointMake(round((NSWidth(self.bounds) - NSWidth(view.frame)) / 2), round((NSHeight(self.bounds) - NSHeight(view.frame)) / 2))];
#else
    view.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
#endif
    view.hidden = YES;
    view.alpha = 1;

    [self addSubview:view];
}

- (void)sd_startImageIndicator {
    id<SDWebImageIndicator> imageIndicator = self.sd_imageIndicator;
    if (!imageIndicator) {
        return;
    }

    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        dispatch_main_async_safe(^{
            if (imageIndicator.indicatorView.alpha != 0) {
                [imageIndicator startAnimatingIndicator];
            }
        });
    });
}

- (void)sd_stopImageIndicator {
    id<SDWebImageIndicator> imageIndicator = self.sd_imageIndicator;
    if (!imageIndicator) {
        return;
    }
    dispatch_main_async_safe(^{
        imageIndicator.indicatorView.alpha = 0;
        [imageIndicator stopAnimatingIndicator];
    });
}

- (void)setResizeMode:(RCTResizeMode)resizeMode {
    if (_resizeMode != resizeMode) {
        _resizeMode = resizeMode;
        self.contentMode = (UIViewContentMode)resizeMode;
    }
}

- (void)setOnFastImageLoadEnd:(RCTDirectEventBlock)onFastImageLoadEnd {
    _onFastImageLoadEnd = onFastImageLoadEnd;
    if (self.hasCompleted) {
        _onFastImageLoadEnd(@{});
    }
}

- (void)setOnFastImageLoad:(RCTDirectEventBlock)onFastImageLoad {
    _onFastImageLoad = onFastImageLoad;
    if (self.hasCompleted) {
        _onFastImageLoad(self.onLoadEvent);
    }
}

- (void)setOnFastImageError:(RCTDirectEventBlock)onFastImageError {
    _onFastImageError = onFastImageError;
    if (self.hasErrored) {
        _onFastImageError(@{});
    }
}

- (void)setOnFastImageLoadStart:(RCTDirectEventBlock)onFastImageLoadStart {
    if (_source && !self.hasSentOnLoadStart) {
        _onFastImageLoadStart = onFastImageLoadStart;
        onFastImageLoadStart(@{});
        self.hasSentOnLoadStart = YES;
    } else {
        _onFastImageLoadStart = onFastImageLoadStart;
        self.hasSentOnLoadStart = NO;
    }
}

- (void)sendOnLoad:(UIImage *)image {
    self.onLoadEvent = @{
                         @"width":[NSNumber numberWithDouble:image.size.width],
                         @"height":[NSNumber numberWithDouble:image.size.height]
                         };
    if (self.onFastImageLoad) {
        self.onFastImageLoad(self.onLoadEvent);
    }
}

- (void)setSource:(FFFastImageSource *)source {
    if (_source != source) {
        _source = source;
        _needsReload = YES;
    }
}

- (void)didSetProps:(NSArray<NSString *> *)changedProps
{
    if (_needsReload) {
        [self reloadImage];
    }
}

- (void)reloadImage
{
    _needsReload = NO;

    if (_source) {
        // Set headers.
        NSDictionary *headers = _source.headers;
        SDWebImageDownloaderRequestModifier *requestModifier = [SDWebImageDownloaderRequestModifier requestModifierWithBlock:^NSURLRequest * _Nullable(NSURLRequest * _Nonnull request) {
            NSMutableURLRequest *mutableRequest = [request mutableCopy];
            for (NSString *header in headers) {
                NSString *value = headers[header];
                [mutableRequest setValue:value forHTTPHeaderField:header];
            }
            return [mutableRequest copy];
        }];

        SDWebImageContext *context = @{SDWebImageContextDownloadRequestModifier : requestModifier};
        
        // Set priority.
        SDWebImageOptions options = SDWebImageRetryFailed | SDWebImageHandleCookies;
        switch (_source.priority) {
            case FFFPriorityLow:
                options |= SDWebImageLowPriority;
                break;
            case FFFPriorityNormal:
                // Priority is normal by default.
                break;
            case FFFPriorityHigh:
                options |= SDWebImageHighPriority;
                break;
        }

        switch (_source.cacheControl) {
            case FFFCacheControlWeb:
                options |= SDWebImageRefreshCached;
                break;
            case FFFCacheControlCacheOnly:
                options |= SDWebImageFromCacheOnly;
                break;
            case FFFCacheControlImmutable:
                break;
        }

        if (self.onFastImageLoadStart) {
            self.onFastImageLoadStart(@{});
            self.hasSentOnLoadStart = YES;
        } {
            self.hasSentOnLoadStart = NO;
        }
        self.hasCompleted = NO;
        self.hasErrored = NO;
        
        if (_source.placeholder) {
            self.sd_imageIndicator = SDWebImageActivityIndicator.grayIndicator;
            self.sd_imageTransition = SDWebImageTransition.fadeTransition;
        }

        [self downloadImage:_source options:options context:context];
    }
}

- (void)downloadImage:(FFFastImageSource *) source options:(SDWebImageOptions) options context:(SDWebImageContext *)context {
    __weak typeof(self) weakSelf = self; // Always use a weak reference to self in blocks

    [self sd_setImageWithURL:source.url
            placeholderImage:nil
                     options:options
                     context:context
                    progress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
                        if (weakSelf.onFastImageProgress) {
                            weakSelf.onFastImageProgress(@{
                                                           @"loaded": @(receivedSize),
                                                           @"total": @(expectedSize)
                                                           });
                        }
                    } completed:^(UIImage * _Nullable image,
                                  NSError * _Nullable error,
                                  SDImageCacheType cacheType,
                                  NSURL * _Nullable imageURL) {
                        if (error) {
                            weakSelf.hasErrored = YES;
                                if (weakSelf.onFastImageError) {
                                    weakSelf.onFastImageError(@{});
                                }
                                if (weakSelf.onFastImageLoadEnd) {
                                    weakSelf.onFastImageLoadEnd(@{});
                                }
                        } else {
                            weakSelf.hasCompleted = YES;
                            [weakSelf sendOnLoad:image];
                            if (weakSelf.onFastImageLoadEnd) {
                                weakSelf.onFastImageLoadEnd(@{});
                            }
                        }
                    }];
}

@end
