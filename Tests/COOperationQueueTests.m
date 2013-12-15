
#import <SenTestingKit/SenTestingKit.h>

#import "TestHelpers.h"

#import "NSOperationQueueController.h"
#import "NSOperationQueueController_Private.h"

@interface NSOperationQueueControllerTests : SenTestCase
@end

static dispatch_semaphore_t waitSemaphore;

static int finishedOperationsCount;

@implementation NSOperationQueueControllerTests

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

- (void)setUp {
    [super setUp];
    
    finishedOperationsCount = 0;
}

- (void)test_addOperationWithBlock {
    __block BOOL isFinished = NO;

    NSOperationQueue *operationQueue = [NSOperationQueue new];

    NSOperationQueueController *controller = [[NSOperationQueueController alloc] initWithOperationQueue:operationQueue];
    [controller addOperationWithBlock:^{
        isFinished = YES;
    }];

    while(isFinished == NO || controller.runningOperations.count != 0) {}

    STAssertTrue(isFinished, nil);
    STAssertEquals((int)controller.runningOperations.count, 0, nil);
}

- (void)test_COOperationQueue_addOperation_max_limit_0 {
    finishedOperationsCount = 0;

    int N = 100;

    NSMutableArray *countArr = [NSMutableArray array];

    NSOperationQueue *operationQueue = [NSOperationQueue new];
    NSOperationQueueController *controller = [[NSOperationQueueController alloc] initWithOperationQueue:operationQueue];

    int countDown = N;
    
    while (countDown-- > 0) {
        NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
            @synchronized(countArr) {
                [countArr addObject:@1];
            }

        }];

        [operation addObserver:self
                    forKeyPath:@"isFinished"
                       options:NSKeyValueObservingOptionNew
                       context:NULL];

        [controller.operationQueue addOperation:operation];
    }

    while (finishedOperationsCount < N) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, NO);
        NSLog(@"%@", controller.operationQueue.operations);
    }

    STAssertEquals((int)countArr.count, N, nil);

    STAssertEquals(finishedOperationsCount, N, @"Expected finishedOperationsCount to be 100");
}

- (void)test_COOperationQueue_addOperation_max_limit_1 {
    NSMutableArray *countArr = [NSMutableArray array];
    __block BOOL finished = NO;

    NSOperationQueue *operationQueue = [NSOperationQueue new];
    operationQueue.maxConcurrentOperationCount = 1;

    NSOperationQueueController *controller = [[NSOperationQueueController alloc] initWithOperationQueue:operationQueue];

    int countDown = 10;
    while (countDown-- > 0 ) {
        NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
            STAssertEquals((int)controller.runningOperations.count, 1, nil);

            @synchronized(countArr) {
                [countArr addObject:@1];
            }

            if (countArr.count == 10) {
                finished = YES;
            }
        }];

        [controller.pendingOperations addObject:operation];
    }

    [controller _runNextOperationIfExists];
    
    while (finished == NO);

    STAssertEquals((int)countArr.count, 10, nil);
}


- (void)test_aggressive_LIFO {
    __block BOOL isFinished = NO;
    
    NSOperationQueue *operationQueue = [NSOperationQueue new];
    operationQueue.maxConcurrentOperationCount = 1;

    NSOperationQueueController *controller = [[NSOperationQueueController alloc] initWithOperationQueue:operationQueue];
    controller.order = NSOperationQueueControllerOrderAggressiveLIFO;

    NSBlockOperation *neverFinishOperation = [NSBlockOperation blockOperationWithBlock:^{
        dispatch_semaphore_wait(waitSemaphore, DISPATCH_TIME_FOREVER);
    }];

    NSBlockOperation *operation1 = [NSBlockOperation blockOperationWithBlock:^{
        // Nothing intentionally - operation will never be run
        // Because it will be replaced by the following operation
        abort();
    }];

    NSBlockOperation *operation2 = [NSBlockOperation blockOperationWithBlock:^{
        // Nothing intentionally - operation will never be run
        // Because it will be replaced by the following operation

        isFinished = YES;
    }];

    waitSemaphore = dispatch_semaphore_create(0);

    [controller addOperation:neverFinishOperation];
    [controller addOperation:operation1];
    [controller addOperation:operation2];

    dispatch_semaphore_signal(waitSemaphore);

    while(isFinished == NO) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, NO);


    STAssertTrue(isFinished, nil);
}


@end
