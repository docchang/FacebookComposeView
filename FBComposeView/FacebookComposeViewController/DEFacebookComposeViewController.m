//
//  DEFacebookComposeViewController.m
//  DEFacebooker
//
//  Copyright (c) 2011-2012 Double Encore, Inc. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
//  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer 
//  in the documentation and/or other materials provided with the distribution. Neither the name of the Double Encore Inc. nor the names of its 
//  contributors may be used to endorse or promote products derived from this software without specific prior written permission.
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
//  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS 
//  BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
//  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
//  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

//  RENAMED to
//  DEFacebookComposeViewController.m
//  DEFacebook
//
//  Modified by Vladmir on 03/09/2012.
//  www.developers-life.com


#import "DEFacebookComposeViewController.h"
#import "DEFacebookSheetCardView.h"
#import "DEFacebookTextView.h"
#import "DEFacebookGradientView.h"
#import "UIDevice+DEFacebookComposeViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <FacebookSDK/FacebookSDK.h>

static BOOL waitingForAccess = NO;


@interface DEFacebookComposeViewController ()

@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) NSMutableArray *images;
@property (nonatomic, strong) NSMutableArray *urls;
@property (nonatomic, strong) NSArray *attachmentFrameViews;
@property (nonatomic, strong) NSArray *attachmentImageViews;
@property (nonatomic) UIStatusBarStyle previousStatusBarStyle;
@property (nonatomic, weak) UIViewController *fromViewController;
@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic, strong) DEFacebookGradientView *gradientView;
@property (nonatomic, strong) UIPickerView *accountPickerView;
@property (nonatomic, strong) UIPopoverController *accountPickerPopoverController;


- (void)tweetComposeViewControllerInit;
- (void)updateFramesForOrientation:(UIInterfaceOrientation)interfaceOrientation;
- (BOOL)isPresented;
- (NSInteger)attachmentsCount;
- (void)updateAttachments;
- (UIImage*)captureScreen;

@end


@implementation DEFacebookComposeViewController

    // IBOutlets
@synthesize cardView = _cardView;
@synthesize titleLabel = _titleLabel;
@synthesize cancelButton = _cancelButton;
@synthesize sendButton = _sendButton;
@synthesize cardHeaderLineView = _cardHeaderLineView;
@synthesize textView = _textView;
@synthesize textViewContainer = _textViewContainer;
@synthesize paperClipView = _paperClipView;
@synthesize attachment1FrameView = _attachment1FrameView;
@synthesize attachment2FrameView = _attachment2FrameView;
@synthesize attachment3FrameView = _attachment3FrameView;
@synthesize attachment1ImageView = _attachment1ImageView;
@synthesize attachment2ImageView = _attachment2ImageView;
@synthesize attachment3ImageView = _attachment3ImageView;
@synthesize characterCountLabel = _characterCountLabel;

    // Public
@synthesize completionHandler = _completionHandler;
@synthesize alwaysUseDETwitterCredentials = _alwaysUseDETwitterCredentials;
@synthesize params;

    // Private
@synthesize text = _text;
@synthesize images = _images;
@synthesize urls = _urls;
@synthesize attachmentFrameViews = _attachmentFrameViews;
@synthesize attachmentImageViews = _attachmentImageViews;
@synthesize previousStatusBarStyle = _previousStatusBarStyle;
@synthesize fromViewController = _fromViewController;
@synthesize backgroundImageView = _backgroundImageView;
@synthesize gradientView = _gradientView;
@synthesize accountPickerView = _accountPickerView;
@synthesize accountPickerPopoverController = _accountPickerPopoverController;

@synthesize navImage = _navImage;

enum {
    DEFacebookComposeViewControllerNoAccountsAlert = 1,
    DEFacebookComposeViewControllerCannotSendAlert
};

NSInteger const DEFacebookMaxLength = 140;
NSInteger const DEFacebookURLLength = 20;  // https://dev.twitter.com/docs/tco-url-wrapper
NSInteger const DEFacebookMaxImages = 1;  // We'll get this dynamically later, but not today.
static NSString * const DEFacebookLastAccountIdentifier = @"DEFacebookLastAccountIdentifier";

#define degreesToRadians(x) (M_PI * x / 180.0f)


#pragma mark - Class Methods



- (UIImage *) captureScreen {
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    CGRect rect = [keyWindow bounds];
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    if (![[UIApplication sharedApplication] isStatusBarHidden]) {
        CGFloat statusBarOffset = -20.0f;
        if ( UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication]statusBarOrientation]))
        {
            CGContextTranslateCTM(context,statusBarOffset, 0.0f);

        }else
        {
            CGContextTranslateCTM(context, 0.0f, statusBarOffset);
        }
    }
    
    [keyWindow.layer renderInContext:context];   
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    UIImageOrientation imageOrientation;
    switch ([UIApplication sharedApplication].statusBarOrientation) {
        case UIInterfaceOrientationLandscapeLeft:
            imageOrientation = UIImageOrientationRight;
            break;
        case UIInterfaceOrientationLandscapeRight:
            imageOrientation = UIImageOrientationLeft;
            break;
        case UIInterfaceOrientationPortrait:
            imageOrientation = UIImageOrientationUp;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            imageOrientation = UIImageOrientationDown;
            break;
        default:
            break;
    }
    
    UIImage *outputImage = [[UIImage alloc] initWithCGImage: image.CGImage
                                                      scale: 1.0
                                                orientation: imageOrientation];
    return outputImage;
}

#pragma mark - Setup & Teardown

// Load the framework bundle.
NSString * const kFBComposeViewResourceBundle = @"FBComposeView.bundle";
+ (NSBundle *)frameworkBundle {
    static NSBundle* frameworkBundle = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        NSString* mainBundlePath = [[NSBundle mainBundle] resourcePath];
        NSString* frameworkBundlePath = [mainBundlePath stringByAppendingPathComponent:kFBComposeViewResourceBundle];
        frameworkBundle = [NSBundle bundleWithPath:frameworkBundlePath];
    });
    return frameworkBundle;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:@"DEFacebookComposeView" bundle:[DEFacebookComposeViewController frameworkBundle]];
    if (self) {
        [self tweetComposeViewControllerInit];
    }
    return self;
}


- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self tweetComposeViewControllerInit];
    }
    return self;
}


- (void)tweetComposeViewControllerInit
{
    _images = [[NSMutableArray alloc] init];
    _urls = [[NSMutableArray alloc] init];
}


- (void)dealloc
{
        // IBOutlets
    
        // Public
    _completionHandler = nil;
    
        // Private
    
}


#pragma mark - Superclass Overrides

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.textViewContainer.backgroundColor = [UIColor clearColor];
    self.textView.backgroundColor = [UIColor clearColor];
    
    
    
    if ([UIDevice de_isIOS5]) {
        self.fromViewController = self.presentingViewController;
        self.textView.keyboardType = UIKeyboardTypeTwitter;
    }
    else {
        self.fromViewController = self.parentViewController;
    }
    
    
    
    
        // Put the attachment frames and image views into arrays so they're easier to work with.
        // Order is important, so we can't use IB object arrays. Or at least this is easier.
    self.attachmentFrameViews = [NSArray arrayWithObjects:
                                 self.attachment1FrameView,
                                 self.attachment2FrameView,
                                 self.attachment3FrameView,
                                 nil];
    
    self.attachmentImageViews = [NSArray arrayWithObjects:
                                 self.attachment1ImageView,
                                 self.attachment2ImageView,
                                 self.attachment3ImageView,
                                 nil];
    
        // Now add some angle to attachments 2 and 3.
    self.attachment2FrameView.transform = CGAffineTransformMakeRotation(degreesToRadians(-6.0f));
    self.attachment2ImageView.transform = CGAffineTransformMakeRotation(degreesToRadians(-6.0f));
    self.attachment3FrameView.transform = CGAffineTransformMakeRotation(degreesToRadians(-12.0f));
    self.attachment3ImageView.transform = CGAffineTransformMakeRotation(degreesToRadians(-12.0f));
    
        // Mask the corners on the image views so they don't stick out of the frame.
    [self.attachmentImageViews enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
        ((UIImageView *)obj).layer.cornerRadius = 3.0f;
        ((UIImageView *)obj).layer.masksToBounds = YES;
    }];
    
    self.textView.text = self.text;
    [self.textView becomeFirstResponder];
    
    

    
    
    [self updateAttachments];
    
    [self.navImage setNeedsDisplay];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

        // Take a snapshot of the current view, and make that our background after our view animates into place.
        // This only works if our orientation is the same as the presenting view.
        // If they don't match, just display the gray background.
    if (self.interfaceOrientation == self.fromViewController.interfaceOrientation) {
//        UIImage *backgroundImage = [self captureScreen];
//        self.backgroundImageView = [[[UIImageView alloc] initWithImage:backgroundImage] autorelease];
    }
    else {
//        self.backgroundImageView = [[[UIImageView alloc] initWithFrame:self.fromViewController.view.bounds] autorelease];
    }
//    self.backgroundImageView.autoresizingMask = UIViewAutoresizingNone;
//    self.backgroundImageView.alpha = 0.0f;
//    self.backgroundImageView.backgroundColor = [UIColor lightGrayColor];
//    [self.view insertSubview:self.backgroundImageView atIndex:0];
    
        // Now let's fade in a gradient view over the presenting view.
    self.gradientView = [[DEFacebookGradientView alloc] initWithFrame:[UIApplication sharedApplication].keyWindow.bounds];
    self.gradientView.autoresizingMask = UIViewAutoresizingNone;
    self.gradientView.transform = self.fromViewController.view.transform;
    self.gradientView.alpha = 0.0f;
    self.gradientView.center = [UIApplication sharedApplication].keyWindow.center;
    [self.fromViewController.view addSubview:self.gradientView];
    [UIView animateWithDuration:0.3f
                     animations:^ {
                         self.gradientView.alpha = 1.0f;
                     }];    
    
    self.previousStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES]; 
    
    [self updateFramesForOrientation:self.interfaceOrientation];
    
}


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.backgroundImageView.alpha = 1.0f;
    //self.backgroundImageView.frame = [self.view convertRect:self.backgroundImageView.frame fromView:[UIApplication sharedApplication].keyWindow];
    [self.view insertSubview:self.gradientView aboveSubview:self.backgroundImageView];
    
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    UIBezierPath *roundedPath = [UIBezierPath bezierPathWithRoundedRect:self.navImage.bounds
                                                      byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight
                                                            cornerRadii:CGSizeMake(13.f, 13.f)];
    [roundedPath closePath];
    maskLayer.path = [roundedPath CGPath];
    maskLayer.fillColor = [[UIColor whiteColor] CGColor];
    maskLayer.backgroundColor = [[UIColor clearColor] CGColor];
    self.navImage.layer.mask = maskLayer;
    [self.navImage setNeedsDisplay];
}


- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    UIView *presentingView = [UIDevice de_isIOS5] ? self.fromViewController.view : self.parentViewController.view;
    [presentingView addSubview:self.gradientView];
    
    [self.backgroundImageView removeFromSuperview];
    self.backgroundImageView = nil;
    
    [UIView animateWithDuration:0.3f
                     animations:^ {
                         self.gradientView.alpha = 0.0f;
                     }
                     completion:^(BOOL finished) {
                         [self.gradientView removeFromSuperview];
                     }];
    
    [[UIApplication sharedApplication] setStatusBarStyle:self.previousStatusBarStyle animated:YES];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([self.parentViewController respondsToSelector:@selector(shouldAutorotateToInterfaceOrientation:)]) {
        return [self.parentViewController shouldAutorotateToInterfaceOrientation:interfaceOrientation];
    }
    
    if ([UIDevice de_isPhone]) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    }

    return YES;  // Default for iPad.
}


- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
    [self updateFramesForOrientation:interfaceOrientation];

    // Our fake background won't rotate properly. Just hide it.
    if (interfaceOrientation == self.presentedViewController.interfaceOrientation) {
        self.backgroundImageView.alpha = 1.0f;
    }
    else {
        self.backgroundImageView.alpha = 0.0f;
    }
}


- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
}


- (void)viewDidUnload
{
        // Keep:
        //  _completionHandler
        //  _text
        //  _images
        //  _urls
        //  _twitterAccount
    
        // Save the text.
    self.text = self.textView.text;
    
        // IBOutlets
    self.cardView = nil;
    self.titleLabel = nil;
    self.cancelButton = nil;
    self.sendButton = nil;
    self.cardHeaderLineView = nil;
    self.textView = nil;
    self.textViewContainer = nil;
    self.paperClipView = nil;
    self.attachment1FrameView = nil;
    self.attachment2FrameView = nil;
    self.attachment3FrameView = nil;
    self.attachment1ImageView = nil;
    self.attachment2ImageView = nil;
    self.attachment3ImageView = nil;
    self.characterCountLabel = nil;
    
        // Private
    self.attachmentFrameViews = nil;
    self.attachmentImageViews = nil;
    self.gradientView = nil;
    self.accountPickerView = nil;
    self.accountPickerPopoverController = nil;
    
    [self setNavImage:nil];
    [super viewDidUnload];
}


#pragma mark - Public

- (BOOL)setInitialText:(NSString *)initialText
{
    if ([self isPresented]) {
        return NO;
    }
    
    self.text = initialText;  // Keep a copy in case the view isn't loaded yet.
    self.textView.text = self.text;
    
    return YES;
}


- (BOOL)addImage:(UIImage *)image
{
    [self.images removeAllObjects];
    
    if (image == nil) {
        return NO;
    }
    
    if ([self isPresented]) {
        return NO;
    }
        
    [self.images addObject:image];
    return YES;
}


- (BOOL)addImageWithURL:(NSURL *)url;
    // Not yet impelemented.
{
        // We should probably just start the download, rather than saving the URL.
        // Just save the image once we have it.
    return NO;
}


- (BOOL)removeAllImages
{
    if ([self isPresented]) {
        return NO;
    }
    
    [self.images removeAllObjects];
    return YES;
}


//- (BOOL)addURL:(NSString *)url
- (BOOL)addURL:(NSURL *)url
{
    [self.urls removeAllObjects];
    if (url == nil) {
        return NO;
    }
    
    [self.urls addObject:url.path];
    return YES;
}




#pragma mark - Private

- (void)updateFramesForOrientation:(UIInterfaceOrientation)interfaceOrientation
{    
    CGFloat buttonHorizontalMargin = 8.0f;
    CGFloat cardWidth, cardTop, cardHeight, cardHeaderLineTop, buttonTop;
    UIImage *cancelButtonImage, *sendButtonImage;
    CGFloat titleLabelFontSize, titleLabelTop;
    
    if ([UIDevice de_isPhone]) {
        cardWidth = CGRectGetWidth(self.view.bounds) - 10.0f;
        if (UIInterfaceOrientationIsPortrait(interfaceOrientation)) {
            cardTop = 25.0f;
            cardHeight = 189.0f;
            buttonTop = 7.0f;
            cancelButtonImage = [[UIImage imageNamed:@"FBComposeView.bundle/DEFacebookSendButtonPortrait"] stretchableImageWithLeftCapWidth:4 topCapHeight:0];
            sendButtonImage = [[UIImage imageNamed:@"FBComposeView.bundle/DEFacebookSendButtonPortrait"] stretchableImageWithLeftCapWidth:4 topCapHeight:0];
            cardHeaderLineTop = 41.0f;
            titleLabelFontSize = 20.0f;
            titleLabelTop = 9.0f;
        }
        else {
            cardTop = -1.0f;
            cardHeight = 150.0f;
            buttonTop = 6.0f;
            cancelButtonImage = [[UIImage imageNamed:@"FBComposeView.bundle/DEFacebookSendButtonLandscape"] stretchableImageWithLeftCapWidth:4 topCapHeight:0];
            sendButtonImage = [[UIImage imageNamed:@"FBComposeView.bundle/DEFacebookSendButtonLandscape"] stretchableImageWithLeftCapWidth:4 topCapHeight:0];
            cardHeaderLineTop = 32.0f;
            titleLabelFontSize = 17.0f;
            titleLabelTop = 5.0f;
        }
    }
    else {  // iPad. Similar to iPhone portrait.
        cardWidth = 543.0f;
        cardHeight = 189.0f;
        buttonTop = 7.0f;
        cancelButtonImage = [[UIImage imageNamed:@"FBComposeView.bundle/DEFacebookSendButtonPortrait"] stretchableImageWithLeftCapWidth:4 topCapHeight:0];
        sendButtonImage = [[UIImage imageNamed:@"FBComposeView.bundle/DEFacebookSendButtonPortrait"] stretchableImageWithLeftCapWidth:4 topCapHeight:0];
        cardHeaderLineTop = 41.0f;
        titleLabelFontSize = 20.0f;
        titleLabelTop = 9.0f;
        if (UIInterfaceOrientationIsPortrait(interfaceOrientation)) {
            cardTop = 280.0f;
        }
        else {
            cardTop = 110.0f;
        }
    }
    
    CGFloat cardLeft = trunc((CGRectGetWidth(self.view.bounds) - cardWidth) / 2);
    self.cardView.frame = CGRectMake(cardLeft, cardTop, cardWidth, cardHeight);
    
    self.navImage.frame = CGRectMake(0, 0, cardWidth, 44);
    
    self.titleLabel.font = [UIFont boldSystemFontOfSize:titleLabelFontSize];
    self.titleLabel.frame = CGRectMake(0.0f, titleLabelTop, cardWidth, self.titleLabel.frame.size.height);
    
    [self.cancelButton setBackgroundImage:cancelButtonImage forState:UIControlStateNormal];
    self.cancelButton.frame = CGRectMake(buttonHorizontalMargin, buttonTop, self.cancelButton.frame.size.width, cancelButtonImage.size.height);
    
    [self.sendButton setBackgroundImage:sendButtonImage forState:UIControlStateNormal];
    self.sendButton.frame = CGRectMake(self.cardView.bounds.size.width - buttonHorizontalMargin - self.sendButton.frame.size.width, buttonTop, self.sendButton.frame.size.width, sendButtonImage.size.height);
    
    self.cardHeaderLineView.frame = CGRectMake(0.0f, cardHeaderLineTop, self.cardView.bounds.size.width, self.cardHeaderLineView.frame.size.height);
    
    CGFloat textWidth = CGRectGetWidth(self.cardView.bounds);
    if ([self attachmentsCount] > 0) {
        textWidth -= CGRectGetWidth(self.attachment1FrameView.frame) + 10.0f;  // Got to measure frame 1, because it's not rotated. Other frames are funky.
    }
    CGFloat textTop = CGRectGetMaxY(self.cardHeaderLineView.frame) - 1.0f;
    
    
    CGFloat textHeight = self.cardView.bounds.size.height - textTop - 30.0f;
    self.textViewContainer.frame = CGRectMake(0.0f, textTop, self.cardView.bounds.size.width, textHeight);
    self.textView.frame = CGRectMake(0.0f, 6.0f, textWidth, self.textViewContainer.frame.size.height-6);
    self.textView.scrollIndicatorInsets = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, -(self.cardView.bounds.size.width - textWidth - 1.0f));
    
    self.paperClipView.frame = CGRectMake(CGRectGetMaxX(self.cardView.frame) - self.paperClipView.frame.size.width + 6.0f,
                                          CGRectGetMinY(self.cardView.frame) + CGRectGetMaxY(self.cardHeaderLineView.frame) - 1.0f,
                                          self.paperClipView.frame.size.width,
                                          self.paperClipView.frame.size.height);
    
        // We need to position the rotated views by their center, not their frame.
        // This isn't elegant, but it is correct. Half-points are required because
        // some frame sizes aren't evenly divisible by 2.
    self.attachment1FrameView.center = CGPointMake(self.cardView.bounds.size.width - 45.0f, CGRectGetMaxY(self.paperClipView.frame) - cardTop + 18.0f);
    self.attachment1ImageView.center = CGPointMake(self.cardView.bounds.size.width - 45.5, self.attachment1FrameView.center.y - 2.0f);
    
    self.attachment2FrameView.center = CGPointMake(self.attachment1FrameView.center.x - 4.0f, self.attachment1FrameView.center.y + 5.0f);
    self.attachment2ImageView.center = CGPointMake(self.attachment1ImageView.center.x - 4.0f, self.attachment1ImageView.center.y + 5.0f);
    
    self.attachment3FrameView.center = CGPointMake(self.attachment2FrameView.center.x - 4.0f, self.attachment2FrameView.center.y + 5.0f);
    self.attachment3ImageView.center = CGPointMake(self.attachment2ImageView.center.x - 4.0f, self.attachment2ImageView.center.y + 5.0f);
    
    self.gradientView.frame = self.gradientView.superview.bounds;
    
    
    if (![FBSession.activeSession isOpen]) {
        [self.sendButton setTitle:@"Log in" forState:UIControlStateNormal];
    }
    [self.navImage setNeedsDisplay];
}


- (BOOL)isPresented
{
    return [self isViewLoaded];
}





- (NSInteger)attachmentsCount
{
    return [self.images count] + [self.urls count];
}


- (void)updateAttachments
{
    CGRect frame = self.textView.frame;
    if ([self attachmentsCount] > 0) {
        frame.size.width = self.cardView.frame.size.width - self.attachment1FrameView.frame.size.width;
    }
    else {
        frame.size.width = self.cardView.frame.size.width;
    }
    self.textView.frame = frame;
    
        // Create a array of attachment images to display.
    NSMutableArray *attachmentImages = [NSMutableArray arrayWithArray:self.images];
    for (NSInteger index = 0; index < [self.urls count]; index++) {
        [attachmentImages addObject:[UIImage imageNamed:@"FBComposeView.bundle/DEFacebookURLAttachment"]];
    }
    
    self.paperClipView.hidden = YES;
    self.attachment1FrameView.hidden = YES;
    self.attachment2FrameView.hidden = YES;
    self.attachment3FrameView.hidden = YES;
    
    if ([attachmentImages count] >= 1) {
        self.paperClipView.hidden = NO;
        self.attachment1FrameView.hidden = NO;
        self.attachment1ImageView.image = [attachmentImages objectAtIndex:0];
        
        if ([attachmentImages count] >= 2) {
            self.paperClipView.hidden = NO;
            self.attachment2FrameView.hidden = NO;
            self.attachment2ImageView.image = [attachmentImages objectAtIndex:1];
            
            if ([attachmentImages count] >= 3) {
                self.paperClipView.hidden = NO;
                self.attachment3FrameView.hidden = NO;
                self.attachment3ImageView.image = [attachmentImages objectAtIndex:2];
            }
        }
    }
}




#pragma mark - Actions

- (IBAction)send {
    if (![FBSession.activeSession isOpen]) {
        [FBSession openActiveSessionWithPublishPermissions:[NSArray arrayWithObjects:@"publish_actions", nil]//[NSArray arrayWithObjects: @"read_stream", @"publish_actions", @"publish_stream", nil]
                                           defaultAudience:FBSessionDefaultAudienceFriends
                                              allowLoginUI:YES
                                         completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
                                             if (error) {
                                                 DebugLog(@"error:%@, %@", error, [error userInfo]);
                                                 return;
                                             } else {
                                                 [FBSession setActiveSession:session];
                                                 [self.sendButton setTitle:@"Post" forState:UIControlStateNormal];
                                             }
                                         }];
        return;
    }
    
    
    self.sendButton.enabled = NO;
        
    UIActivityIndicatorView *activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [activity setCenter:CGPointMake(_sendButton.frame.size.width/2, _sendButton.frame.size.height/2)];
    [_sendButton setTitle:@"" forState:UIControlStateNormal];
    [_sendButton addSubview:activity];
    [activity startAnimating];
    self.view.userInteractionEnabled = NO;
    
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObject:self.textView.text forKey:@"message"];
    
    NSString *graphPath = @"me/feed";
    
    
    
    if ([self.urls count] > 0) {
        [d setObject:[self.urls lastObject] forKey:@"link"];
    }
    
    if ([self.images count] > 0) {
        [d setObject:UIImagePNGRepresentation([self.images lastObject]) forKey:@"source"];
        graphPath = @"me/photos";
    }

    // create the connection object
    FBRequestConnection *newConnection = [[FBRequestConnection alloc] init];
    FBRequest *request = [[FBRequest alloc] initWithSession:FBSession.activeSession
                                                  graphPath:graphPath
                                                 parameters:([self.params allKeys].count > 0) ? self.params : d
                                                 HTTPMethod:@"POST"];
    
    [newConnection addRequest:request completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        if (error) {
            DebugLog(@"error:%@, %@", error, [error userInfo]);
            
            // remove activity
            [[[self.sendButton subviews] lastObject] removeFromSuperview];
            [self.sendButton setTitle:@"Post" forState:UIControlStateNormal];
            self.view.userInteractionEnabled = YES;
            
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot Send Message", @"")
                                                                 message:[NSString stringWithFormat:NSLocalizedString(@"The message, \"%@\" cannot be sent because the connection to Facebook failed.", @""), self.textView.text]
                                                                delegate:self
                                                       cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                                       otherButtonTitles:NSLocalizedString(@"Try Again", @""), nil];
            alertView.tag = DEFacebookComposeViewControllerCannotSendAlert;
            [alertView show];
            
            self.sendButton.enabled = YES;
        } else {
            CGFloat yOffset = -(self.view.bounds.size.height + CGRectGetMaxY(self.cardView.frame) + 10.0f);
            
            [UIView animateWithDuration:0.35f
                             animations:^ {
                                 self.cardView.frame = CGRectOffset(self.cardView.frame, 0.0f, yOffset);
                                 self.paperClipView.frame = CGRectOffset(self.paperClipView.frame, 0.0f, yOffset);
                             }];
            
            
            if (self.completionHandler) {
                self.completionHandler(DEFacebookComposeViewControllerResultDone);
            }
            else {
                [self dismissViewControllerAnimated:YES completion:nil];
            }
            DebugLog(@"ok");
        };
    }];
    
    [newConnection start];
}


- (IBAction)cancel
{
    if (self.completionHandler) {
        self.completionHandler(DEFacebookComposeViewControllerResultCancelled);
    }
    else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}


#pragma mark - UIAlertViewDelegate

+ (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
    // Notice this is a class method since we're displaying the alert from a class method.
{
    // no op
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
    // This gets called if there's an error sending the tweet.
{
    if (alertView.tag == DEFacebookComposeViewControllerNoAccountsAlert) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    else if (alertView.tag == DEFacebookComposeViewControllerCannotSendAlert) {
        if (buttonIndex == 1) {
                // The user wants to try again.
            [self send];
        }
    }
}


@end
