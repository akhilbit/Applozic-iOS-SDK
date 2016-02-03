//
//  ALMessageDBService.m
//  ChatApp
//
//  Created by Devashish on 21/09/15.
//  Copyright © 2015 AppLogic. All rights reserved.
//

#import "ALMessageDBService.h"
#import "ALContact.h"
#import "ALDBHandler.h"
#import "DB_Message.h"
#import "ALUserDefaultsHandler.h"
#import "ALMessage.h"
#import "DB_FileMetaInfo.h"
#import "ALMessageService.h"
#import "ALContactService.h"
#import "ALMessageClientService.h"

@implementation ALMessageDBService{
    ALMessageDBService  * dbService;

}


//Add message APIS

-(NSMutableArray *) addMessageList:(NSMutableArray*) messageList {
    NSMutableArray *messageArray = [[NSMutableArray alloc] init];
   
    ALDBHandler * theDBHandler = [ALDBHandler sharedInstance];
    for (ALMessage * theMessage in messageList) {
        
        //Duplicate check before inserting into DB...
        NSManagedObject *message =  [self getMessageByKey:@"key" value:theMessage.key];
        if(message!=nil){
            NSLog(@"Skipping duplicate message found with key %@", theMessage.key);
            continue;
        }
        theMessage.sentToServer = YES;
        DB_Message * theMessageEntity= [self createMessageEntityForDBInsertionWithMessage:theMessage];
        [theDBHandler.managedObjectContext save:nil];
        theMessage.msgDBObjectId = theMessageEntity.objectID;
        
        [messageArray addObject:theMessage];
    }
    
    [theDBHandler.managedObjectContext save:nil];
    return messageArray;
}

-(DB_Message*)addMessage:(ALMessage*) message{
    ALDBHandler * theDBHandler = [ALDBHandler sharedInstance];
    DB_Message* dbMessag = [self createMessageEntityForDBInsertionWithMessage:message];
    [theDBHandler.managedObjectContext save:nil];
    message.msgDBObjectId = dbMessag.objectID;
    
    if(message.sent==TRUE){
        dbMessag.isRead=[NSNumber numberWithBool:YES];
    }
    return dbMessag;
}

-(NSManagedObject *)getMeesageById:(NSManagedObjectID *)objectID
                             error:(NSError **)error{
    
   ALDBHandler * theDBHandler = [ALDBHandler sharedInstance];
   NSManagedObject *obj =  [theDBHandler.managedObjectContext existingObjectWithID:objectID error:error];
   return obj;
}

-(void) updateDeliveryReportForContact: (NSString *) contactId {
 
    NSBatchUpdateRequest *req = [[NSBatchUpdateRequest alloc] initWithEntityName:@"DB_Message"];
        req.predicate = [NSPredicate predicateWithFormat:@"contactId==%@",contactId];
        req.propertiesToUpdate = @{
                                   @"delivered" : @(YES)
                                   };
        req.resultType = NSUpdatedObjectsCountResultType;
        ALDBHandler * dbHandler = [ALDBHandler sharedInstance];
        NSBatchUpdateResult *res = (NSBatchUpdateResult *)[dbHandler.managedObjectContext executeRequest:req error:nil];
        NSLog(@"%@ objects updated", res.result);
}


//update Message APIS
-(void)updateMessageDeliveryReport:(NSString*)keyString{
    
    ALDBHandler * dbHandler = [ALDBHandler sharedInstance];
    
    NSManagedObject* message = [self getMessageByKey:@"key"  value:keyString];
    [message setValue:[NSNumber numberWithBool:YES] forKey:@"delivered"];
    NSError *error = nil;
    if ( [dbHandler.managedObjectContext save:&error]){
        NSLog(@"message found and maked as deliverd");
    } else {
        //NSLog(@"message not found with this key");
    }
    
}


-(void)updateMessageSyncStatus:(NSString*) keyString{
    
    ALDBHandler * dbHandler = [ALDBHandler sharedInstance];
    
    NSManagedObject* message = [self getMessageByKey:@"keyString" value:keyString];
    [message setValue:@"1" forKey:@"isSent"];
    NSError *error = nil;
    if ( [dbHandler.managedObjectContext save:&error]){
        NSLog(@"message found and maked as deliverd");
    } else {
       // NSLog(@"message not found with this key");
    }
}


//Delete Message APIS

-(void) deleteMessage{
    
}

-(void) deleteMessageByKey:(NSString*) keyString {
    
    
    ALDBHandler * dbHandler = [ALDBHandler sharedInstance];
    
    NSManagedObject* message = [self getMessageByKey:@"key" value:keyString];
    
    if(message){
                [dbHandler.managedObjectContext deleteObject:message];

        NSError *error = nil;
        if ( [dbHandler.managedObjectContext save:&error]){
            NSLog(@"message found ");
        }
    }
    else{
         NSLog(@"message not found with this key");
    }
    
}

-(void) deleteAllMessagesByContact: (NSString*) contactId orChannelKey:(NSNumber *)key
{
    ALDBHandler * dbHandler = [ALDBHandler sharedInstance];
   
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DB_Message" inManagedObjectContext:dbHandler.managedObjectContext];
    NSPredicate *predicate;
    if(key != nil)
    {
     predicate = [NSPredicate predicateWithFormat:@"groupId = %@",key];
    }
    else
    {
        predicate = [NSPredicate predicateWithFormat:@"contactId = %@",contactId];
    }
    
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:predicate];
    
    NSError *fetchError = nil;
    
    NSArray *result = [dbHandler.managedObjectContext executeFetchRequest:fetchRequest error:&fetchError];
    
    for (DB_Message *message in result) {
        [dbHandler.managedObjectContext deleteObject:message];
    }
    
    NSError *deleteError = nil;
    
   BOOL success = [dbHandler.managedObjectContext save:&deleteError];
    
    if (!success) {
        NSLog(@"Unable to save managed object context.");
        NSLog(@"%@, %@", deleteError, deleteError.localizedDescription);
    }
    
}

//Generic APIS
-(BOOL) isMessageTableEmpty{
    ALDBHandler * dbHandler = [ALDBHandler sharedInstance];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DB_Message" inManagedObjectContext:dbHandler.managedObjectContext];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:entity];
    [fetchRequest setIncludesPropertyValues:NO];
    [fetchRequest setIncludesSubentities:NO];
    NSError *error = nil;
    NSUInteger count = [ dbHandler.managedObjectContext countForFetchRequest: fetchRequest error: &error];
    if(error == nil ){
        return !(count >0);
    }else{
         NSLog(@"Error fetching count :%@",error);
    }
    return true;
}

- (void)deleteAllObjectsInCoreData
{
    ALDBHandler * dbHandler = [ALDBHandler sharedInstance];
    NSArray *allEntities = dbHandler.managedObjectModel.entities;
    for (NSEntityDescription *entityDescription in allEntities)
    {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entityDescription];
        
        fetchRequest.includesPropertyValues = NO;
        fetchRequest.includesSubentities = NO;
        
        NSError *error;
        NSArray *items = [dbHandler.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        
        if (error) {
            NSLog(@"Error requesting items from Core Data: %@", [error localizedDescription]);
        }
        
        for (NSManagedObject *managedObject in items) {
            [dbHandler.managedObjectContext deleteObject:managedObject];
        }
        
        if (![dbHandler.managedObjectContext save:&error]) {
            NSLog(@"Error deleting %@ - error:%@", entityDescription, [error localizedDescription]);
        }
    }  
}

- (NSManagedObject *)getMessageByKey:(NSString *) key value:(NSString*) value{
    
    
    //Runs at MessageList viewing/opening...ONLY FIRST TIME AND if delete an msg
    ALDBHandler * dbHandler = [ALDBHandler sharedInstance];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DB_Message" inManagedObjectContext:dbHandler.managedObjectContext];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K = %@",key,value];
//    NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"deletedFlag == NO"];
    NSPredicate * resultPredicate=[NSCompoundPredicate andPredicateWithSubpredicates:@[predicate]];//,predicate3]];
    
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:resultPredicate];

    NSError *fetchError = nil;
    NSArray *result = [dbHandler.managedObjectContext executeFetchRequest:fetchRequest error:&fetchError];
    if (result.count > 0) {
        NSManagedObject* message = [result objectAtIndex:0];
       
        return message;
    } else {
      //  NSLog(@"message not found with this key");
        return nil;
    }
}

-(NSUInteger)markConversationAsRead:(NSString *) contactId orChannelKey:(NSNumber *)key
{
    NSArray *messages  = [self getUnreadMessages:contactId];
    
    if(messages.count >0 ){
        NSBatchUpdateRequest *req = [[NSBatchUpdateRequest alloc] initWithEntityName:@"DB_Message"];
        req.predicate = [NSPredicate predicateWithFormat:@"contactId==%@",contactId];
        if(key != nil)
        {
            req.predicate = [NSPredicate predicateWithFormat:@"groupId==%@",key];
        }
        
        req.propertiesToUpdate = @{
                                   @"isRead" : @(YES)
                                   };
        req.resultType = NSUpdatedObjectsCountResultType;
        ALDBHandler * dbHandler = [ALDBHandler sharedInstance];
        NSBatchUpdateResult *res = (NSBatchUpdateResult *)[dbHandler.managedObjectContext executeRequest:req error:nil];
        NSLog(@"%@ objects updated", res.result);
    }
    return messages.count;
}

- (NSArray *)getUnreadMessages:(NSString *) contactId
{
    //Runs at Opening AND Leaving ChatVC AND Opening MessageList..
    ALDBHandler * dbHandler = [ALDBHandler sharedInstance];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DB_Message" inManagedObjectContext:dbHandler.managedObjectContext];
    NSPredicate *predicate;

    NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"isRead==%@ AND type==%@ ",@"0",@"4"];
//    NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"deletedFlag == NO"];
    if (contactId) {
        NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"%K=%@",@"contactId",contactId];
        predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate1,predicate2]];
    } else {
        predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate2]];
    }
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:predicate];
    NSError *fetchError = nil;
    NSArray *result = [dbHandler.managedObjectContext executeFetchRequest:fetchRequest error:&fetchError];
    return result;
}

//------------------------------------------------------------------------------------------------------------------
    #pragma mark - ALMessagesViewController DB Operations.
//------------------------------------------------------------------------------------------------------------------

-(void)getMessages {

    if ( [self isMessageTableEmpty ] ) { // db is not synced
        [self fetchAndRefreshFromServer];
        [self syncConactsDB];
    }
    else // db is synced
    {
        //fetch data from db
        [self fetchConversationsGroupByContactId];
    }
}

-(void)fetchAndRefreshFromServer{
    
    [self syncConverstionDBWithCompletion:^(BOOL success, NSMutableArray * theArray) {
        
        if (success) {
            // save data into the db
            [self addMessageList:theArray];
            // set yes to userdefaults
            [ALUserDefaultsHandler setBoolForKey_isConversationDbSynced:YES];
            // add default contacts
            //fetch data from db
            [self fetchConversationsGroupByContactId];
        }
    }];
}

-(void)fetchAndRefreshFromServerForPush{
    NSString * deviceKeyString = [ALUserDefaultsHandler getDeviceKeyString];
    
    [ALMessageService getLatestMessageForUser:deviceKeyString withCompletion:^(NSMutableArray *messageArray, NSError *error) {
        if (error) {
            NSLog(@"%@",error);
            return ;
        }
      //  [self addMessageList:messageArray];
       [self fetchConversationsGroupByContactId];
    }];

}

-(void)fetchAndRefreshQuickConversation{
    NSString * deviceKeyString = [ALUserDefaultsHandler getDeviceKeyString];
    
    [ALMessageService getLatestMessageForUser:deviceKeyString withCompletion:^(NSMutableArray *messageArray, NSError *error) {
        if (error) {
            NSLog(@"%@",error);
            return ;
        }
        [self addMessageList:messageArray];
        [self.delegate updateMessageList:messageArray];
        //[self fetchConversationsGroupByContactId];
    }];
    
}
//------------------------------------------------------------------------------------------------------------------
    #pragma mark -  Helper methods
//------------------------------------------------------------------------------------------------------------------

-(void)syncConverstionDBWithCompletion:(void(^)(BOOL success , NSMutableArray * theArray)) completion
{
    //[self.mActivityIndicator startAnimating];
    ALMessageClientService * messageClientService  = [[ALMessageClientService alloc]init];
    [messageClientService getMessagesListGroupByContactswithCompletion:^(NSMutableArray *messageArray, NSError *error) {
      //  [self.mActivityIndicator stopAnimating];
        if (error) {
            NSLog(@"%@",error);
            completion(NO,nil);
            return ;
        }
        //NSMutableArray * dataArray = [NSMutableArray arrayWithArray:messageArray];
        completion(YES, messageArray);
    }];
}

-(void)syncConactsDB
{
    ALContactService *contactservice = [[ALContactService alloc] init];
   // [contactservice insertInitialContacts];
}

-(void)fetchConversationsGroupByContactId
{
    ALDBHandler * theDbHandler = [ALDBHandler sharedInstance];
    // get all unique contacts
    NSFetchRequest * theRequest = [NSFetchRequest fetchRequestWithEntityName:@"DB_Message"];
    [theRequest setResultType:NSDictionaryResultType];
    [theRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:NO]]];
    [theRequest setPropertiesToFetch:[NSArray arrayWithObjects:@"contactId", @"groupId", nil]];
    [theRequest setReturnsDistinctResults:YES];
    
    NSArray * theArray = [theDbHandler.managedObjectContext executeFetchRequest:theRequest error:nil];
    // get latest record
    NSMutableArray *messagesArray = [NSMutableArray new];
    for (NSDictionary * theDictionary in theArray) {
        NSFetchRequest * theRequest = [NSFetchRequest fetchRequestWithEntityName:@"DB_Message"];
        
        if([theDictionary[@"groupId"] intValue])
        {
            [theRequest setPredicate:[NSPredicate predicateWithFormat:@"groupId = %@",theDictionary[@"groupId"]]];
        }
        else
        {
            [theRequest setPredicate:[NSPredicate predicateWithFormat:@"contactId = %@",theDictionary[@"contactId"]]];
        }
        
        [theRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:NO]]];
        [theRequest setFetchLimit:1];
        
        NSArray * theArray1 =  [theDbHandler.managedObjectContext executeFetchRequest:theRequest error:nil];
        DB_Message * theMessageEntity = theArray1.firstObject;
        
        ALMessage * theMessage = [self createMessageEntity:theMessageEntity];
        [messagesArray addObject:theMessage];
    }
    if(!self.delegate ){
        NSLog(@"delegate is not set.");
        return;
    }
    
    NSSortDescriptor *sortDescriptor;
    sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"createdAtTime" ascending:NO];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    NSMutableArray *sortedArray = [[messagesArray sortedArrayUsingDescriptors:sortDescriptors] mutableCopy];
    
    if ([self.delegate respondsToSelector:@selector(getMessagesArray:)]) {
        [self.delegate getMessagesArray:sortedArray];
    }
}

-(DB_Message *) createMessageEntityForDBInsertionWithMessage:(ALMessage *) theMessage
{
    
    //Runs at MessageList viewing/opening... ONLY FIRST TIME
    ALDBHandler * theDBHandler = [ALDBHandler sharedInstance];
    
    DB_Message * theMessageEntity = [NSEntityDescription insertNewObjectForEntityForName:@"DB_Message" inManagedObjectContext:theDBHandler.managedObjectContext];
    
    theMessageEntity.contactId = theMessage.contactIds;
    theMessageEntity.createdAt =  theMessage.createdAtTime;
    theMessageEntity.deviceKey = theMessage.deviceKey;
    theMessageEntity.isRead = [NSNumber numberWithBool:([theMessageEntity.type isEqualToString:@"5"] ? TRUE : theMessage.read)];
    theMessageEntity.isSent = [NSNumber numberWithBool:theMessage.sent];
    theMessageEntity.isSentToDevice = [NSNumber numberWithBool:theMessage.sendToDevice];
    theMessageEntity.isShared = [NSNumber numberWithBool:theMessage.shared];
    theMessageEntity.isStoredOnDevice = [NSNumber numberWithBool:theMessage.storeOnDevice];
    theMessageEntity.key = theMessage.key;
    theMessageEntity.messageText = theMessage.message;
    theMessageEntity.userKey = theMessage.userKey;
    theMessageEntity.to = theMessage.to;
    theMessageEntity.type = theMessage.type;
    theMessageEntity.delivered = [NSNumber numberWithBool:theMessage.delivered];
    theMessageEntity.sentToServer = [NSNumber numberWithBool:theMessage.sentToServer];
    theMessageEntity.filePath = theMessage.imageFilePath;
    theMessageEntity.inProgress = [ NSNumber numberWithBool:theMessage.inProgress];
    theMessageEntity.isUploadFailed=[ NSNumber numberWithBool:theMessage.isUploadFailed];
    theMessageEntity.contentType = theMessage.contentType;
    theMessageEntity.deletedFlag=[NSNumber numberWithBool:theMessage.deleted];
    
    
    if(theMessage.getGroupId)
    {
        theMessageEntity.groupId = theMessage.groupId;
    }
    if(theMessage.fileMeta != nil) {
        DB_FileMetaInfo *  fileInfo =  [self createFileMetaInfoEntityForDBInsertionWithMessage:theMessage.fileMeta];
        theMessageEntity.fileMetaInfo = fileInfo;
    }
    return theMessageEntity;
}

-(DB_FileMetaInfo *) createFileMetaInfoEntityForDBInsertionWithMessage:(ALFileMetaInfo *) fileInfo
{
    ALDBHandler * theDBHandler = [ALDBHandler sharedInstance];
    DB_FileMetaInfo * fileMetaInfo = [NSEntityDescription insertNewObjectForEntityForName:@"DB_FileMetaInfo" inManagedObjectContext:theDBHandler.managedObjectContext];

    fileMetaInfo.blobKeyString = fileInfo.blobKey;
    fileMetaInfo.contentType = fileInfo.contentType;
    fileMetaInfo.createdAtTime = fileInfo.createdAtTime;
    fileMetaInfo.key = fileInfo.key;
    fileMetaInfo.name = fileInfo.name;
    fileMetaInfo.size = fileInfo.size;
    fileMetaInfo.suUserKeyString = fileInfo.userKey;
    fileMetaInfo.thumbnailUrl = fileInfo.thumbnailUrl;
    
    return fileMetaInfo;
}

-(ALMessage *) createMessageEntity:(DB_Message *) theEntity
{
    ALMessage * theMessage = [ALMessage new];
    
    theMessage.msgDBObjectId = [theEntity objectID];
    theMessage.key = theEntity.key;
    theMessage.deviceKey = theEntity.deviceKey;
    theMessage.userKey = theEntity.userKey;
    theMessage.to = theEntity.to;
    theMessage.message = theEntity.messageText;
    theMessage.sent = theEntity.isSent.boolValue;
    theMessage.sendToDevice = theEntity.isSentToDevice.boolValue;
    theMessage.shared = theEntity.isShared.boolValue;
    theMessage.createdAtTime = theEntity.createdAt;
    theMessage.type = theEntity.type;
    theMessage.contactIds = theEntity.contactId;
    theMessage.storeOnDevice = theEntity.isStoredOnDevice.boolValue;
    theMessage.inProgress =theEntity.inProgress.boolValue;
    theMessage.read = theEntity.isRead.boolValue;
    theMessage.imageFilePath = theEntity.filePath;
    theMessage.delivered = theEntity.delivered.boolValue;
    theMessage.sentToServer = theEntity.sentToServer.boolValue;
    theMessage.isUploadFailed = theEntity.isUploadFailed.boolValue;
    theMessage.contentType = theEntity.contentType;
    theMessage.deleted=theEntity.deletedFlag.boolValue;
    NSLog(@"theMessage Deleted flag setting %hhd",theMessage.deleted);
    if(theEntity.groupId)
    {
        theMessage.groupId = theEntity.groupId;
    }
    
    // file meta info
    if(theEntity.fileMetaInfo){
        ALFileMetaInfo * theFileMeta = [ALFileMetaInfo new];
        theFileMeta.blobKey = theEntity.fileMetaInfo.blobKeyString;
        theFileMeta.contentType = theEntity.fileMetaInfo.contentType;
        theFileMeta.createdAtTime = theEntity.fileMetaInfo.createdAtTime;
        theFileMeta.key = theEntity.fileMetaInfo.key;
        theFileMeta.name = theEntity.fileMetaInfo.name;
        theFileMeta.size = theEntity.fileMetaInfo.size;
        theFileMeta.userKey = theEntity.fileMetaInfo.suUserKeyString;
        theFileMeta.thumbnailUrl = theEntity.fileMetaInfo.thumbnailUrl;
        theMessage.fileMeta = theFileMeta;
    }
    return theMessage;
}

-(void) updateFileMetaInfo:(ALMessage *) almessage
{
    NSError *error=nil;
    DB_Message * db_Message = (DB_Message*)[self getMeesageById:almessage.msgDBObjectId error:&error];
    almessage.fileMetaKey = almessage.fileMeta.key;
    
    db_Message.fileMetaInfo.blobKeyString = almessage.fileMeta.blobKey;
    db_Message.fileMetaInfo.contentType = almessage.fileMeta.contentType;
    db_Message.fileMetaInfo.createdAtTime = almessage.fileMeta.createdAtTime;
    db_Message.fileMetaInfo.key = almessage.fileMeta.key;
    db_Message.fileMetaInfo.name = almessage.fileMeta.name;
    db_Message.fileMetaInfo.size = almessage.fileMeta.size;
    db_Message.fileMetaInfo.suUserKeyString = almessage.fileMeta.userKey;
    [[ALDBHandler sharedInstance].managedObjectContext save:nil];
    
}

-(NSMutableArray *)getMessageListForContactWithCreatedAt:(NSString *)contactId withCreatedAt:(NSNumber*)createdAt andChannelKey:(NSNumber *)channelKey
{
    ALDBHandler * theDbHandler = [ALDBHandler sharedInstance];
    NSFetchRequest * theRequest = [NSFetchRequest fetchRequestWithEntityName:@"DB_Message"];
    NSPredicate *predicate1;
    if(channelKey != nil)
    {
        predicate1 = [NSPredicate predicateWithFormat:@"groupId = %@",channelKey];
    }
    else
    {
        predicate1 = [NSPredicate predicateWithFormat:@"contactId = %@",contactId];
    }
    
    NSPredicate* predicateDeletedCheck=[NSPredicate predicateWithFormat:@"deletedFlag == NO"];
    
    NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"createdAt < %lu",createdAt];
    theRequest.predicate =[NSCompoundPredicate andPredicateWithSubpredicates:@[predicate1, predicate2, predicateDeletedCheck]];
    
    [theRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:NO]]];
    NSArray * theArray = [theDbHandler.managedObjectContext executeFetchRequest:theRequest error:nil];
    NSMutableArray * msgArray =  [[NSMutableArray alloc]init];
    for (DB_Message * theEntity in theArray) {
        ALMessage * theMessage = [self createMessageEntity:theEntity];
        [msgArray addObject:theMessage];
    }
    return msgArray;
}

-(NSMutableArray *)getPendingMessages{
    
    ALDBHandler * theDbHandler = [ALDBHandler sharedInstance];
    NSFetchRequest * theRequest = [NSFetchRequest fetchRequestWithEntityName:@"DB_Message"];
    theRequest.predicate =[NSPredicate predicateWithFormat:@"sentToServer = %@ and type= %@",@"0",@"5"];
    
    [theRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:YES]]];
    NSArray * theArray = [theDbHandler.managedObjectContext executeFetchRequest:theRequest error:nil];
    NSMutableArray * msgArray = [[NSMutableArray alloc]init];
    
    for (DB_Message * theEntity in theArray) {
        ALMessage * theMessage = [self createMessageEntity:theEntity];
        if(theMessage.groupId==[NSNumber numberWithInt:0]){
            NSLog(@"groupId is coming as 0..setting it null" );
            theMessage.groupId=NULL;
        }
        [msgArray addObject:theMessage];
    }
    
    NSLog(@" get pending messages ...getPendingMessages ..%lu",msgArray.count);
    
    return msgArray;

    
}


@end
