//
//  BrynstagramRecordingViewController.m
//  Brynstagram
//
//  Created by bryn austin bellomy on 6/20/12.
//  Copyright (c) 2012 robot bubble bath LLC. All rights reserved.
//

#import <CoreMotion/CoreMotion.h>
#import <MBProgressHUD/MBProgressHUD.h>
#import <BrynKit/Bryn.h>
#import <GPUImage/GPUImage.h>

#import "BrynstagramRecordingViewController.h"
#import "BrynstagramRecordingViewController-Private.h"
#import "BrynstagramAccelerometerFilter.h"
#import "BrynstagramGPUImageAlphaBlendFilter.h"
#import "BrynstagramAppDelegate.h"
#import "BrynstagramFilter.h"
#import "SEAnimatedPicture.h"
#import "BrynstagramAnimatedObject.h"


@interface BrynstagramRecordingViewController ()

@property (nonatomic, strong, readwrite) id handle_appWillResignActiveNotification;
@property (nonatomic, strong, readwrite) id handle_appWillEnterForegroundNotification;
@property (nonatomic, assign, readwrite) BrynstagramFilterGraphStatus status;

@property (readwrite, strong, nonatomic) NSString *pathToSavedMovie;
@property (nonatomic, assign, readwrite) CGSize characterImageSize;
@property (nonatomic, strong, readwrite) CMMotionManager *motionManager;
@property (atomic,    assign, readwrite) CGAffineTransform characterPan;
@property (atomic,    assign, readwrite) CGFloat characterScale;
@property (atomic,    assign, readwrite) CGFloat characterRotation;
@property (nonatomic, strong, readwrite) BrynstagramAccelerometerLowpassFilter *accelerometerFilter;
@property (nonatomic, assign, readwrite) DispatchSourceState characterTransform_eventEmitterState;
@property (nonatomic, assign, readwrite) dispatch_source_t characterTransform_eventEmitter;
@property (nonatomic, assign, readwrite) dispatch_queue_t characterTransform_queue;
@property (nonatomic, weak,   readwrite) UIPanGestureRecognizer *panGestureRecognizer;
@property (nonatomic, weak,   readwrite) UIPinchGestureRecognizer *pinchGestureRecognizer;

@property (nonatomic, weak,   readwrite) IBOutlet GPUImageView *gpuImageView;

// user-chosen filter
@property (nonatomic, strong, readwrite) GPUImageOutput<GPUImageInput> *filter;
@property (nonatomic, assign, readwrite) BrynstagramFilterType filterType;

// always-on filters
@property (nonatomic, strong, readwrite) GPUImageAlphaBlendFilter *blendFilter;
@property (nonatomic, strong, readwrite) GPUImageTransformFilter *transformFilterCharacter;
//@property (nonatomic, strong, readwrite) BrynstagramGPUImageAnimatedPicture *animatedPicture;
//@property (nonatomic, strong, readwrite) SEAnimatedPicture *animatedPicture;

// openGL shader pipeline
@property (nonatomic, strong, readwrite) GPUImageVideoCamera *videoCamera;
@property (nonatomic, strong, readwrite) GPUImagePicture *sourcePicture;
@property (nonatomic, strong, readwrite) GPUImageMovieWriter *movieWriter;
@property (nonatomic, strong, readwrite) GPUImageFilterPipeline *pipeline;

@end




@implementation BrynstagramRecordingViewController

@dynamic characterPan, characterScale, characterRotation;
@dynamic cameraPosition;

static NSMutableDictionary *preloadedAnimatedObjects = nil;



/**
 * #### beginLoadingAnimatedObject:retrievalKey:
 *
 * method description
 *
 * @param {id<BrynstagramAnimatedObject>} object The object containing the information required to load the desired animation frames.
 * @param {id} key The key to use to retrieve the object later, once it has loaded.
 * @return {void}
 */

/**!
 * #### beginLoadingAnimatedObject:retrievalKey:
 * 
 * @param {id<BrynstagramAnimatedObject>} object
 * @param {id} key
 * 
 * @return {void}
 */

+ (void) beginLoadingAnimatedObject:(id<BrynstagramAnimatedObject>)object retrievalKey:(id)key {
  
  
  NSAssert([(NSString *)key isEqualToString:@"catshmorder"], COLOR_ERROR(@"WELL FUCK ALL"));
  
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    preloadedAnimatedObjects = [NSMutableDictionary dictionary];
  });
  
  //  [SEAnimatedPicture animatedObjectOutputWithAnimatedObject:object];
//  SEAnimatedPicture *p = [[SEAnimatedPicture alloc] initWithAnimatedObject:object];
  preloadedAnimatedObjects[key] = [SEAnimatedPicture animatedObjectOutputWithAnimatedObject:object];
  
  
}



/**
 * #### getPreloadedAnimatedObject:
 *
 * method description
 *
 * @param {id} key The key under which the animated object was originally stored.
 * @return {SEAnimatedPicture*}
 */

/**!
 * #### getPreloadedAnimatedObject:
 * 
 * @param {id} key
 * 
 * @return {SEAnimatedPicture*}
 */

+ (SEAnimatedPicture *) getPreloadedAnimatedObject:(id)key {
  
  
  
  NSAssert([(NSString *)key isEqualToString:@"catshmorder"], COLOR_ERROR(@"WELL FUCK ALL"));
  
  return preloadedAnimatedObjects[key];
}



/**
 * #### releasePreloadedAnimatedObject:
 *
 * method description
 *
 * @param {id} key The key under which the animated object was originally stored.
 * @return {SEAnimatedPicture*}
 */
/**!
 * #### releasePreloadedAnimatedObject:
 * 
 * @param {id} key
 * 
 * @return {SEAnimatedPicture*}
 */

+ (SEAnimatedPicture *) releasePreloadedAnimatedObject:(id)key {
  
  
  NSAssert([(NSString *)key isEqualToString:@"catshmorder"], COLOR_ERROR(@"WELL FUCK ALL"));
  //  NSAssert(NO, @"don't");
  
  SEAnimatedPicture *theObject = [self getPreloadedAnimatedObject:key];
  [preloadedAnimatedObjects removeObjectForKey:key];
  
  
  
  return theObject;
  //  return nil;
}



#pragma mark- Homeless functions (move to a pragma section)
#pragma mark-

/**
 * #### toggleActiveCamera
 *
 * @return {void}
 */

/**!
 * #### toggleActiveCamera:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) toggleActiveCamera {
  [self.videoCamera rotateCamera];
}



#pragma mark- Initialization and teardown
#pragma mark-

/**
 * #### initWithFilterType:nibName:bundle:
 *
 * The designated initializer.
 *
 * @param {BrynstagramFilterType} filterType The type of video filter to apply to the video output.
 * @param {NSString*} nibName The nib name of the view, which is simply passed to UIView's designated initializer.
 * @param {NSBundle*} bundle The bundle from which to load the nib.
 *
 * @return {id} The initialized object, or nil.
 */

/**!
 * #### initWithFilterType:nibName:bundle:
 * 
 * @param {BrynstagramFilterType} filterType
 * @param {NSString*} nibName
 * @param {NSBundle*} bundle
 * 
 * @return {id}
 */

- (id) initWithFilterType: (BrynstagramFilterType) filterType nibName:(NSString *)nibName bundle:(NSBundle *)bundle {
  
  
  self = [super initWithNibName:nibName bundle:bundle];
  if (self) {
    _status = BrynstagramFilterGraphStatusUnintialized;
    _filterType = filterType;
    _characterPinchMinScale = 0.3f;
    _characterPinchMaxScale = 2.0f;
    _accelerometerUpdateInterval = (1.0f / 30.0f); // 30 fps
    _accelerometerLowpassFilterCutoffFrequency = 0.005f;
  }
  return self;
}



/**
 * #### dealloc
 *
 * @return {void}
 */

/**!
 * #### dealloc:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) dealloc {
  
  
  [self stopObservingBackgroundingNotifications];
  
  _pathToSavedMovie = nil;
  _gpuImageView = nil;
  
  if (UIAccelerometer.sharedAccelerometer.delegate == self)
    UIAccelerometer.sharedAccelerometer.delegate = nil;
}




#pragma mark- View lifecycle
#pragma mark-

/**
 * #### viewDidLoad
 * 
 * @return {void}
 */

/**!
 * #### viewDidLoad:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) viewDidLoad {
  
  
  [super viewDidLoad];
  
  // allocate and initialize and connect all of the filter graph units
  [self initializeFilterGraph];
  
  // allocate and initialize the character transform monitoring apparatus
  [self initializeCharacterTransformMonitor];
}



/**
 * #### viewDidUnload
 * 
 * @return {void}
 */

/**!
 * #### viewDidUnload:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) viewDidUnload {
  
  
  // destroy the character transform monitoring apparatus
  [self destroyCharacterTransformMonitor];
  
  // destroy the filter graph
  [self destroyFilterGraph];
  
  [super viewDidUnload];
}



/**
 * #### viewWillAppear:
 * 
 * @param {BOOL} animated
 * 
 * @return {void}
 */

/**!
 * #### viewWillAppear:
 * 
 * @param {BOOL} animated
 * 
 * @return {void}
 */

- (void) viewWillAppear:(BOOL)animated {
  
  
  [super viewWillAppear:animated];
  
  // listen to "entering background" and "entering foreground" notifications so
  // that we can manage opengl shit the right way
  [self beginObservingAppBackgroundingNotifications];
  
  // set up gesture recognizers for dragging and pinch-scaling the character
  UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget: self
                                                                                         action: @selector(didPerformPanGesture:)];
  UIPinchGestureRecognizer *pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget: self
                                                                                               action: @selector(didPerformPinchGesture:)];
  [self.gpuImageView addGestureRecognizer: panGestureRecognizer];
  [self.gpuImageView addGestureRecognizer: pinchGestureRecognizer];
  self.panGestureRecognizer = panGestureRecognizer;
  self.pinchGestureRecognizer = pinchGestureRecognizer;
}



/**
 * #### viewDidAppear:
 * 
 * @param {BOOL} animated
 * 
 * @return {void}
 */

/**!
 * #### viewDidAppear:
 * 
 * @param {BOOL} animated
 * 
 * @return {void}
 */

- (void) viewDidAppear:(BOOL)animated {
  
  
  [super viewDidAppear:animated];
  
  // start the accelerometer, dispatch timer, and queue to monitor and update character's current transform matrix
  [self startCharacterTransformMonitor];
  
  self.gpuImageView.fillMode = kGPUImageFillModeStretch;
  
  // start pumping frames through the filter graph
  [self startFilterGraph];
  
}



/**
 * #### viewWillDisappear:
 * 
 * @param {BOOL} animated
 * 
 * @return {void}
 */

/**!
 * #### viewWillDisappear:
 * 
 * @param {BOOL} animated
 * 
 * @return {void}
 */

- (void) viewWillDisappear:(BOOL)animated {
  
  
  // remove character's gesture recognizers
  [self.gpuImageView removeGestureRecognizer: self.panGestureRecognizer];
  [self.gpuImageView removeGestureRecognizer: self.pinchGestureRecognizer];
  
  // stop the character transform matrix updates
  [self stopCharacterTransformMonitor];
  
  // @@TODO: stop movie?
  
  // have to stop camera capture before the view goes off the screen in order to prevent a crash from the camera still sending frames
  [self stopFilterGraph];
  
  // unregister for backgrounding/foregrounding notifications
  //[self stopObservingBackgroundingNotifications];
  
  [super viewWillDisappear: animated];
}



// @@TODO: finally actually handle memory warnings based on the NSNotification that gets sent out
// @@TODO: kill the filter graph, black-out the view, and display a message to the user
/**
 * #### didReceiveMemoryWarning:
 * 
 * @return {void}
 */

/**!
 * #### didReceiveMemoryWarning:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) didReceiveMemoryWarning {
  
  
  if (self == nil)
    return;
  
  [super didReceiveMemoryWarning];
  
  //  if (self.appIsBackgrounded == NO) {
  if (appIsBackgrounded() == NO) {
    // @@TODO: stop movie?
    [self stopFilterGraph];
    
    
    [ (BrynstagramAppDelegate *) UIApplication.sharedApplication.delegate
     viewControllerDidHandleLocalMemoryCleanup];
  }
}




#pragma mark- App backgrounding
#pragma mark-

/**
 * #### beginObservingAppBackgroundingNotifications
 *
 * Registers a block to be executed when the app enters the background that
 * attempts to ensure that there are no remaining OpenGL calls waiting to
 * execute (which is not allowed during backgrounding).
 *
 * @return {void}
 */

/**!
 * #### beginObservingAppBackgroundingNotifications:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) beginObservingAppBackgroundingNotifications {
  
  
  
  /* UIApplicationWillResignActive notification handler */
  
  @weakify(self);
  NotificationBlock appWillResignActiveBlock = ^(NSNotification *note) {
    @strongify(self);
    
    // UIApplicationWillResignActive application should stop its animation timer (if any), place itself into a known good state, and then call the glFinish function.
    setAppIsBackgrounded(YES);
    
    switch (self.status) {
      case BrynstagramFilterGraphStatusRecordingMovie:
      case BrynstagramFilterGraphStatusInitializingRecordSession:
        [self stopMovieWriter];
        
        // --- INTENTIONAL FALL THROUGH ---
        
      case BrynstagramFilterGraphStatusSavingMovie:
      case BrynstagramFilterGraphStatusReadyToRecord:
        
        [self stopFilterGraph];
        [self stopCharacterTransformMonitor];
        
        [self destroyMovieWriter];
        [self destroyCharacterTransformMonitor];
        [self destroyFilterGraph];
        
        runSynchronouslyOnVideoProcessingQueue(^{
          glFinish();
        });
        
        // --- INTENTIONAL FALL THROUGH ---
        
      case BrynstagramFilterGraphStatusUnintialized:
      case BrynstagramFilterGraphStatusReadyForThroughput:
        break;
        
      default:
        NSAssert(NO, @"self.status set to unknown value.");
        break;
    }
    
    glFinish();
    
  };
  
  self.handle_appWillResignActiveNotification =
  [NSNotificationCenter.defaultCenter addObserverForName: UIApplicationWillResignActiveNotification
                                                  object: UIApplication.sharedApplication
                                                   queue: NSOperationQueue.mainQueue
                                              usingBlock: appWillResignActiveBlock];
  
  
  
  /* UIApplicationWillEnterForeground notification handler */
  
  NotificationBlock appWillEnterForegroundBlock = ^(NSNotification *note) {
    @strongify(self);
    NSLog(@"bkgnd notification (willEnterForeground)");
    // allocate and initialize and connect all of the filter graph units
    NSLog(@"    bkgnd notification : initializeFilterGraph");
    [self initializeFilterGraph];
    
    // allocate and initialize the character transform monitoring apparatus
    NSLog(@"    bkgnd notification : initializeCharacterTransformMonitor");
    [self initializeCharacterTransformMonitor];
    NSLog(@"/ bkgnd notification");
    
    //    strongSelf.appIsBackgrounded = NO;
    setAppIsBackgrounded(NO);
    
    [self startFilterGraph];
    [self startCharacterTransformMonitor];
  };
  
  self.handle_appWillEnterForegroundNotification =
  [NSNotificationCenter.defaultCenter addObserverForName: UIApplicationWillEnterForegroundNotification
                                                  object: UIApplication.sharedApplication
                                                   queue: NSOperationQueue.mainQueue
                                              usingBlock: appWillEnterForegroundBlock];
  
  
}



/**
 * #### stopObservingBackgroundingNotifications
 *
 * method description
 *
 * @return {void}
 */

/**!
 * #### stopObservingBackgroundingNotifications:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) stopObservingBackgroundingNotifications {
  
  
  if (self.handle_appWillResignActiveNotification != nil) {
    [NSNotificationCenter.defaultCenter removeObserver: self.handle_appWillResignActiveNotification];
    self.handle_appWillResignActiveNotification = nil;
  }
  
  if (self.handle_appWillEnterForegroundNotification != nil) {
    [NSNotificationCenter.defaultCenter removeObserver: self.handle_appWillEnterForegroundNotification];
    self.handle_appWillEnterForegroundNotification = nil;
  }
}




#pragma mark- Character transforms
#pragma mark-

/**
 * #### stopCharacterTransformMonitor
 *
 * Stops the dispatch_source event emitter that listens for any transforms that
 * need to be applied to the animated object.
 *
 * @return {void}
 */

/**!
 * #### stopCharacterTransformMonitor:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) stopCharacterTransformMonitor {
  
  
  [self stopAccelerometer];
  
  if (self.characterTransform_eventEmitterState == DispatchSourceState_Resumed) {
    dispatch_suspend(self.characterTransform_eventEmitter);
    self.characterTransform_eventEmitterState = DispatchSourceState_Suspended;
  }
}



/**
 * #### startCharacterTransformMonitor
 *
 * Starts the dispatch_source event emitter that listens for any transforms that
 * need to be applied to the animated object.
 *
 * @return {void}
 */

/**!
 * #### startCharacterTransformMonitor:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) startCharacterTransformMonitor {
  
  
  if (self.characterTransform_eventEmitterState == DispatchSourceState_Suspended
      || self.characterTransform_eventEmitterState == DispatchSourceState_Canceled) {
    dispatch_resume(self.characterTransform_eventEmitter);
    self.characterTransform_eventEmitterState = DispatchSourceState_Resumed;
  }
  [self startAccelerometer];
}



/**
 * #### initializeCharacterTransformMonitor:
 * 
 * @return {void}
 */

/**!
 * #### initializeCharacterTransformMonitor:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) initializeCharacterTransformMonitor {
  
  
  [self initializeAccelerometer];
  
  self.characterTransform_queue = dispatch_queue_create("com.robotbubblebath.Brynstagram.CharacterTransform", 0);
  self.characterTransform_eventEmitter = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_OR, 0, 0, self.characterTransform_queue);
  self.characterTransform_eventEmitterState = DispatchSourceState_Canceled;
  
  @weakify(self);
  
  /** registration handler (set up) **/
  dispatch_source_set_registration_handler(self.characterTransform_eventEmitter, ^{
    @strongify(self);
    if (self == nil)
      return;
    
    BrynstagramCharacterTransformUpdateDataRef transformDataContext = calloc(1, sizeof(BrynstagramCharacterTransformUpdateData));
    //transformDataContext->incomingRotation = ???
    transformDataContext->currentRotation = 0.0f;
    transformDataContext->incomingPan = CGPointZero;
    transformDataContext->panStartPos = CGAffineTransformIdentity;
    transformDataContext->currentPan = CGAffineTransformIdentity;
    transformDataContext->panGestureRecognizerState = UIGestureRecognizerStatePossible;
    transformDataContext->incomingScale = 1.0f;
    transformDataContext->currentScale = 1.0f;
    dispatch_set_context(self.characterTransform_eventEmitter, transformDataContext);
  });
  
  
  
  __block GPUImageTransformFilter *weakTransformFilter = self.transformFilterCharacter;
  __block BrynstagramAccelerometerLowpassFilter *weakAccelerometerFilter = self.accelerometerFilter;
  
  /** timer handler (block to execute while active) **/
  dispatch_source_set_event_handler(self.characterTransform_eventEmitter, ^{
    @strongify(self);
    if (self == nil)
      return;
    
    BrynstagramCharacterTransformUpdateEvent eventType = dispatch_source_get_data(self.characterTransform_eventEmitter);
    BrynstagramCharacterTransformUpdateDataRef transformData = (BrynstagramCharacterTransformUpdateDataRef) dispatch_get_context(self.characterTransform_eventEmitter);
    if (transformData == NULL) {
      return;
    }
    
    // drag pan handler
    if ((eventType & BrynstagramCharacterTransformUpdateEventPan) != 0) {
      Float32 panGestureTamingFactor = (50.0f * (1.0f / transformData->currentScale));
      
      transformData->currentPan = CGAffineTransformTranslate(transformData->panStartPos,
                                                             transformData->incomingPan.x / panGestureTamingFactor,
                                                             transformData->incomingPan.y / panGestureTamingFactor);
      transformData->currentPan.tx = clamp(transformData->currentPan.tx, -1.0f, 1.0f);
      transformData->currentPan.ty = clamp(transformData->currentPan.ty, -2.0f, 2.0f);
      
      if (transformData->panGestureRecognizerState == UIGestureRecognizerStateEnded) {
        transformData->panStartPos = transformData->currentPan;
      }
    }
    
    
    // pinch scale handler
    else if ((eventType & BrynstagramCharacterTransformUpdateEventScale) != 0) {
#define scaledIncomingScale (Float32)(quake3FastSqrt(transformData->incomingScale))
#define newScale            (Float32)(transformData->currentScale * scaledIncomingScale)
      
      transformData->currentScale = clamp(newScale,
                                          self.characterPinchMinScale,
                                          self.characterPinchMaxScale);
    }
    
    
    // accelerometer rotation handler
    else if ((eventType & BrynstagramCharacterTransformUpdateEventRotation) != 0) {
      [weakAccelerometerFilter addAcceleration: transformData->incomingRotation];
      Float64 z = atan2(weakAccelerometerFilter.x, weakAccelerometerFilter.y) + M_PI;
      transformData->currentRotation = z;
    }
    
    CATransform3D rotate, pan, scale;
    rotate = CATransform3DMakeRotation(transformData->currentRotation, 0.0f, 0.0f, 1.0f);
    pan = CATransform3DMakeAffineTransform(transformData->currentPan);
    scale = CATransform3DMakeScale(transformData->currentScale, transformData->currentScale, 0.0f);
    
    // compile the full transform
    [weakTransformFilter setTransform3D: CATransform3DConcat(CATransform3DConcat(rotate, scale), pan)];
  });
  
  dispatch_set_finalizer_f(self.characterTransform_eventEmitter, &characterTransform_eventEmitterFinalizerFn);
  
  /* cancellation handler to free the memory used by the transformData struct */
  //  dispatch_source_set_cancel_handler(self.characterTransform_eventEmitter, ^{
  //    @strongify(self);
  //    if (self == nil)
  //      return;
  //    
  //    BrynstagramCharacterTransformUpdateDataRef transformData = (BrynstagramCharacterTransformUpdateDataRef) dispatch_get_context(self.characterTransform_eventEmitter);
  //    if (transformData != NULL) {
  //      free(transformData);
  //      transformData = NULL;
  //    }
  //    dispatch_set_context(self.characterTransform_eventEmitter, NULL);
  //  });
  
}


void characterTransform_eventEmitterFinalizerFn(void *context) {
  
  
  BrynstagramCharacterTransformUpdateDataRef transformData = (BrynstagramCharacterTransformUpdateDataRef)context;
  
  if (transformData != NULL) {
    free(transformData);
    transformData = NULL;
  }
}



/**
 * #### destroyCharacterTransformMonitor:
 * 
 * @param {}
 * 
 * @return {void}
 */

/**!
 * #### destroyCharacterTransformMonitor:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) destroyCharacterTransformMonitor {
  
  
  [self destroyAccelerometer];
  
  if (self.characterTransform_eventEmitterState == DispatchSourceState_Canceled) {
    self.characterTransform_eventEmitter = nil;
    self.characterTransform_queue = nil;
    return;
  }
  
  if (self.characterTransform_eventEmitter != nil) {
    @synchronized (self) {      
      @weakify(self);
      
      dispatch_sync(self.characterTransform_queue, ^{
        @strongify(self);
        
        // when cancelling, must make sure we resume first if we're suspended  
        if (self.characterTransform_eventEmitterState == DispatchSourceState_Suspended)
          dispatch_resume(self.characterTransform_eventEmitter);
        
        dispatch_source_cancel(self.characterTransform_eventEmitter);
        dispatch_release(self.characterTransform_eventEmitter);
        
        self.characterTransform_eventEmitterState = DispatchSourceState_Canceled;
        self.characterTransform_eventEmitter = nil;
      });
    }
  }
  
  if (self.characterTransform_queue != nil) {
    dispatch_release(self.characterTransform_queue);
    self.characterTransform_queue = nil;
  }
}



/**
 * #### initializeAccelerometer:
 * 
 * @return {void}
 */

/**!
 * #### initializeAccelerometer:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) initializeAccelerometer {
  
  
  self.motionManager = $new(CMMotionManager);
  self.motionManager.accelerometerUpdateInterval = self.accelerometerUpdateInterval;
  
  // inititalize the accelerometer
  self.accelerometerFilter = [[BrynstagramAccelerometerLowpassFilter alloc] initWithSampleRate:self.accelerometerUpdateInterval
                                                                               cutoffFrequency: self.accelerometerLowpassFilterCutoffFrequency];
}



/**
 * #### destroyAccelerometer:
 * 
 * @return {void}
 */

/**!
 * #### destroyAccelerometer:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) destroyAccelerometer {
  
  
  self.motionManager = nil;
  self.accelerometerFilter = nil;
}



/**
 * #### startAccelerometer:
 * 
 * @return {void}
 */

/**!
 * #### startAccelerometer:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) startAccelerometer {
  
  
  @weakify(self);
  
  // handler block for acceleration data
  void (^accelerometerDataHandler)(CMAccelerometerData *, NSError *) = ^(CMAccelerometerData *accelerometerData, NSError *error) {
    @strongify(self);
    if (appIsBackgrounded() == NO && error == nil && self.characterTransform_eventEmitter != NULL) {
      BrynstagramCharacterTransformUpdateDataRef transformData = (BrynstagramCharacterTransformUpdateDataRef) dispatch_get_context(self.characterTransform_eventEmitter);
      if (transformData != NULL) {
        transformData->incomingRotation = accelerometerData.acceleration;
        dispatch_source_merge_data(self.characterTransform_eventEmitter, BrynstagramCharacterTransformUpdateEventRotation);
      }
    }
  };
  
  [self.motionManager startAccelerometerUpdatesToQueue: [NSOperationQueue mainQueue]
                                           withHandler: accelerometerDataHandler];
}



/**
 * #### stopAccelerometer:
 * 
 * @return {void}
 */

/**!
 * #### stopAccelerometer:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) stopAccelerometer {
  
  
  [self.motionManager stopAccelerometerUpdates];
}



/**
 * #### didPerformPanGesture:
 * 
 * @param {UIPanGestureRecognizer*} recognizer
 * 
 * @return {void}
 */

/**!
 * #### didPerformPanGesture:
 * 
 * @param {UIPanGestureRecognizer*} recognizer
 * 
 * @return {void}
 */

- (void) didPerformPanGesture: (UIPanGestureRecognizer *)recognizer {
  
  
  CGPoint translateCoords = [recognizer translationInView: self.gpuImageView];
  
  BrynstagramCharacterTransformUpdateDataRef transformData = (BrynstagramCharacterTransformUpdateDataRef) dispatch_get_context(self.characterTransform_eventEmitter);
  transformData->incomingPan = translateCoords;
  transformData->panGestureRecognizerState = recognizer.state;
  dispatch_source_merge_data(self.characterTransform_eventEmitter, BrynstagramCharacterTransformUpdateEventPan);
}


/**
 * #### didPerformPinchGesture:
 * 
 * @param {UIPinchGestureRecognizer*} recognizer
 * 
 * @return {void}
 */

/**!
 * #### didPerformPinchGesture:
 * 
 * @param {UIPinchGestureRecognizer*} recognizer
 * 
 * @return {void}
 */

- (void) didPerformPinchGesture: (UIPinchGestureRecognizer *)recognizer {
  
  
  BrynstagramCharacterTransformUpdateDataRef transformData = (BrynstagramCharacterTransformUpdateDataRef) dispatch_get_context(self.characterTransform_eventEmitter);
  transformData->incomingScale = recognizer.scale;
  dispatch_source_merge_data(self.characterTransform_eventEmitter, BrynstagramCharacterTransformUpdateEventScale);
}




/**
 * #### initializeFilterGraph:
 *
 * alloc/inits all of the filters in the chain (except for the movie writer) and
 * connects them all together
 *
 * ```
 * requires status:   Uninitialized
 * results in status: Ready for Throughput
 * ```
 * 
 * @return {void}
 */

/**!
 * #### initializeFilterGraph:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) initializeFilterGraph {
  
  
  CGRect frame = CGRectZero;
  frame.size = self.characterImageSize;
  
  //  self.animatedPicture = [BrynstagramRecordingViewController releasePreloadedAnimatedObject: @"catshmorder"];
  //  NSAssert(self.animatedPicture != nil, @"self.animatedPicture is nil.");
  
  // bail if the graph is already initialized
  if (self.status != BrynstagramFilterGraphStatusUnintialized && appIsBackgrounded() == NO) {
    return;
  }
  
  self.videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset: AVCaptureSessionPreset640x480
                                                         cameraPosition: AVCaptureDevicePositionBack];
  NSAssert(self.videoCamera != nil, @"self.videoCamera is nil.");
  
  self.videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
  
#include "BrynstagramRecordingViewController-filter-switch.h"
  // setup our always-on filters (character gravity rotation, alpha blend)
  self.transformFilterCharacter = $new(GPUImageTransformFilter);  NSAssert(self.transformFilterCharacter != nil, @"self.transformFilterCharacter is nil.");
  self.blendFilter = $new(GPUImageAlphaBlendFilter);              NSAssert(self.blendFilter != nil, @"self.blendFilter is nil.");
  
  [self.videoCamera              addTarget: self.blendFilter];
  [[BrynstagramRecordingViewController getPreloadedAnimatedObject: @"catshmorder"] addTarget: self.transformFilterCharacter];
  [self.transformFilterCharacter addTarget: self.blendFilter];
  
  //  self.transformFilterCharacter.targetToIgnoreForUpdates = self.blendFilter; // avoid double-updating the blend
  
  [self.blendFilter addTarget: self.filter];
  [self.filter      addTarget: self.gpuImageView];
  
  self.blendFilter.mix = 1.0f;
  
  self.status = BrynstagramFilterGraphStatusReadyForThroughput;
}



/**
 * #### destroyFilterGraph:
 *
 * unhooks and destroys all of the filters in the chain (except for the movie
 * writer)
 *
 * requires status:   Ready for Throughput (stopped)
 * results in status: Uninitialized
 * 
 * @return {void}
 */

/**!
 * #### destroyFilterGraph:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) destroyFilterGraph {
  
  
  // bail if the graph is not in the Stopped/Ready for Throughput state
  if (self.status != BrynstagramFilterGraphStatusReadyForThroughput) {
    
    return;
  }
  
  [self.videoCamera removeAllTargets];
  [self.transformFilterCharacter removeAllTargets];
  [self.blendFilter removeAllTargets];
  //  [self.animatedPicture removeAllTargets];
  [[BrynstagramRecordingViewController getPreloadedAnimatedObject:@"catshmorder"] removeAllTargets];
  
  [self.filter removeAllTargets];
  
  self.videoCamera = nil;
  self.transformFilterCharacter = nil;
  self.blendFilter = nil;
  self.filter = nil;
  
  //preloadedAnimatedObjects[@"catshmorder"] = self.animatedPicture;
  //  self.animatedPicture = nil;
  
  self.status = BrynstagramFilterGraphStatusUnintialized;
}




/**
 * #### initializeMovieWriter:
 * 
 * @return {void}
 */

/**!
 * #### initializeMovieWriter:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) initializeMovieWriter {
  
  
  // set up the movie file and movie writer
  self.pathToSavedMovie = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.m4v"];
  unlink([self.pathToSavedMovie UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
  
  self.movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL: [NSURL fileURLWithPath: self.pathToSavedMovie]
                                                              size: CGSizeMake(480.0, 640.0)];
  NSAssert(self.movieWriter != nil, @"self.movieWriter == nil");
  self.movieWriter.delegate = self;
  
  // set up audio capture
  self.movieWriter.shouldPassthroughAudio = NO;
  self.videoCamera.audioEncodingTarget = self.movieWriter;
}



/**
 * #### destroyMovieWriter:
 * 
 * @return {void}
 */

/**!
 * #### destroyMovieWriter:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) destroyMovieWriter {
  
  
  self.videoCamera.audioEncodingTarget = nil;
  self.movieWriter = nil;
}



/**
 * #### startFilterGraph:
 *
 * essentially, this calls:
 *  - videoCamera -> startCameraCapture
 *  - animatedPicture -> play
 *
 * requires status:   Ready for Throughput
 * results in status: Ready to Record (and is currently playing)
 * 
 * @return {void}
 */

/**!
 * #### startFilterGraph:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) startFilterGraph {
  
  
  // bail if the graph isn't ready to start
  if (self.status != BrynstagramFilterGraphStatusReadyForThroughput) return;
  
  // start the camera
  [self.videoCamera startCameraCapture];
  
  // try to start animating character
  [[BrynstagramRecordingViewController getPreloadedAnimatedObject:@"catshmorder"] play];
  //  [self.animatedPicture play];
  
  self.status = BrynstagramFilterGraphStatusReadyToRecord;
}


/**
 * #### stopFilterGraph:
 *
 * essentially, this calls:
 *  - animatedPicture -> pause
 *  - videoCamera -> stopCameraCapture
 *
 * requires status:   Ready to Record (playing)  ~OR~
 *                    Recording Movie
 * results in status: Ready for Throughput
 * 
 * @return {void}
 */

/**!
 * #### stopFilterGraph:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) stopFilterGraph {
  
  
  // bail if we're not either playing or recording
  if (self.status != BrynstagramFilterGraphStatusReadyToRecord &&
      self.status != BrynstagramFilterGraphStatusRecordingMovie &&
      self.status != BrynstagramFilterGraphStatusInitializingRecordSession) {
    
    NSLog(COLOR_RED @"REFUSING TO stopFilterGraph (%u)" XCODE_COLORS_RESET, self.status);
    return;
  }
  
  // kill the sources
  [[BrynstagramRecordingViewController getPreloadedAnimatedObject:@"catshmorder"] pause];
  //  [self.animatedPicture pause];
  [self.videoCamera stopCameraCapture];
  // @@TODO: try uncommenting this:
  //self.videoCamera.audioEncodingTarget = nil;
  
  // ready to start up the graph again
  self.status = BrynstagramFilterGraphStatusReadyForThroughput;
}



/**
 * #### startMovieWriter:
 *
 * requires status:   Ready to Record (and is currently playing)
 * results in status: Recording Movie
 * 
 * @return {void}
 */

/**!
 * #### startMovieWriter:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) startMovieWriter {
  
  
  // bail if the graph isn't ready to record
  NSAssert(self.status == BrynstagramFilterGraphStatusReadyToRecord, @"Movie writer not ready to record");
  if (self.status != BrynstagramFilterGraphStatusReadyToRecord) return;
  
  // set limbo state while we initialize
  self.status = BrynstagramFilterGraphStatusInitializingRecordSession;
  
  // stop the graph so we can hook up the movie writer
  [self stopFilterGraph];
  
  // hook into the filter graph
  [self.filter addTarget: self.movieWriter];
  
  // go go go
  self.status = BrynstagramFilterGraphStatusReadyForThroughput;
  [self startFilterGraph];
  [self.movieWriter startRecording];
  self.status = BrynstagramFilterGraphStatusRecordingMovie;
}


/**
 * #### stopMovieWriter:
 *
 * requires status:   Recording Movie
 * results in status: Ready to Record (and is playing) ... [actually none
 *     immediately, but once the video save callback returns, we're there]
 * 
 * @return {void}
 */

/**!
 * #### stopMovieWriter:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) stopMovieWriter {
  
  
  if (self.status != BrynstagramFilterGraphStatusRecordingMovie) {
    
    return;
  }
  
  self.status = BrynstagramFilterGraphStatusSavingMovie;
  
  @weakify(self);
  
  // display the "saving..." hud
  BrynShowMBProgressHUD(self.gpuImageView, ^(MBProgressHUD *hud) {
    hud.animationType = MBProgressHUDAnimationZoom;
    hud.mode = MBProgressHUDModeIndeterminate;
    hud.dimBackground = YES;
    hud.labelText = @"Saving video...";
    hud.minShowTime = 3.0f;
  }, ^{
    @strongify(self);
    
    // disconnect the movie writer from the filter graph (this effectively stops it)
    [self.filter removeTarget: self.movieWriter];
    
    // polish up the recorded file
    [self.movieWriter finishRecording];
    
    // move the saved movie file into the camera roll
    UISaveVideoAtPathToSavedPhotosAlbum(self.pathToSavedMovie,
                                        self,
                                        @selector(video:didFinishSavingToCameraRollWithError:contextInfo:),
                                        nil);
  });
}


/**
 * #### video:didFinishSavingToCameraRollWithError:
 * 
 * (see above, at -stopMovieWriter)
 *
 * @param {NSString*} videoPath
 * @param  {NSError*} error
 * @param     {void*} contextInfo
 * 
 * @return {void}
 */

/**!
 * #### video:didFinishSavingToCameraRollWithError:contextInfo:
 * 
 * @param {NSString*} videoPath
 * @param {NSError*} error
 * @param {void*} contextInfo
 * 
 * @return {void}
 */

- (void)                         video: (NSString *) videoPath
  didFinishSavingToCameraRollWithError: (NSError *) error
                           contextInfo: (void *) contextInfo {
  
  
  @weakify(self);
  dispatch_async(dispatch_get_main_queue(), ^{
    @strongify(self);
    
    if (self.gpuImageView == nil)
      return;
    
    // remove the "saving..." hud
    MBProgressHUD *hud = [MBProgressHUD HUDForView: self.gpuImageView];
    [hud hide: NO];
  });
  
  
  // show the save result hud
  BrynShowMBProgressHUD(
                        self.gpuImageView,
                        
                        ^(MBProgressHUD *hud) {
                          if (error == nil)
                            hud.labelText = @"Saved to camera roll!";
                          else {
                            BrynFnLog(COLOR_ERROR(@"Error saving video to camera roll: %@"), error);
                            hud.labelText = @"Error saving video to camera roll.";
                          }
                          
                          hud.dimBackground = YES;
                          hud.animationType = MBProgressHUDAnimationZoom;
                          hud.mode = MBProgressHUDModeText;
                          hud.minShowTime = 1.5f;
                          [hud hide: YES afterDelay: 1.5f];
                        },
                        
                        ^(void) {
                          @strongify(self);
                          
                          // if a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
                          unlink([self.pathToSavedMovie UTF8String]);
                          
                          // graph has throughput and is ready to record again
                          self.status = BrynstagramFilterGraphStatusReadyToRecord;
                        });
}





#pragma mark- Saving movie file to camera roll
#pragma mark-

/**
 * #### movieRecordingFailedWithError:
 * 
 * @param {NSError*} error
 * 
 * @return {void}
 */

/**!
 * #### movieRecordingFailedWithError:
 * 
 * @param {NSError*} error
 * 
 * @return {void}
 */

- (void) movieRecordingFailedWithError:(NSError *)error {
  
  
  // @@TODO: finish this!  implement delegate and see if error comes out
  NSLog(@"movie failedddd %@", error);
}

/**
 * #### movieRecordingCompleted:
 * 
 * @return {void}
 */

/**!
 * #### movieRecordingCompleted:
 * 
 * @param {}
 * 
 * @return {void}
 */

- (void) movieRecordingCompleted {
  
  
  NSLog(@"movie completed");
}





#pragma mark- Homeless
#pragma mark-



/**
 * #### cameraPosition:
 * 
 * @return {AVCaptureDevicePosition}
 */

/**!
 * #### cameraPosition:
 * 
 * @param {}
 * 
 * @return {AVCaptureDevicePosition}
 */

- (AVCaptureDevicePosition) cameraPosition {
  
  
  return self.videoCamera.cameraPosition;
}

/**
 * #### setFilterIntensity:
 * 
 * @param {Float64} intensity
 * 
 * @return {void}
 */

/**!
 * #### setFilterIntensity:
 * 
 * @param {Float64} intensity
 * 
 * @return {void}
 */

- (void) setFilterIntensity:(Float64)intensity {
  
  
  switch (self.filterType)
  {
    case BrynstagramFilter_MOSAIC:  [(GPUImageMosaicFilter *)self.filter setDisplayTileSize:CGSizeMake(intensity, intensity)]; break;
    case BrynstagramFilter_SEPIA: [(GPUImageSepiaFilter *)self.filter setIntensity:intensity]; break;
    case BrynstagramFilter_PIXELLATE: [(GPUImagePixellateFilter *)self.filter setFractionalWidthOfAPixel:intensity]; break;
    case BrynstagramFilter_POLARPIXELLATE: [(GPUImagePolarPixellateFilter *)self.filter setPixelSize:CGSizeMake(intensity, intensity)]; break;
    case BrynstagramFilter_SATURATION: [(GPUImageSaturationFilter *)self.filter setSaturation:intensity]; break;
    case BrynstagramFilter_CONTRAST: [(GPUImageContrastFilter *)self.filter setContrast:intensity]; break;
    case BrynstagramFilter_BRIGHTNESS: [(GPUImageBrightnessFilter *)self.filter setBrightness:intensity]; break;
    case BrynstagramFilter_EXPOSURE: [(GPUImageExposureFilter *)self.filter setExposure:intensity]; break;
    case BrynstagramFilter_RGB: [(GPUImageRGBFilter *)self.filter setGreen:intensity]; break;
    case BrynstagramFilter_SHARPEN: [(GPUImageSharpenFilter *)self.filter setSharpness:intensity]; break;
    case BrynstagramFilter_HISTOGRAM: [(GPUImageHistogramFilter *)self.filter setDownsamplingFactor:round(intensity)]; break;
    case BrynstagramFilter_UNSHARPMASK: [(GPUImageUnsharpMaskFilter *)self.filter setIntensity:intensity]; break;
    case BrynstagramFilter_GAMMA: [(GPUImageGammaFilter *)self.filter setGamma:intensity]; break;
    case BrynstagramFilter_CROSSHATCH: [(GPUImageCrosshatchFilter *)self.filter setCrossHatchSpacing:intensity]; break;
    case BrynstagramFilter_POSTERIZE: [(GPUImagePosterizeFilter *)self.filter setColorLevels:round(intensity)]; break;
    case BrynstagramFilter_HAZE: [(GPUImageHazeFilter *)self.filter setDistance:intensity]; break;
    case BrynstagramFilter_THRESHOLD: [(GPUImageLuminanceThresholdFilter *)self.filter setThreshold:intensity]; break;
    case BrynstagramFilter_DISSOLVE: [(GPUImageDissolveBlendFilter *)self.filter setMix:intensity]; break;
    case BrynstagramFilter_CHROMAKEY: [(GPUImageChromaKeyBlendFilter *)self.filter setThresholdSensitivity:intensity]; break;
    case BrynstagramFilter_KUWAHARA: [(GPUImageKuwaharaFilter *)self.filter setRadius:round(intensity)]; break;
    case BrynstagramFilter_SWIRL: [(GPUImageSwirlFilter *)self.filter setAngle:intensity]; break;
    case BrynstagramFilter_EMBOSS: [(GPUImageEmbossFilter *)self.filter setIntensity:intensity]; break;
    case BrynstagramFilter_CANNYEDGEDETECTION: [(GPUImageCannyEdgeDetectionFilter *)self.filter setBlurSize:intensity]; break;
    case BrynstagramFilter_SMOOTHTOON: [(GPUImageSmoothToonFilter *)self.filter setBlurSize:intensity]; break;
    case BrynstagramFilter_BULGE: [(GPUImageBulgeDistortionFilter *)self.filter setScale:intensity]; break;
    case BrynstagramFilter_PINCH: [(GPUImagePinchDistortionFilter *)self.filter setScale:intensity]; break;
    case BrynstagramFilter_VIGNETTE: [(GPUImageVignetteFilter *)self.filter setVignetteEnd:intensity]; break;
    case BrynstagramFilter_GAUSSIAN: [(GPUImageGaussianBlurFilter *)self.filter setBlurSize:intensity]; break;
    case BrynstagramFilter_BILATERAL: [(GPUImageBilateralFilter *)self.filter setBlurSize:intensity]; break;
    case BrynstagramFilter_FASTBLUR: [(GPUImageFastBlurFilter *)self.filter setBlurPasses:round(intensity)]; break;
    case BrynstagramFilter_GAUSSIAN_SELECTIVE: [(GPUImageGaussianSelectiveBlurFilter *)self.filter setExcludeCircleRadius:intensity]; break;
    case BrynstagramFilter_FILTERGROUP: [(GPUImagePixellateFilter *)[(GPUImageFilterGroup *)self.filter filterAtIndex:1] setFractionalWidthOfAPixel:intensity]; break;
    case BrynstagramFilter_CROP: [(GPUImageCropFilter *)self.filter setCropRegion:CGRectMake(0.0, 0.0, 1.0, intensity)]; break;
    case BrynstagramFilter_TRANSFORM: [(GPUImageTransformFilter *)self.filter setAffineTransform:CGAffineTransformMakeRotation(intensity)]; break;
    case BrynstagramFilter_TRANSFORM3D:
    {
      CATransform3D perspectiveTransform = CATransform3DIdentity;
      perspectiveTransform.m34 = 0.4;
      perspectiveTransform.m33 = 0.4;
      perspectiveTransform = CATransform3DScale(perspectiveTransform, 0.75, 0.75, 0.75);
      perspectiveTransform = CATransform3DRotate(perspectiveTransform, intensity, 0.0, 1.0, 0.0);
      
      [(GPUImageTransformFilter *)self.filter setTransform3D:perspectiveTransform];            
    }; break;
    case BrynstagramFilter_TILTSHIFT:
    {
      CGFloat midpoint = intensity;
      [(GPUImageTiltShiftFilter *)self.filter setTopFocusLevel:midpoint - 0.1];
      [(GPUImageTiltShiftFilter *)self.filter setBottomFocusLevel:midpoint + 0.1];
    }; break;
    default: break;
  }
}




@end


