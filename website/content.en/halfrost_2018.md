+++
author = "一缕殇流化隐半边冰霜"
categories = ["星霜荏苒"]
date = 2019-02-10T00:02:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/123_0.png"
slug = "halfrost_2018"
tags = ["星霜荏苒"]
title = "【2018 Year-End Review】How to Think About Software Development?"

+++


## Preface

Since some readers are new to this series, I won’t repeat the origin story of the series title here. See [The Story Behind the Name "Time Elapse"](https://github.com/halfrost/Halfrost-Field/blob/master/contents/TimeElapse/start.md)

In this year’s recap, I mainly want to talk with readers about how to think about software development, and to answer the question I left at the end of last year’s year-end summary. This is also a fairly broad topic, and every developer has their own answer. Based on my own experience from just a few years in the industry, I’ll share my view. As a newcomer to development, my perspective may be shallow and perhaps laughably naive. Feedback is very welcome.

----------------------------------------------

## What Is Software Development?

![](https://img.halfrost.com/Blog/ArticleImage/123_15.png)

Software development is the process of requirements analysis, design, coding, testing, and bug fixing involved in creating or maintaining applications, frameworks, or application components. Software development is the process of writing and maintaining code. More broadly, **software development is a manifestation of human thought activity**.

Rather than calling software development “moving bricks,” it is better described as problem-solving ability and a reflection of intelligence. What you develop is not important; what matters is the angle from which you think about problems and your ability to solve them quickly. After using programming languages across frontend, backend, and client-side development, I’ve come to feel that merely being able to use a language is not a big deal. The key is how large a problem you can solve with a given language. Both frontend and backend have their corresponding job levels. At the same level, compensation differences between different development roles are not large. A higher or lower level reflects, to a greater extent, the strength of a person’s thinking ability. Moreover, in every domain and direction, reaching senior engineer level is not easy. Each field has its own roadmap, and going deep in any one domain requires 2–3 years of calm, focused work. It is extremely difficult for anyone to stay ahead continuously and remain at the top of the pyramid.

Broadly speaking, the language you use for development is merely your debut into the industry. As you go further, you will encounter many other languages. How to cultivate your thinking ability is what a software engineering professional needs to focus on. The gap between rookies and experts lies in the accumulation of effective time. It often happens that a rookie and an expert encounter the same problem at the same time—even an unfamiliar one—and the expert can still quickly identify the essence of the problem. After solving it, the expert may say that they found the breakthrough through “intuition.” But that intuition is valuable experience; it is exactly what rookies need time to accumulate. This “intuition” is not mysticism. It is a capability: the ability to solve problems quickly that comes from rich experience.

After going through development iterations across all three ends, when I look at client-side, frontend, and backend together, I find that their development processes and work content share many similarities.

![](https://img.halfrost.com/Blog/ArticleImage/123_16.png)

The development process is consistent across all three ends: review, scheduling, kickoff, standups, development, finalizing the final version, submitting for testing, gray release, and production release.

Each end has APM and performance monitoring requirements, though the architectural implementations differ. The focus of the three ends is different. Client-side and frontend focus more on customers: user experience, page load speed, and so on. Backend focuses more on services: service performance, availability, high concurrency, low latency, I/O read/write speed, multi-active architecture, cross-IDC deployment, and so on. Some readers may bring up the so-called contempt chain here. I don’t think there is any need to look down on other ends. Developers who do pure backend work are usually not very sensitive to graphics and pixels; asking them to implement frontend animations may be difficult. Developers who do pure frontend work may not be very familiar with backend architecture; asking them to design large-scale high-concurrency systems may be difficult. (Considering that some readers are full-stack developers and know all three ends very well, I’ve deliberately added the word “pure” here.) Asking a pure backend developer to write frontend code does not necessarily mean they can do it well; asking a pure client-side developer to write backend code does not necessarily mean they can do it well either. So each end has its own difficulties. We can learn from one another, but there is no need for contempt.

![](https://img.halfrost.com/Blog/ArticleImage/123_17.png)

In summary, in the narrow sense, software development is the process from implementing requirements to the final production release. In the broad sense, it is the process of solidifying and crystallizing human thought activity into software products. During software development, people continuously train their thinking and their ability to discover and solve problems.

----------------------------------------------

All right, that concludes my answer to this question. The logic of the following sections will differ from last year’s. I plan to write about some of the “major events” that happened this year, share some things I saw, heard, and thought about, and also say a few things that I’ve been holding in, with no other good opportunity to say them except in a year-end summary. Some are questions that friends around me or people in groups often discuss. I have my own views on these questions as well, so I’m writing them down. My answers may be completely wrong, but if readers gain something after reading this article, then its purpose will have been achieved.

## Embracing Change

![](https://img.halfrost.com/Blog/ArticleImage/123_1.png)

The question I was asked most over the past year was: “Your company was acquired—does that mean XXX is going to happen?” XXX included many things friends around me guessed at, such as mergers, layoffs, N+1 severance, resignations, and so on. From January 2018 to the announcement at the end of February that we had been acquired by Alibaba, a great many things did indeed happen inside the company, and the organizational structure changed significantly. After the acquisition, internal changes were also substantial. Of course, this was more or less standard procedure; after an acquisition, there are many resource-integration processes. Some people and things closely connected to me changed dramatically. Perhaps because normal post-New-Year personnel movement was happening, within one month many colleagues’ company notes in my WeChat contacts changed. Close “comrades-in-arms” who had worked overtime with me late into the night left me; comrades who had still been discussing problems with me at the bus stop in the middle of the night woke up the next day and told me they were leaving. I am someone who values relationships deeply. After all, we were one team. We had fought our way through together, built our “world” together, and forged an ironclad bond through shared hardship. To “break up” just like that genuinely felt bad. Once I learned the reasons for their departure, all I could do was sigh and wish them great success at their new companies. The atmosphere around me during that period was truly oppressive, so I went to Japan and tried hard to let everything go, following the direction of the blooming cherry blossoms and soaking in hot springs along the way. Of course, the things you try hardest to forget often become even more deeply etched in memory. Now, at the end of 2018, looking back on that period, the only real impact on me was emotional—the effect on friendships. There was basically no other impact. Organizational changes affected upper management the most, the “foreman” layer. For us bottom-level bricklayers and cement workers, the impact was not large. If you’re not honestly moving bricks, what are you thinking about so much?

There were also many changes in my own technical direction. At the beginning of the year, I planned to participate in an artificial intelligence-related project. So I read the Watermelon Book and watched some videos to get started with AI. Most of the introductory knowledge was relatively easy to understand; it was mostly advanced mathematics, linear algebra, and probability theory. During my postgraduate entrance exam preparation, I had reviewed all of these subjects thoroughly, so I hadn’t forgotten much and picked them back up quickly. Later, because of some organizational changes, I wasn’t able to participate in that project. In 2017, the hot technologies were artificial intelligence and blockchain. At the beginning of the year, I also read four introductory blockchain books on my kindle. The underlying technologies of blockchain are not entirely new; what is relatively novel is its design and philosophy. After finishing several introductory blockchain books, I became more interested in the underlying cryptographic technologies, so I picked up cryptography again and read three technical books related to it. Although I did not enter the blockchain industry, cryptography is part of the foundational knowledge of computer science, and it can be extended into many areas. People’s requirements for security are getting higher and higher; network security and information security are all inseparable from encryption. After joining a new project team in May, I set my KPI for the second half of the year, and my goals for that period became consistent and clear. I participated in a network-related project where performance was the top priority, and network latency was also my optimization focus. If HTTPS is slow, where might it be slow? Why is it slow? What does it have to do with the choice of cipher suite? Why can TLS 1.3 shorten the overall request time? Why does QUIC perform well in weak-network environments? How does a cellular network select a base station? What is signal fallback in cellular networks? I previously had only vague answers to these questions. After deeply participating in this project and gaining practical experience, I now have very concrete answers to all of them. After several rounds of optimization, the phased results were also recognized by the business side.

![](https://img.halfrost.com/Blog/ArticleImage/123_2.png)

For my learning and work summaries throughout 2018, see the Archive list on the blog. Looking back, my gains this year were passable overall, with substantial gains in networking-related areas. In a year full of change, I embraced change.

## Career Planning and the Pursuit of Technical Professionals

![](https://img.halfrost.com/Blog/ArticleImage/123_3.png)

Regarding career planning, I was once confused as well, and I asked quite a few senior people how they planned their own careers. I am no longer confused now.

To clarify your own career plan, you must first think through what you pursue as a technical professional. Once you know where your heart points and your goals are clear, formulating a career plan becomes very simple.

A newly graduated student who has just entered the software development industry will inevitably feel somewhat confused, not knowing what they want or how to walk the road ahead. A mentor once gave me this advice: “In the first five years after graduation (at most five years), I recommend trying as many development directions as possible, finding the direction you are truly interested in, and once you find it, lowering your head and drilling into it for 3–5 years.” This approach may be effective for students who feel lost. For new graduates who plan to enter a large company immediately after graduation, my advice is: your primary skill must be specialized. Your primary skill is the stepping stone into a large company. If your primary skill is not specialized enough, even ten additional skills will not help. Joining a large company is only the first step; your subsequent development depends on your own planning. On the premise of doing your own job well, use your spare time to study the directions that interest you.

>Definition of interest:  
>If you are merely following the crowd and learning the latest technologies, that is not genuine interest. I believe the definition of genuine interest is obsession. Some people forget to sleep while playing games; that is obsession with games. Obsession with technology may manifest as staying up all night reading books and writing code and forgetting to sleep (though of course, I do not advocate not sleeping).

After finding the direction you are truly interested in, you can start working hard to become TOP. Becoming top-tier in the field you are proficient in is the highest priority. In large companies, promotion evaluates your professionalism. No matter how broad your technical surface area is, if your depth has not reached the requirements of the next level, you cannot be promoted. Take me as an example: my mobile skills might be just slightly above passing, and I know a little frontend and backend—maybe 30 points each. In this situation, large companies might not even want me. Do not expect a large company to hire you so that one person can do the work of three people, because large companies are fully capable of hiring three people who each score 90 in their respective fields. In that case, being full-stack does not provide much advantage. Promotion in large companies still relies more on professional depth.

However, in your spare time, you can look at other languages and absorb their respective strengths. Before I came into contact with Go, I had almost no real feeling for coroutines. I had only heard of them, and I knew almost nothing about how coroutines schedule user-space execution. Why did Go design coroutines this way, and what problem was it trying to solve? Was Go the first to implement coroutines? Who was the first to implement coroutines? Can Swift implement coroutines? If not, why? Can OC implement them? How would they be implemented? These are all questions worth learning about and thinking through in daily study. Breadth of vision can deepen your understanding of development and improve your understanding of the industry.

Now let’s talk about the pursuit of technical professionals. As a technical professional, I believe my pursuit should be to spend a lifetime cultivating a “signature skill” renowned throughout the martial world—your representative work, the name by which you are known when you roam the world. When traveling the martial world, knowing many weapons, having all kinds of martial arts, and being able to use many programming languages is not some legend. The key is whether you can kill in one move with the weapon you are best at. Ten years to sharpen one sword, with craftsmanship and originality, all to give an accounting to this technical life of mine. I am also taking this pursuit as the goal for the next few years and working hard to realize it.

If the pursuit of a technical professional is to make money quickly and realize the dream of financial freedom, then there is one more point that must be taken seriously: pigs standing in the wind really do get lifted up. Quickly choosing the right direction of the trend is more important than effort. Too many such things happened around me in 2018, and Lei Jun’s entrepreneurial memoirs mentioned the same point. **Working hard and moving forward is certainly important, but sometimes choice may be even more important**!

Many people ask me similar questions: “Shuang, you switched to backend—doesn’t that mean the three years of client-side experience you had before are wasted?” “Shuang, after switching directions, you may not be able to get promoted for years. Do you mind?” “Shuang, do you regret getting into backend knowledge?” My answers are basically all “No regrets.” I am still young, and there are indeed many opportunities to trial and error. Some “mistakes” may only become recognizable when you are older and look back.

When you are young, you have plenty of time, plenty of opportunities, plenty of directions, and also the cost capacity for trial and error. In truth, there is no choice of path at all. The heart is the compass. With fog everywhere, all you can do is look forward.

On the question of changing technical direction, I think I have some right to speak, since I have personally gone through it. As someone who has been through it, I’ll offer readers some advice:

- Unless absolutely necessary, do not change direction. In the new direction, you are a newcomer and everything has to start from scratch. After changing direction, both promotion and job-hopping become relatively troublesome. I have already developed a deep understanding of this problem!

- If you change jobs in order to change direction, then when switching jobs, do not accept a pay cut or a demotion. With the same salary, the lower the job level, the better. This point has already been validated by colleagues around me who changed jobs and directions.
- After changing direction, you need to adjust your mindset. You may have been a big shot in your original domain, but in the new one, be prepared to start at the bottom for a couple of years.

- In the new direction, give yourself confidence. Confidence is more important than gold. Even if the industry is in a winter, keep exercising; health is the capital of revolution. Plan your time well in the new direction.

- If your level can still go up after switching directions, be mentally prepared, and remember: **If you want to wear the crown, you must bear its weight**! Embrace the challenge.

- Following the trend may be more important than working hard.


## Industry Status in 2018: What I Saw and Felt

![](https://img.halfrost.com/Blog/ArticleImage/123_4.png)

At the beginning of 2018, Alibaba acquired Ele.me. In the middle of the year, it merged Ele.me with Koubei. By the end of 2018, some small companies in the industry had shut down, and large companies also began laying people off based on performance, checking attendance, and enforcing 996. The image below shows some layoff information circulating online. Of course, its authenticity is uncertain, but it still reflects some industry trends from the side.

![](https://img.halfrost.com/Blog/ArticleImage/123_14.png)

As an industry gradually matures, the required headcount should become stable, and the bubbles of previous years will no longer appear. Hiring standards for programmers will become increasingly high, because companies need to select the most suitable and outstanding candidates from the pool. For technical people, improving both hard and soft skills becomes especially important. In this section, I want to talk about some phenomena and thoughts from this year. In the next section, I will discuss how to improve technically.

This year, I saw many companies being acquired or merged. The following content is not aimed at any specific company, so please do not map it to any particular one.

Company A is acquired by Company B. Company B needs to integrate Company A’s resources, and unnecessary developers need to be adjusted out (laid off). If you were the boss, how would you lay people off? The easiest thing to think of is to cut the low performers first: eliminate the bottom. What if it is resource integration? How should it be integrated? The easiest approach is to keep the best part of duplicated resources, and lay off the rest or transfer them to other departments. If the middle-office platform is bloated, then adjust the middle-office first.

After a small company is acquired by a large company, the biggest impact is on the small company’s infrastructure. The small company’s infrastructure may have been usable enough for its own business scenarios, but once it is acquired, any infrastructure that is not as good as the large company’s counterpart is at risk of being cut. This is not to deny the capability of people in small companies; rather, it is that staffing and resource allocation simply cannot compare with large companies. For example, for Project C, a large company may invest four experts for three years. A small company building a project with the same functionality might have one developer working on it for one year. There is no comparability at all in terms of personnel investment. Then Project C gets cut after the acquisition, and the related developers are assigned to other projects. If those other projects are ones they like, that is fine. If not, and the developer is personally very strong, they may consider leaving. I saw many such examples in 2018.


The least affected teams in an acquisition are business teams. When a large company acquires a small company, it must be because the large company has not covered the acquired company’s business scenarios, or has not captured a large market share there. It is impossible for a large company to instantly replace the small company’s business in a short period of time. Even if the large company rewrites the entire business, with a complete understanding of the business scenarios and requirements, it still requires a great deal of time, manpower, and resources. Meanwhile, the small company’s business is still iterating, and the large company has to start from 0 while continuing to catch up with the small company’s new requirements. Whether the OKR for a completely disruptive rewrite is high enough still needs to be evaluated. From this perspective, if the acquired small company’s business is relatively stable, then the corresponding core developers are basically not affected much after the acquisition (note: core developers). By comparison, core developers of infrastructure need to face choices such as transferring to other “edge” departments or departments they do not like, or going to a business team to write business code. The core competitiveness of core developers in business teams is that they understand the business system more clearly than anyone else, and they have long internalized the business scenarios.


Combining this with the current state of the industry, I would like to share some of my own views:

If you want to become the kind of coveted talent that big companies compete to “poach,” from my observation there are mainly two types of people. One type pushes a domain to the extreme: reaching 95, even 99 or 100 points. When people mention them, they represent that domain or direction. They are the leader and the foremost figure in that domain. Becoming such a person is very difficult. The corresponding title for this type of person is XXX Senior Technical Expert. The other type pushes a product to the extreme. For example: APM, quality monitoring, container scheduling, SOA, CI/CD, cloud infrastructure, and so on. Or they know a certain part of the company’s business inside out: core developers of WeChat and DingTalk IM, core developers of the transaction systems at Taobao, Tmall, JD.com, and so on. These people will also be aggressively poached. At first glance, the latter type may only score 85 or 90 in technical research, but they score higher in business proficiency.

Both of the above types of talent are highly sought after by large companies today. Of course, if you have not achieved either of the above two points, that does not mean you cannot get into a large company. If you prepare well for interviews and submit your resume seriously, there are still many opportunities.


## How to Improve?


![](https://img.halfrost.com/Blog/ArticleImage/123_5.png)


Many people around me have asked me this question. I do not consider myself a good role model; many people have much stronger execution than I do. So I will talk about how I improved over the past year, as well as what I did poorly, as a negative example for everyone.


Over the past year, besides reading technical books, I also read quite a few columns on Geek Time. I bought several columns there. The first one I bought was Chen Hao’s column (@左耳朵耗子). The content in this column is indeed extremely rich, and quite a bit of it is content that I personally feel I have not yet reached the level required to resonate with. Chen Hao created a reader group for the column and set a requirement for joining it: those who can persist with ARTS for one year can join. Friends around me who saw the contributions on my github would ask, “Why are there so many commits?” In fact, I just wanted to persist with ARTS for one year. If people do not push themselves, they will never know how much potential they have.


However, the result was that I did not persist. I became a negative example for everyone. ARTS stands for Algorithm, Review, Technique, and Share: each week, do at least one leetcode algorithm problem, read and review at least one English technical article, learn at least one technical technique, and share at least one technical article with opinions and reflections. Keep doing this for at least one year. In the second half of 2018, I basically managed to read several English articles every week, learn and record technical techniques, and share multiple technical articles. But I did not keep up with the leetcode algorithm problems. Apart from my own low efficiency leading to weekend overtime, an important reason may still have been that I “aimed too high and executed too poorly.” leetcode problems are divided by difficulty. For easy problems, solving 1–2 of them and getting AC was very quick, and gave me no sense of achievement. For medium and hard problems, I submitted for an entire afternoon and all of them were WA, which was hugely frustrating. Amid self-doubt, I gradually gave up and stopped persisting. I plan to pick this up again in 2019. I hope I will not be proven wrong when I write my year-end summary for 2019. The repo on github has also been created, to force myself a bit. I hope readers are not like me, “aiming high but executing low.”

If you are still confused about how to improve and do not know what to do, then stop being confused. First calm down and persist for one year using the ARTS method. After one year, look back and see how much you have gained.

If some readers feel they have hit a bottleneck in improvement, they can check whether their computer science fundamentals are solid enough to continue building upward. Computer science fundamentals determine the height of the superstructure and the speed of progress.

For example, take blockchain technology. For someone with very solid computer science fundamentals, mastering basic blockchain technology will be very fast, because the protocols and cryptographic techniques inside it are not new. The design philosophy is new, but after reading through it once, they can learn it quickly. Another example is switching directions. How much does it cost for an iOS developer to switch to front-end, artificial intelligence, or backend development? If the fundamentals are solid, then at least the computer science fundamentals transfer seamlessly. They are all general-purpose, and the switching cost is zero. Another example: a novice and an expert read the same technical book. The expert finishes it in one morning, while the novice takes a week. Why is there such a big gap? Because when an expert reads, most of the knowledge points in the book have already been internalized. They understand what is being discussed at a glance, do not need to think, and can read straight through. They only pause to think when encountering something they do not know. After reading an entire book, there may only be 2–3 places that require thought. It is different for a novice. Every page may contain something that requires thought, or even every paragraph may need careful consideration. For example, when reading Introduction to Algorithms, the book often derives some mathematical formulas and then says “it is obvious that...” But for a novice, this conclusion is really not obvious. When the novice reaches that line, they may think about it for an entire morning and still may not understand it. The expert has derived it before or already understood the conclusion long ago, so they pass that line in two seconds. From the example of reading speed, it is easy to see where your knowledge gaps are, and everyone’s gaps are different. My suggestion is that **learning should pay more attention to returning to first principles; computer science fundamentals are really important**.

Take switching directions as an example. Suppose a student used to work on iOS and has now switched to backend development. How should they continue improving in the new direction? First, their computer science fundamentals still need to be solid: computer organization, compiler principles, computer networks, algorithms and data structures, and operating systems. They must be very familiar with all of these. They are the foundation of your superstructure. The more solid the foundation, the higher the superstructure can be built.

![](https://img.halfrost.com/Blog/ArticleImage/123_6.png)

The image above also shows some common skills across different directions, such as using Git, data structures and algorithms, the SOLID, KISS, and YAGNI design principles, SSH, HTTP, HTTPS protocols, design patterns, and so on. Once these fundamentals are solid, the learning path afterward will be faster. For example, after understanding the skip list data structure, you will understand the Redis source code very quickly. After understanding graph algorithms, it is also much easier to understand the underlying implementation of PG.

![](https://img.halfrost.com/Blog/ArticleImage/123_7.png)

The image above is the backend learning roadmap. The first thing you need to become proficient in is the language you use day to day: memory layout, garbage collection algorithms, language features, and so on. Next are commonly used package management tools and the source-level implementation of commonly used libraries. After that, learn about databases: MySQL, PG, MongoDB. Middleware: Redis, RabbitMQ, Kafka, ElasticSearch. The use of Docker and K8s. Web-related topics: Nginx, Caddy, GraphQL. After becoming familiar with the above, you can continue exploring deeply in the areas you are interested in.

As for the other two directions, Front-End and DevOps, I have not gone too deep into them, so I will just include the images directly.

![](https://img.halfrost.com/Blog/ArticleImage/123_8.png)

The image above is the Front-End roadmap.

![](https://img.halfrost.com/Blog/ArticleImage/123_9.png)

The image above is the DevOps roadmap.


## An Architect’s Daily Work

![](https://img.halfrost.com/Blog/ArticleImage/123_10.png)

This year, during day-to-day work, I deliberately observed what architects do. An architect’s work is to propose the most suitable and best architecture solution for every system in the company, and to control various system metrics. Architects must understand the business thoroughly; otherwise, they cannot design a tailor-made architecture for the system. The architecture solution here must be tailor-made. A small company’s business volume is not as large as a large company’s. If it uses an architecture designed for a large company with hundreds of millions of users, it is obviously a waste of resources. Therefore, the architecture will change when the business volume changes significantly. In addition, architects must understand system metrics. How each business inside the company uses system components and resources is within their scope of work. When I apply for machine resources, it needs to be approved by architects. They review what the business is, what the business scenario is, and whether it is reasonable.

Architects also need technical foresight. A good architecture continuously evolves as the business grows. A good architecture should have headroom for the current business and should also anticipate business growth. It should not be the case that when the business suddenly grows, the architecture cannot adapt, leading to a catastrophic collapse. This kind of foresight and prediction is also an ability! This year, I encountered several technical refactorings that lacked foresight. Because I did not make good predictions, sudden risks could only be resolved urgently through overtime. If I had made better predictions, I could have reduced a lot of overtime, and the system would have run more stably and evolved more smoothly.

I believe the requirements for architects are relatively high, and the required breadth of vision is also wide. If you have not seen good and reasonable architecture designs across various scenarios, relying only on unpracticed imagination is not enough. After all, in architecture review meetings, people expect architects to provide valuable suggestions on good architectures. I tried to “comment from the sidelines” on former colleagues’ system architecture designs, and found that many design choices were trade-offs based on business scenarios, not bad designs. In the end, I could not really provide any good suggestions. Being an architect is indeed difficult. Without a thorough understanding of various businesses and practical experience with good architecture designs, there is basically no chance!


In addition, architects focus at a relatively high level, and are not limited to a single technical point. They pay more attention to returns. Why are architects paid highly? Is it because they are familiar with every line of code in a browser kernel? (This is just an example; of course, many architects are indeed proficient in every line of code in a browser kernel.) In fact, no. Their value lies in how large a problem they solve for the company. The high value they create for the company corresponds to their high compensation. They care more about returns. The purpose of a good architecture solution must be to solve problems. Using a particular technology is only a means. What problem can this technology solve? What makes it good? What is the return? Can it solve the problem? When I had just graduated, I paid more attention to technical points, and my perspective was relatively narrow. The shift from focusing only on a single technical point to focusing on technical returns can be considered a watershed in a programmer’s mindset and cognition.
The way architects think about and solve problems is well worth learning from.


## About Travel

![](https://img.halfrost.com/Blog/ArticleImage/123_11.png)


This year I visited 5 countries—Japan, the Czech Republic, Hungary, Austria, and Slovakia—and more than a dozen cities: Nagoya, Osaka, Nara, Kyoto, Hakone, Shizuoka Prefecture, Yamanashi Prefecture, Tokyo, Prague, Karlovy Vary, Český Krumlov, Hallstatt, Salzburg, Linz, Vienna, Budapest, Brno, Kutná Hora, and Bratislava. There were both large cities and small towns. Some people ask me what travel means to me. First, of course, it is about relaxing both body and mind, and releasing the pressure of work and life. Second, it is about broadening my horizons and seeing the world. I go to developed countries to see what life is like for the wealthy, and to explore why people who are materially affluent still have all kinds of worries. I go to poorer countries to see what life is like for the poor, and to understand how people who are materially poor enrich their spiritual lives. Wealthy people have their own troubles, while poor people can still live very happily. The human world is full of stories and interesting things. In the future, if someone offers me a drink and asks whether I have any stories, I can tell them about the interesting things I have seen around the world. Finally, travel lets me make friends with fellow travelers—people from all walks of life and different places, with different interests and hobbies, different skin colors, and a shared curiosity about the world, exploring the unknown together. In the restaurant of a hotel, people from all kinds of countries sit together, with different skin colors. Everyone eats differently: some use their hands directly, some use knives and forks, some use chopsticks, and some use spoons, all speaking a wide variety of languages. They have different beliefs: Christianity, Catholicism, Islam, Buddhism. A small space contains a condensed miniature of the world, bringing together people from different time zones. A famous quote from Julius Caesar also sums up my answer: I see, I come, I conquer. I measure this vast world with my small steps. (Videos from this year’s travels are all on my Douyin account, @halfrost.)

Occasionally intersecting with unfamiliar domains in life may spark special inspiration. Because of this, I have also developed the habit of reflecting on and summarizing what I have done over the past year while staying close to nature. My year-end summaries over the past two years were both completed while traveling. Escaping the noise of the city, on an unfamiliar night, listening to frogs and rain, I walked inward and looked directly at my true self.

My dream for 2019 is to go to Dubai, complete a 15,000-meter skydive, and ride a camel in the desert. My travel plans for 2019 are mainly Dubai, Europe, and the United States: to visit Germany, France, Italy, and Switzerland, and see how the former European powers are doing today; to go to the United States and experience the rich academic atmosphere of Ivy League schools; and to go to Dubai to see just how extravagant the lives of the “white robes” are, pick up some “trash” left by the roadside—Lamborghinis—and stay in a seven-star hotel.

## Finally


All right, that is it for 2018’s “Passing Years.” If you have any objections or anything you would like to discuss, feel free to reach out.


![](https://img.halfrost.com/Blog/ArticleImage/123_12.png)

April 1, 2018, in Japan

![](https://img.halfrost.com/Blog/ArticleImage/123_13.JPG)

December 5, 2018, in Prague, Praha


------------------------------------------------------

> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/halfrost\_2018/](https://halfrost.com/halfrost_2018/)