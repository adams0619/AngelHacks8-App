//
//  CDTQResultSet.h
//
//  Created by Mike Rhodes on 2014-09-27
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <Foundation/Foundation.h>

@class CDTDatastore;
@class CDTQResultSetBuilder;
@class CDTDocumentRevision;
@class CDTQUnindexedMatcher;

typedef void (^CDTQResultSetBuilderBlock)(CDTQResultSetBuilder *configuration);

/**
 A simple object to aid construction of a CDTQResultSet.
 */
@interface CDTQResultSetBuilder : NSObject

@property (nonatomic, strong) NSArray *docIds;
@property (nonatomic, strong) CDTDatastore *datastore;
@property (nonatomic, strong) NSArray *fields;
@property (nonatomic) NSUInteger skip;
@property (nonatomic) NSUInteger limit;
@property (nonatomic, strong) CDTQUnindexedMatcher *matcher;

@end

/**
 Enumerator over documents resulting from query.

 Use a forin query to loop over this object:

 for (DocumentRevision revision : queryResultObject) {
 // do something
 }
 */
@interface CDTQResultSet : NSObject {
    CDTDatastore *_datastore;
    NSArray *_originalDocumentIds;
}

+ (instancetype)resultSetWithBlock:(CDTQResultSetBuilderBlock)block;

- (instancetype)initWithBuilder:(CDTQResultSetBuilder *)builder;

- (void)enumerateObjectsUsingBlock:(void (^)(CDTDocumentRevision *rev, NSUInteger idx,
                                             BOOL *stop))block;

@property (nonatomic, strong, readonly) NSArray *documentIds;  // of type NSString*

@end
