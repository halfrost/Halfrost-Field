# How Does Google S2 Index Data Quickly?

S2 is designed to have good performance on large geographic datasets. Most operations are accelerated using an in-memory edge index data structure (S2ShapeIndex). For example if you have a million polygons, finding the polygon(s) that contain a given point typically takes a few hundred nanoseconds. Similarly it is fast to find objects that are near each other, such as finding all the places of business near a given road, or all the roads near a given location.

S2 is designed to deliver good performance on large geographic datasets. Most operations are accelerated using an in-memory edge index data structure (S2ShapeIndex). For example, if you have a million polygons, finding the polygon(s) that contain a given point typically takes a few hundred nanoseconds. Similarly, it is fast to find objects that are near each other, such as all businesses near a given road or all roads near a given location.


------------------------------------------------------

Spatial search article series:

[Understanding n-dimensional space and n-dimensional spacetime](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/n-dimensional_space_and_n-dimensional_space-time.md)  
[Efficient Multidimensional Spatial Point Indexing Algorithms — Geohash and Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_spatial_search.md)  
[How Is a CellID Generated in Google S2?](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_CellID.md)     
[Finding the LCA (Lowest Common Ancestor) in a Quadtree in Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_lowest_common_ancestor.md)  
[The Magical De Bruijn Sequence](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_De_Bruijn.md)  
[How to Find Hilbert Curve Neighbors on a Quadtree?](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_Hilbert_neighbor.md)  
[How to Solve the Optimal Spatial Covering Problem?](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_regionCoverer.md)


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_s2\_regionCoverer/](https://halfrost.com/go_s2_Hilbert_regionCoverer/)