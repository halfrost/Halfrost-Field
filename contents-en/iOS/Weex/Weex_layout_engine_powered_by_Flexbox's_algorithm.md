# The Weex Layout Engine, Powerfully Driven by the Flexbox Algorithm


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-e08b9b787f8fb07c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


### Preface

In the previous article, we discussed the basic workflow of Weex on the iOS client. This article will take a detailed look at how Weex lays out native UIs with high performance, and then compare it with existing layout approaches to see how Weex's layout performance actually stacks up.


### Table of Contents

- 1.Weex Layout Algorithm
- 2.Performance Analysis of the Weex Layout Algorithm
- 3.How Weex Lays Out Native UIs


### 1. Weex Layout Algorithm

Open the Layout folder in the Weex source code, and you will see two C files. These two files are the Weex layout engine we are going to discuss today.


Layout.h and Layout.c originally came from the code in React Native. In other words, Weex and React Native used the same layout engine code.

The current React Native codebase no longer contains these two files; they have been replaced by Yoga.

![](http://upload-images.jianshu.io/upload_images/1194012-de7f409bd683080e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Yoga was originally a cross-platform, CSS-based layout engine introduced by Facebook in React Native. It implements the Flexbox specification and fully complies with the W3C specification. As the system continued to mature, Facebook re-released it, and it became what is now Yoga ([Yoga official website](https://facebook.github.io/yoga/)).


So what is Flexbox?


![](http://upload-images.jianshu.io/upload_images/1194012-a85be95bcb08cc24.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Anyone familiar with frontend development should already know this concept well. In 2009, the W3C proposed a new approach—Flex layout—which makes it simple to implement all kinds of page layouts in a complete and responsive way. It is now supported by almost all browsers. Modern frontend development is mainly implemented with Html / CSS / JS, where CSS is used for frontend layout. Any Html container can be designated as a Flex layout via css. Once a container is designated as a Flex layout, its child elements can be laid out according to Flexbox syntax.

For the basic definition of Flexbox and more detailed documentation, interested readers can refer to the official W3C documentation, which provides very detailed explanations. [Official documentation link](https://www.w3.org/TR/css-flexbox-1/)

The Layout files in Weex are the predecessor of Yoga, from before Yoga was officially released. The underlying code is written in C, so performance is not an issue. Next, we will take a close look at how the Layout files implement Flexbox.


![](http://upload-images.jianshu.io/upload_images/1194012-8c812635119a366c.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Therefore, all source-code analysis below is based on version v0.10.0.

#### (1) Basic Data Structures in Flexbox


The original goal of Flexbox layout (Flexible Box) was to allocate child-view layouts more efficiently, including dynamically changing width, height, and ordering. Flexbox can more conveniently adapt to screens of different sizes, for example by stretching and shrinking child views.


In the world of Flexbox, there are the concepts of the main axis and the cross axis.

![](http://upload-images.jianshu.io/upload_images/1194012-b476d0e771837826.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

In most cases, child views are laid out along the main axis, from main-start to main-end. One important point to note, however, is that although the main axis and cross axis are always perpendicular to each other, it is not fixed which one is horizontal and which one is vertical. For example, the following situation is possible:


![](http://upload-images.jianshu.io/upload_images/1194012-951af0f2fc01b0a2.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In the case shown above, where the horizontal direction is the cross axis, child views are arranged along the cross axis, from cross-start to cross-end.

**Main axis:** The parent view's main axis, along which child views are primarily arranged and laid out.

**Main-start and main-end:** The direction in which child views are laid out inside the parent view is from main-start toward main-start.

**Main size:** The width or height of a child view in the main-axis direction is its main-axis size. The primary size property of a child view is either width or height, determined by which one corresponds to the main-axis direction.

**Cross axis:** The axis perpendicular to the main axis is called the cross axis. Its direction primarily depends on the direction of the main axis.

**Cross-start and cross-end:** The placement of child-view lines starts at the cross-start edge of the container and ends toward the cross-end edge.

**Cross size:** The width or height of a child view in the cross-axis direction is the item's cross-axis length. The cross-axis length property of a flex item is either the `width` or `height` property, determined by which one corresponds to the cross-axis direction.


Next, let's see how Layout defines the elements in Flexbox.
```c

typedef enum {
  CSS_DIRECTION_INHERIT = 0,
  CSS_DIRECTION_LTR,
  CSS_DIRECTION_RTL
} css_direction_t;


```
This direction is the direction of the overall layout of the defined context. `INHERIT` means inheritance, `LTR` means Left To Right, laying out from left to right. `RTL` means Right To Left, laying out from right to left. In the following analysis, unless otherwise specified, the layout is `LTR`, from left to right. If it is `RTL`, it is the reverse of `LTR`.
```c


typedef enum {
  CSS_FLEX_DIRECTION_COLUMN = 0,
  CSS_FLEX_DIRECTION_COLUMN_REVERSE,
  CSS_FLEX_DIRECTION_ROW,
  CSS_FLEX_DIRECTION_ROW_REVERSE
} css_flex_direction_t;


```
This defines the direction of Flex.


![](http://upload-images.jianshu.io/upload_images/1194012-74e4b1f77d6fa40d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The image above shows COLUMN. The layout flows from top to bottom.

![](http://upload-images.jianshu.io/upload_images/1194012-d34a0fea4404545e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The image above shows COLUMN\_REVERSE. The layout flows from bottom to top.


![](http://upload-images.jianshu.io/upload_images/1194012-8a6e7643a60e2906.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The image above shows ROW. The layout flows from left to right.

![](http://upload-images.jianshu.io/upload_images/1194012-569f2a299797e27b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The image above shows ROW\_REVERSE. The layout flows from right to left.


As you can see here, in an LTR context, ROW\_REVERSE is equivalent to ROW in an RTL context.
```c


typedef enum {
  CSS_JUSTIFY_FLEX_START = 0,
  CSS_JUSTIFY_CENTER,
  CSS_JUSTIFY_FLEX_END,
  CSS_JUSTIFY_SPACE_BETWEEN,
  CSS_JUSTIFY_SPACE_AROUND
} css_justify_t;


```
This defines how subviews are arranged along the main axis.

![](http://upload-images.jianshu.io/upload_images/1194012-7dd84c06eabd1ddd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The image above shows JUSTIFY\_FLEX\_START

![](http://upload-images.jianshu.io/upload_images/1194012-d86b61dabc5a97fd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The image above shows JUSTIFY\_CENTER


![](http://upload-images.jianshu.io/upload_images/1194012-945bde67f5931fcf.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The image above shows JUSTIFY\_FLEX\_END

![](http://upload-images.jianshu.io/upload_images/1194012-3823fed50bd98895.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The image above shows JUSTIFY\_SPACE\_BETWEEN

![](http://upload-images.jianshu.io/upload_images/1194012-5c514b364e470dfc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The image above shows JUSTIFY\_SPACE\_AROUND. In this mode, a certain amount of space is maintained on both the left and right sides of each view.
```c

typedef enum {
  CSS_ALIGN_AUTO = 0,
  CSS_ALIGN_FLEX_START,
  CSS_ALIGN_CENTER,
  CSS_ALIGN_FLEX_END,
  CSS_ALIGN_STRETCH
} css_align_t;

```
This defines how child views are aligned on the cross axis.

In Weex, three modes of type css\_align\_t are defined: align\_content, align\_items, and align\_self. These three alignment modes differ slightly.


ALIGN\_AUTO is only a default value for align\_self. For align\_content and align\_items, it is not a valid value for aligning child views.


#### 1.align\_items

align\_items defines how child views are arranged on the cross axis within a single line.


![](http://upload-images.jianshu.io/upload_images/1194012-e756eec5a022f74a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The image above shows ALIGN\_FLEX\_START.


![](http://upload-images.jianshu.io/upload_images/1194012-5e200b8d742b01a2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The image above shows ALIGN\_CENTER.


![](http://upload-images.jianshu.io/upload_images/1194012-ceab624ccd23e978.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The image above shows ALIGN\_FLEX\_END.

![](http://upload-images.jianshu.io/upload_images/1194012-7bb4781738e20528.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The image above shows ALIGN\_STRETCH.


In the W3C definition of align\_items, there is actually another alignment mode: baseline. It is not included in Weex’s definition.


![](http://upload-images.jianshu.io/upload_images/1194012-10e077f6a05f4fe8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Note that the baseline alignment mode shown above is not defined in Weex!

#### 2. align_content

align_content defines how rows of child views are arranged relative to each other on the cross axis.

![](http://upload-images.jianshu.io/upload_images/1194012-c4e6c4930823f326.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The image above shows ALIGN\_FLEX\_START.

![](http://upload-images.jianshu.io/upload_images/1194012-3425b3876c3d665b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The image above shows ALIGN\_CENTER.


![](http://upload-images.jianshu.io/upload_images/1194012-c5358bd9b76e9aac.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The image above shows ALIGN\_FLEX\_END.


![](http://upload-images.jianshu.io/upload_images/1194012-6a98ea3472c5b20c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The image above shows ALIGN_STRETCH.


In the W3C definition of FlexBox, there are actually two additional modes that Weex does not define.

![](http://upload-images.jianshu.io/upload_images/1194012-b5b1500aa720593a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The alignment mode shown above corresponds to JUSTIFY\_SPACE\_AROUND in justify. The space-around alignment mode in align-content is not available in Weex.

![](http://upload-images.jianshu.io/upload_images/1194012-77e9ab8a8268646f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The alignment mode shown above corresponds to JUSTIFY\_SPACE\_BETWEEN in justify. The space-between alignment mode in align-content is not available in Weex.


#### 3.align_self

This final alignment mode lets you customize the alignment of each child view individually on top of align\_items. If it is auto, it behaves the same as align\_items.

![](http://upload-images.jianshu.io/upload_images/1194012-964d7fb4451fb0b0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```c

typedef enum {
  CSS_POSITION_RELATIVE = 0,
  CSS_POSITION_ABSOLUTE
} css_position_type_t;


```
This is the type used to define coordinate addresses. There are two kinds: relative coordinates and absolute coordinates.
```c

typedef enum {
  CSS_NOWRAP = 0,
  CSS_WRAP
} css_wrap_type_t;


```
In Weex, `wrap` has only two types.

![](http://upload-images.jianshu.io/upload_images/1194012-d982430a883bd70e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The image above shows `NOWRAP`. All child views are laid out in a single row.


![](http://upload-images.jianshu.io/upload_images/1194012-40c4c59a6237ebbb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The image above shows `WRAP`. All child views are laid out from left to right and from top to bottom.


The W3C standard also defines a `wrap_reverse` layout mode.

![](http://upload-images.jianshu.io/upload_images/1194012-40d7272e17d5b429.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

This layout mode arranges items from left to right and from bottom to top. It is not currently defined in Weex.
```c

typedef enum {
  CSS_LEFT = 0,
  CSS_TOP,
  CSS_RIGHT,
  CSS_BOTTOM,
  CSS_START,
  CSS_END,
  CSS_POSITION_COUNT
} css_position_t;

```
This defines the coordinate description. Because `Left` and `Top` appear in `position[2]` and `position[4]`, respectively, they are listed before `Right` and `Bottom`.
```c


typedef enum {
  CSS_MEASURE_MODE_UNDEFINED = 0,
  CSS_MEASURE_MODE_EXACTLY,
  CSS_MEASURE_MODE_AT_MOST
} css_measure_mode_t;

```
This defines the computation methods: one is exact calculation, and the other is approximate estimation.
```c

typedef enum {
  CSS_WIDTH = 0,
  CSS_HEIGHT
} css_dimension_t;

```
This defines the size of the subview: its width and height.
```c

typedef struct {
  float position[4];
  float dimensions[2];
  css_direction_t direction;

  // Cache some information to avoid recalculating it during every Layout process
  bool should_update;
  float last_requested_dimensions[2];
  float last_parent_max_width;
  float last_parent_max_height;
  float last_dimensions[2];
  float last_position[2];
  css_direction_t last_direction;
} css_layout_t;

```
A `css_layout_t` struct is defined here. The `position` and `dimensions` arrays in the struct store the positions on the four sides and the width/height dimensions, respectively. `direction` stores whether the direction is LTR or RTL.

The variables below are all cached state, used to avoid recomputing a layout that has not changed.
```c

typedef struct {
  float dimensions[2];
} css_dim_t;

```
The css\_dim\_t struct contains the size information for the subview: width and height.
```c

typedef struct {
  // Direction of the entire page CSS, LTR, RTL
  css_direction_t direction;
  // Flex direction
  css_flex_direction_t flex_direction;
  // Alignment of child views along the main axis
  css_justify_t justify_content;
  // Alignment between rows of child views on the cross axis
  css_align_t align_content;
  // Alignment of child views on the cross axis
  css_align_t align_items;
  // Alignment of the child view itself
  css_align_t align_self;
  // Coordinate system type of the child view (relative coordinate system, absolute coordinate system)
  css_position_type_t position_type;
  // Wrap type
  css_wrap_type_t flex_wrap;
  float flex;
  // top, bottom, left, right, start, end
  float margin[6];
  // top, bottom, left, right
  float position[4];
  // top, bottom, left, right, start, end
  float padding[6];
  // top, bottom, left, right, start, end
  float border[6];
  // width, height
  float dimensions[2];
  // Minimum width and height
  float minDimensions[2];
  // Maximum width and height
  float maxDimensions[2];
} css_style_t;


```
css\_style\_t records all information for the entire style. The meaning of each variable is described in the comments above.
```c

typedef struct css_node css_node_t;
struct css_node {
  css_style_t style;
  css_layout_t layout;
  int children_count;
  int line_index;

  css_node_t *next_absolute_child;
  css_node_t *next_flex_child;

  css_dim_t (*measure)(void *context, float width, css_measure_mode_t widthMode, float height, css_measure_mode_t heightMode);
  void (*print)(void *context);
  struct css_node* (*get_child)(void *context, int i);
  bool (*is_dirty)(void *context);
  void *context;
};


```
`css_node` defines the data structure for a FlexBox node. It includes the previously mentioned `css_style_t` and `css_layout_t`. Since member functions cannot be defined inside a struct, the following includes four function pointers.

![](http://upload-images.jianshu.io/upload_images/1194012-9192b10f6607271c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```c

css_node_t *new_css_node(void);
void init_css_node(css_node_t *node);
void free_css_node(css_node_t *node);

```
The three functions above are related to the lifecycle of css\_node.
```c

// Create new node
css_node_t *new_css_node() {
  css_node_t *node = (css_node_t *)calloc(1, sizeof(*node));
  init_css_node(node);
  return node;
}

// Free node
void free_css_node(css_node_t *node) {
  free(node);
}


```
When creating a new node, the init\_css\_node method is called.
```c


void init_css_node(css_node_t *node) {
  node->style.align_items = CSS_ALIGN_STRETCH;
  node->style.align_content = CSS_ALIGN_FLEX_START;

  node->style.direction = CSS_DIRECTION_INHERIT;
  node->style.flex_direction = CSS_FLEX_DIRECTION_COLUMN;

  // Note that the values in these arrays below are initialized to undefined, not 0
  node->style.dimensions[CSS_WIDTH] = CSS_UNDEFINED;
  node->style.dimensions[CSS_HEIGHT] = CSS_UNDEFINED;

  node->style.minDimensions[CSS_WIDTH] = CSS_UNDEFINED;
  node->style.minDimensions[CSS_HEIGHT] = CSS_UNDEFINED;

  node->style.maxDimensions[CSS_WIDTH] = CSS_UNDEFINED;
  node->style.maxDimensions[CSS_HEIGHT] = CSS_UNDEFINED;

  node->style.position[CSS_LEFT] = CSS_UNDEFINED;
  node->style.position[CSS_TOP] = CSS_UNDEFINED;
  node->style.position[CSS_RIGHT] = CSS_UNDEFINED;
  node->style.position[CSS_BOTTOM] = CSS_UNDEFINED;

  node->style.margin[CSS_START] = CSS_UNDEFINED;
  node->style.margin[CSS_END] = CSS_UNDEFINED;
  node->style.padding[CSS_START] = CSS_UNDEFINED;
  node->style.padding[CSS_END] = CSS_UNDEFINED;
  node->style.border[CSS_START] = CSS_UNDEFINED;
  node->style.border[CSS_END] = CSS_UNDEFINED;

  node->layout.dimensions[CSS_WIDTH] = CSS_UNDEFINED;
  node->layout.dimensions[CSS_HEIGHT] = CSS_UNDEFINED;

  // The following cache variables used to compare whether changes occurred all have initial values of -1.
  node->layout.last_requested_dimensions[CSS_WIDTH] = -1;
  node->layout.last_requested_dimensions[CSS_HEIGHT] = -1;
  node->layout.last_parent_max_width = -1;
  node->layout.last_parent_max_height = -1;
  node->layout.last_direction = (css_direction_t)-1;
  node->layout.should_update = true;
}


```
The initial `align_items` of `css_node` is `ALIGN_STRETCH`, `align_content` is `ALIGN_FLEX_START`, `direction` is inherited from the parent class, and `flex_direction` is arranged by column.

Next, the array below stores `UNDEFINED`, not `0`, because `0` would conflict with the `0` values in the struct.

Finally, all cached variables are initialized to `-1`.

Next, four global arrays are defined. These four arrays are very useful: they determine the direction and attributes of the subsequent layout. The four arrays are correlated with the axis directions.
```c

static css_position_t leading[4] = {
  /* CSS_FLEX_DIRECTION_COLUMN = */ CSS_TOP,
  /* CSS_FLEX_DIRECTION_COLUMN_REVERSE = */ CSS_BOTTOM,
  /* CSS_FLEX_DIRECTION_ROW = */ CSS_LEFT,
  /* CSS_FLEX_DIRECTION_ROW_REVERSE = */ CSS_RIGHT
};

```
If the main axis is vertical in the `COLUMN` direction, the child view’s leading edge is `CSS_TOP`; if the direction is `COLUMN_REVERSE`, the child view’s leading edge is `CSS_BOTTOM`. If the main axis is horizontal in the `ROW` direction, the child view’s leading edge is `CSS_LEFT`; if the direction is `ROW_REVERSE`, the child view’s leading edge is `CSS_RIGHT`.
```c

static css_position_t trailing[4] = {
  /* CSS_FLEX_DIRECTION_COLUMN = */ CSS_BOTTOM,
  /* CSS_FLEX_DIRECTION_COLUMN_REVERSE = */ CSS_TOP,
  /* CSS_FLEX_DIRECTION_ROW = */ CSS_RIGHT,
  /* CSS_FLEX_DIRECTION_ROW_REVERSE = */ CSS_LEFT
};

```
If the main axis is vertical in the `COLUMN` direction, then the child view’s trailing edge is `CSS_BOTTOM`; if the direction is `COLUMN_REVERSE`, then the child view’s trailing edge is `CSS_TOP`. If the main axis is horizontal in the `ROW` direction, then the child view’s trailing edge is `CSS_RIGHT`; if the direction is `ROW_REVERSE`, then the child view’s trailing edge is `CSS_LEFT`.
```c

static css_position_t pos[4] = {
  /* CSS_FLEX_DIRECTION_COLUMN = */ CSS_TOP,
  /* CSS_FLEX_DIRECTION_COLUMN_REVERSE = */ CSS_BOTTOM,
  /* CSS_FLEX_DIRECTION_ROW = */ CSS_LEFT,
  /* CSS_FLEX_DIRECTION_ROW_REVERSE = */ CSS_RIGHT
};

```
If the main axis is vertical in the COLUMN direction, the child view’s position starts from CSS\_TOP; if the direction is COLUMN\_REVERSE, the child view’s position starts from CSS\_BOTTOM. If the main axis is horizontal in the ROW direction, the child view’s position starts from CSS\_LEFT; if the direction is ROW\_REVERSE, the child view’s position starts from CSS\_RIGHT.
```c

static css_dimension_t dim[4] = {
  /* CSS_FLEX_DIRECTION_COLUMN = */ CSS_HEIGHT,
  /* CSS_FLEX_DIRECTION_COLUMN_REVERSE = */ CSS_HEIGHT,
  /* CSS_FLEX_DIRECTION_ROW = */ CSS_WIDTH,
  /* CSS_FLEX_DIRECTION_ROW_REVERSE = */ CSS_WIDTH
};


```
If the main axis is vertical with direction COLUMN, then the size of a child view along that direction is CSS\_HEIGHT. If the direction is COLUMN\_REVERSE, the size of a child view along that direction is also CSS\_HEIGHT. If the main axis is horizontal with direction ROW, then the size of a child view along that direction is CSS\_WIDTH. If the direction is ROW\_REVERSE, the size of a child view along that direction is CSS\_WIDTH.


#### (II) Layout Algorithm in FlexBox

 
The Weex box model is based on the [CSS box model](https://www.w3.org/TR/css3-box/). Every Weex element can be viewed as a box. When discussing design or layout, we generally refer to this concept as the “box model.”

The box model describes the space occupied by an element. Each box has four edges: the margin edge, border edge, padding edge, and content edge. These four layers of edges form nested boxes, which is the general meaning of the box model.


![](http://upload-images.jianshu.io/upload_images/1194012-2968e2f04c41c140.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The box model is shown above. This diagram is based on LTR, with the main axis in the horizontal direction.

Therefore, when the main axis is in different directions, the behavior may differ.


>Note:
The default box-sizing of the Weex box model is border-box; that is, the box’s width and height include the content, padding, and border widths, but do not include the margin width.
```c

// Check whether the axis is horizontal
static bool isRowDirection(css_flex_direction_t flex_direction) {
  return flex_direction == CSS_FLEX_DIRECTION_ROW ||
         flex_direction == CSS_FLEX_DIRECTION_ROW_REVERSE;
}

// Check whether the axis is vertical
static bool isColumnDirection(css_flex_direction_t flex_direction) {
  return flex_direction == CSS_FLEX_DIRECTION_COLUMN ||
         flex_direction == CSS_FLEX_DIRECTION_COLUMN_REVERSE;
}

```
The ways to determine the axis direction are the two described above.

Next, we also need to calculate the padding, border, and margin in the four directions. Here, we’ll use one direction as an example.

First, how is the margin calculated?
```c

static float getLeadingMargin(css_node_t *node, css_flex_direction_t axis) {
  if (isRowDirection(axis) && !isUndefined(node->style.margin[CSS_START])) {
    return node->style.margin[CSS_START];
  }
  return node->style.margin[leading[axis]];
}


```
Determine whether the axis direction is horizontal. If it is horizontal, directly take `CSS_START` from the node’s margin as the `LeadingMargin`. If it is vertical, retrieve the margin value in the leading direction on the vertical axis.

If retrieving `TrailingMargin`, use `margin[CSS_END]`.
```c

static float getTrailingMargin(css_node_t *node, css_flex_direction_t axis) {
  if (isRowDirection(axis) && !isUndefined(node->style.margin[CSS_END])) {
    return node->style.margin[CSS_END];
  }

  return node->style.margin[trailing[axis]];
}


```
The arrays for the following three values—padding, border, and margin—store 6 values. If the direction is horizontal, CSS\_START stores Leading and CSS\_END stores Trailing. Unless otherwise stated below, this convention applies.
```c

static float getLeadingPadding(css_node_t *node, css_flex_direction_t axis) {
  if (isRowDirection(axis) &&
      !isUndefined(node->style.padding[CSS_START]) &&
      node->style.padding[CSS_START] >= 0) {
    return node->style.padding[CSS_START];
  }

  if (node->style.padding[leading[axis]] >= 0) {
    return node->style.padding[leading[axis]];
  }

  return 0;
}


```
The approach for retrieving Padding is the same as for Margin: in the horizontal direction, just take `padding[CSS_START]` from the array; in the vertical direction, take the corresponding value of `padding[leading[axis]]`.
```c

static float getLeadingBorder(css_node_t *node, css_flex_direction_t axis) {
  if (isRowDirection(axis) &&
      !isUndefined(node->style.border[CSS_START]) &&
      node->style.border[CSS_START] >= 0) {
    return node->style.border[CSS_START];
  }

  if (node->style.border[leading[axis]] >= 0) {
    return node->style.border[leading[axis]];
  }

  return 0;
}


```
Finally, here is how `Border` is calculated. It is exactly the same as the `Padding` and `Margin` described above, so I won’t repeat it here.

With the calculation methods for the offsets on all four sides implemented, the next step is how to perform layout.
```c

// Method to calculate layout
void layoutNode(css_node_t *node, float maxWidth, float maxHeight, css_direction_t parentDirection);

// Before calling layoutNode, the node's layout can be reset
void resetNodeLayout(css_node_t *node);

```
The method for resetting a node is to reset its coordinates to 0, and reset both its width and height to UNDEFINED.
```c

void resetNodeLayout(css_node_t *node) {
  node->layout.dimensions[CSS_WIDTH] = CSS_UNDEFINED;
  node->layout.dimensions[CSS_HEIGHT] = CSS_UNDEFINED;
  node->layout.position[CSS_LEFT] = 0;
  node->layout.position[CSS_TOP] = 0;
}


```
Finally, the layout method is as follows:
```c

void layoutNode(css_node_t *node, float parentMaxWidth, float parentMaxHeight, css_direction_t parentDirection) {
  css_layout_t *layout = &node->layout;
  css_direction_t direction = node->style.direction;
  layout->should_update = true;

  // Check whether the current environment is "clean" and whether the node to lay out is exactly the same as last time.
  bool skipLayout =
    !node->is_dirty(node->context) &&
    eq(layout->last_requested_dimensions[CSS_WIDTH], layout->dimensions[CSS_WIDTH]) &&
    eq(layout->last_requested_dimensions[CSS_HEIGHT], layout->dimensions[CSS_HEIGHT]) &&
    eq(layout->last_parent_max_width, parentMaxWidth) &&
    eq(layout->last_parent_max_height, parentMaxHeight) &&
    eq(layout->last_direction, direction);

  if (skipLayout) {
    // Assign the cached values directly to the current layout
    layout->dimensions[CSS_WIDTH] = layout->last_dimensions[CSS_WIDTH];
    layout->dimensions[CSS_HEIGHT] = layout->last_dimensions[CSS_HEIGHT];
    layout->position[CSS_TOP] = layout->last_position[CSS_TOP];
    layout->position[CSS_LEFT] = layout->last_position[CSS_LEFT];
  } else {
    // Cache the node
    layout->last_requested_dimensions[CSS_WIDTH] = layout->dimensions[CSS_WIDTH];
    layout->last_requested_dimensions[CSS_HEIGHT] = layout->dimensions[CSS_HEIGHT];
    layout->last_parent_max_width = parentMaxWidth;
    layout->last_parent_max_height = parentMaxHeight;
    layout->last_direction = direction;

    // Initialize the size and position of all child view nodes
    for (int i = 0, childCount = node->children_count; i < childCount; i++) {
      resetNodeLayout(node->get_child(node->context, i));
    }

    // Core implementation of view layout
    layoutNodeImpl(node, parentMaxWidth, parentMaxHeight, parentDirection);

    // After layout is complete, cache this layout to avoid recomputing the same layout next time
    layout->last_dimensions[CSS_WIDTH] = layout->dimensions[CSS_WIDTH];
    layout->last_dimensions[CSS_HEIGHT] = layout->dimensions[CSS_HEIGHT];
    layout->last_position[CSS_TOP] = layout->position[CSS_TOP];
    layout->last_position[CSS_LEFT] = layout->position[CSS_LEFT];
  }
}

```
Each step is commented; see the code comments above. Before invoking the core layout implementation, `layoutNodeImpl`, it iterates over and calls `resetNodeLayout` to initialize all child views.

All of the core implementation is in the `layoutNodeImpl` method. In Weex, this method is over 700 lines long; in Yoga’s implementation, the layout algorithm is over 1,000 lines long.
```c

static void layoutNodeImpl(css_node_t *node, float parentMaxWidth, float parentMaxHeight, css_direction_t parentDirection) {

}


```
Here we’ll analyze the main flow of this algorithm. In Weex’s implementation, there are seven loops; assume we label them, in order, as A, B, C, D, E, F, and G.

First, let’s look at loop A.
```c


    float mainContentDim = 0;
    // There are three types of child views: flex-supporting child views, non-flex child views, and absolutely positioned child views. We need to know which child views are waiting for space allocation.
    int flexibleChildrenCount = 0;
    float totalFlexible = 0;
    int nonFlexibleChildrenCount = 0;

    // Use one loop to simply stack child views on the main axis. In loop C, child views already arranged in loop A will be ignored.
    bool isSimpleStackMain =
        (isMainDimDefined && justifyContent == CSS_JUSTIFY_FLEX_START) ||
        (!isMainDimDefined && justifyContent != CSS_JUSTIFY_CENTER);
    int firstComplexMain = (isSimpleStackMain ? childCount : startLine);

    // Use one loop to simply stack child views on the cross axis. In loop D, child views already arranged in loop A will be ignored.
    bool isSimpleStackCross = true;
    int firstComplexCross = childCount;

    css_node_t* firstFlexChild = NULL;
    css_node_t* currentFlexChild = NULL;

    float mainDim = leadingPaddingAndBorderMain;
    float crossDim = 0;

    float maxWidth = CSS_UNDEFINED;
    float maxHeight = CSS_UNDEFINED;

    // Loop A starts here
    for (i = startLine; i < childCount; ++i) {
      child = node->get_child(node->context, i);
      child->line_index = linesCount;

      child->next_absolute_child = NULL;
      child->next_flex_child = NULL;

      css_align_t alignItem = getAlignItem(node, child);

      // Before the recursive layout, prefill child views that can be stretched on the cross axis.
      if (alignItem == CSS_ALIGN_STRETCH &&
          child->style.position_type == CSS_POSITION_RELATIVE &&
          isCrossDimDefined &&
          !isStyleDimDefined(child, crossAxis)) {
          
        // Compare the child view's size on the cross axis with the stretchable space left after subtracting margins, padding, and borders on both sides, because stretching does not shrink the original size.
        child->layout.dimensions[dim[crossAxis]] = fmaxf(
          boundAxis(child, crossAxis, node->layout.dimensions[dim[crossAxis]] -
            paddingAndBorderAxisCross - getMarginAxis(child, crossAxis)),
          getPaddingAndBorderAxis(child, crossAxis)
        );
      } else if (child->style.position_type == CSS_POSITION_ABSOLUTE) {
        // Store a linked list of absolutely positioned child views, so we can quickly skip them during later layout.
        if (firstAbsoluteChild == NULL) {
          firstAbsoluteChild = child;
        }
        if (currentAbsoluteChild != NULL) {
          currentAbsoluteChild->next_absolute_child = child;
        }
        currentAbsoluteChild = child;

        // Prefill the child view. This requires the view's absolute coordinates on the axis: for a horizontal axis, the left and right offsets; for a vertical axis, the top and bottom offsets.
        for (ii = 0; ii < 2; ii++) {
          axis = (ii != 0) ? CSS_FLEX_DIRECTION_ROW : CSS_FLEX_DIRECTION_COLUMN;
          if (isLayoutDimDefined(node, axis) &&
              !isStyleDimDefined(child, axis) &&
              isPosDefined(child, leading[axis]) &&
              isPosDefined(child, trailing[axis])) {
            child->layout.dimensions[dim[axis]] = fmaxf(
              // This is absolute layout, so leading and trailing also need to be subtracted.
              boundAxis(child, axis, node->layout.dimensions[dim[axis]] -
                getPaddingAndBorderAxis(node, axis) -
                getMarginAxis(child, axis) -
                getPosition(child, leading[axis]) -
                getPosition(child, trailing[axis])),
              getPaddingAndBorderAxis(child, axis)
            );
          }
        }
      }


```
The specific implementation of Loop A is shown above; see the code comments.

Loop A mainly lays out the child views in the layout that cannot flex. The `mainContentDim` variable is used to record the total size, as well as the sum of the margins of all child views that cannot flex. It is used to set the size of the `node` and to calculate the remaining space so that flex-capable child views can stretch and adapt.

Each `node` maintains a linked list via `next_absolute_child`, which stores the linked list of absolutely positioned views in order.

Next, we need to further count the child views that can be stretched.
```c

      float nextContentDim = 0;

      // Count flex children that can stretch
      if (isMainDimDefined && isFlex(child)) {
        flexibleChildrenCount++;
        totalFlexible += child->style.flex;

        // Store a linked list to track flex children
        if (firstFlexChild == NULL) {
          firstFlexChild = child;
        }
        if (currentFlexChild != NULL) {
          currentFlexChild->next_flex_child = child;
        }
        currentFlexChild = child;

        // At this point, although we don't know the exact size, we already know the padding, border, and margin, so we can use this information to determine a minimum size for the child view and calculate the remaining available space.
        // The distance to the next content equals the sum of the child's Leading and Trailing padding, border, and margin values.
        nextContentDim = getPaddingAndBorderAxis(child, mainAxis) +
          getMarginAxis(child, mainAxis);

      } else {
        maxWidth = CSS_UNDEFINED;
        maxHeight = CSS_UNDEFINED;

       // Calculate the maximum width and maximum height
        if (!isMainRowDirection) {
          if (isLayoutDimDefined(node, resolvedRowAxis)) {
            maxWidth = node->layout.dimensions[dim[resolvedRowAxis]] -
              paddingAndBorderAxisResolvedRow;
          } else {
            maxWidth = parentMaxWidth -
              getMarginAxis(node, resolvedRowAxis) -
              paddingAndBorderAxisResolvedRow;
          }
        } else {
          if (isLayoutDimDefined(node, CSS_FLEX_DIRECTION_COLUMN)) {
            maxHeight = node->layout.dimensions[dim[CSS_FLEX_DIRECTION_COLUMN]] -
                paddingAndBorderAxisColumn;
          } else {
            maxHeight = parentMaxHeight -
              getMarginAxis(node, CSS_FLEX_DIRECTION_COLUMN) -
              paddingAndBorderAxisColumn;
          }
        }

        // Recursively call the layout function to lay out child views that cannot stretch.
        if (alreadyComputedNextLayout == 0) {
          layoutNode(child, maxWidth, maxHeight, direction);
        }

        // Since the positions of absolutely positioned child views are unrelated to layout, we cannot use them to calculate mainContentDim
        if (child->style.position_type == CSS_POSITION_RELATIVE) {
          nonFlexibleChildrenCount++;
          nextContentDim = getDimWithMargin(child, mainAxis);
        }
      }


```
The above code determines the layout of the non-stretchable child views.

Each `node`’s `next_flex_child` maintains a linked list, which stores, in order, the views that can be stretched via flex.
```c

      // The element to be added may be pushed to the next line
      if (isNodeFlexWrap &&
          isMainDimDefined &&
          mainContentDim + nextContentDim > definedMainDim &&
          // If there is only one element here, it may need a line of its own
          i != startLine) {
        nonFlexibleChildrenCount--;
        alreadyComputedNextLayout = 1;
        break;
      }

      // Stop stacking child views on the main axis; remaining child views are laid out in loop C
      if (isSimpleStackMain &&
          (child->style.position_type != CSS_POSITION_RELATIVE || isFlex(child))) {
        isSimpleStackMain = false;
        firstComplexMain = i;
      }

      // Stop stacking child views on the cross axis; remaining child views are laid out in loop D
      if (isSimpleStackCross &&
          (child->style.position_type != CSS_POSITION_RELATIVE ||
              (alignItem != CSS_ALIGN_STRETCH && alignItem != CSS_ALIGN_FLEX_START) ||
              (alignItem == CSS_ALIGN_STRETCH && !isCrossDimDefined))) {
        isSimpleStackCross = false;
        firstComplexCross = i;
      }

      if (isSimpleStackMain) {
        child->layout.position[pos[mainAxis]] += mainDim;
        if (isMainDimDefined) {
        // Set the child view's TrailingPosition on the main axis
          setTrailingPosition(node, child, mainAxis);
        }
        // Can now compute the size on the main axis
        mainDim += getDimWithMargin(child, mainAxis);
        // Can now compute the size on the cross axis
        crossDim = fmaxf(crossDim, boundAxis(child, crossAxis, getDimWithMargin(child, crossAxis)));
      }

      if (isSimpleStackCross) {
        child->layout.position[pos[crossAxis]] += linesCrossDim + leadingPaddingAndBorderCross;
        if (isCrossDimDefined) {
        // Set the child view's TrailingPosition on the cross axis
          setTrailingPosition(node, child, crossAxis);
        }
      }

      alreadyComputedNextLayout = 0;
      mainContentDim += nextContentDim;
      endLine = i + 1;
    }
// Loop A ends here

```
After loop A finishes, `endLine` is calculated, as are the size on the main axis and the size on the cross axis. The layout of non-stretchable child views is also determined.

Next, the process enters loop B.

Loop B mainly consists of two parts. The first part is used to lay out stretchable child views.
```c

    // To lay out along the main axis, control two spaces: the distance between the first child and the far left, and the distance between two children
    float leadingMainDim = 0;
    float betweenMainDim = 0;

    // Record the remaining available space
    float remainingMainDim = 0;
    if (isMainDimDefined) {
      remainingMainDim = definedMainDim - mainContentDim;
    } else {
      remainingMainDim = fmaxf(mainContentDim, 0) - mainContentDim;
    }

    // If there are still stretchable children, they should fill the remaining available space
    if (flexibleChildrenCount != 0) {
      float flexibleMainDim = remainingMainDim / totalFlexible;
      float baseMainDim;
      float boundMainDim;

      // If the remaining space cannot be given to stretchable children and cannot satisfy their max or min bounds, exclude those children from the stretch calculation
      currentFlexChild = firstFlexChild;
      while (currentFlexChild != NULL) {
        baseMainDim = flexibleMainDim * currentFlexChild->style.flex +
            getPaddingAndBorderAxis(currentFlexChild, mainAxis);
        boundMainDim = boundAxis(currentFlexChild, mainAxis, baseMainDim);

        if (baseMainDim != boundMainDim) {
          remainingMainDim -= boundMainDim;
          totalFlexible -= currentFlexChild->style.flex;
        }

        currentFlexChild = currentFlexChild->next_flex_child;
      }
      flexibleMainDim = remainingMainDim / totalFlexible;

      // Non-stretchable children may overflow inside the parent; in this case, assume there is no available stretch space
      if (flexibleMainDim < 0) {
        flexibleMainDim = 0;
      }

      currentFlexChild = firstFlexChild;
      while (currentFlexChild != NULL) {
        // In this loop, we can already determine the child's final size
        currentFlexChild->layout.dimensions[dim[mainAxis]] = boundAxis(currentFlexChild, mainAxis,
          flexibleMainDim * currentFlexChild->style.flex +
              getPaddingAndBorderAxis(currentFlexChild, mainAxis)
        );

        // Calculate the maximum width of the child on the horizontal axis
        maxWidth = CSS_UNDEFINED;
        if (isLayoutDimDefined(node, resolvedRowAxis)) {
          maxWidth = node->layout.dimensions[dim[resolvedRowAxis]] -
            paddingAndBorderAxisResolvedRow;
        } else if (!isMainRowDirection) {
          maxWidth = parentMaxWidth -
            getMarginAxis(node, resolvedRowAxis) -
            paddingAndBorderAxisResolvedRow;
        }
        
        // Calculate the maximum height of the child on the vertical axis
        maxHeight = CSS_UNDEFINED;
        if (isLayoutDimDefined(node, CSS_FLEX_DIRECTION_COLUMN)) {
          maxHeight = node->layout.dimensions[dim[CSS_FLEX_DIRECTION_COLUMN]] -
            paddingAndBorderAxisColumn;
        } else if (isMainRowDirection) {
          maxHeight = parentMaxHeight -
            getMarginAxis(node, CSS_FLEX_DIRECTION_COLUMN) -
            paddingAndBorderAxisColumn;
        }

        // Recursively lay out the stretchable child again
        layoutNode(currentFlexChild, maxWidth, maxHeight, direction);

        child = currentFlexChild;
        currentFlexChild = currentFlexChild->next_flex_child;
        child->next_flex_child = NULL;
      }
    }


```
After the two `while` loops above finish, all stretchable subviews have been laid out.
```c


 else if (justifyContent != CSS_JUSTIFY_FLEX_START) {
      if (justifyContent == CSS_JUSTIFY_CENTER) {
        leadingMainDim = remainingMainDim / 2;
      } else if (justifyContent == CSS_JUSTIFY_FLEX_END) {
        leadingMainDim = remainingMainDim;
      } else if (justifyContent == CSS_JUSTIFY_SPACE_BETWEEN) {
        remainingMainDim = fmaxf(remainingMainDim, 0);
        if (flexibleChildrenCount + nonFlexibleChildrenCount - 1 != 0) {
          betweenMainDim = remainingMainDim /
            (flexibleChildrenCount + nonFlexibleChildrenCount - 1);
        } else {
          betweenMainDim = 0;
        }
      } else if (justifyContent == CSS_JUSTIFY_SPACE_AROUND) {
        // Code to implement SPACE_AROUND
        betweenMainDim = remainingMainDim /
          (flexibleChildrenCount + nonFlexibleChildrenCount);
        leadingMainDim = betweenMainDim / 2;
      }
    }


```
After the layout of flex-stretchable views is complete, this is the finishing step: adjust the sizes of betweenMainDim and leadingMainDim based on justifyContent.


Then comes loop C.
```c

    // In this loop, the width and height of all child views are determined. When determining each child view's coordinates, the parent view's width and height are also determined.
    mainDim += leadingMainDim;

    // Loop line by line
    for (i = firstComplexMain; i < endLine; ++i) {
      child = node->get_child(node->context, i);

      if (child->style.position_type == CSS_POSITION_ABSOLUTE &&
          isPosDefined(child, leading[mainAxis])) {
        // At this point, the coordinates of the absolutely positioned child view have been determined; the left and top margins are fixed. The child view's absolute position can now be determined.
        child->layout.position[pos[mainAxis]] = getPosition(child, leading[mainAxis]) +
          getLeadingBorder(node, mainAxis) +
          getLeadingMargin(child, mainAxis);
      } else {
        // If the child view is not absolutely positioned, its position is relative, or the left and top margins have not yet been determined, determine the coordinates based on the current position.
        child->layout.position[pos[mainAxis]] += mainDim;

        // Determine the trailing coordinate position
        if (isMainDimDefined) {
          setTrailingPosition(node, child, mainAxis);
        }

        // Next, process relatively positioned child views; absolutely positioned child views do not participate in the following layout calculation.
        if (child->style.position_type == CSS_POSITION_RELATIVE) {
          // The width on the main axis is the sum of all child view widths.
          mainDim += betweenMainDim + getDimWithMargin(child, mainAxis);
          // The height on the cross axis is determined by the tallest child view.
          crossDim = fmaxf(crossDim, boundAxis(child, crossAxis, getDimWithMargin(child, crossAxis)));
        }
      }
    }

    float containerCrossAxis = node->layout.dimensions[dim[crossAxis]];
    if (!isCrossDimDefined) {
      containerCrossAxis = fmaxf(
        // When calculating the parent view, include the top and bottom padding and border.
        boundAxis(node, crossAxis, crossDim + paddingAndBorderAxisCross),
        paddingAndBorderAxisCross
      );
    }


```
In Loop C, the coordinates of all subviews on the main axis are computed, including the width and height of each subview.

Next, the process moves on to Loop D.
```c


     for (i = firstComplexCross; i < endLine; ++i) {
      child = node->get_child(node->context, i);

      if (child->style.position_type == CSS_POSITION_ABSOLUTE &&
          isPosDefined(child, leading[crossAxis])) {
        // At this point, the position of the absolutely positioned child view has been determined; at least one of top/bottom/left/right is set. The child's absolute position can now be determined.
        child->layout.position[pos[crossAxis]] = getPosition(child, leading[crossAxis]) +
          getLeadingBorder(node, crossAxis) +
          getLeadingMargin(child, crossAxis);

      } else {
        float leadingCrossDim = leadingPaddingAndBorderCross;

        // On the cross axis, for relatively positioned child views, use the parent's alignItems or the child's alignSelf to determine the exact position
        if (child->style.position_type == CSS_POSITION_RELATIVE) {
          // Get the child's AlignItem property value
          css_align_t alignItem = getAlignItem(node, child);
          if (alignItem == CSS_ALIGN_STRETCH) {
            // If the child's size on the cross axis is not yet defined, apply STRETCH.
            if (!isStyleDimDefined(child, crossAxis)) {
              float dimCrossAxis = child->layout.dimensions[dim[crossAxis]];
              child->layout.dimensions[dim[crossAxis]] = fmaxf(
                boundAxis(child, crossAxis, containerCrossAxis -
                  paddingAndBorderAxisCross - getMarginAxis(child, crossAxis)),
                getPaddingAndBorderAxis(child, crossAxis)
              );

              // If the view's size changed, its children need to be laid out again
              if (dimCrossAxis != child->layout.dimensions[dim[crossAxis]] && child->children_count > 0) {
                // Reset child margins before re-layout as they are added back in layoutNode and would be doubled
                child->layout.position[leading[mainAxis]] -= getLeadingMargin(child, mainAxis) +
                  getRelativePosition(child, mainAxis);
                child->layout.position[trailing[mainAxis]] -= getTrailingMargin(child, mainAxis) +
                  getRelativePosition(child, mainAxis);
                child->layout.position[leading[crossAxis]] -= getLeadingMargin(child, crossAxis) +
                  getRelativePosition(child, crossAxis);
                child->layout.position[trailing[crossAxis]] -= getTrailingMargin(child, crossAxis) +
                  getRelativePosition(child, crossAxis);

                // Recursively lay out the child view
                layoutNode(child, maxWidth, maxHeight, direction);
              }
            }
          } else if (alignItem != CSS_ALIGN_FLEX_START) {
            // The remaining space on the cross axis equals the parent's cross-axis size minus the child's cross-axis padding, border, margin, and size
            float remainingCrossDim = containerCrossAxis -
              paddingAndBorderAxisCross - getDimWithMargin(child, crossAxis);

            if (alignItem == CSS_ALIGN_CENTER) {
              leadingCrossDim += remainingCrossDim / 2;
            } else { // CSS_ALIGN_FLEX_END
              leadingCrossDim += remainingCrossDim;
            }
          }
        }

        // Determine the child's position on the cross axis
        child->layout.position[pos[crossAxis]] += linesCrossDim + leadingCrossDim;

        // Determine the trailing position
        if (isCrossDimDefined) {
          setTrailingPosition(node, child, crossAxis);
        }
      }
    }

    linesCrossDim += crossDim;
    linesMainDim = fmaxf(linesMainDim, mainDim);
    linesCount += 1;
    startLine = endLine;
  }


```
Loop D above mainly computes the subviews’ coordinates on the cross axis. If a view’s size changes, its subviews also need to be recursively traversed and laid out again.


Next comes loop E.
```c


  if (linesCount > 1 && isCrossDimDefined) {
    float nodeCrossAxisInnerSize = node->layout.dimensions[dim[crossAxis]] -
        paddingAndBorderAxisCross;
    float remainingAlignContentDim = nodeCrossAxisInnerSize - linesCrossDim;

    float crossDimLead = 0;
    float currentLead = leadingPaddingAndBorderCross;

    // Layout alignContent
    css_align_t alignContent = node->style.align_content;
    if (alignContent == CSS_ALIGN_FLEX_END) {
      currentLead += remainingAlignContentDim;
    } else if (alignContent == CSS_ALIGN_CENTER) {
      currentLead += remainingAlignContentDim / 2;
    } else if (alignContent == CSS_ALIGN_STRETCH) {
      if (nodeCrossAxisInnerSize > linesCrossDim) {
        crossDimLead = (remainingAlignContentDim / linesCount);
      }
    }

    int endIndex = 0;
    for (i = 0; i < linesCount; ++i) {
      int startIndex = endIndex;

      // Calculate the line height of each row. The line height is the maximum of lineHeight and the sum of the child view's height on the cross axis plus the top and bottom margins.
      float lineHeight = 0;
      for (ii = startIndex; ii < childCount; ++ii) {
        child = node->get_child(node->context, ii);
        if (child->style.position_type != CSS_POSITION_RELATIVE) {
          continue;
        }
        if (child->line_index != i) {
          break;
        }
        if (isLayoutDimDefined(child, crossAxis)) {
          lineHeight = fmaxf(
            lineHeight,
            child->layout.dimensions[dim[crossAxis]] + getMarginAxis(child, crossAxis)
          );
        }
      }
      endIndex = ii;
      lineHeight += crossDimLead;

      for (ii = startIndex; ii < endIndex; ++ii) {
        child = node->get_child(node->context, ii);
        if (child->style.position_type != CSS_POSITION_RELATIVE) {
          continue;
        }

        // Layout AlignItem
        css_align_t alignContentAlignItem = getAlignItem(node, child);
        if (alignContentAlignItem == CSS_ALIGN_FLEX_START) {
          child->layout.position[pos[crossAxis]] = currentLead + getLeadingMargin(child, crossAxis);
        } else if (alignContentAlignItem == CSS_ALIGN_FLEX_END) {
          child->layout.position[pos[crossAxis]] = currentLead + lineHeight - getTrailingMargin(child, crossAxis) - child->layout.dimensions[dim[crossAxis]];
        } else if (alignContentAlignItem == CSS_ALIGN_CENTER) {
          float childHeight = child->layout.dimensions[dim[crossAxis]];
          child->layout.position[pos[crossAxis]] = currentLead + (lineHeight - childHeight) / 2;
        } else if (alignContentAlignItem == CSS_ALIGN_STRETCH) {
          child->layout.position[pos[crossAxis]] = currentLead + getLeadingMargin(child, crossAxis);
          // TODO(prenaux): Correctly set the height of items with undefined
          //                (auto) crossAxis dimension.
        }
      }

      currentLead += lineHeight;
    }
  }


```
Executing loop E has a prerequisite: there must be more than one line, and a height must be defined on the cross axis. Only after this prerequisite is satisfied will the following align rules begin to apply.

Loop E handles the align stretching rules on the cross axis. This is where `alignContent` and `AlignItem` are laid out.

For the algorithmic principle implemented by this code, see section 9.4 of [http://www.w3.org/TR/2012/CR-css3-flexbox-20120918/#layout-algorithm](http://www.w3.org/TR/2012/CR-css3-flexbox-20120918/#layout-algorithm).


At this point, there may still be some views with no specified width or height. These will be handled in the final pass.
```c


  // If a view has no specified width or height, and its parent has not set its width or height, set the width and height here based on its child views.
  if (!isMainDimDefined) {
    // The view's width equals the inner child view width plus the trailing padding and border width, and the leading padding, border + trailing padding, border on the main axis; take the maximum.
    node->layout.dimensions[dim[mainAxis]] = fmaxf(
      boundAxis(node, mainAxis, linesMainDim + getTrailingPaddingAndBorder(node, mainAxis)),
      paddingAndBorderAxisMain
    );

    if (mainAxis == CSS_FLEX_DIRECTION_ROW_REVERSE ||
        mainAxis == CSS_FLEX_DIRECTION_COLUMN_REVERSE) {
      needsMainTrailingPos = true;
    }
  }

  if (!isCrossDimDefined) {
    node->layout.dimensions[dim[crossAxis]] = fmaxf(
      // The view's height equals the inner child view height plus the top and bottom padding and border width, and the padding and border on the cross axis; take the maximum.
      boundAxis(node, crossAxis, linesCrossDim + paddingAndBorderAxisCross),
      paddingAndBorderAxisCross
    );

    if (crossAxis == CSS_FLEX_DIRECTION_ROW_REVERSE ||
        crossAxis == CSS_FLEX_DIRECTION_COLUMN_REVERSE) {
      needsCrossTrailingPos = true;
    }
  }


```
The width and height of these subviews that do not have fixed dimensions are determined by the parent view. The approach is shown in the code above.

Then there’s loop F.
```c


  if (needsMainTrailingPos || needsCrossTrailingPos) {
    for (i = 0; i < childCount; ++i) {
      child = node->get_child(node->context, i);

      if (needsMainTrailingPos) {
        setTrailingPosition(node, child, mainAxis);
      }

      if (needsCrossTrailingPos) {
        setTrailingPosition(node, child, crossAxis);
      }
    }
  }


```
This step sets the Trailing coordinate of the current node, if necessary. If it is not needed, this step is skipped.

The final step is to loop over G.
```c

  currentAbsoluteChild = firstAbsoluteChild;
  while (currentAbsoluteChild != NULL) {
    for (ii = 0; ii < 2; ii++) {
      axis = (ii != 0) ? CSS_FLEX_DIRECTION_ROW : CSS_FLEX_DIRECTION_COLUMN;

      if (isLayoutDimDefined(node, axis) &&
          !isStyleDimDefined(currentAbsoluteChild, axis) &&
          isPosDefined(currentAbsoluteChild, leading[axis]) &&
          isPosDefined(currentAbsoluteChild, trailing[axis])) {
        // The width of an absolutely positioned child view on the main axis and its height on the cross axis cannot be less than the sum of Padding and Border.
        currentAbsoluteChild->layout.dimensions[dim[axis]] = fmaxf(
          boundAxis(currentAbsoluteChild, axis, node->layout.dimensions[dim[axis]] -
            getBorderAxis(node, axis) -
            getMarginAxis(currentAbsoluteChild, axis) -
            getPosition(currentAbsoluteChild, leading[axis]) -
            getPosition(currentAbsoluteChild, trailing[axis])
          ),
          getPaddingAndBorderAxis(currentAbsoluteChild, axis)
        );
      }

      if (isPosDefined(currentAbsoluteChild, trailing[axis]) &&
          !isPosDefined(currentAbsoluteChild, leading[axis])) {
        // The current child view's coordinate equals the current view's width minus the child view's width and then minus trailing
        currentAbsoluteChild->layout.position[leading[axis]] =
          node->layout.dimensions[dim[axis]] -
          currentAbsoluteChild->layout.dimensions[dim[axis]] -
          getPosition(currentAbsoluteChild, trailing[axis]);
      }
    }

    child = currentAbsoluteChild;
    currentAbsoluteChild = currentAbsoluteChild->next_absolute_child;
    child->next_absolute_child = NULL;
  }


```
This final loop G is used to compute the width and height for subviews with absolute coordinates.

After the seven loops above have completed, layout is finished for all subviews.

To summarize the process above, see the following diagram:


![](http://upload-images.jianshu.io/upload_images/1194012-fc141fa8e3dc0433.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


### II. Weex Layout Algorithm Performance Analysis


#### 1. Algorithm Implementation Analysis

The previous section covered the implementation of Weex's layout algorithm. Here we will analyze how capable this implementation actually is in terms of layout.

Weex's implementation is the predecessor of Facebook's open-source Yoga library, so the two can be considered the same kind of implementation.

This FlexBox implementation in Weex is actually only a subset of the W3C standard, because the official FlexBox standard includes some features that are not implemented here. The FlexBox standard defined by the W3C is documented [here](https://www.w3.org/TR/css-flexbox-1/).

The FlexBox standard defines:

For the parent view (flex container):
1. display
2. flex\-direction
3. flex\-wrap
4. flex\-flow
5. justify\-content
6. align\-items
7. align\-content

For child views (flex items):
1. order
2. flex\-grow
3. flex\-shrink
4. flex\-basis
5. flex
6. align\-self

![](http://upload-images.jianshu.io/upload_images/1194012-63e820c1ee9472cf.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Compared with the official definition, the implementation above has some limitations:

1. All node nodes with display attributes are assumed by default to be Flex views, excluding text nodes, of course, because they are assumed to be inline-flex.
2. The zIndex attribute is not supported, including any ordering along the z axis. All node nodes are arranged in the order in which they are written in code. Weex currently also does not support using z-index to set element layering relationships, but elements that appear later have a higher layer; therefore, for elements that need a higher layer, you can place them later.
3. The order property defined in FlexBox is also not supported. flex items default to the order in which they are written in code.
4. The visibility property is visible by default, and edge collapse merging (collapse) and hidden are not supported for now.
5. Forced breaks are not supported.
6. Vertical inline layout is not supported (for example, text from top to bottom, or text from bottom to top).

The concrete implementation of Flexbox on iOS was already analyzed in the previous section.


![](http://upload-images.jianshu.io/upload_images/1194012-2a97e349befdc557.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Next, let's take a close look at the concrete implementation of Autolayout.


![](http://upload-images.jianshu.io/upload_images/1194012-6b994236e0c27d79.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Previously, when laying out with Frame, knowing one point (origin or center) plus width and height was enough to determine a View.

Now with Autolayout, each View needs four dimensions: left, top, width, and height.

However, a View's constraints are relative to another View, such as its parent view, or relative to pairs of Views.

Constraints between two Views therefore become a system of linear equations with eight variables.


Solving this system of equations may result in the following three cases:

1. If the system has infinitely many solutions, the final result is an under-constrained, ambiguous layout.
2. If the system has no solution, the constraints are in conflict.
3. Only when the system has a unique solution can a stable layout be obtained.

**Autolayout is essentially a linear equation solver that attempts to find a geometric expression satisfying its rules.**


![](http://upload-images.jianshu.io/upload_images/1194012-09b7902e4c7c67e5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The underlying mathematical model of Autolayout is a linear arithmetic constraint problem.


As early as 1940, Dantzig proposed the simplex algorithm for this problem. However, because this algorithm was extremely difficult to apply to UI applications, it was not widely used. It was not until 1997, when two students at Monash University in Australia, Alan Borning and Kim Marriott, implemented the Cassowary linear constraint algorithm, that it began to be widely applied in UI applications.

The Cassowary linear constraint algorithm is based on the dual simplex algorithm. When constraints are added or an object is removed, it can perfectly handle constraints at different levels incrementally through local error gain and weighted-sum comparison. The Cassowary linear constraint algorithm is suitable for GUI layout systems and is used to compute the positions among views. Developers can specify positional relationships and constraint relationships among different Views, and the Cassowary linear constraint algorithm will find the optimal values satisfying those conditions.

Below are related papers written by the two students. If interested, you can read them to understand the concrete implementation of the algorithm:

1. Alan Borning, Kim Marriott, Peter Stuckey, and Yi Xiao, [Solving Linear Arithmetic Constraints for User Interface Applications](https://constraints.cs.washington.edu/solvers/uist97.pdf), Proceedings of the 1997 ACM Symposium on User Interface Software and Technology, October 1997, pages 87-96.
2. Greg J. Badros and Alan Borning, "The Cassowary Linear Arithmetic Constraint Solving Algorithm: Interface and Implementation", Technical Report UW-CSE-98-06-04, June 1998 ([pdf](https://constraints.cs.washington.edu/cassowary/cassowary-tr.pdf))
3. Greg J. Badros, Alan Borning, and Peter J. Stuckey, "The Cassowary Linear Arithmetic Constraint Solving Algorithm," *ACM Transactions on Computer Human Interaction*, Vol. 8 No. 4, December 2001, pages 267-306. ([pdf](https://constraints.cs.washington.edu/solvers/cassowary-tochi.pdf))

The pseudocode for the Cassowary linear constraint algorithm is as follows:

![](http://upload-images.jianshu.io/upload_images/1194012-2f208ced7d958ce8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


This algorithm has already been implemented in various versions. One year later, a new QOCA algorithm was released. The following passage is excerpted from an article in an authoritative ACM paper from 1997:

>Both of our algorithms have been implemented, Cassowary
in Smalltalk and QOCA in C++. They perform surprisingly
well. The QOCA implementation is considerably more sophisticated
and has much better performance than the current version of
Cassowary. However, QOCA is inherently a more complex
algorithm, and re-implementing it with a comparable level
of performance would be a daunting task. In contrast, Cassowary
is straightforward, and a reimplementation based on
this paper is more reasonable, given a knowledge of the simplex
algorithm.


Cassowary ([project homepage](https://constraints.cs.washington.edu/cassowary/)) was also first implemented in Smalltalk and is also used in Autolayout technology. There is also the more complex QOCA algorithm, which we will not go into here. Interested readers can read the three papers above, which describe it in detail.


#### 2. Preparation for Algorithm Performance Testing

Initially, I planned to test Weex's layout performance as well. However, because Weex performs layout on a child thread and then returns to the main thread for refresh and rendering, testing the scenario where everything runs on the main thread would require modifying some code. In addition, Weex's native layout is invoked from JS; using that approach would introduce additional performance overhead and affect the test results. Therefore, I switched to testing the Yoga algorithm, which uses the same layout approach as Weex. Facebook has wrapped it very well, so it is also convenient to use. Although the layout algorithm has some differences from Weex, that does not affect the qualitative comparison.


The test targets are therefore: Frame, FlexBox (Yoga implementation), and Autolayout.

Before testing, we also need to prepare test models. Here, three test models are selected.

The first test model randomly generates completely unrelated Views, as shown below:

![](http://upload-images.jianshu.io/upload_images/1194012-a7a0d48cba94f3d9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The second test model generates mutually nested Views. The nesting rule is set to something simple: each child view is one pixel shorter in height than its parent view. Similar to the figure below, this is the result of 500 mutually nested Views:

![](http://upload-images.jianshu.io/upload_images/1194012-0828ddc58f8d30ca.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The third test model is added specifically for Autolayout. Because of the particular nature of Autolayout constraints, an additional test model is added here for chained constraints. The rule is to add constraints sequentially between two adjacent Views. Similar to the figure below, this is the result of chained constraints across 500 Views:

![](http://upload-images.jianshu.io/upload_images/1194012-1b8f68cd9debed67.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Based on the test models, we can derive the following seven test cases to be tested:

1.Frame
2.Nested Frame
3.Yoga
4.Nested Yoga
5.Autolayout
6.Nested Autolayout
7.Chained Autolayout


Test samples: Because generality needs to be considered, the test samples should be as random as possible. Therefore, all randomly generated coordinates are generated randomly, and the colors of the Views are also generated randomly, ensuring generality, impartiality, and fairness.

Number of tests: To ensure that the test data is as realistic as possible, I spent a lot of time here. Each group of test cases is run against 100, 200, 300, 400, 500, 600, 700, 800, 900, and 1000 views. To ensure generality, each test is run 10,000 times, and the results of the 10,000 runs are summed and averaged. The average is kept to five decimal places. (The statistics for the 10,000 runs are computed by the computer, but it is truly, truly, truly time-consuming. If interested, you can try it on your own machine.)

Finally, here are the configuration and system version of the test machine:

(Because a real iPhone has memory limits for each App, generating 1000 nested views and running 10,000 experiments was completely too much for the real iPhone. The App crashed immediately. So halfway through testing on the device, I switched to the simulator. With the help of the Mac's performance, I gritted my teeth and started from scratch, re-collecting data for all test cases.)

If you have a more powerful Mac (the trash can), the full test process may take less time.

The configuration of the computer I used is as follows:


![](http://upload-images.jianshu.io/upload_images/1194012-510c7d7ab97e2330.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The simulator used for testing was iPad Pro (12.9 inch) iOS 10.3 (14E269).


The test code I used has also been published. If interested, you can test it yourself. [The test code is here](https://github.com/halfrost/Halfrost-Field/tree/master/contents/iOS/AutoLayoutProfiling-master)  

#### 3. Algorithm Performance Test Results

Here are the test results:

![](http://upload-images.jianshu.io/upload_images/1194012-34171d65db564340.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The data above shows the results of testing 10, 20, 30, 40, 50, 60, 70, 80, 90, and 100 Views with the seven groups of test cases. Plotting the results above as a line chart gives the following:

![](http://upload-images.jianshu.io/upload_images/1194012-f9468b0f10f0ef95.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The three Autolayout approaches are still all higher than the other four layout approaches.

![](http://upload-images.jianshu.io/upload_images/1194012-7f51f5e34c9e5485.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The figure above compares the performance of the three layout algorithms in ordinary scenarios. As you can see, FlexBox performance is close to native Frame.

![](http://upload-images.jianshu.io/upload_images/1194012-64f5f7c2e89e2661.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The figure above compares the performance of the three layout algorithms in nested scenarios. As you can see, FlexBox performance is still close to native Frame. Autolayout performance drops sharply in nested scenarios.

![](http://upload-images.jianshu.io/upload_images/1194012-409f0c3e820c5770.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


This final chart is also an additional group of tests added specifically for Autolayout. The purpose is to compare Autolayout performance across the three scenarios. As you can see, nested Autolayout still has the worst performance!


![](http://upload-images.jianshu.io/upload_images/1194012-6b338b4507694268.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The data above shows the results of testing 100, 200, 300, 400, 500, 600, 700, 800, 900, and 1000 Views with the seven groups of test cases. Plotting the results above as a line chart gives the following:


![](http://upload-images.jianshu.io/upload_images/1194012-e60d70a0eaa4a67f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

When the number of views reaches 900 or 1000, nested Autolayout directly causes the simulator to crash.

![](http://upload-images.jianshu.io/upload_images/1194012-4560c9da3bfa0968.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The figure above compares the performance of the three layout algorithms in ordinary scenarios. As you can see, FlexBox performance is close to native Frame.

![](http://upload-images.jianshu.io/upload_images/1194012-cad15676ac4504b7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The figure above compares the performance of the three layout algorithms in nested scenarios. As you can see, FlexBox performance is still close to native Frame. Autolayout performance drops sharply in nested scenarios.

![](http://upload-images.jianshu.io/upload_images/1194012-c71dbeba866e73fb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

This final chart is an additional group of tests added specifically for Autolayout. The purpose is to compare Autolayout performance across the three scenarios. As you can see, the nested Autolayout we commonly use has the worst performance!

### III. How Weex Lays Out Native Interfaces


In the previous section, we saw the powerful layout capabilities of the FlexBox algorithm. In this section, let’s take a look at how Weex leverages those capabilities to lay out native Views.


Before answering that question, let’s first review what was mentioned in the previous article, [“How Weex Runs on the iOS Client”](http://www.jianshu.com/p/41cde2c62b81): before JSFramework transforms the JS file downloaded from the network, the native side first registers four important callback functions.
```objectivec

typedef NSInteger(^WXJSCallNative)(NSString *instance, NSArray *tasks, NSString *callback);
typedef NSInteger(^WXJSCallAddElement)(NSString *instanceId,  NSString *parentRef, NSDictionary *elementData, NSInteger index);
typedef NSInvocation *(^WXJSCallNativeModule)(NSString *instanceId, NSString *moduleName, NSString *methodName, NSArray *args, NSDictionary *options);
typedef void (^WXJSCallNativeComponent)(NSString *instanceId, NSString *componentRef, NSString *methodName, NSArray *args, NSDictionary *options);


```
These four blocks are very important; they are the four core functions for mutual calls between JS and OC.

First, let’s review which closures were encapsulated when these four core functions were registered.
```objectivec

@interface WXBridgeContext ()
@property (nonatomic, strong) id<WXBridgeProtocol>  jsBridge;

```
There is a `jsBridge` in the `WXBridgeContext` class. When `jsBridge` is initialized, it registers these four global functions.

The first closure function:
```objectivec

    [_jsBridge registerCallNative:^NSInteger(NSString *instance, NSArray *tasks, NSString *callback) {
        return [weakSelf invokeNative:instance tasks:tasks callback:callback];
    }];


```
The closure function here will be passed into the following function:
```objectivec

- (void)registerCallNative:(WXJSCallNative)callNative
{
    JSValue* (^callNativeBlock)(JSValue *, JSValue *, JSValue *) = ^JSValue*(JSValue *instance, JSValue *tasks, JSValue *callback){
        NSString *instanceId = [instance toString];
        NSArray *tasksArray = [tasks toArray];
        NSString *callbackId = [callback toString];
        
        WXLogDebug(@"Calling native... instance:%@, tasks:%@, callback:%@", instanceId, tasksArray, callbackId);
        return [JSValue valueWithInt32:(int32_t)callNative(instanceId, tasksArray, callbackId) inContext:[JSContext currentContext]];
    };
    
    _jsContext[@"callNative"] = callNativeBlock;
}


```
Here we encapsulate a function and expose it for JS to use. The method is called `callNative`, and it takes three parameters: `instanceId`, `tasksArray`, and `callbackId`.

All Objective-C closures need to be wrapped in an extra layer, because methods exposed to JS cannot contain colons. All parameters are placed directly in the parameter list inside the parentheses, since that is how JS functions are defined.

After JS calls the `callNative` method, it will eventually execute the `[weakSelf invokeNative:instance tasks:tasks callback:callback]` method in the `WXBridgeContext` class.

The second closure function:
```objectivec

    [_jsBridge registerCallAddElement:^NSInteger(NSString *instanceId, NSString *parentRef, NSDictionary *elementData, NSInteger index) {
        // Temporary here , in order to improve performance, will be refactored next version.
        WXSDKInstance *instance = [WXSDKManager instanceForID:instanceId];
        
        if (!instance) {
            WXLogInfo(@"instance not found, maybe already destroyed");
            return -1;
        }
        WXPerformBlockOnComponentThread(^{
            WXComponentManager *manager = instance.componentManager;
            if (!manager.isValid) {
                return;
            }
            [manager startComponentTasks];
            [manager addComponent:elementData toSupercomponent:parentRef atIndex:index appendingInTree:NO];
        });
        
        return 0;
    }];

```
This closure will be passed to the function below:
```objectivec


- (void)registerCallAddElement:(WXJSCallAddElement)callAddElement
{
    id callAddElementBlock = ^(JSValue *instanceId, JSValue *ref, JSValue *element, JSValue *index, JSValue *ifCallback) {
        
        NSString *instanceIdString = [instanceId toString];
        NSDictionary *componentData = [element toDictionary];
        NSString *parentRef = [ref toString];
        NSInteger insertIndex = [[index toNumber] integerValue];
        
         WXLogDebug(@"callAddElement...%@, %@, %@, %ld", instanceIdString, parentRef, componentData, (long)insertIndex);
        
        return [JSValue valueWithInt32:(int32_t)callAddElement(instanceIdString, parentRef, componentData, insertIndex) inContext:[JSContext currentContext]];
    };

    _jsContext[@"callAddElement"] = callAddElementBlock;
}

```
The wrapping method here is the same as the first method. The method exposed to JS is named `callAddElement`, and it takes four parameters: `instanceIdString`, `componentData` (the component data), `parentRef` (the reference ID), and `insertIndex` (the index at which to insert the view).

When JS calls the `callAddElement` method, it ultimately executes the `WXPerformBlockOnComponentThread` closure in the `WXBridgeContext` class.

The third closure function:
```objectivec


    [_jsBridge registerCallNativeModule:^NSInvocation*(NSString *instanceId, NSString *moduleName, NSString *methodName, NSArray *arguments, NSDictionary *options) {
        WXSDKInstance *instance = [WXSDKManager instanceForID:instanceId];
        
        if (!instance) {
            WXLogInfo(@"instance not found for callNativeModule:%@.%@, maybe already destroyed", moduleName, methodName);
            return nil;
        }
        
        WXModuleMethod *method = [[WXModuleMethod alloc] initWithModuleName:moduleName methodName:methodName arguments:arguments instance:instance];
        return [method invoke];
    }];


```
This closure will be passed to the following function:
```objectivec


- (void)registerCallNativeModule:(WXJSCallNativeModule)callNativeModuleBlock
{
    _jsContext[@"callNativeModule"] = ^JSValue *(JSValue *instanceId, JSValue *moduleName, JSValue *methodName, JSValue *args, JSValue *options) {
        NSString *instanceIdString = [instanceId toString];
        NSString *moduleNameString = [moduleName toString];
        NSString *methodNameString = [methodName toString];
        NSArray *argsArray = [args toArray];
        NSDictionary *optionsDic = [options toDictionary];
        
        WXLogDebug(@"callNativeModule...%@,%@,%@,%@", instanceIdString, moduleNameString, methodNameString, argsArray);
        
        NSInvocation *invocation = callNativeModuleBlock(instanceIdString, moduleNameString, methodNameString, argsArray, optionsDic);
        JSValue *returnValue = [JSValue wx_valueWithReturnValueFromInvocation:invocation inContext:[JSContext currentContext]];
        return returnValue;
    };
}


```
The method exposed to JS is named callNativeModule. The function takes five parameters: instanceIdString, moduleNameString (module name), methodNameString (method name), argsArray (argument array), and optionsDic (dictionary).

When JS calls the callNativeModule method, it will ultimately execute the WXModuleMethod method in the WXBridgeContext class.


The fourth closure function:
```objectivec


    [_jsBridge registerCallNativeComponent:^void(NSString *instanceId, NSString *componentRef, NSString *methodName, NSArray *args, NSDictionary *options) {
        WXSDKInstance *instance = [WXSDKManager instanceForID:instanceId];
        WXComponentMethod *method = [[WXComponentMethod alloc] initWithComponentRef:componentRef methodName:methodName arguments:args instance:instance];
        [method invoke];
    }];

```
This closure will be passed to the function below:
```objectivec

- (void)registerCallNativeComponent:(WXJSCallNativeComponent)callNativeComponentBlock
{
    _jsContext[@"callNativeComponent"] = ^void(JSValue *instanceId, JSValue *componentName, JSValue *methodName, JSValue *args, JSValue *options) {
        NSString *instanceIdString = [instanceId toString];
        NSString *componentNameString = [componentName toString];
        NSString *methodNameString = [methodName toString];
        NSArray *argsArray = [args toArray];
        NSDictionary *optionsDic = [options toDictionary];
        
        WXLogDebug(@"callNativeComponent...%@,%@,%@,%@", instanceIdString, componentNameString, methodNameString, argsArray);
        
        callNativeComponentBlock(instanceIdString, componentNameString, methodNameString, argsArray, optionsDic);
    };
}


```
The method exposed to JS is called callNativeComponent. It takes five parameters: instanceIdString, componentNameString (component name), methodNameString (method name), argsArray (argument array), and optionsDic (dictionary).

When JS calls the callNativeComponent method, it ultimately executes the WXComponentMethod method in the WXBridgeContext class.


![](http://upload-images.jianshu.io/upload_images/1194012-23bfe161375b750a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


To summarize, the four methods exposed to JS above are:

1. callNative
This method is used by JS to call any Native method.

2. callAddElement
This method is used by JS to add view elements to the current page.

3. callNativeModule
This method is used by JS to call methods exposed by a module.

4. callNativeComponent
This method is used by JS to call methods exposed by a component.


During layout, Weex only uses the first two methods.

#### (1) createRoot:


After JSFramework converts the JS file into a JSON-like file, it starts calling Native’s callNative method.

The callNative method ultimately executes the [weakSelf invokeNative:instance tasks:tasks callback:callback] method in the WXBridgeContext class.


The current operation is running on the child thread “com.taobao.weex.bridge”.
```objectivec


- (NSInteger)invokeNative:(NSString *)instanceId tasks:(NSArray *)tasks callback:(NSString __unused*)callback
{
    WXAssertBridgeThread();
    
    if (!instanceId || !tasks) {
        WX_MONITOR_FAIL(WXMTNativeRender, WX_ERR_JSFUNC_PARAM, @"JS call Native params error!");
        return 0;
    }

    WXSDKInstance *instance = [WXSDKManager instanceForID:instanceId];
    if (!instance) {
        WXLogInfo(@"instance already destroyed, task ignored");
        return -1;
    }
    

    // Convert methods sent from JS into Native method calls
    for (NSDictionary *task in tasks) {
        NSString *methodName = task[@"method"];
        NSArray *arguments = task[@"args"];
        if (task[@"component"]) {
            NSString *ref = task[@"ref"];
            WXComponentMethod *method = [[WXComponentMethod alloc] initWithComponentRef:ref methodName:methodName arguments:arguments instance:instance];
            [method invoke];
        } else {
            NSString *moduleName = task[@"module"];
            WXModuleMethod *method = [[WXModuleMethod alloc] initWithModuleName:moduleName methodName:methodName arguments:arguments instance:instance];
            [method invoke];
        }
    }
    
    // If there is a callback, call back to JS
    [self performSelector:@selector(_sendQueueLoop) withObject:nil];
    
    return 1;
}


```
This converts the `callNative` method sent from JS into either a method call on a Native component `component` or a method call on a module `module`.

For example:

JS passes 3 parameters through the `callNative` method.
```objecitvec

instance:0,

tasks:(
        {
        args =         (
                        {
                attr =                 {
                };
                ref = "_root";
                style =                 {
                    alignItems = center;
                };
                type = div;
            }
        );
        method = createBody;
        module = dom;
    }
), 

callback:-1

```
The `tasks` array is parsed to extract each method and its caller.

In this example, it will parse out the `createBody` method of the `Dom` module.

Then it will invoke the `createBody` method of the `Dom` module.
```objectivec


    if (isSync) {
        [invocation invoke];
        return invocation;
    } else {
        [self _dispatchInvocation:invocation moduleInstance:moduleInstance];
        return nil;
    }

```
Before invoking the method, there is a thread-switching step. If it is a synchronous method, it is called directly; if it is an asynchronous method, a thread switch is still required.

The `createBody` method in the Dom module is asynchronous, so the \_dispatchInvocation: moduleInstance: method needs to be called.
```objectivec


- (void)_dispatchInvocation:(NSInvocation *)invocation moduleInstance:(id<WXModuleProtocol>)moduleInstance
{
    // dispatch to user specified queue or thread, default is main thread
    dispatch_block_t dispatchBlock = ^ (){
        [invocation invoke];
    };
    
    NSThread *targetThread = nil;
    dispatch_queue_t targetQueue = nil;

    if([moduleInstance respondsToSelector:@selector(targetExecuteQueue)]){
        // Check whether there is a Queue; if not, return main_queue; if so, switch to targetQueue
        targetQueue = [moduleInstance targetExecuteQueue] ?: dispatch_get_main_queue();
    } else if([moduleInstance respondsToSelector:@selector(targetExecuteThread)]){
        // Check whether there is a Thread; if not, return the main thread; if so, switch to targetThread
        targetThread = [moduleInstance targetExecuteThread] ?: [NSThread mainThread];
    } else {
        targetThread = [NSThread mainThread];
    }

    WXAssert(targetQueue || targetThread, @"No queue or thread found for module:%@", moduleInstance);
    
    if (targetQueue) {
        dispatch_async(targetQueue, dispatchBlock);
    } else {
        WXPerformBlockOnThread(^{
            dispatchBlock();
        }, targetThread);
    }
}


```
Across the entire Weex module, only two modules currently have a `targetQueue`: `WXClipboardModule` and `WXStorageModule`. Since there is no `targetQueue` here, we can only switch to the corresponding `targetThread`.
```objectivec

void WXPerformBlockOnThread(void (^ _Nonnull block)(), NSThread *thread)
{
    [WXUtility performBlock:block onThread:thread];
}

+ (void)performBlock:(void (^)())block onThread:(NSThread *)thread
{
    if (!thread || !block) return;
    
    // If the current thread is not the target thread, switch threads
    if ([NSThread currentThread] == thread) {
        block();
    } else {
        [self performSelector:@selector(_performBlock:)
                     onThread:thread
                   withObject:[block copy]
                waitUntilDone:NO];
    }
}

```
This is where the thread switch happens. If the current thread is not the target thread, it switches threads. The \_performBlock: method is invoked on the target thread, with the original block closure passed in as the argument.

Before the switch, the thread is on the background thread “com.taobao.weex.bridge”.


The targetExecuteThread method is called in WXDomModule.
```objectivec


- (NSThread *)targetExecuteThread
{
    return [WXComponentManager componentThread];
}


```
After switching threads, the current thread became `com.taobao.weex.component`.
```objectivec

- (void)createBody:(NSDictionary *)body
{
    [self performBlockOnComponentManager:^(WXComponentManager *manager) {
        [manager createRoot:body];
    }];
}


- (void)performBlockOnComponentManager:(void(^)(WXComponentManager *))block
{
    if (!block) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    
    WXPerformBlockOnComponentThread(^{
        WXComponentManager *manager = weakSelf.weexInstance.componentManager;
        if (!manager.isValid) {
            return;
        }

        // Start component tasks
        [manager startComponentTasks];
        block(manager);
    });
}


```
After the DOM module’s `createBody` method is called, it first calls `WXComponentManager`’s `startComponentTasks` method, and then calls the `createRoot:` method.

A `WXComponentManager` is initialized here.
```objectivec

- (WXComponentManager *)componentManager
{
    if (!_componentManager) {
        _componentManager = [[WXComponentManager alloc] initWithWeexInstance:self];
    }
    
    return _componentManager;
}


- (instancetype)initWithWeexInstance:(id)weexInstance
{
    if (self = [self init]) {
        _weexInstance = weexInstance;
        
        _indexDict = [NSMapTable strongToWeakObjectsMapTable];
        _fixedComponents = [NSMutableArray wx_mutableArrayUsingWeakReferences];
        _uiTaskQueue = [NSMutableArray array];
        _isValid = YES;
        [self _startDisplayLink];
    }
    
    return self;
}


```
The key point of `WXComponentManager` initialization is that it starts `DisplayLink`, which in turn starts a run loop.
```objectivec

- (void)_startDisplayLink
{
    WXAssertComponentThread();
    
    if(!_displayLink){
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_handleDisplayLink)];
        [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    }
}

```
Once `displayLink` is enabled, it is added to the current run loop. Each time the run loop iterates, the layout refresh method \_handleDisplayLink is executed.
```objectivec

- (void)startComponentTasks
{
    [self _awakeDisplayLink];
}

- (void)_awakeDisplayLink
{
    WXAssertComponentThread();
    if(_displayLink && _displayLink.paused) {
        _displayLink.paused = NO;
    }
}

```
The `startComponentTasks` method of `WXComponentManager` merely changes the `paused` state of `CADisplayLink`. `CADisplayLink` is used to refresh the layout.
```objectivec

@implementation WXComponentManager
{
    // Weak reference to WXSDKInstance
    __weak WXSDKInstance *_weexInstance;
    // Whether current WXComponentManager is available
    BOOL _isValid;
    
    // Whether to stop refreshing layout
    BOOL _stopRunning;
    NSUInteger _noTaskTickCount;
    
    // access only on component thread
    NSMapTable<NSString *, WXComponent *> *_indexDict;
    NSMutableArray<dispatch_block_t> *_uiTaskQueue;
    
    WXComponent *_rootComponent;
    NSMutableArray *_fixedComponents;
    
    css_node_t *_rootCSSNode;
    CADisplayLink *_displayLink;
}

```
These are all the properties of `WXComponentManager`. As you can see, `WXComponentManager` is used to handle UI tasks.

Now let’s look at the `createRoot:` method:
```objectivec


- (void)createRoot:(NSDictionary *)data
{
    WXAssertComponentThread();
    WXAssertParam(data);
    
    // 1.Create WXComponent as rootComponent
    _rootComponent = [self _buildComponentForData:data];

    // 2.Initialize css_node_t as rootCSSNode
    [self _initRootCSSNode];
    
    __weak typeof(self) weakSelf = self;
    // 3.Add UI task to the uiTaskQueue array
    [self _addUITask:^{
        __strong typeof(self) strongSelf = weakSelf;
        strongSelf.weexInstance.rootView.wx_component = strongSelf->_rootComponent;
        [strongSelf.weexInstance.rootView addSubview:strongSelf->_rootComponent.view];
    }];
}

```
Three things happen here:

#### 1. Create WXComponent
```objectivec

- (WXComponent *)_buildComponentForData:(NSDictionary *)data
{
    NSString *ref = data[@"ref"];
    NSString *type = data[@"type"];
    NSDictionary *styles = data[@"style"];
    NSDictionary *attributes = data[@"attr"];
    NSArray *events = data[@"event"];
        
    Class clazz = [WXComponentFactory classWithComponentName:type];
    WXComponent *component = [[clazz alloc] initWithRef:ref type:type styles:styles attributes:attributes events:events weexInstance:self.weexInstance];
    WXAssert(component, @"Component build failed for data:%@", data);
    
    [_indexDict setObject:component forKey:component.ref];
    
    return component;
}

```
The input parameter `data` here is the previous `tasks` array.
```objectivec

- (instancetype)initWithRef:(NSString *)ref
                       type:(NSString *)type
                     styles:(NSDictionary *)styles
                 attributes:(NSDictionary *)attributes
                     events:(NSArray *)events
               weexInstance:(WXSDKInstance *)weexInstance
{
    if (self = [super init]) {
        pthread_mutexattr_init(&_propertMutexAttr);
        pthread_mutexattr_settype(&_propertMutexAttr, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_propertyMutex, &_propertMutexAttr);
        
        _ref = ref;
        _type = type;
        _weexInstance = weexInstance;
        _styles = [self parseStyles:styles];
        _attributes = attributes ? [NSMutableDictionary dictionaryWithDictionary:attributes] : [NSMutableDictionary dictionary];
        _events = events ? [NSMutableArray arrayWithArray:events] : [NSMutableArray array];
        _subcomponents = [NSMutableArray array];
        
        _absolutePosition = CGPointMake(NAN, NAN);
        
        _isNeedJoinLayoutSystem = YES;
        _isLayoutDirty = YES;
        _isViewFrameSyncWithCalculated = YES;
        
        _async = NO;
        
        //TODO set indicator style 
        if ([type isEqualToString:@"indicator"]) {
            _styles[@"position"] = @"absolute";
            if (!_styles[@"left"] && !_styles[@"right"]) {
                _styles[@"left"] = @0.0f;
            }
            if (!_styles[@"top"] && !_styles[@"bottom"]) {
                _styles[@"top"] = @0.0f;
            }
        }
        
        // Set NavBar style
        [self _setupNavBarWithStyles:_styles attributes:_attributes];
        // Initialize the cssNode data structure based on style
        [self _initCSSNodeWithStyles:_styles];
        // Initialize View properties based on style
        [self _initViewPropertyWithStyles:_styles];
        // Handle Border properties such as corner radius, border width, and background color
        [self _handleBorders:styles isUpdating:NO];
    }
    
    return self;
}


```
The function above initializes the various layout properties of WXComponent. Some of FlexBox’s computed property methods are used here, specifically in the \_initCSSNodeWithStyles: method.
```objectivec


- (void)_initCSSNodeWithStyles:(NSDictionary *)styles
{
    _cssNode = new_css_node();
    
    _cssNode->print = cssNodePrint;
    _cssNode->get_child = cssNodeGetChild;
    _cssNode->is_dirty = cssNodeIsDirty;
    if ([self measureBlock]) {
        _cssNode->measure = cssNodeMeasure;
    }
    _cssNode->context = (__bridge void *)self;
    
    // Recalculate the number of subviews of _cssNode that need layout
    [self _recomputeCSSNodeChildren];
    // Fill each style property into the cssNode data structure
    [self _fillCSSNode:styles];
    
    // To be in conformity with Android/Web, hopefully remove this in the future.
    if ([self.ref isEqualToString:WX_SDK_ROOT_REF]) {
        if (isUndefined(_cssNode->style.dimensions[CSS_HEIGHT]) && self.weexInstance.frame.size.height) {
            _cssNode->style.dimensions[CSS_HEIGHT] = self.weexInstance.frame.size.height;
        }
        
        if (isUndefined(_cssNode->style.dimensions[CSS_WIDTH]) && self.weexInstance.frame.size.width) {
            _cssNode->style.dimensions[CSS_WIDTH] = self.weexInstance.frame.size.width;
        }
    }
}

```
In the \_fillCSSNode: method, each property value defined in the FlexBox algorithm is assigned.


#### 2. Initialize css\_node\_t


Here, before preparing to start Layout, we need to initialize rootCSSNode first.
```objectivec

- (void)_initRootCSSNode
{
    _rootCSSNode = new_css_node();
    
    // Set the rootCSSNode's coordinates and width/height based on the page weexInstance
    [self _applyRootFrame:self.weexInstance.frame toRootCSSNode:_rootCSSNode];
    
    _rootCSSNode->style.flex_wrap = CSS_NOWRAP;
    _rootCSSNode->is_dirty = rootNodeIsDirty;
    _rootCSSNode->get_child = rootNodeGetChild;
    _rootCSSNode->context = (__bridge void *)(self);
    _rootCSSNode->children_count = 1;
}

```
In the method above, the coordinates and width/height dimensions of `rootCSSNode` are initialized.

#### 3. Add UI tasks to the `uiTaskQueue` array
```objectivec

    [self _addUITask:^{
        __strong typeof(self) strongSelf = weakSelf;
        strongSelf.weexInstance.rootView.wx_component = strongSelf->_rootComponent;
        [strongSelf.weexInstance.rootView addSubview:strongSelf->_rootComponent.view];
    }];


```
WXComponentManager adds the task of attaching the current component and its corresponding View to the page Instance’s rootView into the uiTaskQueue array.

\_rootComponent.view creates the WXView corresponding to the component, which inherits from UIView. Therefore, the controls Weex creates through JS code are all native; they are all of type WXView, and are essentially UIViews. The step of creating the UIView is executed back on the main thread.

The final work of displaying it on the page is performed by the displayLink refresh method, which refreshes the UI on the main thread.
```objectivec


- (void)_handleDisplayLink
{ 
    [self _layoutAndSyncUI];
}

- (void)_layoutAndSyncUI
{
    // Flexbox layout
    [self _layout];
    if(_uiTaskQueue.count > 0){
        // Synchronously execute UI tasks
        [self _syncUITasks];
        _noTaskTickCount = 0;
    } else {
        // If there are no tasks within the current second, intelligently suspend the displaylink to save CPU time
        _noTaskTickCount ++;
        if (_noTaskTickCount > 60) {
            [self _suspendDisplayLink];
        }
    }
}

```
\_layoutAndSyncUI is the core flow for laying out and refreshing the UI. Each refresh first calls the Flexbox algorithm’s Layout to perform layout; this layout runs on the child thread “com.taobao.weex.component”. It then checks whether there are any UI tasks to execute. If there are, it switches to the main thread to refresh the UI.

There is also an intelligent suspend operation here: if no tasks are detected within one second, the displaylink is suspended to save CPU time.
```objectivec


- (void)_layout
{
    BOOL needsLayout = NO;
    NSEnumerator *enumerator = [_indexDict objectEnumerator];
    WXComponent *component;
    // Determine whether layout is needed, i.e. check the current component's _isLayoutDirty BOOL property
    while ((component = [enumerator nextObject])) {
        if ([component needsLayout]) {
            needsLayout = YES;
            break;
        }
    }

    if (!needsLayout) {
        return;
    }
    
    // Core Flexbox algorithm function
    layoutNode(_rootCSSNode, _rootCSSNode->style.dimensions[CSS_WIDTH], _rootCSSNode->style.dimensions[CSS_HEIGHT], CSS_DIRECTION_INHERIT);
 
    NSMutableSet<WXComponent *> *dirtyComponents = [NSMutableSet set];
    [_rootComponent _calculateFrameWithSuperAbsolutePosition:CGPointZero gatherDirtyComponents:dirtyComponents];
    // Calculate the current weexInstance's rootView.frame and reset rootCSSNode's Layout
    [self _calculateRootFrame];
  
    // For each component that needs layout
    for (WXComponent *dirtyComponent in dirtyComponents) {
        [self _addUITask:^{
            [dirtyComponent _layoutDidFinish];
        }];
    }
}

```
\_indexDict maintains a Map of the layout structure for the entire page. For example:
```objectivec


NSMapTable {
[7] _root -> <div ref=_root> <WXView: 0x7fc59a416140; frame = (0 0; 331.333 331.333); layer = <WXLayer: 0x608000223180>>
[12] 5 -> <image ref=5> <WXImageView: 0x7fc59a724430; baseClass = UIImageView; frame = (110.333 192.333; 110.333 110.333); clipsToBounds = YES; layer = <WXLayer: 0x60000002f780>>
[13] 3 -> <image ref=3> <WXImageView: 0x7fc59a617a00; baseClass = UIImageView; frame = (110.333 55.3333; 110.333 110.333); clipsToBounds = YES; opaque = NO; gestureRecognizers = <NSArray: 0x60000024b760>; layer = <WXLayer: 0x60000003e8c0>>
[15] 4 -> <text ref=4> <WXText: 0x7fc59a509840; text: hello Weex; frame:0.000000,441.666667,331.333333,26.666667 frame = (0 441.667; 331.333 26.6667); opaque = NO; layer = <WXLayer: 0x608000223480>>
}


```
All components are stored with their referenced `ref` value as the key. As long as you know the globally unique `ref` on this page, you can retrieve the component corresponding to that `ref`.

\_layout first checks whether there are any components that need layout. If so, it starts from `rootCSSNode` and performs layout using the Flexbox algorithm. After execution completes, it still needs to adjust the `rootView` frame once, and finally adds a UI task to `taskQueue`; this task indicates that component layout has completed.

Note that all the layout operations above are executed on the child thread “com.taobao.weex.component”.
```objectivec

- (void)_syncUITasks
{
    // Use blocks to receive all tasks originally in uiTaskQueue
    NSArray<dispatch_block_t> *blocks = _uiTaskQueue;
    // Clear uiTaskQueue
    _uiTaskQueue = [NSMutableArray array];
    // Execute all closures in uiTaskQueue sequentially on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        for(dispatch_block_t block in blocks) {
            block();
        }
    });
}


```
After layout is complete, call the synchronous UI refresh method. Note that because this operates on the UI, you must switch back to the main thread.


![](http://upload-images.jianshu.io/upload_images/1194012-6b16532cf00e3f99.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


#### (2) callAddElement

On the background thread “com.taobao.weex.bridge”, it continuously handles calls from JSFramework into Native.
```objectivec

    [_jsBridge registerCallAddElement:^NSInteger(NSString *instanceId, NSString *parentRef, NSDictionary *elementData, NSInteger index) {
        // Temporary here , in order to improve performance, will be refactored next version.
        WXSDKInstance *instance = [WXSDKManager instanceForID:instanceId];
        
        if (!instance) {
            WXLogInfo(@"instance not found, maybe already destroyed");
            return -1;
        }
        
        WXPerformBlockOnComponentThread(^{
            WXComponentManager *manager = instance.componentManager;
            if (!manager.isValid) {
                return;
            }
            [manager startComponentTasks];
            [manager addComponent:elementData toSupercomponent:parentRef atIndex:index appendingInTree:NO];
        });
        
        return 0;
    }];


```
When JSFramework calls the `callAddElement` method, the closure function in the code above is executed. Here, it receives four input arguments from JS.

For example, JSFramework might pass the following four arguments through the `callAddElement` method:
```objectivec

0,
_root, 
{
    attr =     {
        value = "Hello World";
    };
    ref = 4;
    style =     {
        color = "#000000";
        fontSize = 40;
    };
    type = text;
}, 
-1


```
Here, insertIndex is 0, parentRef is \_root, componentData is the information for the component currently being created, and instanceIdString is -1.


After that, WXComponentManager calls startComponentTasks to start the displaylink and continue preparing for layout refresh. Finally, it calls addComponent: toSupercomponent: atIndex: appendingInTree: to add the new component.

Note that these two operations in WXComponentManager require another thread switch, this time to the “com.taobao.weex.component” worker thread.
```objectivec

- (void)addComponent:(NSDictionary *)componentData toSupercomponent:(NSString *)superRef atIndex:(NSInteger)index appendingInTree:(BOOL)appendingInTree
{
    WXComponent *supercomponent = [_indexDict objectForKey:superRef];
    WXAssertComponentExist(supercomponent);
    
    [self _recursivelyAddComponent:componentData toSupercomponent:supercomponent atIndex:index appendingInTree:appendingInTree];
}

```
WXComponentManager recursively adds child components on the `com.taobao.weex.component` worker thread.
```objectivec

- (void)_recursivelyAddComponent:(NSDictionary *)componentData toSupercomponent:(WXComponent *)supercomponent atIndex:(NSInteger)index appendingInTree:(BOOL)appendingInTree
{

   // Build component from componentData
    WXComponent *component = [self _buildComponentForData:componentData];
    
    index = (index == -1 ? supercomponent->_subcomponents.count : index);
    
    [supercomponent _insertSubcomponent:component atIndex:index];
    // Use _lazyCreateView to mark lazy loading
    if(supercomponent && component && supercomponent->_lazyCreateView) {
        component->_lazyCreateView = YES;
    }
    
    // Insert a UI task
    [self _addUITask:^{
        [supercomponent insertSubview:component atIndex:index];
    }];

    NSArray *subcomponentsData = [componentData valueForKey:@"children"];
    
    BOOL appendTree = !appendingInTree && [component.attributes[@"append"] isEqualToString:@"tree"];
    // Recursive rule: if the parent view is a tree structure, child views, even if also tree structures, cannot Layout again
    for(NSDictionary *subcomponentData in subcomponentsData){
        [self _recursivelyAddComponent:subcomponentData toSupercomponent:component atIndex:-1 appendingInTree:appendTree || appendingInTree];
    }
    if (appendTree) {
        // If the current component is a tree structure, force a layout refresh to avoid accumulating too many sync tasks in syncQueue.
        [self _layoutAndSyncUI];
    }
}


```
When recursively adding child components, if the structure is a tree, you also need to force another layout pass and synchronize the UI once more. The `[self \_layoutAndSyncUI]` method called here is implemented exactly the same way as in `createRoot:`, so I won’t go into it again below.


Here, multiple subviews are added in a loop, and accordingly, the `Layout` method is called multiple times as well.


![](http://upload-images.jianshu.io/upload_images/1194012-d1f730e3bee34bdd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


#### (3) createFinish


After all views have been added, `JSFramework` calls the `callNative` method again.

It still passes in three parameters.
```objectivec


instance:0, 
tasks:(
        {
        args =         (
        );
        method = createFinish;
        module = dom;
    }
), 
callback:-1

```
Through this parameter, `callNative` will invoke the `createFinish` method of `WXDomModule`. For the specific implementation here, see `callNative` in the first step; it will not be repeated here.
```objectivec

- (void)createFinish
{
    [self performBlockOnComponentManager:^(WXComponentManager *manager) {
        [manager createFinish];
    }];
}


```
Ultimately, this will also call `WXComponentManager`'s `createFinish`. Of course, a thread switch happens here, switching to the `WXComponentManager` thread—the `com.taobao.weex.component` child thread.
```objectivec

- (void)createFinish
{
    WXAssertComponentThread();
    
    WXSDKInstance *instance  = self.weexInstance;
    [self _addUITask:^{        
        UIView *rootView = instance.rootView;
        
        WX_MONITOR_INSTANCE_PERF_END(WXPTFirstScreenRender, instance);
        WX_MONITOR_INSTANCE_PERF_END(WXPTAllRender, instance);
        WX_MONITOR_SUCCESS(WXMTJSBridge);
        WX_MONITOR_SUCCESS(WXMTNativeRender);
        
        if(instance.renderFinish){
            instance.renderFinish(rootView);
        }
    }];
}


```
The `createFinish` method of `WXComponentManager` ultimately just adds a UI task, which calls back into the `renderFinish` method on the main thread.


![](http://upload-images.jianshu.io/upload_images/1194012-2896c636f11b2202.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


At this point, Weex’s layout flow is complete.


### Finally


![](http://upload-images.jianshu.io/upload_images/1194012-caf559cea2e73cb1.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Although Auto Layout is Apple’s native automatic layout solution, performance issues can appear as soon as the UI becomes even moderately complex. More than half a year ago, Draveness’s article [“Discussing Performance Through Auto Layout’s Layout Algorithm”](http://draveness.me/layout-performance/) also somewhat “criticized” Auto Layout’s performance issues, but the article ultimately proposed using ASDK to solve the problem. This article presents another viable layout approach—FlexBox—and includes test data from extensive benchmarking, as a tribute to that classic article by Dazuo.

Today, the main layout approaches available on iOS are: native Frame-based layout, native Auto Layout, Yoga’s implementation of FlexBox, and ASDK.

Of course, beyond these four basic approaches, there are also some hybrid methods. Weex is one example: it parses CSS in JS into a JSON-like DOM, then calls Native’s FlexBox algorithm for layout. Some time ago, Meituan’s [“The Future of Layout Coding”](http://tech.meituan.com/the_future_of_layout.html) introduced Picasso’s layout approach. Its principle also involves using JSCore: JSON written in JS, or a custom DSL, is transformed by the local picassoEngine layout engine into Native layout, ultimately using the concept of anchors to achieve efficient layout.


Finally, I recommend two excellent open-source libraries on iOS that make use of FlexBox principles:


**[yoga](https://github.com/facebook/yoga)** from Facebook  
**[FlexBoxLayout](https://github.com/LPD-iOS/FlexBoxLayout)** from Ele.me


------------------------------------------------------

Weex source code analysis series:

[How Weex Runs on the iOS Client](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/iOS/Weex/Weex_how_to_work_in_iOS.md)  
[The Weex Layout Engine Powerfully Driven by the FlexBox Algorithm](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/iOS/Weex/Weex_layout_engine_powered_by_Flexbox's_algorithm.md)  
[Things to Know About Weex Event Propagation](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/iOS/Weex/Weex_events.md)     
[The Ingenious JS Framework in Weex](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/iOS/Weex/Weex_ingenuity_JS_framework.md)  
[A Pseudo Best-Practices Guide to Weex for iOS Developers](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/iOS/Weex/Weex_pseudo-best_practices_for_iOS_developers.md)  

------------------------------------------------------