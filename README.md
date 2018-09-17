# MSWebController


## MSWebView 是什么

MSWebView 是一个基于UIWebView和WKWebView的WebView，能够提供类似UIWebView的代理事件完成WebView的delegate回调，并且提供许多额外的功能。

## MSWebView 提供了哪些功能

### 相比 UIWebView，MSWebView 提供了以下功能

* 提供网址提供者的host显示
* 并且针对UIWebView提供了侧滑的手势事件，能够进行自由前进和后退
* 提供进度条显示

### 相比 WKWebView，MSWebView 提供了以下功能

* 统一`UIWebView`和`WKWebView`的`delegate`,能够和使用UIWebView一样使用WKWebView
* 提供了Cookie的注入，能够在每次Web加载完毕之后将cookie信息同步到`NSHTTPCookieStorage`，并且将`NSHTTPCookieStorage`的cookie同步到WKWebView中。

### 更多功能：

* 提供阻塞线程和不阻塞线程的两种js执行方式
* 提供多级历史返回
* 更多功能敬请期待

## MSWebController

* 提供工具条控制Web的前进、返回、刷新、停止等功能。
 
![MSWebGif-01](ScreenSnap/MSGif-1.gif)

## 安装

你可以在 Podfile 中加入下面一行代码来使用 YTKNetwork

    pod 'MSWebController'

## 安装要求

* WKWebView iOS 8+
* UIWebView iOS 7+

## 感谢

* [IMYWebView](https://github.com/li6185377/IMYWebView)
* [SVWebViewController](https://github.com/TransitApp/SVWebViewController)

## 协议

MSWebController 被许可在 MIT 协议下使用。查阅 LICENSE 文件来获得更多信息。
