+++
author = "一缕殇流化隐半边冰霜"
categories = ["Machine Learning", "AI"]
date = 2018-03-22T07:56:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/69_5.png"
slug = "octave_matlab_tutorial"
tags = ["Machine Learning", "AI"]
title = "Octave Matlab 教程"

+++


>由于 Ghost 博客对 LateX 的识别语法和标准的 LateX 语法有差异，为了更加通用性，所以以下文章中 LateX 公式可能出现乱码，如果出现乱码，不嫌弃的话可以在笔者的 [Github](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/contents.md) 上看这篇无乱码的文章。笔者有空会修复这个乱码问题的。请见谅。
>
> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)  
> Follow: [halfrost · GitHub](https://github.com/halfrost)  
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Octave\_Matlab\_Tutorial.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Octave_Matlab_Tutorial.ipynb)


## 一. Basic Operations 基本操作

在 matlab 中，%是注释符号。基础的数学运算有以下这些：

```c
1 + 2   %加
5 - 6   %减
7 * 4   %乘
9 / 3   %除
6 ^ 4   %幂指数
log(20) %对数运算
exp(30) %指数运算
abs(-2) %绝对值运算

```



### 1. 逻辑运算：




```c

1 == 2             %判断是否相等
ans = 0            %false
--------------------------------------------------------------------------------------------
1 ~= 2             % ~= 是 ！= 的意思，判断是否不相等
ans = 1            %True 
--------------------------------------------------------------------------------------------
1 && 0             %逻辑 AND （和运算）
ans = 0
--------------------------------------------------------------------------------------------
1 || 0             %逻辑 OR（或运算）
ans = 1            
--------------------------------------------------------------------------------------------
xor(1,0)           %异或运算
ans = 1 
--------------------------------------------------------------------------------------------

```


### 2. 更换行首提示符

```c

PS1('>>');   %单引号内就是待替换的行首提示符

```

### 3. 变量赋值：

```c

a = 3        % 赋值数字
a = 3；      % 假如不想让其输出可以在后面加上分号（；）
b = 'Hello world'；   %赋值字符串
--------------------------------------------------------------------------------------------
disp(a)
disp(sprintf('2 decimals :%0.2f',a))   %sprintf打印格式化字符串
--------------------------------------------------------------------------------------------
format long   % 让接下来的字符串显示默认的位数
a

format short  % 让接下来的字符串小数点后面打印少量的位数
a
--------------------------------------------------------------------------------------------

```


### 4. 向量和矩阵：


```c

A = [1 2;3 4;5 6;] %创建矩阵变量，分号的意思就是换行到下一行
A =

   1   2
   3   4
   5   6
 
B = [1 2 3]  %创建向量
B =

   1   2   3
--------------------------------------------------------------------------------------------

v = 1:0.1:2    % a:x:b 表示[a,b]区间，x表示递增步长
v =
    1.0000    1.1000    1.2000    1.3000    1.4000    1.5000    1.6000    1.7000    1.8000    1.9000    2.0000

--------------------------------------------------------------------------------------------

ones(2,3)   %生成2*3的元素都为1的矩阵
ans =
     1     1     1
     1     1     1

%如果想生成2*3的元素都为2的矩阵，当然不是用 twos(2,3),而是用下面的方式

2*ones(2,3)
ans =

   2   2   2
   2   2   2
   
%与 ones 相同的快捷命令是 zeros
--------------------------------------------------------------------------------------------

zeros(1,3)  %生成1*3的零矩阵
ans =
     0     0     0
--------------------------------------------------------------------------------------------     

rand(1,3)  %生成1*3的随机数矩阵
ans =

   0.960762   0.089159   0.384507
--------------------------------------------------------------------------------------------   
eye(2,3)   % 生成2*3的单位矩阵
ans =
     1     0     0
     0     1     0
--------------------------------------------------------------------------------------------     
eye(3)     % 生成3*3的单位矩阵
ans =
     1     0     0
     0     1     0
     0     0     1
--------------------------------------------------------------------------------------------

```

### 5. 帮助函数：

```c

help eye  % help 后面跟一个命令名字，就会显示出这个命令的详细用法


```



------------------------------------------------------

## 二. Moving Data Around

### 1. 矩阵计算：


```c

A = [1,2; 3,4; 5,6;];
size(A)           %计算矩阵的维度大小
ans =
     3     2
--------------------------------------------------------------------------------------------

size(A,1)         %显示该矩阵的行数，1代表返回行数
ans =
     3
size(A,2)         %显示该矩阵的列数，2代表返回列数
ans =
     2
--------------------------------------------------------------------------------------------

v = [1,2,3,4]; 
length(v)         % 计算向量的最大维度的大小，length 通常对向量使用，而不对矩阵使用
ans =
     4

--------------------------------------------------------------------------------------------


```



### 2. 读取和存储文件数据：


```c

load xxx               %xxx为当前路径下的文件名
load ('xxx')           %以字符串的形式加载
v = xxx(1:10)          %建立向量v，元素分别为xxx文件内1~10的数据

--------------------------------------------------------------------------------------------

save xxx.mat V         %将当前的数据存储存储到文件中，并且变量名为 V
save xxx.txt V -ascii  %将当前的数据存储存储到ascii编码的文本文档中

```

### 3. 显示命令：


```c

pwd              %显示当前路径
ls               %显示当前路径的文件夹
cd 'path'        %打开该路径
who              %在当前内存中存储的所有变量
whos             %更详细地显示变量的名称、维度和占用多少内存空间和数据类型
clear            %清除所有变量
addpath('path')  %将路径添加到当前搜索处


```

### 4. 矩阵索引操作：


```c

A = [1,2; 3,4; 5,6;];

A(3,2)   %索引矩阵第1行第2列的元素
ans =
     6
--------------------------------------------------------------------------------------------

A(2,:)   %索引矩阵第2行所有元素,冒号表示该行或者该列的所有元素
ans =
     3     4
A(:,2)   %索引矩阵第2列所有元素
ans =
     2
     4
     6
--------------------------------------------------------------------------------------------

A([1 3],:)  %索引矩阵第1行和第3行所有元素
ans =
     1     2
     5     6
--------------------------------------------------------------------------------------------
A(:,2) = [10;11;12]  %将A的第二列用右边的向量替代
ans =
     1     10
     3     11
     5     12
--------------------------------------------------------------------------------------------

A = [A,[100;101;102]] %加入一列新的向量
A =
     1     2     100
     3     4     101
     5     6     102
--------------------------------------------------------------------------------------------
          
A(:)    %将矩阵A的元素变成列向量
ans =
     1
     3
     5
     2
     4
     6
     100
     101
     102
     
--------------------------------------------------------------------------------------------

A = [1,2;3,4];           %合并矩阵，A在左边，B在右边
B = [4,5;6,7];
C = [A B]                %等价于 C = [A,B]
C =
     1     2     4     5
     3     4     6     7
     
C = [A;B]                %合并矩阵，A在上边，B在下边
C =
     1     2
     3     4
     4     5
     6     7     
  
--------------------------------------------------------------------------------------------


```




------------------------------------------------------

## 三. Computing on Data


### 1. 矩阵计算：

```c


A*B                    %矩阵相乘
A.*B                   %矩阵对应元素相乘（两个矩阵需是相同维度）
A.^2                   %矩阵每个元素作平方处理
1./A                   %矩阵每个元素求倒数
log(A)                 %对矩阵每个元素求对数
exp(A)                 %对矩阵每个元素求以e为底，元素为指数的幂运算
abs(A)                 %求矩阵每个元素的绝对值
--------------------------------------------------------------------------------------------
A + ones(length(A),1)  %A中每个元素都加一
A + 1                  %A中每个元素都加一
--------------------------------------------------------------------------------------------
A'                     %A的转置矩阵
--------------------------------------------------------------------------------------------
A < 3                  %A中每个元素都和3进行比较，0为假，1为真
find(A<3)              %查找A中所有小于3的元素，并返回它们的索引
[r,c] = find(A>=7)     %r，c分别表示A矩阵中元素大于7的行和列
--------------------------------------------------------------------------------------------
A = magic(3)           %生成每一行每一列相加起来都是相等的矩阵，即矩阵幻方
A =
     8     1     6
     3     5     7
     4     9     2
--------------------------------------------------------------------------------------------

sum(A)                 %A中所有元素的和
prod(A)                %A中所有元素的积
floor(A)               %A中元素向下取整
ceil(A)                %A中元素向上取整
rand(3)                %生成3*3随机矩阵
max(A,[],1)            %A中每列的最大值，1表示从A的列去取值
max(A,[],2)            %A中每行的最大值，2表示从A的行去取值
max(A)                 %默认是A每列的最大值
max(max(A))            %A中所有元素的最大值
max(A(:))              %A中所有元素的最大值(先将A变成列向量，再求出最大值)
sum(A,1)               %求A每列的和
sum(A,2)               %求A每行的和
eye(9)                 %构造9*9单位矩阵
flipud(A)              %矩阵垂直翻转
pinv(A)                %A的伪逆矩阵(pseudo inverse)

--------------------------------------------------------------------------------------------

```




------------------------------------------------------

## 四. Plotting Data


### 1. 画图：


```c

t = [0:0.01:0.98];
y1 = sin(2*pi*4*t);
y2 = cos(2*pi*4*t);
plot(t,y1);
hold on;                    %在原来的图像中画图
plot(t,y2,'r');
xlabel('time');             %X轴单位
ylabel('value');            %Y轴单位
legend('sin','cos');        %将两条曲线表示出来
title('myplot');            %加入标题
print  -dpng 'myplot.png';  %输出图片为png格式
close                       %关闭


```

![](https://img.halfrost.com/Blog/ArticleImage/69_1.png)


```c


figure(1);plot(t,y1);   %分开画图
figure(2);plot(t,y2);

subplot(1,2,1);         %将图像分为1*2的格子，使用第1个
plot(t,y1);
subplot(1,2,2);         %将图像分为1*2的格子，使用第2个
plot(t,y2);
axis([0.5 1 -1 1]);     %改变轴的刻度 x轴变为[0.5,1] y轴变为[-1,1]
clf;                    %清除一幅图像

```

![](https://img.halfrost.com/Blog/ArticleImage/69_2.png)



```c

A = magic(5);
imagesc(A)                                    %生成矩阵的彩色格图，不同颜色对应不同的值
imagesc(A)， colorbar, colormap gray;         %增加灰度分布图和颜色条



```


![](https://img.halfrost.com/Blog/ArticleImage/69_3.png)



------------------------------------------------------

## 五. Control Statements: for, while, if statement

### 1. 循环语句

```c

 v = zeros(5,1);
for i = 1:5,        %for语句
    v(i) = 2^i;
end;                %以end为结尾标志
ans:
v =
     2
     4
     8
    16
    32
    
--------------------------------------------------------------------------------------------    
    
i = 1；
while i <= 3;       %while语句
      v(i) = 100;
      i = i + 1;
end;
ans:
v =
    100
    100
    100
    16
    32
    
    
--------------------------------------------------------------------------------------------

i = 1 ;
while true,
      v(i) = 999;
      i = i + 1;
      if i==6,
         break;     %break语句
      end;
end;

--------------------------------------------------------------------------------------------


if v(1)== 1,        %if-else语句
   disp('The value is one');
elseif v(1) == 2,
   disp('The value is two'); 
else 
   disp('The value is not one or two');
end;

--------------------------------------------------------------------------------------------

```





------------------------------------------------------


## 六. Octave/Matlab Tutorial 测试



### 1. Question 1


Suppose I first execute the following in Octave/Matlab:

```c

A = [1 2; 3 4; 5 6];  
B = [1 2 3; 4 5 6];

```

Which of the following are then valid commands? Check all that apply. (Hint: A' denotes the transpose of A.)


A. C = A' + B;  
B. C = B * A;  
C. C = A + B;  
D. C = B' * A;  

解答：A、B  

相同维度的矩阵才能够相加。相乘的条件是$A*B$（A的列=B的行）

### 2. Question 2


$ Let\;A= \begin{bmatrix}
 16& 2 & 3 & 13\\ 
 5& 11 & 10 & 8\\ 
 9&  7&  6&12 \\ 
 4&  14& 15 & 1
\end{bmatrix}$

Which of the following indexing expressions gives $ B= \begin{bmatrix}
 16& 2 \\ 
 5& 11 \\ 
 9&  7 \\ 
 4&  14
\end{bmatrix}$? Check all that apply.


A. B = A(:, 1:2);  
B. B = A(1:4, 1:2);  
C. B = A(:, 0:2);  
D. B = A(0:4, 0:2);  

解答： A、B  

$B = A(:, 1:2);$   先取出 A 的所有行，再取出 1，2 列
$B = A(1:4, 1:2);$ 先取出 A 的 1-4行，再取出 1，2 列

### 3. Question 3

Let A be a 10x10 matrix and x be a 10-element vector. Your friend wants to compute the product Ax and writes the following code:

```c

v = zeros(10, 1);
for i = 1:10
  for j = 1:10
    v(i) = v(i) + A(i, j) * x(j);
  end
end

```

How would you vectorize this code to run without any FOR loops? Check all that apply.


A. v = A * x;  
B. v = Ax;  
C. v = A .* x;  
D. v = sum (A * x);  

解答： A  

将 for 循环矢量化



### 4. Question 4

Say you have two column vectors v and w, each with 7 elements (i.e., they have dimensions 7x1). Consider the following code:


```c

z = 0;
for i = 1:7
  z = z + v(i) * w(i)
end


```

Which of the following vectorizations correctly compute z? Check all that apply.


A. z = sum (v .* w);  
B. z = v' * w;  
C. z = v * w';  
D. z = v .* w;  

解答：A、B  

最后的结果是一个实数，通过这一点就可以看哪个选项是 $1*1$ 的。



### 5. Question 5

In Octave/Matlab, many functions work on single numbers, vectors, and matrices. For example, the sin function when applied to a matrix will return a new matrix with the sin of each element. But you have to be careful, as certain functions have different behavior. Suppose you have an 7x7 matrix X. You want to compute the log of every element, the square of every element, add 1 to every element, and divide every element by 4. You will store the results in four matrices, A,B,C,D. One way to do so is the following code:

```c

for i = 1:7
  for j = 1:7
    A(i, j) = log(X(i, j));
    B(i, j) = X(i, j) ^ 2;
    C(i, j) = X(i, j) + 1;
    D(i, j) = X(i, j) / 4;
  end
end

```
Which of the following correctly compute A,B,C, or D? Check all that apply.


A. C = X + 1;  
B. D = X / 4;  
C. A = log (X);  
D. B = X ^ 2;  

解答： A、B、C

最后一个选项应该是 $B = X. \^{} 2;$ (点^2)


------------------------------------------------------


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Octave\_Matlab\_Tutorial.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Octave_Matlab_Tutorial.ipynb)

