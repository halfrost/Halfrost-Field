//
//  FXForms.m
//
//  Version 1.2.14
//
//  Created by Nick Lockwood on 13/02/2014.
//  Copyright (c) 2014 Charcoal Design. All rights reserved.
//
//  Distributed under the permissive zlib License
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/FXForms
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import "FXForms.h"
#import <objc/runtime.h>


#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wdirect-ivar-access"
#pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
#pragma clang diagnostic ignored "-Wreceiver-is-weak"
#pragma clang diagnostic ignored "-Wconversion"
#pragma clang diagnostic ignored "-Wgnu"

#ifdef __IPHONE_8_3
#pragma clang diagnostic ignored "-Wcstring-format-directive"
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
#pragma clang diagnostic ignored "-Wnonnull"
#endif

NSString *const FXFormFieldKey = @"key";
NSString *const FXFormFieldType = @"type";
NSString *const FXFormFieldClass = @"class";
NSString *const FXFormFieldCell = @"cell";
NSString *const FXFormFieldTitle = @"title";
NSString *const FXFormFieldPlaceholder = @"placeholder";
NSString *const FXFormFieldDefaultValue = @"default";
NSString *const FXFormFieldOptions = @"options";
NSString *const FXFormFieldTemplate = @"template";
NSString *const FXFormFieldValueTransformer = @"valueTransformer";
NSString *const FXFormFieldAction = @"action";
NSString *const FXFormFieldSegue = @"segue";
NSString *const FXFormFieldHeader = @"header";
NSString *const FXFormFieldFooter = @"footer";
NSString *const FXFormFieldInline = @"inline";
NSString *const FXFormFieldSortable = @"sortable";
NSString *const FXFormFieldViewController = @"viewController";

NSString *const FXFormFieldTypeDefault = @"default";
NSString *const FXFormFieldTypeLabel = @"label";
NSString *const FXFormFieldTypeText = @"text";
NSString *const FXFormFieldTypeLongText = @"longtext";
NSString *const FXFormFieldTypeURL = @"url";
NSString *const FXFormFieldTypeEmail = @"email";
NSString *const FXFormFieldTypePhone = @"phone";
NSString *const FXFormFieldTypePassword = @"password";
NSString *const FXFormFieldTypeNumber = @"number";
NSString *const FXFormFieldTypeInteger = @"integer";
NSString *const FXFormFieldTypeUnsigned = @"unsigned";
NSString *const FXFormFieldTypeFloat = @"float";
NSString *const FXFormFieldTypeBitfield = @"bitfield";
NSString *const FXFormFieldTypeBoolean = @"boolean";
NSString *const FXFormFieldTypeOption = @"option";
NSString *const FXFormFieldTypeDate = @"date";
NSString *const FXFormFieldTypeTime = @"time";
NSString *const FXFormFieldTypeDateTime = @"datetime";
NSString *const FXFormFieldTypeImage = @"image";


static NSString *const FXFormsException = @"FXFormsException";


static const CGFloat FXFormFieldLabelSpacing = 5;
static const CGFloat FXFormFieldMinLabelWidth = 97;
static const CGFloat FXFormFieldMaxLabelWidth = 240;
static const CGFloat FXFormFieldMinFontSize = 12;
static const CGFloat FXFormFieldPaddingLeft = 10;
static const CGFloat FXFormFieldPaddingRight = 10;
static const CGFloat FXFormFieldPaddingTop = 12;
static const CGFloat FXFormFieldPaddingBottom = 12;


static Class FXFormClassFromString(NSString *className)
{
    Class cls = NSClassFromString(className);
    if (className && !cls)
    {
        //might be a Swift class; time for some hackery!
        className = [@[[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"],
                       className] componentsJoinedByString:@"."];
        //try again
        cls = NSClassFromString(className);
    }
    return cls;
}

static UIView *FXFormsFirstResponder(UIView *view)
{
    if ([view isFirstResponder])
    {
        return view;
    }
    for (UIView *subview in view.subviews)
    {
        UIView *responder = FXFormsFirstResponder(subview);
        if (responder)
        {
            return responder;
        }
    }
    return nil;
}


#pragma mark -
#pragma mark Models


static inline CGFloat FXFormLabelMinFontSize(UILabel *label)
{
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0
    
    if (![label respondsToSelector:@selector(setMinimumScaleFactor:)])
    {
        return label.minimumFontSize;
    }
    
#endif
    
    return label.font.pointSize * label.minimumScaleFactor;
}

static inline void FXFormLabelSetMinFontSize(UILabel *label, CGFloat fontSize)
{
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0
    
    if (![label respondsToSelector:@selector(setMinimumScaleFactor:)])
    {
        label.minimumFontSize = fontSize;
    }
    else
        
#endif
        
    {
        label.minimumScaleFactor = fontSize / label.font.pointSize;
    }
}

static inline NSArray *FXFormProperties(id<FXForm> form)
{
    if (!form) return nil;

    static void *FXFormPropertiesKey = &FXFormPropertiesKey;
    NSMutableArray *properties = objc_getAssociatedObject(form, FXFormPropertiesKey);
    if (!properties)
    {
        static NSSet *NSObjectProperties;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSObjectProperties = [NSMutableSet setWithArray:@[@"description", @"debugDescription", @"hash", @"superclass"]];
            unsigned int propertyCount;
            objc_property_t *propertyList = class_copyPropertyList([NSObject class], &propertyCount);
            for (unsigned int i = 0; i < propertyCount; i++)
            {
                //get property name
                objc_property_t property = propertyList[i];
                const char *propertyName = property_getName(property);
                [(NSMutableSet *)NSObjectProperties addObject:@(propertyName)];
            }
            free(propertyList);
            NSObjectProperties = [NSObjectProperties copy];
        });
        
        properties = [NSMutableArray array];
        Class subclass = [form class];
        while (subclass != [NSObject class])
        {
            unsigned int propertyCount;
            objc_property_t *propertyList = class_copyPropertyList(subclass, &propertyCount);
            for (unsigned int i = 0; i < propertyCount; i++)
            {
                //get property name
                objc_property_t property = propertyList[i];
                const char *propertyName = property_getName(property);
                NSString *key = @(propertyName);
                
                //ignore NSObject properties, unless overridden as readwrite
                char *readonly = property_copyAttributeValue(property, "R");
                if (readonly)
                {
                    free(readonly);
                    if ([NSObjectProperties containsObject:key])
                    {
                        continue;
                    }
                }

                //get property type
                Class valueClass = nil;
                NSString *valueType = nil;
                char *typeEncoding = property_copyAttributeValue(property, "T");
                switch (typeEncoding[0])
                {
                    case '@':
                    {
                        if (strlen(typeEncoding) >= 3)
                        {
                            char *className = strndup(typeEncoding + 2, strlen(typeEncoding) - 3);
                            __autoreleasing NSString *name = @(className);
                            NSRange range = [name rangeOfString:@"<"];
                            if (range.location != NSNotFound)
                            {
                                name = [name substringToIndex:range.location];
                            }
                            valueClass = FXFormClassFromString(name) ?: [NSObject class];
                            free(className);
                        }
                        break;
                    }
                    case 'c':
                    case 'B':
                    {
                        valueClass = [NSNumber class];
                        valueType = FXFormFieldTypeBoolean;
                        break;
                    }
                    case 'i':
                    case 's':
                    case 'l':
                    case 'q':
                    {
                        valueClass = [NSNumber class];
                        valueType = FXFormFieldTypeInteger;
                        break;
                    }
                    case 'C':
                    case 'I':
                    case 'S':
                    case 'L':
                    case 'Q':
                    {
                        valueClass = [NSNumber class];
                        valueType = FXFormFieldTypeUnsigned;
                        break;
                    }
                    case 'f':
                    case 'd':
                    {
                        valueClass = [NSNumber class];
                        valueType = FXFormFieldTypeFloat;
                        break;
                    }
                    case '{': //struct
                    case '(': //union
                    {
                        valueClass = [NSValue class];
                        valueType = FXFormFieldTypeLabel;
                        break;
                    }
                    case ':': //selector
                    case '#': //class
                    default:
                    {
                        valueClass = nil;
                        valueType = nil;
                    }
                }
                free(typeEncoding);
 
                //add to properties
                NSMutableDictionary *inferred = [NSMutableDictionary dictionaryWithObject:key forKey:FXFormFieldKey];
                if (valueClass) inferred[FXFormFieldClass] = valueClass;
                if (valueType) inferred[FXFormFieldType] = valueType;
                [properties addObject:[inferred copy]];
            }
            free(propertyList);
            subclass = [subclass superclass];
        }
        objc_setAssociatedObject(form, FXFormPropertiesKey, properties, OBJC_ASSOCIATION_RETAIN);
    }
    return properties;
}

static BOOL FXFormOverridesSelector(id<FXForm> form, SEL selector)
{
    Class formClass = [form class];
    while (formClass && formClass != [NSObject class])
    {
        unsigned int numberOfMethods;
        Method *methods = class_copyMethodList(formClass, &numberOfMethods);
        for (unsigned int i = 0; i < numberOfMethods; i++)
        {
            if (method_getName(methods[i]) == selector)
            {
                free(methods);
                return YES;
            }
        }
        if (methods) free(methods);
        formClass = [formClass superclass];
    }
    return NO;
}

static BOOL FXFormCanGetValueForKey(id<FXForm> form, NSString *key)
{
    //has key?
    if (![key length])
    {
        return NO;
    }
    
    //does a property exist for it?
    if ([[FXFormProperties(form) valueForKey:FXFormFieldKey] containsObject:key])
    {
        return YES;
    }
    
    //is there a getter method for this key?
    if ([form respondsToSelector:NSSelectorFromString(key)])
    {
        return YES;
    }
    
    //does it override valueForKey?
    if (FXFormOverridesSelector(form, @selector(valueForKey:)))
    {
        return YES;
    }
    
    //does it override valueForUndefinedKey?
    if (FXFormOverridesSelector(form, @selector(valueForUndefinedKey:)))
    {
        return YES;
    }
    
    //it will probably crash
    return NO;
}

static BOOL FXFormCanSetValueForKey(id<FXForm> form, NSString *key)
{
    //has key?
    if (![key length])
    {
        return NO;
    }
    
    //does a property exist for it?
    if ([[FXFormProperties(form) valueForKey:FXFormFieldKey] containsObject:key])
    {
        return YES;
    }
    
    //is there a setter method for this key?
    if ([form respondsToSelector:NSSelectorFromString([NSString stringWithFormat:@"set%@%@:", [[key substringToIndex:1] uppercaseString], [key substringFromIndex:1]])])
    {
        return YES;
    }
    
    //does it override setValueForKey?
    if (FXFormOverridesSelector(form, @selector(setValue:forKey:)))
    {
        return YES;
    }
    
    //does it override setValue:forUndefinedKey?
    if (FXFormOverridesSelector(form, @selector(setValue:forUndefinedKey:)))
    {
        return YES;
    }
    
    //it will probably crash
    return NO;
}

static NSString *FXFormFieldInferType(NSDictionary *dictionary)
{
    //guess type from class
    Class valueClass = dictionary[FXFormFieldClass];
    if ([valueClass isSubclassOfClass:[NSURL class]])
    {
        return FXFormFieldTypeURL;
    }
    else if ([valueClass isSubclassOfClass:[NSNumber class]])
    {
        return FXFormFieldTypeNumber;
    }
    else if ([valueClass isSubclassOfClass:[NSDate class]])
    {
        return FXFormFieldTypeDate;
    }
    else if ([valueClass isSubclassOfClass:[UIImage class]])
    {
        return FXFormFieldTypeImage;
    }
    
    if (!valueClass && ! dictionary[FXFormFieldAction] && !dictionary[FXFormFieldSegue])
    {
        //assume string if there's no action and nothing else to go on
        valueClass = [NSString class];
    }
    
    //guess type from key name
    if ([valueClass isSubclassOfClass:[NSString class]])
    {
        NSString *key = dictionary[FXFormFieldKey];
        NSString *lowercaseKey = [key lowercaseString];
        if ([lowercaseKey hasSuffix:@"password"])
        {
            return FXFormFieldTypePassword;
        }
        else if ([lowercaseKey hasSuffix:@"email"] || [lowercaseKey hasSuffix:@"emailaddress"])
        {
            return FXFormFieldTypeEmail;
        }
        else if ([lowercaseKey hasSuffix:@"phone"] || [lowercaseKey hasSuffix:@"phonenumber"])
        {
            return FXFormFieldTypePhone;
        }
        else if ([lowercaseKey hasSuffix:@"url"] || [lowercaseKey hasSuffix:@"link"])
        {
            return FXFormFieldTypeURL;
        }
        else if (valueClass)
        {
            //only return text type if there's no action and no better guess
            return FXFormFieldTypeText;
        }
    }
    
    return FXFormFieldTypeDefault;
}

static Class FXFormFieldInferClass(NSDictionary *dictionary)
{
    //if there are options, type should match first option
    NSArray *options = dictionary[FXFormFieldOptions];
    if ([options count])
    {
        //use same type as options
        return [[options firstObject] classForCoder];
    }
    
    //attempt to determine class from type
    NSString *type = dictionary[FXFormFieldType] ?: FXFormFieldInferType(dictionary);
    return @{FXFormFieldTypeLabel: [NSString class],
             FXFormFieldTypeText: [NSString class],
             FXFormFieldTypeLongText: [NSString class],
             FXFormFieldTypeURL: [NSURL class],
             FXFormFieldTypeEmail: [NSString class],
             FXFormFieldTypePhone: [NSString class],
             FXFormFieldTypePassword: [NSString class],
             FXFormFieldTypeNumber: [NSNumber class],
             FXFormFieldTypeInteger: [NSNumber class],
             FXFormFieldTypeUnsigned: [NSNumber class],
             FXFormFieldTypeFloat: [NSNumber class],
             FXFormFieldTypeBitfield: [NSNumber class],
             FXFormFieldTypeBoolean: [NSNumber class],
             FXFormFieldTypeOption: [NSNumber class],
             FXFormFieldTypeDate: [NSDate class],
             FXFormFieldTypeTime: [NSDate class],
             FXFormFieldTypeDateTime: [NSDate class],
             FXFormFieldTypeImage: [UIImage class]
             }[type];
}

static void FXFormPreprocessFieldDictionary(NSMutableDictionary *dictionary)
{
    //use base cell for subforms
    NSString *type = dictionary[FXFormFieldType];
    NSArray *options = dictionary[FXFormFieldOptions];
    if ((options || dictionary[FXFormFieldViewController] || dictionary[FXFormFieldTemplate]) &&
        ![type isEqualToString:FXFormFieldTypeBitfield] && ![dictionary[FXFormFieldInline] boolValue])
    {
        //TODO: is there a good way to support custom type for non-inline options cells?
        //TODO: is there a better way to force non-inline cells to use base cell?
        dictionary[FXFormFieldType] = type = FXFormFieldTypeDefault;
    }
    
    //get field value class
    id valueClass = dictionary[FXFormFieldClass];
    if ([valueClass isKindOfClass:[NSString class]])
    {
        dictionary[FXFormFieldClass] = valueClass = FXFormClassFromString(valueClass);
    }
    else if (!valueClass && (valueClass = FXFormFieldInferClass(dictionary)))
    {
        dictionary[FXFormFieldClass] = valueClass;
    }
  
    //get default value
    id defaultValue = dictionary[FXFormFieldDefaultValue];
    if (defaultValue)
    {
        if ([valueClass isSubclassOfClass:[NSArray class]] && ![defaultValue isKindOfClass:[NSArray class]])
        {
          //workaround for common mistake where type is collection, but default value is a single value
          defaultValue = [valueClass arrayWithObject:defaultValue];
        }
        else if ([valueClass isSubclassOfClass:[NSSet class]] && ![defaultValue isKindOfClass:[NSSet class]])
        {
          //as above, but for NSSet
          defaultValue = [valueClass setWithObject:defaultValue];
        }
        else if ([valueClass isSubclassOfClass:[NSOrderedSet class]] && ![defaultValue isKindOfClass:[NSOrderedSet class]])
        {
          //as above, but for NSOrderedSet
          defaultValue = [valueClass orderedSetWithObject:defaultValue];
        }
        dictionary[FXFormFieldDefaultValue] = defaultValue;
    }
  
    //get field type
    NSString *key = dictionary[FXFormFieldKey];
    if (!type)
    {
        dictionary[FXFormFieldType] = type = FXFormFieldInferType(dictionary);
    }
    
    //convert cell from string to class
    id cellClass = dictionary[FXFormFieldCell];
    if ([cellClass isKindOfClass:[NSString class]])
    {
        dictionary[FXFormFieldCell] = cellClass = FXFormClassFromString(cellClass);
    }
    
    //convert view controller from string to class
    id viewController = dictionary[FXFormFieldViewController];
    if ([viewController isKindOfClass:[NSString class]])
    {
        dictionary[FXFormFieldViewController] = viewController = FXFormClassFromString(viewController);
    }
    
    //convert header from string to class
    id header = dictionary[FXFormFieldHeader];
    if ([header isKindOfClass:[NSString class]])
    {
        Class viewClass = FXFormClassFromString(header);
        if ([viewClass isSubclassOfClass:[UIView class]])
        {
            dictionary[FXFormFieldHeader] = viewClass;
        }
        else
        {
            dictionary[FXFormFieldHeader] = [header copy];
        }
    }
    else if ([header isKindOfClass:[NSNull class]])
    {
        dictionary[FXFormFieldHeader] = @"";
    }

    //convert footer from string to class
    id footer = dictionary[FXFormFieldFooter];
    if ([footer isKindOfClass:[NSString class]])
    {
        Class viewClass = FXFormClassFromString(footer);
        if ([viewClass isSubclassOfClass:[UIView class]])
        {
            dictionary[FXFormFieldFooter] = viewClass;
        }
        else
        {
            dictionary[FXFormFieldFooter] = [footer copy];
        }
    }
    else if ([footer isKindOfClass:[NSNull class]])
    {
        dictionary[FXFormFieldFooter] = @"";
    }
    
    //preprocess template dictionary
    NSDictionary *template = dictionary[FXFormFieldTemplate];
    if (template)
    {
        template = [NSMutableDictionary dictionaryWithDictionary:template];
        FXFormPreprocessFieldDictionary((NSMutableDictionary *)template);
        dictionary[FXFormFieldTemplate] = template;
    }
    
    //derive title from key or selector name
    if (!dictionary[FXFormFieldTitle])
    {
        BOOL wasCapital = YES;
        NSString *keyOrAction = key;
        if (!keyOrAction && [dictionary[FXFormFieldAction] isKindOfClass:[NSString class]])
        {
          keyOrAction = dictionary[FXFormFieldAction];
        }
        NSMutableString *output = nil;
        if (keyOrAction)
        {
            output = [NSMutableString stringWithString:[[keyOrAction substringToIndex:1] uppercaseString]];
            for (NSUInteger j = 1; j < [keyOrAction length]; j++)
            {
                unichar character = [keyOrAction characterAtIndex:j];
                BOOL isCapital = ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:character]);
                if (isCapital && !wasCapital) [output appendString:@" "];
                wasCapital = isCapital;
                if (character != ':') [output appendFormat:@"%C", character];
            }
        }
        if ([output length])
        {
            dictionary[FXFormFieldTitle] = NSLocalizedString(output, nil);
        }
    }
}



@interface FXFormController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, copy) NSArray *sections;
@property (nonatomic, strong) NSMutableDictionary *cellHeightCache;
@property (nonatomic, strong) NSMutableDictionary *cellClassesForFieldTypes;
@property (nonatomic, strong) NSMutableDictionary *cellClassesForFieldClasses;
@property (nonatomic, strong) NSMutableDictionary *controllerClassesForFieldTypes;
@property (nonatomic, strong) NSMutableDictionary *controllerClassesForFieldClasses;

@property (nonatomic, assign) UIEdgeInsets originalTableContentInset;

- (void)performAction:(SEL)selector withSender:(id)sender;
- (UIViewController *)tableViewController;

@end


@interface FXFormField ()

@property (nonatomic, strong) Class valueClass;
@property (nonatomic, strong) Class cellClass;
@property (nonatomic, readwrite) NSString *key;
@property (nonatomic, readwrite) NSArray *options;
@property (nonatomic, readwrite) NSDictionary *fieldTemplate;
@property (nonatomic, readwrite) BOOL isSortable;
@property (nonatomic, readwrite) BOOL isInline;
@property (nonatomic, readonly) id (^valueTransformer)(id input);
@property (nonatomic, readonly) id (^reverseValueTransformer)(id input);
@property (nonatomic, strong) id defaultValue;
@property (nonatomic, strong) id header;
@property (nonatomic, strong) id footer;

@property (nonatomic, weak) FXFormController *formController;
@property (nonatomic, strong) NSMutableDictionary *cellConfig;

+ (NSArray *)fieldsWithForm:(id<FXForm>)form controller:(FXFormController *)formController;
- (instancetype)initWithForm:(id<FXForm>)form controller:(FXFormController *)formController attributes:(NSDictionary *)attributes;

@end


@interface FXFormSection : NSObject

+ (NSArray *)sectionsWithForm:(id<FXForm>)form controller:(FXFormController *)formController;

@property (nonatomic, strong) id<FXForm> form;
@property (nonatomic, strong) id header;
@property (nonatomic, strong) id footer;
@property (nonatomic, strong) NSMutableArray *fields;
@property (nonatomic, assign) BOOL isSortable;

- (void)addNewField;

@end


@implementation FXFormField

+ (NSArray *)fieldsWithForm:(id<FXForm>)form controller:(FXFormController *)formController
{
    //get fields
    NSArray *properties = FXFormProperties(form);
    NSMutableArray *fields = [[form fields] mutableCopy];
    if (!fields)
    {
        //use default fields
        fields = [NSMutableArray arrayWithArray:[properties valueForKey:FXFormFieldKey]];
    }
    
    //add extra fields
    [fields addObjectsFromArray:[form extraFields] ?: @[]];
    
    //process fields
    NSMutableDictionary *fieldDictionariesByKey = [NSMutableDictionary dictionary];
    for (NSDictionary *dict in properties)
    {
        fieldDictionariesByKey[dict[FXFormFieldKey]] = dict;
    }
    
    for (NSInteger i = [fields count] - 1; i >= 0; i--)
    {
        NSMutableDictionary *dictionary = nil;
        id dictionaryOrKey = fields[i];
        if ([dictionaryOrKey isKindOfClass:[NSString class]])
        {
            dictionaryOrKey = @{FXFormFieldKey: dictionaryOrKey};
        }
        if ([dictionaryOrKey isKindOfClass:[NSDictionary class]])
        {
            NSString *key = dictionaryOrKey[FXFormFieldKey];
            if ([[form excludedFields] containsObject:key])
            {
                //skip this field
                [fields removeObjectAtIndex:i];
                continue;
            }
            dictionary = [NSMutableDictionary dictionary];
            [dictionary addEntriesFromDictionary:fieldDictionariesByKey[key]];
            [dictionary addEntriesFromDictionary:dictionaryOrKey];
            NSString *selector = [key stringByAppendingString:@"Field"];
            if (selector && [form respondsToSelector:NSSelectorFromString(selector)])
            {
                [dictionary addEntriesFromDictionary:[(NSObject *)form valueForKey:selector]];
            }
            
            FXFormPreprocessFieldDictionary(dictionary);
        }
        else
        {
            [NSException raise:FXFormsException format:@"Unsupported field type: %@", [dictionaryOrKey class]];
        }
        fields[i] = [[self alloc] initWithForm:form controller:formController attributes:dictionary];
    }
    
    return fields;
}

- (instancetype)init
{
    //this class's contructor is private
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (instancetype)initWithForm:(id<FXForm>)form controller:(FXFormController *)formController attributes:(NSDictionary *)attributes
{
    if ((self = [super init]))
    {
        _form = form;
        _formController = formController;
        if ([form respondsToSelector:@selector(field)]) {
            _cellConfig = ((FXFormField *)[(id)form field]).cellConfig;
        } else {
            _cellConfig = [NSMutableDictionary dictionary];
        }
        [attributes enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, __unused BOOL *stop) {
            [self setValue:value forKey:key];
        }];
    }
    return self;
}

- (BOOL)isIndexedType
{
    //return YES if value should be set as index of option, not value of option
    if ([self.valueClass isSubclassOfClass:[NSNumber class]] && ![self.type isEqualToString:FXFormFieldTypeBitfield])
    {
        return ![[self.options firstObject] isKindOfClass:[NSNumber class]];
    }
    return NO;
}

- (BOOL)isCollectionType
{
    for (Class valueClass in @[[NSArray class], [NSSet class], [NSOrderedSet class], [NSIndexSet class], [NSDictionary class]])
    {
        if ([self.valueClass isSubclassOfClass:valueClass]) return YES;
    }
    return NO;
}

- (BOOL)isOrderedCollectionType
{
    for (Class valueClass in @[[NSArray class], [NSOrderedSet class], [NSIndexSet class]])
    {
        if ([self.valueClass isSubclassOfClass:valueClass]) return YES;
    }
    return NO;
}

- (BOOL)isSubform
{
    return (![self.type isEqualToString:FXFormFieldTypeLabel] &&
            ([self.valueClass conformsToProtocol:@protocol(FXForm)] ||
             [self.valueClass isSubclassOfClass:[UIViewController class]] ||
             self.options || [self isCollectionType] || self.viewController));
}

- (NSString *)valueDescription:(id)value
{
    if (self.valueTransformer)
    {
        return [self.valueTransformer(value) fieldDescription];
    }
    
    if ([value isKindOfClass:[NSDate class]])
    {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        if ([self.type isEqualToString:FXFormFieldTypeDate])
        {
            formatter.dateStyle = NSDateFormatterMediumStyle;
            formatter.timeStyle = NSDateFormatterNoStyle;
        }
        else if ([self.type isEqualToString:FXFormFieldTypeTime])
        {
            formatter.dateStyle = NSDateFormatterNoStyle;
            formatter.timeStyle = NSDateFormatterMediumStyle;
        }
        else //datetime
        {
            formatter.dateStyle = NSDateFormatterShortStyle;
            formatter.timeStyle = NSDateFormatterShortStyle;
        }
        
        return [formatter stringFromDate:value];
    }
    
    return [value fieldDescription];
}

- (NSString *)fieldDescription
{
    NSString *descriptionKey = [self.key stringByAppendingString:@"FieldDescription"];
    if (descriptionKey && [self.form respondsToSelector:NSSelectorFromString(descriptionKey)])
    {
        return [(id)self.form valueForKey:descriptionKey];
    }
    
    if (self.options)
    {
        if ([self isIndexedType])
        {
            if (self.value)
            {
                return [self optionDescriptionAtIndex:[self.value integerValue] + (self.placeholder? 1: 0)];
            }
            else
            {
                return [self.placeholder fieldDescription];
            }
        }
      
        if ([self isCollectionType])
        {
            id value = self.value;
            if ([value isKindOfClass:[NSIndexSet class]])
            {
                NSMutableArray *options = [NSMutableArray array];
                [self.options enumerateObjectsUsingBlock:^(id option, NSUInteger i, __unused BOOL *stop) {
                    NSUInteger index = i;
                    if ([option isKindOfClass:[NSNumber class]])
                    {
                        index = [option integerValue];
                    }
                    if ([value containsIndex:index])
                    {
                        NSString *description = [self optionDescriptionAtIndex:i + (self.placeholder? 1: 0)];
                        if ([description length]) [options addObject:description];
                    }
                }];
                
                value = [options count]? options: nil;
            }
            else if (value && self.valueTransformer)
            {
                NSMutableArray *options = [NSMutableArray array];
                for (id option in value) {
                  [options addObject:self.valueTransformer(option)];
                }
                value = [options count]? options: nil;
            }
          
            return [value fieldDescription] ?: [self.placeholder fieldDescription];
        }
        else if ([self.type isEqual:FXFormFieldTypeBitfield])
        {
            NSUInteger value = [self.value integerValue];
            NSMutableArray *options = [NSMutableArray array];
            [self.options enumerateObjectsUsingBlock:^(id option, NSUInteger i, __unused BOOL *stop) {
                NSUInteger bit = 1 << i;
                if ([option isKindOfClass:[NSNumber class]])
                {
                    bit = [option integerValue];
                }
                if (value & bit)
                {
                    NSString *description = [self optionDescriptionAtIndex:i + (self.placeholder? 1: 0)];
                    if ([description length]) [options addObject:description];
                }
            }];
            
            return [options count]? [options fieldDescription]: [self.placeholder fieldDescription];
        }
        else if (self.placeholder && ![self.options containsObject:self.value])
        {
            return [self.placeholder description];
        }
    }
    
    return [self valueDescription:self.value];
}

- (id)valueForUndefinedKey:(NSString *)key
{
    return _cellConfig[key];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
    _cellConfig[key] = value;
}

- (id)valueWithoutDefaultSubstitution
{
    if (FXFormCanGetValueForKey(self.form, self.key))
    {
        id value = [(NSObject *)self.form valueForKey:self.key];
        if (value && self.options)
        {
            if ([self isIndexedType])
            {
                if ([value unsignedIntegerValue] >= [self.options count]) value = nil;
            }
            else if (![self isCollectionType] && ![self.type isEqualToString:FXFormFieldTypeBitfield])
            {
                //TODO: should we validate collection types too, or is that overkill?
                if (![self.options containsObject:value]) value = nil;
            }
        }
        return value;
    }
    return nil;
}

- (id)value
{
    if (FXFormCanGetValueForKey(self.form, self.key))
    {
        id value = [(NSObject *)self.form valueForKey:self.key];
        if (value && self.options)
        {
            if ([self isIndexedType])
            {
                if ([value unsignedIntegerValue] >= [self.options count]) value = nil;
            }
            else if (![self isCollectionType] && ![self.type isEqualToString:FXFormFieldTypeBitfield])
            {
                //TODO: should we validate collection types too, or is that overkill?
                if (![self.options containsObject:value]) value = nil;
            }
        }
        if (!value && self.defaultValue)
        {
            self.value = value = self.defaultValue;
        }
        return value;
    }
    return self.defaultValue;
}

- (void)setValue:(id)value
{
    if (FXFormCanSetValueForKey(self.form, self.key))
    {
        //use default value if available
        value = value ?: self.defaultValue;
        
        if (self.reverseValueTransformer && ![self isCollectionType] && !self.options)
        {
            value = self.reverseValueTransformer(value);
        }
        else if ([value isKindOfClass:[NSString class]])
        {
            if ([self.type isEqualToString:FXFormFieldTypeNumber] ||
                [self.type isEqualToString:FXFormFieldTypeFloat])
            {
                value = [(NSString *)value length]? @([value doubleValue]): nil;
            }
            else if ([self.type isEqualToString:FXFormFieldTypeInteger] ||
                     [self.type isEqualToString:FXFormFieldTypeUnsigned])
            {
                //NOTE: unsignedLongLongValue doesn't exist on NSString
                value = [(NSString *)value length]? @([value longLongValue]): nil;
            }
            else if ([self.valueClass isSubclassOfClass:[NSURL class]])
            {
                value = [self.valueClass URLWithString:value];
            }
        }
        else if ([self.valueClass isSubclassOfClass:[NSString class]])
        {
            //handle case where value is numeric but value class is string
            value = [value description];
        }
      
        if (self.valueClass == [NSMutableString class])
        {
            //replace string or make mutable copy of it
            id _value = [self valueWithoutDefaultSubstitution];
            if (_value)
            {
                [(NSMutableString *)_value setString:value];
                value = _value;
            }
            else
            {
                value = [NSMutableString stringWithString:value];
            }
        }
      
        if (!value)
        {
            for (NSDictionary *field in FXFormProperties(self.form))
            {
                if ([field[FXFormFieldKey] isEqualToString:self.key])
                {
                    if ([@[FXFormFieldTypeBoolean, FXFormFieldTypeInteger,
                           FXFormFieldTypeUnsigned, FXFormFieldTypeFloat] containsObject:field[FXFormFieldType]])
                    {
                        //prevents NSInvalidArgumentException in setNilValueForKey: method
                        value = [self isIndexedType]? @(NSNotFound): @0;
                    }
                    break;
                }
            }
        }
        
        [(NSObject *)self.form setValue:value forKey:self.key];
    }
}

- (void)setValueTransformer:(id)valueTransformer
{
    if ([valueTransformer isKindOfClass:[NSString class]])
    {
        valueTransformer = FXFormClassFromString(valueTransformer);
    }
    if ([valueTransformer class] == valueTransformer)
    {
        valueTransformer = [[valueTransformer alloc] init];
    }
    if ([valueTransformer isKindOfClass:[NSValueTransformer class]])
    {
        NSValueTransformer *transformer = valueTransformer;
        valueTransformer = ^(id input)
        {
            return [transformer transformedValue:input];
        };
        if ([[transformer class] allowsReverseTransformation])
        {
            _reverseValueTransformer = ^(id input)
            {
                return [transformer reverseTransformedValue:input];
            };
        }
    }
    
    _valueTransformer = [valueTransformer copy];
}

- (void)setAction:(id)action
{
    if ([action isKindOfClass:[NSString class]])
    {
        SEL selector = NSSelectorFromString(action);
        __weak FXFormField *weakSelf = self;
        action = ^(id sender)
        {
            [weakSelf.formController performAction:selector withSender:sender];
        };
    }
    
    _action = [action copy];
}

- (void)setSegue:(id)segue
{
    if ([segue isKindOfClass:[NSString class]])
    {
        segue = FXFormClassFromString(segue) ?: [segue copy];
    }
    
    NSAssert(segue != [UIStoryboardPopoverSegue class], @"Unfortunately displaying subcontrollers using UIStoryboardPopoverSegue is not supported, as doing so would require calling private methods. To display using a popover, create a custom UIStoryboard subclass instead.");
    
    _segue = segue;
}

- (void)setClass:(Class)valueClass
{
    _valueClass = valueClass;
}

- (void)setCell:(Class)cellClass
{
    _cellClass = cellClass;
}

- (void)setDefault:(id)defaultValue
{
    _defaultValue = defaultValue;
}

- (void)setInline:(BOOL)isInline
{
    _isInline = isInline;
}

- (void)setOptions:(NSArray *)options
{
    _options = [options count]? [options copy]: nil;
}

- (void)setTemplate:(NSDictionary *)template
{
    _fieldTemplate = [template copy];
}

- (void)setSortable:(BOOL)sortable
{
    _isSortable = sortable;
}

- (void)setHeader:(id)header
{
    if ([header class] == header)
    {
        header = [[header alloc] init];
    }
    _header = header;
}

- (void)setFooter:(id)footer
{
    if ([footer class] == footer)
    {
        footer = [[footer alloc] init];
    }
    _footer = footer;
}

- (BOOL)isSortable
{
    return _isSortable &&
    ([self.valueClass isSubclassOfClass:[NSArray class]] ||
    [self.valueClass isSubclassOfClass:[NSOrderedSet class]]);
}

#pragma mark -
#pragma mark Option helpers

- (NSUInteger)optionCount
{
    NSUInteger count = [self.options count];
    return count? count + (self.placeholder? 1: 0): 0;
}

- (id)optionAtIndex:(NSUInteger)index
{
    if (index == 0)
    {
        return self.placeholder ?: self.options[0];
    }
    else
    {
        return self.options[index - (self.placeholder? 1: 0)];
    }
}

- (NSUInteger)indexOfOption:(id)option
{
    NSUInteger index = [self.options indexOfObject:option];
    if (index == NSNotFound)
    {
        return self.placeholder? 0: NSNotFound;
    }
    else
    {
        return index + (self.placeholder? 1: 0);
    }
}

- (NSString *)optionDescriptionAtIndex:(NSUInteger)index
{
    if (index == 0)
    {
        return self.placeholder? [self.placeholder fieldDescription]: [self valueDescription:self.options[0]];
    }
    else
    {
        return [self valueDescription:self.options[index - (self.placeholder? 1: 0)]];
    }
}

- (void)setOptionSelected:(BOOL)selected atIndex:(NSUInteger)index
{
    if (self.placeholder)
    {
        index = (index == 0)? NSNotFound: index - 1;
    }
    
    if ([self isCollectionType])
    {
        BOOL copyNeeded = ([NSStringFromClass(self.valueClass) rangeOfString:@"Mutable"].location == NSNotFound);
        
        id collection = self.value ?: [[self.valueClass alloc] init];
        if (copyNeeded) collection = [collection mutableCopy];
        
        if (index == NSNotFound)
        {
            collection = nil;
        }
        else if ([self.valueClass isSubclassOfClass:[NSIndexSet class]])
        {
            if (selected)
            {
                [collection addIndex:index];
            }
            else
            {
                [collection removeIndex:index];
            }
        }
        else if ([self.valueClass isSubclassOfClass:[NSDictionary class]])
        {
            if (selected)
            {
                collection[@(index)] = self.options[index];
            }
            else
            {
                [(NSMutableDictionary *)collection removeObjectForKey:@(index)];
            }
        }
        else
        {
            //need to preserve order for ordered collections
            [collection removeAllObjects];
            [self.options enumerateObjectsUsingBlock:^(id option, NSUInteger i, __unused BOOL *stop) {
                
                if (i == index)
                {
                    if (selected) [collection addObject:option];
                }
                else if ([self.value containsObject:option])
                {
                    [collection addObject:option];
                }
            }];
        }
        
        if (copyNeeded) collection = [collection copy];
        self.value = collection;
    }
    else if ([self.type isEqualToString:FXFormFieldTypeBitfield])
    {
        if (index == NSNotFound)
        {
            self.value = @0;
        }
        else
        {
            if ([self.options[index] isKindOfClass:[NSNumber class]])
            {
                index = [self.options[index] integerValue];
            }
            else
            {
                index = 1 << index;
            }
            if (selected)
            {
                self.value = @([self.value integerValue] | index);
            }
            else
            {
                self.value = @([self.value integerValue] ^ index);
            }
        }
    }
    else if ([self isIndexedType])
    {
        if (selected)
        {
            self.value = @(index);
        }
        //cannot deselect
    }
    else if (index != NSNotFound)
    {
        if (selected)
        {
            self.value = self.options[index];
        }
        //cannot deselect
    }
    else
    {
        self.value = nil;
    }
}

- (BOOL)isOptionSelectedAtIndex:(NSUInteger)index
{
    if (self.placeholder)
    {
        index = (index == 0)? NSNotFound: index - 1;
    }

    id option = (index == NSNotFound)? nil: self.options[index];
    if ([self isCollectionType])
    {
        if (index == NSNotFound)
        {
            //true if no option selected
            return [(NSArray *)self.value count] == 0;
        }
        else if ([self.valueClass isSubclassOfClass:[NSIndexSet class]])
        {
            if ([option isKindOfClass:[NSNumber class]])
            {
                index = [option integerValue];
            }
            return [(NSIndexSet *)self.value containsIndex:index];
        }
        else
        {
            return [(NSArray *)self.value containsObject:option];
        }
    }
    else if ([self.type isEqualToString:FXFormFieldTypeBitfield])
    {
        if (index == NSNotFound)
        {
            //true if not numeric
            return ![self.value integerValue];
        }
        else if ([option isKindOfClass:[NSNumber class]])
        {
            index = [option integerValue];
        }
        else
        {
            index = 1 << index;
        }
        return ([self.value integerValue] & index) != 0;
    }
    else if ([self isIndexedType])
    {
        return self.value? [self.value unsignedIntegerValue] == index: !option;
    }
    else
    {
        return option? [option isEqual:self.value]: !self.value;
    }
}

@end


@interface FXOptionsForm : NSObject <FXForm>

@property (nonatomic, strong) FXFormField *field;
@property (nonatomic, strong) NSArray *fields;

@end


@implementation FXOptionsForm

- (instancetype)initWithField:(FXFormField *)field
{
    if ((self = [super init]))
    {
        _field = field;
        id action = ^(__unused id sender)
        {
            if (field.action)
            {
                //this nasty hack is necessary to pass the expected cell as the sender
                FXFormController *formController = field.formController;
                [formController enumerateFieldsWithBlock:^(FXFormField *f, NSIndexPath *indexPath) {
                    if ([f.key isEqual:field.key])
                    {
                        field.action([formController.tableView cellForRowAtIndexPath:indexPath]);
                    }
                }];
            }
        };
        NSMutableArray *fields = [NSMutableArray array];
        if (field.placeholder)
        {
            [fields addObject:@{FXFormFieldKey: @"0",
                                FXFormFieldTitle: [field.placeholder fieldDescription],
                                FXFormFieldType: FXFormFieldTypeOption,
                                FXFormFieldAction: action}];
        }
        for (NSUInteger i = 0; i < [field.options count]; i++)
        {
            NSInteger index = i + (field.placeholder? 1: 0);
            [fields addObject:@{FXFormFieldKey: [@(index) description],
                                FXFormFieldTitle: [field optionDescriptionAtIndex:index],
                                FXFormFieldType: FXFormFieldTypeOption,
                                FXFormFieldAction: action}];
        }
        _fields = fields;
    }
    return self;
}

- (id)valueForKey:(NSString *)key
{
    NSInteger index = [key integerValue];
    return @([self.field isOptionSelectedAtIndex:index]);
}

- (void)setValue:(id)value forKey:(NSString *)key
{
    NSUInteger index = [key integerValue];
    [self.field setOptionSelected:[value boolValue] atIndex:index];
}

- (BOOL)respondsToSelector:(SEL)selector
{
    if ([NSStringFromSelector(selector) hasPrefix:@"set"])
    {
        return YES;
    }
    return [super respondsToSelector:selector];
}

@end


@interface FXTemplateForm : NSObject <FXForm>

@property (nonatomic, strong) FXFormField *field;
@property (nonatomic, strong) NSMutableArray *fields;
@property (nonatomic, strong) NSMutableArray *values;

@end


@implementation FXTemplateForm

- (instancetype)initWithField:(FXFormField *)field
{
    if ((self = [super init]))
    {
        _field = field;
        _fields = [NSMutableArray array];
        _values = [NSMutableArray array];
        [self updateFields];
    }
    return self;
}

- (NSMutableDictionary *)newFieldDictionary
{
    //TODO: is there a better way to handle default template fallback?
    //TODO: can we infer default template from existing values instead of having string fallback?
    NSMutableDictionary *field = [NSMutableDictionary dictionaryWithDictionary:self.field.fieldTemplate];
    FXFormPreprocessFieldDictionary(field);
    field[FXFormFieldTitle] = @""; // title is used for the "Add Item" button, not each field
    return field;
}

- (void)updateFields
{
    //set fields
    [self.fields removeAllObjects];
    NSUInteger count = [(NSArray *)self.field.value count];
    for (NSUInteger i = 0; i < count; i++)
    {
        //TODO: do we need to do something special with the action to ensure the
        //correct cell is passed as the sender, as we do for options fields?
        NSMutableDictionary *field = [self newFieldDictionary];
        field[FXFormFieldKey] = [@(i) description];
        [_fields addObject:field];
    }
    
    //create add button
    NSString *addButtonTitle = self.field.fieldTemplate[FXFormFieldTitle] ?: NSLocalizedString(@"Add Item", nil);
    [_fields addObject:@{FXFormFieldTitle: addButtonTitle,
                         FXFormFieldCell: [FXFormDefaultCell class],
                         @"textLabel.textAlignment": @(NSTextAlignmentLeft),
                         FXFormFieldAction: ^(UITableViewCell<FXFormFieldCell> *cell) {
        
        FXFormField *field = cell.field;
        FXFormController *formController = field.formController;
        UITableView *tableView = formController.tableView;
        
        [tableView beginUpdates];
        
        NSIndexPath *indexPath = [tableView indexPathForCell:cell];
        FXFormSection *section = formController.sections[indexPath.section];
        [section addNewField];

        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        
        [tableView endUpdates];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [formController tableView:tableView didSelectRowAtIndexPath:indexPath];
            [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        });
        
    }}];
    
    //converts values to an ordered array
    if ([self.field.valueClass isSubclassOfClass:[NSIndexSet class]])
    {
        [self.fields removeAllObjects];
        [(NSIndexSet *)self.field.value enumerateIndexesUsingBlock:^(NSUInteger idx, __unused BOOL *stop) {
            [self.fields addObject:@(idx)];
        }];
    }
    else if ([self.field.valueClass isSubclassOfClass:[NSArray class]])
    {
        [self.values setArray:self.field.value];
    }
    else
    {
        [self.values setArray:[self.field.value allValues]];
    }
}

- (void)updateFormValue
{
    //create collection of correct type
    BOOL copyNeeded = ([NSStringFromClass(self.field.valueClass) rangeOfString:@"Mutable"].location == NSNotFound);
    id collection = [[self.field.valueClass alloc] init];
    if (copyNeeded) collection = [collection mutableCopy];
    
    //convert values back to original type
    if ([self.field.valueClass isSubclassOfClass:[NSIndexSet class]])
    {
        for (id object in self.values)
        {
            [collection addIndex:[object integerValue]];
        }
    }
    else if ([self.field.valueClass isSubclassOfClass:[NSDictionary class]])
    {
        [self.values enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, __unused BOOL *stop) {
            collection[@(idx)] = obj;
        }];
    }
    else
    {
        [collection addObjectsFromArray:self.values];
    }
    
    //set field value
    if (copyNeeded) collection = [collection copy];
    self.field.value = collection;
}

- (id)valueForKey:(NSString *)key
{
    NSUInteger index = [key integerValue];
    if (index != NSNotFound)
    {
        id value = self.values[index];
        if (value != [NSNull null])
        {
            return value;
        }
    }
    return nil;
}

- (void)setValue:(id)value forKey:(NSString *)key
{
    //set value
    if (!value) value = [NSNull null];
    NSUInteger index = [key integerValue];
    if (index >= [self.values count])
    {
        [self.values addObject:value];
    }
    else
    {
        self.values[index] = value;
    }
    [self updateFormValue];
}

- (void)addNewField
{
    NSUInteger index = [self.values count];
    NSMutableDictionary *field = [self newFieldDictionary];
    field[FXFormFieldKey] = [@(index) description];
    [self.fields insertObject:field atIndex:index];
    [self.values addObject:[NSNull null]];
}

- (void)removeFieldAtIndex:(NSUInteger)index
{
    [self.fields removeObjectAtIndex:index];
    [self.values removeObjectAtIndex:index];
    for (NSUInteger i = index; i < [self.values count]; i++)
    {
        self.fields[index][FXFormFieldKey] = [@(i) description];
    }
    [self updateFormValue];
}

- (void)moveFieldAtIndex:(NSUInteger)index1 toIndex:(NSUInteger)index2
{
    NSMutableDictionary *field = self.fields[index1];
    [self.fields removeObjectAtIndex:index1];

    id value = self.values[index1];
    [self.values removeObjectAtIndex:index1];
    
    if (index2 >= [self.fields count])
    {
        [self.fields addObject:field];
        [self.values addObject:value];
    }
    else
    {
        [self.fields insertObject:field atIndex:index2];
        [self.values insertObject:value atIndex:index2];
    }
    
    for (NSUInteger i = MIN(index1, index2); i < [self.values count]; i++)
    {
        self.fields[i][FXFormFieldKey] = [@(i) description];
    }
    
    [self updateFormValue];
}

- (BOOL)respondsToSelector:(SEL)selector
{
    if ([NSStringFromSelector(selector) hasPrefix:@"set"])
    {
        return YES;
    }
    return [super respondsToSelector:selector];
}

@end


@implementation FXFormSection

+ (NSArray *)sectionsWithForm:(id<FXForm>)form controller:(FXFormController *)formController
{
    NSMutableArray *sections = [NSMutableArray array];
    FXFormSection *section = nil;
    for (FXFormField *field in [FXFormField fieldsWithForm:form controller:formController])
    {
        id<FXForm> subform = nil;
        if (field.options && field.isInline)
        {
            subform = [[FXOptionsForm alloc] initWithField:field];
        }
        else if ([field isCollectionType] && field.isInline)
        {
            subform = [[FXTemplateForm alloc] initWithField:field];
        }
        else if ([field.valueClass conformsToProtocol:@protocol(FXForm)] && field.isInline)
        {
            if (!field.value && [field respondsToSelector:@selector(init)] &&
                ![field.valueClass isSubclassOfClass:FXFormClassFromString(@"NSManagedObject")])
            {
                //create a new instance of the form automatically
                field.value = [[field.valueClass alloc] init];
            }
            subform = field.value;
        }
        
        if (subform)
        {
            NSArray *subsections = [FXFormSection sectionsWithForm:subform controller:formController];
            [sections addObjectsFromArray:subsections];
            
            section = [subsections firstObject];
            if (!section.header) section.header = field.header ?: field.title;
            section.isSortable = field.isSortable;
            section = nil;
        }
        else
        {
            if (!section || field.header)
            {
                section = [[FXFormSection alloc] init];
                section.form = form;
                section.header = field.header;
                section.isSortable = ([form isKindOfClass:[FXTemplateForm class]] && ((FXTemplateForm *)form).field.isSortable);
                [sections addObject:section];
            }
            [section.fields addObject:field];
            if (field.footer)
            {
                section.footer = field.footer;
                section = nil;
            }
        }
    }
    return sections;
}

- (NSMutableArray *)fields
{
    if (!_fields)
    {
        _fields = [NSMutableArray array];
    }
    return _fields;
}

- (void)addNewField
{
    FXFormController *controller = [[_fields lastObject] formController];
    [(FXTemplateForm *)self.form addNewField];
    [_fields setArray:[FXFormField fieldsWithForm:self.form controller:controller]];
}

- (void)removeFieldAtIndex:(NSUInteger)index
{
    FXFormController *controller = [[_fields lastObject] formController];
    [(FXTemplateForm *)self.form removeFieldAtIndex:index];
    [_fields setArray:[FXFormField fieldsWithForm:self.form controller:controller]];
}

- (void)moveFieldAtIndex:(NSUInteger)index1 toIndex:(NSUInteger)index2
{
    FXFormController *controller = [[_fields lastObject] formController];
    [(FXTemplateForm *)self.form moveFieldAtIndex:index1 toIndex:index2];
    [_fields setArray:[FXFormField fieldsWithForm:self.form controller:controller]];
}

@end


@implementation NSObject (FXForms)

- (NSString *)fieldDescription
{
    for (Class fieldClass in @[[NSString class], [NSNumber class], [NSDate class]])
    {
        if ([self isKindOfClass:fieldClass])
        {
            return [self description];
        }
    }
    for (Class fieldClass in @[[NSDictionary class], [NSArray class], [NSSet class], [NSOrderedSet class]])
    {
        if ([self isKindOfClass:fieldClass])
        {
            id collection = self;
            if (fieldClass == [NSDictionary class])
            {
                collection = [collection allValues];
            }
            NSMutableArray *array = [NSMutableArray array];
            for (id object in collection)
            {
                NSString *description = [object fieldDescription];
                if ([description length]) [array addObject:description];
            }
            return [array componentsJoinedByString:@", "];
        }
    }
    if ([self isKindOfClass:[NSDate class]])
    {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterShortStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        return [formatter stringFromDate:(NSDate *)self];
    }
    return @"";
}

- (NSArray *)fields
{
    return nil;
}

- (NSArray *)extraFields
{
    return nil;
}

- (NSArray *)excludedFields
{
    return nil;
}

@end


#pragma mark -
#pragma mark Controllers


@implementation FXFormController

- (instancetype)init
{
    if ((self = [super init]))
    {
        _cellHeightCache = [NSMutableDictionary dictionary];
        _cellClassesForFieldTypes = [@{FXFormFieldTypeDefault: [FXFormDefaultCell class],
                                       FXFormFieldTypeText: [FXFormTextFieldCell class],
                                       FXFormFieldTypeLongText: [FXFormTextViewCell class],
                                       FXFormFieldTypeURL: [FXFormTextFieldCell class],
                                       FXFormFieldTypeEmail: [FXFormTextFieldCell class],
                                       FXFormFieldTypePhone: [FXFormTextFieldCell class],
                                       FXFormFieldTypePassword: [FXFormTextFieldCell class],
                                       FXFormFieldTypeNumber: [FXFormTextFieldCell class],
                                       FXFormFieldTypeFloat: [FXFormTextFieldCell class],
                                       FXFormFieldTypeInteger: [FXFormTextFieldCell class],
                                       FXFormFieldTypeUnsigned: [FXFormTextFieldCell class],
                                       FXFormFieldTypeBoolean: [FXFormSwitchCell class],
                                       FXFormFieldTypeDate: [FXFormDatePickerCell class],
                                       FXFormFieldTypeTime: [FXFormDatePickerCell class],
                                       FXFormFieldTypeDateTime: [FXFormDatePickerCell class],
                                       FXFormFieldTypeImage: [FXFormImagePickerCell class]} mutableCopy];
        _cellClassesForFieldClasses = [NSMutableDictionary dictionary];
        _controllerClassesForFieldTypes = [@{FXFormFieldTypeDefault: [FXFormViewController class]} mutableCopy];
        _controllerClassesForFieldClasses = [NSMutableDictionary dictionary];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardDidShow:)
                                                     name:UIKeyboardDidShowNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillHide:)
                                                     name:UIKeyboardWillHideNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    _tableView.dataSource = nil;
    _tableView.delegate = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (Class)cellClassForField:(FXFormField *)field
{
    if (field.type != FXFormFieldTypeDefault)
    {
        return self.cellClassesForFieldTypes[field.type] ?:
        self.parentFormController.cellClassesForFieldTypes[field.type] ?:
        self.cellClassesForFieldTypes[FXFormFieldTypeDefault];
    }
    else
    {
        Class valueClass = field.valueClass;
        while (valueClass && valueClass != [NSObject class])
        {
            Class cellClass = self.cellClassesForFieldClasses[NSStringFromClass(valueClass)] ?:
            self.parentFormController.cellClassesForFieldClasses[NSStringFromClass(valueClass)];
            if (cellClass)
            {
                return cellClass;
            }
            valueClass = [valueClass superclass];
        }
        return self.cellClassesForFieldTypes[FXFormFieldTypeDefault];
    }
}

- (void)registerDefaultFieldCellClass:(Class)cellClass
{
    NSParameterAssert([cellClass conformsToProtocol:@protocol(FXFormFieldCell)]);
    [self.cellClassesForFieldTypes setDictionary:@{FXFormFieldTypeDefault: cellClass}];
}

- (void)registerCellClass:(Class)cellClass forFieldType:(NSString *)fieldType
{
    NSParameterAssert([cellClass conformsToProtocol:@protocol(FXFormFieldCell)]);
    self.cellClassesForFieldTypes[fieldType] = cellClass;
}

- (void)registerCellClass:(Class)cellClass forFieldClass:(__unsafe_unretained Class)fieldClass
{
    NSParameterAssert([cellClass conformsToProtocol:@protocol(FXFormFieldCell)]);
    self.cellClassesForFieldClasses[NSStringFromClass(fieldClass)] = cellClass;
}

- (Class)viewControllerClassForField:(FXFormField *)field
{
    if (field.type != FXFormFieldTypeDefault)
    {
        return self.controllerClassesForFieldTypes[field.type] ?:
        self.parentFormController.controllerClassesForFieldTypes[field.type] ?:
        self.controllerClassesForFieldTypes[FXFormFieldTypeDefault];
    }
    else
    {
        Class valueClass = field.valueClass;
        while (valueClass != [NSObject class])
        {
            Class controllerClass = self.controllerClassesForFieldClasses[NSStringFromClass(valueClass)] ?:
            self.parentFormController.controllerClassesForFieldClasses[NSStringFromClass(valueClass)];
            if (controllerClass)
            {
                return controllerClass;
            }
            valueClass = [valueClass superclass];
        }
        return self.controllerClassesForFieldTypes[FXFormFieldTypeDefault];
    }
}

- (void)registerDefaultViewControllerClass:(Class)controllerClass
{
    NSParameterAssert([controllerClass conformsToProtocol:@protocol(FXFormFieldViewController)]);
    [self.controllerClassesForFieldTypes setDictionary:@{FXFormFieldTypeDefault: controllerClass}];
}

- (void)registerViewControllerClass:(Class)controllerClass forFieldType:(NSString *)fieldType
{
    NSParameterAssert([controllerClass conformsToProtocol:@protocol(FXFormFieldViewController)]);
    self.controllerClassesForFieldTypes[fieldType] = controllerClass;
}

- (void)registerViewControllerClass:(Class)controllerClass forFieldClass:(__unsafe_unretained Class)fieldClass
{
    NSParameterAssert([controllerClass conformsToProtocol:@protocol(FXFormFieldViewController)]);
    self.controllerClassesForFieldClasses[NSStringFromClass(fieldClass)] = controllerClass;
}

- (void)setDelegate:(id<FXFormControllerDelegate>)delegate
{
    _delegate = delegate;
    
    //force table to update respondsToSelector: cache
    self.tableView.delegate = nil;
    self.tableView.delegate = self;
}

- (BOOL)respondsToSelector:(SEL)selector
{
    return [super respondsToSelector:selector] || [self.delegate respondsToSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    [invocation invokeWithTarget:self.delegate];
}

- (void)setTableView:(UITableView *)tableView
{
    _tableView = tableView;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.editing = YES;
    self.tableView.allowsSelectionDuringEditing = YES;
    [self.tableView reloadData];
}

- (UIViewController *)tableViewController
{
    id responder = self.tableView;
    while (responder)
    {
        if ([responder isKindOfClass:[UIViewController class]])
        {
            return responder;
        }
        responder = [responder nextResponder];
    }
    return nil;
}

- (void)setForm:(id<FXForm>)form
{
    _form = form;
    self.sections = [FXFormSection sectionsWithForm:form controller:self];
}

- (NSUInteger)numberOfSections
{
    return [self.sections count];
}

- (FXFormSection *)sectionAtIndex:(NSUInteger)index
{
    return self.sections[index];
}

- (NSUInteger)numberOfFieldsInSection:(NSUInteger)index
{
    return [[self sectionAtIndex:index].fields count];
}

- (FXFormField *)fieldForIndexPath:(NSIndexPath *)indexPath
{
    return [self sectionAtIndex:indexPath.section].fields[indexPath.row];
}

- (NSIndexPath *)indexPathForField:(FXFormField *)field
{
    NSUInteger sectionIndex = 0;
    for (FXFormSection *section in self.sections)
    {
        NSUInteger fieldIndex = [section.fields indexOfObject:field];
        if (fieldIndex != NSNotFound)
        {
            return [NSIndexPath indexPathForRow:fieldIndex inSection:sectionIndex];
        }
        sectionIndex ++;
    }
    return nil;
}

- (void)enumerateFieldsWithBlock:(void (^)(FXFormField *field, NSIndexPath *indexPath))block
{
    NSUInteger sectionIndex = 0;
    for (FXFormSection *section in self.sections)
    {
        NSUInteger fieldIndex = 0;
        for (FXFormField *field in section.fields)
        {
            block(field, [NSIndexPath indexPathForRow:fieldIndex inSection:sectionIndex]);
            fieldIndex ++;
        }
        sectionIndex ++;
    }
}

#pragma mark -
#pragma mark Action handler

- (void)performAction:(SEL)selector withSender:(id)sender
{
    //walk up responder chain
    id responder = self.tableView;
    while (responder)
    {
        if ([responder respondsToSelector:selector])
        {
            
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            
            [responder performSelector:selector withObject:sender];
            
#pragma clang diagnostic pop
            
            return;
        }
        responder = [responder nextResponder];
    }
    
    //trye parent controller
    if (self.parentFormController)
    {
        [self.parentFormController performAction:selector withSender:sender];
    }
    else
    {
        [NSException raise:FXFormsException format:@"No object in the responder chain responds to the selector %@", NSStringFromSelector(selector)];
    }
}

#pragma mark -
#pragma mark Datasource methods

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView
{
    return [self numberOfSections];
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForHeaderInSection:(NSInteger)index
{
    return [[self sectionAtIndex:index].header description];
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForFooterInSection:(NSInteger)index
{
    return [[self sectionAtIndex:index].footer description];
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)index
{
    return [self numberOfFieldsInSection:index];
}

- (UITableViewCell *)cellForField:(FXFormField *)field
{
    //don't recycle cells - it would make things complicated
    Class cellClass = field.cellClass ?: [self cellClassForField:field];
    NSString *nibName = NSStringFromClass(cellClass);
    if ([nibName rangeOfString:@"."].location != NSNotFound) {
        nibName = nibName.pathExtension; //Removes Swift namespace
    }
    if ([[NSBundle mainBundle] pathForResource:nibName ofType:@"nib"])
    {
        //load cell from nib
        return [[[NSBundle mainBundle] loadNibNamed:nibName owner:nil options:nil] firstObject];
    }
    else
    {
        //hackity-hack-hack
        UITableViewCellStyle style = UITableViewCellStyleDefault;
        if ([field valueForKey:@"style"])
        {
            style = [[field valueForKey:@"style"] integerValue];
        }
        else if (FXFormCanGetValueForKey(field.form, field.key))
        {
            style = UITableViewCellStyleValue1;
        }

        //don't recycle cells - it would make things complicated
        return [[cellClass alloc] initWithStyle:style reuseIdentifier:NSStringFromClass(cellClass)];
    }
}

- (CGFloat)tableView:(__unused UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    FXFormField *field = [self fieldForIndexPath:indexPath];
    Class cellClass = field.cellClass ?: [self cellClassForField:field];
    if ([cellClass respondsToSelector:@selector(heightForField:width:)])
    {
        return [cellClass heightForField:field width:self.tableView.frame.size.width];
    }

    NSString *className = NSStringFromClass(cellClass);
    NSNumber *cachedHeight = _cellHeightCache[className];
    if (!cachedHeight)
    {
        UITableViewCell *cell = [self cellForField:field];
        cachedHeight = @(cell.bounds.size.height);
        _cellHeightCache[className] = cachedHeight;
    }

    return [cachedHeight floatValue];
}

- (UITableViewCell *)tableView:(__unused UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self cellForField:[self fieldForIndexPath:indexPath]];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        [tableView beginUpdates];
        
        FXFormSection *section = [self sectionAtIndex:indexPath.section];
        [section removeFieldAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        
        [tableView endUpdates];
    }
}

- (void)tableView:(__unused UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    FXFormSection *section = [self sectionAtIndex:sourceIndexPath.section];
    [section moveFieldAtIndex:sourceIndexPath.row toIndex:destinationIndexPath.row];
}

- (NSIndexPath *)tableView:(__unused UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath
{
    FXFormSection *section = [self sectionAtIndex:sourceIndexPath.section];
    if (sourceIndexPath.section == proposedDestinationIndexPath.section &&
        proposedDestinationIndexPath.row < (NSInteger)[section.fields count] - 1)
    {
        return proposedDestinationIndexPath;
    }
    return sourceIndexPath;
}

- (BOOL)tableView:(__unused UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    FXFormSection *section = [self sectionAtIndex:indexPath.section];
    if ([section.form isKindOfClass:[FXTemplateForm class]])
    {
        if (indexPath.row < (NSInteger)[section.fields count] - 1)
        {
            FXFormField *field = ((FXTemplateForm *)section.form).field;
            return [field isOrderedCollectionType] && field.isSortable;
        }
    }
    return NO;
}

#pragma mark -
#pragma mark Delegate methods

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)index
{
    //forward to delegate
    if ([self.delegate respondsToSelector:_cmd])
    {
        return [self.delegate tableView:tableView viewForHeaderInSection:index];
    }
    
    //handle view or class
    id header = [self sectionAtIndex:index].header;
    if ([header isKindOfClass:[UIView class]])
    {
        return header;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)index
{
    //forward to delegate
    if ([self.delegate respondsToSelector:_cmd])
    {
        return [self.delegate tableView:tableView heightForHeaderInSection:index];
    }
    
    //handle view or class
    UIView *header = [self sectionAtIndex:index].header;
    if ([header isKindOfClass:[UIView class]])
    {
        return header.frame.size.height ?: UITableViewAutomaticDimension;
    }
    return UITableViewAutomaticDimension;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)index
{
    //forward to delegate
    if ([self.delegate respondsToSelector:_cmd])
    {
        return [self.delegate tableView:tableView viewForFooterInSection:index];
    }
    
    //handle view or class
    id footer = [self sectionAtIndex:index].footer;
    if ([footer isKindOfClass:[UIView class]])
    {
        return footer;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)index
{
    //forward to delegate
    if ([self.delegate respondsToSelector:_cmd])
    {
        return [self.delegate tableView:tableView heightForFooterInSection:index];
    }
    
    //handle view or class
    UIView *footer = [self sectionAtIndex:index].footer;
    if ([footer isKindOfClass:[UIView class]])
    {
        return footer.frame.size.height ?: UITableViewAutomaticDimension;
    }
    return UITableViewAutomaticDimension;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    FXFormField *field = [self fieldForIndexPath:indexPath];

    //configure cell before setting field (in case it affects how value is displayed)
    [field.cellConfig enumerateKeysAndObjectsUsingBlock:^(NSString *keyPath, id value, __unused BOOL *stop) {
        [cell setValue:value forKeyPath:keyPath];
    }];
    
    //set form field
    ((id<FXFormFieldCell>)cell).field = field;
    
    //configure cell after setting field as well (not ideal, but allows overriding keyboard attributes, etc)
    [field.cellConfig enumerateKeysAndObjectsUsingBlock:^(NSString *keyPath, id value, __unused BOOL *stop) {
        [cell setValue:value forKeyPath:keyPath];
    }];
    
    //forward to delegate
    if ([self.delegate respondsToSelector:_cmd])
    {
        [self.delegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //forward to cell
    UITableViewCell<FXFormFieldCell> *cell = (UITableViewCell<FXFormFieldCell> *)[tableView cellForRowAtIndexPath:indexPath];
    if ([cell respondsToSelector:@selector(didSelectWithTableView:controller:)])
    {
        [cell didSelectWithTableView:tableView controller:[self tableViewController]];
    }
    
    //forward to delegate
    if ([self.delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)])
    {
        [self.delegate tableView:tableView didSelectRowAtIndexPath:indexPath];
    }
}

- (UITableViewCellEditingStyle)tableView:(__unused UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    FXFormSection *section = [self sectionAtIndex:indexPath.section];
    if ([section.form isKindOfClass:[FXTemplateForm class]])
    {
        if (indexPath.row == (NSInteger)[section.fields count] - 1)
        {
            return UITableViewCellEditingStyleInsert;
        }
        return UITableViewCellEditingStyleDelete;
    }
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(__unused UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(__unused NSIndexPath *)indexPath
{
    return NO;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    //dismiss keyboard
    [FXFormsFirstResponder(self.tableView) resignFirstResponder];
    
    //forward to delegate
    if ([self.delegate respondsToSelector:_cmd])
    {
        [self.delegate scrollViewWillBeginDragging:scrollView];
    }
}

#pragma mark -
#pragma mark Keyboard events

- (UITableViewCell *)cellContainingView:(UIView *)view
{
    if (view == nil || [view isKindOfClass:[UITableViewCell class]])
    {
        return (UITableViewCell *)view;
    }
    return [self cellContainingView:view.superview];
}

- (void)keyboardDidShow:(NSNotification *)notification
{
    UITableViewCell *cell = [self cellContainingView:FXFormsFirstResponder(self.tableView)];
    if (cell && ![self.delegate isKindOfClass:[UITableViewController class]])
    {
        // calculate the size of the keyboard and how much is and isn't covering the tableview
        NSDictionary *keyboardInfo = [notification userInfo];
        CGRect keyboardFrame = [keyboardInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
        keyboardFrame = [self.tableView.window convertRect:keyboardFrame toView:self.tableView.superview];
        CGFloat heightOfTableViewThatIsCoveredByKeyboard = self.tableView.frame.origin.y + self.tableView.frame.size.height - keyboardFrame.origin.y;
        CGFloat heightOfTableViewThatIsNotCoveredByKeyboard = self.tableView.frame.size.height - heightOfTableViewThatIsCoveredByKeyboard;
        
        UIEdgeInsets tableContentInset = self.tableView.contentInset;
        self.originalTableContentInset = tableContentInset;
        tableContentInset.bottom = heightOfTableViewThatIsCoveredByKeyboard;
        
        UIEdgeInsets tableScrollIndicatorInsets = self.tableView.scrollIndicatorInsets;
        tableScrollIndicatorInsets.bottom += heightOfTableViewThatIsCoveredByKeyboard;
        
        [UIView beginAnimations:nil context:nil];
        
        // adjust the tableview insets by however much the keyboard is overlapping the tableview
        self.tableView.contentInset = tableContentInset;
        self.tableView.scrollIndicatorInsets = tableScrollIndicatorInsets;
        
        UIView *firstResponder = FXFormsFirstResponder(self.tableView);
        if ([firstResponder isKindOfClass:[UITextView class]])
        {
            UITextView *textView = (UITextView *)firstResponder;
            
            // calculate the position of the cursor in the textView
            NSRange range = textView.selectedRange;
            UITextPosition *beginning = textView.beginningOfDocument;
            UITextPosition *start = [textView positionFromPosition:beginning offset:range.location];
            UITextPosition *end = [textView positionFromPosition:start offset:range.length];
            CGRect caretFrame = [textView caretRectForPosition:end];
            
            // convert the cursor to the same coordinate system as the tableview
            CGRect caretViewFrame = [textView convertRect:caretFrame toView:self.tableView.superview];
            
            // padding makes sure that the cursor isn't sitting just above the
            // keyboard and will adjust to 3 lines of text worth above keyboard
            CGFloat padding = textView.font.lineHeight * 3;
            CGFloat keyboardToCursorDifference = (caretViewFrame.origin.y + caretViewFrame.size.height) - heightOfTableViewThatIsNotCoveredByKeyboard + padding;
            
            // if there is a difference then we want to adjust the keyboard, otherwise
            // the cursor is fine to stay where it is and the keyboard doesn't need to move
            if (keyboardToCursorDifference > 0)
            {
                // adjust offset by this difference
                CGPoint contentOffset = self.tableView.contentOffset;
                contentOffset.y += keyboardToCursorDifference;
                [self.tableView setContentOffset:contentOffset animated:YES];
            }
        }
        
        [UIView commitAnimations];
    }
}

- (void)keyboardWillHide:(NSNotification *)note
{
    UITableViewCell *cell = [self cellContainingView:FXFormsFirstResponder(self.tableView)];
    if (cell && ![self.delegate isKindOfClass:[UITableViewController class]])
    {
        NSDictionary *keyboardInfo = [note userInfo];
        UIEdgeInsets tableScrollIndicatorInsets = self.tableView.scrollIndicatorInsets;
        tableScrollIndicatorInsets.bottom = 0;
        
        //restore insets
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationCurve:(UIViewAnimationCurve)keyboardInfo[UIKeyboardAnimationCurveUserInfoKey]];
        [UIView setAnimationDuration:[keyboardInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
        self.tableView.contentInset = self.originalTableContentInset;
        self.tableView.scrollIndicatorInsets = tableScrollIndicatorInsets;
        self.originalTableContentInset = UIEdgeInsetsZero;
        [UIView commitAnimations];
    }
}

@end


@interface FXFormViewController ()

@property (nonatomic, strong) FXFormController *formController;

@end


@implementation FXFormViewController

@synthesize field = _field;

- (void)dealloc
{
    _formController.delegate = nil;
}

- (void)setField:(FXFormField *)field
{
    _field = field;
    
    id<FXForm> form = nil;
    if (field.options)
    {
        form = [[FXOptionsForm alloc] initWithField:field];
    }
    else if ([field isCollectionType])
    {
        form = [[FXTemplateForm alloc] initWithField:field];
    }
    else if ([field.valueClass conformsToProtocol:@protocol(FXForm)])
    {
        if (!field.value && ![field.valueClass isSubclassOfClass:FXFormClassFromString(@"NSManagedObject")])
        {
            //create a new instance of the form automatically
            field.value = [[field.valueClass alloc] init];
        }
        form = field.value;
    }
    else
    {
        [NSException raise:FXFormsException format:@"FXFormViewController field value must conform to FXForm protocol"];
    }
    
    self.formController.parentFormController = field.formController;
    self.formController.form = form;
}

- (FXFormController *)formController
{
    if (!_formController)
    {
        _formController = [[FXFormController alloc] init];
        _formController.delegate = self;
    }
    return _formController;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (!self.tableView)
    {
        self.tableView = [[UITableView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame
                                                      style:UITableViewStyleGrouped];
        if ([self.tableView respondsToSelector:@selector(cellLayoutMarginsFollowReadableWidth)])
        {
            self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
        }
    }
    if (!self.tableView.superview)
    {
        self.view = self.tableView;
    }
}

- (void)setTableView:(UITableView *)tableView
{
    self.formController.tableView = tableView;
    if (![self isViewLoaded])
    {
        self.view = self.tableView;
    }
}

- (UITableView *)tableView
{
    return self.formController.tableView;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
    if (selected)
    {
        [self.tableView reloadData];
        [self.tableView selectRowAtIndexPath:selected animated:NO scrollPosition:UITableViewScrollPositionNone];
        [self.tableView deselectRowAtIndexPath:selected animated:YES];
    }
}

@end


#pragma mark -
#pragma mark Views


@implementation FXFormBaseCell

@synthesize field = _field;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
    {
        self.textLabel.font = [UIFont boldSystemFontOfSize:17];
        FXFormLabelSetMinFontSize(self.textLabel, FXFormFieldMinFontSize);
        self.detailTextLabel.font = [UIFont systemFontOfSize:17];
        FXFormLabelSetMinFontSize(self.detailTextLabel, FXFormFieldMinFontSize);
        
        if ([[UIDevice currentDevice].systemVersion floatValue] >= 7.0)
        {
            self.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
        else
        {
            self.selectionStyle = UITableViewCellSelectionStyleBlue;
        }
        
        [self setUp];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self setUp];
    }
    return self;
}

- (void)setValue:(id)value forKeyPath:(NSString *)keyPath
{
    if (![keyPath isEqualToString:@"style"])
    {
        [super setValue:value forKeyPath:keyPath];
    }
}

- (void)setField:(FXFormField *)field
{
    _field = field;
    [self update];
    [self setNeedsLayout];
}

- (void)setAccessoryType:(UITableViewCellAccessoryType)accessoryType
{
    //don't distinguish between these, because we're always in edit mode
    super.accessoryType = accessoryType;
    super.editingAccessoryType = accessoryType;
}

- (void)setEditingAccessoryType:(UITableViewCellAccessoryType)editingAccessoryType
{
    //don't distinguish between these, because we're always in edit mode
    [self setAccessoryType:editingAccessoryType];
}

- (void)setAccessoryView:(UIView *)accessoryView
{
    //don't distinguish between these, because we're always in edit mode
    super.accessoryView = accessoryView;
    super.editingAccessoryView = accessoryView;
}

- (void)setEditingAccessoryView:(UIView *)editingAccessoryView
{
    //don't distinguish between these, because we're always in edit mode
    [self setAccessoryView:editingAccessoryView];
}

- (UITableView *)tableView
{
    UITableView *view = (UITableView *)[self superview];
    while (![view isKindOfClass:[UITableView class]])
    {
        view = (UITableView *)[view superview];
    }
    return view;
}

- (NSIndexPath *)indexPathForNextCell
{
    UITableView *tableView = [self tableView];
    NSIndexPath *indexPath = [tableView indexPathForCell:self];
    if (indexPath)
    {
        //get next indexpath
        if ([tableView numberOfRowsInSection:indexPath.section] > indexPath.row + 1)
        {
            return [NSIndexPath indexPathForRow:indexPath.row + 1 inSection:indexPath.section];
        }
        else if ([tableView numberOfSections] > indexPath.section + 1)
        {
            return [NSIndexPath indexPathForRow:0 inSection:indexPath.section + 1];
        }
    }
    return nil;
}

- (UITableViewCell <FXFormFieldCell> *)nextCell
{
    UITableView *tableView = [self tableView];
    NSIndexPath *indexPath = [self indexPathForNextCell];
    if (indexPath)
    {
        //get next cell
        return (UITableViewCell <FXFormFieldCell> *)[tableView cellForRowAtIndexPath:indexPath];
    }
    return nil;
}

- (void)setUp
{
    //override
}

- (void)update
{
    //override
}

- (void)didSelectWithTableView:(__unused UITableView *)tableView controller:(__unused UIViewController *)controller
{
    //override
}

@end


@implementation FXFormDefaultCell

- (void)update
{
    self.textLabel.text = self.field.title;
    self.textLabel.accessibilityValue = self.textLabel.text;
    self.detailTextLabel.text = [self.field fieldDescription];
    self.detailTextLabel.accessibilityValue = self.detailTextLabel.text;
    
    if ([self.field.type isEqualToString:FXFormFieldTypeLabel])
    {
        self.accessoryType = UITableViewCellAccessoryNone;
        if (!self.field.action)
        {
            self.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    }
    else if ([self.field isSubform] || self.field.segue)
    {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    else if ([self.field.type isEqualToString:FXFormFieldTypeBoolean] || [self.field.type isEqualToString:FXFormFieldTypeOption])
    {
        self.detailTextLabel.text = nil;
        self.detailTextLabel.accessibilityValue = self.detailTextLabel.text;
        self.accessoryType = [self.field.value boolValue]? UITableViewCellAccessoryCheckmark: UITableViewCellAccessoryNone;
    }
    else if (self.field.action)
    {
        self.accessoryType = UITableViewCellAccessoryNone;
        self.textLabel.textAlignment = NSTextAlignmentCenter;
    }
    else
    {
        self.accessoryType = UITableViewCellAccessoryNone;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
}

- (void)didSelectWithTableView:(UITableView *)tableView controller:(UIViewController *)controller
{
    if ([self.field.type isEqualToString:FXFormFieldTypeBoolean] || [self.field.type isEqualToString:FXFormFieldTypeOption])
    {
        [FXFormsFirstResponder(tableView) resignFirstResponder];
        self.field.value = @(![self.field.value boolValue]);
        if (self.field.action) self.field.action(self);
        self.accessoryType = [self.field.value boolValue]? UITableViewCellAccessoryCheckmark: UITableViewCellAccessoryNone;
        if ([self.field.type isEqualToString:FXFormFieldTypeOption])
        {
            NSIndexPath *indexPath = [tableView indexPathForCell:self];
            if (indexPath)
            {
                //reload section, in case fields are linked
                [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }
        else
        {
            //deselect the cell
            [tableView deselectRowAtIndexPath:tableView.indexPathForSelectedRow animated:YES];
        }
    }
    else if (self.field.action && (![self.field isSubform] || !self.field.options))
    {
        //action takes precendence over segue or subform - you can implement these yourself in the action
        //the exception is for options fields, where the action will be called when the option is tapped
        //TODO: do we need to make other exceptions? Or is there a better way to handle actions for subforms?
        [FXFormsFirstResponder(tableView) resignFirstResponder];
        self.field.action(self);
        [tableView deselectRowAtIndexPath:tableView.indexPathForSelectedRow animated:YES];
    }
    else if (self.field.segue && [self.field.segue class] != self.field.segue)
    {
        //segue takes precendence over subform - you have to handle setup of subform yourself
        [FXFormsFirstResponder(tableView) resignFirstResponder];
        if ([self.field.segue isKindOfClass:[UIStoryboardSegue class]])
        {
            [controller prepareForSegue:self.field.segue sender:self];
            [(UIStoryboardSegue *)self.field.segue perform];
        }
        else if ([self.field.segue isKindOfClass:[NSString class]])
        {
            [controller performSegueWithIdentifier:self.field.segue sender:self];
        }
    }
    else if ([self.field isSubform])
    {
        [FXFormsFirstResponder(tableView) resignFirstResponder];
        UIViewController *subcontroller = nil;
        if ([self.field.valueClass isSubclassOfClass:[UIViewController class]])
        {
            subcontroller = self.field.value ?: [[self.field.valueClass alloc] init];
        }
        else if (self.field.viewController && self.field.viewController == [self.field.viewController class])
        {
            subcontroller = [[self.field.viewController alloc] init];
            ((id <FXFormFieldViewController>)subcontroller).field = self.field;
        }
        else if ([self.field.viewController isKindOfClass:[UIViewController class]])
        {
            subcontroller = self.field.viewController;
            ((id <FXFormFieldViewController>)subcontroller).field = self.field;
        }
        else
        {
            subcontroller = [[self.field.viewController ?: [FXFormViewController class] alloc] init];
            ((id <FXFormFieldViewController>)subcontroller).field = self.field;
        }
        if (!subcontroller.title) subcontroller.title = self.field.title;
        if (self.field.segue)
        {
            UIStoryboardSegue *segue = [[self.field.segue alloc] initWithIdentifier:self.field.key source:controller destination:subcontroller];
            [controller prepareForSegue:self.field.segue sender:self];
            [segue perform];
        }
        else
        {
            NSAssert(controller.navigationController != nil, @"Attempted to push a sub-viewController from a form that is not embedded inside a UINavigationController. That won't work!");
            [controller.navigationController pushViewController:subcontroller animated:YES];
        }
    }
}

@end


@interface FXFormTextFieldCell () <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, assign, getter = isReturnKeyOverriden) BOOL returnKeyOverridden;

@end


@implementation FXFormTextFieldCell

- (void)setUp
{
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.textLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    
    self.textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 200, 21)];
    self.textField.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin |UIViewAutoresizingFlexibleLeftMargin;
    self.textField.font = [UIFont systemFontOfSize:self.textLabel.font.pointSize];
    self.textField.minimumFontSize = FXFormLabelMinFontSize(self.textLabel);
    self.textField.textColor = [UIColor colorWithRed:0.275f green:0.376f blue:0.522f alpha:1.000f];
    self.textField.delegate = self;
    [self.contentView addSubview:self.textField];
    
    [self.contentView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self.textField action:NSSelectorFromString(@"becomeFirstResponder")]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange) name:UITextFieldTextDidChangeNotification object:self.textField];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _textField.delegate = nil;
}

- (void)setValue:(id)value forKeyPath:(NSString *)keyPath
{
    //TODO: is there a less hacky fix for this?
    static NSDictionary *specialCases = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        specialCases = @{@"textField.autocapitalizationType": ^(UITextField *f, NSInteger v){ f.autocapitalizationType = v; },
                         @"textField.autocorrectionType": ^(UITextField *f, NSInteger v){ f.autocorrectionType = v; },
                         @"textField.spellCheckingType": ^(UITextField *f, NSInteger v){ f.spellCheckingType = v; },
                         @"textField.keyboardType": ^(UITextField *f, NSInteger v){ f.keyboardType = v; },
                         @"textField.keyboardAppearance": ^(UITextField *f, NSInteger v){ f.keyboardAppearance = v; },
                         @"textField.returnKeyType": ^(UITextField *f, NSInteger v){ f.returnKeyType = v; },
                         @"textField.enablesReturnKeyAutomatically": ^(UITextField *f, NSInteger v){ f.enablesReturnKeyAutomatically = !!v; },
                         @"textField.secureTextEntry": ^(UITextField *f, NSInteger v){ f.secureTextEntry = !!v; }};
    });

    void (^block)(UITextField *f, NSInteger v) = specialCases[keyPath];
    if (block)
    {
        if ([keyPath isEqualToString:@"textField.returnKeyType"])
        {
            //oh god, the hack, it burns
            self.returnKeyOverridden = YES;
        }
        
        block(self.textField, [value integerValue]);
    }
    else
    {
        [super setValue:value forKeyPath:keyPath];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect labelFrame = self.textLabel.frame;
    labelFrame.size.width = MIN(MAX([self.textLabel sizeThatFits:CGSizeZero].width, FXFormFieldMinLabelWidth), FXFormFieldMaxLabelWidth);
    self.textLabel.frame = labelFrame;
    
    CGRect textFieldFrame = self.textField.frame;
    textFieldFrame.origin.x = self.textLabel.frame.origin.x + MAX(FXFormFieldMinLabelWidth, self.textLabel.frame.size.width) + FXFormFieldLabelSpacing;
    textFieldFrame.origin.y = (self.contentView.bounds.size.height - textFieldFrame.size.height) / 2;
    textFieldFrame.size.width = self.textField.superview.frame.size.width - textFieldFrame.origin.x - FXFormFieldPaddingRight;
    if (![self.textLabel.text length])
    {
        textFieldFrame.origin.x = FXFormFieldPaddingLeft;
        textFieldFrame.size.width = self.contentView.bounds.size.width - FXFormFieldPaddingLeft - FXFormFieldPaddingRight;
    }
    else if (self.textField.textAlignment == NSTextAlignmentRight)
    {
        textFieldFrame.origin.x = self.textLabel.frame.origin.x + labelFrame.size.width + FXFormFieldLabelSpacing;
        textFieldFrame.size.width = self.textField.superview.frame.size.width - textFieldFrame.origin.x - FXFormFieldPaddingRight;
    }
    self.textField.frame = textFieldFrame;
}

- (void)update
{
    self.textLabel.text = self.field.title;
    self.textLabel.accessibilityValue = self.textLabel.text;
    self.textField.placeholder = [self.field.placeholder fieldDescription];
    self.textField.text = [self.field fieldDescription];
    
    self.textField.returnKeyType = UIReturnKeyDone;
    self.textField.textAlignment = [self.field.title length]? NSTextAlignmentRight: NSTextAlignmentLeft;
    self.textField.secureTextEntry = NO;
    
    if ([self.field.type isEqualToString:FXFormFieldTypeText])
    {
        self.textField.autocorrectionType = UITextAutocorrectionTypeDefault;
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        self.textField.keyboardType = UIKeyboardTypeDefault;
    }
    else if ([self.field.type isEqualToString:FXFormFieldTypeUnsigned])
    {
        self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.textField.keyboardType = UIKeyboardTypeNumberPad;
        self.textField.textAlignment = NSTextAlignmentRight;
    }
    else if ([@[FXFormFieldTypeNumber, FXFormFieldTypeInteger, FXFormFieldTypeFloat] containsObject:self.field.type])
    {
        self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        self.textField.textAlignment = NSTextAlignmentRight;
    }
    else if ([self.field.type isEqualToString:FXFormFieldTypePassword])
    {
        self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.textField.keyboardType = UIKeyboardTypeDefault;
        self.textField.secureTextEntry = YES;
    }
    else if ([self.field.type isEqualToString:FXFormFieldTypeEmail])
    {
        self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.textField.keyboardType = UIKeyboardTypeEmailAddress;
    }
    else if ([self.field.type isEqualToString:FXFormFieldTypePhone])
    {
        self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.textField.keyboardType = UIKeyboardTypePhonePad;
    }
    else if ([self.field.type isEqualToString:FXFormFieldTypeURL])
    {
        self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.textField.keyboardType = UIKeyboardTypeURL;
    }
}

- (BOOL)textFieldShouldBeginEditing:(__unused UITextField *)textField
{
    //welcome to hacksville, population: you
    if (!self.returnKeyOverridden)
    {
        //get return key type
        UIReturnKeyType returnKeyType = UIReturnKeyDone;
        UITableViewCell <FXFormFieldCell> *nextCell = self.nextCell;
        if ([nextCell canBecomeFirstResponder])
        {
            returnKeyType = UIReturnKeyNext;
        }
        
        self.textField.returnKeyType = returnKeyType;
    }
    return YES;
}

- (void)textFieldDidBeginEditing:(__unused UITextField *)textField
{
    [self.textField selectAll:nil];
}

- (void)textDidChange
{
    [self updateFieldValue];
}

- (BOOL)textFieldShouldReturn:(__unused UITextField *)textField
{
    if (self.textField.returnKeyType == UIReturnKeyNext)
    {
        [self.nextCell becomeFirstResponder];
    }
    else
    {
        [self.textField resignFirstResponder];
    }
    return NO;
}

- (void)textFieldDidEndEditing:(__unused UITextField *)textField
{
    [self updateFieldValue];

    if (self.field.action) self.field.action(self);
}

- (void)updateFieldValue
{
    self.field.value = self.textField.text;
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)becomeFirstResponder
{
    return [self.textField becomeFirstResponder];
}

- (BOOL)resignFirstResponder
{
    return [self.textField resignFirstResponder];
}

@end


@interface FXFormTextViewCell () <UITextViewDelegate>

@property (nonatomic, strong) UITextView *textView;

@end


@implementation FXFormTextViewCell

+ (CGFloat)heightForField:(FXFormField *)field width:(CGFloat)width
{
    static UITextView *textView;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        textView = [[UITextView alloc] init];
        textView.font = [UIFont systemFontOfSize:17];
    });
    
    textView.text = [field fieldDescription] ?: @" ";
    CGSize textViewSize = [textView sizeThatFits:CGSizeMake(width - FXFormFieldPaddingLeft - FXFormFieldPaddingRight, FLT_MAX)];
    
    CGFloat height = [field.title length]? 21: 0; // label height
    height += FXFormFieldPaddingTop + ceilf(textViewSize.height) + FXFormFieldPaddingBottom;
    return height;
}

- (void)setUp
{
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.textLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    
    self.textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 320, 21)];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    self.textView.font = [UIFont systemFontOfSize:17];
    self.textView.textColor = [UIColor colorWithRed:0.275f green:0.376f blue:0.522f alpha:1.000f];
    self.textView.backgroundColor = [UIColor clearColor];
    self.textView.delegate = self;
    self.textView.scrollEnabled = NO;
    [self.contentView addSubview:self.textView];
    
    self.detailTextLabel.textAlignment = NSTextAlignmentLeft;
    self.detailTextLabel.numberOfLines = 0;
    
    [self.contentView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self.textView action:NSSelectorFromString(@"becomeFirstResponder")]];
}

- (void)dealloc
{
    _textView.delegate = nil;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect labelFrame = self.textLabel.frame;
    labelFrame.origin.y = FXFormFieldPaddingTop;
    labelFrame.size.width = MIN(MAX([self.textLabel sizeThatFits:CGSizeZero].width, FXFormFieldMinLabelWidth), FXFormFieldMaxLabelWidth);
    self.textLabel.frame = labelFrame;
    
    CGRect textViewFrame = self.textView.frame;
    textViewFrame.origin.x = FXFormFieldPaddingLeft;
    textViewFrame.origin.y = self.textLabel.frame.origin.y + self.textLabel.frame.size.height;
    textViewFrame.size.width = self.contentView.bounds.size.width - FXFormFieldPaddingLeft - FXFormFieldPaddingRight;
    CGSize textViewSize = [self.textView sizeThatFits:CGSizeMake(self.textView.frame.size.width, FLT_MAX)];
    textViewFrame.size.height = ceilf(textViewSize.height);
    if (![self.textLabel.text length])
    {
        textViewFrame.origin.y = self.textLabel.frame.origin.y;
    }
    self.textView.frame = textViewFrame;
    
    textViewFrame.origin.x += 5;
    textViewFrame.size.width -= 5;
    self.detailTextLabel.frame = textViewFrame;
    
    CGRect contentViewFrame = self.contentView.frame;
    contentViewFrame.size.height = self.textView.frame.origin.y + self.textView.frame.size.height + FXFormFieldPaddingBottom;
    self.contentView.frame = contentViewFrame;
}

- (void)update
{
    self.textLabel.text = self.field.title;
    self.textLabel.accessibilityValue = self.textLabel.text;
    self.textView.text = [self.field fieldDescription];
    self.detailTextLabel.text = self.field.placeholder;
    self.detailTextLabel.accessibilityValue = self.detailTextLabel.text;
    self.detailTextLabel.hidden = ([self.textView.text length] > 0);
    
    self.textView.returnKeyType = UIReturnKeyDefault;
    self.textView.textAlignment = NSTextAlignmentLeft;
    self.textView.secureTextEntry = NO;
    
    if ([self.field.type isEqualToString:FXFormFieldTypeText])
    {
        self.textView.autocorrectionType = UITextAutocorrectionTypeDefault;
        self.textView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        self.textView.keyboardType = UIKeyboardTypeDefault;
    }
    else if ([self.field.type isEqualToString:FXFormFieldTypeUnsigned])
    {
        self.textView.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.textView.keyboardType = UIKeyboardTypeNumberPad;
    }
    else if ([@[FXFormFieldTypeNumber, FXFormFieldTypeInteger, FXFormFieldTypeFloat] containsObject:self.field.type])
    {
        self.textView.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.textView.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    }
    else if ([self.field.type isEqualToString:FXFormFieldTypePassword])
    {
        self.textView.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.textView.keyboardType = UIKeyboardTypeDefault;
        self.textView.secureTextEntry = YES;
    }
    else if ([self.field.type isEqualToString:FXFormFieldTypeEmail])
    {
        self.textView.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.textView.keyboardType = UIKeyboardTypeEmailAddress;
    }
    else if ([self.field.type isEqualToString:FXFormFieldTypePhone])
    {
        self.textView.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.textView.keyboardType = UIKeyboardTypePhonePad;
    }
    else if ([self.field.type isEqualToString:FXFormFieldTypeURL])
    {
        self.textView.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.textView.keyboardType = UIKeyboardTypeURL;
    }
}

- (void)textViewDidBeginEditing:(__unused UITextView *)textView
{
    [self.textView selectAll:nil];
}

- (void)textViewDidChange:(UITextView *)textView
{
    [self updateFieldValue];
    
    //show/hide placeholder
    self.detailTextLabel.hidden = ([textView.text length] > 0);
    
    //resize the tableview if required
    UITableView *tableView = [self tableView];
    [tableView beginUpdates];
    [tableView endUpdates];
    
    //scroll to show cursor
    CGRect cursorRect = [self.textView caretRectForPosition:self.textView.selectedTextRange.end];
    [tableView scrollRectToVisible:[tableView convertRect:cursorRect fromView:self.textView] animated:YES];
}

- (void)textViewDidEndEditing:(__unused UITextView *)textView
{
    [self updateFieldValue];
    
    if (self.field.action) self.field.action(self);
}

- (void)updateFieldValue
{
    self.field.value = self.textView.text;
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)becomeFirstResponder
{
    return [self.textView becomeFirstResponder];
}

- (BOOL)resignFirstResponder
{
    return [self.textView resignFirstResponder];
}

@end


@implementation FXFormSwitchCell

- (void)setUp
{
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.accessoryView = [[UISwitch alloc] init];
    [self.switchControl addTarget:self action:@selector(valueChanged) forControlEvents:UIControlEventValueChanged];
}

- (void)update
{
    self.textLabel.text = self.field.title;
    self.textLabel.accessibilityValue = self.textLabel.text;
    self.switchControl.on = [self.field.value boolValue];
}

- (UISwitch *)switchControl
{
    return (UISwitch *)self.accessoryView;
}

- (void)valueChanged
{
    self.field.value = @(self.switchControl.on);
    
    if (self.field.action) self.field.action(self);
}

@end


@implementation FXFormStepperCell

- (void)setUp
{
    UIStepper *stepper = [[UIStepper alloc] init];
    stepper.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    UIView *wrapper = [[UIView alloc] initWithFrame:stepper.frame];
    [wrapper addSubview:stepper];
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 7.0)
    {
        wrapper.frame = CGRectMake(0, 0, wrapper.frame.size.width + FXFormFieldPaddingRight, wrapper.frame.size.height);
    }
    
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.accessoryView = wrapper;
    [self.stepper addTarget:self action:@selector(valueChanged) forControlEvents:UIControlEventValueChanged];
}

- (void)update
{
    self.textLabel.text = self.field.title;
    self.textLabel.accessibilityValue = self.textLabel.text;
    self.detailTextLabel.text = [self.field fieldDescription];
    self.detailTextLabel.accessibilityValue = self.detailTextLabel.text;
    self.stepper.value = [self.field.value doubleValue];
}

- (UIStepper *)stepper
{
    return (UIStepper *)[self.accessoryView.subviews firstObject];
}

- (void)valueChanged
{
    self.field.value = @(self.stepper.value);
    self.detailTextLabel.text = [self.field fieldDescription];
    self.detailTextLabel.accessibilityValue = self.detailTextLabel.text;
    [self setNeedsLayout];
    
    if (self.field.action) self.field.action(self);
}

@end


@interface FXFormSliderCell ()

@property (nonatomic, strong) UISlider *slider;

@end


@implementation FXFormSliderCell

- (void)setUp
{
    self.slider = [[UISlider alloc] init];
    [self.slider addTarget:self action:@selector(valueChanged) forControlEvents:UIControlEventValueChanged];
    [self.contentView addSubview:self.slider];
    
    self.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect sliderFrame = self.slider.frame;
    sliderFrame.origin.x = self.textLabel.frame.origin.x + self.textLabel.frame.size.width + FXFormFieldPaddingLeft;
    sliderFrame.origin.y = (self.contentView.frame.size.height - sliderFrame.size.height) / 2;
    sliderFrame.size.width = self.contentView.bounds.size.width - sliderFrame.origin.x - FXFormFieldPaddingRight;
    self.slider.frame = sliderFrame;
}

- (void)update
{
    self.textLabel.text = self.field.title;
    self.textLabel.accessibilityValue = self.textLabel.text;
    self.slider.value = [self.field.value doubleValue];
}

- (void)valueChanged
{
    self.field.value = @(self.slider.value);
    
    if (self.field.action) self.field.action(self);
}

@end


@interface FXFormDatePickerCell ()

@property (nonatomic, strong) UIDatePicker *datePicker;

@end


@implementation FXFormDatePickerCell

- (void)setUp
{
    self.datePicker = [[UIDatePicker alloc] init];
    [self.datePicker addTarget:self action:@selector(valueChanged) forControlEvents:UIControlEventValueChanged];
}

- (void)update
{
    self.textLabel.text = self.field.title;
    self.textLabel.accessibilityValue = self.textLabel.text;
    self.detailTextLabel.text = [self.field fieldDescription] ?: [self.field.placeholder fieldDescription];
    self.detailTextLabel.accessibilityValue = self.detailTextLabel.text;
    
    if ([self.field.type isEqualToString:FXFormFieldTypeDate])
    {
        self.datePicker.datePickerMode = UIDatePickerModeDate;
    }
    else if ([self.field.type isEqualToString:FXFormFieldTypeTime])
    {
        self.datePicker.datePickerMode = UIDatePickerModeTime;
    }
    else
    {
        self.datePicker.datePickerMode = UIDatePickerModeDateAndTime;
    }
    
    self.datePicker.date = self.field.value ?: ([self.field.placeholder isKindOfClass:[NSDate class]]? self.field.placeholder: [NSDate date]);
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (UIView *)inputView
{
    return self.datePicker;
}

- (void)valueChanged
{
    self.field.value = self.datePicker.date;
    self.detailTextLabel.text = [self.field fieldDescription];
    self.detailTextLabel.accessibilityValue = self.detailTextLabel.text;
    [self setNeedsLayout];
    
    if (self.field.action) self.field.action(self);
}

- (void)didSelectWithTableView:(UITableView *)tableView controller:(__unused UIViewController *)controller
{
    if (![self isFirstResponder])
    {
        [self becomeFirstResponder];
    }
    else
    {
        [self resignFirstResponder];
    }
    [tableView deselectRowAtIndexPath:tableView.indexPathForSelectedRow animated:YES];
}

@end


@interface FXFormImagePickerCell () <UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIActionSheetDelegate>

@property (nonatomic, strong) UIImagePickerController *imagePickerController;
@property (nonatomic, weak) UIViewController *controller;

@end


@implementation FXFormImagePickerCell

- (void)setUp
{
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    self.accessoryView = imageView;
    [self setNeedsLayout];
}

- (void)dealloc
{
    _imagePickerController.delegate = nil;
}

- (void)layoutSubviews
{
    CGRect frame = self.imagePickerView.bounds;
    frame.size.height = self.bounds.size.height - 10;
    UIImage *image = self.imagePickerView.image;
    frame.size.width = image.size.height? image.size.width * (frame.size.height / image.size.height): 0;
    self.imagePickerView.bounds = frame;
    
    [super layoutSubviews];
}

- (void)update
{
    self.textLabel.text = self.field.title;
    self.textLabel.accessibilityValue = self.textLabel.text;
    self.imagePickerView.image = [self imageValue];
    [self setNeedsLayout];
}

- (UIImage *)imageValue
{
    if (self.field.value)
    {
        return self.field.value;
    }
    else if (self.field.placeholder)
    {
        UIImage *placeholderImage = self.field.placeholder;
        if ([placeholderImage isKindOfClass:[NSString class]])
        {
            placeholderImage = [UIImage imageNamed:self.field.placeholder];
        }
        return placeholderImage;
    }
    return nil;
}

- (UIImagePickerController *)imagePickerController
{
    if (!_imagePickerController)
    {
        _imagePickerController = [[UIImagePickerController alloc] init];
        _imagePickerController.delegate = self;
        _imagePickerController.allowsEditing = YES;
    }
    return _imagePickerController;
}

- (UIImageView *)imagePickerView
{
    return (UIImageView *)self.accessoryView;
}

- (void)didSelectWithTableView:(UITableView *)tableView controller:(UIViewController *)controller
{
    [FXFormsFirstResponder(tableView) resignFirstResponder];
    [tableView deselectRowAtIndexPath:tableView.indexPathForSelectedRow animated:YES];
    
    if (!TARGET_IPHONE_SIMULATOR && ![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    {
        self.imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        [controller presentViewController:self.imagePickerController animated:YES completion:nil];
    }
    else if ([UIAlertController class])
    {
        UIAlertControllerStyle style = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)? UIAlertControllerStyleAlert: UIAlertControllerStyleActionSheet;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:style];
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Take Photo", nil) style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [self actionSheet:nil didDismissWithButtonIndex:0];
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Photo Library", nil) style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [self actionSheet:nil didDismissWithButtonIndex:1];
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:NULL]];
        
        self.controller = controller;
        [controller presentViewController:alert animated:YES completion:NULL];
    }
    else
    {
        self.controller = controller;
        [[[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", nil) destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"Take Photo", nil), NSLocalizedString(@"Photo Library", nil), nil] showInView:controller.view];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:NULL];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    self.field.value = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:NULL];
    if (self.field.action) self.field.action(self);
    [self update];
}

- (void)actionSheet:(__unused UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    switch (buttonIndex)
    {
        case 0:
        {
            sourceType = UIImagePickerControllerSourceTypeCamera;
            break;
        }
        case 1:
        {
            sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            break;
        }
        default:
        {
            self.controller = nil;
            return;
        }
    }
    if ([UIImagePickerController isSourceTypeAvailable:sourceType])
    {
        self.imagePickerController.sourceType = sourceType;
        [self.controller presentViewController:self.imagePickerController animated:YES completion:nil];
    }
    self.controller = nil;
}

@end


@interface FXFormOptionPickerCell () <UIPickerViewDataSource, UIPickerViewDelegate>

@property (nonatomic, strong) UIPickerView *pickerView;

@end


@implementation FXFormOptionPickerCell

- (void)setUp
{
    self.pickerView = [[UIPickerView alloc] init];
    self.pickerView.dataSource = self;
    self.pickerView.delegate = self;
}

- (void)dealloc
{
    _pickerView.dataSource = nil;
    _pickerView.delegate = nil;
}

- (void)update
{
    self.textLabel.text = self.field.title;
    self.textLabel.accessibilityValue = self.textLabel.text;
    self.detailTextLabel.text = [self.field fieldDescription];
    self.detailTextLabel.accessibilityValue = self.detailTextLabel.text;
    
    NSUInteger index = self.field.value? [self.field.options indexOfObject:self.field.value]: NSNotFound;
    if (self.field.placeholder)
    {
        index = (index == NSNotFound)? 0: index + 1;
    }
    if (index != NSNotFound)
    {
        [self.pickerView selectRow:index inComponent:0 animated:NO];
    }
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (UIView *)inputView
{
    return self.pickerView;
}

- (void)didSelectWithTableView:(UITableView *)tableView controller:(__unused UIViewController *)controller
{
    if (![self isFirstResponder])
    {
        [self becomeFirstResponder];
    }
    else
    {
        [self resignFirstResponder];
    }
    [tableView deselectRowAtIndexPath:tableView.indexPathForSelectedRow animated:YES];
}

- (NSInteger)numberOfComponentsInPickerView:(__unused UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(__unused UIPickerView *)pickerView numberOfRowsInComponent:(__unused NSInteger)component
{
    return [self.field optionCount];
}

- (NSString *)pickerView:(__unused UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(__unused NSInteger)component
{
    return [self.field optionDescriptionAtIndex:row];
}

- (void)pickerView:(__unused UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(__unused NSInteger)component
{
    [self.field setOptionSelected:YES atIndex:row];
    self.detailTextLabel.text = [self.field fieldDescription] ?: [self.field.placeholder fieldDescription];
    self.detailTextLabel.accessibilityValue = self.detailTextLabel.text;
    
    [self setNeedsLayout];
    
    if (self.field.action) self.field.action(self);
}

@end


@interface FXFormOptionSegmentsCell ()

@property (nonatomic, strong, readwrite) UISegmentedControl *segmentedControl;

@end


@implementation FXFormOptionSegmentsCell

- (void)setUp
{
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[]];
    [self.segmentedControl addTarget:self action:@selector(valueChanged) forControlEvents:UIControlEventValueChanged];
    [self.contentView addSubview:self.segmentedControl];
    
    self.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect segmentedControlFrame = self.segmentedControl.frame;
    segmentedControlFrame.origin.x = self.textLabel.frame.origin.x + self.textLabel.frame.size.width + FXFormFieldPaddingLeft;
    segmentedControlFrame.origin.y = (self.contentView.frame.size.height - segmentedControlFrame.size.height) / 2;
    segmentedControlFrame.size.width = self.contentView.bounds.size.width - segmentedControlFrame.origin.x - FXFormFieldPaddingRight;
    self.segmentedControl.frame = segmentedControlFrame;
}

- (void)update
{
    self.textLabel.text = self.field.title;
    self.textLabel.accessibilityValue = self.textLabel.text;
    
    [self.segmentedControl removeAllSegments];
    for (NSUInteger i = 0; i < [self.field optionCount]; i++)
    {
        [self.segmentedControl insertSegmentWithTitle:[self.field optionDescriptionAtIndex:i] atIndex:i animated:NO];
        if ([self.field isOptionSelectedAtIndex:i])
        {
            [self.segmentedControl setSelectedSegmentIndex:i];
        }
    }
}

- (void)valueChanged
{
    //note: this loop is to prevent bugs when field type is multiselect
    //which currently isn't supported by FXFormOptionSegmentsCell
    NSInteger selectedIndex = self.segmentedControl.selectedSegmentIndex;
    for (NSInteger i = 0; i < (NSInteger)[self.field optionCount]; i++)
    {
        [self.field setOptionSelected:(selectedIndex == i) atIndex:i];
    }
    
    if (self.field.action) self.field.action(self);
}

@end
