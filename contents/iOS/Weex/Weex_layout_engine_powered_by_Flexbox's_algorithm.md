# 由 FlexBox 算法强力驱动的 Weex 布局引擎


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-e08b9b787f8fb07c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>






### 前言

在上篇文章里面谈了Weex在iOS客户端工作的基本流程。这篇文章将会详细的分析Weex是如何高性能的布局原生界面的，之后还会与现有的布局方法进行对比，看看Weex的布局性能究竟如何。


### 目录

- 1.Weex布局算法
- 2.Weex布局算法性能分析
- 3.Weex是如何布局原生界面的


### 一. Weex布局算法

打开Weex的源码的Layout文件夹，就会看到两个c的文件，这两个文件就是今天要谈的Weex的布局引擎。


Layout.h和Layout.c最开始是来自于React-Native里面的代码。也就是说Weex和React-Native的布局引擎都是同一套代码。

当前React-Native的代码里面已经没有这两个文件了，而是换成了Yoga。

![](http://upload-images.jianshu.io/upload_images/1194012-de7f409bd683080e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Yoga本是Facebook在React Native里引入的一种跨平台的基于CSS的布局引擎，它实现了Flexbox规范，完全遵守W3C的规范。随着该系统不断完善，Facebook对其进行重新发布，于是就成了现在的Yoga([Yoga官网](https://facebook.github.io/yoga/))。


那么Flexbox是什么呢？



![](http://upload-images.jianshu.io/upload_images/1194012-a85be95bcb08cc24.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




熟悉前端的同学一定很熟悉这个概念。2009年，W3C提出了一种新的方案——Flex布局，可以简便、完整、响应式地实现各种页面布局。目前，它已经得到了几乎所有浏览器的支持，目前的前端主要是使用Html / CSS / JS实现，其中CSS用于前端的布局。任何一个Html的容器可以通过css指定为Flex布局，一旦一个容器被指定为Flex布局，其子元素就可以按照FlexBox的语法进行布局。

关于FlexBox的基本定义，更加详细的文档说明，感兴趣的同学可以去阅读一下W3C的官方文档，那里会有很详细的说明。[官方文档链接](https://www.w3.org/TR/css-flexbox-1/)

Weex中的Layout文件是Yoga的前身，是Yoga正式发布之前的版本。底层代码使用C语言代码，所以性能也不是问题。接下来就仔细分析Layout文件是如何实现FlexBox的。



![](http://upload-images.jianshu.io/upload_images/1194012-8c812635119a366c.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

故以下源码分析都基于v0.10.0这个版本。

#### （一）FlexBox中的基本数据结构


Flexbox布局（Flexible Box)设计之初的目的是为了能更加高效的分配子视图的布局情况，包括动态的改变宽度，高度，以及排列顺序。Flexbox可以更加方便的兼容各个大小不同的屏幕，比如拉伸和压缩子视图。



在FlexBox的世界里，存在着主轴和侧轴的概念。

![](http://upload-images.jianshu.io/upload_images/1194012-b476d0e771837826.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

大多数情况，子视图都是沿着主轴（main axis），从主轴起点（main-start）到主轴终点（main-end）排列。但是这里需要注意的一点是，主轴和侧轴虽然永远是垂直的关系，但是谁是水平，谁是竖直，并没有确定，有可能会有如下的情况：


![](http://upload-images.jianshu.io/upload_images/1194012-951af0f2fc01b0a2.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


在上图这种水平是侧轴的情况下，子视图是沿着侧轴（cross axis），从侧轴起点（cross-start）到侧轴终点（cross-end）排列的。

**主轴（main axis）：**父视图的主轴，子视图主要沿着这条轴进行排列布局。

**主轴起点（main-start）和主轴终点（main-end）：**子视图在父视图里面布局的方向是从主轴起点（main-start）向主轴终点（main-start）的方向。

**主轴尺寸（main size）：**子视图在主轴方向的宽度或高度就是主轴的尺寸。子视图主要的大小属性要么是宽度，要么是高度属性，由哪一个对着主轴方向决定。

**侧轴（cross axis）：**垂直于主轴称为侧轴。它的方向主要取决于主轴方向。

**侧轴起点（cross-start）和侧轴终点（cross-end）：**子视图行的配置从容器的侧轴起点边开始，往侧轴终点边结束。

**侧轴尺寸（cross size）：**子视图的在侧轴方向的宽度或高度就是项目的侧轴长度，伸缩项目的侧轴长度属性是「width」或「height」属性，由哪一个对着侧轴方向决定。





接下来看看Layout是怎么定义FlexBox里面的元素的。

```c

typedef enum {
  CSS_DIRECTION_INHERIT = 0,
  CSS_DIRECTION_LTR,
  CSS_DIRECTION_RTL
} css_direction_t;


```

这个方向是定义的上下文的整体布局的方向，INHERIT是继承，LTR是Left To Right，从左到右布局。RTL是Right To Left，从右到左布局。下面分析如果不做特殊说明，都是LTR从左向右布局。如果是RTL就是LTR反向。



```c


typedef enum {
  CSS_FLEX_DIRECTION_COLUMN = 0,
  CSS_FLEX_DIRECTION_COLUMN_REVERSE,
  CSS_FLEX_DIRECTION_ROW,
  CSS_FLEX_DIRECTION_ROW_REVERSE
} css_flex_direction_t;



```

这里定义的是Flex的方向。




![](http://upload-images.jianshu.io/upload_images/1194012-74e4b1f77d6fa40d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图是COLUMN。布局的走向是从上往下。

![](http://upload-images.jianshu.io/upload_images/1194012-d34a0fea4404545e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图是COLUMN\_REVERSE。布局的走向是从下往上。


![](http://upload-images.jianshu.io/upload_images/1194012-8a6e7643a60e2906.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


上图是ROW。布局的走向是从左往右。

![](http://upload-images.jianshu.io/upload_images/1194012-569f2a299797e27b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


上图是ROW\_REVERSE。布局的走向是从右往左。



这里可以看出来，在LTR的上下文中，ROW\_REVERSE即等于RTL的上下文中的ROW。


```c


typedef enum {
  CSS_JUSTIFY_FLEX_START = 0,
  CSS_JUSTIFY_CENTER,
  CSS_JUSTIFY_FLEX_END,
  CSS_JUSTIFY_SPACE_BETWEEN,
  CSS_JUSTIFY_SPACE_AROUND
} css_justify_t;


```


这是定义的子视图在主轴上的排列方式。

![](http://upload-images.jianshu.io/upload_images/1194012-7dd84c06eabd1ddd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图是JUSTIFY\_FLEX\_START

![](http://upload-images.jianshu.io/upload_images/1194012-d86b61dabc5a97fd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图是JUSTIFY\_CENTER




![](http://upload-images.jianshu.io/upload_images/1194012-945bde67f5931fcf.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图是JUSTIFY\_FLEX\_END

![](http://upload-images.jianshu.io/upload_images/1194012-3823fed50bd98895.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图是JUSTIFY\_SPACE\_BETWEEN

![](http://upload-images.jianshu.io/upload_images/1194012-5c514b364e470dfc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



上图是JUSTIFY\_SPACE\_AROUND。这种方式是每个视图的左右都保持着一定的宽度。



```c

typedef enum {
  CSS_ALIGN_AUTO = 0,
  CSS_ALIGN_FLEX_START,
  CSS_ALIGN_CENTER,
  CSS_ALIGN_FLEX_END,
  CSS_ALIGN_STRETCH
} css_align_t;

```
这是定义的子视图在侧轴上的对齐方式。

在Weex这里定义了三种属于css\_align\_t类型的方式，align\_content，align\_items，align\_self。这三种类型的对齐方式略有不同。


ALIGN\_AUTO只是针对align\_self的一个默认值，但是对于align\_content，align\_items子视图的对齐方式是无效的值。


#### 1.align\_items

align\_items定义的是子视图在一行里面侧轴上排列的方式。


![](http://upload-images.jianshu.io/upload_images/1194012-e756eec5a022f74a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


上图是ALIGN\_FLEX\_START


![](http://upload-images.jianshu.io/upload_images/1194012-5e200b8d742b01a2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


上图是ALIGN\_CENTER



![](http://upload-images.jianshu.io/upload_images/1194012-ceab624ccd23e978.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



上图是ALIGN\_FLEX\_END

![](http://upload-images.jianshu.io/upload_images/1194012-7bb4781738e20528.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


上图是ALIGN\_STRETCH


align\_items在W3C的定义里面其实还有一个种baseline的对齐方式，这里在定义里面并没有。



![](http://upload-images.jianshu.io/upload_images/1194012-10e077f6a05f4fe8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

注意，上面这种baseline的对齐方式在Weex的定义里面并没有！

#### 2. align_content

align_content定义的是子视图行与行之间在侧轴上排列的方式。

![](http://upload-images.jianshu.io/upload_images/1194012-c4e6c4930823f326.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图是ALIGN\_FLEX\_START

![](http://upload-images.jianshu.io/upload_images/1194012-3425b3876c3d665b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


上图是ALIGN\_CENTER


![](http://upload-images.jianshu.io/upload_images/1194012-c5358bd9b76e9aac.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图是ALIGN\_FLEX\_END



![](http://upload-images.jianshu.io/upload_images/1194012-6a98ea3472c5b20c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图是ALIGN_STRETCH



在FlexBox的W3C的定义里面其实还有两种方式在Weex没有定义。

![](http://upload-images.jianshu.io/upload_images/1194012-b5b1500aa720593a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


上图的这种对齐方式是对应的justify里面的JUSTIFY\_SPACE\_AROUND，align-content里面的space-around这种对齐方式在Weex是没有的。

![](http://upload-images.jianshu.io/upload_images/1194012-77e9ab8a8268646f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图的这种对齐方式是对应的justify里面的JUSTIFY\_SPACE\_BETWEEN，align-content里面的space-between这种对齐方式在Weex是没有的。


#### 3.align_self

最后这一种对齐方式是可以在align\_items的基础上再分别自定义每个子视图的对齐方式。如果是auto，是与align\_items方式相同。

![](http://upload-images.jianshu.io/upload_images/1194012-964d7fb4451fb0b0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


```c

typedef enum {
  CSS_POSITION_RELATIVE = 0,
  CSS_POSITION_ABSOLUTE
} css_position_type_t;


```

这个是定义坐标地址的类型，有相对坐标和绝对坐标两种。


```c

typedef enum {
  CSS_NOWRAP = 0,
  CSS_WRAP
} css_wrap_type_t;


```

在Weex里面wrap只有两种类型。

![](http://upload-images.jianshu.io/upload_images/1194012-d982430a883bd70e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图是NOWRAP。所有的子视图都会排列在一行之中。


![](http://upload-images.jianshu.io/upload_images/1194012-40c4c59a6237ebbb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


上图是WRAP。所有的子视图会从左到右，从上到下排列。


在W3C的标准里面还有一种wrap\_reverse的排列方式。

![](http://upload-images.jianshu.io/upload_images/1194012-40d7272e17d5b429.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这种排列方式，是从左到右，从下到上进行排列，目前在Weex里面没有定义。


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

这里定义的是坐标的描述。Left和Top因为会出现在position[2] 和 position[4]中，所以它们两个排列在Right和Bottom前面。

```c


typedef enum {
  CSS_MEASURE_MODE_UNDEFINED = 0,
  CSS_MEASURE_MODE_EXACTLY,
  CSS_MEASURE_MODE_AT_MOST
} css_measure_mode_t;

```

这里定义的是计算的方式，一种是精确计算，另外一种是估算近视值。


```c

typedef enum {
  CSS_WIDTH = 0,
  CSS_HEIGHT
} css_dimension_t;

```

这里定义的是子视图的尺寸，宽和高。


```c

typedef struct {
  float position[4];
  float dimensions[2];
  css_direction_t direction;

  // 缓存一些信息防止每次Layout过程都要重复计算
  bool should_update;
  float last_requested_dimensions[2];
  float last_parent_max_width;
  float last_parent_max_height;
  float last_dimensions[2];
  float last_position[2];
  css_direction_t last_direction;
} css_layout_t;

```

这里定义了一个css\_layout\_t结构体。结构体里面position和dimensions数组里面分别存储的是四周的位置和宽高的尺寸。direction里面存储的就是LTR还是RTL的方向。

至于下面那些变量信息都是缓存，用来防止没有改变的Lauout还会重复计算的问题。



```c

typedef struct {
  float dimensions[2];
} css_dim_t;

```

css\_dim\_t结构体里面装的就是子视图的尺寸信息，宽和高。



```c

typedef struct {
  // 整个页面CSS的方向，LTR、RTL
  css_direction_t direction;
  // Flex 的方向
  css_flex_direction_t flex_direction;
  // 子视图在主轴上的排列对齐方式
  css_justify_t justify_content;
  // 子视图在侧轴上行与行之间的对齐方式
  css_align_t align_content;
  // 子视图在侧轴上的对齐方式
  css_align_t align_items;
  // 子视图自己本身的对齐方式
  css_align_t align_self;
  // 子视图的坐标系类型(相对坐标系，绝对坐标系)
  css_position_type_t position_type;
  // wrap类型
  css_wrap_type_t flex_wrap;
  float flex;
  // 上，下，左，右，start，end
  float margin[6];
  // 上，下，左，右
  float position[4];
  // 上，下，左，右，start，end
  float padding[6];
  // 上，下，左，右，start，end
  float border[6];
  // 宽，高
  float dimensions[2];
  // 最小的宽和高
  float minDimensions[2];
  // 最大的宽和高
  float maxDimensions[2];
} css_style_t;


```


css\_style\_t记录了整个style的所有信息。每个变量的意义见上面注释。


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

css\_node定义的是FlexBox的一个节点的数据结构。它包含了之前的css\_style\_t和css\_layout\_t。由于结构体里面无法定义成员函数，所以下面包含4个函数指针。

![](http://upload-images.jianshu.io/upload_images/1194012-9192b10f6607271c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


```c

css_node_t *new_css_node(void);
void init_css_node(css_node_t *node);
void free_css_node(css_node_t *node);

```

上面3个函数是关于css\_node的生命周期相关的函数。

```c

// 新建节点
css_node_t *new_css_node() {
  css_node_t *node = (css_node_t *)calloc(1, sizeof(*node));
  init_css_node(node);
  return node;
}

// 释放节点
void free_css_node(css_node_t *node) {
  free(node);
}


```

新建节点的时候就是调用的init\_css\_node方法。

```c


void init_css_node(css_node_t *node) {
  node->style.align_items = CSS_ALIGN_STRETCH;
  node->style.align_content = CSS_ALIGN_FLEX_START;

  node->style.direction = CSS_DIRECTION_INHERIT;
  node->style.flex_direction = CSS_FLEX_DIRECTION_COLUMN;

  // 注意下面这些数组里面的值初始化为undefined，而不是0
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

  // 以下这些用来对比是否发生变化的缓存变量，初始值都为 -1。
  node->layout.last_requested_dimensions[CSS_WIDTH] = -1;
  node->layout.last_requested_dimensions[CSS_HEIGHT] = -1;
  node->layout.last_parent_max_width = -1;
  node->layout.last_parent_max_height = -1;
  node->layout.last_direction = (css_direction_t)-1;
  node->layout.should_update = true;
}


```


css\_node的初始化的align\_items是ALIGN\_STRETCH，align\_content是ALIGN\_FLEX\_START，direction是继承自父类，flex\_direction是按照列排列的。

接着下面数组里面存的都是UNDEFINED，而不是0，因为0会和结构体里面的0冲突。

最后缓存的变量初始化都为-1。


接下来定义了4个全局的数组，这4个数组非常有用，它会决定接下来layout的方向和属性。4个数组和轴的方向是相互关联的。

```c

static css_position_t leading[4] = {
  /* CSS_FLEX_DIRECTION_COLUMN = */ CSS_TOP,
  /* CSS_FLEX_DIRECTION_COLUMN_REVERSE = */ CSS_BOTTOM,
  /* CSS_FLEX_DIRECTION_ROW = */ CSS_LEFT,
  /* CSS_FLEX_DIRECTION_ROW_REVERSE = */ CSS_RIGHT
};

```

如果主轴在COLUMN垂直方向，那么子视图的leading就是CSS\_TOP，方向如果是COLUMN\_REVERSE，那么子视图的leading就是CSS\_BOTTOM；如果主轴在ROW水平方向，那么子视图的leading就是CSS\_LEFT，方向如果是ROW\_REVERSE，那么子视图的leading就是CSS\_RIGHT。


```c

static css_position_t trailing[4] = {
  /* CSS_FLEX_DIRECTION_COLUMN = */ CSS_BOTTOM,
  /* CSS_FLEX_DIRECTION_COLUMN_REVERSE = */ CSS_TOP,
  /* CSS_FLEX_DIRECTION_ROW = */ CSS_RIGHT,
  /* CSS_FLEX_DIRECTION_ROW_REVERSE = */ CSS_LEFT
};

```

如果主轴在COLUMN垂直方向，那么子视图的trailing就是CSS\_BOTTOM，方向如果是COLUMN\_REVERSE，那么子视图的trailing就是CSS\_TOP；如果主轴在ROW水平方向，那么子视图的trailing就是CSS\_RIGHT，方向如果是ROW\_REVERSE，那么子视图的trailing就是CSS\_LEFT。



```c

static css_position_t pos[4] = {
  /* CSS_FLEX_DIRECTION_COLUMN = */ CSS_TOP,
  /* CSS_FLEX_DIRECTION_COLUMN_REVERSE = */ CSS_BOTTOM,
  /* CSS_FLEX_DIRECTION_ROW = */ CSS_LEFT,
  /* CSS_FLEX_DIRECTION_ROW_REVERSE = */ CSS_RIGHT
};

```

如果主轴在COLUMN垂直方向，那么子视图的position就是以CSS\_TOP开始的，方向如果是COLUMN\_REVERSE，那么子视图的position就是以CSS\_BOTTOM开始的；如果主轴在ROW水平方向，那么子视图的position就是以CSS\_LEFT开始的，方向如果是ROW\_REVERSE，那么子视图的position就是以CSS\_RIGHT开始的。


```c

static css_dimension_t dim[4] = {
  /* CSS_FLEX_DIRECTION_COLUMN = */ CSS_HEIGHT,
  /* CSS_FLEX_DIRECTION_COLUMN_REVERSE = */ CSS_HEIGHT,
  /* CSS_FLEX_DIRECTION_ROW = */ CSS_WIDTH,
  /* CSS_FLEX_DIRECTION_ROW_REVERSE = */ CSS_WIDTH
};


```

如果主轴在COLUMN垂直方向，那么子视图在这个方向上的尺寸就是CSS\_HEIGHT，方向如果是COLUMN\_REVERSE，那么子视图在这个方向上的尺寸也是CSS\_HEIGHT；如果主轴在ROW水平方向，那么子视图在这个方向上的尺寸就是CSS\_WIDTH，方向如果是ROW\_REVERSE，那么子视图在这个方向上的尺寸是CSS\_WIDTH。



#### （二）FlexBox中的布局算法

 
Weex 盒模型基于 [CSS 盒模型](https://www.w3.org/TR/css3-box/)，每个 Weex 元素都可视作一个盒子。我们一般在讨论设计或布局时，会提到「盒模型」这个概念。

盒模型描述了一个元素所占用的空间。每一个盒子有四条边界：外边距边界 margin edge, 边框边界 border edge, 内边距边界 padding edge 与内容边界 content edge。这四层边界，形成一层层的盒子包裹起来，这就是盒模型大体上的含义。


![](http://upload-images.jianshu.io/upload_images/1194012-2968e2f04c41c140.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

盒子模型如上，这个图是基于LTR，并且主轴在水平方向的。

所以主轴在不同方向可能就会有不同的情况。


>注意：
Weex 盒模型的 box-sizing 默认为 border-box，即盒子的宽高包含内容content、内边距padding和边框的宽度border，不包含外边距的宽度margin。


```c

// 判断轴是否是水平方向
static bool isRowDirection(css_flex_direction_t flex_direction) {
  return flex_direction == CSS_FLEX_DIRECTION_ROW ||
         flex_direction == CSS_FLEX_DIRECTION_ROW_REVERSE;
}

// 判断轴是否是垂直方向
static bool isColumnDirection(css_flex_direction_t flex_direction) {
  return flex_direction == CSS_FLEX_DIRECTION_COLUMN ||
         flex_direction == CSS_FLEX_DIRECTION_COLUMN_REVERSE;
}

```

判断轴的方向的方向就是上面这两个。

然后接着还要计算4个方向上的padding、border、margin。这里就举一个方向的例子。


首先如何计算Margin的呢？

```c

static float getLeadingMargin(css_node_t *node, css_flex_direction_t axis) {
  if (isRowDirection(axis) && !isUndefined(node->style.margin[CSS_START])) {
    return node->style.margin[CSS_START];
  }
  return node->style.margin[leading[axis]];
}


```

判断轴的方向是不是水平方向，如果是水平方向就直接取node的margin里面的CSS\_START即是LeadingMargin，如果是竖直方向，就取出在竖直轴上面的leading方向的margin的值。

如果取TrailingMargin那么就取margin[CSS\_END]。

```c

static float getTrailingMargin(css_node_t *node, css_flex_direction_t axis) {
  if (isRowDirection(axis) && !isUndefined(node->style.margin[CSS_END])) {
    return node->style.margin[CSS_END];
  }

  return node->style.margin[trailing[axis]];
}


```


以下padding、border、margin三个值的数组存储有6个值，如果是水平方向，那么CSS\_START存储的都是Leading，CSS\_END存储的都是Trailing。下面没有特殊说明，都按照这个规则来。

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

取Padding的思路也和取Margin的思路一样，水平方向就是取出数组里面的padding[CSS\_START]，如果是竖直方向，就对应得取出padding[leading[axis]]的值即可。



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

最后这是Border的计算方法，和上述Padding，Margin一模一样，这里就不再赘述了。

四周边距的计算方法都实现了，接下来就是如何layout了。

```c

// 计算布局的方法
void layoutNode(css_node_t *node, float maxWidth, float maxHeight, css_direction_t parentDirection);

// 在调用layoutNode之前，可以重置node节点的layout
void resetNodeLayout(css_node_t *node);

```

重置node节点的方法就是把节点的坐标重置为0，然后把宽和高都重置为UNDEFINED。

```c

void resetNodeLayout(css_node_t *node) {
  node->layout.dimensions[CSS_WIDTH] = CSS_UNDEFINED;
  node->layout.dimensions[CSS_HEIGHT] = CSS_UNDEFINED;
  node->layout.position[CSS_LEFT] = 0;
  node->layout.position[CSS_TOP] = 0;
}


```

最后，布局方法就是如下：

```c

void layoutNode(css_node_t *node, float parentMaxWidth, float parentMaxHeight, css_direction_t parentDirection) {
  css_layout_t *layout = &node->layout;
  css_direction_t direction = node->style.direction;
  layout->should_update = true;

  // 对比当前环境是否“干净”，以及比较待布局的node节点和上次节点是否完全一致。
  bool skipLayout =
    !node->is_dirty(node->context) &&
    eq(layout->last_requested_dimensions[CSS_WIDTH], layout->dimensions[CSS_WIDTH]) &&
    eq(layout->last_requested_dimensions[CSS_HEIGHT], layout->dimensions[CSS_HEIGHT]) &&
    eq(layout->last_parent_max_width, parentMaxWidth) &&
    eq(layout->last_parent_max_height, parentMaxHeight) &&
    eq(layout->last_direction, direction);

  if (skipLayout) {
    // 把缓存的值直接赋值给当前的layout
    layout->dimensions[CSS_WIDTH] = layout->last_dimensions[CSS_WIDTH];
    layout->dimensions[CSS_HEIGHT] = layout->last_dimensions[CSS_HEIGHT];
    layout->position[CSS_TOP] = layout->last_position[CSS_TOP];
    layout->position[CSS_LEFT] = layout->last_position[CSS_LEFT];
  } else {
    // 缓存node节点
    layout->last_requested_dimensions[CSS_WIDTH] = layout->dimensions[CSS_WIDTH];
    layout->last_requested_dimensions[CSS_HEIGHT] = layout->dimensions[CSS_HEIGHT];
    layout->last_parent_max_width = parentMaxWidth;
    layout->last_parent_max_height = parentMaxHeight;
    layout->last_direction = direction;

    // 初始化所有子视图node的尺寸和位置
    for (int i = 0, childCount = node->children_count; i < childCount; i++) {
      resetNodeLayout(node->get_child(node->context, i));
    }

    // 布局视图的核心实现
    layoutNodeImpl(node, parentMaxWidth, parentMaxHeight, parentDirection);

    // 布局完成，把此次的布局缓存起来，防止下次重复的布局重复计算
    layout->last_dimensions[CSS_WIDTH] = layout->dimensions[CSS_WIDTH];
    layout->last_dimensions[CSS_HEIGHT] = layout->dimensions[CSS_HEIGHT];
    layout->last_position[CSS_TOP] = layout->position[CSS_TOP];
    layout->last_position[CSS_LEFT] = layout->position[CSS_LEFT];
  }
}

```

每步都注释了，见上述代码注释，在调用布局的核心实现layoutNodeImpl之前，会循环调用resetNodeLayout，初始化所有子视图。



所有的核心实现就在layoutNodeImpl这个方法里面了。Weex里面的这个方法实现有700多行，在Yoga的实现中，布局算法有1000多行。




```c

static void layoutNodeImpl(css_node_t *node, float parentMaxWidth, float parentMaxHeight, css_direction_t parentDirection) {

}


```

这里分析一下这个算法的主要流程。在Weex的这个实现中，有7个循环，假设依次分别标上A，B，C，D，E，F，G。


先来看循环A

```c


    float mainContentDim = 0;
    // 存在3类子视图，支持flex的子视图，不支持flex的子视图，绝对布局的子视图，我们需要知道哪些子视图是在等待分配空间。
    int flexibleChildrenCount = 0;
    float totalFlexible = 0;
    int nonFlexibleChildrenCount = 0;

    // 利用一层循环在主轴上简单的堆叠子视图，在循环C中，会忽略这些已经在循环A中已经排列好的子视图
    bool isSimpleStackMain =
        (isMainDimDefined && justifyContent == CSS_JUSTIFY_FLEX_START) ||
        (!isMainDimDefined && justifyContent != CSS_JUSTIFY_CENTER);
    int firstComplexMain = (isSimpleStackMain ? childCount : startLine);

    // 利用一层循环在侧轴上简单的堆叠子视图，在循环D中，会忽略这些已经在循环A中已经排列好的子视图
    bool isSimpleStackCross = true;
    int firstComplexCross = childCount;

    css_node_t* firstFlexChild = NULL;
    css_node_t* currentFlexChild = NULL;

    float mainDim = leadingPaddingAndBorderMain;
    float crossDim = 0;

    float maxWidth = CSS_UNDEFINED;
    float maxHeight = CSS_UNDEFINED;

    // 循环A从这里开始
    for (i = startLine; i < childCount; ++i) {
      child = node->get_child(node->context, i);
      child->line_index = linesCount;

      child->next_absolute_child = NULL;
      child->next_flex_child = NULL;

      css_align_t alignItem = getAlignItem(node, child);

      // 在递归layout之前，先预填充侧轴上可以被拉伸的子视图
      if (alignItem == CSS_ALIGN_STRETCH &&
          child->style.position_type == CSS_POSITION_RELATIVE &&
          isCrossDimDefined &&
          !isStyleDimDefined(child, crossAxis)) {
          
        // 这里要进行一个比较，比较子视图在侧轴上的尺寸 和 侧轴上减去两边的Margin、padding、Border剩下的可拉伸的空间 进行比较，因为拉伸是不会压缩原始的大小的。
        child->layout.dimensions[dim[crossAxis]] = fmaxf(
          boundAxis(child, crossAxis, node->layout.dimensions[dim[crossAxis]] -
            paddingAndBorderAxisCross - getMarginAxis(child, crossAxis)),
          getPaddingAndBorderAxis(child, crossAxis)
        );
      } else if (child->style.position_type == CSS_POSITION_ABSOLUTE) {
        // 这里会储存一个绝对布局子视图的链表。这样我们在后面布局的时候可以快速的跳过它们。
        if (firstAbsoluteChild == NULL) {
          firstAbsoluteChild = child;
        }
        if (currentAbsoluteChild != NULL) {
          currentAbsoluteChild->next_absolute_child = child;
        }
        currentAbsoluteChild = child;

        // 预填充子视图，这里需要用到视图在轴上面的绝对坐标，如果是水平轴，需要用到左右的偏移量，如果是竖直轴，需要用到上下的偏移量。
        for (ii = 0; ii < 2; ii++) {
          axis = (ii != 0) ? CSS_FLEX_DIRECTION_ROW : CSS_FLEX_DIRECTION_COLUMN;
          if (isLayoutDimDefined(node, axis) &&
              !isStyleDimDefined(child, axis) &&
              isPosDefined(child, leading[axis]) &&
              isPosDefined(child, trailing[axis])) {
            child->layout.dimensions[dim[axis]] = fmaxf(
              // 这里是绝对布局，还需要减去leading和trailing
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
循环A的具体实现如上，注释见代码。
循环A主要是实现的是layout布局中不可以flex的子视图的布局，mainContentDim变量是用来记录所有的尺寸以及所有不能flex的子视图的margin的总和。它被用来设置node节点的尺寸，和计算剩余空间以便供可flex子视图进行拉伸适配。

每个node节点的next\_absolute\_child维护了一个链表，这里存储的依次是绝对布局视图的链表。


接着需要再统计可以被拉伸的子视图。

```c

      float nextContentDim = 0;

      // 统计可以拉伸flex的子视图
      if (isMainDimDefined && isFlex(child)) {
        flexibleChildrenCount++;
        totalFlexible += child->style.flex;

        // 存储一个链表维护可以flex的子视图
        if (firstFlexChild == NULL) {
          firstFlexChild = child;
        }
        if (currentFlexChild != NULL) {
          currentFlexChild->next_flex_child = child;
        }
        currentFlexChild = child;

        // 这时我们虽然不知道确切的尺寸信息，但是已经知道了padding , border , margin，我们可以利用这些信息来给子视图确定一个最小的size，计算剩余可用的空间。
        // 下一个content的距离等于当前子视图Leading和Trailing的padding , border , margin6个尺寸之和。
        nextContentDim = getPaddingAndBorderAxis(child, mainAxis) +
          getMarginAxis(child, mainAxis);

      } else {
        maxWidth = CSS_UNDEFINED;
        maxHeight = CSS_UNDEFINED;

       // 计算出最大宽度和最大高度
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

        // 递归调用layout函数，进行不能拉伸的子视图的布局。
        if (alreadyComputedNextLayout == 0) {
          layoutNode(child, maxWidth, maxHeight, direction);
        }

        // 由于绝对布局的子视图的位置和layout无关，所以我们不能用它们来计算mainContentDim
        if (child->style.position_type == CSS_POSITION_RELATIVE) {
          nonFlexibleChildrenCount++;
          nextContentDim = getDimWithMargin(child, mainAxis);
        }
      }


```


上述代码就确定出了不可拉伸的子视图的布局。

每个node节点的next\_flex\_child维护了一个链表，这里存储的依次是可以flex拉伸视图的链表。

```c

      // 将要加入的元素可能会被挤到下一行
      if (isNodeFlexWrap &&
          isMainDimDefined &&
          mainContentDim + nextContentDim > definedMainDim &&
          // 如果这里只有一个元素，它可能就需要单独占一行
          i != startLine) {
        nonFlexibleChildrenCount--;
        alreadyComputedNextLayout = 1;
        break;
      }

      // 停止在主轴上堆叠子视图，剩余的子视图都在循环C里面布局
      if (isSimpleStackMain &&
          (child->style.position_type != CSS_POSITION_RELATIVE || isFlex(child))) {
        isSimpleStackMain = false;
        firstComplexMain = i;
      }

      // 停止在侧轴上堆叠子视图，剩余的子视图都在循环D里面布局
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
        // 设置子视图主轴上的TrailingPosition
          setTrailingPosition(node, child, mainAxis);
        }
        // 可以算出了主轴上的尺寸了
        mainDim += getDimWithMargin(child, mainAxis);
        // 可以算出侧轴上的尺寸了
        crossDim = fmaxf(crossDim, boundAxis(child, crossAxis, getDimWithMargin(child, crossAxis)));
      }

      if (isSimpleStackCross) {
        child->layout.position[pos[crossAxis]] += linesCrossDim + leadingPaddingAndBorderCross;
        if (isCrossDimDefined) {
        // 设置子视图侧轴上的TrailingPosition
          setTrailingPosition(node, child, crossAxis);
        }
      }

      alreadyComputedNextLayout = 0;
      mainContentDim += nextContentDim;
      endLine = i + 1;
    }
// 循环A 至此结束

```

循环A结束以后，会计算出endLine，计算出主轴上的尺寸，侧轴上的尺寸。不可拉伸的子视图的布局也会被确定。


接下来进入循环B的阶段。

循环B主要分为2个部分，第一个部分是用来布局可拉伸的子视图。


```c

    // 为了在主轴上布局，需要控制两个space，一个是第一个子视图和最左边的距离，另一个是两个子视图之间的距离
    float leadingMainDim = 0;
    float betweenMainDim = 0;

    // 记录剩余的可用空间
    float remainingMainDim = 0;
    if (isMainDimDefined) {
      remainingMainDim = definedMainDim - mainContentDim;
    } else {
      remainingMainDim = fmaxf(mainContentDim, 0) - mainContentDim;
    }

    // 如果当前还有可拉伸的子视图，它们就要填充剩余的可用空间
    if (flexibleChildrenCount != 0) {
      float flexibleMainDim = remainingMainDim / totalFlexible;
      float baseMainDim;
      float boundMainDim;

      // 如果剩余的空间不能提供给可拉伸的子视图，不能满足它们的最大或者最小的bounds，那么这些子视图也要排除到计算拉伸的过程之外
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

      // 不可以拉伸的子视图可以在父视图内部overflow，在这种情况下，假设没有可用的拉伸space
      if (flexibleMainDim < 0) {
        flexibleMainDim = 0;
      }

      currentFlexChild = firstFlexChild;
      while (currentFlexChild != NULL) {
        // 在这层循环里面我们已经可以确认子视图的最终大小了
        currentFlexChild->layout.dimensions[dim[mainAxis]] = boundAxis(currentFlexChild, mainAxis,
          flexibleMainDim * currentFlexChild->style.flex +
              getPaddingAndBorderAxis(currentFlexChild, mainAxis)
        );

        // 计算水平方向轴上子视图的最大宽度
        maxWidth = CSS_UNDEFINED;
        if (isLayoutDimDefined(node, resolvedRowAxis)) {
          maxWidth = node->layout.dimensions[dim[resolvedRowAxis]] -
            paddingAndBorderAxisResolvedRow;
        } else if (!isMainRowDirection) {
          maxWidth = parentMaxWidth -
            getMarginAxis(node, resolvedRowAxis) -
            paddingAndBorderAxisResolvedRow;
        }
        
        // 计算垂直方向轴上子视图的最大高度
        maxHeight = CSS_UNDEFINED;
        if (isLayoutDimDefined(node, CSS_FLEX_DIRECTION_COLUMN)) {
          maxHeight = node->layout.dimensions[dim[CSS_FLEX_DIRECTION_COLUMN]] -
            paddingAndBorderAxisColumn;
        } else if (isMainRowDirection) {
          maxHeight = parentMaxHeight -
            getMarginAxis(node, CSS_FLEX_DIRECTION_COLUMN) -
            paddingAndBorderAxisColumn;
        }

        // 再次递归完成可拉伸的子视图的布局
        layoutNode(currentFlexChild, maxWidth, maxHeight, direction);

        child = currentFlexChild;
        currentFlexChild = currentFlexChild->next_flex_child;
        child->next_flex_child = NULL;
      }
    }


```

在上述2个while结束以后，所有可以被拉伸的子视图就都布局完成了。


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
        // 这里是实现SPACE_AROUND的代码
        betweenMainDim = remainingMainDim /
          (flexibleChildrenCount + nonFlexibleChildrenCount);
        leadingMainDim = betweenMainDim / 2;
      }
    }


```

可flex拉伸的视图布局完成以后，这里是收尾工作，根据justifyContent，更改betweenMainDim和leadingMainDim的大小。


接着再是循环C。

```c

    // 在这个循环中，所有子视图的宽和高都将被确定下来。在确定各个子视图的坐标的时候，同时也将确定父视图的宽和高。
    mainDim += leadingMainDim;

    // 按照Line，一层层的循环
    for (i = firstComplexMain; i < endLine; ++i) {
      child = node->get_child(node->context, i);

      if (child->style.position_type == CSS_POSITION_ABSOLUTE &&
          isPosDefined(child, leading[mainAxis])) {
        // 到这里，绝对坐标的子视图的坐标已经确定下来了，左边距和上边距已经被定下来了。这时子视图的绝对坐标可以确定了。
        child->layout.position[pos[mainAxis]] = getPosition(child, leading[mainAxis]) +
          getLeadingBorder(node, mainAxis) +
          getLeadingMargin(child, mainAxis);
      } else {
        // 如果子视图不是绝对坐标，坐标是相对的，或者还没有确定下来左边距和上边距，那么就根据当前位置确定坐标
        child->layout.position[pos[mainAxis]] += mainDim;

        // 确定trailing的坐标位置
        if (isMainDimDefined) {
          setTrailingPosition(node, child, mainAxis);
        }

        // 接下来开始处理相对坐标的子视图，具有绝对坐标的子视图不会参与下述的布局计算中
        if (child->style.position_type == CSS_POSITION_RELATIVE) {
          // 主轴上的宽度是由所有的子视图的宽度累加而成
          mainDim += betweenMainDim + getDimWithMargin(child, mainAxis);
          // 侧轴的高度是由最高的子视图决定的
          crossDim = fmaxf(crossDim, boundAxis(child, crossAxis, getDimWithMargin(child, crossAxis)));
        }
      }
    }

    float containerCrossAxis = node->layout.dimensions[dim[crossAxis]];
    if (!isCrossDimDefined) {
      containerCrossAxis = fmaxf(
        // 计算父视图的时候需要加上，上下的padding和Border。
        boundAxis(node, crossAxis, crossDim + paddingAndBorderAxisCross),
        paddingAndBorderAxisCross
      );
    }



```

在循环C中，会在主轴上计算出所有子视图的坐标，包括各个子视图的宽和高。


接下来就到循环D的流程了。


```c


     for (i = firstComplexCross; i < endLine; ++i) {
      child = node->get_child(node->context, i);

      if (child->style.position_type == CSS_POSITION_ABSOLUTE &&
          isPosDefined(child, leading[crossAxis])) {
        // 到这里，绝对坐标的子视图的坐标已经确定下来了，上下左右至少有一边的坐标已经被定下来了。这时子视图的绝对坐标可以确定了。
        child->layout.position[pos[crossAxis]] = getPosition(child, leading[crossAxis]) +
          getLeadingBorder(node, crossAxis) +
          getLeadingMargin(child, crossAxis);

      } else {
        float leadingCrossDim = leadingPaddingAndBorderCross;

        // 在侧轴上，针对相对坐标的子视图，我们利用父视图的alignItems或者子视图的alignSelf来确定具体的坐标位置
        if (child->style.position_type == CSS_POSITION_RELATIVE) {
          // 获取子视图的AlignItem属性值
          css_align_t alignItem = getAlignItem(node, child);
          if (alignItem == CSS_ALIGN_STRETCH) {
            // 如果在侧轴上子视图还没有确定尺寸，那么才会相应STRETCH拉伸。
            if (!isStyleDimDefined(child, crossAxis)) {
              float dimCrossAxis = child->layout.dimensions[dim[crossAxis]];
              child->layout.dimensions[dim[crossAxis]] = fmaxf(
                boundAxis(child, crossAxis, containerCrossAxis -
                  paddingAndBorderAxisCross - getMarginAxis(child, crossAxis)),
                getPaddingAndBorderAxis(child, crossAxis)
              );

              // 如果视图的大小变化了，连带该视图的子视图还需要再次layout
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

                // 递归子视图的布局
                layoutNode(child, maxWidth, maxHeight, direction);
              }
            }
          } else if (alignItem != CSS_ALIGN_FLEX_START) {
            // 在侧轴上剩余的空间等于父视图在侧轴上的高度减去子视图的在侧轴上padding、Border、Margin以及高度
            float remainingCrossDim = containerCrossAxis -
              paddingAndBorderAxisCross - getDimWithMargin(child, crossAxis);

            if (alignItem == CSS_ALIGN_CENTER) {
              leadingCrossDim += remainingCrossDim / 2;
            } else { // CSS_ALIGN_FLEX_END
              leadingCrossDim += remainingCrossDim;
            }
          }
        }

        // 确定子视图在侧轴上的坐标位置
        child->layout.position[pos[crossAxis]] += linesCrossDim + leadingCrossDim;

        // 确定trailing的坐标
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

上述的循环D中主要是在侧轴上计算子视图的坐标。如果视图发生了大小变化，还需要递归子视图，重新布局一次。


再接着是循环E

```c


  if (linesCount > 1 && isCrossDimDefined) {
    float nodeCrossAxisInnerSize = node->layout.dimensions[dim[crossAxis]] -
        paddingAndBorderAxisCross;
    float remainingAlignContentDim = nodeCrossAxisInnerSize - linesCrossDim;

    float crossDimLead = 0;
    float currentLead = leadingPaddingAndBorderCross;

    // 布局alignContent
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

      // 计算每一行的行高，行高根据lineHeight和子视图在侧轴上的高度加上下的Margin之和比较，取最大值
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

        // 布局AlignItem
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

执行循环E有一个前提，就是，行数至少要超过一行，并且侧轴上有高度定义。满足了这个前提条件以后才会开始下面的align规则。

在循环E中会处理侧轴上的align拉伸规则。这里会布局alignContent和AlignItem。

这块代码实现的算法原理请参见[http://www.w3.org/TR/2012/CR-css3-flexbox-20120918/#layout-algorithm](http://www.w3.org/TR/2012/CR-css3-flexbox-20120918/#layout-algorithm) section 9.4部分。


至此可能还存在一些没有指定宽和高的视图，接下来将会做最后一次的处理。

```c


  // 如果某个视图没有被指定宽或者高，并且也没有被父视图设置宽和高，那么在这里通过子视图来设置宽和高
  if (!isMainDimDefined) {
    // 视图的宽度等于内部子视图的宽度加上Trailing的Padding、Border的宽度和主轴上Leading的Padding、Border+ Trailing的Padding、Border，两者取最大值。
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
      // 视图的高度等于内部子视图的高度加上上下的Padding、Border的宽度和侧轴上Padding、Border，两者取最大值。
      boundAxis(node, crossAxis, linesCrossDim + paddingAndBorderAxisCross),
      paddingAndBorderAxisCross
    );

    if (crossAxis == CSS_FLEX_DIRECTION_ROW_REVERSE ||
        crossAxis == CSS_FLEX_DIRECTION_COLUMN_REVERSE) {
      needsCrossTrailingPos = true;
    }
  }



```

这些没有确定宽和高的子视图的宽和高会根据父视图来决定。方法见上述代码。

再就是循环F了。


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

这一步是设置当前node节点的Trailing坐标，如果有必要的话。如果不需要，这一步会直接跳过。


最后一步就是循环G了。


```c

  currentAbsoluteChild = firstAbsoluteChild;
  while (currentAbsoluteChild != NULL) {
    for (ii = 0; ii < 2; ii++) {
      axis = (ii != 0) ? CSS_FLEX_DIRECTION_ROW : CSS_FLEX_DIRECTION_COLUMN;

      if (isLayoutDimDefined(node, axis) &&
          !isStyleDimDefined(currentAbsoluteChild, axis) &&
          isPosDefined(currentAbsoluteChild, leading[axis]) &&
          isPosDefined(currentAbsoluteChild, trailing[axis])) {
        // 绝对坐标的子视图在主轴上的宽度，在侧轴上的高度都不能比Padding、Border的总和小。
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
        // 当前子视图的坐标等于当前视图的宽度减去子视图的宽度再减去trailing
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

最后这一步循环G是用来给绝对坐标的子视图计算宽度和高度。

执行完上述7个循环以后，所有的子视图就都layout完成了。

总结一下上述的流程，如下图：




![](http://upload-images.jianshu.io/upload_images/1194012-fc141fa8e3dc0433.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)















### 二. Weex布局算法性能分析


#### 1.算法实现分析

上一章节看了Weex的layout算法实现。这里就分析一下在这个实现下，布局能力究竟有多强。

Weex的实现是FaceBook的开源库Yoga的前身，所以这里可以把两个看成是一种实现。

Weex的这种FlexBox的实现其实只是W3C标准的一个实现的子集，因为FlexBox的官方标准里面还有一些并没有实现出来。W3C上定义的FlexBox的标准，文档在[这里](https://www.w3.org/TR/css-flexbox-1/)。

FlexBox标准定义：

针对父视图 (flex container):
1. display
2. flex\-direction
3. flex\-wrap
4. flex\-flow
5. justify\-content
6. align\-items
7. align\-content

针对子视图 (flex items):
1. order
2. flex\-grow
3. flex\-shrink
4. flex\-basis
5. flex
6. align\-self

![](http://upload-images.jianshu.io/upload_images/1194012-63e820c1ee9472cf.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




相比官方的定义，上述的实现有一些限制：

1. 所有显示属性的node节点都默认假定是Flex的视图，当然这里要除去文本节点，因为它会被假定为inline-flex。
2. 不支持zIndex的属性，包括任何z上的排序。所有的node节点都是按照代码书写的先后顺序进行排列的。Weex 目前也不支持 z-index 设置元素层级关系，但靠后的元素层级更高，因此，对于层级高的元素，可将其排列在后面。
3. FlexBox里面定义的order属性，也不支持。flex item默认按照代码书写顺序。
4. visibility属性默认都是可见的，暂时不支持边缘塌陷合并(collapse)和隐藏(hidden)属性。
5. 不支持forced breaks。
6. 不支持垂直方向的inline(比如从上到下的text，或者从下到上的text)

关于Flexbox 在iOS这边的具体实现上一章节已经分析过了。



![](http://upload-images.jianshu.io/upload_images/1194012-2a97e349befdc557.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




接下来仔细分析一下Autolayout的具体实现



![](http://upload-images.jianshu.io/upload_images/1194012-6b994236e0c27d79.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

原来我们用Frame进行布局的时候，需要知道一个点（origin或者center）和宽高就可以确定一个View。

现在换成了Autolayout，每个View需要知道4个尺寸。left，top，width，height。

但是一个View的约束是相对于另一个View的，比如说相对于父视图，或者是相对于两两View之间的。

那么两两个View之间的约束就会变成一个八元一次的方程组。


解这个方程组可能有以下3种情况：

1. 当方程组的解的个数有无穷多个，最终会得到欠约束的有歧义的布局。
2. 当方程无解时，则表示约束有冲突。
3. 只有当方程组有唯一解的时候，才能得到一个稳定的布局。

**Autolayout 本质是一个线性方程解析器，该解析器试图找到一种可满足其规则的几何表达式。**



![](http://upload-images.jianshu.io/upload_images/1194012-09b7902e4c7c67e5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



Autolayout的底层数学模型是线性算术约束问题。


关于这个问题，早在1940年，由Dantzig提出了一个the simplex algorithm算法，但是由于这个算法实在很难用在UI应用上面，所以没有得到很广泛的应用，直到1997年，澳大利亚的莫纳什大学（Monash University）的两名学生，Alan Borning 和 Kim Marriott实现了Cassowary线性约束算法，才得以在UI应用上被大量的应用起来。

Cassowary线性约束算法是基于双simplex算法的，在增加约束或者一个对象被移除的时候，通过局部误差增益 和 加权求和比较 ，能够完美的增量处理不同层次的约束。Cassowary线性约束算法适合GUI布局系统，被用来计算view之间的位置的。开发者可以指定不同View之间的位置关系和约束关系，Cassowary线性约束算法会去求处符合条件的最优值。

下面是两位学生写的相关的论文，有兴趣的可以读一下，了解一下算法的具体实现：

1. Alan Borning, Kim Marriott, Peter Stuckey, and Yi Xiao, [Solving Linear Arithmetic Constraints for User Interface Applications](https://constraints.cs.washington.edu/solvers/uist97.pdf), Proceedings of the 1997 ACM Symposium on User Interface Software and Technology, October 1997, pages 87-96.
2. Greg J. Badros and Alan Borning, "The Cassowary Linear Arithmetic Constraint Solving Algorithm: Interface and Implementation", Technical Report UW-CSE-98-06-04, June 1998 ([pdf](https://constraints.cs.washington.edu/cassowary/cassowary-tr.pdf))
3. Greg J. Badros, Alan Borning, and Peter J. Stuckey, "The Cassowary Linear Arithmetic Constraint Solving Algorithm," *ACM Transactions on Computer Human Interaction*, Vol. 8 No. 4, December 2001, pages 267-306. ([pdf](https://constraints.cs.washington.edu/solvers/cassowary-tochi.pdf))

Cassowary线性约束算法的伪代码如下：

![](http://upload-images.jianshu.io/upload_images/1194012-2f208ced7d958ce8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


关于这个算法已经被人们实现成了各个版本。1年以后，又出了一个新的QOCA算法。以下这段话摘抄自1997年ACM权威论文上的一篇文章：

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


Cassowary（[项目主页](https://constraints.cs.washington.edu/cassowary/)）也是优先被Smalltalk实现了，也是用在Autolayout技术上。另外还有更加复杂的QOCA算法，这里就不再细谈了，有兴趣的同学可以看看上面三篇论文，里面有详细的描述。


#### 2.算法性能测试准备工作

开始笔者是打算连带Weex的布局性能一起测试的，但是由于Weex的布局都在子线程，刷新渲染回到主线程，需要测试都在主线程的情况需要改动一些代码，而且Weex原生的布局是从JS调用方法，如果用这种方法又会多损耗一些性能，对测试结果有影响。于是换成Weex相同布局方式的Yoga算法进行测试。由于Facebook对它进行了很好的封装，使用起来也很方便。虽然Layout算法和Weex有些差异，但是不影响定性的比较。


确定下来测试对象：Frame，FlexBox(Yoga实现)，Autolayout。

测试前，还需要准备测试模型，这里选出了3种测试模型。

第一种测试模型是随机生成完全不相关联的View。如下图：

![](http://upload-images.jianshu.io/upload_images/1194012-a7a0d48cba94f3d9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

第二种测试模型是生成相互嵌套的View。嵌套规则设置一个简单的：子视图依次比父视图高度少一个像素。类似下图，这是500个View相互嵌套的结果：

![](http://upload-images.jianshu.io/upload_images/1194012-0828ddc58f8d30ca.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

第三种测试模型是针对Autolayout专门加的。由于Autolayout约束的特殊性，这里针对链式约束额外增加的测试模型。规则是前后两个相连的View之间依次加上约束。类似下图，这是500个View链式的约束结果：

![](http://upload-images.jianshu.io/upload_images/1194012-1b8f68cd9debed67.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

根据测试模型，我们可以得到如下的7组需要测试的测试用例：

1.Frame
2.嵌套的Frame
3.Yoga
4.嵌套的Yoga
5.Autolayout
6.嵌套的Autolayout
7.链式的Autolayout


测试样本：由于需要考虑到测试的通用性，测试样本要尽量随机。于是针对随机生成的坐标全部都随机生成，View的颜色也全部都随机生成，这样保证了通用公正公平性质。

测试次数：为了保证测试数据能尽量真实，笔者在这里花了大量的时间。每组测试用例都针对从100，200，300，400，500，600，700，800，900，1000个视图进行测试，为了保证测试的普遍性，这里每次测试都测试10000次，然后对10000次的结果进行加和平均。加和平均取小数点后5位。（10000次的统计是用计算机来算的，但是真的非常非常非常的耗时，有兴趣的可以自己用电脑试试）

最后展示一下测试机器的配置和系统版本：

（由于iPhone真机对每个App的内存有限制，产生1000个嵌套的视图，并且进行10000次试验，iPhone真机完全受不了这种计算量，App直接闪退，所以用真机测试到一半，改用模拟器测试，借助Mac的性能，咬着牙从零开始，重新统计了所有测试用例的数据）

如果有性能更强的Mac电脑（垃圾桶），测试全过程花的时间可能会更少。

笔者用的电脑的配置如下：



![](http://upload-images.jianshu.io/upload_images/1194012-510c7d7ab97e2330.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


测试用的模拟器是iPad Pro（12.9 inch）iOS 10.3（14E269）



我所用的测试代码也公布出来，有兴趣的可以自己测试测试。[测试代码在这里](https://github.com/halfrost/Halfrost-Field/tree/master/contents/iOS/AutoLayoutProfiling-master)  

#### 3.算法性能测试结果

公布测试结果：

![](http://upload-images.jianshu.io/upload_images/1194012-34171d65db564340.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图数据是10，20，30，40，50，60，70，80，90，100个View分别用7组用例测试出来的结果。将上面的结果统计成折线图，如下：

![](http://upload-images.jianshu.io/upload_images/1194012-f9468b0f10f0ef95.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

结果依旧是Autolayout的3种方式都高于其他4种布局方式。

![](http://upload-images.jianshu.io/upload_images/1194012-7f51f5e34c9e5485.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图是3个布局算法在普通场景下的性能比较图，可以看到，FlexBox的性能接近于原生的Frame。

![](http://upload-images.jianshu.io/upload_images/1194012-64f5f7c2e89e2661.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图是3个布局算法在嵌套情况下的性能比较图，可以看到，FlexBox的性能也依旧接近于原生的Frame。而嵌套情况下的Autolayout的性能急剧下降。

![](http://upload-images.jianshu.io/upload_images/1194012-409f0c3e820c5770.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


最后这张图也是专门针对Autolayout额外加的一组测试。目的是为了比较3种场景下不同的Autolayout的性能，可以看到，嵌套的Autolayout的性能依旧是最差的！



![](http://upload-images.jianshu.io/upload_images/1194012-6b338b4507694268.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图数据是100，200，300，400，500，600，700，800，900，1000个View分别用7组用例测试出来的结果。将上面的结果统计成折线图，如下：


![](http://upload-images.jianshu.io/upload_images/1194012-e60d70a0eaa4a67f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

当视图多到900，1000的时候，嵌套的Autolayout直接就导致模拟器崩溃了。

![](http://upload-images.jianshu.io/upload_images/1194012-4560c9da3bfa0968.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图是3个布局算法在普通场景下的性能比较图，可以看到，FlexBox的性能接近于原生的Frame。

![](http://upload-images.jianshu.io/upload_images/1194012-cad15676ac4504b7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图是3个布局算法在嵌套情况下的性能比较图，可以看到，FlexBox的性能也依旧接近于原生的Frame。而嵌套情况下的Autolayout的性能急剧下降。

![](http://upload-images.jianshu.io/upload_images/1194012-c71dbeba866e73fb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

最后这张图是专门针对Autolayout额外加的一组测试。目的是为了比较3种场景下不同的Autolayout的性能，可以看到，平时我们使用嵌套的Autolayout的性能是最差的！

### 三. Weex是如何布局原生界面的


上一章节看了FlexBox算法的强大布局能力，这一章节就来看看Weex究竟是如何利用这个能力的对原生View进行Layout。


在解答上面这个问题之前，先让我们回顾一下上篇文章[《Weex 是如何在 iOS 客户端上跑起来的》](http://www.jianshu.com/p/41cde2c62b81)里面提到的，在JSFramework转换从网络上下载下来的JS文件之前，本地先注册了4个重要的回调函数。


```objectivec

typedef NSInteger(^WXJSCallNative)(NSString *instance, NSArray *tasks, NSString *callback);
typedef NSInteger(^WXJSCallAddElement)(NSString *instanceId,  NSString *parentRef, NSDictionary *elementData, NSInteger index);
typedef NSInvocation *(^WXJSCallNativeModule)(NSString *instanceId, NSString *moduleName, NSString *methodName, NSArray *args, NSDictionary *options);
typedef void (^WXJSCallNativeComponent)(NSString *instanceId, NSString *componentRef, NSString *methodName, NSArray *args, NSDictionary *options);


```

这4个block非常重要，是JS和OC进行相互调用的四大函数。

先来回顾一下这四大函数注册的时候分别封装了哪些闭包。

```objectivec

@interface WXBridgeContext ()
@property (nonatomic, strong) id<WXBridgeProtocol>  jsBridge;

```

在WXBridgeContext类里面有一个jsBridge。jsBridge初始化的时候会注册这4个全局函数。


第一个闭包函数：

```objectivec

    [_jsBridge registerCallNative:^NSInteger(NSString *instance, NSArray *tasks, NSString *callback) {
        return [weakSelf invokeNative:instance tasks:tasks callback:callback];
    }];



```


这里的闭包函数会被传入到下面这个函数中：


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

这里就封装了一个函数，暴露给JS用。方法名叫callNative，函数参数为3个，分别是instanceId，tasksArray任务数组，callbackId回调ID。

所有的OC的闭包都需要封装一层，因为暴露给JS的方法不能有冒号，所有的参数都是直接跟在小括号的参数列表里面的，因为JS的函数是这样定义的。

当JS调用callNative方法之后，就会最终执行WXBridgeContext类里面的[weakSelf invokeNative:instance tasks:tasks callback:callback]方法。


第二个闭包函数：

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

这个闭包会被传到下面的函数中：



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

这里的包装方法和第一个方法是相同的。这里暴露给JS的方法名叫callAddElement，函数参数为4个，分别是instanceIdString，componentData组件的数据，parentRef引用编号，insertIndex插入视图的index。

当JS调用callAddElement方法，就会最终执行WXBridgeContext类里面的WXPerformBlockOnComponentThread闭包。

第三个闭包函数：


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

这个闭包会被传到下面的函数中：

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



这里暴露给JS的方法名叫callNativeModule，函数参数为5个，分别是instanceIdString，moduleNameString模块名，methodNameString方法名，argsArray参数数组，optionsDic字典。

当JS调用callNativeModule方法，就会最终执行WXBridgeContext类里面的WXModuleMethod方法。


第四个闭包函数：

```objectivec


    [_jsBridge registerCallNativeComponent:^void(NSString *instanceId, NSString *componentRef, NSString *methodName, NSArray *args, NSDictionary *options) {
        WXSDKInstance *instance = [WXSDKManager instanceForID:instanceId];
        WXComponentMethod *method = [[WXComponentMethod alloc] initWithComponentRef:componentRef methodName:methodName arguments:args instance:instance];
        [method invoke];
    }];

```

这个闭包会被传到下面的函数中：

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

这里暴露给JS的方法名叫callNativeComponent，函数参数为5个，分别是instanceIdString，componentNameString组件名，methodNameString方法名，argsArray参数数组，optionsDic字典。

当JS调用callNativeComponent方法，就会最终执行WXBridgeContext类里面的WXComponentMethod方法。



![](http://upload-images.jianshu.io/upload_images/1194012-23bfe161375b750a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




总结一下上述暴露给JS的4个方法：

1. callNative
这个方法是JS用来调用任意一个Native方法的。

2. callAddElement
这个方法是JS用来给当前页面添加视图元素的。

3. callNativeModule
这个方法是JS用来调用模块里面暴露出来的方法。

4. callNativeComponent
这个方法是JS用来调用组件里面暴露出来的方法。


Weex在布局的时候就只会用到前2个方法。

####（一）createRoot:


当JSFramework把JS文件转换类似JSON的文件之后，就开始调用Native的callNative方法。

callNative方法会最终执行WXBridgeContext类里面的[weakSelf invokeNative:instance tasks:tasks callback:callback]方法。


当前操作处于子线程“com.taobao.weex.bridge”中。

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
    

    // 根据JS发送过来的方法，进行转换成Native方法调用
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
    
    // 如果有回调，回调给JS
    [self performSelector:@selector(_sendQueueLoop) withObject:nil];
    
    return 1;
}


```


这里会把JS从发送过来的callNative方法转换成Native的组件component的方法调用或者模块module的方法调用。

举个例子：

JS从callNative方法传过来3个参数


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

tasks数组里面会解析出各个方法和调用者。

这个例子里面就会解析出Dom模块的createBody方法。

接着就会调用Dom模块的createBody方法。

```objectivec


    if (isSync) {
        [invocation invoke];
        return invocation;
    } else {
        [self _dispatchInvocation:invocation moduleInstance:moduleInstance];
        return nil;
    }

```

调用方法之前，有一个线程切换的步骤。如果是同步方法，那么就直接调用，如果是异步方法，那么嗨需要进行线程转换。

Dom模块的createBody方法是异步的方法，于是就需要调用\_dispatchInvocation: moduleInstance:方法。


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
        // 判断当前是否有Queue，如果没有，就返回main_queue，如果有，就切换到targetQueue
        targetQueue = [moduleInstance targetExecuteQueue] ?: dispatch_get_main_queue();
    } else if([moduleInstance respondsToSelector:@selector(targetExecuteThread)]){
        // 判断当前是否有Thread，如果没有，就返回主线程，如果有，就切换到targetThread
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

在整个Weex模块中，目前只有2个模块是有targetQueue的，一个是WXClipboardModule，另一个是WXStorageModule。所以这里没有targetQueue，就只能切换到对应的targetThread上。

```objectivec

void WXPerformBlockOnThread(void (^ _Nonnull block)(), NSThread *thread)
{
    [WXUtility performBlock:block onThread:thread];
}

+ (void)performBlock:(void (^)())block onThread:(NSThread *)thread
{
    if (!thread || !block) return;
    
    // 如果当前线程不是目标线程上，就要切换线程
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

这里就是切换线程的操作，如果当前线程不是目标线程，就要切换线程。在目标线程上调用\_performBlock:方法，入参还是最初传进来的block闭包。

切换前线程处于子线程“com.taobao.weex.bridge”中。


在WXDomModule中调用targetExecuteThread方法

```objectivec


- (NSThread *)targetExecuteThread
{
    return [WXComponentManager componentThread];
}


```

切换线程之后，当前线程变成了“com.taobao.weex.component”。


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

        // 开启组件任务
        [manager startComponentTasks];
        block(manager);
    });
}



```


当调用了Dom模块的createBody方法以后，会先调用WXComponentManager的startComponentTasks方法，再调用createRoot:方法。


这里会初始化一个WXComponentManager。

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

WXComponentManager的初始化重点是会开启DisplayLink，它会开启一个runloop。

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


displayLink一旦开启，被加入到当前runloop之中，每次runloop循环一次都会执行刷新布局的方法\_handleDisplayLink。

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

WXComponentManager的startComponentTasks方法仅仅是更改了CADisplayLink的paused的状态。CADisplayLink就是用来刷新layout的。

```objectivec

@implementation WXComponentManager
{
    // 对WXSDKInstance的弱引用
    __weak WXSDKInstance *_weexInstance;
    // 当前WXComponentManager是否可用
    BOOL _isValid;
    
    // 是否停止刷新布局
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


以上就是WXComponentManager的所有属性，可以看出WXComponentManager就是用来处理UI任务的。

再来看看createRoot:方法：

```objectivec


- (void)createRoot:(NSDictionary *)data
{
    WXAssertComponentThread();
    WXAssertParam(data);
    
    // 1.创建WXComponent，作为rootComponent
    _rootComponent = [self _buildComponentForData:data];

    // 2.初始化css_node_t，作为rootCSSNode
    [self _initRootCSSNode];
    
    __weak typeof(self) weakSelf = self;
    // 3.添加UI任务到uiTaskQueue数组中
    [self _addUITask:^{
        __strong typeof(self) strongSelf = weakSelf;
        strongSelf.weexInstance.rootView.wx_component = strongSelf->_rootComponent;
        [strongSelf.weexInstance.rootView addSubview:strongSelf->_rootComponent.view];
    }];
}

```

这里干了3件事情:

#### 1.创建WXComponent

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

这里的入参data是之前的tasks数组。

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
        
        // 设置NavBar的Style
        [self _setupNavBarWithStyles:_styles attributes:_attributes];
        // 根据style初始化cssNode数据结构
        [self _initCSSNodeWithStyles:_styles];
        // 根据style初始化View的各个属性
        [self _initViewPropertyWithStyles:_styles];
        // 处理Border的圆角，边线宽度，背景颜色等属性
        [self _handleBorders:styles isUpdating:NO];
    }
    
    return self;
}


```


上述函数就是初始化WXComponent的布局的各个属性。这里会用到FlexBox里面的一些计算属性的方法就在\_initCSSNodeWithStyles:方法里面。

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
    
    // 重新计算_cssNode需要布局的子视图个数
    [self _recomputeCSSNodeChildren];
    // 将style各个属性都填充到cssNode数据结构中
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


在\_fillCSSNode:方法里面会对FlexBox算法里面定义的各个属性值就行赋值。





#### 2.初始化css\_node\_t


在这里，准备开始Layout之前，我们需要先初始化rootCSSNode

```objectivec

- (void)_initRootCSSNode
{
    _rootCSSNode = new_css_node();
    
    // 根据页面weexInstance设置rootCSSNode的坐标和宽高尺寸
    [self _applyRootFrame:self.weexInstance.frame toRootCSSNode:_rootCSSNode];
    
    _rootCSSNode->style.flex_wrap = CSS_NOWRAP;
    _rootCSSNode->is_dirty = rootNodeIsDirty;
    _rootCSSNode->get_child = rootNodeGetChild;
    _rootCSSNode->context = (__bridge void *)(self);
    _rootCSSNode->children_count = 1;
}

```

在上述方法中，会初始化rootCSSNode的坐标和宽高尺寸。

#### 3.添加UI任务到uiTaskQueue数组中



```objectivec

    [self _addUITask:^{
        __strong typeof(self) strongSelf = weakSelf;
        strongSelf.weexInstance.rootView.wx_component = strongSelf->_rootComponent;
        [strongSelf.weexInstance.rootView addSubview:strongSelf->_rootComponent.view];
    }];


```



WXComponentManager会把当前的组件以及它对应的View添加到页面Instance的rootView上面的这个任务，添加到uiTaskQueue数组中。


\_rootComponent.view会创建组件对应的WXView，这个是继承自UIView的。所以Weex通过JS代码创建出来的控件都是原生的，都是WXView类型的，实质就是UIView。创建UIView这一步又是回到主线程中执行的。

最后显示到页面上的工作，是由displayLink的刷新方法在主线程刷新UI显示的。

```objectivec


- (void)_handleDisplayLink
{ 
    [self _layoutAndSyncUI];
}

- (void)_layoutAndSyncUI
{
    // Flexbox布局
    [self _layout];
    if(_uiTaskQueue.count > 0){
        // 同步执行UI任务
        [self _syncUITasks];
        _noTaskTickCount = 0;
    } else {
        // 如果当前一秒内没有任务，那么智能的挂起displaylink，以节约CPU时间
        _noTaskTickCount ++;
        if (_noTaskTickCount > 60) {
            [self _suspendDisplayLink];
        }
    }
}

```

\_layoutAndSyncUI是布局和刷新UI的核心流程。每次刷新一次，都会先调用Flexbox算法的Layout进行布局，这个布局是在子线程“com.taobao.weex.component”执行的。接着再去查看当前是否有UI任务需要执行，如果有，就切换到主线程进行UI刷新操作。

这里还会有一个智能的挂起操作。就是判断一秒内如果都没有任务，那么就挂起displaylink，以节约CPU时间。


```objectivec


- (void)_layout
{
    BOOL needsLayout = NO;
    NSEnumerator *enumerator = [_indexDict objectEnumerator];
    WXComponent *component;
    // 判断当前是否需要布局，即是判断当前组件的_isLayoutDirty这个BOLL属性值
    while ((component = [enumerator nextObject])) {
        if ([component needsLayout]) {
            needsLayout = YES;
            break;
        }
    }

    if (!needsLayout) {
        return;
    }
    
    // Flexbox的算法核心函数
    layoutNode(_rootCSSNode, _rootCSSNode->style.dimensions[CSS_WIDTH], _rootCSSNode->style.dimensions[CSS_HEIGHT], CSS_DIRECTION_INHERIT);
 
    NSMutableSet<WXComponent *> *dirtyComponents = [NSMutableSet set];
    [_rootComponent _calculateFrameWithSuperAbsolutePosition:CGPointZero gatherDirtyComponents:dirtyComponents];
    // 计算当前weexInstance的rootView.frame，并且重置rootCSSNode的Layout
    [self _calculateRootFrame];
  
    // 在每个需要布局的组件之间
    for (WXComponent *dirtyComponent in dirtyComponents) {
        [self _addUITask:^{
            [dirtyComponent _layoutDidFinish];
        }];
    }
}

```

\_indexDict里面维护了一张整个页面的布局结构的Map，举个例子：

```objectivec


NSMapTable {
[7] _root -> <div ref=_root> <WXView: 0x7fc59a416140; frame = (0 0; 331.333 331.333); layer = <WXLayer: 0x608000223180>>
[12] 5 -> <image ref=5> <WXImageView: 0x7fc59a724430; baseClass = UIImageView; frame = (110.333 192.333; 110.333 110.333); clipsToBounds = YES; layer = <WXLayer: 0x60000002f780>>
[13] 3 -> <image ref=3> <WXImageView: 0x7fc59a617a00; baseClass = UIImageView; frame = (110.333 55.3333; 110.333 110.333); clipsToBounds = YES; opaque = NO; gestureRecognizers = <NSArray: 0x60000024b760>; layer = <WXLayer: 0x60000003e8c0>>
[15] 4 -> <text ref=4> <WXText: 0x7fc59a509840; text: hello Weex; frame:0.000000,441.666667,331.333333,26.666667 frame = (0 441.667; 331.333 26.6667); opaque = NO; layer = <WXLayer: 0x608000223480>>
}



```


所有的组件都是由ref引用值作为Key存储的，只要知道这个页面上全局唯一的ref，就可以拿到这个ref对应的组件。

\_layout会先判断当前是否有需要布局的组件，如果有，就从rootCSSNode开始进行Flexbox算法的Layout。执行完成以后还需要调整一次rootView的frame，最后添加一个UI任务到taskQueue中，这个任务标记的是组件布局完成。

注意上述所有布局操作都是在子线程“com.taobao.weex.component”中执行的。


```objectivec

- (void)_syncUITasks
{
    // 用blocks接收原来uiTaskQueue里面的所有任务
    NSArray<dispatch_block_t> *blocks = _uiTaskQueue;
    // 清空uiTaskQueue
    _uiTaskQueue = [NSMutableArray array];
    // 在主线程中依次执行uiTaskQueue里面的所有闭包
    dispatch_async(dispatch_get_main_queue(), ^{
        for(dispatch_block_t block in blocks) {
            block();
        }
    });
}


```

布局完成以后就调用同步的UI刷新方法。注意这里要对UI进行操作，一定要切换回主线程。



![](http://upload-images.jianshu.io/upload_images/1194012-6b16532cf00e3f99.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)









####（二）callAddElement

在子线程“com.taobao.weex.bridge”中，会一直相应来自JSFramework调用Native的方法。


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

当JSFramework调用callAddElement方法，就会执行上述代码的闭包函数。这里会接收来自JS的4个入参。


举个例子，JSFramework可能会通过callAddElement方法传过来这样4个参数：

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

这里的insertIndex为0，parentRef是\_root，componentData是当前要创建的组件的信息，instanceIdString是-1。


之后WXComponentManager就会调用startComponentTasks开始displaylink继续准备刷新布局，最后调用addComponent: toSupercomponent: atIndex: appendingInTree:方法添加新的组件。

注意，WXComponentManager的这两步操作，又要切换线程，切换到“com.taobao.weex.component”子线程中。


```objectivec

- (void)addComponent:(NSDictionary *)componentData toSupercomponent:(NSString *)superRef atIndex:(NSInteger)index appendingInTree:(BOOL)appendingInTree
{
    WXComponent *supercomponent = [_indexDict objectForKey:superRef];
    WXAssertComponentExist(supercomponent);
    
    [self _recursivelyAddComponent:componentData toSupercomponent:supercomponent atIndex:index appendingInTree:appendingInTree];
}

```


WXComponentManager会在“com.taobao.weex.component”子线程中递归的添加子组件。


```objectivec

- (void)_recursivelyAddComponent:(NSDictionary *)componentData toSupercomponent:(WXComponent *)supercomponent atIndex:(NSInteger)index appendingInTree:(BOOL)appendingInTree
{

   // 根据componentData构建组件
    WXComponent *component = [self _buildComponentForData:componentData];
    
    index = (index == -1 ? supercomponent->_subcomponents.count : index);
    
    [supercomponent _insertSubcomponent:component atIndex:index];
    // 用_lazyCreateView标识懒加载
    if(supercomponent && component && supercomponent->_lazyCreateView) {
        component->_lazyCreateView = YES;
    }
    
    // 插入一个UI任务
    [self _addUITask:^{
        [supercomponent insertSubview:component atIndex:index];
    }];

    NSArray *subcomponentsData = [componentData valueForKey:@"children"];
    
    BOOL appendTree = !appendingInTree && [component.attributes[@"append"] isEqualToString:@"tree"];
    // 再次递归的规则：如果父视图是一个树状结构，子视图即使也是一个树状结构，也不能再次Layout
    for(NSDictionary *subcomponentData in subcomponentsData){
        [self _recursivelyAddComponent:subcomponentData toSupercomponent:component atIndex:-1 appendingInTree:appendTree || appendingInTree];
    }
    if (appendTree) {
        // 如果当前组件是树状结构，强制刷新layout，以防在syncQueue中堆积太多的同步任务。
        [self _layoutAndSyncUI];
    }
}


```


在递归的添加子组件的时候，如果是树状结构，还需要再次强制进行一次layout，同步一次UI。这里调用[self \_layoutAndSyncUI]方法和createRoot:时候实现是完全一样的，下面就不再赘述了。


这里会循环添加多个子视图，相应的也会调用多次Layout方法。



![](http://upload-images.jianshu.io/upload_images/1194012-d1f730e3bee34bdd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)






#### （三）createFinish


当所有的视图都添加完成以后，JSFramework就是再次调用callNative方法。

还是会传过来3个参数。

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

callNative通过这个参数会调用到WXDomModule的createFinish方法。这里的具体实现见第一步的callNative，这里不再赘述。

```objectivec

- (void)createFinish
{
    [self performBlockOnComponentManager:^(WXComponentManager *manager) {
        [manager createFinish];
    }];
}


```

这里最终也是会调用到WXComponentManager的createFinish。当然这里是会进行线程切换，切换到WXComponentManager的线程“com.taobao.weex.component”子线程上。

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

WXComponentManager的createFinish方法最后就是添加一个UI任务，回调到主线程的renderFinish方法里面。



![](http://upload-images.jianshu.io/upload_images/1194012-2896c636f11b2202.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



至此，Weex的布局流程就完成了。


### 最后


![](http://upload-images.jianshu.io/upload_images/1194012-caf559cea2e73cb1.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



虽然Autolayout是苹果原生就支持的自动布局方案，但是在稍微复杂的界面就会出现性能问题。大半年前，Draveness的这篇[《从 Auto Layout 的布局算法谈性能》](http://draveness.me/layout-performance/)文章里面也稍微“批判”了Autolayout的性能问题，但是文章里面最后提到的是用ASDK的方法来解决问题。本篇文章则献上另外一种可用的布局方法——FlexBox，并且带上了经过大量测试的测试数据，向大左的这篇经典文章致敬！

如今，iOS平台上几大可用的布局方法有：Frame原生布局，Autolayout原生自动布局，FlexBox的Yoga实现，ASDK。

当然，基于这4种基本方案以外，还有一些组合方法，比如Weex的这种，用JS的CSS解析成类似JSON的DOM，再调用Native的FlexBox算法进行布局。前段时间还有来自美团的[《布局编码的未来》](http://tech.meituan.com/the_future_of_layout.html)里面提到的毕加索（picasso）布局方法。原理也是会用到JSCore，将JS写的JSON或者自定义的DSL，经过本地的picassoEngine布局引擎转换成Native布局，最终利用锚点的概念做到高效的布局。


最后，推荐2个iOS平台上比较优秀的利用了FlexBox的原理的开源库：


来自Facebook的**[yoga](https://github.com/facebook/yoga)**  
来自饿了么的**[FlexBoxLayout](https://github.com/LPD-iOS/FlexBoxLayout)**



------------------------------------------------------

Weex 源码解析系列文章：

[Weex 是如何在 iOS 客户端上跑起来的](https://github.com/halfrost/Halfrost-Field/blob/master/contents/iOS/Weex/Weex_how_to_work_in_iOS.md)  
[由 FlexBox 算法强力驱动的 Weex 布局引擎](https://github.com/halfrost/Halfrost-Field/blob/master/contents/iOS/Weex/Weex_layout_engine_powered_by_Flexbox's_algorithm.md)  
[Weex 事件传递的那些事儿](https://github.com/halfrost/Halfrost-Field/blob/master/contents/iOS/Weex/Weex_events.md)     
[Weex 中别具匠心的 JS Framework](https://github.com/halfrost/Halfrost-Field/blob/master/contents/iOS/Weex/Weex_ingenuity_JS_framework.md)  
[iOS 开发者的 Weex 伪最佳实践指北](https://github.com/halfrost/Halfrost-Field/blob/master/contents/iOS/Weex/Weex_pseudo-best_practices_for_iOS_developers.md)  

------------------------------------------------------