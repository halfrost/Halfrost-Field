<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-dc92dffb821d6ce9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


## Preface    
   Today I’d like to share some lessons learned from setting up a Code Review server at my company. In today’s mobile internet landscape, iteration cycles are extremely fast, and the speed of shipping releases largely determines the survival of a startup. As a result, code quality plays an especially important role in determining product quality.

    Table of Contents
    1.Phabricator Summary
    2.pre-push code review tool —— Differential
    3.code repository browse tool — Diffusion
    4.post-push code review tool —— Audit
    5.Other Feature Summary
    6.Final

#### I. Phabricator Summary
Today I’m going to introduce an excellent code review tool: Phabricator. Phabricator is one of the 11 major IT technologies that power Facebook. On the Phabricator website, its developers describe it this way: “Facebook engineers make no secret of their love for Phabricator; they even regard it as synonymous with ‘smooth’ and ‘rigorous’.” Below, I’ll walk through the code review workflow in Phabricator and highlight some of its strengths.

> 11 major IT technologies that power Facebook
1.HTML5
2.Facebook Platform
3.Facebook Credits
4.Facebook Apps
5.Open Compute Project
6.Hadoop
7.LAMP Stack
8.Scuba
9.HipHop For PHP
10.Scribe and Thrift
11.Phabricator

This is what the deployed server interface looks like:

![](http://upload-images.jianshu.io/upload_images/1194012-2aac90194fcb247f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

#### II. Differential
Differential is one of Phabricator’s core features. It is the primary platform where developers review one another’s code and discuss changes.

When it comes to generating a diff, you need to use the Arcanist Tool.

1.DownLoad Tool Download the Arcanist Tool

![](http://upload-images.jianshu.io/upload_images/1194012-0cb7d73b33d2b5eb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

2.Edit Path Configure the path
![](http://upload-images.jianshu.io/upload_images/1194012-b2939dd587f84f1b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

3.install certificate Install the certificate
![](http://upload-images.jianshu.io/upload_images/1194012-9016eb3624214f9c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

4.install certificate Verify the certificate token
![](http://upload-images.jianshu.io/upload_images/1194012-74c12121defa9fb1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

5.creat diff Generate the diff

![](http://upload-images.jianshu.io/upload_images/1194012-bfc62b4ab782de65.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

6.edit diff info Edit the diff information

![](http://upload-images.jianshu.io/upload_images/1194012-4cb2db4f59eb3b03.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

At this point, a diff has been created. Correspondingly, there should also be a diff record on the web page of the server you set up.
![](http://upload-images.jianshu.io/upload_images/1194012-7bf98ce3a90abce7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Now the workflow should move into pre-push code review: before submitting, you wait for the reviewer to review the code.

![](http://upload-images.jianshu.io/upload_images/1194012-9e61121c03b3f55a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-dc5fdb22cd13ba04.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-ad02ed72daf6e7f2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-56fc42fcf5704311.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The reviewer will see an interface like this:

![](http://upload-images.jianshu.io/upload_images/1194012-d34acabd1eff76d0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

After the reviewer approves it, the person who requested the review will receive an approval notification in their interface.

![](http://upload-images.jianshu.io/upload_images/1194012-da6258378190cd76.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-b8b22e89915cb850.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

#### III. Diffusion
Phabricator provides Diffusion, a remote repository browsing tool similar to GitLab. Developers can quickly view the following information:
1.VCS Repertory information Online version control system repository information

![](http://upload-images.jianshu.io/upload_images/1194012-40b2facdc859325e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-55d65be193b68502.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

2.VCS commit history Commit history

![](http://upload-images.jianshu.io/upload_images/1194012-1bbe2e7ca4d1fc9c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

3.Repertory directory structure Repository directory tree


![](http://upload-images.jianshu.io/upload_images/1194012-096e9c4661858248.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

4.Directory structure & commit information Commit information

![](http://upload-images.jianshu.io/upload_images/1194012-d7b0afe985b0ae5d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

5.Branches information Branch information

![](http://upload-images.jianshu.io/upload_images/1194012-9ac2dd3a89ea716e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

#### IV. Audit

1.Differences
Many people may wonder: now that we have Differential, why do we still need Audit?

Let me explain the difference between Review and Audit.

> 1.Phabricator supports two similar but separate code review workflows:

> 2.Differential is used for pre-push code review, called "reviews" elsewhere in the documentation. You can learn more in Differential User Guide.

> 3.Audit is used for post-push code reviews, called "audits" elsewhere in the documentation. You can learn more in Audit User Guide.
(By "pre-push", this document means review which blocks deployment of changes, while "post-push" means review which happens after changes are deployed or en route to deployment.)

> 4.Both are lightweight, asynchronous web-based workflows where reviewers/auditors inspect code independently, from their own machines -- not synchronous review sessions where authors and reviewers meet in person to discuss changes.

The above is Facebook’s official explanation. In simple terms, Differential is a code review tool used before code is submitted to a VCS repository. However, in some cases, due to time constraints or other circumstances, we may not have enough time to perform a very detailed pre-commit review and need to deploy earlier. So how can we review code after it has already been submitted to the VCS and still ensure code quality? The answer is Audit. That is Audit’s responsibility.

2.How it works
Some people may also ask: how does Audit work? What is the underlying mechanism?
Audit is mainly implemented through several types of audit request triggers.

The Audit tool primarily tracks two things:
- Code commits, and their audit status, such as “Not Audited”, “Approved”, and “Concern Raised”.

- Audit Requests. Audit requests notify users to audit a commit. They can be triggered in several ways.

Now that we’ve covered how it works, let’s look at its interface.

![](http://upload-images.jianshu.io/upload_images/1194012-50a25fd88098eec2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

3.Audit types  

Audit can be divided into two types:
- Required Audits. When you are a member of a project or the owner of a package, Required Audits prompt you to audit a commit. When you approve the commit, the audit request is closed.

- Problem Commits. These refer to cases where someone raises concerns about code you submitted during the audit process. Once you have addressed their concerns and all auditors approve the code, the problem commit will disappear.

4.Audit workflow
Here is an example to explain the Audit workflow in detail:

A makes a code commit.
B receives an audit request.
After a while, B logs in to Phabricator and sees the audit request on the homepage.
B inspects the code submitted by A. He finds some issues in the code, then selects the “Raise Concern” option and describes the issues in a comment.
A receives an email saying that B has concerns about her commit. She decides to handle the issue later.
Soon afterward, A logs in to Phabricator and sees a prompt under “Problem Commits” on the homepage.
A resolves those issues in some way, such as “discussing them with B” or “fixing the issues and committing the changes”.
B is satisfied and approves the original commit.
The audit request disappears from B’s to-do list. The problem commit also disappears from A’s to-do list.

That is the standard Audit workflow.

5.Audit Triggers
Audit requests can be triggered in the following four ways:
- Adding “Auditors: username1, username2” to the commit message will trigger audit requests for those users.
- In the Herald tool, you can create a set of trigger rules based on commit attributes, such as files being created, text being modified, the committer, and so on.
- In any commit, you can create an audit request for yourself through the commit message.
- You can create a package and choose “Enable Auditing”. This is a more powerful feature and may be useful for very large teams.

6.Some tips for Audit
- Auditor accountability. When reviewing a code commit, the audits you are responsible for are highlighted. You are accountable for any audit actions you take.
- In the diff comparison area, click a line number to add an inline comment.
- In the diff comparison area, drag across line numbers to add an inline comment spanning multiple lines.
- Inline comments are initially saved only as drafts until you submit the comment at the bottom of the page.
- Press “?” to view keyboard shortcuts.

Raise Concern

![](http://upload-images.jianshu.io/upload_images/1194012-2d78952c638a8c92.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Add Comment


![](http://upload-images.jianshu.io/upload_images/1194012-2b0ca4ef38e934b6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

#### V. Other Feature Summary
- Maniphest: task management and defect tracking, similar to GitHub Issues
- CountDown: scheduled reminder tool
- Repository: remote VCS repository management
- Herald Rule: create custom rules that notify us when certain events trigger those rules, similar to IFTTT

#### VI. Final
Finally, let’s talk about the advantages of Phabricator.

- In Phabricator, diffs are also presented for review by submitting a request. However, its diff does not contain the full contents of the files—only the changed portions. Therefore, you do not need to add the repository to the tool in advance. You can submit a diff directly, or paste the diff content to submit it.
- It is not just a code review tool; it also provides bug tracking, wiki, and other features. You can run unit tests directly and associate bugs with code reviews.
- Requests are clearly categorized by status, and the search functionality is easy to use.
- It supports SVN and Git.
- All review work requires only a browser; no additional plugins or software need to be installed.
- The UI and usability are excellent. The interface layout and themes can be customized, making it more modern and dynamic.

>“The function of good software is to make the complex appear to be simple”        
         
> –Grady Booch,One of the UML founders


“The function of good software is to make the complex appear to be simple.” 
(Grady Booch, one of the founders of UML)

Come experience the power of code review together!


This article shares how to use Phabricator. If your company has this server, or if you have purchased Phabricator services but do not know how to use them yet, this article should help you get started. When I have time, I’ll share some of the pitfalls I encountered when setting up this server myself. That’s all for this post—feel free to discuss!

Here is the Keynote I used when sharing this internally at my company. It’s not perfect, but I’m sharing it as well for anyone interested: http://pan.baidu.com/s/1dFiAaM9


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/code\_review\_phabricator\_use\_guide\_introduce/](https://halfrost.com/code_review_phabricator_use_guide_introduce/)