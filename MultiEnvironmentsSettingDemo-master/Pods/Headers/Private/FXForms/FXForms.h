//
//  FXForms.h
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

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wmissing-variable-declarations"


#import <UIKit/UIKit.h>


UIKIT_EXTERN NSString *const FXFormFieldKey; //key
UIKIT_EXTERN NSString *const FXFormFieldType; //type
UIKIT_EXTERN NSString *const FXFormFieldClass; //class
UIKIT_EXTERN NSString *const FXFormFieldCell; //cell
UIKIT_EXTERN NSString *const FXFormFieldTitle; //title
UIKIT_EXTERN NSString *const FXFormFieldPlaceholder; //placeholder
UIKIT_EXTERN NSString *const FXFormFieldDefaultValue; //default
UIKIT_EXTERN NSString *const FXFormFieldOptions; //options
UIKIT_EXTERN NSString *const FXFormFieldTemplate; //template
UIKIT_EXTERN NSString *const FXFormFieldValueTransformer; //valueTransformer
UIKIT_EXTERN NSString *const FXFormFieldAction; //action
UIKIT_EXTERN NSString *const FXFormFieldSegue; //segue
UIKIT_EXTERN NSString *const FXFormFieldHeader; //header
UIKIT_EXTERN NSString *const FXFormFieldFooter; //footer
UIKIT_EXTERN NSString *const FXFormFieldInline; //inline
UIKIT_EXTERN NSString *const FXFormFieldSortable; //sortable
UIKIT_EXTERN NSString *const FXFormFieldViewController; //viewController

UIKIT_EXTERN NSString *const FXFormFieldTypeDefault; //default
UIKIT_EXTERN NSString *const FXFormFieldTypeLabel; //label
UIKIT_EXTERN NSString *const FXFormFieldTypeText; //text
UIKIT_EXTERN NSString *const FXFormFieldTypeLongText; //longtext
UIKIT_EXTERN NSString *const FXFormFieldTypeURL; //url
UIKIT_EXTERN NSString *const FXFormFieldTypeEmail; //email
UIKIT_EXTERN NSString *const FXFormFieldTypePhone; //phone
UIKIT_EXTERN NSString *const FXFormFieldTypePassword; //password
UIKIT_EXTERN NSString *const FXFormFieldTypeNumber; //number
UIKIT_EXTERN NSString *const FXFormFieldTypeInteger; //integer
UIKIT_EXTERN NSString *const FXFormFieldTypeUnsigned; //unsigned
UIKIT_EXTERN NSString *const FXFormFieldTypeFloat; //float
UIKIT_EXTERN NSString *const FXFormFieldTypeBitfield; //bitfield
UIKIT_EXTERN NSString *const FXFormFieldTypeBoolean; //boolean
UIKIT_EXTERN NSString *const FXFormFieldTypeOption; //option
UIKIT_EXTERN NSString *const FXFormFieldTypeDate; //date
UIKIT_EXTERN NSString *const FXFormFieldTypeTime; //time
UIKIT_EXTERN NSString *const FXFormFieldTypeDateTime; //datetime
UIKIT_EXTERN NSString *const FXFormFieldTypeImage; //image


#pragma mark -
#pragma mark Models


@interface NSObject (FXForms)

- (NSString *)fieldDescription;

@end


@protocol FXForm <NSObject>
@optional

- (NSArray *)fields;
- (NSArray *)extraFields;
- (NSArray *)excludedFields;

// informal protocol:

// - (NSDictionary *)<fieldKey>Field
// - (NSString *)<fieldKey>FieldDescription

@end


@interface FXFormField : NSObject

@property (nonatomic, readonly) id<FXForm> form;
@property (nonatomic, readonly) NSString *key;
@property (nonatomic, readonly) NSString *type;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) id placeholder;
@property (nonatomic, readonly) NSDictionary *fieldTemplate;
@property (nonatomic, readonly) BOOL isSortable;
@property (nonatomic, readonly) BOOL isInline;
@property (nonatomic, readonly) Class valueClass;
@property (nonatomic, readonly) id viewController;
@property (nonatomic, readonly) void (^action)(id sender);
@property (nonatomic, readonly) id segue;
@property (nonatomic, strong) id value;

- (NSUInteger)optionCount;
- (id)optionAtIndex:(NSUInteger)index;
- (NSUInteger)indexOfOption:(id)option;
- (NSString *)optionDescriptionAtIndex:(NSUInteger)index;
- (void)setOptionSelected:(BOOL)selected atIndex:(NSUInteger)index;
- (BOOL)isOptionSelectedAtIndex:(NSUInteger)index;

@end


#pragma mark -
#pragma mark Controllers


@protocol FXFormControllerDelegate <UITableViewDelegate>

@end


@interface FXFormController : NSObject

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) FXFormController *parentFormController;
@property (nonatomic, weak) id<FXFormControllerDelegate> delegate;
@property (nonatomic, strong) id<FXForm> form;

- (NSUInteger)numberOfSections;
- (NSUInteger)numberOfFieldsInSection:(NSUInteger)section;
- (FXFormField *)fieldForIndexPath:(NSIndexPath *)indexPath;
- (NSIndexPath *)indexPathForField:(FXFormField *)field;
- (void)enumerateFieldsWithBlock:(void (^)(FXFormField *field, NSIndexPath *indexPath))block;

- (Class)cellClassForField:(FXFormField *)field;
- (void)registerDefaultFieldCellClass:(Class)cellClass;
- (void)registerCellClass:(Class)cellClass forFieldType:(NSString *)fieldType;
- (void)registerCellClass:(Class)cellClass forFieldClass:(Class)fieldClass;

- (Class)viewControllerClassForField:(FXFormField *)field;
- (void)registerDefaultViewControllerClass:(Class)controllerClass;
- (void)registerViewControllerClass:(Class)controllerClass forFieldType:(NSString *)fieldType;
- (void)registerViewControllerClass:(Class)controllerClass forFieldClass:(Class)fieldClass;


@end


@protocol FXFormFieldViewController <NSObject>

@property (nonatomic, strong) FXFormField *field;

@end


@interface FXFormViewController : UIViewController <FXFormFieldViewController, FXFormControllerDelegate>

@property (nonatomic, readonly) FXFormController *formController;
@property (nonatomic, strong) IBOutlet UITableView *tableView;

@end


#pragma mark -
#pragma mark Views


@protocol FXFormFieldCell <NSObject>

@property (nonatomic, strong) FXFormField *field;

@optional

+ (CGFloat)heightForField:(FXFormField *)field width:(CGFloat)width;
- (void)didSelectWithTableView:(UITableView *)tableView
                    controller:(UIViewController *)controller;
@end


@interface FXFormBaseCell : UITableViewCell <FXFormFieldCell>

@property (nonatomic, readonly) UITableViewCell <FXFormFieldCell> *nextCell;

- (void)setUp;
- (void)update;
- (void)didSelectWithTableView:(UITableView *)tableView
                    controller:(UIViewController *)controller;

@end


@interface FXFormDefaultCell : FXFormBaseCell

@end


@interface FXFormTextFieldCell : FXFormBaseCell

@property (nonatomic, readonly) UITextField *textField;

@end


@interface FXFormTextViewCell : FXFormBaseCell

@property (nonatomic, readonly) UITextView *textView;

@end


@interface FXFormSwitchCell : FXFormBaseCell

@property (nonatomic, readonly) UISwitch *switchControl;

@end


@interface FXFormStepperCell : FXFormBaseCell

@property (nonatomic, readonly) UIStepper *stepper;

@end


@interface FXFormSliderCell : FXFormBaseCell

@property (nonatomic, readonly) UISlider *slider;

@end


@interface FXFormDatePickerCell : FXFormBaseCell

@property (nonatomic, readonly) UIDatePicker *datePicker;

@end


@interface FXFormImagePickerCell : FXFormBaseCell

@property (nonatomic, readonly) UIImageView *imagePickerView;
@property (nonatomic, readonly) UIImagePickerController *imagePickerController;

@end


@interface FXFormOptionPickerCell : FXFormBaseCell

@property (nonatomic, readonly) UIPickerView *pickerView;

@end


@interface FXFormOptionSegmentsCell : FXFormBaseCell

@property (nonatomic, readonly) UISegmentedControl *segmentedControl;

@end


#pragma clang diagnostic pop

