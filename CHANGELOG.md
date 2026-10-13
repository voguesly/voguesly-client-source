## v0.9.100

- **电脑版：修好一个「连上之后又反复掉线」的问题**：上一版加了一个自动挽救措施 —— 增强模式起不来时会自动换一个网卡名重建连接。但客户端另一边还在找原来的名字，于是误判成「没连上」，反复重启内核，最后把连接整个断掉。现在两边的名字对得上了，不会再自己把自己断掉。

## v0.9.99

- **电脑版：修好一个「所有线路都变红、上不了网」的问题**：电脑上同时装了 Hyper-V、WSL、Docker 或虚拟机这类虚拟网卡时，易联以前会漏掉一步设置，导致域名解析绕过易联直接出去，于是所有线路都显示红色、网站也打不开。现在这一项会稳定生效。
- **电脑版：连接和断开更稳**：连接时会先让内核正常退出，不再直接强制结束；「增强模式」万一启动不起来，会自动换一个网卡名重试，不用再干等；两个网卡名都起不来时会明确提示「重启电脑可恢复」。

## v0.9.97

- **「系统代理（兼容模式）」打开后不会再自己关掉**（电脑版）：增强模式连上时会自动关一次系统代理（增强模式已经接管全部流量，不需要它）；之后你自己再打开，就会一直保持，和 Clash Verge 等软件一样。
- **「全部走代理」模式更稳**：以前全部走代理时会固定在一条线路上，这条线路晚高峰连不上就整台电脑上不了网；现在和智能分流一样，主线路连不上会自动换到备用线路。
- **「网络检测」页不再显示「系统代理：未开启」吓到你**：开着增强模式时改为显示「不需要（增强模式已接管全部流量）」。

## v0.9.96

- **和 Clash Verge、官方 FlClash 等软件一起装时更稳**：
  - 其他代理软件占着网络时，连接前会明确告诉你是哪一个软件、怎么彻底退出（在右下角托盘图标上右键 →「退出」，只关窗口不算）。不会再认错软件，也不会同时再弹一条「连接超时」。
  - 如果易联在后台被其他软件的安装程序意外关掉，会在几秒内自动重新连上，不会再出现「显示已连接、其实上不了网」。
  - 装了官方 FlClash 等软件时，易联不会再显示「已连接」却打不开网站，会提示你先退出对方。
  - Mac：Shadowrocket 等 VPN 类软件开着时，会提示你把它的 VPN 开关关掉（只退出 App 不会断开 VPN）；不会再因为电脑装过 Clash Verge 就一直提示「请先退出 Clash Verge」。
- 安装或升级易联时，不会再影响你电脑上的官方 FlClash。
- 不再占用 Clash Verge、FlClash 的「一键导入」链接，在其他网站点「导入到 Clash」会正常打开对应的软件。

## v0.9.95

- **自动线路会显示「当前」正在用哪一条**：「切换线路」里的「🛡 自动」卡片现在会写出实际在用的线路，不用再猜日常上网走的是哪个节点。
- **线路改名后不会再一直转圈**：如果你之前手动选过的线路改了名字，App 会自动显示实际在用的线路，不会停在旧名字上转圈。
- **提醒你关闭其他代理软件**：连接时如果发现 Clash Verge、v2rayN、NekoBox 等还在后台运行（包括关了窗口但仍在后台的服务），会提示你先退出它们，避免「显示已连接但部分软件上不了网」。
- 「上传日志」会一并记录是否有其他代理软件在运行、系统代理和代理环境变量的设置，客服能更快找到问题。
- **Windows 开增强模式时，DNS 不会再漏到本地运营商**：以前在 Windows 上，部分域名查询会绕过易联、直接走 Wi-Fi 或网线的运营商 DNS，检测网站会显示「DNS 在中国」。现在所有查询都经过易联线路，IP 和 DNS 一致。

## v0.9.94

- **切换「智能分流 / 全部走代理」后立即生效**（修复 0.9.93 的遗漏）：打开 App 后第一次切换，Telegram 等已经开着的 App 也会马上换到新模式，不用再重开它们。

## v0.9.93

- **切换「智能分流 / 全部走代理」后立即生效**：以前切换后，已经开着的 App（比如 Telegram）还会沿用原来的线路，要重开 App 才会换过去；现在切换时会自动让它们重新连接，马上走新的模式。
- 首页通知条右边留白加宽，文字不再贴边。

## v0.9.92

- **首页会显示重要通知**：遇到需要你处理的情况（比如要更新订阅），首页顶部会出现提示，点一下就能处理。
- **在线客服、下载页、官网和 Telegram 入口以后由我们直接更新**：地址有变化时 App 会自动收到，不用重新下载安装。
- 「网络检测」的分流测试：「Cloudflare」一项改名为「普通网站」，并说明 AI 和查 IP 网站走美国住宅线路，所以 IP 和普通网站不同是正常的。
- 退出登录或换账号时，不会再误删你自己添加的其他订阅（部分使用免费域名的订阅以前会被误认成易联订阅）。

## v0.9.91

- **入口被干扰时自动换一个能用的**：登录、更新订阅、Google 登录、找回密码不会再卡在打不开的地址上；以后我们更换入口地址，App 会自动收到新地址，不用重新下载安装。
- **一键更新更稳**：主下载站打不开时会自动换备用下载站，下载完照样核对文件，保证装的是完整的新版本。
- **在线客服多了一个备用入口**，主入口打不开时自动换。
- **开了「全部走代理」会一直提醒你**：首页会显示一条提示，说明国内网站也会绕海外、按当前线路的倍率扣流量，并显示当前线路倍率；点一下就能切回「智能分流」。
- 高级功能：可以添加单独节点（客服发给你的节点链接），也可以重新添加或替换订阅。
- 「上传日志」里的连接检测更准确，客服排查更快。

## v0.9.90

- **修复 Windows 版「增强模式」开不起来**（0.9.86 起）：打开增强模式时会弹「TUN 授权未通过」、然后只能用兼容模式，Telegram 等软件不走易联。现在点「是」授权一次就能正常开启。
- **「上传日志」网络不稳时会自动重试**：遇到网络抖动会自动再试几次，按钮上会显示「正在重试」；真的没发出去时会弹窗明确告诉你，写好的内容不会丢，稍后再点一次就行。
- 打开在线客服时会自动带上你的客户端版本号，客服不用再问你用的是哪个版本，排查更快。

## v0.9.89

- **打开 App 或切换连接方式时，不再弹出英文提示「core done」**：真的出问题时，会用中文告诉你发生了什么、下一步怎么做。
- 连接出错时不再弹出看不懂的英文技术报错，改为一句中文提示；原始信息会记在日志里，方便客服排查。
- **「上传日志」更有用，客服能更快定位问题**：会自动附上每个线路组当前用的是哪条线路、能不能用；最近两天连接失败最多的网站和原因；上传那一刻对关键线路、国内网站和易联面板的实测结果。重启 App 之后，之前的错误记录也不会丢。
- 已经有一张未关闭的工单时，再次上传日志不会再失败，会自动追加到那张工单里。
- 复制、导出日志时会自动去掉账号凭证；日志不再记录 Wi-Fi 名称。

## v0.9.88

- **修复「连接设置」里加第二条附加规则，会把第一条（以及以前加过的规则）替换掉**：现在每条规则各自保存，加多少条都在。
- 附加规则的「线路」选项不再出现「GLOBAL」：选了它实际等于直连，容易误会。
- **连接方式显示真实状态**：增强模式没起来、自动改用兼容模式时，面板会如实显示「兼容模式」，并且可以再点「增强模式」重试（以前显示成增强、点也点不动）。
- 关掉更新窗口会真正取消下载，不会过一会儿自己安装或者重启。
- 修复切换到备用入口后，退出登录没清干净订阅、「更新订阅」重复导入的问题。

## v0.9.87

- **大圆圈右下角新增齿轮「连接设置」**：点开可以直接选连接方式——「增强模式」（整台电脑都走易联，推荐）或「兼容模式」（只有浏览器等软件走易联，不需要电脑密码），不用再去设置里翻。还可以在这里加「附加规则」，让某个网站固定直连或固定走某条线路：匹配方式和线路都是下拉选，填错格式会提示，不会再出现「加了一条规则整个客户端失灵」。
- **「切换线路」不再一片红**：以前后台自动检测偶尔超时一次，就把线路标成红色「未连通」，看起来像线路全坏了。现在没测过的线路显示「未测试」，点一下就测；切到某个线路组时会自动把没测过的补测一遍。只有真正测过还不通（你点了测速，或者切换线路组时自动补测），才会显示「未连通」。
- **延迟数字更准**：显示最近 3 次测速里最好的一次（以前第二次测速总是显示两次里较慢的那个，而且有时会被未处理的原始数字覆盖）。
- **打开 App 不会再马上要电脑密码**：只有在你点「连接」、需要开启增强模式时才会问。
- **和小火箭等其他 VPN 同时开着时，提示说人话、不会一闪而过**：以前会弹出一行看不懂的技术报错，几秒就消失。现在会说明「另一个 VPN 也在运行，一般不影响使用」，需要你点「知道了」才关闭；检测到必须先退出的代理软件时，会写清楚是哪个软件、要「退出程序」而不是只断开。
- **加了附加规则马上生效**：以前在设置里改完附加规则，要断开重连才生效。
- **修复「没连上线路时，登录、更新订阅很慢甚至失败」**：以前客户端每次联网，都会先去试一个在国内已经打不开的旧地址，要等它超时才换下一个。现在会优先使用国内能直接打开的地址。
- **注册、忘记密码、Google 登录、打开网页面板，这几个按钮恢复正常**：以前会跳到那个在国内打不开的旧地址。
- **邀请链接恢复正常**：以前复制出去的邀请链接，朋友在国内没连线路时打不开；现在可以直接打开，邀请码也会自动填好。
- 英文界面修正了多处句号后缺空格的文字；上传日志时会带上连接错误记录，方便客服排查。

## v0.9.86

- **修复「加过自定义规则后客户端整个失灵」**：如果你在「配置覆写 → 自定义规则」里加过带横杠的规则类型（例如「域名后缀」「IP 段」），客户端会变成：界面显示已连接、但线路列表空白、订阅永远更新不了。表面完全看不出跟规则有关。已修好，旧规则会自动兼容，不用重新添加。
- **修复「点了连接，圆圈转一下就自己熄灭」**：这个问题还会连带让你更新不了订阅——两个症状其实是同一个原因。已修好。
- **修复「更新订阅失败」**：以前一旦核心出问题，连订阅都更新不了，等于没法自救。现在更新订阅会依次尝试直连、你自己的系统代理、我们的线路，只要有一条通就能更新。
- **核心启动失败时会告诉你原因**：以前只是圆圈熄掉，一个字的提示都没有。
- **左边「切换线路」入口不会再消失**：以前核心没起来时整个入口会不见，看起来像功能被删了。
- **Mac 大幅省电**：闲置时的 CPU 占用明显下降（托盘图标每秒重绘、连接按钮的呼吸动画在看不见时仍在跑、后台每 3 秒执行系统检查——都修了）。窗口被其他程序挡住或收进托盘时会自动降低刷新频率。
- **和官方 FlClash 同时安装时不再互相干扰**：以前两个程序会抢同一个系统服务和端口，导致其中一个的增强模式起不来。
- **安全加固**：订阅凭证文件收紧了读取权限（以前同一台电脑的其他用户能读到）；Windows 增强模式的授权服务补上了多处校验。

- Linux 版修复「增强模式」：以前打开增强模式后界面显示已连接，实际上虚拟网卡根本没建起来，终端命令、Telegram 这类不走系统代理的软件仍然不通。现在增强模式会真正接管整机流量。
- Linux 版 AppImage 也能开增强模式：第一次打开时输入一次管理员密码即可（以前 AppImage 因为文件只读，授权永远失败）。
- Linux 版增强模式授权方式更安全：改用系统的「网络权限」（capabilities）授权，不再把代理核心设成 root 权限程序；升级后第一次开增强模式会再要一次管理员密码，并顺手清掉旧版留下的 root 权限。
- Linux 版安装包修正：rpm 里的图标文件权限修正；应用菜单分类补上「网络」；桌面快捷方式文件的规范版本号写法修正。
- 登录失败时会显示服务器给的原因（例如「密码必须大于 8 个字符」），不再只显示「网络错误」。

## v0.9.85

- 修复 Windows 在全新系统上打不开：部分电脑（没装过游戏、Office 等软件的新系统）打开时提示「找不到 VCRUNTIME140_1.dll」或「找不到 MSVCP140.dll」。现在安装版和便携版都自带所需的运行库，不用再另外安装。
- 一键更新下载更可靠：下载完会核对文件大小和校验码，网络不稳定导致下载不完整时自动续传或重新下载（最多 3 次），不会再把没下完的安装包拿去安装（以前 Mac 可能提示「磁盘映像已损坏」）。仍然失败时会提示「网络不稳定，下载不完整」，可以重试或打开下载页手动下载。
- Linux 支持网页一键登录：在易联网页面板点「易联客户端 → 已安装，一键登录」即可拉起客户端登录，客户端已经打开时也能接收。
- Linux AppImage 版可以正常使用：修复在 Debian 等系统上打不开的问题。
- Windows 安装版默认勾选「创建桌面快捷方式」；安装向导换成易联的欢迎页和配图，「应用和功能」里显示「易联 Voguesly」。
- 修复 Windows 装完直接打开时，在网页上点「一键登录」没有反应（客户端收不到网页发来的登录请求）。

## v0.9.84

- 电脑版在线客服切走再回来不用重新加载：去看别的页面再回到「在线客服」，聊天记录的位置和还没发出去的字都还在。客服页已经打开时再点一次「在线客服」，可以手动重新载入（白屏时用）。隐藏超过 15 分钟、主动关闭或退出登录后会释放，下次打开重新载入。
- 首页一键更新订阅：账号卡「购买/续费」旁边新增「更新订阅」按钮，手机上不用再进「账户与设置」才能更新。
- 测速失败不再弹提示：线路测速或自动选线检测失败时，顶部不再一次弹出好几条英文提示（线路列表里本来就会显示未连通）。
- 邀请页「可用佣金」显示修正：以前把「确认中」的佣金当成可用，点划转或提现会失败；现在可用佣金和确认中的佣金分开显示。提现方式、提现门槛和结算比例按后台设置显示，不再固定写「支付宝 / 微信 / USDT」。
- 设备统计更准：同一个 Wi-Fi 下的多台设备会分开计算，不会再被当成一台。
- 新增 Linux 版（64 位，提供 deb 和 AppImage）：默认使用系统代理模式；注册需要人机验证时会在浏览器打开注册页。

## v0.9.83

- 全新门面：
  - 12 款二次元风头像，当前选中的会有紫色圈。
  - 首页账号卡重新设计：套餐胶囊、还剩几天、剩余流量改用和面板一样的衬线大数字、紫色渐变进度条、在线设备与已用流量。
- 新手引导：第一次连接成功后，用聚光灯一步步框出「开启易联 / 切换线路 / 网络检测 / 在线客服 / 账户与设置」。以后可以在「账户与设置 → 遇到问题 → 新手引导」再看一次。
- 名字和图标更直白：
  - 「我的账户」改名「账户与设置」，侧栏不再重复出现「用户中心」。
  - 在线客服更醒目，带绿色「在线」小点。
  - 「检查更新」下面显示当前版本号。
  - 「出站模式 / 规则」改为「分流模式 / 易联智能分流」。
  - 连接圆圈里的「TUN」改为「增强模式 / 兼容模式」。
  - 线路页不再出现 Fallback / Selector 这类英文，改成「当前：某某线路」。
- 「账户与设置」页重新分组：服务 / 遇到问题 / 设置 / 其他。更新订阅的卡片会说明它的作用（线路或规则有变动时点一下就保持最新）。
- 修复：
  - 支付提示、关于页等文字里出现「\n」。
  - 检测页提示了一个不存在的设置路径。
  - 网络出错时显示一串英文，现在改成中文说明。
- 检查更新更及时：最多 15 分钟检查一次。32 位的老安卓手机一键更新时会下载对应的安装包。
- 上传日志会附带「现场快照」：当时连没连上、各线路组实际用的节点和延迟、订阅上次更新时间。客服不用再反复问。

## v0.9.82

- 网页一键登录客户端：在易联网页面板点「易联客户端 → 已安装，一键登录」，客户端会弹出确认框（显示网页上的账号邮箱），点「登录」就完成，不用再输密码。授权码 60 秒内有效、只能用一次。Windows 在客户端已经打开的情况下也能接收（以前第二次打开链接会没有反应）。
- 首页账号卡和「我的」页显示「在线设备 x / y 台」：满了会标红并提示先退出不用的设备，不用再猜「为什么新设备连不上」。
- 公告有新内容时，侧栏「公告」和手机「我的」会亮小红点，点进去看过就消失。
- 线路页：每个分组里的「🛡 自动」固定排在第一位并标「推荐 · 自动切换」（当前线路不通会自动换下一条）；按延迟或名字排序也不会把它挤下去。修复部分节点名前面显示两个国旗。
- 日志里不再记录订阅链接和登录凭证（上传日志前也会再清一遍），更安全。
- 「上传日志」改为按大小收集最近的日志（以前固定只收最近 150 行，往往只覆盖一两分钟），间歇性掉线的现场更容易被带上，客服不用再让你「再试一次再传」。

## v0.9.75

- 侧栏「商城」改名为「购买套餐」：更直白，一看就知是购买加速套餐，不会误解成买实物。
- 导出 / 复制日志现在自动附带环境快照：客户端版本、系统、TUN 状态、当前订阅、各线路组当前选中的节点。以前客户导出的日志只有连接记录，缺少「当时用的什么节点、什么状态」，客服很难还原问题；现在一份日志就能看清现场。

## v0.9.74

- 检测页新增「虚拟网卡被其他 VPN 抢走」的明确警告：以前如果你同时开着别的代理软件（如 Clash Verge、Shadowrocket），而它抢走了系统的默认路由，易联虽然显示在运行，但你的节点和分流规则其实没生效 —— 页面顶部只会显示「一切正常」，很难发现。现在这种情况会明确标红，并告诉你怎么处理（完全退出那个软件，或在它里面关掉网络接管，再回到易联重连）。不会去动你其他的软件（Tailscale 这类连公司内网的通道照常）。
- 延迟测试「超时」不再显示成刺眼的红色、文字改为「未连通」：手机热点、校园网这类不稳的网络下，一次测速失败并不代表节点坏了（同一个节点从稳定线路测其实是好的）。以前一抖就标红，容易让人误以为「买的节点用不了」。现在用中性颜色，红色只留给真正确定有问题的项。
- 修复延迟测试把大量好节点误报「超时/死掉」：整组测速由一次并发上百条改成每批 12 条的队列，避免节点排队等到测速超时才轮到、结果好节点被误判。（此前版本已修，本版合并统一。）
- 延迟测试超时上限由 5 秒放宽到 8 秒，减少慢速线路被误判超时。（此前版本已修，本版合并统一。）
- 修复「导出日志」一直失败：储存面板打不开时自动写到下载目录，并新增「复制全部日志」按钮（不经文件系统，最不容易失败）。（此前版本已修，本版合并统一。）
- 面板多域名自动 failover：中国大陆 CF 被墙导致登不进、拉不到订阅时自动切换备用域名。（此前版本已修，本版合并统一。）

## v0.9.72

- 修复「直连」这一项永远显示红色/超时:此前测速用的地址在国内本身就连不上，测直连必然失败，跟你的网络无关。现在换成国内外都能通的地址，直连会显示真实延迟。
- 修复部分节点延迟数字虚高、看起来很慢其实不慢：旧的测速地址只解析到单个 IP，个别线路绕到那个 IP 时延迟会成倍放大（实测同一个地址，经香港出口 627 毫秒、经新加坡出口只有 49 毫秒，而换成新地址两边都是个位数）。现在的延迟数字更接近真实情况，选节点不会再被误导。
- 升级后自动生效；你自己改过测速地址的不会被覆盖。

## v0.9.71

- 修复 0.9.70 引入的问题：部分用户（尤其校园网、公司网这类偶尔丢包的网络）会「用着用着突然断一下」。原因是 0.9.70 新加的「自动检测掉线就重连」会把网络抖动误判成断线，于是客户端在你正常使用时自己重启了一次连接 —— 反而制造了断线。这一版已经把这个自动重连去掉。
- 保留 0.9.70 的连接保活：连着的时候仍然每 45 秒做一次极轻量的心跳，让校园网、公司网这类会回收「空闲连接」的网络不会因为你闲置几分钟就把连接掐断。心跳只负责保活，不会再因为一次探测失败就断开或重启。
- 心跳探测目标改用更稳定的地址，减少在国内网络环境下的无谓失败。

## v0.9.70

- 继续修复「电脑放着不动几分钟就断网、回来要刷新才好」。桌面版新增连接保活:连着的时候每 45 秒悄悄经隧道做一次极轻量的连通性探测(每次几百字节,流量可以忽略),让连接一直保持活动状态。这样校园网、公司网、部分运营商这类会主动回收「空闲连接」的网络，就不会再因为你闲置几分钟而把连接掐断。上一版(0.9.68)只放宽了其中一种协议(Hysteria2)的空闲判定时间，治标；这一版从连接本身入手，不管你用的是哪种节点都一视同仁。
- 万一整条线路真的断了(不只是空闲——比如切换网络、笔记本网卡从休眠恢复)，桌面版现在会自动侦测并悄悄重连一次，不用再手动点断开重连。为避免误判，要连续探测失败约两分钟才会触发，且有严格频率限制，不会反复重启核心。
- 以上仅桌面版(Windows / macOS)生效；手机版有自己的连接管理，不在此列。

## v0.9.69

- 修复一批网站在易联开着时打不开、关掉却正常的问题（面板、下载站、在线客服、微软 Azure 存储等）。原因是客户端的 DNS 里配了两台境外服务器做「防污染复核」，而它们在国内本身就连不上：只要一个域名解析出来的是境外 IP、并且按规则走直连，复核这一步就会卡死，整个解析超时，网站彻底打不开。代理本身是通的、测速也正常，所以很难往 DNS 上想。
  这次是从根上关掉这层复核 —— 我们用的本来就是加密 DNS（DoH），不存在被污染的问题，这层复核只剩下卡死的风险。此前是发现一个域名就加一条例外，前后加了七轮也没堵住。升级后自动生效，不需要任何操作。
- 英文、日文、俄文界面补齐：登录、商城、支付、邀请返利、工单、用户中心、新手引导、检测与诊断、安装更新这些页面此前一直是写死的中文，非中文用户看到的是一片看不懂的字。这次 443 条文案全部补齐五种语言。
- 切换语言后立即全局生效：此前通知、托盘菜单、底部提示条、诊断页这些不走页面刷新的地方会一直停留在旧语言，要重启客户端才会变。
- 简体中文文案里混入的粤语口语已全部改写为普通话（例如检测页的「呢度讲清楚而家边条通路喺度行」）。粤语版本移到繁体中文，繁体一律用书面语。
- 修复诊断页把同一个第三方客户端列两次（装了 mihomo-party 时会同时显示「Mihomo Party」和「mihomo 内核」）。
- 「检查更新」不再需要手动点：改为启动时和切回前台时自动检查，最多每小时一次；检查失败不占用这一小时的额度。

## v0.9.68

- 修复「电脑放着不动几分钟就断网、回来要刷新网页」：连接空闲判定时间由 30 秒放宽到 120 秒，与服务端一致。此前客户端硬编码 30 秒会压制服务端设置（协议上取双方较小值），电脑空闲后网卡进入省电、保活包停发，30 秒就会把整条连接判死，连带这条连接上所有正在进行的请求一起断开 —— 表现就是网页提示「没有网络」、要刷新一次才好。（后台统计显示这类断开在近 48 小时内相当普遍；本次修复对使用易联 App 的用户生效，其他第三方客户端受其自身内核限制不在此列。）

## v0.9.67

- 新增「本机环境」诊断：在「检测」页最上方，一眼看清虚拟网卡、系统代理、本地端口三条通路现在分别由谁接管，并列出同时在运行的其他代理软件。出现「显示已连接却上不了网」时不必再靠猜。
- 系统代理被其他代理软件接管时，诊断卡会明确说明「上网不受影响」（易联走的是虚拟网卡），并提供「重设易联的系统代理」按钮 —— 该按钮只会重写易联自己的设置，不会关闭或修改你其他的代理软件。
- 左侧栏「检查更新」改为常驻：此前只有检测到新版本时才出现，导致已是最新版的用户根本找不到这个入口，也无法手动检查。现在平时显示「检查更新」，有新版时高亮显示版本号。
- 安卓版同步更新至同一版本号，便于日后对照排查；安卓也已用上易联专属端口，不再与其他代理 App 抢占本地端口。

## v0.9.66

- 代理端口改为易联专属，不再与其他客户端抢占：此前沿用 Clash 生态通用的 7890，只要电脑上装了 Clash Verge / ClashX / mihomo-party / 原版 FlClash 等任意一个并先启动，易联就会绑不到端口，表现为「显示已连接却上不了网」。升级会自动搬迁（你自己改过端口的不会被覆盖）。
- 「系统代理（兼容模式）」状态改为如实显示：此前只要虚拟网卡在运行就不再校验系统代理，导致系统代理被其他代理软件接管后，易联仍显示自己接管中。
- 被其他程序接管系统代理时只提示一次并说明「上网不受影响」，不会再误断开正常工作的虚拟网卡。

## v0.9.65

- 主页大圆圈文字重新排版：连接状态与承载方式分两行显示，长文案（如「TUN + 系统代理」）不会再溢出圆形边界。
- 左侧栏「在线客服」下方新增「有新版本」入口：检查到新版时才出现，点击即可查看更新说明并下载，不必再进入「设置 → 关于」。
- 该入口独立于「自动检查更新」开关：即使关闭了更新弹窗提醒，仍然能在侧栏找到更新入口，且不会主动弹窗打扰。

## v0.9.64

- 修复虚拟网卡（设备接管）明明已经正常工作，却被客户端误判为失败、进而自动切回系统代理的问题。这是此前「连接一会儿就掉、Telegram 时好时坏」的根本原因。
- 根因：macOS 上的接管检测用「默认路由是否指向虚拟网卡」来判断，但 macOS 的接管方式并不会改写默认路由，因此健康状态也会被判成失败。
- 现在改为检测真实公网目标的实际出口，并校验该虚拟网卡确实属于易联，不会再把其他 VPN（如 Tailscale）误认成易联自己的接管。
- 误判消除后，不会再出现无谓的核心重启与自动降级。

## v0.9.63

- 修复 macOS 虚拟网卡（设备接管）打开后仍然无法生效、只能退回系统代理的问题。
- 根因：0.9.57 起「按 App 版本迁移后台服务」会在每次升级时注销并重新注册后台项目，重新注册后状态未必立刻恢复为已启用，导致版本标记始终写不回去，每次连接都重复注销一次，核心始终拿不到提权，虚拟网卡永远建立不起来。
- 现在后台项目已启用时直接沿用，不再主动注销；只有在提权真正失败（例如升级后仍是旧后台服务）时才做一次重新注册并自动重试。
- 重新注册后如果需要重新授权，会明确提示并可一键打开系统设置。

## v0.9.62

- 修复桌面端「客户端显示已连接、实际全部超时」：TUN 接管失败时不再把设备留在「TUN 与系统代理都关闭」的断网状态。
- 升级迁移不再强制关闭「系统代理（兼容模式）」。此前 v2/v3 迁移会无条件关掉它，一旦 TUN 因权限或路由问题接管失败，用户就没有任何可用通路。
- TUN 授权失败、被其他代理占用或路由持续不通时，改为自动切到兼容模式并明确提示当前不是整机接管，同时保留 TUN 偏好；断开重连或重启后会重新尝试 TUN。
- 修正「关闭其他代理后可直接重试」提示与实际行为不符的问题：第三方冲突不再把 TUN 开关永久写成关闭。
- TUN 路由探测持续失败时不再直接关停核心，改为保住核心并降级承载，避免连接被整体切断。

## v0.9.61

- 修复 macOS TUN 启动后约数秒被易联自身路由探测误判并自动关闭的问题：增加启动收敛宽限、连续失败阈值与一次受控核心/TUN 恢复。
- 修复 TUN 失败后的生命周期清理，避免残留核心进程/监听器影响下一次连接；不关闭或修改其他 VPN（包括 Tailscale）。
- 仪表盘恢复「虚拟网卡（设备接管）」与「系统代理（兼容模式）」开关；大圆圈按实际接管路径显示 TUN、系统代理或两者。
- 桌面新配置默认 TUN 优先、系统代理关闭；现有配置继续由迁移逻辑保持 TUN 优先。

## v0.9.60

- 升级迁移现有桌面配置回到 TUN 优先：旧的系统代理偏好不会再让大圆圈静默只启动兼容模式。
- 普通用户主页继续只显示 TUN（设备接管），系统代理保留在进阶设置。

## v0.9.59

- macOS 普通用户主页只保留 TUN（设备接管），系统代理移到进阶设置，避免把兼容模式误认为整机已接管。
- TUN 授权失败时回滚开关状态，避免显示「TUN 已开启」但实际仍由系统代理或直连承载。
- 从 DMG 直接运行时明确提示先拖入 Applications；TUN 授权提示可一键打开 macOS 后台项目设置。
- 发布 DMG 固定包含 Applications 快捷方式，更新后可直接拖拽覆盖旧版本。

## v0.9.58

- 仪表盘同时显示 TUN（设备接管）与系统代理（兼容模式），连接状态明确标记实际接管方式
- macOS 自动 DNS 只在 TUN 运行期间临时加入，停止或退出时只撤销易联自己加入的 DNS，不覆盖用户后续修改
- TUN 接管失败提示改为可执行指引，明确关闭其他 VPN 或使用仪表盘系统代理备用入口
- 修正 Android 平台 VPN 系统代理文案不应套用桌面兼容模式说明
- 串行化 macOS 自动 DNS 的加入/恢复操作，避免快速开关 TUN 时发生竞态

## v0.9.57

- 修复 macOS 升级后旧版 root TUN helper 仍驻留内存、导致 0.9.56 新路径修复未生效的问题
- helper 注册现在按 App 版本迁移：检测到旧 daemon 时安全卸载并重新注册当前版本，避免用户手工敲 launchctl 命令
- Telegram 等不遵循 macOS 系统代理的应用可在 TUN 真正建立后随系统流量接管

## v0.9.56

- 修复 macOS TUN helper 仍只允许旧 App Bundle 核心路径，导致外置核心无法提权、TUN 被降级为关闭的问题
- macOS helper 现在只接受 Voguesly 固定的 Application Support 外置核心路径，并继续执行真实路径、文件类型与代码签名校验
- 修复后重新验证核心 setuid、TUN 路由与系统代理连接态

## v0.8.93

- Support custom overwrite

- Support run on demand

- Optimize windows ipc

- Optimize windows arm64

- Optimize build

- Optimize some details

- Update core

## v0.8.92

- Add sqlite store

- Optimize android quick action

- Optimize backup and restore

- Optimize more details

## v0.8.91

- Fix windows some issues

- Optimize overwrite handle

- Optimize access control page

- Optimize some details

## v0.8.90

- Fix android tile service

- Support append system DNS

- Fix some issues

- Update changelog

## v0.8.89

- Fix some issues

- Optimize Windows service mode

- Update core

- Update changelog

## v0.8.88

- Add android separates the core process

- Support core status check and force restart

- Optimize proxies page and access page

- Update flutter and pub dependencies

- Update go version

- Optimize more details

- Update changelog

## v0.8.87

- Optimize desktop view

- Optimize logs, requests, connection pages

- Optimize windows tray auto hide

- Optimize some details

- Update core

- Update changelog

## v0.8.86

- Fix windows tun issues

- Optimize android get system dns

- Optimize more details

- Update changelog

## v0.8.85

- Support override script

- Support proxies search

- Support svg display

- Optimize config persistence

- Add some scenes auto close connections

- Update core

- Optimize more details

## v0.8.84

- Fix windows service verify issues

- Update changelog

## v0.8.83

- Add windows server mode start process verify

- Add linux deb dependencies

- Add backup recovery strategy select

- Support custom text scaling

- Optimize the display of different text scale

- Optimize windows setup experience

- Optimize startTun performance

- Optimize android tv experience

- Optimize default option

- Optimize computed text size

- Optimize hyperOS freeform window

- Add developer mode

- Update core

- Optimize more details

- Add issues template

- Update changelog

## v0.8.82

- Optimize android vpn performance

- Add custom primary color and color scheme

- Add linux nad windows arm release

- Optimize requests and logs page

- Fix map input page delete issues

- Update changelog

## v0.8.81

- Add rule override

- Update core

- Optimize more details

- Update changelog

## v0.8.80

- Optimize dashboard performance

- Fix some issues

- Fix unselected proxy group delay issues

- Fix asn url issues

- Update changelog

## v0.8.79

- Fix tab delay view issues

- Fix tray action issues

- Fix get profile redirect client ua issues

- Fix proxy card delay view issues

- Add Russian, Japanese adaptation

- Fix some issues

- Update changelog

## v0.8.78

- Fix list form input view issues

- Fix traffic view issues

- Update changelog

## v0.8.77

- Optimize performance

- Update core

- Optimize core stability

- Fix linux tun authority check error

- Fix some issues

- Fix scroll physics error

- Update changelog

## v0.8.75

- Add windows storage corruption detection

- Fix core crash caused by windows resource manager restart

- Optimize logs, requests, access to pages

- Fix macos bypass domain issues

- Update changelog

## v0.8.74

- Fix some issues

- Update changelog

## v0.8.73

- Update popup menu

- Add file editor

- Fix android service issues

- Optimize desktop background performance

- Optimize android main process performance

- Optimize delay test

- Optimize vpn protect

- Update changelog

## v0.8.72

- Update core

- Fix some issues

- Update changelog

## v0.8.71

- Remake dashboard

- Optimize theme

- Optimize more details

- Update flutter version

- Update changelog

## v0.8.70

- Support better window position memory

- Add windows arm64 and linux arm64 build script

- Optimize some details

## v0.8.69

- Remake desktop

- Optimize change proxy

- Optimize network check

- Fix fallback issues

- Optimize lots of details

- Update change.yaml

- Fix android tile issues

- Fix windows tray issues

- Support setting bypassDomain

- Update flutter version

- Fix android service issues

- Fix macos dock exit button issues

- Add route address setting

- Optimize provider view

- Update changelog

- Update CHANGELOG.md

## v0.8.67

- Add android shortcuts

- Fix init params issues

- Fix dynamic color issues

- Optimize navigator animate

- Optimize window init

- Optimize fab

- Optimize save

## v0.8.66

- Fix the collapse issues

- Add fontFamily options

## v0.8.65

- Update core version

- Update flutter version

- Optimize ip check

- Optimize url-test

## v0.8.64

- Update release message

- Init auto gen changelog

- Fix windows tray issues

- Fix urltest issues

- Add auto changelog

- Fix windows admin auto launch issues

- Add android vpn options

- Support proxies icon configuration

- Optimize android immersion display

- Fix some issues

- Optimize ip detection

- Support android vpn ipv6 inbound switch

- Support log export

- Optimize more details

- Fix android system dns issues

- Optimize dns default option

- Fix some issues

- Update readme

## v0.8.60

- Fix build error2

- Fix build error

- Support desktop hotkey

- Support android ipv6 inbound

- Support android system dns

- fix some bugs

## v0.8.59

- Fix delete profile error

## v0.8.58

- Fix submit error 2

- Fix submit error

- Optimize DNS strategy

- Fix the problem that the tray is not displayed in some cases

- Optimize tray

- Update core

- Fix some error

## v0.8.57

- Fix tun update issues

- Add DNS override
- Fixed some bugs
- Optimize more detail

- Add Hosts override

## v0.8.56

- fix android tip error
- fix windows auto launch error

## v0.8.55

- Fix windows tray issues

- Optimize windows logic

- Optimize app logic

- Support windows administrator auto launch

- Support android close vpn

## v0.8.53

- Change flutter version

- Support profiles sort

- Support windows country flags display

- Optimize proxies page and profiles page columns

## v0.8.52

- Update flutter version

- Update version

- Update timeout time

- Update access control page

- Fix bug

## v0.8.51

- Optimize provider page

- Optimize delay test

- Support local backup and recovery

- Fix android tile service issues

## v0.8.49

- Fix linux core build error

- Add proxy-only traffic statistics

- Update core

- Optimize more details

- Merge pull request #140 from txyyh/main

- 添加自建 F-Droid 仓库相关 workflow
- Rename readme fingerprint

- Rename workflow deploy repo name

- Add download guide to README

- Add push release files to fdroid-repo

## v0.8.48

- Optimize proxies page

- Fix ua issues

- Optimize more details

## v0.8.47

- Fix windows build error

## v0.8.46

- Update app icon

- Fix desktop backup error

- Optimize request ua

- Change android icon

- Optimize dashboard

## v0.8.44

- Remove request validate certificate

- Sync core

## v0.8.43

- Fix windows error

## v0.8.42

- Fix setup.dart error

- Fix android system proxy not effective

- Add macos arm64

## v0.8.41

- Optimize proxies page

- Support mouse drag scroll

- Adjust desktop ui

- Revert "Fix android vpn issues"

- This reverts commit 891977408e6938e2acd74e9b9adb959c48c79988.

## v0.8.40

- Fix android vpn issues

- Fix android vpn issues

- Rollback partial modification

## v0.8.39

- Fix the problem that ui can't be synchronized when android vpn is occupied by an external

- Override default socksPort,port

## v0.8.38

- Fix fab issues

## v0.8.37

- Update version

- Fix the problem that vpn cannot be started in some cases

- Fix the problem that geodata url does not take effect

## v0.8.36

- Update ua

- Fix change outbound mode without check ip issues

- Separate android ui and vpn

- Fix url validate issues 2

- Add android hidden from the recent task

- Add geoip file

- Support modify geoData URL

## v0.8.35

- Fix url validate issues

- Fix check ip performance problem

- Optimize resources page

## v0.8.34

- Add ua selector

- Support modify test url

- Optimize android proxy

- Fix the error that async proxy provider could not selected the proxy

## v0.8.33

- Fix android proxy error

- Fix submit error

- Add windows tun

- Optimize android proxy

- Optimize change profile

- Update application ua

- Optimize delay test

## v0.8.32

- Fix android repeated request notification issues

## v0.8.31

- Fix memory overflow issues

## v0.8.30

- Optimize proxies expansion panel 2

- Fix android scan qrcode error

## v0.8.29

- Optimize proxies expansion panel

- Fix text error

## v0.8.28

- Optimize proxy

- Optimize delayed sorting performance

- Add expansion panel proxies page

- Support to adjust the proxy card size

- Support to adjust proxies columns number

- Fix autoRun show issues

- Fix Android 10 issues

- Optimize ip show

## v0.8.26

- Add intranet IP display

- Add connections page

- Add search in connections, requests

- Add keyword search in connections, requests, logs

- Add basic viewing editing capabilities

- Optimize update profile

## v0.8.25

- Update version

- Fix the problem of excessive memory usage in traffic usage.

- Add lightBlue theme color

- Fix start unable to update profile issues

- Fix flashback caused by process

## v0.8.23

- Add build version

- Optimize quick start

- Update system default option

## v0.8.22

- Update build.yml

- Fix android vpn close issues

- Add requests page

- Fix checkUpdate dark mode style error

- Fix quickStart error open app

- Add memory proxies tab index

- Support hidden group

- Optimize logs

- Fix externalController hot load error

## v0.8.21

- Add tcp concurrent switch

- Add system proxy switch

- Add geodata loader switch

- Add external controller switch

- Add auto gc on trim memory

- Fix android notification error

## v0.8.20

- Fix ipv6 error

- Fix android udp direct error

- Add ipv6 switch

- Add access all selected button

- Remove android low version splash

## v0.8.19

- Update version

- Add allowBypass

- Fix Android only pick .text file issues

## v0.8.18

- Fix search issues

## v0.8.17

- Fix LoadBalance, Relay load error

- Fix build.yml4

- Fix build.yml3

- Fix build.yml2

- Fix build.yml

- Add search function at access control

- Fix the issues with the profile add button to cover the edit button

- Adapt LoadBalance and Relay

- Add arm

- Fix android notification icon error

## v0.8.16

- Add one-click update all profiles
- Add expire show

## v0.8.15

- Temp remove tun mode

- Remove macos in workflow

- Change go version

## v0.8.14

- Update Version

- Fix tun unable to open

## v0.8.13

- Optimize delay test2

- Optimize delay test

- Add check ip

- add check ip request

## v0.8.12

- Fix the problem that the download of remote resources failed after GeodataMode was turned on, which caused the
  application to flash back.

- Fix edit profile error

- Fix quickStart change proxy error

- Fix core version

## v0.8.10

- Fix core version

## v0.8.9

- Update file_picker

- Add resources page

- Optimize more detail

- Add access selected sorted

- Fix notification duplicate creation issue

- Fix AccessControl click issue

## v0.8.7

- Fix Workflow

- Fix Linux unable to open

- Update README.md 3

- Create LICENSE
- Update README.md 2

- Update README.md

- Optimize workFlow

## v0.8.6

- optimize checkUpdate

## v0.8.5

- Fix submit error

## v0.8.4

- add WebDAV

- add Auto check updates

- Optimize more details

- optimize delayTest

## v0.8.2

- upgrade flutter version

## v0.8.1

- Update kernel
- Add import profile via QR code image

## v0.8.0

- Add compatibility mode and adapt clash scheme.

## v0.7.14

- update Version

- Reconstruction application proxy logic

## v0.7.13

- Fix Tab destroy error

## v0.7.12

- Optimize repeat healthcheck

## v0.7.11

- Optimize Direct mode ui

## v0.7.10

- Optimize Healthcheck

- Remove proxies position animation, improve performance
- Add Telegram Link

- Update healthcheck policy

- New Check URLTest

- Fix the problem of invalid auto-selection

## v0.7.8

- New Async UpdateConfig

- add changeProfileDebounce

- Update Workflow

- Fix ChangeProfile block

- Fix Release Message Error

## v0.7.7

- Update Selector 2

## v0.7.6

- Update Version

- Fix Proxies Select Error

## v0.7.5

- Fix the problem that the proxy group is empty in global mode.

- Fix the problem that the proxy group is empty in global mode.

## v0.7.4

- Add ProxyProvider2

## v0.7.3

- Add ProxyProvider

- Update Version

- Update ProxyGroup Sort

- Fix Android quickStart VpnService some problems

## v0.7.1

- Update version

- Set Android notification low importance

- Fix the issue that VpnService can't be closed correctly in special cases

- Fix the problem that TileService is not destroyed correctly in some cases

- Adjust tab animation defaults

- Add Telegram in README_zh_CN.md

- Add Telegram

## v0.7.0

- update mobile_scanner

- Initial commit
