# iOS 一键打包说明（GitHub Actions）

> 本仓库已内置打包流程：只要在 GitHub 网页上点一下，就会自动编译并产出 **IPA 安装包**，全程不需要 Mac 电脑。

---

## 一、准备工作

1. 一个 GitHub 账号（没有的话去 `https://github.com` 免费注册）
2. 本项目文件（就是当前这个文件夹）

---

## 二、第一次使用：把项目放到 GitHub 上

### 1. 新建一个空仓库
1. 登录 GitHub → 右上角 **`+`** → **New repository**
2. **Repository name** 填：`sd-ios-build`（名字随意，用英文）
3. 可见性选择：
   - **Public**（公开）：构建**完全免费**，但代码公开可见
   - **Private**（私有）：代码私有，macOS 构建每月约 200 分钟免费额度（一次打包约 5~10 分钟）
4. ⚠️ **不要勾选** "Add a README file"、"Add .gitignore"、"Choose a license"（必须是空仓库）
5. 点 **Create repository**

### 2. 上传项目
1. 在刚建好的空仓库页面，点中间那行蓝色链接 **uploading an existing file**
2. 把本项目文件夹里的**全部内容**拖进上传区域
   - ⚠️ 注意：要包含隐藏文件夹 **`.github`**（打包流程就放在里面）
   - 用 Mac 拖拽时按 `Command + Shift + .` 可以显示隐藏文件
3. 页面底部点 **Commit changes**

> 也可以用命令行推送（如果本机装了 git）：
> ```bash
> cd 项目文件夹
> git init && git add -A && git commit -m "init"
> git branch -M main
> git remote add origin https://github.com/你的用户名/sd-ios-build.git
> git push -u origin main
> ```

---

## 三、打包（每次要出包时执行）

1. 打开你的仓库页面 → 顶部 **Actions** 标签
2. 左侧列表点 **「iOS 打包（IPA）」**
3. 右侧点 **Run workflow** 按钮 → 弹窗里：
   - **Bundle ID**：一般**留空**（用项目默认值）；如需指定就填，例如 `com.xxx.app`
   - **是否签名**：客户自己找渠道签名的话，保持 **`false`**
4. 点绿色 **Run workflow** 开始构建
5. 等 **5~10 分钟**（首次会慢一些，要下载 Flutter SDK 和依赖）
6. 构建完成后，点进这次运行记录 → 页面底部 **Artifacts** 区域 → 下载 **`unsigned-ipa`**（未签名 IPA）

---

## 四、拿到 IPA 之后

| 你的用途 | 做法 |
|---|---|
| 找签名平台/服务商重签分发 | 直接把下载到的 **未签名 IPA** 交给对方即可（超级签、企业签平台都接收未签名包） |
| 上架 App Store / TestFlight 内测 | 需要**已签名**包：请在下面第五节配置证书后，把"是否签名"选 `true` |

---

## 五、（可选）配置证书，出已签名包

如果你要用自己的证书签名（例如上传 App Store），在仓库里配置 5 个 Secret：

**位置**：仓库 → **Settings** → 左侧 **Secrets and variables** → **Actions** → **New repository secret**

| Secret 名称 | 填什么 |
|---|---|
| `IOS_P12_BASE64` | p12 证书文件转成 base64 后的文本 |
| `IOS_P12_PASSWORD` | p12 证书的密码 |
| `IOS_PROVISION_BASE64` | mobileprovision 描述文件转成 base64 后的文本 |
| `IOS_BUNDLE_ID` | Bundle ID（需与描述文件里的 App ID 一致） |
| `IOS_EXPORT_METHOD` | 导出方式：`app-store` / `ad-hoc` / `enterprise` |

**base64 怎么生成**：
```bash
# Mac / Linux
base64 -i 证书.p12 | pbcopy          # 直接复制到剪贴板
base64 -i xxx.mobileprovision | pbcopy

# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("证书.p12")) | Set-Clipboard
```

配置好后，打包时把 **是否签名** 选 `true`，就会多产出一个 `signed-ipa`。

---

## 六、常见问题

**Q：构建失败了怎么办？**
A：进 Actions 里点开失败的那次运行，把**红色报错那几行**截图发我们，我们来判断（常见原因是依赖下载超时，重跑一次通常就好）。

**Q：每次都要等 5~10 分钟？**
A：是的，主要是下载 Flutter SDK 和编译时间。第二次之后有缓存会快一些。

**Q：私有仓库会不会收费？**
A：GitHub 每月给私有仓库 2000 分钟免费额度，但 macOS 构建按 **10 倍**扣，即实际约 200 分钟/月 —— 一次打包 5~10 分钟，够用 20~40 次。

**Q：可以改应用名称/图标吗？**
A：可以，改完代码提交到仓库再打包即可（应用名在 `ios/Runner/Info.plist` 的 `CFBundleDisplayName`）。

**Q：产出的 IPA 能直接装到手机上吗？**
A：不能。iOS 的安装必须经过签名 —— 未签名 IPA 需要交给签名渠道重签后才能安装（这正是本流程的分工）。

---

## 七、技术细节（给技术人员看）

- 构建环境：GitHub Actions `macos-14` + Xcode 15 + Flutter **3.24.5**
- 编译命令：`flutter build ios --release --no-codesign`
- 打包方式：将 `Runner.app` 放入 `Payload/` 目录后压缩为 `.ipa`
- 流程文件：`.github/workflows/ios-build.yml`
