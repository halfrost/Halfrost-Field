# iOS 多环境打包配置
用一个Scheme配置多个环境变量，Run的时候选择不同的Build Configuration就可以分别打出不用的包，但是这种一个Schem配置打多个包的情况在实际项目中，我是不推荐的！这里仅仅是为了展示如何配置多环境的过程，配置Scheme，并且有Cocopods的时候怎么配置的Demo

##怎么设计Scheme
关于项目中具体应该怎么设计Scheme，请看我这篇博客的分析。

##出现异常
如果程序运行出现“The operation couldn‘t be completed (LaunchServicesError error 0.)” Clean一下就好了。