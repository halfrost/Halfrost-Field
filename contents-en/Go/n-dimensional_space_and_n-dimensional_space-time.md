# Understanding n-Dimensional Space and n-Dimensional Spacetime


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-949b8eb387f7248b.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


## Preface

Some readers may be wondering why I would suddenly publish an article that seems completely unrelated to technology. In fact, this topic grew out of my research into spatial search. After reading some materials and deepening my understanding of n-dimensional space and n-dimensional spacetime, I wrote this summary. If you have never been exposed to this topic before, it may feel unfamiliar at first. If you are a mathematics major or work professionally in this area, please feel free to point out any mistakes so we can discuss them together.


## Space and Spacetime

First, space and spacetime are two concepts that are often confused. In fact, they are different.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-675163b7b1955259.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


Einstein’s general relativity mentions four-dimensional space, meaning three dimensions of space plus one dimension of time. This is not the same as the concept of multidimensional space in mathematics. In reality, the time dimension is independent of the spatial dimensions. One-dimensional space can also have time, and two-dimensional space can also have time. Multidimensional spaces all have time. But the “four-dimensional space” mentioned in general relativity is actually four-dimensional spacetime composed of three spatial dimensions plus one temporal dimension.

After Riemannian geometry, high-dimensional geometry developed for many years. In superstring theory, the universe has nine spatial dimensions plus one temporal dimension. In M-theory, the universe is eleven-dimensional spacetime with ten spatial dimensions plus one temporal dimension.


## How to Describe the Partitioning of High-Dimensional Space


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-2de3dd99366b20d8.jpeg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


In two-dimensional space, two perpendicular intersecting lines can form the X-axis and the Y-axis. In three-dimensional space, three mutually perpendicular intersecting directions form the X-axis, Y-axis, and Z-axis. The third line passes through the intersection point in the two-dimensional space (that is, the origin) and is perpendicular to the two-dimensional space. Similarly, in four-dimensional space, there is likewise a line that passes through the intersection point of the three lines in three-dimensional space (the origin of the three-dimensional coordinate axes) and is perpendicular to the previous three lines. This line in four-dimensional space that is perpendicular to three-dimensional space cannot be represented or drawn in three-dimensional space. It lies in four-dimensional space inside the coordinate origin.

So how can four-dimensional space be connected intuitively with three-dimensional space? After all, three-dimensional space is the spatial structure we humans are most familiar with. We know that three-dimensional space has the X-axis, Y-axis, and Z-axis, and these three axes divide the entire space into six faces: up and down, left and right, front and back. How else can four-dimensional space partition space? Compared with three-dimensional space, it has two additional directions: inside and outside. The “upper side” on the inside and the “upper side” on the outside are different spaces, even though in three-dimensional space they are both simply “above.”

Similarly, if we continue extending these ideas into higher-dimensional space, then there must exist a line that is perpendicular to n-1 lines, where those n-1 lines also mutually intersect at right angles.


The above describes multidimensional space from the perspective of spatial partitioning.


## The Form of Objects in High-Dimensional Space


In high-dimensional space, objects are highly abstract and may be impossible to draw graphically. But we can understand higher dimensions through the lower-dimensional spaces we can comprehend, which requires studying how objects in high-dimensional space appear in lower-dimensional space.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-3eb351520239e67c.jpeg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


In two-dimensional space, an equilateral triangle has three vertices. Suppose all side lengths are equal to 1. If there exists a fourth point in space such that its distance to each of the three vertices is also 1, then this point must not exist in the two-dimensional space; it must exist in three-dimensional space (the mathematical proof is omitted here—it is too hard; interested readers can try proving it). If these four points are all connected in three-dimensional space, they form a three-dimensional regular tetrahedron.

Similarly, if there is a fifth point whose distance to every vertex of this three-dimensional regular tetrahedron is 1, then this point must exist in four-dimensional space, and together with the three-dimensional regular tetrahedron it forms a four-dimensional hypertetrahedron.

A hypertetrahedron is already beyond the dimensions we live in, so we cannot draw its shape in three-dimensional space. But we can observe it in three-dimensional space through projection.


Let’s first review how a three-dimensional regular tetrahedron is generated. Since the base is an equilateral triangle, the distance from the orthocenter of the equilateral triangle to the three vertices must be equal. So we take this center point and pull it into three-dimensional space until its distance from the other three vertices is 1. This generates a three-dimensional regular tetrahedron. The three internal obtuse triangles divided by the orthocenter follow the orthocenter as it is pulled outward, becoming the three outer faces of the regular tetrahedron.


Similarly, in a three-dimensional regular tetrahedron, take its orthocenter. The distance from the orthocenter to the four vertices is equal. This orthocenter divides the regular tetrahedron internally into four flattened tetrahedra. If we pull the orthocenter into four-dimensional space and use it as the fifth vertex, it becomes a hypertetrahedron. The four flattened tetrahedra created by the internal division also evolve into the four outer surfaces of the hypertetrahedron.

A four-dimensional hypertetrahedron is a hyperbody composed of 5 vertices, 10 edges, 10 triangular faces, and 5 tetrahedra. It cannot be described in three-dimensional space.

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-6ce61cfd05e13311.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


A cube is a common three-dimensional object. What does a cube become in four-dimensional space?


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-e2f93e999b664bf5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


The figure above is a cube in four-dimensional space, called a hypercube.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-b71e1fbb2966d876.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


The figure above shows that every edge of the four-dimensional cube has the same length, and also shows how the cubes are connected to one another. The simplest way to construct a hypercube is to take two cubes and connect each of the 8 vertices of one cube to the corresponding vertex of the other cube.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-4d23bc0e50ce2097.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


The figure above reveals that a hypercube is essentially obtained by combining two cubes and connecting their corresponding vertices.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-98a888cd92384a41.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


The figure above arranges each vertex by the length of the path along edges starting from the bottommost vertex. If we want to use a hypercube as the basis for connecting different processors in a [parallel computing](https://zh.wikipedia.org/wiki/%E5%B9%B6%E8%A1%8C%E8%AE%A1%E7%AE%97) [network topology](https://zh.wikipedia.org/wiki/%E7%BD%91%E7%BB%9C%E6%8B%93%E6%89%91), these diagrams are very useful. Between any two vertices in a hypercube, there are at most 4 different routes, and many paths here are equivalent. A hypercube is also a [bipartite graph](https://zh.wikipedia.org/wiki/%E4%BA%8C%E5%88%86%E5%9B%BE), just like a square and a cube.

The following two figures are perspective projections.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-d25f24d1099f52c6.gif?imageMogr2/auto-orient/strip'>
</p>


The figure above is the [perspective projection](https://zh.wikipedia.org/wiki/%E9%80%8F%E8%A7%86%E6%8A%95%E5%BD%B1) of a tesseract during a [simple rotation](https://zh.wikipedia.org/w/index.php?title=%E5%8D%95%E6%97%8B%E8%BD%AC&action=edit&redlink=1) around a plane that cuts through the shape from front-left to back-right and from top to bottom.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-c7d7a93436e337e1.gif?imageMogr2/auto-orient/strip'>
</p>


The figure above is the perspective projection of a tesseract during a [double rotation](https://zh.wikipedia.org/w/index.php?title=%E5%8F%8C%E6%97%8B%E8%BD%AC&action=edit&redlink=1) around two mutually [orthogonal](https://zh.wikipedia.org/wiki/%E6%AD%A3%E4%BA%A4) planes in four-dimensional space.

Four-dimensional space and the spaces above it belong to high-dimensional models. High-dimensional models can also be divided into mathematical and physical concepts.

In mathematics, there are many models of multidimensionality. In theory, the number of dimensions can be very high, and there are many models. But very few satisfy commutative invariance, so some people believe four-dimensional space is the physical upper limit. Others, however, believe that higher-dimensional physics may exist. Thinking about this is intellectually beneficial because it is constrained only by mathematical conditions.

In physics, there are also many models of multidimensionality. In theory, the number of dimensions cannot be very high. To explain the finite-but-unbounded nature of the universe as a whole, multidimensionality must be introduced, usually as four-dimensional spacetime (a pair of relatively composed properties). There are also some other finite, countable numbers of dimensions, but not many models may be physically valid. Thinking about this is very difficult because it is constrained by physical phenomena.


## Do X-Ray Vision and Walking Through Walls Really Not Exist?


![](http://upload-images.jianshu.io/upload_images/1194012-dfbf3d0c8e69d510.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The world as seen by an ant is almost two-dimensional. In its eyes there is only length and width, but no height. Any three-dimensional object is just a “surface” to it, and it will crawl over it. Or consider a two-dimensional space: people living inside Along the River During the Qingming Festival would see only chaotic points, lines, and surfaces. The people in the painting cannot form a complete understanding of the entire world in the painting. But we, living in three-dimensional space, can see the entire painted world at a glance. Similarly, those of us in three-dimensional space cannot see a three-dimensional object completely at a glance. For example, to see a tall building in front of us in its entirety—its four sides plus its roof and bottom—we cannot do it in a single glance; we need to walk around it. But in four-dimensional space, a four-dimensional being looking at a tall building could see what it looks like in a single glance.

This suggests a perhaps not entirely correct conclusion: lower-dimensional space is merely the skin of higher-dimensional space, because lower-dimensional space is formed when some dimension in higher-dimensional space collapses and degenerates into a “skin.”


Recall the two-dimensional equilateral triangle, the three-dimensional regular tetrahedron, and the four-dimensional hypertetrahedron mentioned earlier. Isn’t the lower dimension just the skin of the higher dimension? From a higher dimension, the lower dimension is visible in its entirety.


Another example is the “perspective” used in sketching: through certain imaging principles, one can see parts of an object that are occluded. Of course, this is not seeing them in reality. If it were real seeing, then this “perspective” would be crossing dimensions.

Then consider Sun Wukong in Journey to the West drawing a circle to protect Tang Sanzang. In two-dimensional space, this circle can completely protect Tang Sanzang. But in three-dimensional space, one only needs to jump out of the circle to escape Wukong’s constraint. In three-dimensional space, to protect someone, you need to enclose them in a sealed space. But if this person were from four-dimensional space, then they could also easily jump out of this four-dimensional space. This is why people in three-dimensional space cannot understand “walking through walls,” while people in four-dimensional space could do it very easily.


## Do Transformers Really Not Exist?


![](http://upload-images.jianshu.io/upload_images/1194012-da866af91bb3a209.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In the three-dimensional space we live in, there are not many organisms that can continuously change their own form. In the three-dimensional world, very few things can transform like Transformers, especially transformations from the inside out. So in a high-dimensional world, do things like Transformers exist?

The answer is that there may not be many within the same dimension, but there are many across spatial dimensions.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-ef3ad4007f2458b2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


For example, how do two-dimensional objects understand a cube or polyhedron in three-dimensional space?

Consider the example of a hyperbola:

![](http://upload-images.jianshu.io/upload_images/1194012-35158cb898435c4e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Two inverted cones are placed tip to tip. When a plane cuts through them, the curve left by the three-dimensional object on that plane is called a conic section. Depending on the direction in which the surface is cut, different conic sections can be formed: circles, parabolas, hyperbolas, and ellipses.

In a two-dimensional world, one can only recognize these different kinds of conic sections. But in a three-dimensional world, we can understand that they are two cones.

![](http://upload-images.jianshu.io/upload_images/1194012-b7c3b73c271e81af.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The figure above also clearly shows that when an object in high-dimensional space has different cross-sections on a plane, the displayed shapes are also different.


Now let’s extend this to four-dimensional space. If an object in four-dimensional space is continuously sliced by three-dimensional space, wouldn’t the three-dimensional bodies it leaves in three-dimensional space keep changing?

So the reason we cannot understand Transformers is that we are in a lower-dimensional space. When a higher-dimensional object is sliced by a lower-dimensional space, a Transformer-like phenomenon occurs.


## Can Time Really Not Be Reversed?


![](http://upload-images.jianshu.io/upload_images/1194012-f28578499b050c7f.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

When I was a child, I often thought about this question: can time really not be reversed? Can a broken mirror really never be made whole again? To explain this clearly, we must first discuss the four-dimensional spacetime we currently inhabit.

In Einstein’s general relativity, four-dimensional spacetime is discussed: three dimensions of space plus one dimension of time. A person’s life is like a timeline, from birth to old age. In four-dimensional spacetime, a person cannot return to the past or go back to childhood.


So how do we define spacetime?

## How to Describe High-Dimensional Spacetime

At the beginning of the article, we used coordinate axes and spatial partitioning to divide high-dimensional space, and extended the idea to n-dimensional space.

Here we switch perspectives: starting from low-dimensional spacetime, we extend to n-dimensional spacetime using a probabilistic viewpoint.

First look at one-dimensional space: two points can form a line. When infinitely many lines cover a layer, it becomes two-dimensional space. So many lines fill all possibilities. Therefore one dimension has only length, with no width or height (depth).

In two-dimensional space, there are surfaces one after another. When infinitely many surfaces fill a space, it becomes three-dimensional space. These many surfaces also fill all possibilities of space. Two-dimensional space therefore has length and width, but no height (depth).

Everyone is familiar with three-dimensional space, so there is no need to elaborate. Things in three-dimensional space all have length, width, and height.


In four-dimensional spacetime, there is one more dimension of time than in three-dimensional space. Still using the previous probabilistic approach to define four-dimensional spacetime, the extra time dimension runs from the creation of an object to its final extinction. For a person, this is one lifetime. The time of this lifetime fills all the activities a person can possibly do in life and represents all possibilities.


![](http://upload-images.jianshu.io/upload_images/1194012-1f313cd65476dbfe.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Here there is the concept of parallel universes. Over the span of a person’s life, they make many choices, and these choices change the future development of their life. Every choice has its own possibility. If there are n choices, there are n outcomes. As each outcome continues to develop, it may lead to a different life. The same timeline may simultaneously correspond to n possibilities. In a game, this is equivalent to having n main storylines, while each game character can choose only one of them.


![](http://upload-images.jianshu.io/upload_images/1194012-c2b3f5b4103d1463.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Of course, each choice is not necessarily binary. There can also be multiple choices. The outcomes caused by multiple choices will also differ. For example, choosing to pursue graduate study abroad, finding a foreign girlfriend, and buying a house overseas. The accumulation of choices across multiple dimensions affects the future. It is also possible that by studying hard in childhood, getting into a prestigious school, and growing up, one lives the life of a winner.


In quantum theory, ultrafine particles make up the entire world. Various possibilities, as waves, weaken until they become a definite point. As we continuously make choices in life, we also continuously weaken these waves. Once all choices have been made, a point is determined, and that point is the final result.


So many main storylines in a game can also form a surface. This surface is a two-dimensional surface, though of course it is a special one: the lines inside it are all timelines. This forms five-dimensional spacetime.


Now let’s return to the question we discussed earlier: whether time can be reversed.

We know that if a surface is distorted, points that were originally far apart can be brought very close together.

This is also the idea behind a wormhole. If you travel along the surface, it takes many light-years, but if you pass through the wormhole, you can immediately reach the other side.

![](http://upload-images.jianshu.io/upload_images/1194012-8a658e7a5a83670a.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The phenomenon above can be summarized as follows: an object one dimension lower can be distorted to quickly connect things that were originally far apart.

Then in six-dimensional spacetime, if we distort five-dimensional spacetime and bring the current life and the time of birth together, we can return to the past, and time is effectively reversed!


So time reversal may be achievable in six-dimensional spacetime!


In six-dimensional spacetime, treat all these possibilities as a point. If these points then fill all possibilities, seven-dimensional spacetime is obtained. So what is seven-dimensional spacetime? What is its meaning?


The points in seven-dimensional spacetime represent all possibilities of the universe; each is an infinite point.

What do all possibilities of the universe refer to?

![](http://upload-images.jianshu.io/upload_images/1194012-6b4262597cf568f4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

This must begin with the Big Bang. The Big Bang produced all things. The universe also has a lifetime, and by the time it reaches its end, it will also contain various possibilities.


When the points in seven-dimensional spacetime fill all possibilities, eight-dimensional spacetime is obtained. What, then, is the meaning of the points in eight-dimensional spacetime?

The points in seven-dimensional spacetime represent all possibilities of the universe. Then in eight-dimensional spacetime, there are many other points. What do they mean?

These points may actually be different infinite possibilities produced by different Big Bangs. Different initial conditions lead, after the explosion, to different gravity and different speeds of light.


If we continue distorting eight-dimensional spacetime, we obtain nine-dimensional spacetime.


Now let’s step back and summarize the definition of spacetime.

Starting from one dimension: starting from a point, two points form a line, which is one-dimensional. Lines then become a surface, becoming two-dimensional. Surfaces then accumulate to become three-dimensional.

After three dimensions, four-dimensional spacetime becomes a point in time. Two points form a line, except that this line is a timeline. This becomes five-dimensional spacetime. Five-dimensional spacetime then becomes six-dimensional through accumulation and distortion.

Seven-dimensional spacetime is again a point, and this point represents all possibilities of a universe. Connecting two such infinite points represents possibilities within different infinities generated by different possible universes. This becomes eight-dimensional spacetime. Eight-dimensional spacetime then becomes nine-dimensional spacetime through accumulation and distortion.

Then in ten-dimensional spacetime, it becomes a point again. This point must represent all possible infinite points of all possible timelines in all possible universes.


However, this point seems to no longer exist.

In superstring theory, the vibrating superstrings in ten-dimensional spacetime are precisely the particles smaller than atoms that create our universe and other universes. In other words, ten-dimensional spacetime contains all, all, all possibilities.


At this point, the article is nearing its end.

Finally, let me pose two questions.

Can Euclidean high-dimensional space be “compressed”? Can n-dimensional space be reduced to one-dimensional space?  
Can the time dimension in the high-dimensional spacetime of Einstein’s general relativity be “compressed”? Can n-dimensional spacetime be reduced to four-dimensional spacetime or an even lower-dimensional spacetime?


------------------------------------------------------

Spatial Search Series:

[Understanding n-Dimensional Space and n-Dimensional Spacetime](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/n-dimensional_space_and_n-dimensional_space-time.md)  
[Efficient Multidimensional Spatial Point Indexing Algorithms — Geohash and Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_spatial_search.md)  
[How Is CellID Generated in Google S2?](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_CellID.md)     
[Finding the LCA (Lowest Common Ancestor) in a Quadtree in Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_lowest_common_ancestor.md)  
[The Magical De Bruijn Sequence](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_De_Bruijn.md)  
[How to Find Neighbors on a Hilbert Curve in a Quadtree?](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_Hilbert_neighbor.md)

------------------------------------------------------

Reference:  

[Interpreting the Mysterious Four-Dimensional Space](http://v.youku.com/v_show/id_XMTc3ODM4MTE2OA==.html?spm=a2h0j.8191423.module_basic_relation.5~5!2~5~5!6~5!2~1~3~A)  
[The Evolution from One-Dimensional Space to Ten-Dimensional Space](http://v.youku.com/v_show/id_XNTYzNzQ4OTY0.html?spm=a2h0k.8191407.0.0&from=s1.8-1-1.2)

> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/n\-dimensional\_space\_and\_n\-dimensional\_space-time/](https://halfrost.com/n-dimensional_space_and_n-dimensional_space-time/)