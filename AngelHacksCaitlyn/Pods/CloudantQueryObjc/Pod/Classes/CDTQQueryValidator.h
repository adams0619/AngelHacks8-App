//
//  CDTQQueryValidator.h
//  Pods
//
//  Created by Rhys Short on 06/11/2014.
//
//

#import <Foundation/Foundation.h>

// This class contains common validation options for the
// two different implementations of query
@interface CDTQQueryValidator : NSObject

/**
 Expand implicit operators in a query, and validate
 */
+ (NSDictionary *)normaliseAndValidateQuery:(NSDictionary *)query;

@end
