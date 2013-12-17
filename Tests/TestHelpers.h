
#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestingKit.h>
#import <Kiwi.h>

#define raiseShouldNotReachHere() @throw [NSException exceptionWithName:NSGenericException reason:[NSString stringWithFormat:@"Should not reach here: %s:%d, %s", __FILE__, __LINE__, __PRETTY_FUNCTION__] userInfo:nil]


typedef void (^asyncronousBlock)(void);


static inline dispatch_queue_t currentQueue() {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    dispatch_queue_t currentQueue = dispatch_get_current_queue();
#pragma clang diagnostic pop

    return currentQueue;
}

static inline dispatch_queue_t serialQueue() {
    static dispatch_queue_t _serialQueue = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        _serialQueue = dispatch_queue_create("com.CompositeOperations.Tests.queue.serial", DISPATCH_QUEUE_SERIAL);
    });

    return _serialQueue;
}

static inline dispatch_queue_t concurrentQueue() {
    static dispatch_queue_t _concurrentQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    });

    return _concurrentQueue;
}

static inline dispatch_queue_t createQueue() {
    return dispatch_queue_create("com.CompositeOperations.Tests.queue.serial.random", NULL);
}

static inline void asynchronousJob(asyncronousBlock block) {
    dispatch_queue_t queue = createQueue();

    dispatch_async(queue, block);
}

@interface SenTestCase (Helpers)
@end

static inline void dispatch_once_and_next_time(dispatch_once_t *oncePredicate, dispatch_block_t onceBlock, dispatch_block_t nextTimeBlock) {
    if (*oncePredicate) {
        [nextTimeBlock invoke];
    }

    dispatch_once(oncePredicate, ^{
        [onceBlock invoke];
    });
}

static dispatch_semaphore_t waitSemaphore;
static int finishedOperationsCount = 0;


@interface KeyValueObserver : NSObject
@end

@implementation KeyValueObserver

+ (instancetype)sharedObserver {
    static KeyValueObserver *sharedObserver;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedObserver = [[self alloc] init];
    });

    return sharedObserver;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {

    @synchronized(self) {
        if ([keyPath isEqual:@"isFinished"]) {
            BOOL finished = (BOOL)[[change objectForKey:NSKeyValueChangeNewKey] integerValue];

            if (finished == YES) {
                [object removeObserver:self forKeyPath:@"isFinished"];
                finishedOperationsCount++;
            }
        }
    }
}

@end

@interface NSNeverFinishBlockOperation : NSOperation
@property (copy, nonatomic) void (^operationBlock)(void);
@end

@implementation NSNeverFinishBlockOperation

+ (instancetype)blockOperationWithBlock:(void (^)(void))block {
    NSNeverFinishBlockOperation *neverFinishOperation = [[NSNeverFinishBlockOperation alloc] init];

    neverFinishOperation.operationBlock = block;

    return neverFinishOperation;
}

- (void)start {
    [self main];
}

- (void)main {
    [self.operationBlock invoke];
}

@end



