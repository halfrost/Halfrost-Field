+++
author = "一缕殇流化隐半边冰霜"
categories = ["dimensional"]
date = 2017-09-30T10:01:10Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/60_0.png"
slug = "n-dimensional_space_and_n-dimensional_space-time"
tags = ["dimensional"]
title = "How to Understand n-Dimensional Space and n-Dimensional Spacetime"

+++


## Preface

Some readers may be wondering why I would suddenly publish an article that seems completely unrelated to technology. In fact, this topic is something I branched into while researching spatiotemporal search. After reading some materials, I deepened my understanding of n-dimensional space and n-dimensional spacetime, so I summarized it here. If you have never encountered this subject before, it will probably feel unfamiliar at first. If you are a mathematics major or work professionally in this area, please feel free to point out any mistakes in the article so we can discuss them together.


## Space and Spacetime

First, space and spacetime are two concepts that are often confused. In fact, they are different.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/60_1.png'>
</p>


Einstein’s general theory of relativity mentions four-dimensional space, referring to three spatial dimensions plus one time dimension. This is not the same as the concept of multidimensional space in mathematics. In reality, the time dimension is independent of the spatial dimensions. One-dimensional space can also have time, and two-dimensional space can also have time. Multidimensional spaces all have time. However, the four-dimensional space mentioned in general relativity is actually four-dimensional spacetime composed of three spatial dimensions plus one time dimension.

After Riemannian geometry, higher-dimensional geometry developed for many years. In superstring theory, the universe has nine spatial dimensions plus one time dimension. In M-theory, the universe is eleven-dimensional spacetime consisting of ten spatial dimensions plus one time dimension.


## How to Describe the Partitioning of Higher-Dimensional Space


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/60_2.png'>
</p>


In two-dimensional space, two perpendicular intersecting straight lines can form the X-axis and the Y-axis. In three-dimensional space, three mutually perpendicular intersecting directions form the X-axis, Y-axis, and Z-axis. The third line passes through the intersection point in the two-dimensional space, namely the origin, and is perpendicular to the two-dimensional space. Similarly, in four-dimensional space, there will likewise be a line that passes through the intersection point of the three lines in three-dimensional space, the origin of the three-dimensional coordinate axes, and is perpendicular to the previous three lines. This line in four-dimensional space that is perpendicular to three-dimensional space cannot be represented in three-dimensional space, nor can it be drawn. It lies in four-dimensional space inside the coordinate origin.

So how can four-dimensional space be intuitively related to three-dimensional space? After all, three-dimensional space is the spatial structure we humans are most familiar with. We know that three-dimensional space has an X-axis, Y-axis, and Z-axis. These three axes can divide the entire space into 6 faces: up and down, left and right, front and back. Then how else can four-dimensional space partition space? Compared with three-dimensional space, it has two additional directions: inside and outside. The “upper side” on the inside and the “upper side” on the outside are different spaces, even though in three-dimensional space they are both “above.”

Similarly, if we continue extending these ideas to higher-dimensional space, then there must exist a line that is perpendicular to n-1 lines, and those n-1 lines are also mutually perpendicular and intersecting.


The above is a way to describe multidimensional space from the perspective of spatial partitioning.


## The Forms of Objects in Higher-Dimensional Space


In higher-dimensional space, objects are highly abstract and may be impossible to draw graphically. However, we can understand higher dimensions through lower-dimensional spaces that we can comprehend. This requires studying how objects in higher-dimensional space manifest in lower-dimensional space.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/60_3.png'>
</p>


In two-dimensional space, an equilateral triangle has three vertices. Suppose all side lengths are equal to 1. If there exists a fourth point in space such that its distance to all three vertices is also 1, then this point must not exist in two-dimensional space, and must exist in three-dimensional space (the mathematical proof is omitted here; it is too difficult, but interested readers can try proving it). If these four points are all connected in three-dimensional space, they form a regular tetrahedron in three dimensions.

Similarly, if there is a fifth point whose distance to this three-dimensional regular tetrahedron is also 1, then that point must exist in four-dimensional space, and together with the three-dimensional regular tetrahedron it forms a four-dimensional hypertetrahedron.

A hypertetrahedron already exceeds the dimensionality of our everyday life, so we cannot draw its shape in three-dimensional space. But we can observe it in three-dimensional space by means of projection.


Let’s first review how a three-dimensional regular tetrahedron is produced. Because it starts from an equilateral triangle, the distance from the orthocenter of the equilateral triangle to its three vertices must be equal. Then we take this incenter and pull it into three-dimensional space until its distance to the other three vertices is 1. In this way, a three-dimensional regular tetrahedron is generated. The three obtuse triangles inside, divided by the orthocenter, follow the orthocenter as it is pulled outward and become the 3 outer faces of the regular tetrahedron.


Similarly, in a three-dimensional regular tetrahedron, take its orthocenter. The distances from the orthocenter to the four vertices are all equal. This orthocenter divides the regular tetrahedron internally into 4 flattened tetrahedra. If the orthocenter is then pulled into four-dimensional space to become the fifth vertex, it becomes a hypertetrahedron. The 4 flattened tetrahedra divided internally also evolve into the four outer surfaces of the hypertetrahedron.

A four-dimensional hypertetrahedron is a hyper-body composed of 5 vertices, 10 edges, 10 triangular faces, and 5 tetrahedra. It cannot be described using three-dimensional space.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/60_4.png'>
</p>


A cube is a familiar three-dimensional object. So what does a cube become in four-dimensional space?


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/60_5.png'>
</p>


The figure above is a cube in four-dimensional space, called a hypercube.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/60_6.png'>
</p>


The figure above shows that every edge of the four-dimensional cube has equal length, and also shows how the cubes are connected to each other. The simplest way to construct a hypercube is to take 2 cubes and connect each of the 8 vertices of one cube to the corresponding vertex of the other hypercube.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/60_7.png'>
</p>


The figure above reveals that a hypercube is essentially obtained by combining 2 cubes and connecting their corresponding vertices.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/60_8.png'>
</p>


The figure above arranges each vertex by the length of the path along edges starting from the lowest vertex. If we want to use the hypercube as the basis for connecting different processors in [parallel computing](https://zh.wikipedia.org/wiki/%E5%B9%B6%E8%A1%8C%E8%AE%A1%E7%AE%97) [network topology](https://zh.wikipedia.org/wiki/%E7%BD%91%E7%BB%9C%E6%8B%93%E6%89%91), these images are very useful. Between any two vertices in a hypercube, there are at most 4 different paths, and many of these paths are equivalent. A hypercube is also a [bipartite graph](https://zh.wikipedia.org/wiki/%E4%BA%8C%E5%88%86%E5%9B%BE), just like a square and a cube.

The following two figures are perspective projections.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/60_9.gif'>
</p>


The figure above is the [perspective projection](https://zh.wikipedia.org/wiki/%E9%80%8F%E8%A7%86%E6%8A%95%E5%BD%B1) of a tesseract during a [simple rotation](https://zh.wikipedia.org/w/index.php?title=%E5%8D%95%E6%97%8B%E8%BD%AC&action=edit&redlink=1) around a plane that cuts through the figure from front-left to back-right, and from top to bottom.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/60_10.gif'>
</p>


The figure above is the perspective projection of a tesseract during a [double rotation](https://zh.wikipedia.org/w/index.php?title=%E5%8F%8C%E6%97%8B%E8%BD%AC&action=edit&redlink=1) around two mutually [orthogonal](https://zh.wikipedia.org/wiki/%E6%AD%A3%E4%BA%A4) planes in four-dimensional space.

Four-dimensional space and the spaces above belong to higher-dimensional models. Higher-dimensional models are also divided into mathematical and physical concepts.

In mathematics, multidimensionality has many models. In theory, the number of dimensions can be very high. There are many models. However, very few satisfy commutative invariance, so some people believe that four-dimensional space is the physical upper limit. Others, however, believe that physics with higher dimensions may exist. Thinking about this is intellectually beneficial, because it is constrained only by mathematical conditions.

In physics, multidimensionality also has many models. In theory, the number of dimensions cannot be very high. To explain the finite but unbounded nature of the universe as a whole, multidimensionality must be introduced. Usually this is four-dimensional spacetime (a pair of relative constituent properties), though there are also some other finite and countable numbers of dimensions. There may not be many models that are physically valid. Thinking about this is very difficult, because it is constrained by physical phenomena.


## Do X-Ray Vision and Walking Through Walls Really Not Exist?


![](https://img.halfrost.com/Blog/ArticleImage/60_11.png)


The world as seen by an ant is almost two-dimensional. In its eyes, there is only length and width, but no height. Any three-dimensional object is just a “surface” to it, so it will crawl over it. Or consider a two-dimensional space: people living inside Along the River During the Qingming Festival would see only chaotic points, lines, and surfaces. The people in the painting would have no way to form a complete understanding of the world in the entire painting. But we, living in three-dimensional space, can see the entire world in the painting at a glance. Similarly, we who live in three-dimensional space cannot see a three-dimensional object completely at a glance. For example, with a skyscraper in front of us, if we want to see all four sides plus the roof and the bottom, we cannot do so at a glance; we have to walk around it. But in four-dimensional space, a creature in four-dimensional space looking at a skyscraper could actually see what it looks like in a single glance.

This leads to a conclusion that may not be entirely correct: lower-dimensional space is nothing more than the skin of higher-dimensional space, because lower-dimensional space is what results when some dimension of higher-dimensional space collapses, degenerating into a “skin.”


Think back to the two-dimensional equilateral triangle, the three-dimensional regular tetrahedron, and the four-dimensional hypertetrahedron discussed earlier. Isn’t the lower dimension just the skin of the higher dimension? Looking at a lower dimension from a higher dimension, everything is laid bare.


For another example, consider “perspective” in sketching. Through certain imaging principles, one can see the parts of an object that are occluded. Of course, this is not literally seeing them. If it were truly seeing them, then this “perspective” would be crossing dimensions.

Now consider Sun Wukong drawing a circle to protect Tang Sanzang in Journey to the West. In two-dimensional space, this circle could completely protect Tang Sanzang. But in three-dimensional space, one only needs to gently jump out of the circle to escape Wukong’s constraint. In three-dimensional space, to protect a person, you need to enclose them in a closed space. But if that person is from four-dimensional space, then they can also jump out of this four-dimensional space very easily. This is why people in three-dimensional space cannot understand “walking through walls,” whereas people in four-dimensional space can do it quite easily.


## Do Transformers Really Not Exist?


![](https://img.halfrost.com/Blog/ArticleImage/60_12.png)


In the three-dimensional space we live in, there are not many organisms that can continuously change their own form. In the three-dimensional world, there are really not many things that can transform like Transformers, especially transformations from the inside out. So in the world of higher-dimensional space, do things like Transformers exist?

The answer is that within the same dimension, perhaps not many do; but across spatial dimensions, there are many.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/60_13.png'>
</p>


For example, for a cube or polyhedron in three-dimensional space, how do two-dimensional things understand them?

Take a hyperbola as an example:

![](https://img.halfrost.com/Blog/ArticleImage/60_14.png)


Place two inverted cones tip to tip. Use a plane to slice through them. The curve left by the three-dimensional object on that plane is what we call a conic section. When the cutting direction of the plane differs, different conic sections can be formed: circles, parabolas, hyperbolas, and ellipses.

In the two-dimensional world, one can only recognize these different conic sections. But in the three-dimensional world, we can understand that they are two cones.

![](https://img.halfrost.com/Blog/ArticleImage/60_15.png)
The figure above also clearly shows that objects in higher-dimensional space have different cross-sections on a plane, and therefore present different shapes.


Now let’s extend this to four-dimensional space. If an object in four-dimensional space is continuously sliced by three-dimensional space, wouldn’t the three-dimensional solids it leaves behind in three-dimensional space keep changing?

So the reason we cannot understand Transformers is that we are in a lower-dimensional space. When a higher-dimensional object is sliced by a lower-dimensional space, a Transformers-like phenomenon occurs.


## Can Time Really Not Be Reversed?


![](https://img.halfrost.com/Blog/ArticleImage/60_16.png)

When I was a child, I often thought about this question: can time really not be reversed? Can a broken mirror really never be made whole again? To explain this clearly, we must first talk about the four-dimensional spacetime we currently inhabit.

In Einstein’s general theory of relativity, four-dimensional spacetime refers to three spatial dimensions plus one time dimension. A person’s life is like a timeline, from birth to old age. In four-dimensional spacetime, people cannot return to the past or go back to their childhood.


So how do we define spacetime?

## How to Describe Higher-Dimensional Spacetime

At the beginning of the article, we used coordinate axes and spatial partitioning to divide higher-dimensional space, and then generalized it to n-dimensional space.

Here, let’s look at it from another perspective: starting from lower-dimensional spacetime, using a probability-theory view, and then generalizing it to n-dimensional spacetime.

First, consider one-dimensional space. Two points can form a line. When infinitely many lines fill an entire layer, it becomes two-dimensional space. So many lines fill all possibilities. Therefore, one dimension has only length, with no width or height (depth).

In two-dimensional space, there are individual surfaces. When countless surfaces fill a space, it becomes three-dimensional space. These many surfaces also fill all the possibilities in that space. Two-dimensional space has length and width, but no height (depth).

Everyone is familiar with three-dimensional space, so we will not elaborate further. Things in three-dimensional space all have length, width, and height.


In four-dimensional spacetime, there is one more dimension than three-dimensional space: time. Still using the probability-theory approach from before to define four-dimensional spacetime, the additional time dimension runs from the creation of an object to its eventual disappearance. For a person, that is a lifetime. The time of this lifetime fills all the activities a person can possibly do in their life, representing all possibilities.


![](https://img.halfrost.com/Blog/ArticleImage/60_17.png)

Here we encounter the concept of parallel universes. Over the course of a person’s lifetime, they make many choices, and these choices change the development of the rest of their life. Every choice has its own possibilities. If there are n choices, there are n outcomes. If each outcome continues to develop, it may lead to a different life. The same timeline may simultaneously correspond to n possibilities. In a game, this is equivalent to having n main storylines, while each game character can choose only one of them.


![](https://img.halfrost.com/Blog/ArticleImage/60_18.png)


Of course, not every choice is necessarily binary. There may also be multiple choices. The outcomes caused by multiple choices will also differ. For example, choosing to take the postgraduate entrance exam and study abroad, finding a foreign girlfriend, and buying a house overseas. Choices accumulated across multiple dimensions will affect the future. It is also possible that someone studies hard as a child, gets into a prestigious university, and grows up to live the life of a winner.


In quantum theory, tiny particles make up the entire world. Various possibilities, as waves, diminish until they collapse to a definite point. As we continuously make choices in life, we also continuously weaken these waves. Once all choices have been made, a point is determined, and that point is the final result.


So many main storylines in a game can also form a surface. This surface is a two-dimensional surface. Of course, it is a very special surface: all the lines inside it are timelines. This forms five-dimensional spacetime.


Now let’s return to the question we discussed earlier: can time be reversed?

We know that if a surface is distorted, points that were originally far apart can be made very close to each other.

A wormhole works on the same principle. If you travel along the surface, it may take many light-years, but if you pass through the wormhole, you can immediately reach the opposite side.

![](https://img.halfrost.com/Blog/ArticleImage/60_19.png)


The phenomenon above can be summarized as follows: lower-dimensional things can be distorted to quickly connect things that were originally far apart.

So in six-dimensional spacetime, if we distort five-dimensional spacetime and bring the current life and the moment of birth together, then we can return to the past. Time would effectively have been reversed!


Therefore, time reversal is possible in six-dimensional spacetime!


In six-dimensional spacetime, all of these possibilities are regarded as a point. Then if these points fill all possibilities, seven-dimensional spacetime is obtained. So what is seven-dimensional spacetime? What does it mean?


A point in seven-dimensional spacetime represents all possibilities of the universe; it is an infinite point.

What, then, do all the possibilities of the universe refer to?

![](https://img.halfrost.com/Blog/ArticleImage/60_20.png)

This starts with the Big Bang: the Big Bang gave rise to all things. The universe also has a life of its own, and by the time it reaches its end, it will also contain various possibilities.


When the points in seven-dimensional spacetime fill all possibilities, eight-dimensional spacetime is obtained. So what is the meaning of the points in eight-dimensional spacetime?

A point in seven-dimensional spacetime represents all possibilities of the universe. Then, in eight-dimensional spacetime, there are so many other points—what do they mean?

These points may in fact be different infinities of possibilities generated by different Big Bangs. Different initial conditions produce different gravity and different speeds of light after the explosion.


If we continue distorting eight-dimensional spacetime, we obtain nine-dimensional spacetime.


Now let’s go back and summarize the definition of spacetime.

Starting from one dimension, we begin with a point. Two points form a line, which is one-dimensional. A line then becomes a surface, forming two dimensions, and surfaces accumulate to become three dimensions.

After three dimensions, four-dimensional spacetime becomes a time point. Two points connect into a line, except this line is a timeline. This becomes five-dimensional spacetime. Five-dimensional spacetime then becomes six-dimensional through accumulation and distortion.

Seven-dimensional spacetime is again a point, and this point represents all possibilities of one universe. Connecting two such infinite points represents different infinities of possibilities generated by different possible universes. This becomes eight-dimensional spacetime. Eight-dimensional spacetime then becomes nine-dimensional spacetime through accumulation and distortion.

Then, in ten-dimensional spacetime, it becomes a point again. This point must represent all possible infinite points of all possible timelines in all possible universes.


However, this point seems to no longer exist.

In superstring theory, the vibrating superstrings in ten-dimensional spacetime are precisely the particles smaller than atoms that make up our universe and other universes. In other words, ten-dimensional spacetime contains every single possibility.


At this point, the article is nearing its end.

Finally, let me pose two questions.

Can Euclidean higher-dimensional space be “compressed”? Can n-dimensional space be reduced to one-dimensional space?  
Can the time dimension of higher-dimensional spacetime in Einstein’s general relativity be “compressed”? Can n-dimensional spacetime be reduced to four-dimensional spacetime, or even lower-dimensional spacetime?

------------------------------------------------------

Reference:  

[Interpreting the Mysterious Four-Dimensional Space](http://v.youku.com/v_show/id_XMTc3ODM4MTE2OA==.html?spm=a2h0j.8191423.module_basic_relation.5~5!2~5~5!6~5!2~1~3~A)  
[The Evolution from One-Dimensional Space to Ten-Dimensional Space](http://v.youku.com/v_show/id_XNTYzNzQ4OTY0.html?spm=a2h0k.8191407.0.0&from=s1.8-1-1.2)

> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/n\-dimensional\_space\_and\_n\-dimensional\_space-time/](https://halfrost.com/n-dimensional_space_and_n-dimensional_space-time/)